"""Tests for the Vercel packaging tool and its local server.

python3 -m unittest discover -s tool/web -p 'test_*.py'
"""

from __future__ import annotations

import contextlib
import http.client
import io
import json
import re
import sys
import tempfile
import threading
import unittest
import unittest.mock
import urllib.error
import urllib.request
from pathlib import Path
from typing import ClassVar

sys.path.insert(0, str(Path(__file__).parent))
import package_vercel as pv
import serve_output

SUPABASE = "https://abcdefghijklmnop.supabase.co"
FINGERPRINT = ":".join(["96", "C8", "54", "35", "77", "E8", "20", "5A"] * 4)
REPO = Path(__file__).resolve().parents[2]

ASSETLINKS = [
    {
        "relation": [pv.ASSETLINKS_RELATION],
        "target": {
            "namespace": "android_app",
            "package_name": "io.github.example.app",
            "sha256_cert_fingerprints": [FINGERPRINT],
        },
    }
]

INDEX = '<!DOCTYPE html><html><head><base href="/"></head><body>app</body></html>'

# The web app's origins in the tests: the origin and two earlier addresses.
ORIGIN = "https://app.example.pk"
OLD_HOSTS = ("old.example.org", "older-app.example.net")
APP = pv.AppOrigins(ORIGIN, tuple(f"https://{host}" for host in OLD_HOSTS))
MOVED_SCRIPT_TAG = '<script src="/moved.js"></script>'


def write_origins(root: Path, app: object) -> Path:
    path = root / "origins.json"
    path.write_text(json.dumps({"site": {"origin": "https://example.pk"}, "app": app}))
    return path


def write_build(root: Path, assetlinks: object = ASSETLINKS, extra: dict | None = None) -> Path:
    """A minimal Flutter web build under root/build."""
    build = root / "build"
    files = {
        "index.html": INDEX,
        "flutter_bootstrap.js": "// bootstrap",
        "flutter_service_worker.js": "// worker",
        "flutter.js": "// loader",
        "main.dart.js": "// app",
        "version.json": "{}",
        "manifest.json": "{}",
        ".last_build_id": "abc",
        "canvaskit/canvaskit.wasm": "\0asm",
        "assets/fonts/MaterialIcons-Regular.otf": "font",
        pv.ASSETLINKS: json.dumps(assetlinks),
        **(extra or {}),
    }
    for name, text in files.items():
        path = build / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return build


def cache_control(config: dict, path: str) -> list[str]:
    """Every Cache-Control value the pre-filesystem routes give `path`."""
    values = []
    for route in config["routes"]:
        if "handle" in route:
            break
        if re.search(route["src"], path, re.IGNORECASE) and "Cache-Control" in route.get(
            "headers", {}
        ):
            values.append(route["headers"]["Cache-Control"])
    return values


class SupabaseOriginTest(unittest.TestCase):
    def test_accepts_an_https_origin(self):
        self.assertEqual(pv.supabase_origin(SUPABASE + "/"), SUPABASE)
        self.assertEqual(
            pv.supabase_origin("https://db.example.com:8443"), "https://db.example.com:8443"
        )

    def test_refuses_anything_else(self):
        for url in (
            "http://abc.supabase.co",
            "https://abc.supabase.co/rest/v1",
            "https://abc.supabase.co?x=1",
            "https://user:pw@abc.supabase.co",
            "https://<project-ref>.supabase.co",
            "https://a..b.co",
            "abc.supabase.co",
            "",
        ):
            with self.subTest(url=url), self.assertRaises(pv.PackagingError):
                pv.supabase_origin(url)


class ContentSecurityPolicyTest(unittest.TestCase):
    def setUp(self):
        self.csp = pv.content_security_policy(SUPABASE)
        self.directives = {
            part.split()[0]: part.split()[1:] for part in self.csp.split("; ") if part
        }

    def test_backend_is_the_project_only(self):
        self.assertEqual(
            self.directives["connect-src"],
            ["'self'", SUPABASE, "wss://abcdefghijklmnop.supabase.co", "https://fonts.gstatic.com"],
        )
        self.assertIn(SUPABASE, self.directives["img-src"])

    def test_scripts_are_same_origin_with_wasm_only(self):
        self.assertEqual(self.directives["script-src"], ["'self'", "'wasm-unsafe-eval'"])
        self.assertNotIn("'unsafe-eval'", self.csp)
        self.assertNotIn("'unsafe-inline'", self.directives["script-src"])

    def test_locks_down_embedding_plugins_and_base(self):
        self.assertEqual(self.directives["frame-ancestors"], ["'none'"])
        self.assertEqual(self.directives["object-src"], ["'none'"])
        self.assertEqual(self.directives["base-uri"], ["'self'"])
        self.assertEqual(self.directives["form-action"], ["'self'"])
        self.assertEqual(self.directives["default-src"], ["'self'"])

    def test_no_wildcards(self):
        self.assertNotIn("*", self.csp)
        self.assertNotIn("https:", self.csp.replace("https://", ""))


