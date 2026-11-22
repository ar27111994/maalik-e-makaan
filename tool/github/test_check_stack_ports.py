"""Tests of check_stack_ports.py (make test-tools).

Most tests apply a small mutant to copies of the repository's own workflows and
supabase/config.toml, and require the check to name it: the reservation removed from each job
that starts the stack, moved after the start or anywhere after the job's first step, narrowed so
a port of config.toml falls outside it, a new job that starts the stack without it (in any of
the spellings StartsStackTest lists), a port added to config.toml outside it, and, where the
reservation may fail, a start whose `if:` lets it run all the same (ConditionTest lists them).
StepKeysTest covers a reservation in the background, inside a `parallel:` group or written
twice, a start inside a group, and an id, a condition or a boolean that is not what it looks like.
"""

from __future__ import annotations

import io
import json
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
GUARD = "steps.reserve.outcome == 'success'"
BACKUP_IF = f"if: env.CHAIN_MATCHES == 'true' && {GUARD}"
# Conditions under which a step runs only when the reservation succeeded, with their terms.
WAITS = [
    (GUARD, [GUARD]),
    (f"env.CHAIN_MATCHES == 'true' && {GUARD}", ["env.CHAIN_MATCHES == 'true'", GUARD]),
    (f"{GUARD} && env.CHAIN_MATCHES == 'true'", [GUARD, "env.CHAIN_MATCHES == 'true'"]),
    (f"${{{{ always() && {GUARD} }}}}", ["always()", GUARD]),
    ("  !cancelled()  &&\n  steps.reserve.outcome  ==  'success'\n", ["!cancelled()", GUARD]),
    # An || or && inside brackets or a string belongs to its term.
    (f"(env.A == '1' || env.B == '2') && {GUARD}", ["(env.A == '1' || env.B == '2')", GUARD]),
    (f"contains(fromJSON('[1]')[0] && 'x', 'x') && {GUARD}", None),
    (f"env.A == 'a || b && c' && {GUARD}", ["env.A == 'a || b && c'", GUARD]),
    (f"env.A == 'it''s (' && {GUARD}", ["env.A == 'it''s ('", GUARD]),
    # GitHub ends an expression at the first }} outside a string, so one inside is the term's.
    (f"${{{{ env.A == '}}}}' && {GUARD} }}}}", ["env.A == '}}'", GUARD]),
    (f"env.A == '{{0}}' && {GUARD}\n", ["env.A == '{0}'", GUARD]),
    (f"{GUARD} && false", [GUARD, "false"]),
]
# Conditions the check refuses, each with why: they let the step run after a failed reservation,
# or they are not `&&`-joined terms with the guard, as it is spelt, among them.
REFUSED = [
    ("env.CHAIN_MATCHES == 'true'", "the term is missing"),
    (f"{GUARD} || always()", "|| lets it run without the term"),
    (f"always() || {GUARD}", "|| lets it run without the term"),
    (f"env.A == '1' && {GUARD} || env.B == '2'", "&& binds tighter than ||"),
    (f"!(always() && {GUARD} && true)", "the term is inside brackets, negated"),
    (f"({GUARD})", "the term is inside brackets"),
    (f"({GUARD} && always()) == false", "the term is inside brackets"),
    (f"contains('x', 'x' && {GUARD} && 'x') || true", "the term is a function's argument"),
    (f"fromJSON('[true]')[0 && {GUARD} && 0]", "the term is inside an index"),
    (f"!{GUARD}", "not the term: ! binds before ==, so this is never true"),
    ("steps.reserve.outcome=='success'", "not the term as it is spelt"),
    ("steps.reserve.outcome\u00a0== 'success'", "a no-break space is not the term's space"),
    (f"{GUARD} == false", "the term is compared"),
    ("steps.reserve.outcome != 'success'", "another comparison"),
    ("steps.reserve.outcome == 'failure'", "another outcome"),
    ("steps.reserve.conclusion == 'success'", "continue-on-error makes every conclusion success"),
    ("steps.reserved.outcome == 'success'", "another step's id"),
    (f"env.A == '{GUARD.replace(chr(39), chr(39) * 2)}'", "a string of other text"),
    (f"env.A == 'x && {GUARD} && x'", "the term is inside a string"),
    (
        f"${{{{ env.CHAIN_MATCHES == 'true' }}}} && ${{{{ {GUARD} }}}}",
        "text around expressions is always true",
    ),
    (f"${{{{ {GUARD} }}}} && true", "text around an expression is always true"),
    (f"true && ${{{{ {GUARD} }}}}", "text around an expression is always true"),
    (f"${{{{ {GUARD} }}}} ${{{{ {GUARD} }}}}", "two expressions are text"),
    (f"{GUARD} }}}}", "a stray }}"),
    # Anything before ${{ or after its }} makes the whole a text (TemplateReader.ParseScalar).
    (
        f"${{{{ env.CHAIN_MATCHES == 'true' && {GUARD} }}}}\n",
        "the newline a | or > block ends with",
    ),
    (f" ${{{{ {GUARD} }}}}", "a space before ${{"),
    (f"${{{{ {GUARD} }}}} ", "a space after }}"),
    (f"\u00a0${{{{ {GUARD} }}}}", "a no-break space before ${{"),
    (f"${{{{ {GUARD} && env.A == '1' }}}}}}", "a third } is text after the expression"),
    (f"${{{{ env.A == '${{{{' && {GUARD} }}}}", "a second ${{, though in a string"),
    (f"env.A == {{0}} && {GUARD}", "a brace outside a string"),
    (f"env.A == 'x && {GUARD}", "a string left open"),
    (f"(always() && {GUARD}", "a bracket left open"),
    (f"always()) && {GUARD} && (true", "a bracket closed before it opens"),
    (f"always() & {GUARD}", "one & is not &&"),
    ("", "no if: at all"),
]
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
        # Without the reservations, exactly the three jobs are reported, each once.
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

    def test_the_step_moved_later_but_before_the_start(self):
        # Steps that connect out (setup-cli, flutter-action, setup-node) would then run before
        # it, and a reservation does not free a port a socket already holds.
        for path, job, start in STARTS:
            for where in ("after setup-cli", "to just before the start"):
                with self.subTest(job=job, where=where):
                    self.setUp()
                    text = self.text(path)
                    a, b = step_span(text, job, csp.NAME)
                    step = text[a:b].rstrip("\n") + "\n"
                    text = text[:a] + text[b:]
                    if where == "after setup-cli":
                        first, last = job_span(text, job)
                        if "supabase/setup-cli@" not in text[first:last]:
                            continue  # the backup job installs the CLI by its own step
                        at = text.index("supabase/setup-cli@", first, last)
                        at = text.index("\n      - ", at) + 1
                    else:
                        at = step_span(text, job, start)[0]
                    self.write(path, text[:at] + step + text[at:])
                    text = self.text(path)
                    line = text[: step_span(text, job, csp.NAME)[0]].count("\n") + 1
                    (found,) = self.assert_problems(f'job {job!r}: "{csp.NAME}" is step ')
                    self.assertTrue(found.startswith(f"{path}:{line}: "), found)
                    self.assertTrue(found.endswith(f"; make it the job's first ({csp.WHY})"), found)

    def test_a_job_that_runs_make_test_uat_without_it(self):
        # tool/uat/run.sh starts the stack itself when it is not running.
        text = self.text(CI)
        a, b = step_span(text, "uat", csp.NAME)
        c, d = step_span(text[:a] + text[b:], "uat", "Start the stack")
        text = text[:a] + text[b:]
        self.write(CI, text[:c] + text[d:])
        self.assert_problems("job 'uat' starts the local stack with no")

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
        # Two in the uat job: its supabase start and its make test-uat.
        self.assert_problems(
            *[f'"{csp.NAME}" has continue-on-error, but the start it guards (line'] * 3
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
        self.replace(BACKUP, BACKUP_IF, "if: env.CHAIN_MATCHES == 'true'")
        self.assert_problems(
            f'this start can run when "{csp.NAME}" failed (it has continue-on-error): give that'
            f' step an id and make "{GUARD}", spelt so, one of the &&-joined terms of this'
            " step's if:, with no || outside brackets and nothing before or after a ${{ }}"
            " around it"
        )
        self.setUp()
        self.replace(BACKUP, "        id: reserve\n", "")
        self.assert_problems("give that step an id")
        self.setUp()
        text = self.text(BACKUP)
        a, b = step_span(text, "backup", "Start a local stack from the applied chain")
        self.write(BACKUP, text[:a] + text[a:b].replace(f"        {BACKUP_IF}\n", "") + text[b:])
        self.assert_problems("this start can run when")

    def test_the_backup_start_must_wait_on_every_path(self):
        for condition, why in REFUSED[1:-1]:
            with self.subTest(condition, why=why):
                self.setUp()
                self.replace(BACKUP, BACKUP_IF, f"if: {json.dumps(condition)}")
                self.assert_problems("this start can run when")

    def test_the_backup_start_may_wait_in_other_words(self):
        for condition, _ in WAITS:
            with self.subTest(condition):
                self.setUp()
                self.replace(BACKUP, BACKUP_IF, f"if: {json.dumps(condition)}")
                self.assert_problems()

    def test_an_expression_in_a_block_is_text(self):
        """`|` and `>` keep the line's newline, which GitHub reads as text after the `}}`."""
        expression = "${{ " + BACKUP_IF.removeprefix("if: ") + " }}"
        for style, refused in (("|", True), (">", True), ("|-", False), (">-", False)):
            with self.subTest(style):
                self.setUp()
                self.replace(BACKUP, BACKUP_IF, f"if: {style}\n          {expression}")
                self.assert_problems(*["this start can run when"] * refused)
        self.setUp()
        self.replace(BACKUP, BACKUP_IF, f"if: {expression}")
        self.assert_problems()
        # Without ${{ }} the whole block is one expression, and its newline is only a space.
        self.setUp()
        self.replace(BACKUP, BACKUP_IF, "if: |\n          " + BACKUP_IF.removeprefix("if: "))
        self.assert_problems()

    def test_a_continue_on_error_the_check_cannot_read(self):
        text = self.text(BACKUP)
        a, b = step_span(text, "backup", csp.NAME)
        reserve = text[a:b]
        self.assertEqual(reserve.count("        continue-on-error: true\n"), 1)
        for value in ("${{ true }}", "${{ fromJSON('true') }}", '"true"', "yes", "1"):
            with self.subTest(reserve=value):
                self.setUp()
                self.write(
                    BACKUP,
                    text[:a]
                    + reserve.replace("continue-on-error: true", f"continue-on-error: {value}")
                    + text[b:],
                )
                self.assert_problems(f'"{csp.NAME}": write continue-on-error as a plain true')
        a, b = step_span(text, "backup", "Start a local stack from the applied chain")
        start = text[a:b]
        self.assertEqual(start.count("        continue-on-error: true\n"), 1)
        for value in ("${{ true }}", '"true"'):
            with self.subTest(start=value):
                self.setUp()
                self.write(
                    BACKUP,
                    text[:a]
                    + start.replace("continue-on-error: true", f"continue-on-error: {value}")
                    + text[b:],
                )
                self.assert_problems("write this start's continue-on-error as a plain true")
        # Where the reservation must not fail, an expression is no plainer.
        self.setUp()
        self.replace(
            CI, NAME_LINE, NAME_LINE + "        continue-on-error: ${{ false }}\n", count=2
        )
        self.assert_problems(*[f'"{csp.NAME}": write continue-on-error as a plain true'] * 2)
        self.setUp()
        self.replace(CI, NAME_LINE, NAME_LINE + "        continue-on-error: false\n", count=2)
        self.assert_problems()


class StepKeysTest(Repo):
    """The reservation's and the guarded start's keys, read as GitHub reads them."""

    def backup_step(self, name: str) -> tuple[str, str, str]:
        text = self.text(BACKUP)
        a, b = step_span(text, "backup", name)
        return text[:a], text[a:b], text[b:]

    def test_a_reservation_in_the_background_is_refused(self):
        for value in ("true", "false", "${{ true }}"):
            with self.subTest(value):
                self.setUp()
                self.replace(CI, NAME_LINE, NAME_LINE + f"        background: {value}\n", count=2)
                self.assert_problems(*[f'"{csp.NAME}" has background:'] * 2)

    def test_a_reservation_inside_a_parallel_group_is_refused(self):
        text = self.text(CI)
        a, b = step_span(text, "supabase-stack", csp.NAME)
        grouped = "      - parallel:\n" + textwrap.indent(text[a:b], "    ")
        self.write(CI, text[:a] + grouped + text[b:])
        self.assert_problems(
            f'"{csp.NAME}" is inside a parallel: group',
            f"job 'supabase-stack' starts the local stack with no \"{csp.NAME}\" step before it;",
        )

    def test_a_start_inside_a_parallel_group_is_found(self):
        for workflow, job, name in STARTS:
            with self.subTest(job=job):
                self.setUp()
                text = self.text(workflow)
                a, b = step_span(text, job, name)
                grouped = "      - parallel:\n" + textwrap.indent(text[a:b], "    ")
                # With the reservation first, the grouped start is as good as any other.
                self.write(workflow, text[:a] + grouped + text[b:])
                self.assert_problems()
                # Without it, the grouped start is the one named.
                c, d = step_span(text[:a] + grouped + text[b:], job, csp.NAME)
                moved = text[:a] + grouped + text[b:]
                self.write(workflow, moved[:c] + moved[d:])
                found = self.problems()
                self.assertIn(f"job {job!r} starts the local stack with no", found[0])

    def test_a_grouped_start_must_wait_for_a_reservation_that_may_fail(self):
        before, start, after = self.backup_step("Start a local stack from the applied chain")
        grouped = "      - parallel:\n" + textwrap.indent(start, "    ")
        self.write(BACKUP, before + grouped.replace(f"            {BACKUP_IF}\n", "") + after)
        self.assert_problems("this start can run when")

    def test_a_second_reservation_is_refused(self):
        before, reserve, after = self.backup_step(csp.NAME)
        self.assertEqual(reserve.count("        id: reserve\n"), 1)
        # The first cannot fail, so no guard would be asked for the second, which can.
        first = reserve.replace("        id: reserve\n", "        id: first\n").replace(
            "        continue-on-error: true\n", ""
        )
        self.write(BACKUP, before + first + reserve + after)
        self.assert_problems(f"job 'backup' has \"{csp.NAME}\" 2 times; keep the first")

    def test_the_reservation_needs_an_id_github_takes(self):
        for value in ('""', "", "~", "1", "true", "a.b", "a b", "'a'' || ''b'", "!!null reserve"):
            with self.subTest(value):
                self.setUp()
                self.replace(
                    BACKUP, "        id: reserve\n", f"        id: {value}\n".replace(" \n", "\n")
                )
                self.assert_problems("give that step an id")
        # Another step named `reserve` does not stand in for a reservation with no id.
        self.setUp()
        self.replace(BACKUP, "        id: reserve\n", "        id:\n")
        text = self.text(BACKUP)
        a, _ = step_span(text, "backup", "Start a local stack from the applied chain")
        self.write(BACKUP, text[:a] + '      - id: reserve\n        run: "true"\n' + text[a:])
        self.assert_problems("give that step an id")
        self.setUp()
        self.replace(BACKUP, "        id: reserve\n", "        id: port_reservation-1\n")
        self.replace(
            BACKUP, BACKUP_IF, BACKUP_IF.replace("steps.reserve.", "steps.port_reservation-1.")
        )
        self.assert_problems()

    def test_a_tagged_condition_is_not_its_text(self):
        for tag in ("!!null", "!!bool", "!!int"):
            with self.subTest(tag):
                self.setUp()
                self.replace(
                    BACKUP, BACKUP_IF, f"if: {tag} {json.dumps(BACKUP_IF.removeprefix('if: '))}"
                )
                self.assert_problems("this start can run when")

    def test_a_tagged_boolean_is_not_a_plain_one(self):
        before, reserve, after = self.backup_step(csp.NAME)
        for value in ("!!bool yes", "!!bool 1", "!!bool on"):
            with self.subTest(value):
                self.setUp()
                self.write(
                    BACKUP,
                    before
                    + reserve.replace("continue-on-error: true", f"continue-on-error: {value}")
                    + after,
                )
                self.assert_problems(f'"{csp.NAME}": write continue-on-error as a plain true')
        # The check reads each as true, so the guard is still asked for: the backup's start has
        # it, and without it each is refused. (GitHub's runner refuses the quoted, tagged one.)
        for value in ("True", "TRUE", "true # as the restore check may fail", '!!bool "true"'):
            with self.subTest(value):
                self.setUp()
                self.write(
                    BACKUP,
                    before
                    + reserve.replace("continue-on-error: true", f"continue-on-error: {value}")
                    + after,
                )
                self.assert_problems()
                self.replace(BACKUP, BACKUP_IF, "if: env.CHAIN_MATCHES == 'true'")
                self.assert_problems("this start can run when")

    def test_groups_inside_groups_and_groups_that_are_not_lists(self):
        text = self.text(CI)
        a, b = step_span(text, "supabase-stack", "Start the stack")
        start = text[a:b]
        nested = "      - parallel:\n          - parallel:\n" + textwrap.indent(start, "        ")
        self.write(CI, text[:a] + nested + text[b:])
        self.assert_problems()
        c, d = step_span(text, "supabase-stack", csp.NAME)
        self.write(CI, text[:c] + text[d:a] + nested + text[b:])
        self.assert_problems("job 'supabase-stack' starts the local stack with no")
        # GitHub's schema takes only a list there, so anything else is a step like any other.
        for value in ("{}", "supabase start", "~"):
            with self.subTest(value):
                self.setUp()
                self.write(CI, text[:a] + f"      - parallel: {value}\n" + start + text[b:])
                self.assert_problems()

    def test_a_group_that_holds_itself_is_read_once(self):
        text = self.text(CI)
        a, _ = step_span(text, "supabase-stack", "Start the stack")
        for group in (
            "      - &again\n        parallel: [*again]\n",
            "      - parallel: &again\n          - parallel: *again\n",
        ):
            with self.subTest(group):
                self.setUp()
                self.write(CI, text[:a] + group + text[a:])
                self.assert_problems()

    def test_a_file_nested_too_deeply_to_read_is_reported(self):
        self.write(".github/workflows/deep.yml", "jobs: " + "[" * 5000 + "]" * 5000 + "\n")
        self.assert_problems(".github/workflows/deep.yml:1: cannot read it")

    def test_the_reservation_runs_under_bash(self):
        for shell in ("sh", "true {0}", "python", "pwsh", "${{ matrix.shell }}", "1"):
            with self.subTest(step=shell):
                self.setUp()
                self.replace(CI, NAME_LINE, NAME_LINE + f"        shell: {shell}\n", count=2)
                self.assert_problems(*[f'"{csp.NAME}" would run under shell'] * 2)
        self.setUp()
        self.replace(CI, NAME_LINE, NAME_LINE + "        shell: bash\n", count=2)
        self.assert_problems()
        # The workflow's default, and a job's, which comes before it.
        defaults = "defaults:\n  run:\n    shell: bash\n"
        for workflow, count in ((CI, 2), (BACKUP, 1)):
            with self.subTest(workflow=workflow):
                self.setUp()
                self.replace(workflow, defaults, defaults.replace("bash", "sh"))
                self.assert_problems(*[f"\"{csp.NAME}\" would run under shell 'sh'"] * count)
                self.setUp()
                self.replace(workflow, defaults, "")
                self.assert_problems()
        self.setUp()
        text = self.text(CI)
        a, _ = job_span(text, "uat")
        head = text[a:].split("\n", 1)[0] + "\n"
        self.write(
            CI,
            text[:a]
            + head
            + "    defaults:\n      run:\n        shell: sh\n"
            + text[a + len(head) :],
        )
        self.assert_problems(f"\"{csp.NAME}\" would run under shell 'sh'")
        # A step's own shell comes before both.
        self.replace(CI, NAME_LINE, NAME_LINE + "        shell: bash\n", count=2)
        self.assert_problems()


class ConditionTest(unittest.TestCase):
    def test_the_backup_condition_is_the_one_tested(self):
        text = (ROOT / BACKUP).read_text(encoding="utf-8")
        a, b = step_span(text, "backup", "Start a local stack from the applied chain")
        self.assertEqual(text[a:b].count(f"        {BACKUP_IF}\n"), 1)
        self.assertEqual(WAITS[1][0], BACKUP_IF.removeprefix("if: "))

    def test_conditions_that_wait_for_the_reservation(self):
        for condition, _ in WAITS:
            with self.subTest(condition):
                self.assertTrue(csp.waits_for(condition, GUARD))

    def test_conditions_that_do_not(self):
        for condition, why in REFUSED:
            with self.subTest(condition, why=why):
                self.assertFalse(csp.waits_for(condition, GUARD))

    def test_terms(self):
        for condition, expected in WAITS:
            if expected is not None:
                with self.subTest(condition):
                    self.assertEqual(csp.terms(condition), expected)
        self.assertEqual(
            csp.terms(WAITS[6][0]), ["contains(fromJSON('[1]')[0] && 'x', 'x')", GUARD]
        )
        self.assertEqual(csp.terms(""), [""])
        self.assertEqual(csp.terms("${{ }}"), [""])
        self.assertEqual(csp.terms("a&&b"), ["a", "b"])
        self.assertEqual(csp.terms("a && b &&"), ["a", "b", ""])
        self.assertEqual(
            csp.terms("(a || (b && c)) && d[e || f]"), ["(a || (b && c))", "d[e || f]"]
        )
        self.assertEqual(csp.terms("${{a}}"), ["a"])
        self.assertEqual(csp.terms(" a \t&&\r\n b "), ["a", "b"])
        self.assertEqual(csp.terms("a\u00a0&& b"), ["a\u00a0", "b"])
        self.assertEqual(csp.terms("${{ a == '}}' }}"), ["a == '}}'"])

    def test_what_is_not_only_terms(self):
        for condition in (
            "a || b",
            "a && b || c",
            "(a) || (b)",
            "a)",
            "(a",
            "a]",
            "[a",
            "a && (b",
            "'a",
            "a == 'b''",
            "${{ a }} && b",
            "a && ${{ b }}",
            "${{ a }} ${{ b }}",
            "${{ a",
            "a }}",
            "${{ ${{ a }} }}",
            "${{ a }}\n",
            " ${{ a }}",
            "${{ a }}}",
            "a && {b}",
            "a == '${{'",
        ):
            with self.subTest(condition):
                self.assertIsNone(csp.terms(condition))


class StartsStackTest(unittest.TestCase):
    def test_commands_that_start_the_stack(self):
        for run in (
            "supabase start",
            "supabase start -x studio",
            "cd x && supabase db start\n",
            "echo\n  supabase   start\n",
            "supabase --workdir . start",
            'supabase --workdir "$WORKDIR" start -x studio',
            "supabase --debug --workdir=. db start",
            "supabase db --workdir . start",
            "npx supabase start",
            "npx supabase@2.122.1 start -x studio",
            "pnpm dlx supabase@latest --workdir . db start",
            "npx supabase@^2 start",
            "npx supabase@~2.1 start",
            "npx supabase@* start",
            "npx supabase@2.1.0+build start",
            "npx 'supabase@>=2' start",
            "npm exec supabase -- start",
            '"supabase" start',
            "supabase 'start' -x studio",
            'sup"a"base --workdir "$WORKDIR" "start"',
            "supabase st\\\nart",
            '"make" test-uat',
            "supabase \\\n  start -x studio",
            "supabase \\\n  --workdir . \\\n  db start",
            "make test-uat",
            "UAT_RESET=1 make -C . test-uat",
            "tool/uat/run.sh",
            "bash ./tool/uat/run.sh",
        ):
            self.assertTrue(csp.starts_stack(run), run)

    def test_commands_that_do_not(self):
        for run in (
            "supabase stop --no-backup",
            "supabase status",
            "# supabase start is in the step above",
            "supabase db reset --local",
            "supabase starter",
            "supabase status --output start",
            "supabase --workdir ./start status",
            "make test-uat-report",
            "make test-functions-e2e",
            "# make test-uat",
            "cat tool/uat/run.shx",
            "supabase stop \\\n  # start",
            "supabase@2 status",
            "supabase -- status",
            "supabase --\\\nstart",
            "supabase\\\nstart",
        ):
            self.assertFalse(csp.starts_stack(run), run)

    def test_a_long_line_is_quick(self):
        # The pattern has no nested ambiguity: from one `supabase`, a long run of options that
        # does not end in `start` fails without backtracking, with a version after the name too.
        # (A line that repeats `supabase` thousands of times is searched from each of them.)
        for name in ("supabase", "supabase@^2.1"):
            run = name + " --flag value" * 5000 + " status"
            self.assertFalse(csp.starts_stack(run))

    def test_the_uat_runner_still_starts_the_stack(self):
        # csp.UAT_STARTS treats make test-uat and tool/uat/run.sh as starts: keep that true.
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        recipe = makefile.split("\ntest-uat:", 1)[1].split("\n\n", 1)[0]
        self.assertIn("\ttool/uat/run.sh", recipe)
        script = (ROOT / "tool/uat/run.sh").read_text(encoding="utf-8")
        self.assertIn('SUPABASE=(supabase --workdir "$WORKDIR")', script)
        self.assertIn('"${SUPABASE[@]}" start -x', script)

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
        self.assertIn("(54320, 54321, 54322, 54323, 54324; 10 workflow file(s))", out)

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
