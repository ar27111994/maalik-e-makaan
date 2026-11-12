"""Tests for the Urdu font builder (python3 -m unittest discover -s tool/design -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import dataclasses
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import build_fonts as bf

SANS, NASTALIQ = bf.FONTS
COMMITTED = bf.OUTPUTS


def temporary_folder(test: unittest.TestCase) -> Path:
    folder = Path(tempfile.mkdtemp())
    test.addCleanup(shutil.rmtree, folder)
    return folder


def ttf(data: bytes):
    from fontTools.ttLib import TTFont

    return TTFont(io.BytesIO(data), recalcTimestamp=False)


def axes(font) -> dict[str, tuple[float, float, float]]:
    return {a.axisTag: (a.minValue, a.defaultValue, a.maxValue) for a in font["fvar"].axes}


class SourceTest(unittest.TestCase):
    def test_the_sources_are_the_upstream_files(self) -> None:
        for font in bf.FONTS:
            self.assertTrue(bf.check_source(font), font.source)

    def test_a_changed_or_missing_source_is_refused(self) -> None:
        folder = temporary_folder(self)
        (folder / SANS.source).write_bytes(b"not the font")
        with self.assertRaises(bf.FontError) as caught:
            bf.check_source(SANS, folder)
        self.assertIn("not the upstream file", str(caught.exception))
        with self.assertRaises(bf.FontError) as caught:
            bf.check_source(NASTALIQ, folder)
        self.assertIn("is missing", str(caught.exception))


class WordmarkTextTest(unittest.TestCase):
    def test_is_the_apps_urdu_name(self) -> None:
        self.assertEqual(bf.wordmark_text(), "مالکِ مکان")

    def test_an_arb_without_the_name_is_refused(self) -> None:
        arb = temporary_folder(self) / "app_ur.arb"
        for content in ({}, {"appName": " "}, {"appName": 7}):
            arb.write_text(json.dumps(content), encoding="utf-8")
            with self.assertRaises(bf.FontError, msg=content):
                bf.wordmark_text(arb)


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text = bf.wordmark_text()
        cls.sources = {font.output: bf.check_source(font) for font in bf.FONTS}
        cls.built = {
            font.output: bf.build(font, cls.sources[font.output], cls.text) for font in bf.FONTS
        }

    def test_the_urdu_face_keeps_every_glyph_and_weight_at_its_normal_width(self) -> None:
        source = ttf(self.sources[SANS.output])
        built = ttf(self.built[SANS.output])
        self.assertEqual(axes(source)["wdth"], (62.5, 100.0, 100.0))
        self.assertEqual(axes(built), {"wght": (100.0, 400.0, 900.0)})
        self.assertEqual(built.getBestCmap(), source.getBestCmap())
        self.assertEqual(built.getGlyphOrder(), source.getGlyphOrder())
        self.assertLess(len(self.built[SANS.output]), 0.6 * len(self.sources[SANS.output]))

    def test_the_wordmark_holds_only_the_letters_of_the_name(self) -> None:
        built = ttf(self.built[NASTALIQ.output])
        self.assertEqual(set(built.getBestCmap()), {ord(char) for char in self.text})
        self.assertEqual(axes(built), {"wght": (400.0, 400.0, 700.0)})
        # Contextual forms and the marks' placement survive: far more glyphs than letters.
        self.assertGreater(len(built.getGlyphOrder()), 50)
        for table in ("GSUB", "GPOS", "gvar"):
            self.assertIn(table, built)
        self.assertLess(len(self.built[NASTALIQ.output]), 0.1 * len(self.sources[NASTALIQ.output]))

    def test_both_keep_the_licence_in_their_names(self) -> None:
        for data in self.built.values():
            names = ttf(data)["name"]
            self.assertIn("Copyright", names.getDebugName(0))
            self.assertIn("SIL Open Font License", names.getDebugName(13))
            self.assertEqual(names.getDebugName(14), "https://scripts.sil.org/OFL")

    def test_the_build_is_reproducible(self) -> None:
        for font in bf.FONTS:
            again = bf.build(font, self.sources[font.output], self.text)
            self.assertEqual(again, self.built[font.output], font.output)

    def test_a_name_the_wordmark_font_cannot_draw_is_refused(self) -> None:
        with self.assertRaises(bf.FontError) as caught:
            bf.build(NASTALIQ, self.sources[NASTALIQ.output], "مالکِ مکان 中")
        self.assertIn("中", str(caught.exception))

    def test_an_axis_the_font_lacks_is_refused(self) -> None:
        wrong = dataclasses.replace(NASTALIQ, pin={"wdth": 100})
        with self.assertRaises(bf.FontError) as caught:
            bf.build(wrong, self.sources[NASTALIQ.output], self.text)
        self.assertIn("no wdth axis", str(caught.exception))

    def test_a_font_that_would_lose_its_licence_names_is_refused(self) -> None:
        from fontTools import subset

        original = subset.Subsetter.subset

        def drop_licence(subsetter, font):
            original(subsetter, font)
            font["name"].names = [r for r in font["name"].names if r.nameID not in (0, 13, 14)]

        with (
            mock.patch.object(subset.Subsetter, "subset", drop_licence),
            self.assertRaises(bf.FontError) as caught,
        ):
            bf.build(NASTALIQ, self.sources[NASTALIQ.output], self.text)
        self.assertIn("licence name records [0, 13, 14]", str(caught.exception))


class MainTest(unittest.TestCase):
    def run_main(self, argv: list[str]) -> tuple[int, str]:
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = bf.main(argv)
        return code, err.getvalue()

    def test_the_committed_fonts_are_current(self) -> None:
        self.assertEqual(self.run_main(["--check"]), (0, ""))

    def test_check_names_a_stale_font_and_a_build_rewrites_it(self) -> None:
        folder = temporary_folder(self)
        with mock.patch.object(bf, "OUTPUTS", folder):
            code, err = self.run_main(["--check"])
            self.assertEqual(code, 1)
            self.assertIn("NotoSansArabic-Variable.ttf is stale", err)
            self.assertIn("NotoNastaliqUrdu-Wordmark.ttf is stale", err)
            self.assertEqual(self.run_main([]), (0, ""))
            for font in bf.FONTS:
                self.assertEqual(
                    (folder / font.output).read_bytes(), (COMMITTED / font.output).read_bytes()
                )
            self.assertEqual(self.run_main(["--check"]), (0, ""))

    def test_a_bad_source_or_usage_fails(self) -> None:
        with mock.patch.object(bf, "check_source", side_effect=bf.FontError("boom")):
            self.assertEqual(self.run_main([]), (1, "error: boom\n"))
        code, err = self.run_main(["--write"])
        self.assertEqual(code, 2)
        self.assertIn("usage", err)


if __name__ == "__main__":
    unittest.main()
