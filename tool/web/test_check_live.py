"""Tests for the pre-deploy check that the addresses answer (check_live.py).

python3 -m unittest discover -s tool/web -p 'test_*.py'
"""

from __future__ import annotations

import contextlib
import http.server
import io
import json
import os
import socket
import sys
import tempfile
import threading
import unittest
import unittest.mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_live as cl
import package_vercel as pv

REPO = Path(__file__).resolve().parents[2]
SITE = "https://example.pk"
WWW = "https://www.example.pk"
APP = "https://app.example.pk"
OLD_APP = "https://old-app.example.org"
ORIGINS = cl.Origins(SITE, (WWW,), APP, (OLD_APP,))
STATEMENTS = json.dumps([{"relation": ["x"], "target": {"package_name": "a.b"}}]).encode()


def moved_page(origin: str) -> bytes:
    """The page an earlier address of the web app answers with, as package_vercel.py writes it
    for `origin`."""
    app = pv.AppOrigins(origin, (OLD_APP,))
    return pv.moved_files(app)[pv.MOVED_PAGE].encode()


# Every address answering as it does once the move is live.
LIVE = {
    f"{SITE}/": cl.Answer(200),
    f"{WWW}/": cl.Answer(308, f"{SITE}/"),
    f"{APP}{cl.ASSETLINKS}": cl.Answer(200, body=STATEMENTS),
    f"{OLD_APP}/": cl.Answer(200, body=moved_page(APP)),
}


class Web:
    """A fake fetch: each URL's answers in turn (the last one repeats), or UnreachableError."""

    def __init__(self, answers: dict[str, object]) -> None:
        self.answers = {
            url: list(value) if isinstance(value, list) else [value]
            for url, value in answers.items()
        }
        self.calls: list[str] = []

    def __call__(self, url: str) -> cl.Answer:
        self.calls.append(url)
        queue = self.answers.get(url, [cl.UnreachableError("no such host")])
        value = queue.pop(0) if len(queue) > 1 else queue[0]
        if isinstance(value, Exception):
            raise value
        return value


def run(part: str, answers: dict[str, object], origins: cl.Origins = ORIGINS):
    """(problems, printed lines) of one check against fake answers, without sleeping."""
    checker = cl.Checker(Web(answers), sleep=lambda _: None)
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        getattr(checker, part)(origins)
    return checker.problems, out.getvalue()


def write_origins(root: Path, data: object) -> Path:
    path = root / "origins.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


