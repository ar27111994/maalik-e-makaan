"""Tests for lint_hardcoded.py: each rule fires, and only where it should."""

from __future__ import annotations

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import lint_hardcoded as lint

FILE = Path("lib/widget.dart")


def rules(source: str) -> list[str]:
    return [finding.rule for finding in lint.lint_text(FILE, source)]


class RuleTest(unittest.TestCase):
    def test_colours_come_from_roles(self) -> None:
        self.assertEqual(rules("final c = Color(0xFF112233);"), ["colour"])
        self.assertEqual(rules("Color.fromARGB(255, 1, 2, 3)"), ["colour"])
        self.assertEqual(rules("Color.fromRGBO(1, 2, 3, 1)"), ["colour"])
        self.assertEqual(rules("color: Colors.red,"), ["colour"])
        self.assertEqual(rules("color: Colors.transparent,"), [])
        self.assertEqual(rules("color: context.mm.colors.primary,"), [])

    def test_font_sizes_come_from_the_text_theme(self) -> None:
        self.assertEqual(rules("TextStyle(fontSize: 14)"), ["font-size"])
        self.assertEqual(rules("TextStyle(fontSize: 13.5)"), ["font-size"])
        self.assertEqual(rules("TextStyle(fontSize: size)"), [])

    def test_spacing_and_radii_come_from_tokens(self) -> None:
        self.assertEqual(rules("padding: EdgeInsets.all(16),"), ["spacing"])
        self.assertEqual(rules("EdgeInsetsDirectional.only(start: 8)"), ["spacing"])
        self.assertEqual(rules("const SizedBox(height: 12)"), ["spacing"])
        self.assertEqual(rules("SizedBox(width: .5)"), ["spacing"])
        self.assertEqual(rules("BorderRadius.circular(12)"), ["radius"])
        self.assertEqual(rules("Radius.circular(4)"), ["radius"])
        self.assertEqual(rules("EdgeInsets.all(MmSpace.s4)"), [])
        self.assertEqual(rules("SizedBox(height: MmSpace.s3)"), [])
        self.assertEqual(rules("BorderRadius.circular(MmRadius.md)"), [])

    def test_zero_is_always_allowed(self) -> None:
        self.assertEqual(rules("EdgeInsets.all(0)"), [])
        self.assertEqual(rules("SizedBox(height: 0)"), [])
        self.assertEqual(rules("SizedBox(height: 0.0)"), [])
        self.assertEqual(rules("Duration(milliseconds: 0)"), [])

    def test_durations_come_from_motion_tokens(self) -> None:
        self.assertEqual(rules("Duration(milliseconds: 200)"), ["motion"])
        self.assertEqual(rules("MmMotion.of(context).standard"), [])

    def test_geometry_is_directional(self) -> None:
        self.assertEqual(rules("EdgeInsets.only(left: x)"), ["rtl"])
        self.assertEqual(rules("EdgeInsets.fromLTRB(a, b, c, d)"), ["rtl"])
        self.assertEqual(rules("alignment: Alignment.centerLeft,"), ["rtl"])
        self.assertEqual(rules("Positioned(right: x, child: c)"), ["rtl"])
        self.assertEqual(rules("EdgeInsetsDirectional.only(start: x)"), [])
        self.assertEqual(rules("AlignmentDirectional.centerStart"), [])
        self.assertEqual(rules("Alignment.center"), [])
        self.assertEqual(rules("PositionedDirectional(start: x, child: c)"), [])

    def test_one_line_can_break_several_rules(self) -> None:
        self.assertEqual(
            rules("Container(padding: EdgeInsets.all(8), color: Colors.red)"),
            ["colour", "spacing"],
        )


class ExemptionTest(unittest.TestCase):
    def test_comments_are_ignored(self) -> None:
        self.assertEqual(rules("// Use EdgeInsets.all(16) here"), [])
        self.assertEqual(rules("/// Colors.red is wrong"), [])
        self.assertEqual(rules(" * EdgeInsets.all(16)"), [])
        self.assertEqual(rules("final a = x; // EdgeInsets.all(16)"), [])

    def test_a_double_slash_inside_a_string_is_code(self) -> None:
        self.assertEqual(rules("f('https://x', EdgeInsets.all(16));"), ["spacing"])
        self.assertEqual(rules('f("a\\"//", Colors.red);'), ["colour"])

    def test_an_allowance_needs_a_reason(self) -> None:
        self.assertEqual(rules("Colors.black, // design-lint: allow Material scrim"), [])
        self.assertEqual(rules("Colors.black, // design-lint: allow"), ["allow"])


class FilesTest(unittest.TestCase):
    def test_generated_files_are_skipped_and_main_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "l10n" / "generated").mkdir(parents=True)
            (root / "tokens.g.dart").write_text("Color(0xFF000000);", encoding="utf-8")
            (root / "l10n" / "generated" / "x.dart").write_text("Colors.red;", encoding="utf-8")
            clean = root / "clean.dart"
            clean.write_text("EdgeInsets.all(MmSpace.s4);", encoding="utf-8")
            self.assertEqual(lint.dart_files([root]), [clean])
            # Files can be named directly (the git hook passes staged files).
            self.assertEqual(lint.dart_files([clean, root / "tokens.g.dart"]), [clean])
            self.assertEqual(lint.dart_files([root / "notes.md"]), [])

            out = io.StringIO()
            with redirect_stdout(out):
                self.assertEqual(lint.main([str(root)]), 0)
            self.assertIn("1 files clean", out.getvalue())

            (root / "bad.dart").write_text("SizedBox(height: 8);", encoding="utf-8")
            out, err = io.StringIO(), io.StringIO()
            with redirect_stdout(out), redirect_stderr(err):
                self.assertEqual(lint.main([str(root)]), 1)
            self.assertIn("bad.dart:1: [spacing] use MmSpace", out.getvalue())
            self.assertIn("1 design-lint finding(s)", err.getvalue())

    def test_a_missing_directory_is_a_usage_error(self) -> None:
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(lint.main(["no/such/dir"]), 2)
        self.assertIn("no such file or directory", err.getvalue())

    def test_findings_print_paths_relative_to_the_repository(self) -> None:
        finding = lint.Finding(lint.ROOT / "app/lib/a.dart", 3, "rtl", "  x  ", "hint")
        self.assertEqual(str(finding), "app/lib/a.dart:3: [rtl] hint: x")


if __name__ == "__main__":
    unittest.main()