class CachePolicyTest(unittest.TestCase):
    def test_hashed_names_are_immutable(self):
        self.assertTrue(pv.is_immutable("assets/logo.0123abcd.png"))
        self.assertTrue(pv.is_immutable("chunk-deadbeef42.js"))

    def test_flutter_names_and_entry_points_revalidate(self):
        for path in (
            "main.dart.js",
            "canvaskit/canvaskit.wasm",
            "assets/fonts/MaterialIcons-Regular.otf",
            "index.html",
            "flutter_bootstrap.js",
            "flutter_service_worker.js",
            "version.json",
            "manifest.json",
            pv.ASSETLINKS,
            "abc.12345.js",
        ):
            with self.subTest(path=path):
                self.assertFalse(pv.is_immutable(path))


class BuildConfigTest(unittest.TestCase):
    FILES: ClassVar[list[str]] = [
        "index.html",
        "flutter_bootstrap.js",
        "main.dart.js",
        "assets/logo.0123abcd.png",
        pv.ASSETLINKS,
    ]

    def test_shape_follows_build_output_api_v3(self):
        config = pv.build_config(self.FILES, SUPABASE)
        self.assertEqual(config["version"], 3)
        routes = config["routes"]
        self.assertEqual(routes[0]["src"], "^/.*$")
        self.assertTrue(routes[0]["continue"])
        self.assertEqual(
            routes[0]["headers"]["Content-Security-Policy"], pv.content_security_policy(SUPABASE)
        )
        self.assertEqual(routes[-2], {"handle": "filesystem"})
        self.assertEqual(routes[-1], {"src": "^/.*$", "dest": "/index.html", "status": 200})
        self.assertEqual(config["overrides"], {pv.ASSETLINKS: {"contentType": "application/json"}})
        for route in routes[:-2]:
            self.assertEqual(set(route), {"src", "headers", "continue"})
            re.compile(route["src"])

    def test_every_path_gets_exactly_one_cache_policy(self):
        config = pv.build_config(self.FILES, SUPABASE)
        expected = {
            "/assets/logo.0123abcd.png": pv.CACHE_IMMUTABLE,
            "/index.html": pv.CACHE_REVALIDATE,
            "/": pv.CACHE_REVALIDATE,
            "/main.dart.js": pv.CACHE_REVALIDATE,
            "/flutter_bootstrap.js": pv.CACHE_REVALIDATE,
            "/auth/callback": pv.CACHE_REVALIDATE,
            "/assets/logo.0123abcd.png.map": pv.CACHE_REVALIDATE,
            "/x/assets/logo.0123abcd.png": pv.CACHE_REVALIDATE,
        }
        for path, value in expected.items():
            with self.subTest(path=path):
                self.assertEqual(cache_control(config, path), [value])

    def test_without_hashed_files_one_rule_revalidates_everything(self):
        config = pv.build_config(["index.html", "main.dart.js"], SUPABASE)
        self.assertEqual(cache_control(config, "/main.dart.js"), [pv.CACHE_REVALIDATE])
        self.assertEqual(len(config["routes"]), 4)

    def test_without_earlier_addresses_no_route_depends_on_the_host(self):
        for app in (None, pv.AppOrigins(ORIGIN)):
            with self.subTest(app=app):
                config = pv.build_config(self.FILES, SUPABASE, app)
                self.assertEqual(config, pv.build_config(self.FILES, SUPABASE))
                self.assertFalse(any("has" in route for route in config["routes"]))
                self.assertNotIn("Clear-Site-Data", json.dumps(config))

    def test_earlier_addresses_answer_with_the_page_around_the_filesystem(self):
        routes = pv.build_config(self.FILES, SUPABASE, APP)["routes"]
        handle = routes.index({"handle": "filesystem"})
        moved = {
            "has": [{"type": "host", "value": r"old\.example\.org|older-app\.example\.net"}],
            "headers": {"Clear-Site-Data": '"storage"'},
            "dest": "/moved.html",
            "status": 200,
        }
        self.assertEqual(routes[handle - 1], {"src": r"^/+(?:index\.html|moved\.html)?$", **moved})
        # After it every path, /auth/callback included (docs/operations.md, Domains, step 12).
        self.assertEqual(routes[handle + 1], {"src": "^/.*$", **moved})
        # The root and the page with more slashes before them too, and nothing deeper.
        first = re.compile(routes[handle - 1]["src"], re.IGNORECASE)
        for path in ("/", "//", "///", "/index.html", "//index.html", "//moved.html"):
            self.assertTrue(first.search(path), path)
        for path in ("/x/index.html", "//x/", "/index.htm", "/main.dart.js"):
            self.assertFalse(first.search(path), path)
        self.assertEqual(routes[-1], {"src": "^/.*$", "dest": "/index.html", "status": 200})
        self.assertEqual(len(routes), handle + 3)
        # The header routes come first and continue, so the page carries them too.
        for route in routes[: handle - 1]:
            self.assertTrue(route["continue"])
        # A host value matches only those hosts, whole (Vercel anchors it, as the server does).
        value = moved["has"][0]["value"]
        for host, matches in (
            ("old.example.org", True),
            ("older-app.example.net", True),
            ("oldxexample.org", False),
            ("app.example.pk", False),
            ("old.example.org.evil.example", False),
        ):
            self.assertEqual(bool(re.fullmatch(value, host)), matches, host)

    def test_only_an_earlier_address_ever_clears_storage_and_only_storage(self):
        routes = pv.build_config(self.FILES, SUPABASE, APP)["routes"]
        clearing = [route for route in routes if "Clear-Site-Data" in route.get("headers", {})]
        self.assertEqual(len(clearing), 2)
        for route in clearing:
            # Never without the host condition: the origin's storage is the app's own.
            self.assertEqual([c["type"] for c in route["has"]], ["host"])
            self.assertNotIn(ORIGIN.removeprefix("https://"), route["has"][0]["value"])
            # "cache" stalls Chromium, "executionContexts" reloads the page, the app sets no
            # cookies, and "*" means all of them.
            self.assertEqual(route["headers"], {"Clear-Site-Data": '"storage"'})
            self.assertNotIn("continue", route)
        before, after = (re.compile(route["src"], re.IGNORECASE) for route in clearing)
        # Before the filesystem only the pages that are files; the rest of the files are served.
        for path, matches in (
            ("/", True),
            ("/index.html", True),
            ("/moved.html", True),
            ("/moved.js", False),
            ("/main.dart.js", False),
            ("/.well-known/assetlinks.json", False),
            ("/auth/callback", False),
            ("/invite", False),
        ):
            self.assertEqual(bool(before.search(path)), matches, path)
        # After it every path that is not a file, the e-mail links' callback included: since
        # step 12 (docs/operations.md, Domains) it clears the storage that holds a sign-in
        # verifier too, and the page sends the link on to the origin.
        for path, matches in (
            ("/invite", True),
            ("/a/b/", True),
            ("/auth/callback/extra", True),
            ("/auth/callbacks", True),
            ("/auth", True),
            ("/auth/callback", True),
            ("/AUTH/Callback", True),
            ("/auth/callback/", True),
            ("//auth/callback", True),
        ):
            self.assertEqual(bool(after.search(path)), matches, path)

    def test_routes_without_a_host_condition_are_the_config_without_earlier_addresses(self):
        # The routes an earlier address adds all carry its host condition, and taking them away
        # leaves exactly the config of a web app with no earlier address: so no route that a
        # request to the origin can match differs from that one, the callback's included.
        config = pv.build_config(self.FILES, SUPABASE, APP)
        hosted = [route for route in config["routes"] if "has" in route]
        self.assertEqual(len(hosted), 2)
        unconditional = [route for route in config["routes"] if "has" not in route]
        self.assertEqual({**config, "routes": unconditional}, pv.build_config(self.FILES, SUPABASE))

    def test_every_security_header_is_set(self):
        headers = pv.build_config(self.FILES, SUPABASE)["routes"][0]["headers"]
        self.assertEqual(
            set(headers),
            {
                "Content-Security-Policy",
                "Strict-Transport-Security",
                "X-Content-Type-Options",
                "Referrer-Policy",
                "X-Frame-Options",
                "Permissions-Policy",
                "Cross-Origin-Opener-Policy",
                "X-Robots-Tag",
            },
        )
        self.assertEqual(headers["X-Robots-Tag"], "noindex")


