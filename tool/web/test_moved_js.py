#!/usr/bin/env python3
"""Tests of tool/web/moved/moved.js, the script of the page an earlier address of the web app
answers with (python3 -m unittest discover -s tool/web -p 'test_*.py').

The script runs in Node (the repository's .nvmrc version, which the hygiene job sets up), in a
context that holds only what the script uses of a browser: the page's <meta>, its links, the
address, and a localStorage that can refuse to open.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).parent))
import package_vercel as pv

REPO = Path(__file__).resolve().parents[2]
SCRIPT = pv.MOVED_SOURCES / pv.MOVED_SCRIPT
ORIGIN = "https://app.example.pk"
OLD = "https://old.example.org"

# Runs the script whose path is the first argument in the scenario the second one gives as JSON
# (after `node -e`, the arguments start at argv[1]), and prints what the script did.
HARNESS = r"""
const fs = require('node:fs');
const vm = require('node:vm');
const [path, json] = process.argv.slice(1);
const scenario = JSON.parse(json);
const store = new Map(Object.entries(scenario.storage));
const storage = {
  get length() { return store.size; },
  key(index) { return [...store.keys()][index] ?? null; },
  removeItem(key) { store.delete(key); },
};
const replaced = [];
const listeners = [];
const links = scenario.links.map((href) => ({
  href,
  setAttribute(name, value) { this[name] = value; },
}));
const meta = { getAttribute: (name) => (name === 'content' ? scenario.meta : null) };
const document = {
  querySelector: (selector) =>
    selector === 'meta[name="mm-moved-to"]' && scenario.meta !== null ? meta : null,
  querySelectorAll: (selector) => (selector === 'a[data-moved]' ? links : []),
  addEventListener: (type, listener) => { if (type === 'DOMContentLoaded') listeners.push(listener); },
};
const window = { document, location: { ...scenario.location, replace: (url) => replaced.push(url) } };
Object.defineProperty(window, 'localStorage', {
  get() {
    if (scenario.blocked) throw new Error('SecurityError');
    return storage;
  },
});
vm.runInNewContext(fs.readFileSync(path, 'utf8'), { window, document });
for (const listener of listeners) listener();
console.log(JSON.stringify({
  replaced,
  storage: Object.fromEntries(store),
  links: links.map((link) => link.href),
}));
"""

# What the app keeps in the browser (docs/architecture/app.md, On the device), by example.
APP_KEYS = {
    "mm.swr.v1.tenants.4f2c": '{"rows":["a record of the app"]}',
    "mm.settings.locale": '"ur"',
    "mm.settings.theme": '"dark"',
    "mm.portfolio.current": '"4f2c"',
    "mm.invitation.pending": '"token"',
    "mm.documents.camera_target": '"lease"',
    "sb-abcdefghijklmnop-auth-token": '{"access_token":"x","refresh_token":"y"}',
    "sb-abcdefghijklmnop-auth-token-code-verifier": "v",
    "flutter.supabase.auth.token-code-verifier": '"verifier"',
}
# Names that only look like the app's.
OTHER_KEYS = {
    "theme": "1",
    "mmx.settings": "1",
    "xmm.settings.locale": "1",
    "sb-auth-token": "1",
    "sb-abcdefghijklmnop-auth": "1",
    "flutterx": "1",
    "": "1",
}


def at(path: str = "/", search: str = "", fragment: str = "", origin: str = OLD) -> dict[str, str]:
    """A window.location."""
    return {"origin": origin, "pathname": path, "search": search, "hash": fragment}


def run(
    location: dict[str, str],
    meta: str | None = ORIGIN,
    storage: dict[str, str] | None = None,
    blocked: bool = False,
) -> dict:
    """What the script did at `location`: the addresses it replaced the page with, the storage
    it left and where the page's links point afterwards."""
    scenario = {
        "location": location,
        "meta": meta,
        "storage": {**APP_KEYS, **OTHER_KEYS} if storage is None else storage,
        "links": [f"{ORIGIN}/", f"{ORIGIN}/"],
        "blocked": blocked,
    }
    done = subprocess.run(  # noqa: S603 (node, on this repository's own script)
        ["node", "-e", HARNESS, str(SCRIPT), json.dumps(scenario)],  # noqa: S607
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )
    if done.returncode != 0:
        raise AssertionError(f"node failed: {done.stderr}")
    return json.loads(done.stdout)


