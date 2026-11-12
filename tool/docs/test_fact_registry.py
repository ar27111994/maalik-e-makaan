"""Tests for the facts and checks (python3 -m unittest discover -s tool/docs -p 'test_*.py')."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import docs_fixture
import fact_markers
import fact_registry as reg
import fact_sources
from docs_fixture import edited
from fact_sources import Repo, SourceShapeError

CI = ".github/workflows/ci.yml"
DEPLOY = ".github/workflows/deploy.yml"
PR_TITLE = ".github/workflows/pr-title.yml"
COMMANDS = "docs/agents/commands.md"
CONVENTIONS = "docs/agents/conventions.md"


def line(path: str, needle: str, changes: dict[str, str | None] | None = None) -> int:
    """The line of `needle` in the fixture's `path`, after `changes`."""
    text = docs_fixture.with_changes(changes or {})[path]
    assert text is not None and needle in text, needle
    return text[: text.index(needle)].count("\n") + 1


def merge(*changes: dict[str, str | None]) -> dict[str, str | None]:
    """Several changes at once, each to its own file: edited() starts from the fixture, so a
    second edit of the same file would replace the first."""
    merged: dict[str, str | None] = {}
    for change in changes:
        if set(change) & set(merged):
            raise ValueError(f"two changes to {sorted(set(change) & set(merged))}")
        merged.update(change)
    return merged


class FixtureCase(unittest.TestCase):
    def repo(self, changes: dict[str, str | None] | None = None) -> Repo:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        return Repo(root, docs_fixture.write(root, changes))

    def run_check(
        self, check: reg.Check, changes: dict[str, str | None] | None = None
    ) -> list[tuple[str, int, str]]:
        repo = self.repo(changes)
        problems = check.run(repo, repo.tracked)
        return sorted((p.path, p.line, p.message) for p in problems)

    def assert_problems(
        self,
        check: reg.Check,
        changes: dict[str, str | None] | None,
        expected: list[tuple[str, int, str]],
    ) -> None:
        """Exactly the expected problems: path, line and a fragment of the message each."""
        found = self.run_check(check, changes)
        self.assertEqual(
            [(p, n) for p, n, _ in found], sorted((p, n) for p, n, _ in expected), found
        )
        for (_, _, message), (_, _, fragment) in zip(found, sorted(expected), strict=True):
            self.assertIn(fragment, message)


def check(name: str) -> reg.Check:
    return next(c for c in reg.CHECKS if c.name == name)


def fact(key: str) -> reg.Fact:
    return reg.facts_by_key()[key]


class WordingTest(unittest.TestCase):
    def test_prose_list(self) -> None:
        self.assertEqual(reg.prose_list(["a"]), "a")
        self.assertEqual(reg.prose_list(["a", "b"]), "a and b")
        self.assertEqual(reg.prose_list(["a", "b", "c"]), "a, b and c")
        self.assertEqual(reg.prose_list(["a", "b", "c"], "or"), "a, b or c")
        with self.assertRaises(ValueError):
            reg.prose_list([])

    def test_count_value(self) -> None:
        for text, value in (("six", 6), ("Six", 6), ("6", 6), ("1,974", 1974), ("twenty", 20)):
            self.assertEqual(reg.count_value(text), value, text)

    def test_counts(self) -> None:
        self.assertEqual(reg.count_text(1), "one")
        self.assertEqual(reg.count_text(9), "nine")
        self.assertEqual(reg.count_text(14), "14")
        self.assertEqual(reg.count_text(0), "0")
        self.assertEqual(reg.thousands(1974), "1,974")
        self.assertEqual(reg.thousands(912), "912")
        self.assertEqual(reg.plural(1, "suite"), "1 suite")
        self.assertEqual(reg.plural(1974, "test"), "1,974 tests")


