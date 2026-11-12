"""Tests for the source parsers (python3 -m unittest discover -s tool/docs -p 'test_*.py')."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import docs_fixture
import fact_sources as fs
from fact_sources import SourceShapeError

# The repository's commitlint.config.mjs as it is today, rules and comments included.
COMMITLINT_TODAY = """\
// Conventional Commits (https://www.conventionalcommits.org) with the scopes
// used in this monorepo.
export default {
  extends: ['@commitlint/config-conventional'],
  // release-please's own commit (release-please-config.json sets its title). Its
  // body is the generated changelog, whose links run past 100 characters.
  ignores: [(message) => /^chore\\(release\\): release \\d+\\.\\d+\\.\\d+/.test(message)],
  rules: {
    // The types and header limit @commitlint/config-conventional sets, stated here so the
    // repository has one list.
    'type-enum': [
      2,
      'always',
      [
        'build',
        'chore',
        'ci',
        'docs',
        'feat',
        'fix',
        'perf',
        'refactor',
        'revert',
        'style',
        'test',
      ],
    ],
    'header-max-length': [2, 'always', 100],
    'scope-enum': [
      2,
      'always',
      [
        'app',
        'core',
        'ui',
        'db',
        'functions',
        'web',
        'ci',
        'deps',
        // Dependabot's scope for development dependencies.
        'deps-dev',
        'docs',
        'formal',
        'planning',
        'release',
        'repo',
        'security',
        'test',
      ],
    ],
    'body-max-line-length': [2, 'always', 100],
    'footer-max-line-length': [0],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'start-case']],
  },
};
"""


def commitlint_with(old: str, new: str) -> str:
    if COMMITLINT_TODAY.count(old) != 1:
        raise AssertionError(old)
    return COMMITLINT_TODAY.replace(old, new)


class CommitlintTest(unittest.TestCase):
    def test_todays_config(self) -> None:
        parsed = fs.parse_commitlint(COMMITLINT_TODAY)
        self.assertEqual(
            parsed.types,
            (
                "build",
                "chore",
                "ci",
                "docs",
                "feat",
                "fix",
                "perf",
                "refactor",
                "revert",
                "style",
                "test",
            ),
        )
        self.assertEqual(len(parsed.scopes), 16)
        self.assertEqual(parsed.scopes[:3], ("app", "core", "ui"))
        self.assertEqual(parsed.scopes[-1], "test")
        self.assertEqual(parsed.header_max, 100)
        self.assertTrue(parsed.ignores.search("chore(release): release 1.2.3"))
        self.assertFalse(parsed.ignores.search("chore(release): bump"))
        self.assertEqual(parsed.ignores_line, 7)

    def test_comments_double_quotes_and_no_trailing_comma(self) -> None:
        text = commitlint_with(
            "    'header-max-length': [2, 'always', 100],",
            '    "header-max-length": [2, "always", /* the default */ 72],',
        ).replace(
            "        'test',\n      ],\n    ],\n    'body",
            "        'test' // last\n      ],\n    ],\n    'body",
        )
        parsed = fs.parse_commitlint(text)
        self.assertEqual(parsed.header_max, 72)
        self.assertEqual(parsed.scopes[-1], "test")
        self.assertIn("deps-dev", parsed.scopes)

    def assert_refused(self, text: str, *words: str) -> None:
        with self.assertRaises(SourceShapeError) as caught:
            fs.parse_commitlint(text)
        self.assertEqual(caught.exception.path, "commitlint.config.mjs")
        for word in words:
            self.assertIn(word, caught.exception.message)

    def test_a_missing_rule(self) -> None:
        self.assert_refused(
            commitlint_with("    'header-max-length': [2, 'always', 100],\n", ""),
            "'header-max-length' is missing",
            "parse_commitlint",
        )
        self.assert_refused(
            COMMITLINT_TODAY.replace("'type-enum'", "'type-list'"), "'type-enum' is missing"
        )

    def test_a_rule_given_twice(self) -> None:
        self.assert_refused(
            commitlint_with(
                "    'header-max-length'",
                "    'scope-enum': [2, 'always', ['x']],\n    'header-max-length'",
            ),
            "'scope-enum' appears 2 times",
        )

    def test_another_severity_or_never(self) -> None:
        self.assert_refused(
            COMMITLINT_TODAY.replace("'scope-enum': [\n      2,", "'scope-enum': [\n      1,"),
            "'scope-enum' is not [2, 'always'",
        )
        self.assert_refused(
            COMMITLINT_TODAY.replace(
                "'type-enum': [\n      2,\n      'always'",
                "'type-enum': [\n      2,\n      'never'",
            ),
            "'type-enum' is not",
        )

    def test_a_spread_a_variable_or_a_call(self) -> None:
        for item in ("...base", "extra", "list()"):
            self.assert_refused(
                commitlint_with("        'app',\n", f"        {item},\n"),
                "'scope-enum' has the item",
                "quoted name",
            )

    def test_a_duplicate_or_an_empty_list(self) -> None:
        self.assert_refused(
            commitlint_with("        'core',\n", "        'app',\n"), "lists app twice"
        )
        empty = (
            COMMITLINT_TODAY[: COMMITLINT_TODAY.index("    'scope-enum'")]
            + "    'scope-enum': [2, 'always', []],\n  },\n};\n"
        )
        self.assert_refused(empty, "'scope-enum' lists no names")

    def test_ignores_with_a_flag_or_another_shape(self) -> None:
        self.assert_refused(
            commitlint_with("\\d+/.test(message)", "\\d+/i.test(message)"), "ignores is not exactly"
        )
        self.assert_refused(commitlint_with("(message) => /", "(m) => /"), "ignores is not exactly")
        self.assert_refused(
            commitlint_with("  ignores: [", "  ignores: [isRelease, "), "ignores is not exactly"
        )

    def test_a_header_limit_that_is_not_a_whole_number(self) -> None:
        self.assert_refused(
            commitlint_with("[2, 'always', 100],\n    'scope", "[2, 'always', LIMIT],\n    'scope"),
            "'header-max-length' is not [2, 'always', N]",
        )

    def test_an_unclosed_array_or_comment(self) -> None:
        self.assert_refused(
            COMMITLINT_TODAY[: COMMITLINT_TODAY.index("    'header-max-length'") - 8],
            "is not closed",
        )
        self.assert_refused(
            commitlint_with("        'app',\n", "        'app', /* open\n"), "is not closed"
        )
        self.assert_refused(commitlint_with("        'app',\n", "        'app,\n"), "is not closed")


class ReleasePleaseTest(unittest.TestCase):
    def test_sections_title_and_extra_files(self) -> None:
        parsed = fs.parse_release_please(docs_fixture.RELEASE_PLEASE)
        self.assertEqual(parsed.visible, ("feat", "fix", "docs"))
        self.assertEqual(parsed.hidden, ("build", "chore", "ci", "test"))
        self.assertEqual(parsed.title_pattern, "chore(release): release${component} ${version}")
        self.assertEqual(parsed.extra_files[1], {"type": "generic", "path": "README.md"})

    def test_a_duplicate_type(self) -> None:
        text = docs_fixture.RELEASE_PLEASE.replace('"type": "test"', '"type": "ci"')
        with self.assertRaisesRegex(SourceShapeError, "lists the type ci twice"):
            fs.parse_release_please(text)

    def test_missing_or_malformed_sections(self) -> None:
        config = json.loads(docs_fixture.RELEASE_PLEASE)
        del config["changelog-sections"]
        with self.assertRaisesRegex(SourceShapeError, "changelog-sections is missing"):
            fs.parse_release_please(json.dumps(config))
        config = json.loads(docs_fixture.RELEASE_PLEASE)
        config["changelog-sections"][0]["emoji"] = "x"
        with self.assertRaisesRegex(SourceShapeError, "is not {type, section, hidden"):
            fs.parse_release_please(json.dumps(config))
        with self.assertRaisesRegex(SourceShapeError, "is not JSON"):
            fs.parse_release_please("{")

    def test_a_missing_title_pattern_or_extra_files(self) -> None:
        config = json.loads(docs_fixture.RELEASE_PLEASE)
        del config["pull-request-title-pattern"]
        with self.assertRaisesRegex(SourceShapeError, "pull-request-title-pattern"):
            fs.parse_release_please(json.dumps(config))
        config = json.loads(docs_fixture.RELEASE_PLEASE)
        config["packages"]["."]["extra-files"] = "README.md"
        with self.assertRaisesRegex(SourceShapeError, "extra-files"):
            fs.parse_release_please(json.dumps(config))


class ManifestTest(unittest.TestCase):
    def test_the_version(self) -> None:
        self.assertEqual(fs.parse_manifest('{".":"1.0.1"}\n'), "1.0.1")

    def test_an_extra_key_or_a_version_that_is_not_semantic(self) -> None:
        for text, message in (
            ('{".": "1.0.1", "app": "1.0.0"}', 'exactly the key "."'),
            ('{".": "1.0"}', "is not a version X.Y.Z"),
            ('{".": "v1.0.1"}', "is not a version X.Y.Z"),
            ("[]", 'exactly the key "."'),
            ("{", "is not JSON"),
        ):
            with self.assertRaisesRegex(SourceShapeError, message):
                fs.parse_manifest(text)


class MakefileTest(unittest.TestCase):
    def setUp(self) -> None:
        self.makefile = fs.parse_makefile(docs_fixture.MAKEFILE)

    def test_targets_help_prerequisites_and_phony(self) -> None:
        targets = self.makefile.targets
        self.assertNotIn("SHELL", targets)
        self.assertNotIn("VENV", targets)
        self.assertNotIn(".PHONY", targets)
        self.assertEqual(targets["test"].prereqs, ("test-tools", "test-core", "test-ui"))
        self.assertEqual(targets["test"].help, "Every fast suite")
        self.assertEqual(targets["help"].line, 6)
        self.assertEqual(self.makefile.phony, frozenset(targets))

    def test_backslash_continuations_are_joined(self) -> None:
        recipe = self.makefile.targets["test-core"].recipe
        self.assertEqual(len(recipe), 2)
        self.assertEqual(
            recipe[0][1],
            "cd packages/mm_core && dart test --coverage=coverage && dart run coverage:format_coverage --lcov",
        )

    def test_a_target_defined_twice(self) -> None:
        with self.assertRaisesRegex(SourceShapeError, "lint is defined twice"):
            fs.parse_makefile(docs_fixture.MAKEFILE + "lint: ## again\n\ttrue\n")
        with self.assertRaisesRegex(SourceShapeError, "has no targets"):
            fs.parse_makefile("A := 1\n")

    def test_coverage_gates(self) -> None:
        gates = fs.coverage_gates(self.makefile)
        self.assertEqual((gates["test-core"].lines, gates["test-core"].branches), (100, None))
        self.assertEqual(gates["test-ui"].lines, 95)
        self.assertEqual(gates["test-app"].lines, 90)
        functions = gates["test-functions"]
        self.assertEqual(
            (functions.lines, functions.branches, functions.functions), (100, 100, 100)
        )

    def test_coverage_gate_errors(self) -> None:
        doubled = docs_fixture.MAKEFILE.replace(
            "app/coverage/lcov.info --min 90\n",
            "app/coverage/lcov.info --min 90\n\tpython3 tool/coverage/check.py x --min 1\n",
        )
        with self.assertRaisesRegex(
            SourceShapeError, "test-app calls tool/coverage/check.py 2 times"
        ):
            fs.coverage_gates(fs.parse_makefile(doubled))
        with self.assertRaisesRegex(SourceShapeError, "test-ui's --min is '9.5'"):
            fs.coverage_gates(
                fs.parse_makefile(docs_fixture.MAKEFILE.replace("--min 95", "--min 9.5"))
            )
        with self.assertRaisesRegex(SourceShapeError, "test-ui has no --min"):
            fs.coverage_gates(
                fs.parse_makefile(docs_fixture.MAKEFILE.replace("--min 95", "--min-branches 95"))
            )
        with self.assertRaisesRegex(SourceShapeError, "has no target test-app"):
            fs.coverage_gates(
                fs.parse_makefile(docs_fixture.MAKEFILE.replace("test-app:", "test-apps:"))
            )

    def test_test_web_steps(self) -> None:
        self.assertEqual(
            fs.test_web_steps(self.makefile), ("npm run check", "npm test", "npm run build")
        )

    def test_test_web_shapes_it_refuses(self) -> None:
        for old, new in (
            ("cd website && npm run check", "cd website && npm ci && npm run check"),
            ("cd website && npm run check", "npm run check"),
            ("\t  && npm run build\n", "\t  && npm run build\n\tnpm run preview\n"),
        ):
            makefile = fs.parse_makefile(docs_fixture.MAKEFILE.replace(old, new))
            with self.assertRaisesRegex(SourceShapeError, "test_web_steps"):
                fs.test_web_steps(makefile)

    def test_test_tools_dirs(self) -> None:
        self.assertEqual([d for _, d in fs.test_tools_dirs(self.makefile)], ["tool", "tool/docs"])
        odd = docs_fixture.MAKEFILE.replace(
            "-s tool/docs -p 'test_*.py'", "-s tool/docs -p 'test_*.py' -v"
        )
        with self.assertRaisesRegex(SourceShapeError, "update test_tools_dirs"):
            fs.test_tools_dirs(fs.parse_makefile(odd))


class SuitesTest(unittest.TestCase):
    def test_journeys(self) -> None:
        self.assertEqual(fs.parse_journeys(docs_fixture.JOURNEYS), 3)

    def test_journeys_with_a_gap_a_repeat_or_none(self) -> None:
        for text, message in (
            ('test("J1 a");\ntest("J3 b");\n', "not 1 to 2"),
            ('test("J1 a");\ntest("J1 b");\n', "not 1 to 2"),
            ('test.describe("none");\n', "has no journey"),
        ):
            with self.assertRaisesRegex(SourceShapeError, message):
                fs.parse_journeys(text)

    def test_pgtap_suites_and_tests(self) -> None:
        parsed = fs.parse_pgtap(
            {"a.test.sql": "select plan(600);", "b.test.sql": "SELECT PLAN( 1374 )"}
        )
        self.assertEqual((parsed.suites, parsed.tests), (2, 1974))

    def test_pgtap_errors(self) -> None:
        for files, message in (
            ({"a.test.sql": "select 1;"}, "has 0 select plan"),
            ({"a.test.sql": "select plan(1); select plan(2);"}, "has 2 select plan"),
            ({"a.test.sql": "select no_plan();"}, "no_plan"),
            ({}, "has no"),
        ):
            with self.assertRaisesRegex(SourceShapeError, message):
                fs.parse_pgtap(files)

    def test_decisions_and_proposals(self) -> None:
        parsed = fs.parse_decisions(docs_fixture.PROJECT)
        self.assertEqual((parsed.decisions, parsed.proposals), (2, 1))

    def test_a_hundred_decisions(self) -> None:
        text = "".join(f"- D-{n:02d}: decision\n" for n in range(1, 101))
        self.assertEqual(fs.parse_decisions(text).decisions, 100)
        with self.assertRaisesRegex(SourceShapeError, "D-3 is not written with two digits"):
            fs.parse_decisions("- D-01: a\n- D-02: b\n- D-3: c\n")

    def test_decisions_with_a_gap_or_none(self) -> None:
        with self.assertRaisesRegex(SourceShapeError, "D- bullets are 01, 03"):
            fs.parse_decisions("- D-01: a\n- D-03: c\n")
        with self.assertRaisesRegex(SourceShapeError, "P- bullets are 02"):
            fs.parse_decisions("- D-01: a\n- P-02: c\n")
        with self.assertRaisesRegex(SourceShapeError, "no decision"):
            fs.parse_decisions("# Nothing\n")


class WorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.ci = fs.parse_workflow("ci.yml", docs_fixture.CI)

    def test_jobs_names_and_needs(self) -> None:
        self.assertEqual(
            [(j.id, j.name) for j in self.ci.jobs],
            [
                ("hygiene", "Repository hygiene"),
                ("dart", "Dart · ${{ matrix.package }}"),
                ("website", "Website (Astro)"),
                ("database", "Database"),
                ("passed", "CI passed"),
            ],
        )
        self.assertEqual(self.ci.job("passed").needs, ("hygiene", "dart", "website", "database"))
        self.assertEqual(self.ci.job("hygiene").line, 12)
        deploy = fs.parse_workflow("deploy.yml", docs_fixture.DEPLOY)
        self.assertEqual(deploy.job("web").needs, ("supabase",))
        with self.assertRaisesRegex(SourceShapeError, "has no job nope"):
            self.ci.job("nope")

    def test_needs_as_a_block_list_or_a_scalar(self) -> None:
        text = (
            "jobs:\n  a:\n    needs:\n      - b\n      - 'c'\n    steps: []\n  d:\n    needs: a\n"
        )
        parsed = fs.parse_workflow("w.yml", text)
        self.assertEqual(parsed.job("a").needs, ("b", "c"))
        self.assertEqual(parsed.job("d").needs, ("a",))
        with self.assertRaisesRegex(SourceShapeError, "needs: is neither a list"):
            fs.parse_workflow("w.yml", "jobs:\n  a:\n    needs:\n      b: c\n")
        with self.assertRaisesRegex(SourceShapeError, "is not closed"):
            fs.parse_workflow("w.yml", "jobs:\n  a:\n    needs: [b,\n")

    def test_runs_single_line_literal_and_folded(self) -> None:
        self.assertEqual(
            [(s.name, s.runs) for s in self.ci.job("hygiene").steps],
            [
                (None, ()),
                ("Lint (make lint)", ((18, "make lint"),)),
                ("Generated files are up to date", ((20, "make tokens-check docs-check"),)),
            ],
        )
        self.assertEqual(
            self.ci.job("database").runs, ((59, "# The pgTAP suites."), (60, "make test-db"))
        )
        self.assertEqual(
            [cmd for _, cmd in self.ci.job("website").runs],
            ["npm ci", "npm run check", "npm test", "npm run build"],
        )
        self.assertEqual(self.ci.job("dart").runs, ((32, 'make "$TARGET"'),))

    def test_env_pins_at_workflow_and_job_level(self) -> None:
        self.assertEqual(
            [(p.name, p.value, p.line) for p in self.ci.env],
            [
                ("FLUTTER_VERSION", "3.47.9", 7),
                ("DENO_VERSION", "2.9.6", 8),
                ("SUPABASE_CLI_VERSION", "2.122.1", 9),
            ],
        )
        job_level = fs.parse_workflow(
            "s.yml", 'jobs:\n  a:\n    env:\n      DENO_VERSION: "2.9.6" # pin\n'
        )
        self.assertEqual([(p.name, p.value) for p in job_level.env], [("DENO_VERSION", "2.9.6")])

    def test_tool_inputs_and_the_setup_cli_version_under_its_uses(self) -> None:
        self.assertEqual(
            [(p.name, p.value) for p in self.ci.inputs],
            [
                ("flutter-version", "${{ env.FLUTTER_VERSION }}"),
                ("setup-cli version", "${{ env.SUPABASE_CLI_VERSION }}"),
                ("deno-version", "${{ env.DENO_VERSION }}"),
            ],
        )
        deploy = fs.parse_workflow("deploy.yml", docs_fixture.DEPLOY)
        self.assertEqual(
            [(p.name, p.line) for p in deploy.inputs],
            [("flutter-version", 15), ("setup-cli version", 22)],
        )
        other = "jobs:\n  a:\n    steps:\n      - uses: actions/setup-node@x\n        with:\n          version: 22\n"
        self.assertEqual(fs.parse_workflow("w.yml", other).inputs, ())

    def test_a_workflow_without_jobs(self) -> None:
        self.assertEqual(fs.parse_workflow("w.yml", "name: x\n").jobs, ())


class DependabotTest(unittest.TestCase):
    def test_prefixes_and_scopes(self) -> None:
        updates = fs.parse_dependabot(docs_fixture.DEPENDABOT)
        self.assertEqual(
            [(u.ecosystem, u.prefix, u.include_scope, u.line) for u in updates],
            [("github-actions", "ci", True, 6), ("npm", "chore", True, 11)],
        )

    def test_an_entry_without_a_prefix_or_no_entry(self) -> None:
        with self.assertRaisesRegex(SourceShapeError, "the npm entry on line 2 has no prefix"):
            fs.parse_dependabot("updates:\n  - package-ecosystem: npm\n    directory: /\n")
        with self.assertRaisesRegex(SourceShapeError, "no `- package-ecosystem:`"):
            fs.parse_dependabot("version: 2\n")


class ToolchainTest(unittest.TestCase):
    def test_nvmrc(self) -> None:
        self.assertEqual(fs.parse_nvmrc("22.23.4\n"), "22.23.4")
        with self.assertRaisesRegex(SourceShapeError, "not one version"):
            fs.parse_nvmrc("lts/*\n")

    def test_pubspec_sdk_and_workspace(self) -> None:
        root = docs_fixture.FILES["pubspec.yaml"]
        self.assertEqual(fs.parse_pubspec_sdk("pubspec.yaml", root), "3.13.0")
        self.assertEqual(fs.parse_workspace(root), ("app", "packages/mm_core"))
        with self.assertRaisesRegex(SourceShapeError, "a/pubspec.yaml: has no `environment:`"):
            fs.parse_pubspec_sdk("a/pubspec.yaml", "environment:\n  sdk: '>=3.0.0 <4.0.0'\n")
        with self.assertRaisesRegex(SourceShapeError, "no `workspace:`"):
            fs.parse_workspace("name: x\n")

    def test_python_floor(self) -> None:
        self.assertEqual(fs.parse_python_floor(docs_fixture.FILES["pyproject.toml"]), "3.12")
        disagreeing = docs_fixture.FILES["pyproject.toml"].replace('"py312"\n', '"py313"\n')
        with self.assertRaisesRegex(SourceShapeError, "black targets py312 but ruff py313"):
            fs.parse_python_floor(disagreeing)
        with self.assertRaisesRegex(SourceShapeError, "needs black target-version"):
            fs.parse_python_floor("[tool.black]\n")
        with self.assertRaisesRegex(SourceShapeError, "is not TOML"):
            fs.parse_python_floor("[tool")
        with self.assertRaisesRegex(SourceShapeError, "is not pyXY"):
            fs.parse_python_floor(
                '[tool.black]\ntarget-version = ["3"]\n[tool.ruff]\ntarget-version = "3"\n'
            )

    def test_app_majors(self) -> None:
        self.assertEqual(
            fs.parse_app_majors(docs_fixture.FILES["app/pubspec.yaml"]),
            {"flutter_riverpod": 3, "go_router": 18, "supabase_flutter": 2},
        )
        with self.assertRaisesRegex(SourceShapeError, "no `go_router: \\^X.Y.Z`"):
            fs.parse_app_majors("dependencies:\n  flutter_riverpod: ^3.0.0\n  go_router: any\n")

    def test_formal_pins(self) -> None:
        pins = fs.parse_formal_pins(
            docs_fixture.INSTALL, "z3-solver==5.3.3.0 \\\n", "leanprover/lean4:v4.35.0\n"
        )
        self.assertEqual(
            (pins.tla, pins.tlc, pins.lean, pins.lean434, pins.bend, pins.z3, pins.lean_toolchain),
            ("1.7.4", "2.19", "4.35.0", "4.34.0", "2.0.39", "5.3.3.0", "4.35.0"),
        )
        self.assertEqual(pins.sha256["BEND"][:8], "6cf462fd")

    def test_formal_pin_errors(self) -> None:
        z3, lean = "z3-solver==1.0\n", "leanprover/lean4:v4.35.0\n"
        with self.assertRaisesRegex(SourceShapeError, "does not set BEND_SHA256"):
            fs.parse_formal_pins(docs_fixture.INSTALL.replace("BEND_SHA256", "BEND_SUM"), z3, lean)
        with self.assertRaisesRegex(SourceShapeError, "TLC2 Version X.Y"):
            fs.parse_formal_pins(
                docs_fixture.INSTALL.replace("# TLC2 Version 2.19", "# TLC"), z3, lean
            )
        with self.assertRaisesRegex(SourceShapeError, "does not pin z3-solver"):
            fs.parse_formal_pins(docs_fixture.INSTALL, "z3==1\n", lean)
        with self.assertRaisesRegex(SourceShapeError, "lean-toolchain: is not"):
            fs.parse_formal_pins(docs_fixture.INSTALL, z3, "stable\n")


class GlobTest(unittest.TestCase):
    def test_glob_match(self) -> None:
        cases = (
            ("README.md", "**/*.md", True),
            ("docs/a/b.md", "**/*.md", True),
            ("docs/a.txt", "**/*.md", False),
            ("tool/test_a.py", "tool/**/test_*.py", True),
            ("tool/docs/test_a.py", "tool/**/test_*.py", True),
            ("tool/docs/x/a.py", "tool/docs/*", False),
            ("tool/docs/a.py", "tool/docs/*", True),
            ("website/src/content/x/y.md", "website/src/content/**", True),
            ("a.yml", "?.yml", True),
            ("a+b.yml", "a+b.yml", True),
        )
        for path, pattern, expected in cases:
            self.assertEqual(fs.glob_match(path, pattern), expected, (path, pattern))


class RepoTest(unittest.TestCase):
    def test_a_source_is_read_once_and_a_failure_remembered(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tracked = docs_fixture.write(root, {".nvmrc": "lts\n"})
            repo = fs.Repo(root, tracked)
            with self.assertRaises(SourceShapeError) as first:
                repo.nvmrc()
            (root / ".nvmrc").write_text("22.0.0\n")
            with self.assertRaises(SourceShapeError) as second:
                repo.nvmrc()
            self.assertIs(first.exception, second.exception)
            self.assertEqual(repo.makefile().targets["lint"].line, 18)
            self.assertIs(repo.makefile(), repo.makefile())

    def test_missing_sources_and_the_tracked_lists(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tracked = docs_fixture.write(root, {"app/uat/tests/journeys.spec.ts": None})
            repo = fs.Repo(root, tracked)
            with self.assertRaisesRegex(SourceShapeError, "journeys.spec.ts: is missing"):
                repo.journeys()
            self.assertEqual(repo.pgtap().tests, 1974)
            self.assertEqual(
                repo.workflow_paths(),
                [
                    ".github/workflows/ci.yml",
                    ".github/workflows/deploy.yml",
                    ".github/workflows/pr-title.yml",
                ],
            )
            self.assertEqual(
                repo.member_sdks(),
                {"app/pubspec.yaml": "3.13.0", "packages/mm_core/pubspec.yaml": "3.13.0"},
            )
            self.assertEqual(
                repo.tracked_matching("tool/**/test_*.py"),
                ["tool/docs/test_docs.py", "tool/test_guard.py"],
            )
            self.assertEqual(repo.decisions().decisions, 2)
            self.assertEqual(repo.dependabot()[0].prefix, "ci")
            self.assertEqual(repo.formal_pins().bend, "2.0.39")
            self.assertEqual(repo.app_majors()["go_router"], 18)
            self.assertEqual(repo.python_floor(), "3.12")
            self.assertEqual(repo.manifest(), "1.2.3")

    def test_ci_versions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tracked = docs_fixture.write(
                root, docs_fixture.edited(".github/workflows/ci.yml", "  DENO_VERSION: 2.9.6\n", "")
            )
            with self.assertRaisesRegex(SourceShapeError, "does not set DENO_VERSION"):
                fs.Repo(root, tracked).ci_versions()
            tracked = docs_fixture.write(
                root,
                docs_fixture.edited(
                    ".github/workflows/ci.yml",
                    "    runs-on: ubuntu-24.04\n    steps:\n      - uses: actions",
                    "    runs-on: ubuntu-24.04\n    env:\n      DENO_VERSION: 1.0.0\n    steps:\n      - uses: actions",
                ),
            )
            with self.assertRaisesRegex(SourceShapeError, "sets DENO_VERSION twice"):
                fs.Repo(root, tracked).ci_versions()


if __name__ == "__main__":
    unittest.main()