class MovedScriptTest(unittest.TestCase):
    def test_removes_the_apps_keys_and_goes_to_the_same_page_on_the_origin(self):
        did = run(at("/invite", "?x=1&y=%20", "#token=abc"))
        # One navigation, which replaces the page (no way back to the earlier address).
        self.assertEqual(did["replaced"], [f"{ORIGIN}/invite?x=1&y=%20#token=abc"])
        self.assertEqual(did["storage"], OTHER_KEYS)
        self.assertEqual(did["links"], [f"{ORIGIN}/invite?x=1&y=%20#token=abc"] * 2)

    def test_keeps_the_path_the_query_and_the_fragment(self):
        for path, search, fragment in (
            ("/a/b/", "", ""),
            ("/invite", "", "#token=abc"),
            ("/leases/4f2c", "?tab=dues", ""),
            ("/auth/callback/extra", "?code=x", ""),
            ("/%D8%A7", "?q=%26", "#%23"),
        ):
            with self.subTest(path=path, search=search, fragment=fragment):
                did = run(at(path, search, fragment))
                self.assertEqual(did["replaced"], [f"{ORIGIN}{path}{search}{fragment}"])

    def test_the_first_page_in_any_spelling_is_the_origins_first_page(self):
        # With more slashes before them too: the earlier address's route answers those with
        # this page as well (package_vercel.legacy_routes).
        for path in (
            "/",
            "/index.html",
            "/moved.html",
            "//",
            "///",
            "//index.html",
            "///moved.html",
        ):
            with self.subTest(path=path):
                did = run(at(path, "?from=mail", "#top"))
                self.assertEqual(did["replaced"], [f"{ORIGIN}/?from=mail#top"])
        self.assertEqual(run(at("/"))["replaced"], [f"{ORIGIN}/"])
        # Only those: a deeper page with such a name is a page of the app.
        self.assertEqual(run(at("/x/index.html"))["replaced"], [f"{ORIGIN}/x/index.html"])
        self.assertEqual(run(at("//x/index.html"))["replaced"], [f"{ORIGIN}//x/index.html"])

    def test_a_path_cannot_send_people_to_another_origin(self):
        for path in ("//evil.example/x", "/\\evil.example", "/@evil.example"):
            with self.subTest(path=path):
                (address,) = run(at(path))["replaced"]
                self.assertTrue(address.startswith(f"{ORIGIN}/"), address)
                self.assertEqual(urlsplit(address).netloc, ORIGIN.removeprefix("https://"))

    def test_on_the_origin_it_removes_nothing_and_goes_nowhere(self):
        # The page's files are served on the origin too; there the storage is the app's own.
        for path in ("/moved.html", "/", "/invite"):
            with self.subTest(path=path):
                did = run(at(path, origin=ORIGIN))
                self.assertEqual(did["replaced"], [])
                self.assertEqual(did["storage"], {**APP_KEYS, **OTHER_KEYS})
                self.assertEqual(did["links"], [f"{ORIGIN}/"] * 2)

    def test_without_a_destination_it_removes_nothing_and_goes_nowhere(self):
        for meta in (
            None,
            "",
            "{{origin}}",
            "http://app.example.pk",
            "https://app.example.pk/",
            "https://app.example.pk/path",
            "https://user@app.example.pk",
            "https://app.example.pk:8443",
            "https://APP.example.pk",
            "javascript:alert(1)",
            "//app.example.pk",
        ):
            with self.subTest(meta=meta):
                did = run(at("/invite"), meta=meta)
                self.assertEqual(did["replaced"], [])
                self.assertEqual(did["storage"], {**APP_KEYS, **OTHER_KEYS})

    def test_storage_the_browser_blocks_does_not_stop_the_move(self):
        did = run(at("/invite", "", "#token=abc"), blocked=True)
        self.assertEqual(did["replaced"], [f"{ORIGIN}/invite#token=abc"])

    def test_empty_storage_is_fine(self):
        did = run(at("/"), storage={})
        self.assertEqual((did["replaced"], did["storage"]), ([f"{ORIGIN}/"], {}))

    def test_every_key_the_app_writes_is_one_the_script_removes(self):
        """The app's keys, read from its sources: the settings' and the record cache's (through
        shared_preferences, which on the web writes each under its own name), Supabase's session
        (supabase_flutter: sb-<the project's first host label>-auth-token, straight into
        localStorage) and gotrue's sign-in-link verifier (shared_preferences' older interface,
        under flutter.)."""
        settings = (REPO / "app/lib/src/settings/app_settings.dart").read_text(encoding="utf-8")
        cache = (REPO / "app/lib/src/data/cache/swr_cache.dart").read_text(encoding="utf-8")
        keys = re.findall(r"static const \w+Key = '([^']+)';", settings)
        (prefix,) = re.findall(r"static const _prefix = '([^']+)';", cache)
        self.assertGreaterEqual(len(keys), 7)
        written = [
            *keys,
            f"{prefix}tenants",
            "sb-abcdefghijklmnop-auth-token",
            "flutter.supabase.auth.token-code-verifier",
        ]
        for key in written:
            self.assertRegex(key, r"^(mm\.|sb-|flutter\.)")
        did = run(at("/"), storage=dict.fromkeys(written, "1"))
        self.assertEqual(did["storage"], {})
        # Every preference of the app is one of those: nothing else opens the preferences.
        users = sorted(
            path.relative_to(REPO).as_posix()
            for path in (REPO / "app/lib").rglob("*.dart")
            if "SharedPreferences" in path.read_text(encoding="utf-8")
        )
        self.assertEqual(
            users,
            [
                "app/lib/src/bootstrap.dart",
                "app/lib/src/data/cache/swr_cache.dart",
                "app/lib/src/settings/app_settings.dart",
            ],
        )

    def test_the_script_fits_the_apps_content_security_policy_and_old_browsers(self):
        script = SCRIPT.read_text(encoding="utf-8")
        code = re.sub(r"^\s*//.*$", "", script, flags=re.MULTILINE)
        # No HTML or script sink (Trusted Types), no network, no timers.
        for sink in (
            "innerHTML",
            "outerHTML",
            "insertAdjacentHTML",
            "document.write",
            "eval(",
            "Function(",
            "setTimeout",
            "setInterval",
            "import(",
            "fetch(",
            "XMLHttpRequest",
            ".src",
            "location.href",
            "location.assign",
        ):
            self.assertNotIn(sink, code, sink)
        # ES5, so a browser without the header still runs it.
        self.assertNotRegex(code, r"=>|\blet\b|\bconst\b|`|\bclass\b|\.\.\.|\?\?|\?\.")
        self.assertIn("'use strict';", code)
        self.assertEqual(code.count("location.replace("), 1)
        # Only this origin's own localStorage, key by key: never clear(), which a later use of
        # the page on an address that keeps other data would turn into a loss.
        self.assertNotIn(".clear(", code)
        self.assertNotIn("sessionStorage", code)


if __name__ == "__main__":
    unittest.main()
