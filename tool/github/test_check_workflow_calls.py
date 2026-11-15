"""Tests of check_workflow_calls.py, and the canary for actionlint's "$/" support (make test-tools)."""

from __future__ import annotations

import io
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_workflow_calls as cwc

ROOT = cwc.ROOT
GIT = shutil.which("git")
ACTIONLINT_CONFIG = ROOT / ".github/actionlint.yaml"
LINT_REQUIREMENTS = ROOT / "tool/requirements-lint.in"

# The reusable workflow most tests call: one input of each type, and secrets.
CALLED = """\
name: Called
on:
  workflow_call:
    inputs:
      ref:
        type: string
        required: true
      fast:
        type: boolean
        default: false
      count:
        type: number
        required: false
      label:
        type: string
        required: true
        default: main
    secrets:
      TOKEN:
        required: true
      OPTIONAL:
        required: false
  workflow_dispatch:
jobs:
  run:
    runs-on: ubuntu-24.04
    steps:
      - run: echo
"""


def caller(call: str, extra: str = "") -> str:
    """A workflow whose job `call` is the given job body (indented under it)."""
    body = textwrap.indent(textwrap.dedent(call).strip("\n"), "    ")
    return f"name: Caller\non: push\njobs:\n  call:\n{body}\n{extra}"


GOOD_CALL = """\
uses: $/.github/workflows/called.yml
with:
  ref: v1.0.0
secrets:
  TOKEN: ${{ secrets.TOKEN }}
"""


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.write(".github/workflows/called.yml", CALLED)

    def write(self, path: str, text: str) -> str:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return path

    def problems(self, *paths: str) -> list[cwc.Problem]:
        return cwc.Checker(self.root).problems(list(paths))

    def messages(self, call: str) -> list[str]:
        path = self.write(".github/workflows/caller.yml", caller(call))
        return [p.message for p in self.problems(path)]

    def assert_one(self, call: str, fragment: str) -> cwc.Problem:
        path = self.write(".github/workflows/caller.yml", caller(call))
        found = self.problems(path)
        self.assertEqual(len(found), 1, [str(p) for p in found])
        self.assertIn(fragment, found[0].message)
        return found[0]


class RelativeReferencesTest(Fixture):
    def test_a_job_level_call_written_with_dot_slash_is_refused(self):
        problem = self.assert_one(
            "uses: ./.github/workflows/called.yml\nwith:\n  ref: v1\n",
            'write "$/.github/workflows/called.yml"',
        )
        self.assertIn("reusable workflow", problem.message)
        self.assertEqual(problem.line, 5)
        self.assertEqual(str(problem), f"{problem.path}:5: {problem.message}")

    def test_a_step_level_action_written_with_dot_slash_is_refused(self):
        problem = self.assert_one(
            "runs-on: ubuntu-24.04\nsteps:\n  - run: echo\n  - uses: ./.github/actions/setup\n",
            'write "$/.github/actions/setup"',
        )
        self.assertIn("action", problem.message)
        self.assertEqual(problem.line, 8)

    def test_a_dot_slash_step_in_a_composite_action_is_refused(self):
        path = self.write(
            "tools/actions/build/action.yml",
            "name: Build\ndescription: d\nruns:\n  using: composite\n  steps:\n"
            "    - uses: ./tools/actions/other\n    - uses: actions/checkout@0123\n",
        )
        found = self.problems(path)
        self.assertEqual(
            [(p.line, 'write "$/tools/actions/other"' in p.message) for p in found], [(6, True)]
        )

    def test_remote_and_docker_references_are_left_alone(self):
        self.assertEqual(
            self.messages(
                "runs-on: ubuntu-24.04\nsteps:\n  - uses: actions/checkout@0123\n"
                "  - uses: docker://alpine:3\n"
            ),
            [],
        )
        self.assertEqual(self.messages("uses: owner/repo/.github/workflows/x.yml@0123\n"), [])


