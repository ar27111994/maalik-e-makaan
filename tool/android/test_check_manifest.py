"""Tests of check_manifest.py (make test-tools)."""

import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import check_manifest

HEADER = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
INTERNET = '<uses-permission android:name="android.permission.INTERNET"/>'


class CheckManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, body, name="AndroidManifest.xml"):
        path = self.dir / name
        path.write_text(f"{HEADER}{body}<application/></manifest>", encoding="utf-8")
        return path

    def run_main(self, *paths):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = check_manifest.main([str(path) for path in paths])
        return code, out.getvalue(), err.getvalue()

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
        self.assertEqual(len(check_manifest.problems(path)), 1)

    def test_every_manifest_given_is_checked(self):
        good = self.manifest(INTERNET, "good.xml")
        bad = self.manifest("", "bad.xml")
        code, _, err = self.run_main(good, bad)
        self.assertEqual(code, 1)
        self.assertIn("bad.xml", err)
        self.assertNotIn("good.xml", err)

    def test_an_unreadable_or_foreign_file_fails(self):
        missing = self.dir / "absent.xml"
        broken = self.dir / "broken.xml"
        broken.write_text("<manifest", encoding="utf-8")
        other = self.dir / "other.xml"
        other.write_text("<resources/>", encoding="utf-8")
        for path in (missing, broken, other):
            with self.subTest(path=path.name):
                self.assertEqual(len(check_manifest.problems(path)), 1)


if __name__ == "__main__":
    unittest.main()