class RenderTest(FixtureCase):
    def render(self, key: str, changes: dict[str, str | None] | None = None) -> str:
        return fact(key).render(self.repo(changes))

    def test_each_renderer_from_the_fixture(self) -> None:
        self.assertEqual(
            self.render("commit-scopes"), "`app`, `ci`, `deps`, `deps-dev`, `docs`, `repo`"
        )
        self.assertEqual(
            self.render("commit-types-and-scopes"),
            "types: |\n  build\n  chore\n  ci\n  docs\n  feat\n  fix\n  test\n"
            "scopes: |\n  app\n  ci\n  deps\n  deps-dev\n  docs\n  repo",
        )
        self.assertEqual(self.render("changelog-visible"), "`feat`, `fix` and `docs`")
        self.assertEqual(self.render("changelog-hidden"), "`build`, `chore`, `ci` and `test`")
        self.assertEqual(self.render("coverage-ui"), "95%")
        self.assertEqual(self.render("coverage-app"), "90%")
        self.assertEqual(
            self.render("test-web-steps"), "`npm run check`, `npm test` and `npm run build`"
        )
        self.assertEqual(self.render("make-test-targets"), "`test-tools test-core test-ui`")
        self.assertEqual(self.render("uat-journeys"), "three")
        self.assertEqual(self.render("pgtap-count"), "2 suites, 1,974 tests")
        self.assertEqual(self.render("decision-range"), "D-01 to D-02")
        self.assertEqual(self.render("commit-header-max"), "100")
        self.assertEqual(self.render("commit-body-max"), "100")
        self.assertEqual(self.render("commit-subject-case"), "upper, Pascal or Start")
        self.assertEqual(
            self.render("release-files"),
            "`.release-please-manifest.json`, `app/pubspec.yaml` and `README.md`",
        )
        self.assertEqual(self.render("golden-variants"), "`light`, `dark` and `largeText`")

    def test_every_commitlint_case_has_a_word(self) -> None:
        self.assertEqual(set(reg._CASE_WORDS), set(fact_sources.COMMIT_CASES))

    def test_the_docs_say_sentence_case_is_allowed(self) -> None:
        changes = edited("commitlint.config.mjs", "'start-case']", "'start-case', 'sentence-case']")
        with self.assertRaisesRegex(SourceShapeError, "now refuses sentence case"):
            self.render("commit-subject-case", changes)

    def test_an_extra_file_without_a_path(self) -> None:
        changes = edited(
            "release-please-config.json",
            '{ "type": "generic", "path": "README.md" }',
            '{ "type": "generic", "file": "README.md" }',
        )
        with self.assertRaisesRegex(SourceShapeError, 'has no "path"; give it one'):
            self.render("release-files", changes)

    def test_renderers_at_their_edges(self) -> None:
        many = "".join(f'  test("J{n} x", async () => {{}});\n' for n in range(1, 15))
        self.assertEqual(
            self.render("uat-journeys", {"app/uat/tests/journeys.spec.ts": many}), "14"
        )
        one_suite = {
            "supabase/tests/database/02_ledger.test.sql": None,
            "supabase/tests/database/01_schema.test.sql": "select plan(1);",
        }
        self.assertEqual(self.render("pgtap-count", one_suite), "1 suite, 1 test")
        self.assertEqual(
            self.render("decision-range", {".planning/PROJECT.md": "- D-01: a\n"}), "D-01"
        )

    def test_a_ui_gate_on_branches_is_refused_because_the_docs_say_lines(self) -> None:
        changes = edited("Makefile", "--min 95", "--min 95 --min-branches 80")
        with self.assertRaisesRegex(SourceShapeError, "test-ui gates branches or functions"):
            self.render("coverage-ui", changes)

    def test_make_test_needs_prerequisites(self) -> None:
        changes = edited("Makefile", "test: test-tools test-core test-ui ##", "test: ##")
        with self.assertRaisesRegex(SourceShapeError, "test has no prerequisites"):
            self.render("make-test-targets", changes)

    def test_every_rendered_body_fits_its_markers(self) -> None:
        repo = self.repo()
        for item in reg.FACTS:
            body = item.render(repo)
            self.assertEqual(reg.unholdable(item.kind, body), [], item.key)
            if item.kind != "yaml":
                for text in ("|", "<!--", "-->"):
                    self.assertNotIn(text, body, item.key)
            if item.kind == "inline":
                self.assertNotIn("\n", body, item.key)

    def test_unholdable(self) -> None:
        self.assertEqual(reg.unholdable("inline", "a | b"), ["|"])
        self.assertEqual(reg.unholdable("inline", "a\nb"), ["a line break"])
        self.assertEqual(reg.unholdable("block", "a\n<!-- b -->"), ["<!--", "-->"])
        self.assertEqual(reg.unholdable("yaml", "types: |\n  a"), [])
        self.assertEqual(reg.unholdable("yaml", "a: 1\n# /docs:x"), ["a marker line"])


class RegistryShapeTest(unittest.TestCase):
    def test_keys_labels_and_idents(self) -> None:
        keys = [f.key for f in reg.FACTS]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(
            [f.ident for f in reg.FACTS], [f"G{n}" for n in range(1, len(reg.FACTS) + 1)]
        )
        self.assertEqual(
            [c.ident for c in reg.CHECKS], [f"C{n}" for n in range(1, len(reg.CHECKS) + 1)]
        )
        self.assertEqual(len({c.name for c in reg.CHECKS}), len(reg.CHECKS))
        for item in reg.FACTS:
            self.assertRegex(item.key, rf"^{fact_markers.KEY}$")
            for bad in ("--", ">", "|"):
                self.assertNotIn(bad, item.source, item.key)
            self.assertIn(item.kind, fact_markers.KINDS)
            self.assertTrue(item.reads and item.targets, item.key)
            for target in item.targets:
                self.assertIsNone(fact_markers.forbidden_reason(target), target)
                self.assertEqual(
                    fact_markers.syntax_of(target) == "yaml", item.kind == "yaml", target
                )
        for item in reg.CHECKS:
            self.assertRegex(item.name, rf"^{fact_markers.KEY}$")
            self.assertTrue(item.reads and item.describe, item.name)

    def test_the_canonical_markers_of_every_fact_scan_cleanly(self) -> None:
        for item in reg.FACTS:
            if item.kind == "yaml":
                text = (
                    f"  {fact_markers.yaml_open_marker(item.key, item.source)}\n  a: 1\n"
                    f"  {fact_markers.yaml_close_marker(item.key)}\n"
                )
                path = "f.yml"
            else:
                text = (
                    f"x {fact_markers.open_marker(item.key, item.source)}y"
                    f"{fact_markers.close_marker(item.key)}\n"
                )
                path = "f.md"
            kinds = {item.key: "inline" if item.kind == "block" else item.kind}
            spans, errors = fact_markers.scan(path, text, kinds)
            self.assertEqual((len(spans), errors), (1, []), item.key)