class ReadOriginsTest(unittest.TestCase):
    def test_reads_contracts_origins_json_by_default(self):
        data = json.loads((REPO / "contracts/origins.json").read_text(encoding="utf-8"))
        origins = cl.read_origins()
        self.assertEqual(origins.site, data["site"]["origin"])
        self.assertEqual(origins.site_aliases, tuple(data["site"].get("aliases", [])))
        self.assertEqual(origins.app, data["app"]["origin"])
        self.assertEqual(origins.app_legacy, tuple(data["app"].get("legacy", [])))

    def test_aliases_and_earlier_addresses_are_optional(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = write_origins(Path(tmp), {"site": {"origin": SITE}, "app": {"origin": APP}})
            self.assertEqual(cl.read_origins(path), cl.Origins(SITE, (), APP, ()))

    def test_refuses_what_is_not_an_https_origin(self):
        for site, app in (
            ("http://example.pk", APP),
            (SITE, "https://app.example.pk/"),
            (SITE, "https://App.example.pk"),
            (SITE, "https://app.example.pk:8443"),
            (SITE, 7),
        ):
            with self.subTest(site=site, app=app), tempfile.TemporaryDirectory() as tmp:
                path = write_origins(Path(tmp), {"site": {"origin": site}, "app": {"origin": app}})
                with self.assertRaisesRegex(cl.OriginsError, "not an https origin"):
                    cl.read_origins(path)

    def test_refuses_a_file_it_cannot_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            for data in ({"site": {"origin": SITE}}, [], {"site": "x", "app": "y"}):
                with self.subTest(data=data):
                    path = write_origins(Path(tmp), data)
                    with self.assertRaisesRegex(cl.OriginsError, "cannot read"):
                        cl.read_origins(path)
            path = write_origins(
                Path(tmp), {"site": {"origin": SITE, "aliases": WWW}, "app": {"origin": APP}}
            )
            with self.assertRaisesRegex(cl.OriginsError, "site.aliases must be a list"):
                cl.read_origins(path)
            with self.assertRaisesRegex(cl.OriginsError, "cannot read"):
                cl.read_origins(Path(tmp) / "missing.json")


class AnswerTest(unittest.TestCase):
    def setUp(self):
        self.pauses: list[float] = []

    def answer(self, web: Web) -> cl.Answer:
        return cl.answer("https://x.example.pk/", web, self.pauses.append)

    def test_the_first_answer_below_500_is_taken_at_once(self):
        for status in (200, 308, 400, 401, 403, 404, 409):
            with self.subTest(status=status):
                web = Web({"https://x.example.pk/": cl.Answer(status)})
                self.assertEqual(self.answer(web).status, status)
                self.assertEqual(len(web.calls), 1)
        self.assertEqual(self.pauses, [])

    def test_no_answer_and_5xx_are_tried_again(self):
        web = Web(
            {
                "https://x.example.pk/": [
                    cl.UnreachableError("timed out"),
                    cl.Answer(503),
                    cl.Answer(200),
                ]
            }
        )
        self.assertEqual(self.answer(web).status, 200)
        self.assertEqual(self.pauses, [cl.PAUSE_SECONDS] * 2)

    def test_408_and_429_are_tried_again(self):
        for status in (408, 429):
            with self.subTest(status=status):
                self.pauses.clear()
                web = Web({"https://x.example.pk/": [cl.Answer(status), cl.Answer(200)]})
                self.assertEqual(self.answer(web).status, 200)
                self.assertEqual(self.pauses, [cl.PAUSE_SECONDS])

    def test_a_lasting_429_is_returned_after_the_last_try(self):
        web = Web({"https://x.example.pk/": cl.Answer(429)})
        self.assertEqual(self.answer(web).status, 429)
        self.assertEqual(len(web.calls), cl.TRIES)
        self.assertEqual(self.pauses, [cl.PAUSE_SECONDS] * (cl.TRIES - 1))

    def test_retry_after_sets_the_pause_within_the_cap(self):
        cases = {
            "2": 2.0,
            " 2 ": 2.0,
            "0": 0.0,
            "60": cl.MAX_RETRY_AFTER_SECONDS,
            "61": cl.MAX_RETRY_AFTER_SECONDS,
            "86400": cl.MAX_RETRY_AFTER_SECONDS,
            "9" * 5000: cl.MAX_RETRY_AFTER_SECONDS,
            "": cl.PAUSE_SECONDS,
            "soon": cl.PAUSE_SECONDS,
            "-1": cl.PAUSE_SECONDS,
            "1.5": cl.PAUSE_SECONDS,
            "\u0662": cl.PAUSE_SECONDS,  # an Arabic-Indic two: not ASCII digits
            "Wed, 21 Oct 2026 07:28:00 GMT": cl.PAUSE_SECONDS,
        }
        for header, pause in cases.items():
            with self.subTest(header=header[:20]):
                self.pauses.clear()
                web = Web(
                    {
                        "https://x.example.pk/": [
                            cl.Answer(429, retry_after=header),
                            cl.Answer(200),
                        ]
                    }
                )
                self.assertEqual(self.answer(web).status, 200)
                self.assertEqual(self.pauses, [pause])

    def test_retry_after_on_a_5xx_counts_and_no_answer_falls_back(self):
        web = Web(
            {
                "https://x.example.pk/": [
                    cl.Answer(503, retry_after="3"),
                    cl.UnreachableError("reset"),
                    cl.Answer(200),
                ]
            }
        )
        self.assertEqual(self.answer(web).status, 200)
        self.assertEqual(self.pauses, [3.0, cl.PAUSE_SECONDS])

    def test_gives_up_after_the_last_try(self):
        web = Web({"https://x.example.pk/": cl.UnreachableError("certificate verify failed")})
        with self.assertRaisesRegex(cl.UnreachableError, "certificate verify failed"):
            self.answer(web)
        self.assertEqual(len(web.calls), cl.TRIES)
        self.assertEqual(len(self.pauses), cl.TRIES - 1)

    def test_a_lasting_5xx_is_returned(self):
        web = Web({"https://x.example.pk/": [cl.UnreachableError("reset"), cl.Answer(502)]})
        self.assertEqual(self.answer(web).status, 502)
        self.assertEqual(len(web.calls), cl.TRIES)


class AppCheckTest(unittest.TestCase):
    def test_passes_when_the_origin_serves_the_app_links_file(self):
        problems, out = run("app", LIVE)
        self.assertEqual(problems, 0)
        self.assertIn(f"{APP}{cl.ASSETLINKS}: 200, 1 statement(s)", out)

    def test_fails_when_the_origin_does_not_answer(self):
        problems, out = run("app", {})
        self.assertEqual(problems, 1)
        self.assertIn(f"::error::{APP}{cl.ASSETLINKS} does not answer over HTTPS", out)
        self.assertIn("steps 2 and 3", out)

    def test_fails_on_another_status(self):
        for status in (404, 308, 503):
            with self.subTest(status=status):
                problems, out = run("app", {f"{APP}{cl.ASSETLINKS}": cl.Answer(status)})
                self.assertEqual(problems, 1)
                self.assertIn(f"answered {status}, not 200", out)

    def test_fails_when_the_file_is_not_a_list_of_statements(self):
        for body in (b"<!DOCTYPE html>", b"[]", b"{}", b"\xff"):
            with self.subTest(body=body):
                answers = {f"{APP}{cl.ASSETLINKS}": cl.Answer(200, body=body)}
                problems, out = run("app", answers)
                self.assertEqual(problems, 1)
                self.assertIn("is not a JSON list of statements", out)


class SiteCheckTest(unittest.TestCase):
    def test_passes_once_everything_is_live(self):
        problems, out = run("site", LIVE)
        self.assertEqual(problems, 0, out)
        self.assertIn(f"{SITE}/: 200", out)
        self.assertIn(f"{WWW}/: 308 to {SITE}/", out)
        self.assertIn(f"{OLD_APP}/: 200, the page that sends people on to {APP}", out)

    def test_an_earlier_address_that_redirects_to_the_origin_passes_too(self):
        # What a deployment that carries a move may also do, when it has no storage to clear.
        problems, out = run("site", {**LIVE, f"{OLD_APP}/": cl.Answer(308, f"{APP}/")})
        self.assertEqual(problems, 0, out)
        self.assertIn(f"{OLD_APP}/: 308 to {APP}/", out)

    def test_fails_when_the_web_app_of_the_move_is_not_deployed_yet(self):
        # Before the web app's deploy, the earlier address serves the app itself.
        app = b'<!DOCTYPE html><html><body><script src="flutter_bootstrap.js"></script></body>'
        for body in (b"", app):
            with self.subTest(body=body):
                problems, out = run("site", {**LIVE, f"{OLD_APP}/": cl.Answer(200, body=body)})
                self.assertEqual(problems, 1)
                self.assertIn(
                    f"::error::{OLD_APP}/ answered 200 without sending people on to {APP}", out
                )
                self.assertIn("deploy the web app of this release first", out)

    def test_fails_when_an_earlier_address_sends_people_elsewhere(self):
        for answer, message in (
            (
                cl.Answer(200, body=moved_page("https://elsewhere.example.org")),
                f"{OLD_APP}/ sends people on to https://elsewhere.example.org, not {APP}",
            ),
            (
                cl.Answer(200, body=b'<meta name="mm-moved-to" content="">'),
                f"{OLD_APP}/ sends people on to nowhere, not {APP}",
            ),
            (
                # The origin with a path is not the origin: the script would refuse it.
                cl.Answer(200, body=moved_page(APP).replace(APP.encode(), f"{APP}/x".encode())),
                f"{OLD_APP}/ sends people on to {APP}/x, not {APP}",
            ),
            (
                cl.Answer(308, "https://elsewhere.example.org/"),
                f"{OLD_APP}/ redirects to https://elsewhere.example.org/, not {APP}/",
            ),
            (cl.Answer(308, APP), f"{OLD_APP}/ redirects to {APP}, not {APP}/"),
            (cl.Answer(308), f"{OLD_APP}/ redirects to nowhere, not {APP}/"),
            (cl.Answer(301, f"{APP}/"), f"{OLD_APP}/ answered 301, and does not send people on"),
            (cl.Answer(404), f"{OLD_APP}/ answered 404, and does not send people on"),
            (cl.UnreachableError("timed out"), f"{OLD_APP}/ does not answer over HTTPS"),
        ):
            with self.subTest(message=message):
                problems, out = run("site", {**LIVE, f"{OLD_APP}/": answer})
                self.assertEqual(problems, 1, out)
                self.assertIn(f"::error::{message}", out)

    def test_fails_when_an_alias_redirects_elsewhere(self):
        answers = {**LIVE, f"{WWW}/": cl.Answer(308, "https://elsewhere.example.org/")}
        problems, out = run("site", answers)
        self.assertEqual(problems, 1)
        self.assertIn(f"{WWW}/ redirects to https://elsewhere.example.org/, not {SITE}/", out)
        # An alias redirects by the hosting's own setting: a page there is not one.
        problems, out = run("site", {**LIVE, f"{WWW}/": cl.Answer(200, body=moved_page(SITE))})
        self.assertEqual(problems, 1)
        self.assertIn(f"::error::{WWW}/ answered 200, not 308", out)

    def test_fails_when_the_new_hosts_do_not_answer(self):
        problems, out = run("site", {f"{OLD_APP}/": LIVE[f"{OLD_APP}/"]})
        self.assertEqual(problems, 3)
        for url in (f"{SITE}/", f"{WWW}/", f"{APP}{cl.ASSETLINKS}"):
            self.assertIn(f"::error::{url} does not answer over HTTPS", out)

    def test_without_aliases_or_earlier_addresses_checks_the_origins_alone(self):
        problems, out = run("site", LIVE, cl.Origins(SITE, (), APP, ()))
        self.assertEqual(problems, 0)
        self.assertNotIn("308", out)
        self.assertNotIn("sends people on", out)


class MainTest(unittest.TestCase):
    def main(self, *argv: str, answers: dict[str, object] | None = None):
        out = io.StringIO()
        with (
            contextlib.redirect_stdout(out),
            unittest.mock.patch.object(cl, "PAUSE_SECONDS", 0),
            tempfile.TemporaryDirectory() as tmp,
        ):
            path = write_origins(
                Path(tmp),
                {
                    "site": {"origin": SITE, "aliases": [WWW]},
                    "app": {"origin": APP, "legacy": [OLD_APP]},
                },
            )
            code = cl.main([*argv, "--origins", str(path)], get=Web(answers or LIVE))
        return code, out.getvalue()

    def test_exit_codes(self):
        self.assertEqual(self.main("app")[0], 0)
        self.assertEqual(self.main("site")[0], 0)
        code, out = self.main("site", answers={**LIVE, f"{SITE}/": cl.Answer(404)})
        self.assertEqual(code, 1)
        self.assertIn("1 address check(s) failed; nothing was built or deployed", out)

    def test_a_bad_origins_file_is_an_error(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), tempfile.TemporaryDirectory() as tmp:
            path = write_origins(Path(tmp), {"site": {"origin": "http://x"}, "app": {}})
            self.assertEqual(cl.main(["app", "--origins", str(path)], get=Web({})), 2)
        self.assertIn("::error::", out.getvalue())

    def test_refuses_an_unknown_part(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            cl.main(["everything"])


class _Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/busy":
            self.send_response(429)
            self.send_header("Retry-After", "7")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif self.path == "/moved":
            self.send_response(308)
            self.send_header("Location", "https://app.example.pk/")
            self.end_headers()
        elif self.path == "/ok":
            body = b"[1]"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def log_message(self, *args):
        pass


class FetchTest(unittest.TestCase):
    """fetch() against a real local server: answers as they are, redirects not followed."""

    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.server.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        local = "127.0.0.1,localhost"
        patch = unittest.mock.patch.dict(os.environ, {"NO_PROXY": local, "no_proxy": local})
        patch.start()
        self.addCleanup(patch.stop)

    def test_answers(self):
        self.assertEqual(cl.fetch(f"{self.base}/ok"), cl.Answer(200, "", b"[1]"))
        moved = cl.fetch(f"{self.base}/moved")
        self.assertEqual((moved.status, moved.location), (308, "https://app.example.pk/"))
        self.assertEqual(cl.fetch(f"{self.base}/missing").status, 404)
        self.assertEqual(cl.fetch(f"{self.base}/busy"), cl.Answer(429, "", b"", "7"))

    def test_no_server_is_unreachable(self):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        with self.assertRaises(cl.UnreachableError):
            cl.fetch(f"http://127.0.0.1:{port}/")


if __name__ == "__main__":
    unittest.main()