class AppOriginsTest(unittest.TestCase):
    def test_reads_contracts_origins_json_by_default(self):
        app = json.loads((REPO / "contracts/origins.json").read_text(encoding="utf-8"))["app"]
        self.assertEqual(
            pv.read_app_origins(), pv.AppOrigins(app["origin"], tuple(app.get("legacy", [])))
        )

    def test_accepts_origins_with_or_without_earlier_addresses(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = write_origins(Path(tmp), {"origin": ORIGIN})
            self.assertEqual(pv.read_app_origins(path), pv.AppOrigins(ORIGIN))
            path = write_origins(Path(tmp), {"origin": ORIGIN, "legacy": list(APP.legacy)})
            self.assertEqual(pv.read_app_origins(path), APP)
            self.assertEqual(APP.legacy_hosts(), OLD_HOSTS)

    def test_refuses_anything_but_https_origins_named_once(self):
        cases = {
            "http": {"origin": "http://app.example.pk"},
            "upper case": {"origin": "https://App.example.pk"},
            "a trailing slash": {"origin": "https://app.example.pk/"},
            "a path": {"origin": "https://example.pk/app"},
            "a port": {"origin": "https://app.example.pk:8443"},
            "credentials": {"origin": "https://u@app.example.pk"},
            "a bare host": {"origin": "app.example.pk"},
            "a regex character": {"origin": "https://app.example.pk|x"},
            "legacy not a list": {"origin": ORIGIN, "legacy": "https://old.example.org"},
            "legacy not a string": {"origin": ORIGIN, "legacy": [1]},
            "a repeat": {"origin": ORIGIN, "legacy": [ORIGIN]},
            "no origin": {"legacy": []},
            "not an object": [ORIGIN],
        }
        for name, app in cases.items():
            with (
                self.subTest(name),
                tempfile.TemporaryDirectory() as tmp,
                self.assertRaises(pv.PackagingError),
            ):
                pv.read_app_origins(write_origins(Path(tmp), app))
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(pv.PackagingError, "cannot read"):
                pv.read_app_origins(Path(tmp) / "absent.json")
            (Path(tmp) / "bad.json").write_text("{", encoding="utf-8")
            with self.assertRaisesRegex(pv.PackagingError, "cannot read"):
                pv.read_app_origins(Path(tmp) / "bad.json")


class CheckBuildTest(unittest.TestCase):
    def test_accepts_a_complete_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            pv.check_build(write_build(Path(tmp)))

    def test_refuses_missing_directory_and_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(pv.PackagingError, "not a directory"):
                pv.check_build(Path(tmp) / "nope")
            build = write_build(Path(tmp))
            (build / pv.ASSETLINKS).unlink()
            with self.assertRaisesRegex(pv.PackagingError, "assetlinks.json"):
                pv.check_build(build)

    def test_refuses_bad_asset_links(self):
        bad_statement = json.loads(json.dumps(ASSETLINKS))
        bad_statement[0]["target"]["sha256_cert_fingerprints"] = [FINGERPRINT.lower()]
        cases = {
            "not JSON": "{",
            "empty": [],
            "wrong relation": [{**ASSETLINKS[0], "relation": ["other"]}],
            "lower-case fingerprint": bad_statement,
            "not an object": ["x"],
        }
        for name, assetlinks in cases.items():
            with self.subTest(name), tempfile.TemporaryDirectory() as tmp:
                build = write_build(Path(tmp))
                text = assetlinks if isinstance(assetlinks, str) else json.dumps(assetlinks)
                (build / pv.ASSETLINKS).write_text(text, encoding="utf-8")
                with self.assertRaises(pv.PackagingError):
                    pv.check_build(build)

    def test_committed_asset_links_are_valid(self):
        with tempfile.TemporaryDirectory() as tmp:
            committed = (REPO / "app/web" / pv.ASSETLINKS).read_text(encoding="utf-8")
            build = write_build(Path(tmp), assetlinks=json.loads(committed))
            pv.check_build(build)
            target = json.loads(committed)[0]["target"]
            self.assertEqual(target["package_name"], "io.github.ar27111994.maalik_e_makaan")


class PackageTest(unittest.TestCase):
    def test_writes_static_files_and_config(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = write_build(Path(tmp))
            output = Path(tmp) / "deploy/.vercel/output"
            config = pv.package(build, output, SUPABASE)
            static = output / "static"
            self.assertTrue((static / "index.html").is_file())
            self.assertTrue((static / pv.ASSETLINKS).is_file())
            self.assertTrue((static / "canvaskit/canvaskit.wasm").is_file())
            self.assertFalse((static / ".last_build_id").exists())
            written = json.loads((output / "config.json").read_text(encoding="utf-8"))
            self.assertEqual(written, config)

    def test_writes_the_page_of_the_earlier_addresses_and_its_script(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            build = write_build(root)
            origins = write_origins(root, {"origin": APP.origin, "legacy": list(APP.legacy)})
            pv.package(build, root / "out", SUPABASE, origins)
            page = (root / "out/static/moved.html").read_text(encoding="utf-8")
            script = (root / "out/static/moved.js").read_text(encoding="utf-8")
        self.assertEqual(script, (pv.MOVED_SOURCES / "moved.js").read_text(encoding="utf-8"))
        self.assertNotIn("{{", page)
        # The destination the script and the redirect smoke test read, once.
        self.assertEqual(page.count(f'<meta name="mm-moved-to" content="{ORIGIN}">'), 1)
        # Same-origin script, no inline one: the app's Content-Security-Policy allows no other.
        self.assertEqual(re.findall(r"<script[^>]*>[^<]*</script>", page), [MOVED_SCRIPT_TAG])
        self.assertNotRegex(page, r"\son[a-z]+=|javascript:")
        # Without scripts: straight to the origin's first page, and a link in each language.
        self.assertIn(
            f'<noscript><meta http-equiv="refresh" content="0; url={ORIGIN}/"></noscript>', page
        )
        self.assertEqual(page.count(f'<a href="{ORIGIN}/"'), 2)
        self.assertEqual(page.count(">app.example.pk</a>"), 2)
        self.assertIn('<p lang="ur" dir="rtl">', page)
        self.assertIn('<meta name="robots" content="noindex">', page)
        # No earlier address is written into either file: the page is the same on each.
        for host in OLD_HOSTS:
            self.assertNotIn(host, page + script)

    def test_without_earlier_addresses_there_is_no_such_page(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            build = write_build(root, extra={"moved.html": "the app's own"})
            pv.package(build, root / "out", SUPABASE, write_origins(root, {"origin": ORIGIN}))
            page = (root / "out/static/moved.html").read_text(encoding="utf-8")
            self.assertEqual(page, "the app's own")
            self.assertFalse((root / "out/static/moved.js").exists())

    def test_refuses_a_build_that_holds_the_pages_names(self):
        for name in ("moved.html", "moved.js"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                build = write_build(root, extra={name: "the app's own"})
                origins = write_origins(root, {"origin": APP.origin, "legacy": list(APP.legacy)})
                with self.assertRaisesRegex(pv.PackagingError, f"already holds {name}"):
                    pv.package(build, root / "out", SUPABASE, origins)
                self.assertFalse((root / "out").exists())

    def test_a_placeholder_without_a_value_stops_the_packaging(self):
        with tempfile.TemporaryDirectory() as tmp:
            sources = Path(tmp)
            (sources / "moved.html").write_text("<p>{{origin}} {{other}}</p>", encoding="utf-8")
            (sources / "moved.js").write_text("// script", encoding="utf-8")
            with (
                unittest.mock.patch.object(pv, "MOVED_SOURCES", sources),
                self.assertRaisesRegex(pv.PackagingError, "placeholder with no value"),
            ):
                pv.moved_files(APP)

    def test_replaces_a_previous_output_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = write_build(Path(tmp))
            output = Path(tmp) / "out"
            pv.package(build, output, SUPABASE)
            (output / "static/stale.js").write_text("old", encoding="utf-8")
            pv.package(build, output, SUPABASE)
            self.assertFalse((output / "static/stale.js").exists())
            (output / "precious.txt").write_text("keep", encoding="utf-8")
            with self.assertRaisesRegex(pv.PackagingError, "refusing"):
                pv.package(build, output, SUPABASE)
            self.assertTrue((output / "precious.txt").exists())
            afile = Path(tmp) / "afile"
            afile.write_text("", encoding="utf-8")
            with self.assertRaisesRegex(pv.PackagingError, "not a directory"):
                pv.package(build, afile, SUPABASE)

    def test_main_reports_errors_with_exit_code_2(self):
        with tempfile.TemporaryDirectory() as tmp:
            build = write_build(Path(tmp))
            stderr, stdout = io.StringIO(), io.StringIO()
            with contextlib.redirect_stderr(stderr):
                code = pv.main(
                    ["--build", str(build), "--output", f"{tmp}/o", "--supabase-url", "http://x.co"]
                )
            self.assertEqual(code, 2)
            self.assertIn("https", stderr.getvalue())
            with contextlib.redirect_stdout(stdout):
                code = pv.main(
                    ["--build", str(build), "--output", f"{tmp}/o", "--supabase-url", SUPABASE]
                )
            self.assertEqual(code, 0)
            # The build's ten files, and the page of the earlier addresses with its script.
            self.assertIn("Packaged 12 files", stdout.getvalue())
            self.assertIn("clear their storage and send people to the origin", stdout.getvalue())
            with (
                contextlib.redirect_stderr(stderr),
                unittest.mock.patch.object(pv, "ORIGINS", Path(tmp) / "absent.json"),
            ):
                code = pv.main(
                    ["--build", str(build), "--output", f"{tmp}/o", "--supabase-url", SUPABASE]
                )
            self.assertEqual(code, 2)
            self.assertIn("cannot read the web app's origins", stderr.getvalue())


class ServeOutputTest(unittest.TestCase):
    """The local server applies config.json the way Vercel does."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        build = write_build(root, extra={"assets/logo.0123abcd.png": "png"})
        output = root / ".vercel/output"
        origins = write_origins(root, {"origin": APP.origin, "legacy": list(APP.legacy)})
        pv.package(build, output, SUPABASE, origins)
        cls.server = serve_output.serve(output)
        cls.server.output = output
        cls.base = "http://{}:{}".format(*cls.server.server_address[:2])
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.tmp.cleanup()

    def get(self, path: str, method: str = "GET"):
        request = urllib.request.Request(self.base + path, method=method)  # noqa: S310 (local)
        try:
            with urllib.request.urlopen(request) as response:  # noqa: S310
                return response.status, dict(response.headers), response.read().decode()
        except urllib.error.HTTPError as error:
            return error.code, dict(error.headers), error.read().decode()

    def get_as(self, host: str, path: str, method: str = "GET"):
        """A request with the Host header `host` (redirects are not followed)."""
        connection = http.client.HTTPConnection(*self.server.server_address[:2], timeout=10)
        try:
            connection.request(method, path, headers={"Host": f"{host}:443"})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), response.read().decode()
        finally:
            connection.close()

    def test_an_earlier_address_answers_every_page_with_the_one_that_clears_and_sends_on(self):
        moved = pv.moved_files(APP)["moved.html"]
        for host in OLD_HOSTS:
            for path in (
                "/",
                "/index.html",
                "/moved.html",
                "/?from=mail",
                "/invite",
                "/invite?x=1",
                "/a/b/?x=1&y=%20",
                "/auth/callback/extra",
                "/auth/callbacks",
                "/auth",
                "/.well-known/other.json",
                # An e-mail link's callback, late or not: the page clears the storage that holds
                # its sign-in verifier and carries the query on (test_moved_js).
                "/auth/callback",
                "/auth/callback?code=x",
                "/AUTH/CALLBACK?code=x",
                "/auth/callback?error=access_denied&error_code=otp_expired",
            ):
                with self.subTest(host=host, path=path):
                    status, headers, body = self.get_as(host, path)
                    self.assertEqual((status, body), (200, moved))
                    self.assertEqual(headers["Clear-Site-Data"], '"storage"')
                    self.assertEqual(headers["Content-Type"], "text/html; charset=utf-8")
                    self.assertNotIn("Location", headers)
                    self.assertEqual(headers["Cache-Control"], pv.CACHE_REVALIDATE)
                    self.assertEqual(
                        headers["Content-Security-Policy"], pv.content_security_policy(SUPABASE)
                    )
                    self.assertEqual(headers["X-Robots-Tag"], "noindex")
        status, headers, body = self.get_as(OLD_HOSTS[0], "/invite?x=1", "HEAD")
        self.assertEqual((status, body, headers["Clear-Site-Data"]), (200, "", '"storage"'))

    def test_an_earlier_address_keeps_serving_its_files_and_clears_nothing(self):
        host = OLD_HOSTS[0]
        status, headers, body = self.get_as(host, "/.well-known/assetlinks.json")
        self.assertEqual((status, headers["Content-Type"]), (200, "application/json"))
        self.assertEqual(json.loads(body), ASSETLINKS)
        self.assertNotIn("Clear-Site-Data", headers)
        for path in (
            "/main.dart.js",
            "/flutter_bootstrap.js",
            "/canvaskit/canvaskit.wasm",
            "/manifest.json",
            "/moved.js",
        ):
            with self.subTest(path=path):
                status, headers, _ = self.get_as(host, path, "HEAD")
                self.assertEqual(status, 200)
                self.assertNotIn("Clear-Site-Data", headers)
        status, headers, body = self.get_as(host, "/moved.js")
        self.assertEqual(headers["Content-Type"], "text/javascript; charset=utf-8")
        self.assertEqual(body, pv.moved_files(APP)["moved.js"])

    def test_the_origin_and_other_hosts_serve_the_app_and_never_clear(self):
        for host in ("app.example.pk", "preview-abc.example.org", "xold.example.org", "localhost"):
            for path in ("/", "/index.html", "/invite?x=1", "/a/b", "/auth/callback?code=x"):
                with self.subTest(host=host, path=path):
                    status, headers, body = self.get_as(host, path)
                    self.assertEqual((status, body), (200, INDEX))
                    self.assertNotIn("Clear-Site-Data", headers)
            # The page's own files are files there too, and its script does nothing on the origin.
            for path in ("/moved.html", "/moved.js", "/.well-known/assetlinks.json"):
                with self.subTest(host=host, path=path):
                    status, headers, _ = self.get_as(host, path)
                    self.assertEqual(status, 200)
                    self.assertNotIn("Clear-Site-Data", headers)

    def test_unknown_paths_fall_back_to_index_with_headers(self):
        for path in ("/", "/auth/callback?code=x", "/invite/abc", "/a/b/c/d"):
            with self.subTest(path=path):
                status, headers, body = self.get(path)
                self.assertEqual(status, 200)
                self.assertEqual(body, INDEX)
                self.assertEqual(headers["Content-Type"], "text/html; charset=utf-8")
                self.assertEqual(headers["Cache-Control"], pv.CACHE_REVALIDATE)
                self.assertEqual(
                    headers["Content-Security-Policy"], pv.content_security_policy(SUPABASE)
                )
                self.assertEqual(headers["X-Frame-Options"], "DENY")
                self.assertEqual(headers["X-Robots-Tag"], "noindex")

    def test_files_keep_their_type_and_cache_policy(self):
        status, headers, body = self.get("/.well-known/assetlinks.json")
        self.assertEqual((status, headers["Content-Type"]), (200, "application/json"))
        self.assertEqual(json.loads(body), ASSETLINKS)
        self.assertEqual(headers["Cache-Control"], pv.CACHE_REVALIDATE)
        _, headers, _ = self.get("/canvaskit/canvaskit.wasm")
        self.assertEqual(headers["Content-Type"], "application/wasm")
        _, headers, _ = self.get("/main.dart.js")
        self.assertEqual(headers["Content-Type"], "text/javascript; charset=utf-8")
        _, headers, _ = self.get("/assets/logo.0123abcd.png", method="HEAD")
        self.assertEqual(headers["Cache-Control"], pv.CACHE_IMMUTABLE)

    def test_a_target_that_starts_with_two_slashes_is_a_path_on_the_host_asked(self):
        # urlsplit("//evil.example/x") reads evil.example as a host and /x as the path; Vercel
        # routes the whole target as the path, on the Host header's host.
        moved = pv.moved_files(APP)["moved.html"]
        for host in OLD_HOSTS:
            for path in (
                "//evil.example/",
                "//evil.example/x/",
                "//evil.example/.well-known/assetlinks.json",
                "//evil.example/auth/callback?code=x",
            ):
                with self.subTest(host=host, path=path):
                    status, headers, body = self.get_as(host, path)
                    self.assertEqual((status, body), (200, moved))
                    self.assertEqual(headers["Clear-Site-Data"], '"storage"')
        # On the origin it is no file: the app's index.html, not main.dart.js.
        status, headers, body = self.get_as("app.example.pk", "//evil.example/main.dart.js")
        self.assertEqual((status, body), (200, INDEX))
        self.assertEqual(headers["Content-Type"], "text/html; charset=utf-8")
        # The router itself, which http.server's own reduction of // to / does not shield.
        router = serve_output.Router.load(Path(self.server.output))
        found = router.resolve("//evil.example/.well-known/assetlinks.json", OLD_HOSTS[0])
        self.assertEqual((found.status, found.file.name), (200, "moved.html"))
        found = router.resolve("//evil.example/main.dart.js?x=1", "app.example.pk")
        self.assertEqual((found.status, found.file.name), (200, "index.html"))

    def test_an_empty_segment_names_no_file_so_routes_and_files_see_the_same_path(self):
        # The routes see the target as sent; the file lookup must not collapse "//" behind
        # their back, or an earlier address answers "//" with the app's shell, not the page
        # that clears its storage.
        moved = pv.moved_files(APP)["moved.html"]
        for host in OLD_HOSTS:
            for path in ("//", "///", "//index.html", "//moved.html", "///index.html?x=1"):
                with self.subTest(host=host, path=path):
                    status, headers, body = self.get_as(host, path)
                    self.assertEqual((status, body), (200, moved))
                    self.assertEqual(headers["Clear-Site-Data"], '"storage"')
            # A file asked for with an empty segment is no file there either.
            for path in ("//main.dart.js", "/assets//logo.0123abcd.png"):
                with self.subTest(host=host, path=path):
                    status, _, body = self.get_as(host, path)
                    self.assertEqual((status, body), (200, moved))
        # On the origin such a path falls back to the app's index.html, as any other path does.
        for path in ("//", "//main.dart.js", "/assets//logo.0123abcd.png"):
            with self.subTest(host="app.example.pk", path=path):
                status, headers, body = self.get_as("app.example.pk", path)
                self.assertEqual((status, body), (200, INDEX))
                self.assertEqual(headers["Content-Type"], "text/html; charset=utf-8")
        # The router itself, without http.server in front of it.
        router = serve_output.Router.load(Path(self.server.output))
        self.assertIsNone(router._file("//index.html"))
        self.assertIsNone(router._file("/assets//logo.0123abcd.png"))
        self.assertEqual(router._file("/").name, "index.html")
        self.assertEqual(router._file("/main.dart.js").name, "main.dart.js")

    def test_a_form_with_a_slash_more_gets_the_page_on_an_earlier_address(self):
        # Android asks for /.well-known/assetlinks.json as written, so only that form is kept
        # among the paths a link or Android asks for; a form with an extra slash is another
        # path, and gets the page that clears and sends on, as any other path does. The
        # callback gets the page in every form.
        moved = pv.moved_files(APP)["moved.html"]
        for host in OLD_HOSTS:
            for path in (
                "//auth/callback",
                "//auth/callback?code=x",
                "/auth//callback",
                "/auth/callback/",
                "//.well-known/assetlinks.json",
                "/.well-known//assetlinks.json",
                "//main.dart.js",
            ):
                with self.subTest(host=host, path=path):
                    status, headers, body = self.get_as(host, path)
                    self.assertEqual((status, body), (200, moved))
                    self.assertEqual(headers["Clear-Site-Data"], '"storage"')
        # On the origin each is the app's shell, as any other path is, and clears nothing.
        for path in ("//auth/callback?code=x", "//.well-known/assetlinks.json"):
            with self.subTest(host="app.example.pk", path=path):
                status, headers, body = self.get_as("app.example.pk", path)
                self.assertEqual((status, body), (200, INDEX))
                self.assertNotIn("Clear-Site-Data", headers)

    def test_a_nul_in_the_path_names_no_file_and_still_gets_an_answer(self):
        # unquote turns %00 into a NUL, which Path.resolve() refuses with ValueError; the
        # server must answer as for any other path, not drop the connection.
        moved = pv.moved_files(APP)["moved.html"]
        for path in ("/%00", "/ur/%00", "/main.dart.js%00", "/%00?x=1"):
            with self.subTest(host="app.example.pk", path=path):
                status, headers, body = self.get_as("app.example.pk", path)
                self.assertEqual((status, body), (200, INDEX))
                self.assertNotIn("Clear-Site-Data", headers)
            with self.subTest(host=OLD_HOSTS[0], path=path):
                status, headers, body = self.get_as(OLD_HOSTS[0], path)
                self.assertEqual((status, body), (200, moved))
                self.assertEqual(headers["Clear-Site-Data"], '"storage"')
        router = serve_output.Router.load(Path(self.server.output))
        self.assertIsNone(router._file("/main.dart.js\0"))

    def test_a_target_that_is_not_a_path_is_a_bad_request(self):
        for target in ("*", "http://evil.example/", "evil.example/x"):
            with self.subTest(target=target):
                status, _, body = self.get_as("app.example.pk", target)
                self.assertEqual((status, body), (400, "Bad Request\n"))

    def test_paths_cannot_escape_the_static_directory(self):
        status, _, body = self.get("/%2e%2e/config.json")
        self.assertEqual(status, 200)
        self.assertEqual(body, INDEX)

    def test_refuses_routes_it_does_not_implement(self):
        redirect = {"src": "/a", "status": 308, "headers": {"Location": "/b"}}
        cases = [
            {"version": 2},
            {"version": 3, "routes": [{"handle": "miss"}]},
            {"version": 3, "routes": [{"src": "/a", "headers": {}, "continue": True, "has": []}]},
            {
                "version": 3,
                "routes": [
                    {
                        "src": "/a",
                        "dest": "/b",
                        "has": [{"type": "header", "key": "x", "value": "y"}],
                    }
                ],
            },
            # A redirect: the package sends people on with a page, so the server has none.
            {"version": 3, "routes": [redirect]},
            {"version": 3, "routes": [{"handle": "filesystem"}, redirect]},
            {"version": 3, "routes": [{"src": "/a", "headers": {}}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "/b", "continue": True}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "/b", "status": 404}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "/b", "locale": {}}]},
            # A rewrite names a static file: no groups, query or other origin.
            {"version": 3, "routes": [{"src": "/(.*)", "dest": "/$1"}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "/b?c=1"}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "https://example.org/b"}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "//example.org/b"}]},
            {"version": 3, "routes": [{"src": "/a", "dest": 1}]},
            {"version": 3, "routes": [{"handle": "filesystem"}, {"src": "/a", "headers": {}}]},
            {"version": 3, "routes": [{"handle": "filesystem"}, {"handle": "filesystem"}]},
        ]
        for config in cases:
            with self.subTest(config=config), tempfile.TemporaryDirectory() as tmp:
                (Path(tmp) / "config.json").write_text(json.dumps(config), encoding="utf-8")
                with self.assertRaises(serve_output.UnsupportedConfigError):
                    serve_output.Router.load(Path(tmp))

    def test_a_rewrite_to_a_missing_file_is_not_found(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            (output / "static").mkdir()
            (output / "static/here.html").write_text("here", encoding="utf-8")
            config = {
                "version": 3,
                "routes": [
                    {"src": "^/.*$", "headers": {"X-A": "1", "X-B": "1"}, "continue": True},
                    {"src": "^/before$", "dest": "/here.html", "headers": {"X-B": "2"}},
                    {"src": "^/gone$", "dest": "/absent.html"},
                    {"handle": "filesystem"},
                    {"src": "^/after$", "dest": "/absent.html", "status": 200},
                ],
            }
            (output / "config.json").write_text(json.dumps(config), encoding="utf-8")
            router = serve_output.Router.load(output)
            found = router.resolve("/before?x=1")
            self.assertEqual((found.status, found.file.name), (200, "here.html"))
            # A rewrite's own headers come after the ones gathered, and replace them.
            self.assertEqual(found.headers, {"X-A": "1", "X-B": "2"})
            for path in ("/gone", "/after", "/nowhere"):
                with self.subTest(path=path):
                    missing = router.resolve(path)
                    self.assertEqual((missing.status, missing.file), (404, None))
                    self.assertEqual(missing.headers, {"X-A": "1", "X-B": "1"})

    def test_main_reports_a_bad_directory(self):
        stderr = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stderr(stderr):
            self.assertEqual(serve_output.main([tmp, "--port", "0"]), 2)
        self.assertIn("error:", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