class MarkdownHelpersTest(unittest.TestCase):
    def test_code_spans(self) -> None:
        self.assertEqual(
            reg.code_spans("a `make x` b ``code ` tick`` c `` `y` ``"),
            ["make x", "code ` tick", "`y`"],
        )

    def test_make_targets_in(self) -> None:
        self.assertEqual(
            reg.make_targets_in("make lint docs-check   # guards"), ["lint", "docs-check"]
        )
        self.assertEqual(reg.make_targets_in("UAT_RESET=1 A=b make test-uat"), ["test-uat"])
        self.assertEqual(reg.make_targets_in('make "$TARGET"'), [])
        self.assertEqual(reg.make_targets_in("cd x && make y"), [])
        self.assertEqual(reg.make_targets_in("make"), [])

    def test_make_references_in_spans_and_fenced_lines_only(self) -> None:
        text = "Run `make a b`, then make c.\n\n```sh\nmake d   # e\n  make f\necho make g\n```\n`make h`\n"
        self.assertEqual(
            reg.make_references(text), [(1, ["a", "b"]), (4, ["d"]), (5, ["f"]), (8, ["h"])]
        )

    def test_sections_and_tables(self) -> None:
        text = (
            "# T\n\n## A\n\nx\n\n| H | I |\n| - | - |\n| a \\| b | c |\n| d | e |\n\nafter\n\n"
            "| other |\n| ----- |\n| z |\n\n### Sub\n\nstill A\n\n## B\n\ny\n"
        )
        start, body = reg.section(text, "## A")
        self.assertEqual(start, 3)
        self.assertIn("still A", body)
        self.assertNotIn("y", body)
        heading, rows = reg.table_rows(text, "## A")
        self.assertEqual(heading, 3)
        self.assertEqual(
            [(n, cells) for n, cells, _ in rows], [(9, ["a \\| b", "c"]), (10, ["d", "e"])]
        )
        self.assertEqual(reg.section(text, "## Missing"), (0, []))
        self.assertEqual(reg.table_rows(text, "## B"), (22, []))

    def test_scanned_markdown(self) -> None:
        tracked = [
            "README.md",
            "CHANGELOG.md",
            "website/src/content/guides/en/a.md",
            ".planning/research/x.md",
            ".planning/STATE.md",
            "docs/a.md",
            "a.yml",
            "llms.txt",
            "docs/llms.txt",
        ]
        self.assertEqual(
            reg.scanned_markdown(tracked),
            ["README.md", ".planning/STATE.md", "docs/a.md", "llms.txt"],
        )

    def test_strip_markers_and_generated_spans(self) -> None:
        line = "a <!-- docs:k from s; x -->90%<!-- /docs:k --> b <!-- docs:j -->1<!-- /docs:j -->"
        self.assertEqual(reg.strip_markers(line), "a 90% b 1")
        self.assertEqual(reg.strip_generated(line), "a  b ")
        wrapped = "a <!-- docs:k -->`x`,\n  90% line<!-- /docs:k --> b\nc"
        self.assertEqual(reg.strip_generated(wrapped), "a \n b\nc")


class ConsistentFixtureTest(FixtureCase):
    def test_every_check_passes_on_the_fixture(self) -> None:
        for item in reg.CHECKS:
            self.assertEqual(self.run_check(item), [], item.name)