class SelfReferencesTest(Fixture):
    def test_a_correct_call_passes(self):
        self.assertEqual(self.messages(GOOD_CALL), [])

    def test_a_reference_with_an_at_ref_is_refused(self):
        self.assert_one(
            GOOD_CALL.replace("called.yml", "called.yml@main"),
            'takes none, since it always names the caller\'s own commit: write "$/.github/workflows/called.yml"',
        )
        self.assert_one(
            "runs-on: ubuntu-24.04\nsteps:\n  - uses: $/.github/actions/setup@v1\n", "has an @ref"
        )

    def test_a_step_level_self_reference_is_accepted(self):
        self.assertEqual(
            self.messages("runs-on: ubuntu-24.04\nsteps:\n  - uses: $/.github/actions/setup\n"), []
        )

    def test_the_called_file_must_exist(self):
        self.assert_one(
            GOOD_CALL.replace("called.yml", "missing.yml"),
            "names .github/workflows/missing.yml, which does not exist",
        )

    def test_the_called_file_must_be_a_workflow_directly_in_github_workflows(self):
        self.write(".github/workflows/sub/called.yml", CALLED)
        self.write("ci/called.yml", CALLED)
        self.write(".github/workflows/called.txt", CALLED)
        for target in ("sub/called.yml", "../../ci/called.yml", "called.txt"):
            with self.subTest(target=target):
                self.assert_one(
                    GOOD_CALL.replace("called.yml", target),
                    "is not a workflow file directly in .github/workflows/",
                )

    def test_the_called_file_must_declare_workflow_call(self):
        self.write(".github/workflows/called.yml", CALLED.replace("workflow_call:", "push:", 1))
        self.assert_one(GOOD_CALL, "does not declare on.workflow_call")

    def test_workflow_call_as_a_string_or_in_a_list_counts(self):
        for on in ("on: workflow_call", "on: [push, workflow_call]", "on:\n  - workflow_call"):
            with self.subTest(on=on):
                self.write(".github/workflows/plain.yml", f"name: P\n{on}\njobs: {{}}\n")
                self.assertEqual(self.messages("uses: $/.github/workflows/plain.yml\n"), [])
        self.write(".github/workflows/plain.yml", "name: P\non: [push]\njobs: {}\n")
        self.assertEqual(len(self.messages("uses: $/.github/workflows/plain.yml\n")), 1)

    def test_an_unreadable_called_file_is_reported(self):
        self.write(".github/workflows/called.yml", "on: [unclosed\n")
        self.assert_one(GOOD_CALL, "cannot read .github/workflows/called.yml")

    def test_an_unreadable_caller_is_reported(self):
        path = self.write(".github/workflows/caller.yml", "jobs: {unclosed\n")
        found = self.problems(path)
        self.assertEqual(len(found), 1)
        self.assertIn("cannot read it", found[0].message)


class InputsTest(Fixture):
    def test_an_undeclared_input_is_refused(self):
        problem = self.assert_one(
            GOOD_CALL.replace("  ref: v1.0.0", "  ref: v1.0.0\n  site-only: true"),
            "input 'site-only' is not declared",
        )
        self.assertIn("its inputs: count, fast, label, ref", problem.message)
        self.assertEqual(problem.line, 8)

    def test_a_required_input_without_a_default_must_be_passed(self):
        self.assert_one(
            GOOD_CALL.replace("with:\n  ref: v1.0.0\n", ""),
            "requires the input 'ref', which is not passed",
        )

    def test_a_required_input_with_a_default_and_optional_inputs_may_be_left_out(self):
        # label is required with a default; fast and count are optional.
        self.assertEqual(self.messages(GOOD_CALL), [])

    def test_literal_values_must_have_the_declared_type(self):
        cases = {
            "fast: true": None,
            "fast: False": None,
            "fast: 'true'": "is a boolean, but the value given is a string; write it unquoted",
            "fast: yes": "is a boolean, but the value given is a string",
            "fast: 1": "is a boolean, but the value given is a number",
            "count: 3": None,
            "count: -2.5": None,
            'count: "3"': "is a number, but the value given is a string",
            "count: true": "is a number, but the value given is a boolean",
            "label: next": None,
            "label: '1'": None,
            "label: 1.0": "is a string, but the value given is a number; quote it ('1.0')",
            "label: on": None,
            "label: true": "is a string, but the value given is a boolean; quote it ('true')",
            "label:": "is a string, but the value given is a null",
            "label: [a, b]": "is a string, but the value given is a sequence",
            "fast: ${{ inputs.fast }}": None,
            "count: ${{ fromJSON(vars.COUNT) }}": None,
            "label: release-${{ github.run_id }}": None,
        }
        for entry, fragment in cases.items():
            with self.subTest(entry=entry):
                found = self.messages(GOOD_CALL.replace("  ref: v1.0.0", f"  ref: v1\n  {entry}"))
                if fragment is None:
                    self.assertEqual(found, [])
                else:
                    self.assertEqual(len(found), 1, found)
                    self.assertIn(fragment, found[0])

    def test_an_input_without_a_known_type_takes_any_value(self):
        self.write(
            ".github/workflows/called.yml",
            "on:\n  workflow_call:\n    inputs:\n      free: {}\njobs: {}\n",
        )
        self.assertEqual(
            self.messages("uses: $/.github/workflows/called.yml\nwith:\n  free: 1\n"), []
        )

    def test_a_workflow_with_no_inputs_says_so(self):
        self.write(".github/workflows/plain.yml", "on: workflow_call\njobs: {}\n")
        found = self.messages("uses: $/.github/workflows/plain.yml\nwith:\n  x: 1\n")
        self.assertEqual(len(found), 1)
        self.assertIn("(its inputs: none)", found[0])


