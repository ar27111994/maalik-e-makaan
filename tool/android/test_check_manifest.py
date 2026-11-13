"""Tests of check_manifest.py (make test-tools)."""

import io
import json
import tempfile
import unittest
import unittest.mock
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import check_manifest

HEADER = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'
ICONS = 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"'
HOSTS = {"app.example.pk", "old.example.org"}


# The <data> of an App Links filter for HOSTS: each scheme, with each host, with each path.
DATA = (
    '<data android:scheme="https"/><data android:host="app.example.pk"/>'
    '<data android:host="old.example.org"/><data android:pathPrefix="/auth/callback"/>'
    '<data android:path="/invite"/>'
)


def app_links(data: str = DATA, verify: str = 'android:autoVerify="true"') -> str:
    """An activity with an App Links filter holding `data`."""
    return (
        f'<activity android:name=".MainActivity"><intent-filter {verify}>'
        '<action android:name="android.intent.action.VIEW"/>'
        '<category android:name="android.intent.category.BROWSABLE"/>'
        f"{data}</intent-filter></activity>"
    )


APPLICATION = f"<application {ICONS}>{app_links()}</application>"


class CheckManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, body, name="AndroidManifest.xml", application=APPLICATION):
        path = self.dir / name
        path.write_text(f"{HEADER}{body}{application}</manifest>", encoding="utf-8")
        return path

    def run_main(self, *paths):
        out, err = io.StringIO(), io.StringIO()
        with (
            redirect_stdout(out),
            redirect_stderr(err),
            unittest.mock.patch.object(check_manifest, "app_link_hosts", return_value=HOSTS),
        ):
            code = check_manifest.main([str(path) for path in paths])
        return code, out.getvalue(), err.getvalue()

    def problems(self, path):
        return check_manifest.problems(path, HOSTS)

    def test_the_repository_main_manifest_passes(self):
        self.assertEqual(check_manifest.problems(check_manifest.MAIN_MANIFEST), [])

    def test_a_manifest_with_the_permission_passes(self):
        code, out, err = self.run_main(self.manifest(INTERNET))
        self.assertEqual(code, 0)
        self.assertIn("passed", out)
        self.assertEqual(err, "")

    def test_a_manifest_without_internet_fails(self):
        path = self.manifest('<uses-permission android:name="android.permission.CAMERA"/>')
        code, _, err = self.run_main(path)
        self.assertEqual(code, 1)
        self.assertIn("android.permission.INTERNET", err)

    def test_a_permission_named_without_the_android_namespace_does_not_count(self):
        path = self.manifest('<uses-permission name="android.permission.INTERNET"/>')
        self.assertEqual(len(self.problems(path)), 1)

    def test_every_manifest_given_is_checked(self):
        good = self.manifest(INTERNET, "good.xml")
        bad = self.manifest("", "bad.xml")
        code, _, err = self.run_main(good, bad)
        self.assertEqual(code, 1)
        self.assertIn("bad.xml", err)
        self.assertNotIn("good.xml", err)

    def test_the_application_must_name_both_launcher_icons(self):
        for application in (
            "<application/>",
            '<application android:icon="@mipmap/ic_launcher"/>',
            '<application android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/other"/>',
            '<application icon="@mipmap/ic_launcher" roundIcon="@mipmap/ic_launcher_round"/>',
        ):
            with self.subTest(application=application):
                application = application.replace("/>", f">{app_links()}</application>")
                path = self.manifest(INTERNET, application=application)
                found = self.problems(path)
                self.assertEqual(len(found), 1 if "android:icon" in application else 2)
                self.assertTrue(all("<application> needs android:" in line for line in found))

    def test_a_manifest_without_an_application_fails(self):
        path = self.manifest(INTERNET, application="")
        found = self.problems(path)
        self.assertEqual(len(found), 1)
        self.assertIn("no <application>", found[0])

    def test_an_unreadable_or_foreign_file_fails(self):
        missing = self.dir / "absent.xml"
        broken = self.dir / "broken.xml"
        broken.write_text("<manifest", encoding="utf-8")
        other = self.dir / "other.xml"
        other.write_text("<resources/>", encoding="utf-8")
        for path in (missing, broken, other):
            with self.subTest(path=path.name):
                self.assertEqual(len(self.problems(path)), 1)

    def test_the_app_links_name_exactly_the_web_apps_hosts_and_both_paths(self):
        cases = {
            "no verified filter": (app_links(verify=""), ["no <intent-filter"]),
            "an http scheme too": (
                app_links(DATA + '<data android:scheme="http"/>'),
                ["schemes are ['http', 'https']"],
            ),
            "the earlier host missing": (
                app_links(DATA.replace("old.example.org", "app.example.pk")),
                ["lacks the web app's host old.example.org"],
            ),
            "a host the file does not list": (
                app_links(DATA + '<data android:host="typo.example.pk"/>'),
                ["names typo.example.pk, which contracts/origins.json does not list"],
            ),
            "no invitation path": (
                app_links(DATA.replace('<data android:path="/invite"/>', "")),
                ['lacks android:path="/invite"'],
            ),
            "the callback as an exact path": (
                app_links(DATA.replace("pathPrefix", "path")),
                ['lacks android:pathPrefix="/auth/callback"'],
            ),
        }
        for name, (activity, expected) in cases.items():
            with self.subTest(name):
                path = self.manifest(
                    INTERNET, application=f"<application {ICONS}>{activity}</application>"
                )
                found = self.problems(path)
                self.assertEqual(len(found), len(expected), found)
                for fragment, line in zip(expected, found, strict=True):
                    self.assertIn(fragment, line)

    def test_an_unreadable_origins_file_fails(self):
        err = io.StringIO()
        with (
            redirect_stderr(err),
            unittest.mock.patch.object(check_manifest, "ORIGINS", self.dir / "absent.json"),
        ):
            self.assertEqual(check_manifest.main([]), 1)
        self.assertIn("cannot read the web app's hosts", err.getvalue())

    def test_the_hosts_come_from_contracts_origins_json(self):
        origins = json.loads(check_manifest.ORIGINS.read_text(encoding="utf-8"))["app"]
        expected = {url.removeprefix("https://") for url in [origins["origin"], *origins["legacy"]]}
        self.assertEqual(check_manifest.app_link_hosts(), expected)
        for bad in ("http://a.example", "https://a.example/path", "https://a.example:8443"):
            with self.subTest(bad):
                file = self.dir / "origins.json"
                file.write_text(json.dumps({"app": {"origin": bad}}), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "is not an https origin"):
                    check_manifest.app_link_hosts(file)


if __name__ == "__main__":
    unittest.main()