class CommitChecksTest(FixtureCase):
    def test_c1_changelog_sections_against_the_types(self) -> None:
        missing = edited("commitlint.config.mjs", "'fix', 'test'", "'fix', 'perf', 'test'")
        self.assert_problems(
            check("changelog-sections"),
            missing,
            [
                (
                    "release-please-config.json",
                    line("release-please-config.json", '"changelog-sections"'),
                    "has no changelog section for the commit type perf",
                )
            ],
        )
        extra = edited(
            "release-please-config.json",
            '{ "type": "test", "section": "Tests", "hidden": true }',
            '{ "type": "test", "section": "Tests", "hidden": true },\n    { "type": "style", "section": "Style" }',
        )
        self.assert_problems(
            check("changelog-sections"),
            merge(missing, extra),
            [
                (
                    "release-please-config.json",
                    3,
                    "has no changelog section for the commit type perf",
                ),
                (
                    "release-please-config.json",
                    line("release-please-config.json", '"style"', extra),
                    "refuses",
                ),
            ],
        )

    def test_c2_the_release_title_is_ignored(self) -> None:
        changes = edited(
            "release-please-config.json",
            '"chore(release): release${component} ${version}"',
            '"chore: release ${version}"',
        )
        self.assert_problems(
            check("release-title-ignored"),
            changes,
            [
                (
                    "commitlint.config.mjs",
                    line("commitlint.config.mjs", "ignores:"),
                    "does not match release-please's pull request title 'chore: release 1.2.3'",
                )
            ],
        )

    def test_c3_the_header_length(self) -> None:
        self.assert_problems(
            check("header-length"),
            edited(PR_TITLE, 'MAX_HEADER: "100"', 'MAX_HEADER: "90"'),
            [
                (
                    PR_TITLE,
                    line(PR_TITLE, "MAX_HEADER: "),
                    "MAX_HEADER is 90; commitlint's header-max-length is 100",
                )
            ],
        )
        shorter = edited(
            "commitlint.config.mjs",
            "[2, 'always', 100],\n    'scope",
            "[2, 'always', 72],\n    'scope",
        )
        self.assert_problems(
            check("header-length"),
            shorter,
            [
                (PR_TITLE, line(PR_TITLE, "the 100-character"), "says 100-character"),
                (PR_TITLE, line(PR_TITLE, "squash commit's 100-character"), "says 100-character"),
                (PR_TITLE, line(PR_TITLE, "MAX_HEADER: "), "MAX_HEADER is 100"),
            ],
        )
        self.assert_problems(
            check("header-length"),
            edited(PR_TITLE, '          MAX_HEADER: "100"\n', ""),
            [(PR_TITLE, 1, "sets MAX_HEADER 0 times")],
        )

    def test_c3_the_limits_the_docs_state(self) -> None:
        hand = merge(
            edited("docs/uat.md", " journeys.", " journeys. Titles fit the 72-character header."),
            edited("CHANGELOG.md", "## 1.2.3\n", "## 1.2.3\n\nBody lines at most 50 characters.\n"),
            edited(
                "docs/release-readiness.md",
                "# Dated\n",
                "# Dated\n\nThen a 50-character header.\n",
            ),
            {"llms.txt": "# Project\n\nBody lines at\nmost 80 characters.\n"},
            {"docs/agrees.md": "# Agrees\n\nA title fits the 100-character header.\n"},
        )
        self.assert_problems(
            check("header-length"),
            hand,
            [
                (
                    "docs/uat.md",
                    3,
                    "says 72-character header; commitlint's header-max-length is 100",
                ),
                (
                    "llms.txt",
                    3,
                    "says Body lines at most 80 characters; commitlint's body-max-line-length",
                ),
            ],
        )
        limits = edited(
            "commitlint.config.mjs",
            "'body-max-line-length': [2, 'always', 100]",
            "'body-max-line-length': [2, 'always', 72]",
        )
        # The generated copies are make docs's to rewrite; the check leaves them out.
        self.assert_problems(check("header-length"), limits, [])

    def test_c4_dependabot_commits(self) -> None:
        self.assert_problems(
            check("dependabot-commits"),
            edited(".github/dependabot.yml", "prefix: chore", "prefix: deps"),
            [(".github/dependabot.yml", 11, "commit as deps, a type")],
        )
        self.assert_problems(
            check("dependabot-commits"),
            edited(
                "commitlint.config.mjs",
                "        // Dependabot's scope for development dependencies.\n        'deps-dev',\n",
                "",
            ),
            [(".github/dependabot.yml", 6, "use the scope deps-dev")],
        )
        no_scope = edited(
            ".github/dependabot.yml",
            "      prefix: ci\n      include: scope\n",
            "      prefix: ci\n",
        )
        self.assert_problems(check("dependabot-commits"), no_scope, [])


