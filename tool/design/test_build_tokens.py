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
        self.assertIn("fontFamily: 'NotoSansArabic',", dart)
        # Nastaliq only for the Urdu wordmark: one family, one style.
        self.assertIn("static const String urduWordmark = 'NotoNastaliqUrdu';", dart)
        self.assertIn("static const TextStyle urduWordmark = TextStyle(", dart)
        self.assertEqual(dart.count("fontFamily: 'NotoNastaliqUrdu',"), 1)
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
        # Custom properties are named in kebab case, as every other group's are.
        self.assertIn('--mm-font-urdu-wordmark: "Noto Nastaliq Urdu", ', css)
        self.assertNotIn("--mm-font-urduWordmark", css)
        # Figures with Urdu words: both stacks' named faces before the one generic family.
        self.assertIn(
            '--mm-font-latin-urdu: "Atkinson Hyperlegible Next", Roboto, "Noto Sans Arabic", '
            '"Segoe UI", Tahoma, sans-serif;',
            css,
        )

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
            dart, css, design, email, templates = (
                Path(folder) / name for name in ("t.g.dart", "t.css", "DESIGN.md", "t.ts", "mail")
            )
            design.write_text(bt.DESIGN_MD.read_text(encoding="utf-8"), encoding="utf-8")
            templates.mkdir()
            with mock.patch.multiple(
                bt,
                DART_OUT=dart,
                CSS_OUT=css,
                DESIGN_MD=design,
                EMAIL_TS_OUT=email,
                EMAIL_TEMPLATES=templates,
            ):
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


# The e-mails' Urdu stack and the wordmark's, as a style attribute writes them.
EMAIL_URDU = "'Noto Sans Arabic', 'Segoe UI', Tahoma, 'Geeza Pro', sans-serif"
EMAIL_WORDMARK = "'Noto Nastaliq Urdu', 'Noto Naskh Arabic', serif"
NASTALIQ_BODY = "'Noto Nastaliq Urdu', 'Jameel Noori Nastaleeq', 'Noto Naskh Arabic', serif"
NAME = "مالکِ مکان"

# A template in the shape of supabase/templates: an English part, the wordmark in its header,
# and an Urdu part still in Nastaliq.
TEMPLATE = f"""<!doctype html>
<html lang="en">
  <body>
    <p style="font-family: Arial, sans-serif; line-height: 1.5;">Maalik-e-Makaan · <span lang="ur" dir="rtl" style="font-family: {NASTALIQ_BODY};">{NAME}</span></p>
    <div lang="ur" dir="rtl" style="padding: 8px; font-family: {NASTALIQ_BODY}; line-height: 2.2;">
      <h1 style="margin: 0; line-height: 2.2;">اپنی ای میل کی تصدیق کریں</h1>
      <p style="font-size: 16px;">{NAME} ایپ میں خوش آمدید<br><a href="{{{{ .ConfirmationURL }}}}" dir="ltr">{{{{ .ConfirmationURL }}}}</a></p>
      <hr style="border: 0;"/>
    </div>
  </body>
</html>
"""


class EmailTypographyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.model = bt.load()

    def test_the_urdu_stack_gains_the_email_faces_before_its_generic_family(self) -> None:
        email = bt.email_typography(self.model)
        self.assertEqual(
            email["urdu"]["fontFamily"],
            ["Noto Sans Arabic", "Segoe UI", "Tahoma", "Geeza Pro", "sans-serif"],
        )
        self.assertEqual(bt.email_stack(email["urdu"]["fontFamily"]), EMAIL_URDU)
        # The wordmark keeps the tokens' stack as it is.
        self.assertEqual(
            email["urduWordmark"]["fontFamily"], self.model["families"]["urduWordmark"]
        )
        self.assertEqual(bt.email_stack(email["urduWordmark"]["fontFamily"]), EMAIL_WORDMARK)

    def test_line_heights_follow_the_urdu_styles(self) -> None:
        email = bt.email_typography(self.model)
        typography = self.model["typography"]
        self.assertEqual(email["urdu"]["lineHeight"], 1.65)
        self.assertAlmostEqual(
            email["urdu"]["lineHeight"], typography[("urdu", "body")]["height"], 2
        )
        self.assertEqual(email["urdu"]["headingLineHeight"], 1.52)
        self.assertEqual(email["urduWordmark"]["lineHeight"], 2)

    def test_a_face_already_in_the_stack_is_not_named_twice(self) -> None:
        model = {**self.model, "families": {**self.model["families"]}}
        model["families"]["urdu"] = ["Noto Sans Arabic", "Geeza Pro", "Tahoma", "sans-serif"]
        self.assertEqual(
            bt.email_typography(model)["urdu"]["fontFamily"],
            ["Noto Sans Arabic", "Geeza Pro", "Tahoma", "sans-serif"],
        )

    def test_a_nastaliq_face_is_refused_for_urdu_text(self) -> None:
        def mutate(d):
            d["font"]["family"]["urdu"]["$value"] = [
                "Noto Sans Arabic",
                "Noto Nastaliq Urdu",
                "sans-serif",
            ]

        with self.assertRaises(bt.TokenError) as caught:
            bt.email_typography(load_variant(mutate))
        self.assertIn(
            "Noto Nastaliq Urdu: Nastaliq is for the wordmark only", str(caught.exception)
        )
        for face in ("Jameel Noori Nastaleeq", "Urdu Typesetting", "Gulzar"):
            with (
                self.subTest(face=face),
                mock.patch.object(bt, "EMAIL_URDU_FALLBACKS", (face,)),
                self.assertRaises(bt.TokenError),
            ):
                bt.email_typography(self.model)

    def test_stacks_end_with_one_generic_family(self) -> None:
        for stack in (
            ["Noto Sans Arabic"],
            ["sans-serif", "Tahoma"],
            ["Tahoma", "serif", "sans-serif"],
        ):
            model = {**self.model, "families": {**self.model["families"], "urdu": stack}}
            with self.subTest(stack=stack), self.assertRaises(bt.TokenError) as caught:
                bt.email_typography(model)
            self.assertIn(
                "font.family.urdu must end with one generic family", str(caught.exception)
            )
        model = {
            **self.model,
            "families": {**self.model["families"], "urduWordmark": ["Noto Nastaliq Urdu"]},
        }
        with self.assertRaises(bt.TokenError) as caught:
            bt.email_typography(model)
        self.assertIn("font.family.urduWordmark", str(caught.exception))

    def test_the_typescript_module_holds_the_stacks_and_line_heights(self) -> None:
        ts = bt.render_email_ts(bt.email_typography(self.model))
        self.assertTrue(ts.startswith("// GENERATED by tool/design/build_tokens.py"))
        self.assertIn(f'    fontFamily: "{EMAIL_URDU}",\n    lineHeight: 1.65,\n', ts)
        self.assertIn("    headingLineHeight: 1.52,\n", ts)
        self.assertIn(f'    fontFamily: "{EMAIL_WORDMARK}",\n    lineHeight: 2,\n', ts)
        self.assertTrue(ts.endswith("} as const;\n"))

    def test_the_wordmark_name_is_the_apps_urdu_name(self) -> None:
        self.assertEqual(bt.wordmark_name(), NAME)
        with tempfile.TemporaryDirectory() as folder:
            arb = Path(folder) / "app_ur.arb"
            arb.write_text('{"appName": "  "}', encoding="utf-8")
            with self.assertRaises(bt.TokenError):
                bt.wordmark_name(arb)


class EmailTemplateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.email = bt.email_typography(bt.load())

    def render(self, html: str) -> str:
        return bt.render_email_template(self.email, html, NAME, "t.html")

    def assert_refused(self, html: str, fragment: str) -> None:
        with self.assertRaises(bt.TokenError) as caught:
            self.render(html)
        self.assertIn(fragment, str(caught.exception))

    def test_a_nastaliq_body_is_rewritten_in_the_sans_stack(self) -> None:
        out = self.render(TEMPLATE)
        self.assertIn(
            f'<div lang="ur" dir="rtl" style="padding: 8px; font-family: {EMAIL_URDU}; '
            'line-height: 1.65;">',
            out,
        )
        self.assertIn('<h1 style="margin: 0; line-height: 1.52;">', out)
        # Nastaliq is left only on the brand name standing alone.
        self.assertIn(f'style="font-family: {EMAIL_WORDMARK};">{NAME}</span>', out)
        self.assertEqual(out.count("Nastaliq"), 1)
        self.assertNotIn("Nastaleeq", out)

    def test_everything_else_is_kept(self) -> None:
        out = self.render(TEMPLATE)
        before, after = TEMPLATE.splitlines(), out.splitlines()
        self.assertEqual(len(before), len(after))
        changed = [i for i, (a, b) in enumerate(zip(before, after, strict=True)) if a != b]
        self.assertEqual(changed, [3, 4, 5])
        # The English text keeps its own face, and a paragraph or link without type is untouched.
        self.assertIn('<p style="font-family: Arial, sans-serif; line-height: 1.5;">', out)
        self.assertIn('<p style="font-size: 16px;">', out)
        self.assertIn('<hr style="border: 0;"/>', out)
        # Rendering again changes nothing.
        self.assertEqual(self.render(out), out)

    def test_the_brand_name_inside_a_sentence_is_urdu_text(self) -> None:
        html = (
            f'<p lang="ur" style="font-family: {NASTALIQ_BODY}; line-height: 2;">' f"{NAME} ایپ</p>"
        )
        self.assertEqual(
            self.render(html),
            f'<p lang="ur" style="font-family: {EMAIL_URDU}; line-height: 1.65;">{NAME} ایپ</p>',
        )

    def test_a_language_tag_with_a_region_is_urdu(self) -> None:
        html = '<p lang="ur-PK" style="font-family: serif; line-height: 2;">خوش آمدید</p>'
        self.assertIn(EMAIL_URDU, self.render(html))

    def test_urdu_text_must_be_marked_as_urdu(self) -> None:
        self.assert_refused(
            '<html lang="en"><p style="font-family: serif;">\n' + NAME + "</p></html>",
            't.html:2: Urdu text outside a lang="ur" element',
        )

    def test_urdu_must_set_its_own_face_and_line_height(self) -> None:
        self.assert_refused(
            '<div lang="ur">\nخوش آمدید</div>', 't.html:1: <div lang="ur"> sets no font-family'
        )
        self.assert_refused(
            '<div lang="ur" style="font-family: serif;">خوش آمدید</div>',
            '<div lang="ur"> sets no line-height',
        )
        # The wordmark needs a face but no line height of its own.
        self.assertIn(
            EMAIL_WORDMARK,
            self.render(f'<span lang="ur" style="font-family: serif;">{NAME}</span>'),
        )

    def test_type_is_set_in_double_quoted_longhand_inline_styles(self) -> None:
        self.assert_refused(
            "<div lang=\"ur\" style='font-family: serif;'>خوش آمدید</div>",
            "write the style attribute in double quotes",
        )
        self.assert_refused(
            '<div lang="ur" style="font: 16px/2 serif;">خوش آمدید</div>',
            "not the font shorthand",
        )
        self.assert_refused(
            "<head><style>p { font-family: serif; }</style></head>", "e-mail styles are inline"
        )
        for rel in ("stylesheet", "StyleSheet", "stylesheet preload", "alternate STYLESHEET"):
            with self.subTest(rel=rel):
                self.assert_refused(
                    f'<head><link rel="{rel}" href="x.css"></head>', "e-mail styles are inline"
                )
        self.assert_refused("<head><STYLE>p { color: red; }</STYLE></head>", "styles are inline")
        # Other links are not style sheets.
        self.assertEqual(
            self.render('<head><link rel="preload" href="x.woff2"></head>'),
            '<head><link rel="preload" href="x.woff2"></head>',
        )

    def test_type_is_set_only_through_the_style_attribute(self) -> None:
        for html in (
            f'<div lang="ur" style="font-family: serif; line-height: 2;"><font face="Noto Nastaliq Urdu">{NAME} ایپ</font></div>',
            '<p><FONT FACE="Noto Nastaliq Urdu">Hello</FONT></p>',
            '<basefont face="Noto Nastaliq Urdu">',
            '<p lang="ur" face="Noto Nastaliq Urdu">خوش آمدید</p>',
            '<svg><text lang="ur" font-family="Noto Nastaliq Urdu">خوش آمدید</text></svg>',
        ):
            with self.subTest(html=html):
                self.assert_refused(html, "not a font element or a face or font-family attribute")

    def test_urdu_styles_hide_nothing_from_the_check(self) -> None:
        for style in (
            "font-family/**/: 'Noto Nastaliq Urdu'; line-height: 2;",
            "font-family: serif; line-height: 2; /* note */",
            "font-famil\\79: 'Noto Nastaliq Urdu'; line-height: 2;",
            "font&#45;family: 'Noto Nastaliq Urdu'; line-height: 2;",
        ):
            with self.subTest(style=style):
                self.assert_refused(
                    f'<div lang="ur" style="font-family: serif; line-height: 2;">'
                    f'<p style="{style}">خوش آمدید</p></div>',
                    "without CSS comments, CSS escapes or character references",
                )

    def test_the_committed_templates_use_the_email_stacks(self) -> None:
        templates = sorted(bt.EMAIL_TEMPLATES.glob("*.html"))
        self.assertEqual(
            [path.name for path in templates],
            ["confirmation.html", "email_change.html", "recovery.html"],
        )
        for path in templates:
            html = path.read_text(encoding="utf-8")
            with self.subTest(template=path.name):
                self.assertEqual(self.render(html), html)
                self.assertEqual(html.count(f"font-family: {EMAIL_URDU};"), 1)
                self.assertEqual(html.count("line-height: 1.65;"), 1)
                self.assertEqual(html.count("line-height: 1.52;"), 1)
                self.assertEqual(html.count("'Noto Nastaliq Urdu'"), 1)
                self.assertIn(f'style="font-family: {EMAIL_WORDMARK};">{NAME}</span>', html)

    def test_check_refuses_a_template_set_in_nastaliq(self) -> None:
        real = (bt.EMAIL_TEMPLATES / "confirmation.html").read_text(encoding="utf-8")
        nastaliq = real.replace(EMAIL_URDU, NASTALIQ_BODY).replace(
            "line-height: 1.65", "line-height: 2.2"
        )
        self.assertNotEqual(nastaliq, real)
        with tempfile.TemporaryDirectory() as folder:
            templates = Path(folder) / "templates"
            templates.mkdir()
            template = templates / "confirmation.html"
            template.write_text(nastaliq, encoding="utf-8")
            design = Path(folder) / "DESIGN.md"
            design.write_text(bt.DESIGN_MD.read_text(encoding="utf-8"), encoding="utf-8")
            outputs = {
                "DART_OUT": bt.DART_OUT,
                "CSS_OUT": bt.CSS_OUT,
                "EMAIL_TS_OUT": bt.EMAIL_TS_OUT,
            }
            # Fresh copies of the other outputs, so only the template is stale.
            for key, path in outputs.items():
                copy_path = Path(folder) / path.name
                copy_path.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
                outputs[key] = copy_path
            with mock.patch.multiple(bt, DESIGN_MD=design, EMAIL_TEMPLATES=templates, **outputs):
                err = io.StringIO()
                with contextlib.redirect_stderr(err):
                    self.assertEqual(bt.main(["--check"]), 1)
                self.assertIn("confirmation.html", err.getvalue())
                self.assertEqual(bt.main([]), 0)
                self.assertEqual(template.read_text(encoding="utf-8"), real)
                self.assertEqual(bt.main(["--check"]), 0)

    def test_check_refuses_a_face_set_outside_the_style_attributes(self) -> None:
        real = (bt.EMAIL_TEMPLATES / "confirmation.html").read_text(encoding="utf-8")
        welcome = real.index("<p ", real.index('lang="ur" dir="rtl" style="padding'))
        end = real.index("</p>", welcome) + len("</p>")
        mutants = {
            "a font element": real[:welcome]
            + '<font face="Noto Nastaliq Urdu">'
            + real[welcome:end]
            + "</font>"
            + real[end:],
            "a style sheet": real.replace(
                "</head>", '<link rel="StyleSheet" href="https://example.com/x.css">\n  </head>'
            ),
        }
        for what, html in mutants.items():
            with self.subTest(what), tempfile.TemporaryDirectory() as folder:
                (Path(folder) / "confirmation.html").write_text(html, encoding="utf-8")
                err = io.StringIO()
                with (
                    mock.patch.object(bt, "EMAIL_TEMPLATES", Path(folder)),
                    contextlib.redirect_stderr(err),
                ):
                    self.assertEqual(bt.main(["--check"]), 1)
                self.assertIn("confirmation.html:", err.getvalue())

    def test_a_malformed_template_fails_with_its_name(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            templates = Path(folder)
            (templates / "broken.html").write_text(
                '<div lang="ur">خوش آمدید</div>', encoding="utf-8"
            )
            err = io.StringIO()
            with (
                mock.patch.object(bt, "EMAIL_TEMPLATES", templates),
                contextlib.redirect_stderr(err),
            ):
                self.assertEqual(bt.main(["--check"]), 1)
            self.assertIn("broken.html:1:", err.getvalue())


if __name__ == "__main__":
    unittest.main()


class LatinUrduStackTest(unittest.TestCase):
    def test_named_faces_of_both_stacks_come_before_the_generic_family(self):
        families = {
            "latin": ["Atkinson Hyperlegible Next", "Roboto", "sans-serif"],
            "urdu": ["Noto Sans Arabic", "Tahoma", "sans-serif"],
        }
        self.assertEqual(
            bt.latin_urdu_stack(families),
            ["Atkinson Hyperlegible Next", "Roboto", "Noto Sans Arabic", "Tahoma", "sans-serif"],
        )

    def test_a_face_in_both_stacks_appears_once(self):
        families = {"latin": ["Roboto", "sans-serif"], "urdu": ["Tahoma", "Roboto", "serif"]}
        self.assertEqual(bt.latin_urdu_stack(families), ["Roboto", "Tahoma", "sans-serif"])

    def test_a_latin_stack_without_a_generic_family_is_refused(self):
        families = {"latin": ["Roboto"], "urdu": ["Tahoma", "sans-serif"]}
        with self.assertRaises(bt.TokenError):
            bt.latin_urdu_stack(families)
