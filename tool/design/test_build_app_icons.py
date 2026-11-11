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


def pixels(header: bytes, image: bytes) -> list[bytes]:
    """The rows of an image's pixels."""
    width, _, _, colour_type = struct.unpack(">IIBB", header[:10])
    stride = width * (4 if colour_type == bai.RGBA else 3)
    return [image[index : index + stride] for index in range(0, len(image), stride)]


def paeth(left: int, up: int, corner: int) -> int:
    estimate = left + up - corner
    nearest = min((abs(estimate - left), 0), (abs(estimate - up), 1), (abs(estimate - corner), 2))
    return (left, up, corner)[nearest[1]]


def filtered(header: bytes, image: bytes, kinds: list[int]) -> bytes:
    """The scanlines of [image] with its rows filtered as an encoder may (PNG filter types 0 to
    4: none, Sub, Up, Average, Paeth), the row's type taken from [kinds] in turn."""
    step = 4 if header[9] == bai.RGBA else 3
    rows = pixels(header, image)
    out = bytearray()
    for number, row in enumerate(rows):
        above = rows[number - 1] if number else bytes(len(row))
        kind = kinds[number % len(kinds)]
        out.append(kind)
        for index, value in enumerate(row):
            left = row[index - step] if index >= step else 0
            corner = above[index - step] if index >= step else 0
            predicted = (
                0,
                left,
                above[index],
                (left + above[index]) // 2,
                paeth(left, above[index], corner),
            )[kind]
            out.append((value - predicted) & 0xFF)
    return bytes(out)


def chunks(*parts: tuple[bytes, bytes]) -> bytes:
    """A PNG file of the given (type, data) chunks, each with its length and checksum."""
    return bai.PNG_SIGNATURE + b"".join(bai._chunk(kind, body) for kind, body in parts)


def png(header: bytes, scanlines: bytes, level: int = 9) -> bytes:
    return chunks((b"IHDR", header), (b"IDAT", zlib.compress(scanlines, level)), (b"IEND", b""))