class MakeChecksTest(FixtureCase):
    def test_c5_every_target_named_and_phony(self) -> None:
        self.assert_problems(
            check("make-targets"),
            edited(
                COMMANDS, "| `make format`         | Formats", "| Format                | Formats"
            ),
            [(COMMANDS, 1, "does not name `make format` (Makefile line 10)")],
        )
        self.assert_problems(
            check("make-targets"),
            edited("Makefile", ".PHONY: lint\n", ""),
            [("Makefile", 17, "lint is not .PHONY; add `.PHONY: lint`")],
        )

    def test_c5_every_make_reference_names_a_target(self) -> None:
        changes = merge(
            edited("AGENTS.md", "make test              # every", "make tset              # every"),
            edited("docs/uat.md", " journeys.", " journeys (`UAT_RESET=1 make test-uatt`)."),
        )
        self.assert_problems(
            check("make-targets"),
            changes,
            [
                (
                    "AGENTS.md",
                    line("AGENTS.md", "make test  "),
                    "names make tset, which is not a Makefile target",
                ),
                ("docs/uat.md", 3, "names make test-uatt"),
            ],
        )

    def test_c5_reads_llms_txt_and_skips_a_tracked_file_that_is_gone(self) -> None:
        changes = {
            "llms.txt": "# Project\n\n- [UAT](docs/uat.md): `make test-uat`\n",
            "docs/gone.md": None,
        }
        repo = self.repo(changes)
        problems = check("make-targets").run(repo, (*repo.tracked, "docs/gone.md"))
        self.assertEqual(
            [(p.path, p.line) for p in problems], [("llms.txt", 3)], [str(p) for p in problems]
        )

    def test_c6_test_tools_discovery(self) -> None:
        self.assert_problems(
            check("test-tools-discovery"),
            {"tool/web/test_package.py": ""},
            [("Makefile", line("Makefile", "test-tools:"), "does not run the tests in tool/web")],
        )
        gone = edited(
            "Makefile",
            "\tpython3 -m unittest discover -s tool/docs -p 'test_*.py'\n",
            "\tpython3 -m unittest discover -s tool/docs -p 'test_*.py'\n"
            "\tpython3 -m unittest discover -s tool/gone -p 'test_*.py'\n"
            "\tpython3 -m unittest discover -s tool -p 'test_*.py'\n",
        )
        self.assert_problems(
            check("test-tools-discovery"),
            gone,
            [
                (
                    "Makefile",
                    line("Makefile", "-s tool/gone", gone),
                    "discovers tool/gone, which has no tracked",
                ),
                ("Makefile", line("Makefile", "-s tool/gone", gone) + 1, "discovers tool twice"),
            ],
        )

    def test_c7_the_floors(self) -> None:
        self.assert_problems(
            check("coverage"),
            edited("Makefile", "lcov.info --min 100\n", "lcov.info --min 95\n"),
            [
                (
                    "Makefile",
                    line("Makefile", "packages/mm_core/coverage/lcov.info --min"),
                    "test-core's gate is 95% of lines",
                ),
                # The copies the floor message points at are reported one by one as well.
                (COMMANDS, line(COMMANDS, "| `make test-core`"), "says 100% for make test-core"),
            ],
        )
        self.assert_problems(
            check("coverage"),
            edited("Makefile", "--min-branches 100", "--min-branches 90"),
            [
                (
                    "Makefile",
                    line("Makefile", "supabase/functions/coverage"),
                    "test-functions' gate is not 100%",
                )
            ],
        )

    def test_c7_and_c12_leave_out_generated_spans_even_when_they_wrap(self) -> None:
        wrapped = {
            "docs/extra.md": (
                "# Extra\n\n`make test-ui` keeps <!-- docs:coverage-ui -->80% line\n"
                "coverage, Flutter 3.1<!-- /docs:coverage-ui --> and more.\n"
            )
        }
        for name in ("coverage", "version-mentions"):
            # The stale span is make docs' to rewrite (and M7's, being in no target), not a copy.
            self.assertEqual(self.run_check(check(name), wrapped), [], name)

    def test_c7_a_line_naming_a_target_states_its_gate(self) -> None:
        changes = edited(
            "Makefile", "app/coverage/lcov.info --min 90", "app/coverage/lcov.info --min 100"
        )
        # The README's table row is copied by hand; commands.md's 90% is a generated span, which
        # make docs rewrites, so it is not reported again here.
        self.assert_problems(
            check("coverage"),
            changes,
            [
                (
                    "README.md",
                    line("README.md", "| App  |"),
                    "says 90% for make test-app and make test-core; the Makefile gate is 100",
                )
            ],
        )
        two = merge(
            changes,
            edited("docs/uat.md", " journeys.", " journeys; `make test-ui` keeps 96% of lines."),
        )
        self.assert_problems(
            check("coverage"),
            two,
            [
                ("README.md", line("README.md", "| App  |"), "says 90%"),
                ("docs/uat.md", 3, "says 96% for make test-ui; the Makefile gate is 95"),
            ],
        )


