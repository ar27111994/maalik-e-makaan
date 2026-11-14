"""The address and Auth checks end with their own error before GitHub's timeout ends their job.

python3 -m unittest discover -s tool/web -p 'test_*.py'

check_live.py and check_auth_urls.py try a request again on no answer, a 5xx, 408 or 429
(check_live.answer). If a job's timeout-minutes ran out first, GitHub would cancel the job
without the check's ::error:: line that says what to fix. These tests read every workflow under
.github/workflows, find each job that runs a check, and work out the longest the checks of that
job can take: they run each check's main() as the job does (contracts/origins.json and the iOS
Info.plist of this checkout), with every request failing in the slowest way it can, and count
the requests and the pauses. A change to a constant (TRIES, TIMEOUT_SECONDS,
MAX_RETRY_AFTER_SECONDS, PAUSE_SECONDS), to the addresses a check asks for, or to a job's
timeout-minutes that no longer leaves the job time to print its error fails here.

The worst case of one request is TIMEOUT_SECONDS: urllib applies it to the connection and to
each read of the answer, which for these small answers (a status line, a few headers, a body
of a few kilobytes) is a read or two. A server that trickles its answer a byte at a time, or a
DNS resolver that hangs, could take longer; neither is modelled.
"""

from __future__ import annotations

import contextlib
import io
import re
import sys
import unittest
import unittest.mock
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_auth_urls as ca
import check_live as cl

REPO = Path(__file__).resolve().parents[2]
WORKFLOWS = REPO / ".github/workflows"
# The time a job spends before its first check: GitHub's "Set up job" (the runner and the
# actions it downloads), the checkout of the ref, and the shell steps in between (a secret's
# presence, jq on contracts/origins.json). Each takes seconds; two minutes covers them.
SETUP_MARGIN_SECONDS = 120
# The jobs that run a check today, so a workflow this parser misreads fails rather than passes.
EXPECTED = {
    ("release.yml", "preflight"),
    ("deploy.yml", "supabase"),
    ("deploy.yml", "web"),
    ("deploy.yml", "site"),
}
_JOB = re.compile(r"  ([A-Za-z0-9_-]+):\s*$")
_TIMEOUT = re.compile(r"    timeout-minutes:\s*(\d+)\s*$")
_CHECK = re.compile(r"python3 tool/web/(check_live\.py (?:app|site)|check_auth_urls\.py)")
# An answer worth another try, with the longest wait a Retry-After header can ask for.
_BUSY = cl.Answer(429, retry_after="86400")
_REF = "abcdefghijklmnopqrst"


@dataclass
class Job:
    """A workflow job: its timeout-minutes (None when unset) and the checks it runs, in order."""

    timeout_minutes: int | None = None
    checks: list[str] = field(default_factory=list)


def jobs(path: Path) -> dict[str, Job]:
    """The jobs of a workflow file, read line by line: a job is a two-space key under `jobs:`."""
    found: dict[str, Job] = {}
    current: Job | None = None
    in_jobs = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.lstrip().startswith("#"):
            continue
        if not line.startswith(" ") and line.strip():
            in_jobs = line.rstrip() == "jobs:"
            current = None
            continue
        if not in_jobs:
            continue
        if job := _JOB.fullmatch(line):
            current = found.setdefault(job[1], Job())
        elif current is not None:
            if timeout := _TIMEOUT.fullmatch(line):
                current.timeout_minutes = int(timeout[1])
            current.checks += _CHECK.findall(line)
    return found


def run_check(check: str, get: Callable[[str], cl.Answer], sleep: Callable[[float], None]) -> int:
    """Run `check` (as _CHECK reads it from a workflow) the way the job runs it."""
    with contextlib.redirect_stdout(io.StringIO()):
        if check.startswith("check_live.py "):
            return cl.main([check.split()[1]], get, sleep)
        environ = {ca.ACCESS_ENV: "a token"}
        return ca.main(["--project-ref", _REF], environ, get, sleep)