def flip(data: bytes, index: int) -> bytes:
    """[data] with every bit of the byte at [index] inverted."""
    return data[:index] + bytes([data[index] ^ 0xFF]) + data[index + 1 :]


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
        header, image = bai.render(mark(HOUSE), icon)
        self.assertEqual(header, struct.pack(">IIBBBBB", 32, 32, 8, bai.RGBA, 0, 0, 0))
        self.assertEqual(len(image), 32 * 32 * 4)
        rows = pixels(header, image)
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
        self.assertEqual(bai.png_image(data), content)
        # The image is compared, not the file's bytes: another compression reads the same.
        header, scanlines = bai.png_parts(data)
        self.assertEqual(set(scanlines[:: 8 * 3 + 1]), {0})  # every row unfiltered
        recompressed = png(header, scanlines, level=1)
        self.assertNotEqual(recompressed, data)
        self.assertEqual(bai.png_image(recompressed), content)

    def test_every_row_filter_is_undone(self) -> None:
        for alpha in (False, True):
            icon = bai.Icon("x.png", 24, "square", 1, "#1D3F8F", "#FFFFFF", alpha=alpha)
            header, image = bai.render(mark(HOUSE), icon)
            for kinds in ([0], [1], [2], [3], [4], [4, 3, 2, 1, 0]):
                with self.subTest(alpha=alpha, kinds=kinds):
                    scanlines = filtered(header, image, kinds)
                    stride = len(image) // 24
                    rows = bytes(b for i, b in enumerate(scanlines) if i % (stride + 1))
                    self.assertEqual(rows == image, kinds == [0])  # filters change the bytes
                    self.assertEqual(bai.png_image(png(header, scanlines)), (header, image))

    def test_other_files_are_refused(self) -> None:
        header = struct.pack(">IIBBBBB", 1, 1, 8, bai.RGB, 0, 0, 0)
        end = (b"IEND", b"")
        for data in (
            b"GIF89a",
            chunks((b"IHDR", header), end),
            chunks((b"IHDR", header[:12]), (b"IDAT", zlib.compress(b"\x00\x01\x02\x03")), end),
            chunks((b"IHDR", header), (b"IDAT", b"not zlib"), end),
            png(header, b"\x00\x01\x02\x03\x04"),  # a row too long
            png(header, b"\x05\x01\x02\x03"),  # no filter type 5
            png(struct.pack(">IIBBBBB", 1, 1, 16, bai.RGB, 0, 0, 0), bytes(7)),
            png(struct.pack(">IIBBBBB", 1, 1, 8, 3, 0, 0, 0), bytes(2)),  # a palette
            png(struct.pack(">IIBBBBB", 1, 1, 8, bai.RGB, 0, 0, 1), bytes(4)),  # interlaced
        ):
            with self.subTest(data=data[:12]), self.assertRaises(bai.IconError):
                bai.png_image(data)

    def test_a_damaged_file_is_refused_even_when_its_pixels_decode(self) -> None:
        header = struct.pack(">IIBBBBB", 1, 1, 8, bai.RGB, 0, 0, 0)
        scanlines = b"\x00\x01\x02\x03"
        data = png(header, scanlines)
        self.assertEqual(bai.png_image(data), (header, b"\x01\x02\x03"))
        idat = len(bai.PNG_SIGNATURE) + 12 + len(header)  # where the IDAT chunk starts
        (length,) = struct.unpack(">I", data[idat : idat + 4])
        compressed = zlib.compress(scanlines)
        start, end = (b"IHDR", header), (b"IEND", b"")
        text = bai._chunk(b"tEXt", b"Title\x00x")
        for damaged, problem in (
            # The last byte of IDAT's checksum, just before the 12 bytes of IEND.
            (flip(data, len(data) - 13), "bad checksum in IDAT"),
            (flip(data, idat + 10), "bad checksum in IDAT"),  # a byte of the compressed data
            (flip(data, 8 + 8 + 4), "bad checksum in IHDR"),  # the image's height
            (flip(data, 8 + 4), "bad checksum in b'\\xb6HDR'"),  # the I of its type
            (flip(data, len(data) - 1), "bad checksum in IEND"),
            (data[:-12], "the file ends before an IEND chunk"),
            (data[:-4], "the file ends part-way through the IEND chunk"),  # no checksum
            (data[:-9], "the file ends part-way through a chunk"),  # no type
            (data + b"\x00", "1 byte follows the IEND chunk"),
            (data + text, f"{len(text)} bytes follow the IEND chunk"),
            # IDAT's length made longer: 12 bytes more still end inside the file (where IEND's
            # checksum was), 13 run past it.
            (
                data[:idat] + struct.pack(">I", length + 12) + data[idat + 4 :],
                "bad checksum in IDAT",
            ),
            (
                data[:idat] + struct.pack(">I", length + 13) + data[idat + 4 :],
                "the file ends part-way through the IDAT chunk",
            ),
            (
                data[:idat] + b"\xff\xff\xff\xff" + data[idat + 4 :],
                "the file ends part-way through the IDAT chunk",
            ),
            (
                chunks(start, (b"IDAT", compressed), (b"IEND", b"\x00")),
                "the IEND chunk is not empty",
            ),
            (bai.PNG_SIGNATURE + text + data[8:], "the first chunk is tEXt, not IHDR"),
            (chunks(end, start, (b"IDAT", compressed), end), "the first chunk is IEND, not IHDR"),
            (chunks(start, start, (b"IDAT", compressed), end), "a second IHDR chunk"),
            (
                chunks(start, (b"IDAT", compressed + b"tail"), end),
                "4 bytes follow the compressed image data",
            ),
            (
                chunks(start, (b"IDAT", compressed[:-1]), end),
                "the compressed image data is cut short",
            ),
        ):
            with self.subTest(problem=problem):
                with self.assertRaises(bai.DamagedPngError) as caught:
                    bai.png_image(damaged)
                self.assertEqual(str(caught.exception), problem)
        with self.assertRaises(bai.DamagedPngError) as caught:
            bai.png_image(chunks(start, (b"IDAT", b"not zlib"), end))
        self.assertTrue(str(caught.exception).startswith("the compressed image data is damaged ("))

    def test_ancillary_chunks_and_split_image_data_are_read(self) -> None:
        # As another encoder or an optimiser may write a file: the image data split over several
        # IDAT chunks, one of them empty, and ancillary chunks before and after it.
        header = struct.pack(">IIBBBBB", 2, 1, 8, bai.RGBA, 0, 0, 0)
        compressed = zlib.compress(b"\x00" + bytes(range(8)))
        data = chunks(
            (b"IHDR", header),
            (b"gAMA", struct.pack(">I", 45455)),
            (b"IDAT", compressed[:3]),
            (b"IDAT", b""),
            (b"IDAT", compressed[3:]),
            (b"tEXt", b"Title\x00x"),
            (b"IEND", b""),
        )
        self.assertEqual(bai.png_image(data), (header, bytes(range(8))))

    def test_split_image_data_and_unknown_critical_chunks_are_refused(self) -> None:
        # libpng refuses both: IDAT chunks must form one run, and a critical chunk it does not
        # know (an upper-case first letter) means it cannot read the file.
        header = struct.pack(">IIBBBBB", 2, 1, 8, bai.RGBA, 0, 0, 0)
        compressed = zlib.compress(b"\x00" + bytes(range(8)))
        interleaved = chunks(
            (b"IHDR", header),
            (b"IDAT", compressed[:3]),
            (b"tEXt", b"a\x00b"),
            (b"IDAT", compressed[3:]),
            (b"IEND", b""),
        )
        with self.assertRaisesRegex(bai.DamagedPngError, "not one unbroken run"):
            bai.png_image(interleaved)
        unknown = chunks((b"IHDR", header), (b"ABCD", b""), (b"IDAT", compressed), (b"IEND", b""))
        with self.assertRaisesRegex(bai.DamagedPngError, "unknown critical chunk, ABCD"):
            bai.png_image(unknown)

    def test_formats_are_described(self) -> None:
        self.assertEqual(
            bai.describe(struct.pack(">IIBBBBB", 512, 512, 8, bai.RGBA, 0, 0, 0)),
            "a 512 x 512, 8-bit RGBA image",
        )
        self.assertEqual(
            bai.describe(struct.pack(">IIBBBBB", 16, 8, 4, 3, 0, 0, 1)),
            "a 16 x 8, 4-bit palette image (interlaced)",
        )
        self.assertIn("colour type 7", bai.describe(struct.pack(">IIBBBBB", 1, 1, 8, 7, 0, 0, 0)))


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
        self.assertIn(f"{bai.WEB}/favicon.png is missing", found)
        self.assertIn(f"{bai.APP_ICON_SET}/Contents.json is missing or stale", found)
        touched = bai.write(self.root)
        self.assertIn(f"wrote {bai.RES}/mipmap-anydpi-v26/ic_launcher.xml", touched)
        self.assertEqual(bai.problems(self.root), [])
        self.assertEqual(bai.write(self.root), [])  # nothing left to change

    def test_check_finds_edits_and_strays_and_write_mends_them(self) -> None:
        bai.write(self.root)
        favicon = self.root / bai.WEB / "favicon.png"
        header, image = bai.png_image(favicon.read_bytes())
        favicon.write_bytes(bai.png_file(header, image[:-1] + b"\x01"))
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
                f"{bai.WEB}/favicon.png does not hold the generated pixels",
                f"{bai.APP_ICON_SET}/Icon-App-20x20@1x.png is not a generated icon",
            ],
        )
        self.assertIn(f"removed {bai.APP_ICON_SET}/Icon-App-20x20@1x.png", bai.write(self.root))
        self.assertFalse(stray.exists())
        self.assertEqual(bai.problems(self.root), [])

    def test_a_losslessly_reencoded_icon_is_left_alone(self) -> None:
        bai.write(self.root)
        # As an optimiser may write it: other row filters, another compression level.
        favicon = self.root / bai.WEB / "favicon.png"
        header, image = bai.png_image(favicon.read_bytes())
        reencoded = png(header, filtered(header, image, [1, 2, 3, 4]), level=1)
        favicon.write_bytes(reencoded)
        self.assertEqual(bai.problems(self.root), [])
        self.assertEqual(bai.write(self.root), [])
        self.assertEqual(favicon.read_bytes(), reencoded)

    def test_an_icon_in_another_format_is_reported_and_rewritten(self) -> None:
        bai.write(self.root)
        # The same colours without the alpha channel: Google Play would refuse such an icon.
        favicon = self.root / bai.WEB / "favicon.png"
        header, image = bai.png_image(favicon.read_bytes())
        rgb = struct.pack(">IIBBBBB", 16, 16, 8, bai.RGB, 0, 0, 0)
        favicon.write_bytes(bai.png_file(rgb, bytes(b for i, b in enumerate(image) if i % 4 != 3)))
        self.assertEqual(
            bai.problems(self.root),
            [
                f"{bai.WEB}/favicon.png is a 16 x 16, 8-bit RGB image, "
                "not a 16 x 16, 8-bit RGBA image"
            ],
        )
        favicon.write_bytes(b"GIF89a")
        self.assertEqual(
            bai.problems(self.root), [f"{bai.WEB}/favicon.png cannot be read: not a PNG file"]
        )
        self.assertEqual(bai.write(self.root), [f"wrote {bai.WEB}/favicon.png"])
        self.assertEqual(bai.png_image(favicon.read_bytes()), (header, image))

    def test_a_damaged_icon_is_reported_and_rewritten(self) -> None:
        bai.write(self.root)
        favicon = self.root / bai.WEB / "favicon.png"
        good = favicon.read_bytes()
        # Each of these still decodes to the generated pixels with a lenient reader.
        for damaged, problem in (
            (flip(good, len(good) - 13), "bad checksum in IDAT"),  # IDAT's checksum
            (good[:-12], "the file ends before an IEND chunk"),
            (good[:-2], "the file ends part-way through the IEND chunk"),
            (good + b"\x00\x00", "2 bytes follow the IEND chunk"),
        ):
            with self.subTest(problem=problem):
                favicon.write_bytes(damaged)
                self.assertEqual(
                    bai.problems(self.root), [f"{bai.WEB}/favicon.png is damaged: {problem}"]
                )
                self.assertEqual(bai.write(self.root), [f"wrote {bai.WEB}/favicon.png"])
                self.assertEqual(favicon.read_bytes(), good)
                self.assertEqual(bai.problems(self.root), [])

    def test_clutter_in_the_icon_set_is_left_alone(self) -> None:
        bai.write(self.root)
        icon_set = self.root / bai.APP_ICON_SET
        clutter = [".DS_Store", "._AppIcon.png", ".Contents.json.swp", "Thumbs.db", "AppIcon.png~"]
        for name in clutter:
            (icon_set / name).write_bytes(b"clutter")
        self.assertEqual(bai.problems(self.root), [])
        stray = icon_set / "Icon-App-1024x1024@1x.png"
        stray.write_bytes(b"old")
        self.assertEqual(
            bai.problems(self.root),
            [f"{bai.APP_ICON_SET}/Icon-App-1024x1024@1x.png is not a generated icon"],
        )
        self.assertEqual(
            bai.write(self.root), [f"removed {bai.APP_ICON_SET}/Icon-App-1024x1024@1x.png"]
        )
        self.assertTrue(all((icon_set / name).exists() for name in clutter))

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
