"""Tests for the Vercel packaging tool and its local server.

python3 -m unittest discover -s tool/web -p 'test_*.py'
"""

from __future__ import annotations

import contextlib
import io
import json
import re
import sys
import tempfile
import threading
import unittest
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
            },
        )


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
            self.assertIn("Packaged 10 files", stdout.getvalue())


class ServeOutputTest(unittest.TestCase):
    """The local server applies config.json the way Vercel does."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        build = write_build(root, extra={"assets/logo.0123abcd.png": "png"})
        output = root / ".vercel/output"
        pv.package(build, output, SUPABASE)
        cls.server = serve_output.serve(output)
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

    def test_paths_cannot_escape_the_static_directory(self):
        status, _, body = self.get("/%2e%2e/config.json")
        self.assertEqual(status, 200)
        self.assertEqual(body, INDEX)

    def test_refuses_routes_it_does_not_implement(self):
        cases = [
            {"version": 2},
            {"version": 3, "routes": [{"handle": "miss"}]},
            {"version": 3, "routes": [{"src": "/a", "dest": "/b"}]},
            {"version": 3, "routes": [{"src": "/a", "headers": {}, "continue": True, "has": []}]},
            {"version": 3, "routes": [{"handle": "filesystem"}, {"src": "/a", "headers": {}}]},
            {"version": 3, "routes": [{"handle": "filesystem"}, {"handle": "filesystem"}]},
        ]
        for config in cases:
            with self.subTest(config=config), tempfile.TemporaryDirectory() as tmp:
                (Path(tmp) / "config.json").write_text(json.dumps(config), encoding="utf-8")
                with self.assertRaises(serve_output.UnsupportedConfigError):
                    serve_output.Router.load(Path(tmp))

    def test_main_reports_a_bad_directory(self):
        stderr = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stderr(stderr):
            self.assertEqual(serve_output.main([tmp, "--port", "0"]), 2)
        self.assertIn("error:", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