class WorkflowChecksTest(FixtureCase):
    def test_c8_job_names_needs_and_targets(self) -> None:
        renamed = edited(CI, "    name: Database\n", "    name: Database (pgTAP)\n")
        self.assert_problems(
            check("ci-jobs"),
            renamed,
            [
                (
                    COMMANDS,
                    line(COMMANDS, "## CI jobs"),
                    'no row for "Database (pgTAP)" (the job database',
                ),
                (COMMANDS, line(COMMANDS, "| Database "), 'names "Database", but no job'),
            ],
        )
        self.assert_problems(
            check("ci-jobs"),
            edited(CI, "        database,\n      ]", "        ghost,\n      ]"),
            [
                (CI, line(CI, "  passed:"), "`CI passed` does not need database"),
                (CI, line(CI, "  passed:"), "`CI passed` needs ghost, which is not a job"),
            ],
        )
        self.assert_problems(
            check("ci-jobs"),
            edited(
                COMMANDS, "`make tokens-check docs-check` |", "`make tokens-check`            |"
            ),
            [
                (
                    COMMANDS,
                    line(COMMANDS, "| Repository hygiene"),
                    "does not name docs-check, which the job runs (.github/workflows/ci.yml line"
                    f" {line(CI, 'run: make tokens-check docs-check')})",
                )
            ],
        )

    def test_c8_the_section_and_the_passed_job(self) -> None:
        self.assert_problems(
            check("ci-jobs"),
            edited(COMMANDS, "the `CI passed` job needs", "one job needs"),
            [(COMMANDS, line(COMMANDS, "## CI jobs"), "does not name `CI passed`")],
        )
        self.assert_problems(
            check("ci-jobs"),
            edited(CI, "    name: CI passed\n", "    name: All good\n"),
            [
                (CI, 1, "needs exactly one job named `CI passed`"),
                (COMMANDS, line(COMMANDS, "## CI jobs"), 'no row for "All good"'),
            ],
        )
        self.assert_problems(
            check("ci-jobs"),
            edited(COMMANDS, "## CI jobs", "## Jobs"),
            [(COMMANDS, 1, "has no `## CI jobs` section")],
        )

    def test_c9_every_workflow_listed(self) -> None:
        self.assert_problems(
            check("workflows-listed"),
            {".github/workflows/extra.yml": "name: Extra\n"},
            [
                (
                    COMMANDS,
                    line(COMMANDS, "## CI jobs"),
                    "does not name the workflow .github/workflows/extra.yml; add `extra.yml`",
                )
            ],
        )

    def test_c10_the_website_sequence(self) -> None:
        swapped = edited(
            CI,
            "        run: npm run check\n      - name: Unit tests\n        run: npm test",
            "        run: npm test\n      - name: Unit tests\n        run: npm run check",
        )
        self.assert_problems(
            check("website-sequence"),
            swapped,
            [
                (
                    CI,
                    line(CI, "  website:"),
                    "runs npm test, npm run check, npm run build; make test-web runs npm run check, npm test, npm run build",
                )
            ],
        )

    def test_c11_workflow_pins(self) -> None:
        self.assert_problems(
            check("toolchain-pins"),
            edited(DEPLOY, "FLUTTER_VERSION: 3.47.9", "FLUTTER_VERSION: 3.47.8"),
            [(DEPLOY, 5, "FLUTTER_VERSION is 3.47.8; .github/workflows/ci.yml has 3.47.9")],
        )
        self.assert_problems(
            check("toolchain-pins"),
            edited(DEPLOY, "version: ${{ env.SUPABASE_CLI_VERSION }}", "version: 2.122.1"),
            [(DEPLOY, 22, "setup-cli version is 2.122.1; read ${{ env.SUPABASE_CLI_VERSION }}")],
        )
        self.assert_problems(
            check("toolchain-pins"),
            edited(DEPLOY, "  SUPABASE_CLI_VERSION: 2.122.1\n", ""),
            [(DEPLOY, 21, "reads env.SUPABASE_CLI_VERSION, which this workflow does not set")],
        )
        self.assert_problems(
            check("toolchain-pins"),
            edited(
                CI,
                "flutter-version: ${{ env.FLUTTER_VERSION }}",
                "flutter-version: ${{ env.DENO_VERSION }}",
            ),
            [(CI, line(CI, "flutter-version: "), "read ${{ env.FLUTTER_VERSION }}")],
        )

    def test_c11_java_python_and_the_vercel_cli(self) -> None:
        self.assert_problems(
            check("toolchain-pins"),
            edited(CI, "java-version: ${{ env.JAVA_VERSION }}", 'java-version: "17"'),
            [(CI, line(CI, "java-version: "), "java-version is 17; read ${{ env.JAVA_VERSION }}")],
        )
        literal = edited(DEPLOY, '"vercel@$VERCEL_CLI_VERSION" build', "vercel@64.0.0 build")
        self.assert_problems(
            check("toolchain-pins"),
            literal,
            [
                (
                    DEPLOY,
                    line(DEPLOY, "vercel@$VERCEL"),
                    'runs vercel@64.0.0; run "vercel@$VERCEL_CLI_VERSION"',
                )
            ],
        )
        unset = edited(DEPLOY, "      VERCEL_CLI_VERSION: 65.8.0\n", "")
        self.assert_problems(
            check("toolchain-pins"),
            unset,
            [
                (DEPLOY, line(DEPLOY, "vercel@$VERCEL", unset), "reads VERCEL_CLI_VERSION, which"),
                (DEPLOY, line(DEPLOY, "vercel@${VERCEL", unset), "reads VERCEL_CLI_VERSION, which"),
            ],
        )
        # A pin ci.yml does not set: every workflow that sets it agrees with the first.
        other = {
            ".github/workflows/zz.yml": "name: Z\nenv:\n  VERCEL_CLI_VERSION: 64.0.0\njobs: {}\n"
        }
        self.assert_problems(
            check("toolchain-pins"),
            other,
            [(".github/workflows/zz.yml", 3, f"VERCEL_CLI_VERSION is 64.0.0; {DEPLOY} has 65.8.0")],
        )

    def test_c11_ci_names_the_postgresql_it_installs(self) -> None:
        self.assert_problems(
            check("toolchain-pins"),
            edited(CI, "Install PostgreSQL 16 and", "Install PostgreSQL 17 and"),
            [(CI, line(CI, "Install PostgreSQL"), "says PostgreSQL 17; it installs postgresql-16")],
        )
        self.assert_problems(
            check("toolchain-pins"),
            edited(CI, "pg_ctlcluster 16", "pg_ctlcluster 15"),
            [(CI, line(CI, "pg_ctlcluster"), "says pg_ctlcluster 15; it installs postgresql-16")],
        )
        quiet = edited(
            CI, "      - name: Install PostgreSQL 16 and pgTAP\n", "      - name: Database\n"
        )
        quiet[CI] = (quiet[CI] or "").replace("          sudo pg_ctlcluster 16 main start\n", "")
        self.assert_problems(check("toolchain-pins"), quiet, [])

    def test_c11_pubspecs_and_lean(self) -> None:
        self.assert_problems(
            check("toolchain-pins"),
            merge(
                {"packages/mm_core/pubspec.yaml": "name: mm_core\nenvironment:\n  sdk: ^3.12.0\n"},
                {"formal/lean/lean-toolchain": "leanprover/lean4:v4.34.0\n"},
            ),
            [
                (
                    "formal/lean/lean-toolchain",
                    1,
                    "names Lean 4.34.0; tool/formal/install.sh pins LEAN_VERSION=4.35.0",
                ),
                (
                    "packages/mm_core/pubspec.yaml",
                    3,
                    "sdk is ^3.12.0; the workspace's pubspec.yaml has ^3.13.0",
                ),
            ],
        )