class SecretsTest(Fixture):
    def test_an_undeclared_secret_is_refused(self):
        problem = self.assert_one(
            GOOD_CALL + "  OTHER: ${{ secrets.OTHER }}\n", "secret 'OTHER' is not declared"
        )
        self.assertIn("its secrets: OPTIONAL, TOKEN", problem.message)
        self.assertEqual(problem.line, 10)

    def test_a_required_secret_must_be_passed(self):
        self.assert_one(
            GOOD_CALL.replace("  TOKEN: ${{ secrets.TOKEN }}", "  OPTIONAL: x"),
            "requires the secret 'TOKEN', which is not passed",
        )
        self.assert_one(
            GOOD_CALL.replace("secrets:\n  TOKEN: ${{ secrets.TOKEN }}\n", ""),
            "requires the secret 'TOKEN'",
        )

    def test_secrets_inherit_is_accepted(self):
        self.assertEqual(
            self.messages(
                GOOD_CALL.replace("secrets:\n  TOKEN: ${{ secrets.TOKEN }}", "secrets: inherit")
            ),
            [],
        )

    def test_secrets_of_another_shape_are_refused(self):
        self.assert_one(
            GOOD_CALL.replace("secrets:\n  TOKEN: ${{ secrets.TOKEN }}", "secrets: [TOKEN]"),
            'secrets is neither a mapping nor "inherit"',
        )


class YamlTest(unittest.TestCase):
    def test_yaml_1_2_scalars(self):
        document = cwc.compose(
            "a: on\nb: yes\nc: true\nd: 0o17\ne: 2026-11-15\nf: .inf\ng: 1_000\n"
        )
        kinds = {key.value: cwc.kind_of(value) for key, value in cwc.items(document)}
        self.assertEqual(
            kinds,
            {
                "a": "string",
                "b": "string",
                "c": "boolean",
                "d": "number",
                "e": "string",
                "f": "number",
                "g": "string",
            },
        )

    def test_helpers_on_other_shapes(self):
        sequence = cwc.compose("[a, {b: c}]")
        self.assertIsNone(cwc.get(sequence, "a"))
        self.assertEqual(cwc.items(sequence), [])
        self.assertIsNone(cwc.scalar(sequence))
        self.assertEqual(cwc.kind_of(cwc.compose("{}")), "mapping")
        self.assertIsNone(cwc.workflow_call(cwc.compose("name: no events")))


@unittest.skipIf(GIT is None, "git is not installed")
class MainTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        subprocess.run(  # noqa: S603 - fixed arguments, a temporary repository
            [GIT, "init", "-q", str(self.root)], check=True
        )

    def add(self, path: str, text: str) -> None:
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        subprocess.run(  # noqa: S603 - fixed arguments, a temporary repository
            [GIT, "-C", str(self.root), "add", path], check=True
        )

    def run_main(self) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = cwc.main([str(self.root)])
        return code, out.getvalue(), err.getvalue()

    def test_the_repository_passes(self):
        files = cwc.tracked_files(ROOT)
        self.assertIn(".github/workflows/release.yml", files)
        self.assertEqual([str(p) for p in cwc.Checker(ROOT).problems(files)], [])

    def test_main_checks_tracked_workflows_and_actions_only(self):
        self.add(".github/workflows/called.yml", CALLED)
        self.add(".github/workflows/caller.yml", caller(GOOD_CALL))
        self.add("README.md", "uses: ./x\n")
        code, out, err = self.run_main()
        self.assertEqual((code, err), (0, ""))
        self.assertIn("passed (2 file(s))", out)
        self.add("tools/a/action.yml", "runs:\n  using: composite\n  steps:\n    - uses: ./b\n")
        (self.root / ".github/workflows/untracked.yml").write_text(caller("uses: ./c\n"))
        code, out, err = self.run_main()
        self.assertEqual((code, out), (1, ""))
        self.assertEqual(err.count("\n"), 1)
        self.assertIn('tools/a/action.yml:4: the same-repository action "./b"', err)


