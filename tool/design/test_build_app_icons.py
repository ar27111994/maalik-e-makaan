"""Tests for the app-icon builder (python3 -m unittest discover -s tool/design -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import io
import json
import re
import shutil
import struct
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import build_app_icons as bai

HOUSE = "M8 15.5 16 8.5l8 7M10.5 13.5V24h11V13.5M14 24v-5h4v5"
ANDROID = "{http://schemas.android.com/apk/res/android}"
INPUTS = (bai.BRAND, bai.TOKENS, bai.APP_STRINGS, Path(bai.WEB) / "manifest.json")


def mark(path: str, size: float = 32, stroke: float = 2) -> bai.Mark:
    return bai.Mark(size, 8, stroke, path, bai.parse_path(path))


def xml(text: str) -> ET.Element:
    return ET.fromstring(text)  # noqa: S314 (the generator's own output)


def pixels(header: bytes, scanlines: bytes) -> list[bytes]:
    """The rows of an unfiltered image, without their filter bytes."""
    width, _, _, colour_type = struct.unpack(">IIBB", header[:10])
    stride = width * (4 if colour_type == bai.RGBA else 3)
    rows = [scanlines[index : index + stride + 1] for index in range(0, len(scanlines), stride + 1)]
    assert all(row[0] == 0 for row in rows)
    return [row[1:] for row in rows]


class PathTest(unittest.TestCase):
    def test_the_house(self) -> None:
        self.assertEqual(
            bai.parse_path(HOUSE),
            (
                ((8, 15.5), (16, 8.5), (24, 15.5)),
                ((10.5, 13.5), (10.5, 24), (21.5, 24), (21.5, 13.5)),
                ((14, 24), (14, 19), (18, 19), (18, 24)),
            ),
        )

    def test_relative_and_absolute_commands_draw_the_same(self) -> None:
        absolute = bai.parse_path("M1 1 L4 1 L4 5 H1 V1")
        self.assertEqual(bai.parse_path("m1 1 3 0 0 4h-3v-4"), absolute)
        self.assertEqual(bai.parse_path("M1,1L4,1,4,5H1V1"), absolute)
        self.assertEqual(bai.parse_path(" M 1 1 l 3 0 l 0 4 h -3 v -4 "), absolute)
        self.assertEqual(bai.parse_path("M1e0 .1 4-1"), (((1, 0.1), (4, -1)),))

    def test_close_returns_to_the_start_and_the_next_line_starts_there(self) -> None:
        self.assertEqual(bai.parse_path("M0 0 4 0 4 4Z"), (((0, 0), (4, 0), (4, 4), (0, 0)),))
        self.assertEqual(
            bai.parse_path("M1 1 2 1zl0 3"),
            (((1, 1), (2, 1), (1, 1)), ((1, 1), (1, 4))),
        )

    def test_a_lone_move_draws_nothing(self) -> None:
        self.assertEqual(bai.parse_path("M0 0M1 1 2 2"), (((1, 1), (2, 2)),))

    def test_curves_and_broken_paths_are_refused(self) -> None:
        for path in (
            "M0 0 C1 1 2 2 3 3",
            "M0 0 A1 1 0 0 1 2 2",
            "L1 1",
            "1 1",
            "M0",
            "M0 0 L1",
            "M0 0 Z 1 1",
            "Z",
            "M0 0 L1 #",
            "",
        ):
            with self.subTest(path=path), self.assertRaises(bai.IconError):
                bai.parse_path(path)


class InputsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.folder = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.folder)

    def brand(self, source: str) -> Path:
        path = self.folder / "brand.ts"
        path.write_text(source, encoding="utf-8")
        return path

    def test_the_repository_mark(self) -> None:
        found = bai.read_mark(bai.ROOT / bai.BRAND)
        self.assertEqual((found.size, found.tile_radius, found.stroke_width), (32, 8, 2))
        self.assertEqual(found.path, HOUSE)
        self.assertEqual(found.strokes, bai.parse_path(HOUSE))

    def test_the_mark_needs_plain_literals_and_round_strokes(self) -> None:
        source = (bai.ROOT / bai.BRAND).read_text(encoding="utf-8")
        self.assertEqual(bai.read_mark(self.brand(source)).path, HOUSE)
        for old, new in (
            ("export const MARK_STROKE_WIDTH = 2;", "export const MARK_STROKE_WIDTH = WIDTH;"),
            ("export const MARK_TILE_RADIUS = 8;", ""),
            ('MARK_VIEWBOX = "0 0 32 32"', 'MARK_VIEWBOX = "0 0 32 24"'),
            ('MARK_VIEWBOX = "0 0 32 32"', 'MARK_VIEWBOX = "4 4 32 32"'),
            ('stroke-linecap="round"', 'stroke-linecap="square"'),
            ('stroke-linejoin="round"', 'stroke-linejoin="miter"'),
        ):
            with self.subTest(new=new):
                self.assertIn(old, source)
                with self.assertRaises(bai.IconError):
                    bai.read_mark(self.brand(source.replace(old, new)))

    def test_the_palette_comes_from_the_tokens(self) -> None:
        palette = bai.read_palette(bai.ROOT / bai.TOKENS)
        tokens = json.loads((bai.ROOT / bai.TOKENS).read_text(encoding="utf-8"))["color"]
        self.assertEqual(palette.primary, tokens["light"]["primary"]["$value"]["hex"].upper())
        self.assertEqual(palette.on_primary, tokens["light"]["onPrimary"]["$value"]["hex"].upper())
        self.assertEqual(palette.background, tokens["light"]["bg"]["$value"]["hex"].upper())
        self.assertEqual(palette.dark_primary, tokens["dark"]["primary"]["$value"]["hex"].upper())
        self.assertEqual(
            palette.dark_on_primary, tokens["dark"]["onPrimary"]["$value"]["hex"].upper()
        )

    def test_missing_or_malformed_colours_are_refused(self) -> None:
        path = self.folder / "tokens.json"
        for colours in (
            {},
            {"light": {"primary": {"$value": {"hex": "#123456"}}}},
            {"light": {"primary": {"$value": {"hex": "blue"}}}},
        ):
            path.write_text(json.dumps({"color": colours}), encoding="utf-8")
            with self.subTest(colours=colours), self.assertRaises(bai.IconError):
                bai.read_palette(path)

    def test_the_app_name(self) -> None:
        self.assertEqual(bai.read_app_name(bai.ROOT / bai.APP_STRINGS), "Maalik-e-Makaan")
        path = self.folder / "app_en.arb"
        path.write_text('{"appName": " "}', encoding="utf-8")
        with self.assertRaises(bai.IconError):
            bai.read_app_name(path)


class GeometryTest(unittest.TestCase):
    def test_the_house_sits_inside_every_safe_zone(self) -> None:
        house = bai.read_mark(bai.ROOT / bai.BRAND)
        bai.check_geometry(house)
        # From the tile's centre to the far side of a bottom corner's round join.
        self.assertAlmostEqual(house.reach(), 1 + (5.5**2 + 8**2) ** 0.5)
        self.assertLess(house.reach() * 72 / 32, 66 / 2)  # adaptive icon, in dp
        self.assertLess(house.reach() / 32, 0.4)  # maskable icon, share of its width

    def test_a_house_past_a_safe_zone_is_refused(self) -> None:
        for path in ("M2 16 30 16", "M3.5 16 16 16"):  # past the adaptive, then the maskable
            with self.subTest(path=path), self.assertRaises(bai.IconError):
                bai.check_geometry(mark(path))


class RasterTest(unittest.TestCase):
    def test_coverage_ramps_across_one_pixel(self) -> None:
        self.assertEqual(
            [bai._coverage(d) for d in (-1, -0.5, -0.25, 0, 0.25, 0.5, 1)],
            [255, 255, 191, 128, 64, 0, 0],
        )

    def test_a_stroke_covers_the_pixels_under_it(self) -> None:
        # A stroke 2 px wide along y = 8.5 (offset 0.5) spans rows 7.5 to 9.5.
        cells = bai.stroke_coverage(mark("M2 8 14 8", size=16), 16, 1.0, 0.5)
        column = [cells[row * 16 + 8] for row in range(16)]
        self.assertEqual(column[6:11], [0, 128, 255, 128, 0])
        self.assertEqual(sum(column), 511)
        # The round caps end the stroke a radius past its ends.
        row = cells[8 * 16 : 9 * 16]
        self.assertEqual(row[0], 0)
        self.assertEqual(row[1], 128)
        self.assertEqual(row[2:15], b"\xff" * 13)
        self.assertEqual(row[15], 128)

    def test_where_two_strokes_meet_their_coverage_adds_up(self) -> None:
        # Pixel (4, 4) has a vertical stroke over its left half and a horizontal stroke over its
        # top half: three quarters covered, where the nearer stroke alone says a half.
        cells = bai.stroke_coverage(mark("M3.5 0 3.5 12M0 3.5 12 3.5", size=12), 12, 1.0, 0.0)
        self.assertEqual(cells[4 * 12 + 4], 191)
        self.assertEqual(cells[4 * 12 + 8], 128)  # only the horizontal stroke

    def test_shapes(self) -> None:
        square = bai.shape_coverage("square", 8, 8, 0)
        self.assertEqual(square, b"\xff" * 64)
        tile = bai.shape_coverage("tile", 32, 32, 8)
        self.assertEqual(tile[0], 0)
        self.assertEqual(tile[16 * 32], 255)  # the middle of an edge
        self.assertEqual(tile[16 * 32 + 16], 255)
        self.assertEqual(tile, bytes(reversed(tile)))
        circle = bai.shape_coverage("circle", 32, 32, 0)
        self.assertEqual(circle[0], 0)
        self.assertEqual(circle[3 * 32 + 3], 0)  # inside the tile's corner, outside the circle
        self.assertEqual(tile[3 * 32 + 3], 255)
        self.assertEqual(circle[16 * 32 + 16], 255)
        self.assertEqual(circle[16 * 32], 253)  # its edge passes just outside the pixel
        self.assertEqual(circle[16 * 32 + 1], 255)
        with self.assertRaises(bai.IconError):
            bai.shape_coverage("star", 8, 8, 0)

    def test_an_opaque_icon_must_fill_its_canvas(self) -> None:
        icon = bai.Icon("x.png", 16, "tile", 1, "#000000", "#FFFFFF", alpha=False)
        with self.assertRaises(bai.IconError):
            bai.render(mark(HOUSE), icon)

    def test_render_blends_the_colours_by_coverage(self) -> None:
        icon = bai.Icon("x.png", 32, "tile", 1, "#102030", "#F0E0D0", alpha=True)
        header, scanlines = bai.render(mark(HOUSE), icon)
        self.assertEqual(header, struct.pack(">IIBBBBB", 32, 32, 8, bai.RGBA, 0, 0, 0))
        rows = pixels(header, scanlines)
        self.assertEqual(rows[0][:4], bytes([0x10, 0x20, 0x30, 0]))  # transparent corner
        self.assertEqual(rows[16][:4], bytes([0x10, 0x20, 0x30, 255]))  # edge of the tile
        self.assertEqual(rows[23][14 * 4 : 15 * 4], bytes([0xF0, 0xE0, 0xD0, 255]))  # the floor
        colours = {rows[y][x * 4 : x * 4 + 3] for y in range(32) for x in range(32)}
        self.assertGreater(len(colours), 10)  # anti-aliased edges in between


class PngTest(unittest.TestCase):
    def test_a_written_png_reads_back(self) -> None:
        icon = bai.Icon("x.png", 8, "square", 1, "#000000", "#FFFFFF", alpha=False)
        content = bai.render(mark(HOUSE), icon)
        data = bai.png_file(*content)
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(bai.png_content(data), content)
        # Pixels are compared, not bytes: another compression of the same pixels reads the same.
        recompressed = data.replace(
            data[33 : data.index(b"IEND") - 4],
            bai._chunk(b"IDAT", zlib.compress(content[1], 1)),
        )
        self.assertNotEqual(recompressed, data)
        self.assertEqual(bai.png_content(recompressed), content)

    def test_other_files_are_refused(self) -> None:
        header = struct.pack(">IIBBBBB", 1, 1, 8, bai.RGB, 0, 0, 0)
        for data in (
            b"GIF89a",
            bai.PNG_SIGNATURE + bai._chunk(b"IHDR", header) + bai._chunk(b"IEND", b""),
            bai.PNG_SIGNATURE + bai._chunk(b"IHDR", header) + bai._chunk(b"IDAT", b"not zlib"),
        ):
            with self.subTest(data=data[:12]), self.assertRaises(bai.IconError):
                bai.png_content(data)


class OutputsTest(unittest.TestCase):
    """What the generator makes from the repository's own mark and tokens."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.outputs = bai.build(bai.ROOT)
        cls.palette = bai.read_palette(bai.ROOT / bai.TOKENS)

    def size_and_type(self, path: str) -> tuple[int, int, int]:
        width, height, _, colour_type = struct.unpack(">IIBB", self.outputs.images[path][0][:10])
        return width, height, colour_type

    def test_every_platform_gets_its_sizes(self) -> None:
        expected = {
            f"{bai.RES}/mipmap-{density}/{name}.png": (size, size, bai.RGBA)
            for density, size in (
                ("mdpi", 48),
                ("hdpi", 72),
                ("xhdpi", 96),
                ("xxhdpi", 144),
                ("xxxhdpi", 192),
            )
            for name in ("ic_launcher", "ic_launcher_round")
        }
        expected |= {
            bai.PLAY_ICON: (512, 512, bai.RGBA),
            f"{bai.APP_ICON_SET}/AppIcon.png": (1024, 1024, bai.RGB),
            f"{bai.APP_ICON_SET}/AppIcon-dark.png": (1024, 1024, bai.RGB),
            f"{bai.APP_ICON_SET}/AppIcon-tinted.png": (1024, 1024, bai.RGB),
            f"{bai.WEB}/favicon.png": (32, 32, bai.RGBA),
            f"{bai.WEB}/icons/Icon-192.png": (192, 192, bai.RGBA),
            f"{bai.WEB}/icons/Icon-512.png": (512, 512, bai.RGBA),
            f"{bai.WEB}/icons/Icon-maskable-192.png": (192, 192, bai.RGB),
            f"{bai.WEB}/icons/Icon-maskable-512.png": (512, 512, bai.RGB),
        }
        self.assertEqual({path: self.size_and_type(path) for path in self.outputs.images}, expected)

    def test_full_square_icons_are_opaque_to_the_corners(self) -> None:
        primary = bytes.fromhex(self.palette.primary[1:])
        for path, channels in ((bai.PLAY_ICON, 4), (f"{bai.APP_ICON_SET}/AppIcon.png", 3)):
            rows = pixels(*self.outputs.images[path])
            corners = [
                row[start : start + channels]
                for row in (rows[0], rows[-1])
                for start in (0, len(row) - channels)
            ]
            with self.subTest(path=path):
                self.assertEqual({corner[:3] for corner in corners}, {primary})
                if channels == 4:
                    alpha = {value for row in rows for value in row[3::4]}
                    self.assertEqual(alpha, {255})

    def test_the_tinted_icon_is_grey(self) -> None:
        rows = pixels(*self.outputs.images[f"{bai.APP_ICON_SET}/AppIcon-tinted.png"])
        self.assertTrue(all(row[0::3] == row[1::3] == row[2::3] for row in rows))

    def test_the_dark_icon_uses_the_dark_theme(self) -> None:
        rows = pixels(*self.outputs.images[f"{bai.APP_ICON_SET}/AppIcon-dark.png"])
        self.assertEqual(rows[0][:3], bytes.fromhex(self.palette.dark_on_primary[1:]))
        floor = rows[24 * 32][16 * 32 * 3 : 16 * 32 * 3 + 3]  # the house's floor, mark (16, 24)
        self.assertEqual(floor, bytes.fromhex(self.palette.dark_primary[1:]))

    def test_the_ios_set_lists_exactly_its_images(self) -> None:
        contents = json.loads(self.outputs.texts[f"{bai.APP_ICON_SET}/Contents.json"])
        images = contents["images"]
        self.assertEqual(
            {f"{bai.APP_ICON_SET}/{image['filename']}" for image in images},
            {path for path in self.outputs.images if path.startswith(bai.APP_ICON_SET)},
        )
        self.assertTrue(all(image["size"] == "1024x1024" for image in images))
        self.assertTrue(all(image["idiom"] == "universal" for image in images))
        self.assertEqual(
            [image.get("appearances", [{}])[0].get("value") for image in images],
            [None, "dark", "tinted"],
        )
        self.assertEqual(contents["info"], {"author": "xcode", "version": 1})

    def test_the_adaptive_icon_has_every_layer(self) -> None:
        launcher = self.outputs.texts[f"{bai.RES}/mipmap-anydpi-v26/ic_launcher.xml"]
        self.assertEqual(
            launcher, self.outputs.texts[f"{bai.RES}/mipmap-anydpi-v26/ic_launcher_round.xml"]
        )
        root = xml(launcher)
        self.assertEqual(root.tag, "adaptive-icon")
        self.assertEqual(
            {child.tag: child.get(f"{ANDROID}drawable") for child in root},
            {
                "background": "@color/ic_launcher_background",
                "foreground": "@drawable/ic_launcher_foreground",
                "monochrome": "@drawable/ic_launcher_foreground",
            },
        )
        colours = xml(self.outputs.texts[f"{bai.RES}/values/ic_launcher_background.xml"])
        self.assertEqual(colours.find("color").text, self.palette.primary)

    def test_the_foreground_draws_the_mark_in_the_safe_zone(self) -> None:
        vector = xml(self.outputs.texts[f"{bai.RES}/drawable/ic_launcher_foreground.xml"])
        self.assertEqual(vector.get(f"{ANDROID}viewportWidth"), "108")
        group = vector.find("group")
        self.assertEqual(group.get(f"{ANDROID}translateX"), "18")
        self.assertEqual(group.get(f"{ANDROID}scaleX"), "2.25")
        path = group.find("path")
        self.assertEqual(path.get(f"{ANDROID}pathData"), HOUSE)
        self.assertEqual(path.get(f"{ANDROID}strokeColor"), self.palette.on_primary)
        self.assertEqual(path.get(f"{ANDROID}strokeWidth"), "2")
        self.assertEqual(path.get(f"{ANDROID}strokeLineCap"), "round")
        self.assertEqual(path.get(f"{ANDROID}strokeLineJoin"), "round")
        self.assertIsNone(path.get(f"{ANDROID}fillColor"))

    def test_the_web_manifest(self) -> None:
        manifest = json.loads(self.outputs.texts[f"{bai.WEB}/manifest.json"])
        self.assertEqual(manifest["name"], "Maalik-e-Makaan")
        self.assertEqual(manifest["short_name"], "Maalik-e-Makaan")
        self.assertEqual(manifest["theme_color"], self.palette.primary)
        self.assertEqual(manifest["background_color"], self.palette.background)
        self.assertEqual(manifest["start_url"], ".")  # kept from the committed file
        for icon in manifest["icons"]:
            path = f"{bai.WEB}/{icon['src']}"
            width, height, _ = self.size_and_type(path)
            self.assertEqual(icon["sizes"], f"{width}x{height}")
        self.assertEqual(sum(icon.get("purpose") == "maskable" for icon in manifest["icons"]), 2)

    def test_the_web_page_links_generated_icons(self) -> None:
        page = (bai.ROOT / bai.WEB / "index.html").read_text(encoding="utf-8")
        links = re.findall(r'<link rel="(?:icon|apple-touch-icon)"[^>]*href="([^"]+)"', page)
        self.assertEqual(len(links), 2)
        for link in links:
            self.assertIn(f"{bai.WEB}/{link}", self.outputs.images)
        # iOS shows transparency as black: its touch icon must be opaque.
        self.assertIn("icons/Icon-maskable-192.png", links)


