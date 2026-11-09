"""Tests for the design-token builder (python3 -m unittest discover -s tool/design -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import build_tokens as bt

SOURCE = json.loads(bt.SOURCE.read_text(encoding="utf-8"))


def load_variant(mutate) -> dict:
    """Validates a mutated copy of the real token file."""
    data = copy.deepcopy(SOURCE)
    mutate(data)
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "tokens.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return bt.load(path)


class ColourMathTest(unittest.TestCase):
    def test_contrast_of_known_pairs(self) -> None:
        self.assertAlmostEqual(bt.contrast_ratio("#000000", "#FFFFFF"), 21.0, places=2)
        self.assertAlmostEqual(bt.contrast_ratio("#FFFFFF", "#FFFFFF"), 1.0, places=6)
        self.assertAlmostEqual(bt.contrast_ratio("#1D3F8F", "#FFFFFF"), 9.72, places=2)


class ValidationTest(unittest.TestCase):
    def test_the_real_tokens_are_valid(self) -> None:
        model = bt.load()
        self.assertEqual(list(model["modes"]), list(bt.COLOR_MODES))
        self.assertIn(("latin", "body"), model["typography"])

    def assert_rejected(self, mutate, fragment: str) -> None:
        with self.assertRaises(bt.TokenError) as caught:
            load_variant(mutate)
        self.assertIn(fragment, str(caught.exception))

    def test_a_missing_mode_is_rejected(self) -> None:
        self.assert_rejected(lambda d: d["color"].pop("dark"), "color.dark is missing")

    def test_modes_must_share_roles(self) -> None:
        self.assert_rejected(lambda d: d["color"]["dark"].pop("credit"), "same roles")

    def test_components_must_match_hex(self) -> None:
        def mutate(d):
            d["color"]["light"]["ink"]["$value"]["components"] = [1, 1, 1]

        self.assert_rejected(mutate, "disagree")

    def test_hex_must_be_six_digits(self) -> None:
        def mutate(d):
            d["color"]["light"]["ink"]["$value"]["hex"] = "#12345G"

        self.assert_rejected(mutate, "#RRGGBB")

    def test_colours_must_be_opaque_srgb(self) -> None:
        def translucent(d):
            d["color"]["light"]["ink"]["$value"]["alpha"] = 0.5

        self.assert_rejected(translucent, "opaque")

        def p3(d):
            d["color"]["light"]["ink"]["$value"]["colorSpace"] = "display-p3"

        self.assert_rejected(p3, "srgb")

    def test_low_contrast_fails_the_build(self) -> None:
        def mutate(d):
            d["color"]["light"]["inkMuted"]["$value"] = {
                "colorSpace": "srgb",
                "components": [0.6667, 0.6667, 0.6667],
                "alpha": 1,
                "hex": "#AAAAAA",
            }

        self.assert_rejected(mutate, "inkMuted on bg")

    def test_high_contrast_modes_need_seven_to_one(self) -> None:
        def mutate(d):
            # 5.74:1 on white: fine for AA, not for the high-contrast mode.
            d["color"]["lightHighContrast"]["inkMuted"]["$value"] = {
                "colorSpace": "srgb",
                "components": [0.4392, 0.4392, 0.4392],
                "alpha": 1,
                "hex": "#707070",
            }

        self.assert_rejected(mutate, "needs 7.0:1")

    def test_dimensions_and_durations_need_units(self) -> None:
        def dimension(d):
            d["space"]["s4"]["$value"] = {"value": 16, "unit": "rem"}

        self.assert_rejected(dimension, "unit: px")

        def duration(d):
            d["duration"]["quick"]["$value"] = {"value": 0.1, "unit": "s"}

        self.assert_rejected(duration, "unit: ms")

    def test_typography_rules(self) -> None:
        def small(d):
            d["typography"]["latin"]["caption"]["$value"]["fontSize"]["value"] = 11

        self.assert_rejected(small, "smaller than 12 px")

        def weight(d):
            d["typography"]["latin"]["body"]["$value"]["fontWeight"] = 450

        self.assert_rejected(weight, "multiple of 100")

        def family(d):
            d["typography"]["latin"]["body"]["$value"]["fontFamily"] = "{font.family.mono}"

        self.assert_rejected(family, "unknown family mono")

        def literal(d):
            d["typography"]["latin"]["body"]["$value"]["fontFamily"] = "Arial"

        self.assert_rejected(literal, "must reference")

    def test_fonts_must_be_bundled(self) -> None:
        def mutate(d):
            d["font"]["family"]["latin"]["$value"] = ["Inter", "sans-serif"]

        self.assert_rejected(mutate, "mm_ui bundles")

    def test_easings_have_four_numbers(self) -> None:
        def mutate(d):
            d["easing"]["standard"]["$value"] = [0.2, 0, 0]

        self.assert_rejected(mutate, "four numbers")


class OutputTest(unittest.TestCase):
    def setUp(self) -> None:
        self.model = bt.load()

    def test_dart_declares_every_mode_and_role(self) -> None:
        dart = bt.render_dart(self.model)
        for mode in bt.COLOR_MODES:
            self.assertIn(f"static const MmColorTokens {mode} = MmColorTokens(", dart)
        self.assertIn("primary: Color(0xFF1D3F8F),", dart)
        self.assertIn("static const TextStyle urduBody = TextStyle(", dart)
        self.assertIn("fontFamily: 'NotoNastaliqUrdu',", dart)
        self.assertIn("static const Duration standard = Duration(milliseconds: 200);", dart)
        self.assertIn("static const Cubic standard = Cubic(0.2, 0, 0, 1);", dart)

    def test_dart_members_are_laid_out_like_dart_format(self) -> None:
        lines = bt._members([["  /// a", "  int a;"], ["  int b;"], ["  /// c", "  int c;"]])
        self.assertEqual(lines, ["  /// a", "  int a;", "  int b;", "", "  /// c", "  int c;"])

    def test_css_covers_modes_contrast_and_motion_preferences(self) -> None:
        css = bt.render_css(self.model)
        self.assertIn("--mm-color-primary: #1D3F8F;", css)
        self.assertIn("@media (prefers-color-scheme: dark)", css)
        self.assertIn('[data-theme="dark"]', css)
        self.assertIn("@media (prefers-contrast: more) and (prefers-color-scheme: dark)", css)
        self.assertIn("--mm-duration-standard: 0ms;", css)
        self.assertIn('--mm-font-latin: "Atkinson Hyperlegible Next", Roboto, sans-serif;', css)

    def test_design_md_keeps_its_body(self) -> None:
        rendered = bt.render_design_md(self.model, "---\nname: old\n---\n\n## Overview\n\nKept.\n")
        self.assertTrue(rendered.startswith("---\nname: Maalik-e-Makaan\n"))
        self.assertTrue(rendered.endswith("\n## Overview\n\nKept.\n"))
        self.assertIn('  primary: "#1D3F8F"', rendered)
        self.assertIn('    textColor: "{colors.onPrimary}"', rendered)

    def test_design_md_needs_a_frontmatter(self) -> None:
        with self.assertRaises(bt.TokenError):
            bt.render_design_md(self.model, "# No frontmatter\n")
        with self.assertRaises(bt.TokenError):
            bt.render_design_md(self.model, "---\nname: x\n")

    def test_component_references_must_resolve(self) -> None:
        broken = {**bt.DESIGN_COMPONENTS, "ghost": {"textColor": "{colors.nope}"}}
        with (
            mock.patch.object(bt, "DESIGN_COMPONENTS", broken),
            self.assertRaises(bt.TokenError) as caught,
        ):
            bt.lint_design_components(self.model)
        self.assertIn("broken reference {colors.nope}", str(caught.exception))
        malformed = {**bt.DESIGN_COMPONENTS, "ghost": {"textColor": "{colors.ink"}}
        with (
            mock.patch.object(bt, "DESIGN_COMPONENTS", malformed),
            self.assertRaises(bt.TokenError),
        ):
            bt.lint_design_components(self.model)

    def test_component_text_needs_contrast(self) -> None:
        faint = {
            **bt.DESIGN_COMPONENTS,
            "faint": {"backgroundColor": "{colors.bg}", "textColor": "{colors.rule}"},
        }
        with (
            mock.patch.object(bt, "DESIGN_COMPONENTS", faint),
            self.assertRaises(bt.TokenError) as caught,
        ):
            bt.lint_design_components(self.model)
        self.assertIn("below 4.5:1", str(caught.exception))


class MainTest(unittest.TestCase):
    def test_the_committed_outputs_are_fresh(self) -> None:
        self.assertEqual(bt.main(["--check"]), 0)

    def test_usage_errors(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(bt.main(["--bogus"]), 2)

    def test_check_reports_stale_outputs_and_write_mode_writes(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            dart, css, design = (Path(folder) / name for name in ("t.g.dart", "t.css", "DESIGN.md"))
            design.write_text(bt.DESIGN_MD.read_text(encoding="utf-8"), encoding="utf-8")
            with mock.patch.multiple(bt, DART_OUT=dart, CSS_OUT=css, DESIGN_MD=design):
                err = io.StringIO()
                with contextlib.redirect_stderr(err):
                    self.assertEqual(bt.main(["--check"]), 1)
                self.assertIn("stale", err.getvalue())
                self.assertEqual(bt.main([]), 0)
                self.assertEqual(bt.main(["--check"]), 0)

    def test_invalid_tokens_fail_with_a_message(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "tokens.json"
            source.write_text("{}", encoding="utf-8")
            err = io.StringIO()
            with (
                mock.patch.object(bt, "SOURCE", source),
                mock.patch.object(bt, "ROOT", Path(folder)),
                contextlib.redirect_stderr(err),
            ):
                self.assertEqual(bt.main(["--check"]), 1)
            self.assertIn("color.light is missing", err.getvalue())


if __name__ == "__main__":
    unittest.main()
