"""Tests of package_unsigned_ipa.sh (make test-tools)."""

import stat
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "package_unsigned_ipa.sh"


def run(*args, cwd):
    return subprocess.run(  # noqa: S603 - the repository's own script
        ["bash", str(SCRIPT), *args],  # noqa: S607 - bash from PATH
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )


class PackageUnsignedIpaTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        app = self.dir / "Runner.app"
        framework = app / "Frameworks" / "Flutter.framework"
        (framework / "Versions" / "A").mkdir(parents=True)
        (app / "Info.plist").write_text("<plist/>", encoding="utf-8")
        binary = app / "Runner"
        binary.write_bytes(b"\xcf\xfa\xed\xfe")
        binary.chmod(0o755)
        (framework / "Versions" / "A" / "Flutter").write_bytes(b"lib")
        (framework / "Flutter").symlink_to("Versions/A/Flutter")

    def tearDown(self):
        self.tmp.cleanup()

    def package(self):
        result = run("Runner.app", "out.ipa", cwd=self.dir)
        self.assertEqual(result.returncode, 0, result.stderr)
        return zipfile.ZipFile(self.dir / "out.ipa")

    def test_the_bundle_sits_inside_payload(self):
        with self.package() as ipa:
            names = ipa.namelist()
        self.assertIn("Payload/Runner.app/Info.plist", names)
        self.assertTrue(all(name.startswith("Payload/") for name in names), names)

    def test_the_executable_keeps_its_permissions(self):
        with self.package() as ipa:
            mode = ipa.getinfo("Payload/Runner.app/Runner").external_attr >> 16
        self.assertTrue(mode & stat.S_IXUSR, oct(mode))

    def test_framework_links_stay_links(self):
        with self.package() as ipa:
            info = ipa.getinfo("Payload/Runner.app/Frameworks/Flutter.framework/Flutter")
            target = ipa.read(info).decode()
        self.assertTrue(stat.S_ISLNK(info.external_attr >> 16))
        self.assertEqual(target, "Versions/A/Flutter")

    def test_an_existing_output_is_replaced(self):
        (self.dir / "out.ipa").write_text("stale", encoding="utf-8")
        with self.package() as ipa:
            self.assertNotIn("stale", ipa.namelist())

    def test_a_directory_without_info_plist_is_refused(self):
        (self.dir / "Empty.app").mkdir()
        result = run("Empty.app", "out.ipa", cwd=self.dir)
        self.assertEqual(result.returncode, 1)
        self.assertIn("is not an app bundle", result.stdout + result.stderr)
        self.assertFalse((self.dir / "out.ipa").exists())

    def test_usage_without_arguments(self):
        result = run(cwd=self.dir)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage", result.stderr)


if __name__ == "__main__":
    unittest.main()
