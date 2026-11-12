"""Tests for the command line (python3 -m unittest discover -s tool/docs -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import docs_fixture
import fact_registry
import sync_facts

GIT = shutil.which("git")


class CommandLineCase(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def build(
        self, changes: dict[str, str | None] | None = None, *, current: bool = True
    ) -> list[str]:
        """The fixture repository, with its generated facts made current first."""
        tracked = docs_fixture.write(self.root)
        if current:
            code, _, err = self.run_main("--write", tracked=tracked)
            self.assertEqual(code, 0, err)
        for path, text in (changes or {}).items():
            target = self.root / path
            if text is None:
                target.unlink()
                tracked.remove(path)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            if path not in tracked:
                tracked.append(path)
        return sorted(tracked)

    def run_main(self, *argv: str, tracked: list[str] | None = None) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = sync_facts.main(list(argv), root=self.root, tracked=tracked)
        return code, out.getvalue(), err.getvalue()

    def read(self, path: str) -> str:
        return (self.root / path).read_text(encoding="utf-8")

    def current(self, path: str) -> str:
        """The file as it is now in the temporary repository (after the first --write)."""
        return self.read(path)


class WriteAndCheckTest(CommandLineCase):
    def test_write_then_check_passes(self) -> None:
        tracked = docs_fixture.write(self.root)
        code, out, _ = self.run_main("--write", tracked=tracked)
        self.assertEqual(code, 0)
        self.assertIn(
            "make docs: rewrote README.md (coverage-ui, coverage-app, pgtap-count, uat-journeys)",
            out,
        )
        self.assertIn("2 suites, 1,974 tests", self.read("README.md"))
        code, out, err = self.run_main("--check", tracked=tracked)
        self.assertEqual((code, err), (0, ""))
        self.assertIn("11 generated facts and 14 checks agree with their sources", out)

    def test_a_second_write_changes_no_file(self) -> None:
        tracked = self.build()
        before = {
            p: ((self.root / p).read_bytes(), (self.root / p).stat().st_mtime_ns) for p in tracked
        }
        code, out, _ = self.run_main("--write", tracked=tracked)
        self.assertEqual((code, out), (0, "make docs: every generated fact is current\n"))
        after = {
            p: ((self.root / p).read_bytes(), (self.root / p).stat().st_mtime_ns) for p in tracked
        }
        self.assertEqual(before, after)

    def test_a_stale_fact_fails_with_a_diff_and_leaves_the_file_alone(self) -> None:
        tracked = self.build()
        readme = self.current("README.md")
        stale = readme.replace("2 suites, 1,974 tests", "3 suites, 2,000 tests")
        (self.root / "README.md").write_text(stale, encoding="utf-8")
        code, out, err = self.run_main("--check", tracked=tracked)
        self.assertEqual((code, out), (1, ""))
        self.assertIn("docs-check: 1 generated fact is stale:", err)
        self.assertIn("--- a/README.md\n+++ b/README.md (after make docs)\n", err)
        self.assertIn("-- the pgTAP suites (", err)
        self.assertIn("+- the pgTAP suites (", err)
        self.assertIn(
            "Run `make docs` to rewrite the generated facts (it also runs Prettier).", err
        )
        self.assertEqual(self.read("README.md"), stale)
        code, _, _ = self.run_main("--write", tracked=tracked)
        self.assertEqual((code, self.read("README.md")), (0, readme))

    def test_a_copy_that_disagrees_is_listed_for_fixing_by_hand(self) -> None:
        tracked = self.build()
        text = self.current("README.md").replace("Flutter 3.47 (Dart", "Flutter 3.46 (Dart")
        (self.root / "README.md").write_text(text, encoding="utf-8")
        code, _, err = self.run_main("--check", tracked=tracked)
        self.assertEqual(code, 1)
        self.assertIn("docs-check: 1 copy disagrees with its source; fix it by hand:", err)
        self.assertIn(
            "  README.md:13: says Flutter 3.46; .github/workflows/ci.yml's FLUTTER_VERSION is 3.47.9",
            err,
        )
        self.assertIn("Fix the copies listed above; `make docs` does not write them.", err)

    def test_stale_facts_and_copies_together(self) -> None:
        tracked = self.build()
        text = self.current("README.md").replace("Flutter 3.47 (Dart", "Flutter 3.46 (Dart")
        text = text.replace("three<!--", "four<!--")
        (self.root / "README.md").write_text(text, encoding="utf-8")
        code, _, err = self.run_main("--check", tracked=tracked)
        self.assertEqual(code, 1)
        self.assertIn("1 generated fact is stale", err)
        self.assertIn("1 copy disagrees", err)
        self.assertIn("then fix the copies listed above.", err)

    def test_a_target_without_its_marker_fails_with_m8(self) -> None:
        tracked = self.build({"docs/uat.md": "# UAT\n\nThree journeys.\n"})
        for mode in ("--check", "--write"):
            code, _, err = self.run_main(mode, tracked=tracked)
            self.assertEqual(code, 1, mode)
            self.assertIn(
                "M8 docs/uat.md:1: has no docs:uat-journeys span; restore it from git", err
            )

    def test_a_stray_marker_fails_with_m7(self) -> None:
        tracked = self.build(
            {
                "docs/other.md": "# Other\n\nSee <!-- docs:uat-journeys -->3<!-- /docs:uat-journeys -->.\n"
            }
        )
        code, _, err = self.run_main("--check", tracked=tracked)
        self.assertEqual(code, 1)
        self.assertIn("M7 docs/other.md:3: docs:uat-journeys is not expected here", err)
        self.assertIn("docs/agents/conventions.md, Generated files", err)

    def test_a_broken_marker_stops_write_from_writing_anything(self) -> None:
        tracked = self.build()
        stale = self.current("README.md").replace("2 suites, 1,974 tests", "old")
        (self.root / "README.md").write_text(stale, encoding="utf-8")
        broken = self.current("docs/uat.md").replace("<!-- /docs:uat-journeys -->", "")
        (self.root / "docs/uat.md").write_text(broken, encoding="utf-8")
        code, out, err = self.run_main("--write", tracked=tracked)
        self.assertEqual((code, out), (1, ""))
        self.assertIn("M1 docs/uat.md:3: docs:uat-journeys has no close marker", err)
        self.assertIn("make docs: wrote nothing", err)
        self.assertEqual(self.read("README.md"), stale)

    def test_a_source_that_changed_shape_is_named_and_the_rest_still_checked(self) -> None:
        tracked = self.build()
        scopes = docs_fixture.COMMITLINT.replace(
            "    'scope-enum': [\n      2,\n      'always',\n      [",
            "    'scope-enum': [\n      2,\n      'always',\n      [\n        ...shared,",
        )
        (self.root / "commitlint.config.mjs").write_text(scopes, encoding="utf-8")
        stale = self.current("README.md").replace("2 suites, 1,974 tests", "old")
        (self.root / "README.md").write_text(stale, encoding="utf-8")
        code, _, err = self.run_main("--check", tracked=tracked)
        self.assertEqual(code, 1)
        self.assertIn("source: commitlint.config.mjs: 'scope-enum' has the item '...shared'", err)
        self.assertIn(
            "  not checked: G1 commit-scopes, G2 commit-types-and-scopes, C1 changelog-sections,"
            " C2 release-title-ignored, C3 header-length, C4 dependabot-commits",
            err,
        )
        self.assertIn("--- a/README.md", err)
        code, out, err = self.run_main("--write", tracked=tracked)
        self.assertEqual((code, out), (1, ""))
        self.assertIn("make docs: wrote nothing", err)
        self.assertEqual(self.read("README.md"), stale)

    def test_line_endings_and_other_bytes_are_kept(self) -> None:
        tracked = self.build()
        crlf = self.current("docs/uat.md").replace("\n", "\r\n").replace("three<!--", "two<!--")
        (self.root / "docs/uat.md").write_bytes(crlf.encode("utf-8"))
        code, _, _ = self.run_main("--write", tracked=tracked)
        self.assertEqual(code, 0)
        self.assertEqual(
            (self.root / "docs/uat.md").read_bytes(),
            crlf.replace("two<!--", "three<!--").encode("utf-8"),
        )


class PathsTest(CommandLineCase):
    def test_unrelated_paths_return_at_once_without_reading_a_source(self) -> None:
        tracked = self.build({"commitlint.config.mjs": "export default {};\n"})
        code, out, err = self.run_main(
            "--check", "--paths", "app/lib/main.dart", "website/src/x.ts", tracked=tracked
        )
        self.assertEqual((code, out, err), (0, "", ""))
        self.assertEqual(self.run_main("--check", "--paths", tracked=tracked), (0, "", ""))

    def test_a_source_a_target_or_the_tool_runs_the_check(self) -> None:
        tracked = self.build({"commitlint.config.mjs": "export default {};\n"})
        for path in (
            "commitlint.config.mjs",
            "./docs/uat.md",
            "tool/docs/fact_registry.py",
            "docs/any.md",
            ".github/workflows/new.yml",
        ):
            code, _, err = self.run_main("--check", "--paths", "app/x.dart", path, tracked=tracked)
            self.assertEqual(code, 1, path)
            self.assertIn("source: commitlint.config.mjs:", err)

    def test_relevant(self) -> None:
        self.assertTrue(sync_facts.relevant(["Makefile"]))
        self.assertTrue(sync_facts.relevant(["supabase/tests/database/03_x.test.sql"]))
        self.assertFalse(sync_facts.relevant(["supabase/migrations/1_x.sql", "app/lib/a.dart"]))
        # A marker can be in any Markdown or YAML file, and llms.txt must hold none (M16).
        for path in ("llms.txt", ".github/ISSUE_TEMPLATE/bug_report.yml", "app/l10n.yaml"):
            self.assertTrue(sync_facts.relevant([path]), path)


class ListAndUsageTest(CommandLineCase):
    def test_list_files(self) -> None:
        code, out, _ = self.run_main("--list-files")
        self.assertEqual(code, 0)
        self.assertEqual(
            out.splitlines(), sorted({p for f in fact_registry.FACTS for p in f.targets})
        )
        self.assertIn(".github/workflows/pr-title.yml", out.splitlines())

    def test_list_names_every_fact_and_check(self) -> None:
        code, out, _ = self.run_main("--list")
        self.assertEqual(code, 0)
        for item in fact_registry.FACTS:
            self.assertIn(f"{item.ident:<4}{item.key}", out)
        for item in fact_registry.CHECKS:
            self.assertIn(f"{item.ident:<4}{item.name}", out)

    def test_usage_errors_exit_2(self) -> None:
        for argv in (
            ["--bogus"],
            ["--write", "--check"],
            [],
            ["--write", "--paths", "a"],
            ["--list", "x"],
        ):
            code, _, err = self.run_main(*argv)
            self.assertEqual(code, 2, argv)
            self.assertIn("usage:", err)

    def test_help_exits_0(self) -> None:
        code, out, _ = self.run_main("--help")
        self.assertEqual(code, 0)
        self.assertIn("--list-files", out)


@unittest.skipIf(GIT is None, "git is not installed")
class GitTest(CommandLineCase):
    def git(self, *args: str) -> None:
        env = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}
        subprocess.run(  # noqa: S603 - fixed arguments, a temporary repository
            [GIT or "git", "-C", str(self.root), *args], check=True, capture_output=True, env=env
        )

    def test_the_tracked_files_come_from_git(self) -> None:
        docs_fixture.write(self.root)
        self.git("init", "--quiet")
        self.git("add", "--all")
        (self.root / "untracked.md").write_text("x <!-- docs:nope -->1<!-- /docs:nope -->\n")
        self.assertEqual(self.run_main("--write")[0], 0)
        code, out, _ = self.run_main("--check")
        self.assertEqual(code, 0, out)

    def test_outside_a_repository_it_says_so(self) -> None:
        code, _, err = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("cannot list the tracked files", err)


if __name__ == "__main__":
    unittest.main()
