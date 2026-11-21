"""Tests of tool/web/redirect_smoke_test.sh with --page, against tool/web/serve_output.py
(python3 -m unittest discover -s tool/web -p 'test_*.py').

The Deploy workflow runs the script right after `vercel deploy --prod`, while the earlier
address may still answer from the deployment before. These tests switch a local server from
such a package to the new one while the script waits, which no other gate does: CI's own run
of the script meets only the new package.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import package_vercel as pv
import serve_output
from test_package_vercel import APP, OLD_HOSTS, SUPABASE, write_build, write_origins

SCRIPT = Path(__file__).with_name("redirect_smoke_test.sh")
CALLBACK = "/auth/callback?code=smoke-test"
# The route after the filesystem in the deployments from the move's release until step 12's
# (docs/operations.md, Domains), which kept the e-mail links' callback.
KEPT_CALLBACK = "^/(?!auth/callback$).*$"


class Switch:
    """A router for serve_output's handler that answers from one package or another."""

    def __init__(self, router: serve_output.Router) -> None:
        self.router = router

    def resolve(self, raw_path: str, host: str = "localhost") -> serve_output.Response:
        return self.router.resolve(raw_path, host)

    def content_type(self, file: Path) -> str:
        return self.router.content_type(file)


@unittest.skipUnless(shutil.which("bash") and shutil.which("curl"), "needs bash and curl")
class RedirectSmokeTestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        root = Path(cls.tmp.name)
        build = write_build(root)
        origins = write_origins(root, {"origin": APP.origin, "legacy": list(APP.legacy)})
        cls.new = root / "new/.vercel/output"
        pv.package(build, cls.new, SUPABASE, origins)
        # The same package as the deployment before step 12 served it: the callback kept.
        cls.before = root / "before/.vercel/output"
        shutil.copytree(cls.new, cls.before)
        config = json.loads((cls.before / "config.json").read_text(encoding="utf-8"))
        after = [
            route for route in config["routes"] if route.get("src") == "^/.*$" and "has" in route
        ]
        assert len(after) == 1, after
        after[0]["src"] = KEPT_CALLBACK
        (cls.before / "config.json").write_text(json.dumps(config), encoding="utf-8")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def setUp(self):
        self.switch = Switch(serve_output.Router.load(self.before))
        self.server = serve_output.ThreadingHTTPServer(
            ("127.0.0.1", 0), serve_output.handler_for(self.switch)
        )
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.base = "http://{}:{}".format(*self.server.server_address[:2])

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def run_script(self, *args: str, switch_when_waiting: bool = False) -> tuple[int, str]:
        """Runs the script as the earlier address; with `switch_when_waiting`, the server
        starts answering from the new package once the script says it is waiting."""
        lines = []
        command = ["bash", str(SCRIPT), self.base, APP.origin, "--host", OLD_HOSTS[0], *args]
        with subprocess.Popen(  # noqa: S603 (the repository's own script)
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        ) as process:
            # The script's own wait ends after two minutes; it prints a line every five seconds.
            killer = threading.Timer(180, process.kill)
            killer.start()
            try:
                for line in process.stdout or ():
                    lines.append(line)
                    if switch_when_waiting and "waiting for the deployment" in line:
                        self.switch.router = serve_output.Router.load(self.new)
                code = process.wait()
            finally:
                killer.cancel()
        return code, "".join(lines)

    def test_waits_for_a_moved_path_the_deployment_before_still_kept(self):
        # / already answers with the page under the deployment before, so only the callback
        # can tell the two apart: the script must wait for it, then pass on the new package.
        code, output = self.run_script(
            "--page",
            "--moved",
            CALLBACK,
            "--keep",
            "/.well-known/assetlinks.json",
            switch_when_waiting=True,
        )
        self.assertIn(f"{CALLBACK} on {OLD_HOSTS[0]} does not send people on yet", output)
        self.assertEqual(code, 0, output)
        self.assertIn(f"{CALLBACK} on {OLD_HOSTS[0]}: 200, clears its storage", output)

    def test_the_callback_moved_from_kept_to_the_page(self):
        # The flag the workflows passed before step 12 holds for the package before it and
        # fails on the new one, where the callback clears: the workflows had to change with it.
        code, output = self.run_script("--page", "--keep", CALLBACK)
        self.assertEqual(code, 0, output)
        self.switch.router = serve_output.Router.load(self.new)
        code, output = self.run_script("--page", "--keep", CALLBACK)
        self.assertEqual(code, 1, output)
        self.assertIn(f"{CALLBACK} on {OLD_HOSTS[0]} carries Clear-Site-Data", output)
        code, output = self.run_script("--page", "--moved", CALLBACK)
        self.assertEqual(code, 0, output)
        self.assertNotIn("waiting", output)

    def test_moved_needs_page(self):
        code, output = self.run_script("--moved", CALLBACK)
        self.assertEqual(code, 2, output)
        self.assertIn("--moved needs --page", output)


if __name__ == "__main__":
    unittest.main()
