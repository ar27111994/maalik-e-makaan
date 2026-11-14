"""Tests for the pre-deploy check of Auth's redirect URLs (check_auth_urls.py).

python3 -m unittest discover -s tool/web -p 'test_*.py'
"""

from __future__ import annotations

import contextlib
import io
import json
import plistlib
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_auth_urls as ca

SCHEME = "io.example.app"
APP = "https://app.example.pk"
OLD = "https://old-app.example.org"
APP_WEB, APP_IOS = f"{APP}/auth/callback", f"{SCHEME}://app.example.pk/auth/callback"
OLD_WEB, OLD_IOS = f"{OLD}/auth/callback", f"{SCHEME}://old-app.example.org/auth/callback"


def checked(site_url: str, *allow: str):
    """(errors, warnings, printed) for Auth's settings against APP with the earlier OLD."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        errors, warnings = ca.check(ca.AuthUrls(site_url, allow), APP, (OLD,), (SCHEME,))
    return errors, warnings, out.getvalue()


class GlobTest(unittest.TestCase):
    def matches(self, pattern: str, text: str) -> bool:
        return bool(ca.glob_regex(pattern).fullmatch(text))

    def test_literal_entries_match_only_themselves(self):
        self.assertTrue(self.matches(APP_WEB, APP_WEB))
        self.assertFalse(self.matches(APP_WEB, f"{APP_WEB}x"))
        self.assertFalse(self.matches(APP_WEB, "https://appxexample.pk/auth/callback"))

    def test_a_star_stops_at_dots_and_slashes(self):
        pattern = "https://*.example.pk/auth/callback"
        self.assertTrue(self.matches(pattern, APP_WEB))
        self.assertFalse(self.matches(pattern, "https://a.b.example.pk/auth/callback"))
        self.assertTrue(self.matches("https://app.example.pk/*", "https://app.example.pk/x"))
        self.assertFalse(self.matches("https://app.example.pk/*", APP_WEB))

    def test_a_double_star_crosses_them(self):
        self.assertTrue(self.matches("https://app.example.pk/**", APP_WEB))
        self.assertTrue(self.matches("https://**.example.pk/**", "https://a.b.example.pk/x/y"))

    def test_question_marks_classes_and_choices(self):
        self.assertTrue(self.matches("https://ap?.example.pk", "https://app.example.pk"))
        self.assertFalse(self.matches("https://ap?.example.pk", "https://ap/.example.pk"))
        self.assertTrue(self.matches("https://[a-c]pp.example.pk", "https://app.example.pk"))
        self.assertFalse(self.matches("https://[!a]pp.example.pk", "https://app.example.pk"))
        self.assertTrue(self.matches("https://[!b]pp.example.pk", "https://app.example.pk"))
        pattern = "https://{app,old-app}.example.{pk,org}/**"
        self.assertTrue(self.matches(pattern, APP_WEB))
        self.assertTrue(self.matches(pattern, "https://old-app.example.org/x"))
        self.assertFalse(self.matches(pattern, "https://other.example.pk/x"))
        self.assertTrue(self.matches(r"https://app\*.pk", "https://app*.pk"))
        self.assertFalse(self.matches(r"https://app\*.pk", "https://appx.pk"))
        # Outside braces a comma and a closing brace are plain characters.
        self.assertTrue(self.matches("a,b}", "a,b}"))

    def test_malformed_entries_are_refused(self):
        for pattern in ("https://[app", "https://{app", "https://{a,b", "x\\", "[]", "[!]"):
            with self.subTest(pattern=pattern), self.assertRaises(ca.AuthCheckError):
                ca.glob_regex(pattern)


class SiteUrlTest(unittest.TestCase):
    def test_scheme_host_and_port_must_all_match(self):
        auth = ca.AuthUrls(f"{APP}/", ())
        self.assertTrue(auth.by_site_url(APP_WEB))
        self.assertFalse(auth.by_site_url(APP_IOS))
        self.assertFalse(auth.by_site_url("https://app.example.pk:8443/auth/callback"))
        self.assertFalse(auth.by_site_url(OLD_WEB))
        self.assertFalse(ca.AuthUrls("", ()).by_site_url(APP_WEB))
        self.assertFalse(ca.AuthUrls("https://app.example.pk:x/", ()).by_site_url(APP_WEB))

    def test_any_port_on_a_loopback_host(self):
        auth = ca.AuthUrls("http://localhost:3000", ())
        self.assertTrue(auth.by_site_url("http://localhost:8080/auth/callback"))


class CheckTest(unittest.TestCase):
    def test_during_the_move_every_callback_must_be_listed(self):
        # Steps 4 to 7: the Site URL is still on the earlier host.
        errors, warnings, out = checked(OLD, APP_WEB, APP_IOS, OLD_WEB, OLD_IOS)
        self.assertEqual((errors, warnings), ([], []))
        for url in (APP_WEB, APP_IOS, OLD_WEB, OLD_IOS):
            self.assertIn(f"{url}: allowed (redirect URLs)", out)

    def test_the_new_callbacks_missing_stop_the_deploy(self):
        errors, _, _ = checked(OLD, OLD_WEB, OLD_IOS)
        self.assertEqual(len(errors), 2)
        self.assertIn(f"Auth does not allow {APP_WEB}, which this release's builds send", errors[0])
        self.assertIn(f"the Site URL, {OLD}", errors[0])
        self.assertIn(APP_IOS, errors[1])

    def test_an_earlier_callback_allowed_by_the_site_url_alone_stops_the_deploy(self):
        errors, _, _ = checked(OLD, APP_WEB, APP_IOS)
        self.assertEqual(len(errors), 2)
        self.assertIn(f"Auth allows {OLD_WEB} only because the Site URL is on its host", errors[0])
        self.assertIn(f"Auth does not allow {OLD_IOS}, which builds from before", errors[1])

    def test_after_the_move_the_site_url_covers_the_web_callback(self):
        errors, warnings, out = checked(APP, APP_IOS, OLD_WEB, OLD_IOS)
        self.assertEqual((errors, warnings), ([], []))
        self.assertIn(f"{APP_WEB}: allowed (the Site URL's host)", out)

    def test_after_the_move_dropped_earlier_callbacks_only_warn(self):
        errors, warnings, _ = checked(APP, APP_IOS)
        self.assertEqual(errors, [])
        self.assertEqual(len(warnings), 2)
        self.assertIn(f"Auth does not allow {OLD_WEB}", warnings[0])
        self.assertIn("out of use", warnings[0])

    def test_wildcards_count_as_listed(self):
        errors, warnings, _ = checked(
            OLD, "https://{app.example.pk,old-app.example.org}/**", f"{SCHEME}://**"
        )
        self.assertEqual((errors, warnings), ([], []))

    def test_no_site_url_and_no_list(self):
        errors, warnings, _ = checked("")
        self.assertEqual(len(errors), 2)
        self.assertIn("the Site URL, (none)", errors[0])
        self.assertEqual(len(warnings), 2)


class ReadTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)

    def write(self, name: str, data: object) -> Path:
        path = self.tmp / name
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_reads_the_management_api_fields(self):
        path = self.write(
            "auth.json", {"site_url": OLD, "uri_allow_list": f" {APP_WEB}, ,{APP_IOS} "}
        )
        self.assertEqual(ca.read_auth(path), ca.AuthUrls(OLD, (APP_WEB, APP_IOS)))
        path = self.write("auth.json", {"site_url": None, "uri_allow_list": None})
        self.assertEqual(ca.read_auth(path), ca.AuthUrls("", ()))

    def test_refuses_what_it_cannot_read(self):
        for data in ({}, [], {"site_url": 1}, {"site_url": OLD, "uri_allow_list": ["x"]}):
            with self.subTest(data=data), self.assertRaises(ca.AuthCheckError):
                ca.read_auth(self.write("auth.json", data))
        with self.assertRaises(ca.AuthCheckError):
            ca.read_auth(self.write("auth.json", {"site_url": OLD, "uri_allow_list": "https://{"}))
        with self.assertRaises(ca.AuthCheckError):
            ca.read_auth(self.tmp / "missing.json")

    def test_reads_the_ios_schemes(self):
        self.assertEqual(ca.read_schemes(), ("io.github.ar27111994.maalikemakaan",))
        path = self.tmp / "Info.plist"
        path.write_bytes(plistlib.dumps({"CFBundleURLTypes": []}))
        with self.assertRaisesRegex(ca.AuthCheckError, "no URL scheme"):
            ca.read_schemes(path)
        path.write_bytes(b"not a plist")
        with self.assertRaisesRegex(ca.AuthCheckError, "cannot read"):
            ca.read_schemes(path)

    def test_callbacks(self):
        self.assertEqual(ca.callbacks(APP, (SCHEME,)), [APP_WEB, APP_IOS])


REF = "abcdefghijklmnopqrst"
TOKEN = "test-value-not-a-real-token"  # a value the output must never show
EVERY = ",".join((APP_WEB, APP_IOS, OLD_WEB, OLD_IOS))


class FakeApi:
    """Answers check_live.answer()'s GETs from a list, recording each URL."""

    def __init__(self, *answers: object):
        self.answers = list(answers)
        self.urls: list[str] = []
        self.pauses: list[float] = []

    def get(self, url: str) -> ca.Answer:
        self.urls.append(url)
        got = self.answers.pop(0)
        if isinstance(got, Exception):
            raise got
        assert isinstance(got, ca.Answer)
        return got


