"""Tests for the icon-font builder (python3 -m unittest discover -s tool/design -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import build_icons as bi

HAVE_LUCIDE = (bi.LUCIDE / "font" / "lucide.ttf").exists()


def icon_set(icons: list[dict]) -> Path:
    folder = Path(tempfile.mkdtemp())
    path = folder / "icons.json"
    path.write_text(json.dumps({"icons": icons}), encoding="utf-8")
    return path


class IconSetTest(unittest.TestCase):
    def test_the_real_icon_set_is_valid(self) -> None:
        icons = bi.load_icon_set()
        self.assertGreater(len(icons), 50)

    def test_names_must_be_unique_identifiers(self) -> None:
        for bad in ("Home", "home-icon", "1home", "new"):
            with self.assertRaises(bi.IconError, msg=bad):
                bi.load_icon_set(icon_set([{"name": bad, "lucide": "house"}]))
        with self.assertRaises(bi.IconError):
            bi.load_icon_set(icon_set([{"name": "a", "lucide": "x"}, {"name": "a", "lucide": "y"}]))

    def test_entries_need_a_glyph_and_a_boolean_mirror(self) -> None:
        with self.assertRaises(bi.IconError):
            bi.load_icon_set(icon_set([{"name": "a"}]))
        with self.assertRaises(bi.IconError):
            bi.load_icon_set(icon_set([{"name": "a", "lucide": "x", "mirror": "yes"}]))
        with self.assertRaises(bi.IconError):
            bi.load_icon_set(icon_set([]))

    def test_unknown_glyphs_are_rejected(self) -> None:
        with self.assertRaises(bi.IconError) as caught:
            bi.resolve([{"name": "ghost", "lucide": "ghost-glyph"}], {"house": 0xE0F5})
        self.assertIn("ghost-glyph", str(caught.exception))


class RenderTest(unittest.TestCase):
    def test_dart_constants_and_mirroring(self) -> None:
        dart = bi.render_dart(
            [("home", "house", 0xE0F5, False), ("back", "arrow-left", 0xE048, True)], "9.9.9"
        )
        self.assertIn("static const IconData home = IconData(\n    0xe0f5,", dart)
        self.assertIn("fontFamily: 'MmIcons',", dart)
        self.assertIn("    matchTextDirection: true,\n  );", dart)
        self.assertEqual(dart.count("matchTextDirection"), 1)
        self.assertIn("'back': back,", dart)
        self.assertIn("lucide-static 9.9.9", dart)


@unittest.skipUnless(HAVE_LUCIDE, "node_modules/lucide-static is not installed (run npm ci)")
class FontTest(unittest.TestCase):
    def test_subset_holds_exactly_the_requested_glyphs(self) -> None:
        codepoints = bi.lucide_codepoints()
        wanted = sorted({codepoints["house"], codepoints["arrow-left"]})
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "sub.ttf"
            bi.subset_font(bi.LUCIDE / "font" / "lucide.ttf", wanted, target)
            self.assertEqual(bi.font_codepoints(target), set(wanted))
            self.assertLess(target.stat().st_size, 10_000)

    def test_subset_glyphs_keep_their_place(self) -> None:
        # Lucide's own font gives every glyph a side bearing of 0, wherever
        # its outline starts; the subset sets it to the outline's start, so
        # the narrow vertical ellipsis stays centred in its square.
        from fontTools.ttLib import TTFont

        codepoints = bi.lucide_codepoints()
        wanted = [codepoints["ellipsis-vertical"]]
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "sub.ttf"
            bi.subset_font(bi.LUCIDE / "font" / "lucide.ttf", wanted, target)
            self.assertEqual(bi.misplaced_glyphs(target), [])
            font = TTFont(target)
            name = font.getBestCmap()[wanted[0]]
            advance, bearing = font["hmtx"][name]
            glyph = font["glyf"][name]
            self.assertEqual(advance, 1000)
            self.assertGreater(bearing, 400)
            self.assertAlmostEqual(bearing + glyph.xMax, advance, delta=2)
            # A font whose bearings were left as Lucide ships them is caught.
            font["hmtx"][name] = (advance, 0)
            font.save(target)
            self.assertEqual(bi.misplaced_glyphs(target), [name])

    def test_the_committed_outputs_are_fresh(self) -> None:
        self.assertEqual(bi.main(["--check"]), 0)

    def test_check_detects_stale_outputs_and_build_writes_them(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            outputs = {
                "FONT_OUT": Path(folder) / "MmIcons.ttf",
                "LICENSE_OUT": Path(folder) / "LICENSE.txt",
                "DART_OUT": Path(folder) / "mm_icons.g.dart",
            }
            with mock.patch.multiple(bi, ROOT=Path(folder), **outputs):
                err = io.StringIO()
                with contextlib.redirect_stderr(err):
                    self.assertEqual(bi.main(["--check"]), 1)
                self.assertIn("stale", err.getvalue())
                self.assertEqual(bi.main([]), 0)
                self.assertEqual(bi.main(["--check"]), 0)
                # A font with other glyphs is reported.
                shutil.copy(bi.LUCIDE / "font" / "lucide.ttf", outputs["FONT_OUT"])
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(bi.main(["--check"]), 1)
                # So is a font with the right glyphs but their bearings at 0.
                self.assertEqual(bi.main([]), 0)
                from fontTools.ttLib import TTFont

                font = TTFont(outputs["FONT_OUT"])
                for name in font.getGlyphOrder():
                    advance, _ = font["hmtx"][name]
                    font["hmtx"][name] = (advance, 0)
                font.save(outputs["FONT_OUT"])
                err = io.StringIO()
                with contextlib.redirect_stderr(err):
                    self.assertEqual(bi.main(["--check"]), 1)
                self.assertIn("off their place", err.getvalue())


class MainTest(unittest.TestCase):
    def test_usage_and_missing_sources(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(bi.main(["--bogus"]), 2)
        with tempfile.TemporaryDirectory() as folder:
            err = io.StringIO()
            with mock.patch.object(bi, "LUCIDE", Path(folder)), contextlib.redirect_stderr(err):
                self.assertEqual(bi.main(["--check"]), 1)
            self.assertIn("npm ci", err.getvalue())


if __name__ == "__main__":
    unittest.main()