def worst_seconds(check: str) -> float:
    """The longest `check` can take: every request takes TIMEOUT_SECONDS and then gets no answer,
    or an answer worth another try that asks for the longest wait; whichever is slower."""
    timeout = ca.TIMEOUT_SECONDS if check.startswith("check_auth_urls") else cl.TIMEOUT_SECONDS
    slowest = 0.0
    for failure in ("no answer", "busy"):
        requests: list[str] = []
        pauses: list[float] = []

        def get(url: str, failure: str = failure, requests: list[str] = requests) -> cl.Answer:
            requests.append(url)
            if failure == "no answer":
                raise cl.UnreachableError("timed out")
            return _BUSY

        code = run_check(check, get, pauses.append)
        if code == 0:
            raise AssertionError(f"{check} passed with every request failing")
        slowest = max(slowest, len(requests) * timeout + sum(pauses))
    return slowest


def every_job() -> dict[tuple[str, str], Job]:
    return {
        (path.name, name): job
        for path in sorted(WORKFLOWS.glob("*.y*ml"))
        for name, job in jobs(path).items()
        if job.checks
    }


class CheckTimeTest(unittest.TestCase):
    def test_the_workflows_are_read(self):
        found = every_job()
        self.assertLessEqual(EXPECTED, set(found), found)
        self.assertEqual(
            found[("release.yml", "preflight")].checks,
            [
                "check_live.py app",
                "check_auth_urls.py",
            ],
        )
        self.assertEqual(found[("deploy.yml", "site")].checks, ["check_live.py site"])

    def test_every_job_ends_with_the_checks_error_before_its_timeout(self):
        for (workflow, name), job in sorted(every_job().items()):
            with self.subTest(job=f"{workflow} {name}"):
                self.assertIsNotNone(
                    job.timeout_minutes, f"{workflow} {name} runs a check without timeout-minutes"
                )
                checks = sum(worst_seconds(check) for check in job.checks)
                budget = job.timeout_minutes * 60
                self.assertLessEqual(
                    SETUP_MARGIN_SECONDS + checks,
                    budget,
                    f"{workflow} {name}: {SETUP_MARGIN_SECONDS} s of setup and {checks:.0f} s of"
                    f" {', '.join(job.checks)} in the worst case exceed timeout-minutes"
                    f" {job.timeout_minutes} ({budget} s)",
                )

    def test_the_worst_case_counts_every_try_and_pause(self):
        # One address: TRIES requests and TRIES - 1 pauses of the longest wait.
        per_address = cl.TRIES * cl.TIMEOUT_SECONDS + (cl.TRIES - 1) * max(
            cl.MAX_RETRY_AFTER_SECONDS, cl.PAUSE_SECONDS
        )
        self.assertEqual(worst_seconds("check_live.py app"), per_address)
        self.assertEqual(worst_seconds("check_auth_urls.py"), per_address)
        # The site check asks the site's origin, each alias, the web app's App Links file and
        # each earlier address of the web app.
        origins = cl.read_origins()
        addresses = 2 + len(origins.site_aliases) + len(origins.app_legacy)
        self.assertEqual(worst_seconds("check_live.py site"), addresses * per_address)

    def test_the_parser_reads_jobs_timeouts_and_checks(self):
        workflow = REPO / "build" / "never-written.yml"
        text = (
            "name: X\n"
            "on: push\n"
            "jobs:\n"
            "  one:\n"
            "    timeout-minutes: 7\n"
            "    steps:\n"
            "      # run: python3 tool/web/check_live.py site (a comment, not a step)\n"
            "      - run: python3 tool/web/check_live.py app\n"
            "      - run: |\n"
            '          python3 tool/web/check_auth_urls.py --project-ref "$REF"\n'
            "  two:\n"
            "    steps:\n"
            "      - run: python3 tool/web/check_live.py site\n"
            "env:\n"
            "  three: python3 tool/web/check_live.py app\n"
        )
        with unittest.mock.patch.object(Path, "read_text", return_value=text):
            found = jobs(workflow)
        self.assertEqual(
            found,
            {
                "one": Job(7, ["check_live.py app", "check_auth_urls.py"]),
                "two": Job(None, ["check_live.py site"]),
            },
        )


if __name__ == "__main__":
    unittest.main()
