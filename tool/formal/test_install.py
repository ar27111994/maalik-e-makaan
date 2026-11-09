"""Tests of tool/formal/install.sh that need no network: its checksum gate."""

import os
import platform
import subprocess
import tempfile
import unittest
from pathlib import Path

INSTALL = Path(__file__).resolve().parent / "install.sh"


def run(*args: str, **env: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(  # noqa: S603 - the repository's own script
        ["bash", str(INSTALL), *args],  # noqa: S607 - bash from PATH
        capture_output=True,
        text=True,
        env={**os.environ, **env},
        check=False,
    )


@unittest.skipUnless(
    platform.system() == "Linux" and platform.machine() == "x86_64",
    "the pinned archives are for Linux x86_64",
)
class InstallTest(unittest.TestCase):
    def test_rejects_a_file_that_does_not_match_its_sha256(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            mirror = Path(tmp, "mirror")
            mirror.mkdir()
            Path(mirror, "tla2tools.jar").write_bytes(b"not the pinned jar")
            cache = Path(tmp, "cache")
            got = run("tla", FORMAL_CACHE=str(cache), FORMAL_MIRROR=str(mirror))
            self.assertEqual(got.returncode, 1, got.stderr)
            self.assertIn("sha256 mismatch for tla2tools.jar", got.stderr)
            self.assertFalse(Path(cache, "tla2tools.jar").exists())
            self.assertFalse(Path(cache, "env.sh").exists())

    def test_reports_a_missing_mirror_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            got = run("bend", FORMAL_CACHE=str(Path(tmp, "cache")), FORMAL_MIRROR=tmp)
            self.assertEqual(got.returncode, 1, got.stderr)
            self.assertIn("FORMAL_MIRROR has no bend-2.0.39-linux-x64.tar.gz", got.stderr)

    def test_refuses_an_unknown_tool(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            got = run("coq", FORMAL_CACHE=tmp)
            self.assertEqual(got.returncode, 2)
            self.assertIn("usage:", got.stderr)


if __name__ == "__main__":
    unittest.main()