class WriteAndCheckTest(unittest.TestCase):
    """Writing and checking, on a copy of the inputs, with a few small icons."""

    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        for path in INPUTS:
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(bai.ROOT / path, self.root / path)
        small = [
            bai.Icon(
                f"{bai.APP_ICON_SET}/AppIcon.png", 16, "square", 1, "#000000", "#FFFFFF", False
            ),
            bai.Icon(f"{bai.WEB}/favicon.png", 16, "tile", 1, "#000000", "#FFFFFF", True),
        ]
        patcher = mock.patch.object(bai, "icons", lambda palette: small)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_write_then_check(self) -> None:
        found = bai.problems(self.root)
        self.assertIn(
            f"{bai.WEB}/favicon.png is missing or does not hold the generated pixels", found
        )
        self.assertIn(f"{bai.APP_ICON_SET}/Contents.json is missing or stale", found)
        touched = bai.write(self.root)
        self.assertIn(f"wrote {bai.RES}/mipmap-anydpi-v26/ic_launcher.xml", touched)
        self.assertEqual(bai.problems(self.root), [])
        self.assertEqual(bai.write(self.root), [])  # nothing left to change

    def test_check_finds_edits_and_strays_and_write_mends_them(self) -> None:
        bai.write(self.root)
        favicon = self.root / bai.WEB / "favicon.png"
        header, scanlines = bai.png_content(favicon.read_bytes())
        favicon.write_bytes(bai.png_file(header, scanlines[:-1] + b"\x01"))
        contents = self.root / bai.APP_ICON_SET / "Contents.json"
        contents.write_text(contents.read_text(encoding="utf-8").replace("dark", "light"))
        stray = self.root / bai.APP_ICON_SET / "Icon-App-20x20@1x.png"
        stray.write_bytes(b"old")
        manifest = self.root / bai.WEB / "manifest.json"
        manifest.write_text(manifest.read_text(encoding="utf-8").replace("#1D3F8F", "#0175C2"))
        self.assertEqual(
            bai.problems(self.root),
            [
                f"{bai.APP_ICON_SET}/Contents.json is missing or stale",
                f"{bai.WEB}/manifest.json is missing or stale",
                f"{bai.WEB}/favicon.png is missing or does not hold the generated pixels",
                f"{bai.APP_ICON_SET}/Icon-App-20x20@1x.png is not a generated icon",
            ],
        )
        self.assertIn(f"removed {bai.APP_ICON_SET}/Icon-App-20x20@1x.png", bai.write(self.root))
        self.assertFalse(stray.exists())
        self.assertEqual(bai.problems(self.root), [])

    def test_a_recompressed_icon_is_left_alone(self) -> None:
        bai.write(self.root)
        favicon = self.root / bai.WEB / "favicon.png"
        header, scanlines = bai.png_content(favicon.read_bytes())
        recompressed = (
            bai.PNG_SIGNATURE
            + bai._chunk(b"IHDR", header)
            + bai._chunk(b"IDAT", zlib.compress(scanlines, 1))
            + bai._chunk(b"IEND", b"")
        )
        favicon.write_bytes(recompressed)
        self.assertEqual(bai.problems(self.root), [])
        self.assertEqual(bai.write(self.root), [])
        self.assertEqual(favicon.read_bytes(), recompressed)

    def test_main(self) -> None:
        with mock.patch.object(bai, "ROOT", self.root):
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                self.assertEqual(bai.main(["--bogus"]), 2)
                self.assertEqual(bai.main(["--check"]), 1)
                self.assertIn("make app-icons", err.getvalue())
                self.assertEqual(bai.main([]), 0)
                self.assertIn("wrote app/web/favicon.png", out.getvalue())
                self.assertEqual(bai.main(["--check"]), 0)
                (self.root / bai.TOKENS).write_text("{}", encoding="utf-8")
                self.assertEqual(bai.main(["--check"]), 1)
                self.assertIn("error: no colour token light.primary", err.getvalue())


if __name__ == "__main__":
    unittest.main()