class ActionlintCanaryTest(unittest.TestCase):
    """The pinned actionlint still refuses "$/", so .github/actionlint.yaml's ignore and
    check_workflow_calls.py are both still needed. When this fails because actionlint accepts
    "$/", do what the failure says."""

    FIXTURE_CALLER = (
        "name: Caller\non: push\npermissions: {}\njobs:\n  call:\n"
        "    uses: $/.github/workflows/called.yml\n    with:\n      undeclared: 1\n"
    )
    REFUSAL = re.compile(
        r'reusable workflow call "\$/\.github/workflows/called\.yml" at "uses" is not following'
        r' the format "owner/repo/path/to/workflow\.yml@ref" nor "\./path/to/workflow\.yml"\.'
        r".*\[workflow-call\]"
    )

    def setUp(self):
        self.actionlint = shutil.which("actionlint")
        if self.actionlint is None:
            self.fail("actionlint is not on PATH: run make bootstrap and use make test-tools")
        pin = re.search(
            r"^actionlint-py==(\d+\.\d+\.\d+)\.\d+$", LINT_REQUIREMENTS.read_text(), re.M
        )
        self.assertIsNotNone(pin, f"{LINT_REQUIREMENTS} does not pin actionlint-py")
        version = subprocess.run(  # noqa: S603 - the pinned actionlint from PATH
            [self.actionlint, "-version"], check=True, capture_output=True, text=True
        ).stdout.split("\n")[0]
        self.assertEqual(version, pin[1], "this is not the pinned actionlint: run make bootstrap")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / ".git").mkdir()
        workflows = self.root / ".github/workflows"
        workflows.mkdir(parents=True)
        (workflows / "called.yml").write_text(
            "name: Called\non:\n  workflow_call:\npermissions: {}\njobs:\n  run:\n"
            "    runs-on: ubuntu-24.04\n    steps:\n      - run: echo\n"
        )

    def actionlint_on(self, caller_text: str, *flags: str) -> subprocess.CompletedProcess[str]:
        (self.root / ".github/workflows/caller.yml").write_text(caller_text)
        return subprocess.run(  # noqa: S603 - the pinned actionlint, a temporary fixture
            [self.actionlint, "-no-color", "-oneline", *flags, ".github/workflows/caller.yml"],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_the_pinned_actionlint_still_refuses_self_repository_calls(self):
        result = self.actionlint_on(self.FIXTURE_CALLER)
        if result.returncode == 0 or not self.REFUSAL.search(result.stdout):
            self.fail(
                'actionlint no longer refuses a "$/" reusable workflow call as it did in 1.7.12'
                f" (exit {result.returncode}, output: {result.stdout!r}). If it now accepts"
                ' "$/": remove the ignore in .github/actionlint.yaml, then trim'
                " tool/github/check_workflow_calls.py to what actionlint still does not check"
                " (see whether it now reports the undeclared input in this fixture), and update"
                " this test and docs/agents/conventions.md."
            )

    def test_the_repository_ignore_hides_only_that_message(self):
        config = ("-config-file", str(ACTIONLINT_CONFIG))
        self.assertEqual(self.actionlint_on(self.FIXTURE_CALLER, *config).stdout, "")
        # The same message for a "./" call with an @ref, and actionlint's refusal of "$/" in a
        # step (another rule), are not hidden.
        dot_slash = self.FIXTURE_CALLER.replace("$/", "./").replace("called.yml", "called.yml@main")
        step = (
            "name: Caller\non: push\npermissions: {}\njobs:\n  steps:\n"
            "    runs-on: ubuntu-24.04\n    steps:\n      - uses: $/.github/actions/setup\n"
        )
        for text, rule in ((dot_slash, "[workflow-call]"), (step, "[action]")):
            with self.subTest(rule=rule):
                result = self.actionlint_on(text, *config)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(rule, result.stdout)
