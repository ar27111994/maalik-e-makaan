"""Tests of check_stack_ports.py (make test-tools).

Most tests apply a small mutant to copies of the repository's own workflows and
supabase/config.toml, and require the check to name it: the reservation removed from each job
that starts the stack, moved after the start, narrowed so a port of config.toml falls outside
it, a new job that starts the stack without it, and a port added to config.toml outside it.
"""

from __future__ import annotations

import io
import shutil
import sys
import tempfile
import textwrap
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_stack_ports as csp

ROOT = csp.ROOT
CI = ".github/workflows/ci.yml"
BACKUP = ".github/workflows/backup.yml"
NAME_LINE = f"      - name: {csp.NAME}\n"
# The jobs that start the stack today, as (workflow, job, the start step's name).
STARTS = [
    (CI, "supabase-stack", "Start the stack"),
    (CI, "uat", "Start the stack"),
    (BACKUP, "backup", "Start a local stack from the applied chain"),
]


def job_span(text: str, job: str) -> tuple[int, int]:
    """The character span of a job (a two-space key under `jobs:`) in a workflow's text."""
    start = text.index(f"\n  {job}:\n") + 1
    following = [text.find(f"\n  {key}", start + 1) for key in "abcdefghijklmnopqrstuvwxyz"]
    end = min([i + 1 for i in following if i != -1] + [len(text)])
    return start, end


def step_span(text: str, job: str, name: str) -> tuple[int, int]:
    """The character span of the job's step with that name: its lines indented under its `- `,
    up to the next step, a blank line or a comment between steps."""
    first, last = job_span(text, job)
    start = text.index(f"      - name: {name}\n", first, last)
    end = text.index("\n", start) + 1
    while end < last and text.startswith("        ", end):
        end = text.index("\n", end) + 1
    return start, end