def settings(**fields: object) -> ca.Answer:
    """A 200 holding Auth's settings: `fields`, and a secret the check must not keep."""
    return ca.Answer(200, body=json.dumps({"smtp_pass": "hunter2", **fields}).encode())


class FetchTest(unittest.TestCase):
    def fetch(self, api: FakeApi, ref: str = REF, token: str = TOKEN) -> ca.AuthUrls:
        return ca.fetch_auth(ref, token, api.get, api.pauses.append)

    def test_reads_the_two_fields_from_the_management_api(self):
        api = FakeApi(settings(site_url=OLD, uri_allow_list=EVERY))
        auth = self.fetch(api)
        self.assertEqual(auth, ca.AuthUrls(OLD, (APP_WEB, APP_IOS, OLD_WEB, OLD_IOS)))
        self.assertEqual(api.urls, [f"https://api.supabase.com/v1/projects/{REF}/config/auth"])
        self.assertNotIn("hunter2", repr(auth))

    def test_a_token_that_may_not_read_the_settings(self):
        for status in (401, 403):
            with self.subTest(status=status), self.assertRaises(ca.TokenCannotReadError):
                self.fetch(FakeApi(ca.Answer(status)))

    def test_tries_again_on_5xx_and_no_answer_then_reads(self):
        api = FakeApi(
            ca.Answer(502), ca.UnreachableError("reset"), settings(site_url=APP, uri_allow_list="")
        )
        self.assertEqual(self.fetch(api), ca.AuthUrls(APP, ()))
        self.assertEqual(api.pauses, [5.0, 5.0])

    def test_any_other_failure_stops(self):
        cases = {
            "404": FakeApi(ca.Answer(404)),
            "a redirect": FakeApi(ca.Answer(302)),
            "5xx every time": FakeApi(*[ca.Answer(503)] * 6),
            "no answer": FakeApi(*[ca.UnreachableError("timed out")] * 6),
            "not JSON": FakeApi(ca.Answer(200, body=b"<html>")),
            "no site_url": FakeApi(ca.Answer(200, body=b"{}")),
        }
        for name, api in cases.items():
            with self.subTest(name), self.assertRaises(ca.AuthCheckError):
                self.fetch(api)

    def test_refuses_a_bad_reference_or_no_token_before_any_request(self):
        for ref, token in (("abc/../x", TOKEN), ("ABCDEFGHIJKLMNOPQRST", TOKEN), (REF, "")):
            api = FakeApi()
            with self.subTest(ref=ref, token=bool(token)), self.assertRaises(ca.AuthCheckError):
                self.fetch(api, ref, token)
            self.assertEqual(api.urls, [])

    def test_the_request_carries_the_token_and_follows_no_redirect(self):
        seen: dict[str, object] = {}

        class Opener:
            def open(self, request, timeout):
                seen["auth"] = request.get_header("Authorization")
                seen["timeout"] = timeout
                raise ca.urllib.error.URLError("offline")

        with (
            unittest.mock.patch.object(
                ca.urllib.request, "build_opener", return_value=Opener()
            ) as build,
            self.assertRaises(ca.UnreachableError),
        ):
            ca.fetch_with_token(TOKEN)("https://api.supabase.com/x")
        self.assertEqual(seen, {"auth": f"Bearer {TOKEN}", "timeout": ca.TIMEOUT_SECONDS})
        self.assertIs(build.call_args.args[0], ca._NoRedirect)
        self.assertIsNone(ca._NoRedirect().redirect_request())