class VersionMentionsTest(FixtureCase):
    def mention(self, words: str) -> list[tuple[str, int, str]]:
        return self.run_check(check("version-mentions"), {"docs/extra.md": f"# Extra\n\n{words}\n"})

    def test_prefixes_and_words_are_accepted(self) -> None:
        for words in (
            "Flutter 3.47 and Flutter 3.47.9",
            "Dart 3, Deno 2 and Node 22.23",
            "Node.js 22 with Python 3.12+",
            "Lean 4 is the language",
            "`make test-ui` at 200% text",
            "go_router 18.2 and supabase_flutter 2",
            "Postgres 17 on Supabase, a local Supabase stack (Postgres 17.11.0)",
            "the local PostgreSQL 16, PostgreSQL 16.15 with pgTAP and a PostgreSQL 16 server",
            "Measured on PostgreSQL 15, and PostgreSQL 14 and 17 behave alike",
        ):
            self.assertEqual(self.mention(words), [], words)

    def test_each_mention_that_disagrees(self) -> None:
        cases = {
            "Flutter 3.46": "FLUTTER_VERSION is 3.47.9",
            "Flutter 3.4": "FLUTTER_VERSION is 3.47.9",
            "Dart 2": "the Dart SDK floor in pubspec.yaml is 3.13.0",
            "Dart 3.1": "the Dart SDK floor",
            "Deno 1.4": "DENO_VERSION is 2.9.6",
            "Node 20": ".nvmrc has 22.23.4",
            "Python 3.11 or later": "target Python 3.12",
            "Python 3.13+": "target Python 3.12",
            "Riverpod 2": "flutter_riverpod ^3",
            "go_router 17": "go_router ^18",
            "supabase_flutter 1": "supabase_flutter ^2",
            "Lean 4.36.0": "pins Lean 4.35.0 and 4.34.0",
            "Bend 2.0.38": "pins Bend 2.0.39",
            "TLC 2.18": "pins TLC 2.19",
            "tlaplus v1.7.3": "pins tlaplus v1.7.4",
            "z3-solver 5.3.2.0": "pins z3-solver 5.3.3.0",
            "Postgres 16 on Supabase": "supabase/config.toml's [db] major_version is 17",
            "Supabase backend (PostgreSQL 15": "major_version is 17",
            "local PostgreSQL 17": "ci.yml installs postgresql-16 for make test-db",
            "PostgreSQL 15 with pgTAP": "installs postgresql-16",
            "PostgreSQL 17 server": "installs postgresql-16",
        }
        for words, source in cases.items():
            found = self.mention(f"It uses {words} today.")
            self.assertEqual(len(found), 1, (words, found))
            self.assertEqual(found[0][:2], ("docs/extra.md", 3))
            self.assertIn(f"says {words}", found[0][2])
            self.assertIn(source, found[0][2])

    def test_two_independent_drifts_are_both_reported(self) -> None:
        found = self.mention("Flutter 3.46\nand Node 20.")
        self.assertEqual(
            [(p, n) for p, n, _ in found], [("docs/extra.md", 3), ("docs/extra.md", 4)]
        )

    def test_llms_txt_is_read(self) -> None:
        found = self.run_check(
            check("version-mentions"), {"llms.txt": "# Project\n\n> Flutter 3.1 on Supabase.\n"}
        )
        self.assertEqual([(p, n) for p, n, _ in found], [("llms.txt", 3)])

    def test_dated_evidence_planning_and_site_copy_are_left_out(self) -> None:
        for path in (
            "docs/release-readiness.md",
            ".planning/STATE.md",
            "website/src/content/x.md",
            "CHANGELOG.md",
        ):
            self.assertEqual(
                self.run_check(check("version-mentions"), {path: "Flutter 3.1\n"}), [], path
            )


class GeneratedFilesAndReleaseTest(FixtureCase):
    def test_c13_the_generated_files_table_and_the_ci_step(self) -> None:
        self.assert_problems(
            check("generated-files-table"),
            edited(CONVENTIONS, "| Repeated facts | the source each names | `make docs`   |\n", ""),
            [
                (
                    CONVENTIONS,
                    line(CONVENTIONS, "## Generated files"),
                    "no row for `make docs` (docs-check checks its output)",
                )
            ],
        )
        self.assert_problems(
            check("generated-files-table"),
            edited(CI, "run: make tokens-check docs-check", "run: make tokens-check"),
            [
                (
                    CI,
                    line(CI, "- name: Generated files"),
                    '"Generated files are up to date" does not run make docs-check',
                )
            ],
        )
        self.assert_problems(
            check("generated-files-table"),
            edited(CI, "- name: Generated files are up to date", "- name: Generated"),
            [(CI, 1, 'needs exactly one step named "Generated files are up to date"')],
        )

    def test_c14_the_release_line(self) -> None:
        self.assert_problems(
            check("release-in-readme"),
            edited("README.md", "**v1.2.3 is", "**v1.2.2 is"),
            [
                (
                    "README.md",
                    3,
                    "the release line names 1.2.2; .release-please-manifest.json has 1.2.3",
                )
            ],
        )
        self.assert_problems(
            check("release-in-readme"),
            edited("README.md", "**v1.2.3 is", "**1.2.3 is"),
            [("README.md", 3, "should name the release as v1.2.3")],
        )
        self.assert_problems(
            check("release-in-readme"),
            edited("README.md", " <!-- x-release-please-version -->", ""),
            [("README.md", 1, "has 0 lines marked x-release-please-version")],
        )
        self.assert_problems(
            check("release-in-readme"),
            edited(
                "README.md",
                "([release notes](CHANGELOG.md)).",
                "v1.2.3 again <!-- x-release-please-version -->",
            ),
            [("README.md", 4, "has 2 lines marked")],
        )
        self.assert_problems(
            check("release-in-readme"),
            edited(
                "release-please-config.json",
                '"path": "README.md" }',
                '"path": "README.md", "type": "json" }',
            ),
            [
                (
                    "release-please-config.json",
                    line("release-please-config.json", '"extra-files"'),
                    'extra-files needs { "type": "generic", "path": "README.md" }',
                )
            ],
        )