class Repo(unittest.TestCase):
    """A copy of the repository's workflows and supabase/config.toml."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / csp.WORKFLOWS, self.root / csp.WORKFLOWS)
        (self.root / "supabase").mkdir()
        shutil.copy(ROOT / csp.CONFIG, self.root / csp.CONFIG)

    def text(self, path: str) -> str:
        return (self.root / path).read_text(encoding="utf-8")

    def write(self, path: str, text: str) -> None:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def replace(self, path: str, old: str, new: str, count: int = 1) -> None:
        text = self.text(path)
        self.assertEqual(text.count(old), count, old)
        self.write(path, text.replace(old, new))

    def problems(self) -> list[str]:
        return [str(p) for p in csp.Checker(self.root).problems(csp.workflow_files(self.root))]

    def assert_problems(self, *fragments: str) -> list[str]:
        found = self.problems()
        self.assertEqual(len(found), len(fragments), found)
        for fragment, problem in zip(fragments, found, strict=True):
            self.assertIn(fragment, problem)
        return found


class TheRepositoryTest(Repo):
    def test_the_repository_passes(self):
        self.assertEqual(self.problems(), [])

    def test_the_spans_this_file_cuts_are_the_steps(self):
        for path, job, start in STARTS:
            text = self.text(path)
            for name in (csp.NAME, start):
                a, b = step_span(text, job, name)
                self.assertTrue(text[a:b].startswith(f"      - name: {name}\n"))
                self.assertIn("run: ", text[a:b])

    def test_each_job_that_starts_the_stack_is_found(self):
        # Without the reservations, exactly the three starts are reported.
        for path in (CI, BACKUP):
            text = self.text(path)
            for _, job, _ in [s for s in STARTS if s[0] == path]:
                a, b = step_span(text, job, csp.NAME)
                text = text[:a] + text[b:]
            self.write(path, text)
        found = self.problems()
        self.assertEqual(
            [p.split(": ", 1)[1].split(" starts")[0] for p in found],
            ["job 'backup'", "job 'supabase-stack'", "job 'uat'"],
        )

    def test_the_config_ports_in_the_automatic_range(self):
        ports = {p.where: p.number for p in csp.Checker(self.root).ports}
        self.assertEqual(
            ports,
            {
                "api.port": 54321,
                "db.port": 54322,
                "db.shadow_port": 54320,
                "studio.port": 54323,
                "local_smtp.port": 54324,
            },
        )


class MutantsTest(Repo):
    def test_the_step_removed_from_each_job(self):
        for path, job, start in STARTS:
            with self.subTest(job=job):
                self.setUp()
                text = self.text(path)
                a, b = step_span(text, job, csp.NAME)
                self.write(path, text[:a] + text[b:])
                (found,) = self.assert_problems(
                    f'job {job!r} starts the local stack with no "{csp.NAME}" step before it;'
                    " make that step the job's first"
                )
                text = self.text(path)
                line = text[: step_span(text, job, start)[0]].count("\n") + 1
                self.assertTrue(found.startswith(f"{path}:{line}: "), found)

    def test_the_step_moved_after_the_start(self):
        for path, job, start in STARTS:
            with self.subTest(job=job):
                self.setUp()
                text = self.text(path)
                a, b = step_span(text, job, csp.NAME)
                step = text[a:b]
                text = text[:a] + text[b:]
                _, end = step_span(text, job, start)
                self.write(path, text[:end] + step + text[end:])
                self.assert_problems(
                    f'no "{csp.NAME}" step before it (the one at line',
                )
                self.assertIn("comes after it); make that step the job's first", self.problems()[0])

    def test_the_range_narrowed(self):
        self.replace(CI, "54320-54329", "54321-54329", count=2)
        self.replace(BACKUP, "54320-54329", "54320-54323")
        text = self.text(BACKUP)
        line = text[: step_span(text, "backup", csp.NAME)[0]].count("\n") + 1
        self.assert_problems(
            f"backup.yml:{line}: the reserved range 54320-54323 leaves out 54324"
            " (supabase/config.toml, local_smtp.port); widen it to cover every port there",
            "the reserved range 54321-54329 leaves out 54320 (supabase/config.toml, db.shadow_port)",
            "the reserved range 54321-54329 leaves out 54320 (supabase/config.toml, db.shadow_port)",
        )

    def test_a_new_job_that_starts_the_stack_without_it(self):
        job = textwrap.indent(
            textwrap.dedent("""\
                stack-again:
                  runs-on: ubuntu-24.04
                  steps:
                    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
                    - name: Start
                      run: |
                        cd supabase && supabase db start
                """),
            "  ",
        )
        self.write(CI, self.text(CI) + job)
        self.assert_problems("job 'stack-again' starts the local stack with no")

    def test_a_port_added_to_config_toml_outside_the_range(self):
        self.replace(csp.CONFIG, "port = 54324\n", "port = 54324\nsmtp_port = 54335\n")
        found = self.assert_problems(*["leaves out 54335"] * 3)
        for problem in found:
            self.assertIn(
                "54320-54329 leaves out 54335 (supabase/config.toml, local_smtp.smtp_port)",
                problem,
            )

    def test_a_port_below_the_automatic_range_needs_no_reservation(self):
        self.replace(csp.CONFIG, "port = 54324\n", "port = 54324\nsmtp_port = 2500\n")
        self.replace(csp.CONFIG, "inspector_port = 8083", "inspector_port = 8084")
        self.assertEqual(self.problems(), [])

    def test_another_spelling_is_refused(self):
        self.replace(
            CI,
            'echo "${reserved:+$reserved,}54320-54329" | sudo tee'
            " /proc/sys/net/ipv4/ip_local_reserved_ports",
            'sudo sysctl -w net.ipv4.ip_local_reserved_ports="${reserved:+$reserved,}54320-54329"',
            count=2,
        )
        self.assert_problems(*[f'"{csp.NAME}" must run exactly: reserved="$(cat'] * 2)

    def test_an_empty_range_is_refused(self):
        self.replace(BACKUP, "54320-54329", "54329-54320")
        found = self.problems()
        self.assertIn("the reserved range 54329-54320 is empty", found[0])
        self.assertEqual(len(found), 6, found)  # and every port is left out

    def test_an_if_on_the_step_is_refused(self):
        self.replace(
            CI,
            NAME_LINE,
            NAME_LINE + "        if: github.event_name == 'push'\n",
            count=2,
        )
        self.assert_problems(*[f'"{csp.NAME}" has an if:, so it can be skipped'] * 2)

    def test_continue_on_error_only_where_the_start_has_it(self):
        self.replace(
            CI,
            NAME_LINE,
            NAME_LINE + "        continue-on-error: true\n",
            count=2,
        )
        self.assert_problems(
            *[f'"{csp.NAME}" has continue-on-error, but the start it guards (line'] * 2
        )

    def test_the_backup_start_must_stay_allowed_to_fail(self):
        text = self.text(BACKUP)
        a, b = step_span(text, "backup", "Start a local stack from the applied chain")
        step = text[a:b]
        self.assertEqual(step.count("        continue-on-error: true\n"), 1)
        self.write(
            BACKUP, text[:a] + step.replace("        continue-on-error: true\n", "") + text[b:]
        )
        self.assert_problems("does not, so a failed reservation would pass in silence")

    def test_the_backup_start_must_wait_for_the_reservation(self):
        self.replace(
            BACKUP,
            "if: env.CHAIN_MATCHES == 'true' && steps.reserve.outcome == 'success'",
            "if: env.CHAIN_MATCHES == 'true'",
        )
        self.assert_problems(
            f'this start runs even when "{csp.NAME}" failed (it has continue-on-error): give'
            " that step an id and add \"steps.reserve.outcome == 'success'\" to this step's if:"
        )
        self.setUp()
        self.replace(BACKUP, "        id: reserve\n", "")
        self.assert_problems("give that step an id")


class StartsStackTest(unittest.TestCase):
    def test_commands_that_start_the_stack(self):
        for run in (
            "supabase start",
            "supabase start -x studio",
            "cd x && supabase db start\n",
            "echo\n  supabase   start\n",
        ):
            self.assertTrue(csp.starts_stack(run), run)

    def test_commands_that_do_not(self):
        for run in (
            "supabase stop --no-backup",
            "supabase status",
            "# supabase start is in the step above",
            "supabase db reset --local",
            "supabase starter",
        ):
            self.assertFalse(csp.starts_stack(run), run)

    def test_config_ports(self):
        config = {
            "port": 1,
            "api": {"port": 2, "ports": 3, "report": 4, "enabled": True},
            "db": {"shadow_port": 5, "pooler": {"port": 6}, "port_name": 7},
            "x": {"smtp_port": True, "pop3_port": "8"},
        }
        self.assertEqual(
            [(p.where, p.number) for p in csp.config_ports(config)],
            [("port", 1), ("api.port", 2), ("db.shadow_port", 5), ("db.pooler.port", 6)],
        )


class MainTest(Repo):
    def run_main(self) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = csp.main([str(self.root)])
        return code, out.getvalue(), err.getvalue()

    def test_a_pass_names_the_ports(self):
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.assertIn("(54320, 54321, 54322, 54323, 54324; 9 workflow file(s))", out)

    def test_the_default_root_is_the_repository(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(csp.main([]), 0)

    def test_a_failure_is_printed_and_fails(self):
        self.replace(CI, "54320-54329", "54322-54329", count=2)
        code, out, err = self.run_main()
        self.assertEqual((code, out), (1, ""))
        self.assertEqual(err.count("leaves out 54320"), 2)
        self.assertEqual(err.count("leaves out 54321"), 2)

    def test_unreadable_files_are_reported(self):
        self.write(".github/workflows/broken.yaml", "jobs: [\n")
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn(".github/workflows/broken.yaml:1: cannot read it", err)
        self.write(csp.CONFIG, "[db\n")
        code, out, err = self.run_main()
        self.assertEqual((code, out), (1, ""))
        self.assertIn("supabase/config.toml:1: cannot read it", err)

    def test_other_files_are_left_alone(self):
        self.write(".github/workflows/notes.md", "run: supabase start\n")
        self.write(".github/workflows/odd.yml", "name: odd\njobs:\n  a:\n    uses: x/y\n")
        self.assertEqual(self.run_main()[0], 0)


if __name__ == "__main__":
    unittest.main()