class MainTest(unittest.TestCase):
    def run_api(self, api: FakeApi, environ: dict[str, str] | None = None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ca.main(
                ["--project-ref", REF],
                {"SUPABASE_ACCESS_TOKEN": TOKEN} if environ is None else environ,
                api.get,
                api.pauses.append,
            )
        self.assertNotIn(TOKEN, out.getvalue())
        self.assertNotIn("hunter2", out.getvalue())
        return code, out.getvalue()

    def test_from_the_api_passes_against_the_repository_files(self):
        # The repository's contracts/origins.json and Info.plist, during the move.
        origins = ca.read_origins()
        schemes = ca.read_schemes()
        allow = ",".join(
            url
            for origin in (origins.app, *origins.app_legacy)
            for url in ca.callbacks(origin, schemes)
        )
        site = origins.app_legacy[0] if origins.app_legacy else origins.app
        code, out = self.run_api(FakeApi(settings(site_url=site, uri_allow_list=allow)))
        self.assertEqual(code, 0, out)
        self.assertIn("Auth allows the e-mail links of this release's builds", out)

    def test_from_the_api_fails_on_a_missing_callback(self):
        code, out = self.run_api(
            FakeApi(settings(site_url="https://elsewhere.example", uri_allow_list=""))
        )
        self.assertEqual(code, 1)
        self.assertIn("nothing that sends them is built or deployed", out)

    def test_a_token_that_may_not_read_only_warns(self):
        code, out = self.run_api(FakeApi(ca.Answer(403)))
        self.assertEqual(code, 0)
        self.assertIn("::warning::The access token may not read Auth's settings (HTTP 403)", out)
        self.assertIn("goes ahead", out)
        self.assertNotIn("::error::", out)

    def test_unreadable_settings_or_no_token_fail(self):
        code, out = self.run_api(FakeApi(*[ca.Answer(500)] * 6))
        self.assertEqual(code, 2)
        self.assertIn("::error::Auth's settings could not be read (HTTP 500)", out)
        code, out = self.run_api(FakeApi(), environ={})
        self.assertEqual(code, 2)
        self.assertIn("::error::SUPABASE_ACCESS_TOKEN is not set", out)

    def test_a_file_or_the_api_not_both(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            ca.main(["auth.json", "--project-ref", REF], {}, FakeApi().get)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            ca.main([], {}, FakeApi().get)

    def run_main(self, auth: object, origins: object | None = None):
        out = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(out):
            auth_path = Path(tmp) / "auth.json"
            auth_path.write_text(json.dumps(auth), encoding="utf-8")
            origins_path = Path(tmp) / "origins.json"
            origins_path.write_text(
                json.dumps(
                    origins
                    or {
                        "site": {"origin": "https://example.pk"},
                        "app": {"origin": APP, "legacy": [OLD]},
                    }
                ),
                encoding="utf-8",
            )
            plist = Path(tmp) / "Info.plist"
            plist.write_bytes(
                plistlib.dumps({"CFBundleURLTypes": [{"CFBundleURLSchemes": [SCHEME]}]})
            )
            code = ca.main([str(auth_path), "--origins", str(origins_path), "--plist", str(plist)])
        return code, out.getvalue()

    def test_passes(self):
        allow = ",".join((APP_WEB, APP_IOS, OLD_WEB, OLD_IOS))
        code, out = self.run_main({"site_url": OLD, "uri_allow_list": allow})
        self.assertEqual(code, 0)
        self.assertIn("Auth allows the e-mail links of this release's builds", out)

    def test_warnings_alone_pass(self):
        code, out = self.run_main({"site_url": APP, "uri_allow_list": APP_IOS})
        self.assertEqual(code, 0)
        self.assertEqual(out.count("::warning::"), 2)

    def test_errors_fail(self):
        code, out = self.run_main({"site_url": OLD, "uri_allow_list": ""})
        self.assertEqual(code, 1)
        self.assertEqual(out.count("::error::"), 4)
        self.assertIn(
            "4 e-mail link address(es) not allowed; nothing that sends them is built or deployed",
            out,
        )

    def test_unreadable_input_is_an_error(self):
        code, out = self.run_main({"uri_allow_list": ""})
        self.assertEqual(code, 2)
        code, out = self.run_main({"site_url": OLD}, origins={"site": {}, "app": {}})
        self.assertEqual(code, 2)
        self.assertIn("::error::", out)


if __name__ == "__main__":
    unittest.main()