class RangesAndCountsTest(FixtureCase):
    def test_c15_the_ranges_of_decisions_and_proposals(self) -> None:
        changes = merge(
            {"llms.txt": "# Project\n\n- decisions D-01 to D-07, open proposals P-01 and P-02\n"},
            edited("docs/uat.md", " journeys.", " journeys; decisions\nD-01 to D-02 hold."),
            {".planning/STATE.md": "decisions D-01 to D-09 on 1 November\n"},
        )
        self.assert_problems(
            check("decision-ranges"),
            changes,
            [
                (
                    "llms.txt",
                    3,
                    "says decisions D-01 to D-07; .planning/PROJECT.md has D-01 to D-02",
                ),
                ("llms.txt", 3, "says proposals P-01 and P-02; .planning/PROJECT.md has P-01"),
            ],
        )
        none = merge(
            {
                ".planning/PROJECT.md": docs_fixture.PROJECT.replace(
                    "- P-01: **Reminders.** Later.\n", ""
                )
            },
            {"llms.txt": "# Project\n\nThe proposals P-01 to P-03.\n"},
        )
        self.assert_problems(check("decision-ranges"), none, [("llms.txt", 3, "has no P- entry")])
        three = {
            ".planning/PROJECT.md": docs_fixture.PROJECT.replace("- D-02:", "- D-02: x\n- D-03:"),
            "llms.txt": "# Project\n\nAll the decisions D-01 to D-03.\n",
        }
        self.assert_problems(
            check("decision-ranges"),
            three,
            [("README.md", line("README.md", "The decisions D-01"), "has D-01 to D-03")],
        )

    def test_c16_golden_variants_and_tla_models(self) -> None:
        changes = merge(
            edited("README.md", "Goldens in three variants,", "Goldens in 4 variants,"),
            edited(
                "docs/uat.md",
                " journeys.",
                " journeys, in all Three\nvariants and Five TLA+ models.",
            ),
            {"docs/release-readiness.md": "# Dated\n\nGoldens in 9 variants.\n"},
            {".planning/STATE.md": "Seven TLA+ models.\n"},
        )
        self.assert_problems(
            check("counts"),
            changes,
            [
                (
                    "README.md",
                    line("README.md", "Goldens in"),
                    "says 4 variants; packages/mm_ui/test/support/harness.dart has 3 MmVariant values",
                ),
                ("docs/uat.md", 4, "says Five TLA+ models; formal/tla has 2 models (Alpha, Beta)"),
            ],
        )

    def test_c16_the_pgtap_figures_in_the_docs_and_the_deck(self) -> None:
        slide = "website/deck/slides/trust.html"
        changes = {
            slide: docs_fixture.TRUST_SLIDE.replace("in 2 suites", "in 3 suites").replace(
                ">2</p>", ">3</p>"
            ),
            "docs/extra.md": "# Extra\n\nThe 912 database tests in 21 suites.\n",
        }
        self.assert_problems(
            check("counts"),
            changes,
            [
                (
                    "docs/extra.md",
                    3,
                    "says 912 database tests in 21 suites; supabase/tests/database plans 1,974 tests in 2 suites",
                ),
                (slide, 2, "says 1,974 database tests in 3 suites"),
                (slide, 4, "says 3 TLA+ models; formal/tla has 2 models"),
            ],
        )

    def test_c16_reads_a_source_only_when_something_counts_it(self) -> None:
        broken = {"packages/mm_ui/test/support/harness.dart": "enum Other {}\n"}
        quiet = merge(
            broken,
            edited("README.md", "Goldens in three variants,", "Goldens in each variant,"),
            edited(CONVENTIONS, "Goldens run in three variants:", "Goldens run in each variant:"),
        )
        self.assertEqual(self.run_check(check("counts"), quiet), [])
        with self.assertRaisesRegex(SourceShapeError, "has no `enum MmVariant"):
            self.run_check(check("counts"), broken)

    def test_the_fixture_helpers_refuse_what_they_cannot_do(self) -> None:
        with self.assertRaisesRegex(ValueError, "is not in README.md exactly once"):
            docs_fixture.edited("README.md", "no such text", "x")
        with self.assertRaisesRegex(ValueError, r"two changes to \['README.md'\]"):
            merge(
                edited("README.md", "# Project", "# A"), edited("README.md", "## Quality", "## B")
            )


if __name__ == "__main__":
    unittest.main()
