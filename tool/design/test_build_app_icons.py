"""Tests for the app-icon builder (python3 -m unittest discover -s tool/design -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import io
import itertools
import json
import math
import re
import runpy
import shutil
import struct
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zlib
from html.parser import HTMLParser
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import build_app_icons as bai

# The owner's mark of 23 November 2026, "twin gables", as website/src/lib/brand.ts holds it.
GABLES = (
    "M6 24V18H4L12 6L16 12L20 6L28 18H26V24H22V16.5A2 2 0 0 0 18 16.5V24H14V16.5"
    "A2 2 0 0 0 10 16.5V24Z"
)
ANDROID = "{http://schemas.android.com/apk/res/android}"
INPUTS = (bai.BRAND, bai.TOKENS, bai.APP_STRINGS, Path(bai.WEB) / "manifest.json")


def mark(path: str, size: float = 32) -> bai.Mark:
    return bai.Mark(size, 8, path, bai.parse_path(path))


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


# --- An exact render, worked out here independently of the generator -----------------------


def _right_of(column: int, xa: float, xb: float) -> float:
    """The mean, along an edge running straight from x = [xa] to x = [xb] (in step with y), of
    how much of the pixel column [column, column + 1] lies to the edge's right."""

    def antiderivative(x: float) -> float:  # of column + 1 - clamp(x, column, column + 1)
        t = x - column
        return t if t <= 0 else 0.5 if t >= 1 else t - t * t / 2

    if xa == xb:
        return column + 1 - min(max(xa, column), column + 1)
    return (antiderivative(xb) - antiderivative(xa)) / (xb - xa)


def exact_shares(polygons: list[list[tuple[float, float]]], size: int) -> list[float]:
    """Each pixel's exact share of [polygons] (closed, inside the canvas, each point wound at
    most once and the same way), row after row: the integral of the winding number over the
    pixel's square, which is, for each edge and each row it crosses, the area of the pixel to
    the edge's right, signed by the edge's direction. Pixels wholly right of an edge take its
    whole height; for the pixels it passes through, the mean width to its right is found from
    the antiderivative of the clamped distance."""
    steps = [[0.0] * (size + 1) for _ in range(size)]
    within = [[0.0] * size for _ in range(size)]
    for polygon in polygons:
        for (x0, y0), (x1, y1) in zip(polygon, polygon[1:] + polygon[:1], strict=True):
            if y0 == y1:
                continue
            sign = 1.0 if y1 > y0 else -1.0
            (ax, ay), (bx, by) = sorted([(x0, y0), (x1, y1)], key=lambda point: point[1])
            for row in range(math.floor(ay), math.ceil(by)):
                top, bottom = max(row, ay), min(row + 1, by)
                xt = ax + (bx - ax) * (top - ay) / (by - ay)
                xb = ax + (bx - ax) * (bottom - ay) / (by - ay)
                height = (bottom - top) * sign
                left, right = min(xt, xb), max(xt, xb)
                for column in range(math.floor(left), math.ceil(right)):
                    within[row][column] += height * _right_of(column, xt, xb)
                steps[row][math.ceil(right)] += height
    shares = []
    for row in range(size):
        level = 0.0
        for column in range(size):
            level += steps[row][column]
            shares.append(min(1.0, abs(level + within[row][column])))
    return shares


def twin_gables(scale: float, offset: float, flatness: float = 1e-6) -> list[tuple[float, float]]:
    """The chosen mark, built from the designer's description rather than from its path: two
    gables peaking at (12, 6) and (20, 6) over a valley at (16, 12), eaves at (4, 18) and
    (28, 18), walls down to y 24, and two doorways 4 wide whose heads are half circles of
    radius 2 springing at y 16.5. Its arcs are chords at most [flatness] pixels from them."""
    radius = 2 * scale
    count = math.ceil(math.pi / math.sqrt(8 * flatness / radius))

    def head(centre: float) -> list[tuple[float, float]]:  # from the right spring over the top
        return [
            (centre + 2 * math.cos(-math.pi * k / count), 16.5 + 2 * math.sin(-math.pi * k / count))
            for k in range(1, count)
        ]

    outline = [
        *((6, 24), (6, 18), (4, 18), (12, 6), (16, 12), (20, 6), (28, 18), (26, 18), (26, 24)),
        *((22, 24), (22, 16.5), *head(20), (18, 16.5), (18, 24), (14, 24), (14, 16.5)),
        *(*head(12), (10, 16.5), (10, 24)),
    ]
    return [(offset + u * scale, offset + v * scale) for u, v in outline]


def icon_links(html: str) -> list[tuple[str, str | None]]:
    """Each icon link in [html], in order: its rel as lower-case tokens joined by single spaces,
    and its own href, whatever the attributes' order. A browser reads rel as a set of tokens in
    any case, so rel="ICON" and rel=" icon " name an icon as rel="icon" does."""
    found: list[tuple[str, str | None]] = []

    class Links(HTMLParser):
        def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
            attributes = dict(attrs)
            tokens = (attributes.get("rel") or "").lower().split()
            if tag == "link" and any("icon" in token for token in tokens):
                found.append((" ".join(tokens), attributes.get("href")))

    Links().feed(html)
    return found


def worst_rounding(coverage: bytes, shares: list[float]) -> float:
    """How far, in levels of 255, the generator's bytes stray from the exact shares."""
    return max(abs(byte - share * 255) for byte, share in zip(coverage, shares, strict=True))


class PathTest(unittest.TestCase):
    def test_the_twin_gables(self) -> None:
        (contour,) = bai.parse_path(GABLES)
        lines = [edge for edge in contour if isinstance(edge, bai.Line)]
        arcs = [edge for edge in contour if isinstance(edge, bai.Arc)]
        self.assertEqual((len(lines), len(arcs)), (15, 2))  # Z closes the ground line
        self.assertEqual(
            [edge.start for edge in contour],
            [
                *((6, 24), (6, 18), (4, 18), (12, 6), (16, 12), (20, 6), (28, 18), (26, 18)),
                *((26, 24), (22, 24), (22, 16.5), (18, 16.5), (18, 24), (14, 24), (14, 16.5)),
                *((10, 16.5), (10, 24)),
            ],
        )
        self.assertEqual(contour[-1].end, contour[0].start)
        # Each doorway's head: a half circle of radius 2, over the top (anticlockwise on screen).
        self.assertEqual(
            arcs,
            [
                bai.Arc((22, 16.5), (18, 16.5), (20, 16.5), 2, clockwise=False),
                bai.Arc((14, 16.5), (10, 16.5), (12, 16.5), 2, clockwise=False),
            ],
        )

    def test_relative_and_compact_commands_draw_the_same(self) -> None:
        absolute = bai.parse_path(GABLES)
        for path in (
            "m6 24v-6h-2l8-12 4 6 4-6 8 12h-2v6h-4v-7.5a2 2 0 0 0-4 0v7.5h-4v-7.5a2 2 0 0 0-4 0v7.5z",
            "M6,24V18H4L12,6,16,12,20,6,28,18H26V24H22V16.5A2,2,0,0,0,18,16.5V24H14V16.5"
            "A2,2,0,0,0,10,16.5V24",  # no Z: a filled subpath closes itself
            "M6 24V18H4L12 6L16 12L20 6L28 18H26V24H22V16.5a2 2 0 00-4 0V24H14V16.5a2 2 0 00-4 0V24Z",
            " M 6 24 V 18 H 4 L 12 6 16 12 20 6 28 18 H 26 V 24 H 22 V 16.5 A 2 2 45 0 0 18 16.5 "
            "V 24 H 14 V 16.5 A -2 -2 0 0 0 10 16.5 V 24 Z ",  # a circle ignores the rotation
        ):
            with self.subTest(path=path):
                self.assertEqual(bai.parse_path(path), absolute)
        self.assertEqual(bai.parse_path("M1e0 .1 4-1"), bai.parse_path("M1 0.1L4 -1Z"))

    def test_a_subpath_after_z_starts_where_the_last_one_did(self) -> None:
        line = bai.Line
        self.assertEqual(
            bai.parse_path("M1 1 3 1 3 3zl0 3 2 0"),
            (
                (line((1, 1), (3, 1)), line((3, 1), (3, 3)), line((3, 3), (1, 1))),
                (line((1, 1), (1, 4)), line((1, 4), (3, 4)), line((3, 4), (1, 1))),
            ),
        )

    def test_a_relative_move_after_an_open_subpath_counts_from_where_it_ended(self) -> None:
        # SVG keeps the current point at an open subpath's last point; the fill's closing line
        # does not move it, so the hole starts at (5, 22) + (7, -8) = (12, 14), not (12, 2).
        self.assertEqual(
            bai.parse_path("M5 10H27V22H5m7 -8v4h8v-4z"),
            bai.parse_path("M5 10H27V22H5ZM12 14V18H20V14Z"),
        )
        self.assertEqual(
            bai.parse_path("M5 10H27V22H5zm7 4v4h8v-4z"),
            bai.parse_path("M5 10H27V22H5ZM12 14V18H20V14Z"),
        )  # after Z the current point is the start, (5, 10)

    def test_moves_and_still_lines_draw_nothing(self) -> None:
        self.assertEqual(
            bai.parse_path("M0 0M1 1 2 2 1 2L1 2"), bai.parse_path("M1 1 2 2 1 2Z")
        )  # a lone move, and a line to where it already is

    def test_arcs_follow_svg(self) -> None:
        # The sweep flag picks the direction; with the large-arc flag it picks the centre too.
        small = bai.parse_path("M0 0A5 5 0 0 1 6 0Z")[0][0]
        self.assertEqual(small, bai.Arc((0, 0), (6, 0), (3, 4), 5, clockwise=True))
        large = bai.parse_path("M0 0A5 5 0 1 1 6 0Z")[0][0]
        self.assertEqual(large, bai.Arc((0, 0), (6, 0), (3, -4), 5, clockwise=True))
        self.assertEqual(mark("M0 0A5 5 0 0 1 6 0Z").box(), (0, -1, 6, 0))
        self.assertEqual(mark("M0 0A5 5 0 1 1 6 0Z").box(), (-2, -9, 8, 0))
        self.assertEqual(mark("M0 0A5 5 0 1 0 6 0Z").box(), (-2, 0, 8, 9))
        # A radius too short to span its ends is lengthened until it does.
        self.assertEqual(
            bai.parse_path("M0 0A1 1 0 0 1 4 0Z")[0][0],
            bai.Arc((0, 0), (4, 0), (2, 0), 2, clockwise=True),
        )
        # A radius of 0 draws a line, and an arc that ends where it starts draws nothing.
        self.assertEqual(bai.parse_path("M0 0A0 3 0 0 1 4 0L4 4"), bai.parse_path("M0 0 4 0 4 4"))
        self.assertEqual(
            bai.parse_path("M0 0A2 2 0 0 1 0 0L4 0 4 4"), bai.parse_path("M0 0 4 0 4 4")
        )

    def test_curves_ellipses_and_broken_paths_are_refused(self) -> None:
        for path, problem in (
            ("M0 0 C1 1 2 2 3 3", "command C is not supported"),
            ("M0 0 Q1 1 2 2", "command Q is not supported"),
            ("M0 0 A1 2 0 0 1 2 2", "must be circular, not 1 by 2"),
            ("M0 0 A2 2 0 2 1 4 0", "needs a flag of 0 or 1"),
            ("M0 0 A2 2 0 0", "needs a flag of 0 or 1"),
            ("M0 0 A2 2 0 0 1 4", "A command lacks a number"),
            ("L1 1", "must start with M"),
            ("1 1", "must start with M"),
            ("M0", "M command lacks a number"),
            ("M0 0 L1", "L command lacks a number"),
            ("M0 0 Z 1 1", "a number cannot follow Z"),
            ("Z", "closes a shape it has not started"),
            ("M0 0 Z Z", "closes a shape it has not started"),
            ("M0 0 L1 #", "L command lacks a number"),
            ("M0 0 #1", "cannot read the path at '#1'"),
            ("", "draws nothing"),
            ("M3 3", "draws nothing"),
            # Within the bound on numbers, arcs whose centre would leave a float's range: ends
            # 1e-160 apart have a square, but the centre's distance from them over it does not.
            ("M0 0 A1 1 0 0 1 1e-160 0", "the arc from (0, 0) of radius 1 is too large to draw"),
            ("M0 0 A1 1 0 1 1 1e-200 0", "the arc from (0, 0) ends too close to its start"),
        ):
            with self.subTest(path=path), self.assertRaisesRegex(bai.IconError, re.escape(problem)):
                bai.parse_path(path)
        # Just inside those limits: ends 1e-150 apart still have a square.
        tiny = bai._arc((0, 0), (1e-150, 0), 1, 1, large=True, clockwise=True)
        self.assertAlmostEqual(tiny.radius, 1)
        # The arc's own limits, which the bound on numbers now keeps the path from reaching: a
        # radius whose square, or ends whose distance, would leave a float's range.
        for start, end, radius, problem in (
            ((0, 0), (4, 0), 1e155, "the arc from (0, 0) of radius 1e+155 is too large"),
            ((0, 0), (1e200, 0), 2, "the arc from (0, 0) of radius 2 is too large to draw"),
            ((0, 0), (1e-150, 0), 1e150, "of radius 1e+150 is too large to draw"),
        ):
            with (
                self.subTest(radius=radius, end=end),
                self.assertRaisesRegex(bai.IconError, re.escape(problem)),
            ):
                bai._arc(start, end, radius, radius, large=False, clockwise=True)
        # Just inside them, a radius whose square still fits draws an arc so flat it is a line;
        # so does the largest radius a path may hold.
        flat = bai._arc((0, 0), (4, 0), 1e154, 1e154, large=False, clockwise=True)
        self.assertEqual(flat.radius, 1e154)
        self.assertEqual(list(flat.points(1e-3)), [(4, 0)])
        (widest,) = bai.parse_path("M0 0 A4096 4096 0 0 1 4 0")
        self.assertEqual(widest[0].radius, 4096)
        for path in ("M0 0 A4097 4097 0 0 1 4 0", "M0 0 A1e9 1e9 0 0 1 4 0"):
            with self.subTest(path=path), self.assertRaisesRegex(bai.IconError, "1/1024 of its"):
                bai.parse_path(path)

    def test_numbers_far_beyond_the_tile_are_refused(self) -> None:
        # The mark lives on a 32-unit tile, and the readers part ways on numbers far beyond it:
        # Android's parser fails on one past a 32-bit float, Skia skips an arc of radius 1e20 or
        # more, and the generator misjudges an arc's turn above about 1e16. So a number may be
        # at most 1e9 from 0, in either reading; 1e9 itself is allowed.
        for android in (False, True):
            self.assertEqual(
                bai.parse_path("M0 0A2 2 -1e9 0 1 4 0Z", android=android),
                bai.parse_path("M0 0A2 2 1000000000 0 1 4 0Z"),
            )
            for path, problem in (
                ("M1e309 0 4 4 0 4", "M command has the number 1e309, more than 1e+09 from 0"),
                ("M0 0 L-2e308 0", "L command has the number -2e308, more than 1e+09 from 0"),
                ("M0 0 H1000000000.5", "H command has the number 1000000000.5, more than"),
                ("M0 0 V-1e10", "V command has the number -1e10, more than 1e+09 from 0"),
                ("M0 0 A1e10 1e10 0 0 1 4 0", "A command has the number 1e10, more than 1e+09"),
                ("M0 0 A2 2 1e39 0 1 4 0", "A command has the number 1e39, more than 1e+09"),
                ("M0 0 a2 2 0 0 1 4 -2e9", "a command has the number -2e9, more than 1e+09"),
            ):
                with (
                    self.subTest(path=path, android=android),
                    self.assertRaisesRegex(bai.IconError, re.escape(f"the path's {problem}")),
                ):
                    bai.parse_path(path, android=android)
        with self.assertRaisesRegex(bai.IconError, "Android, browsers and this generator do not"):
            bai.parse_path("M0 0 L1e20 0")

    def test_what_32_bit_renderers_draw_otherwise_is_refused(self) -> None:
        rest = GABLES.removeprefix("M6 24")
        gables = bai.parse_path(GABLES, android=True)
        # Points beyond 1024 units: 32-bit floats read 999999990 as 1e9.
        for start, problem in (
            ("M999999990 0m-999999984 24", "M command reaches (1e+09, 0), more than 1024"),
            ("M16777217 0m-16777211 24", "M command reaches (1.67772e+07, 0), more than 1024"),
        ):
            with (
                self.subTest(start=start),
                self.assertRaisesRegex(bai.IconError, re.escape(problem)),
            ):
                bai.parse_path(start + rest, android=True)
        self.assertEqual(bai.parse_path("M1000 0m-994 24" + rest, android=True), gables)
        self.assertEqual(len(bai.parse_path("M0 0L1024 0 0 1Z")), 1)
        for path in ("M0 0L1024.5 0 0 1Z", "M0 0H-1025", "M0 0V2000", "M0 0A2 2 0 0 1 1025 0"):
            with self.subTest(path=path), self.assertRaisesRegex(bai.IconError, "more than 1024"):
                bai.parse_path(path)
        # An arc whose ends are under 1/1024 of its radius apart: Chrome may draw it whole.
        for old, new in (
            ("A2 2 0 0 0 18 16.5", "A1e9 1e9 0 0 0 18 16.5"),
            ("L28 18H26", "L28 18A1000 1000 0 0 0 27.99999 18H26"),
            ("A2 2 0 0 0 10 16.5", "A0.1 0.1 0 1 1 13.99999 16.5L10 16.5"),
        ):
            with self.subTest(new=new), self.assertRaisesRegex(bai.IconError, "1/1024 of its"):
                bai.parse_path(GABLES.replace(old, new), android=True)
        # Numbers in forms Chrome reads as none, whatever their value.
        for number in ("0e39", "-0.0E+039", "0" * 38 + "27"):
            with (
                self.subTest(number=number),
                self.assertRaisesRegex(bai.IconError, f"writes the number {re.escape(number)}"),
            ):
                bai.parse_path(f"M5 10h{number}H27V22H5Z", android=True)
        for number in ("0e38", "0e+038", "1e-50", "0" * 37 + "27", "27." + "0" * 60):
            with self.subTest(number=number):
                bai.parse_path(f"M5 10h{number}H27V22H5Z", android=True)

    def test_a_number_needs_a_digit_after_its_dot(self) -> None:
        # Browsers read a dot in a number only with a digit after it: Firefox and Chrome stop
        # drawing at "5." and "5.e0" (SVG 1.1's grammar allowed them). Android reads them, so the
        # refusal is the browsers', in either reading. A dot with a digit after it starts a number.
        square = bai.parse_path("M5 10H27V22H5Z")
        for path in ("M5.0 10H27.0V22H5Z", "M5 10H27V22H5.0Z"):
            with self.subTest(path=path):
                self.assertEqual(bai.parse_path(path), square)
        self.assertEqual(bai.parse_path("M0 0L.5.5 1 0"), bai.parse_path("M0 0L0.5 0.5 1 0"))
        for android in (False, True):
            for path, rest in (
                ("M5. 10H27V22H5Z", "5. 10H27V22H5Z"),
                ("M5.e0 10H27V22H5Z", "5.e0 10H27V22H5Z"),
                ("M5 1.e1H27V22H5Z", "1.e1H27V22H5Z"),
                ("M5 10H27V22H5.Z", "5.Z"),
                ("M5 10H27V22.H5Z", "22.H5Z"),
                ("M0 0A2 2 0 0 1. 4 0", "1. 4 0"),  # a flag
            ):
                with (
                    self.subTest(path=path, android=android),
                    self.assertRaisesRegex(
                        bai.IconError,
                        re.escape(f"the path has a number that ends in a dot, at {rest!r}"),
                    ),
                ):
                    bai.parse_path(path, android=android)

    def test_an_unreadable_path_is_shown_as_it_is(self) -> None:
        # The message shows what stopped the reading, escaped, past SVG's whitespace only: not
        # stripped as Python's str.strip() would strip a vertical tab, a no-break space or a NEL.
        for path, rest in (
            ("M5 10H27V22H5\vZ", "\x0bZ"),
            ("M5 10H27V22H5\u00a0Z", "\xa0Z"),
            ("M5 10H27V22H5 \u0085Z", "\x85Z"),
            ("M5 10H27V22H5 \t#Z", "#Z"),
        ):
            with (
                self.subTest(path=path),
                self.assertRaisesRegex(
                    bai.IconError, re.escape(f"cannot read the path at {rest!r}") + "$"
                ),
            ):
                bai.parse_path(path)

    def test_commas_stand_only_between_arguments(self) -> None:
        # SVG 2's path grammar: a comma, with whitespace around it, between two arguments (also
        # between repeated groups); only whitespace before or after a command letter. Browsers
        # differ on a comma anywhere else (Chrome reads past one before a command letter but
        # stops at one after Z), so the generator refuses it.
        square = bai.parse_path("M5 10H27V22H5Z")
        for path in (
            "M5,10H27V22H5Z",
            "M5 , 10 L27 ,10 , 27 22,5 22Z",
            " M 5 10 H 27 V 22 H 5 Z ",
            "M5\t10\nH27\rV22\fH5 Z",  # SVG's five whitespace characters
        ):
            with self.subTest(path=path):
                self.assertEqual(bai.parse_path(path), square)
        for path, rest in (
            ("M5 10H27,V22H5Z", ",V22H5Z"),  # before a command
            (",M5 10H27V22H5Z", ",M5 10H27V22H5Z"),
            ("M5 10H27V22H5 ,Z", ",Z"),
            ("M,5 10H27V22H5Z", ",5 10H27V22H5Z"),  # after a command
            ("M5 10H27V22H5Z,M5 10H6V11Z", ",M5 10H6V11Z"),
            ("M5,,10H27V22H5Z", ",10H27V22H5Z"),  # two between arguments
            ("M5 10H27V22H5Z,", ","),  # after the last
        ):
            with (
                self.subTest(path=path),
                self.assertRaisesRegex(
                    bai.IconError, re.escape(f"has a comma where SVG allows none, at {rest!r}")
                ),
            ):
                bai.parse_path(path)
        # SVG's whitespace and ASCII digits only: not a vertical tab, a no-break space or another
        # script's digits (Eastern Arabic five), which Python's \s, \d and float() all take.
        for path in ("M5\v10H27V22H5Z", "M5\u00a010H27V22H5Z", "M\u0665 10H27V22H5Z"):
            with (
                self.subTest(path=path),
                self.assertRaisesRegex(bai.IconError, "the path's M command lacks a number"),
            ):
                bai.parse_path(path)

    def test_the_android_reading_refuses_what_android_misreads(self) -> None:
        # The Android vector takes the mark's path as written, and Android's path parser (AOSP
        # libs/hwui/PathParser.cpp) ends a number only at a plain space, a comma, a minus sign or
        # the next command: to it a flag, a plus sign, a dot or a tab after a number is part of
        # that number. So the mark is read with android=True, which refuses all of them. (The
        # drawable's XML turns a tab, LF or CR in an attribute into a space and forbids a form
        # feed, so it would not hold such a path as written; PathParser given them misreads them.)
        compact = "M0 0a2 2 0 01 4 0"
        self.assertEqual(bai.parse_path(compact), bai.parse_path("M0 0a2 2 0 0 1 4 0"))
        for path in (
            "M0 0a2 2 0 0 1 4 0",
            "M0 0a2,2,0,0,1,4,0",
            "M4 0a2 2 0 0 1-4 0",  # a minus sign ends a number
            "M0 0L-1-2 3,-4 5 , 6Z",
            "M+1 2 L +3 4,+5 6",  # a plus sign after a command, a space or a comma
            "M0 0L1e+2 3E-1 2e1-3Z",  # an exponent's sign is its number's own
            GABLES,
        ):
            with self.subTest(path=path):
                self.assertEqual(bai.parse_path(path, android=True), bai.parse_path(path))
        for path, at in (
            (compact, "01 4 0"),  # Android reads one number, 1
            ("M0 0a2 2 0 0 1.5 0", "1.5 0"),
            ("M0 0A2+2 0 0 0 4 0", "2+2 0 0 0 4 0"),  # a plus sign as the separator
            ("M0 0L1+2", "1+2"),
            ("M0 0L1e1.5 2 3", "1e1.5 2 3"),  # Android reads 10 and loses the .5
            ("M0 0L.5.5", ".5.5"),  # one Android would split, refused to keep the rule simple
            # PathParser given these reads 1 and loses the 2, and reads -2 twice; the drawable's
            # XML would hold a space for the tab, LF or CR instead, and refuses a form feed.
            ("M0 0L1\t2", "\t2"),
            ("M0 0L1\n2", "\n2"),
            ("M0 0L1,\t-2", "\t-2"),
            ("M0 0L1 2\rZ", "\rZ"),
            ("\fM0 0L1 2", "\fM0 0L1 2"),
            ("M0 0a2 2 0 0\t1 4 0", "\t1 4 0"),
        ):
            with (
                self.subTest(path=path),
                self.assertRaisesRegex(
                    bai.IconError,
                    re.escape(f"Android's path parser may misread the path at {at!r}: it ends"),
                ),
            ):
                bai.parse_path(path, android=True)
        with self.assertRaisesRegex(bai.IconError, "the path's a command lacks a number"):
            bai.parse_path("M0 0a2 2 0 0 1", android=True)


class ArcTest(unittest.TestCase):
    def test_turns_grow_with_the_angle(self) -> None:
        # A whole circle's quarters, from the start in the arc's own sense.
        arc = bai.Arc((1, 0), (0, -1), (0, 0), 1, clockwise=True)
        turns = [
            arc.turn((math.cos(k * math.pi / 8), math.sin(k * math.pi / 8))) for k in range(16)
        ]
        self.assertEqual([round(turn, 9) for turn in turns[::4]], [0, 1, 2, 3])
        self.assertEqual(turns, sorted(turns))
        self.assertLess(turns[-1], 4)
        self.assertTrue(arc.covers((-1, 0)))  # half way round three quarters
        # A quarter turn anticlockwise on screen, from 3 o'clock up to 12.
        quarter = bai.Arc((1, 0), (0, -1), (0, 0), 1, clockwise=False)
        self.assertEqual(quarter.turn((0, -1)), 1)
        self.assertEqual(quarter.turn((0, 1)), 3)
        self.assertTrue(quarter.covers((1, -1)))
        self.assertFalse(quarter.covers((-1, 0)))  # past its end

    def test_chords_stay_within_the_tolerance(self) -> None:
        # A quarter, a half, three quarters and nearly a whole circle, each way round.
        for path in (
            "M12 6A4 4 0 0 1 16 2",
            "M12 6A4 4 0 0 0 20 6",
            "M12 6A4 4 0 1 1 16 2",
            "M12 6A4 4 0 1 0 12 6.01",
        ):
            (contour,) = bai.parse_path(path)
            arc = contour[0]
            for tolerance in (0.1, 1e-3, 1e-6):
                with self.subTest(path=path, tolerance=tolerance):
                    points = [arc.start, *arc.points(tolerance)]
                    self.assertEqual(points[-1], arc.end)
                    for (x0, y0), (x1, y1) in itertools.pairwise(points):
                        for x, y in ((x0, y0), ((x0 + x1) / 2, (y0 + y1) / 2)):
                            distance = math.hypot(x - arc.centre[0], y - arc.centre[1])
                            self.assertLessEqual(arc.radius - distance, tolerance * (1 + 1e-9))
                            self.assertLessEqual(distance - arc.radius, 1e-12)
                    # The chords turn the arc's way all along: none doubles back.
                    for a, b, c in zip(points, points[1:], points[2:], strict=False):
                        side = bai._side(a, b, c)
                        self.assertGreater(side if arc.clockwise else -side, 0)


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
        self.assertEqual((found.size, found.tile_radius), (32, 8))
        self.assertEqual(found.path, GABLES)
        self.assertEqual(found.contours, bai.parse_path(GABLES))

    def test_the_mark_needs_plain_literals_and_a_filled_glyph(self) -> None:
        source = (bai.ROOT / bai.BRAND).read_text(encoding="utf-8")
        self.assertEqual(bai.read_mark(self.brand(source)).path, GABLES)
        # Prettier puts the long path on the line after its name; on the same line reads too.
        one_line = re.sub(r"MARK_GLYPH_PATH =\s+", "MARK_GLYPH_PATH = ", source)
        self.assertNotEqual(one_line, source)
        self.assertEqual(bai.read_mark(self.brand(one_line)).path, GABLES)
        for old, new, problem in (
            ('"M6 24V18', 'HOUSE + "M6 24V18', "MARK_GLYPH_PATH as a plain literal"),
            ("export const MARK_TILE_RADIUS = 8;", "", "MARK_TILE_RADIUS as a plain literal"),
            # An ASCII number, as TypeScript needs (not an Eastern Arabic eight).
            ("MARK_TILE_RADIUS = 8;", "MARK_TILE_RADIUS = \u0668;", "MARK_TILE_RADIUS as a plain"),
            ('MARK_VIEWBOX = "0 0 32 32"', 'MARK_VIEWBOX = "0 0 32 24"', "a square"),
            ('MARK_VIEWBOX = "0 0 32 32"', 'MARK_VIEWBOX = "4 4 32 32"', "from the origin"),
            # Exactly "0 0 N N" in ASCII digits, as the website writes it into its SVGs: not
            # another script's digits, a no-break space, an exponent, "nan" or a zero side, which
            # Python's split() and float() would take.
            (
                '"0 0 32 32"',
                '"0 0 \u0663\u0662 \u0663\u0662"',
                '"0 0 N N" in ASCII digits, not \'0 0',
            ),
            ('"0 0 32 32"', '"0 0 32\u00a032"', "MARK_VIEWBOX must be a square from the origin"),
            ('"0 0 32 32"', '"0 0 3.2e1 3.2e1"', '"0 0 N N" in ASCII digits, not \'0 0 3.2e1'),
            ('"0 0 32 32"', '"0 0 nan nan"', "\"0 0 N N\" in ASCII digits, not '0 0 nan nan'"),
            ('"0 0 32 32"', '"0 0 0 0"', "\"0 0 N N\" in ASCII digits, not '0 0 0 0'"),
            ('"0 0 32 32"', '"0 0 32 32 "', "\"0 0 N N\" in ASCII digits, not '0 0 32 32 '"),
            # The viewBox and the tile markSvg draws in it are one square.
            ('"0 0 32 32"', '"0 0 48 48"', 'draw the tile as <rect width="48" height="48"'),
            (
                '<rect width="32"',
                '<rect width="31"',
                'sets; it has <rect width="31" height="32" ...>',
            ),
            (
                '<rect width="32" height="32"',
                '<rect width="32" height="31"',
                'sets; it has <rect width="32" height="31" ...>',
            ),
            (
                '<rect width="32" height="32"',
                '<rect height="32" width="32"',
                "it has no such <rect>",
            ),
            ('fill="${glyph}"/>', 'fill="${glyph}" stroke="${glyph}"/>', "strokes the mark"),
            ('fill="${glyph}"/>', 'fill="none" stroke-width="2"/>', "strokes the mark"),
            ("A2 2 0 0 0 18 16.5", "C22 14 18 14 18 16.5", "command C is not supported"),
            # As SVGO writes arcs: SVG reads it, Android's vector parser may not.
            ("A2 2 0 0 0 18 16.5", "A2 2 0 00 18 16.5", "Android's path parser may misread"),
            ("A2 2 0 0 0 18 16.5", "A2+2 0 0 0 18 16.5", "may misread the path at '2+2 0 0"),
            # A number that ends in a dot: Android reads it, browsers stop drawing at it.
            ("V18H4", "V18.H4", "a number that ends in a dot, at '18.H4L12 6L16 12"),
            # Numbers past what every reader draws alike: Android fails on 1e39 (past a 32-bit
            # float), Skia skips an arc of radius 1e20 or more.
            ("A2 2 0 0 0 18 16.5", "A2 2 1e39 0 0 18 16.5", "A command has the number 1e39"),
            ("A2 2 0 0 0 18 16.5", "A1e10 1e10 0 0 0 18 16.5", "has the number 1e10, more than"),
        ):
            with self.subTest(new=new):
                self.assertIn(old, source)
                with self.assertRaisesRegex(bai.IconError, re.escape(problem)):
                    bai.read_mark(self.brand(source.replace(old, new)))
        # Another square reads when markSvg draws its tile at that size too.
        larger = source.replace('"0 0 32 32"', '"0 0 48 48"').replace(
            '<rect width="32" height="32"', '<rect width="48" height="48"'
        )
        self.assertEqual(bai.read_mark(self.brand(larger)).size, 48)
        # A radius past half the tile's side is read, and refused by check_geometry.
        wide = bai.read_mark(self.brand(source.replace("RADIUS = 8;", "RADIUS = 16.5;")))
        self.assertEqual(wide.tile_radius, 16.5)
        with self.assertRaisesRegex(bai.IconError, "MARK_TILE_RADIUS must be from 0 to 16"):
            bai.check_geometry(wide)

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


class OutlineTest(unittest.TestCase):
    def test_the_twin_gables_are_one_outline_wound_once(self) -> None:
        gables = mark(GABLES)
        bai.check_outline(gables)
        (polygon,) = gables.polygons(1e-9)
        # The designer's area: 228 for the outline with straight doorway heads, less two half
        # circles of radius 2. Clockwise on screen, so the signed area is positive.
        self.assertAlmostEqual(bai._signed_area(polygon), 228 - 4 * math.pi, places=8)
        # Every level or upright edge on an even unit, so on whole pixels at 16, 32, 48 and 64 px.
        axis = [
            edge.start[0] if edge.start[0] == edge.end[0] else edge.start[1]
            for edge in gables.edges()
            if isinstance(edge, bai.Line)
            and (edge.start[0] == edge.end[0] or edge.start[1] == edge.end[1])
        ]
        self.assertEqual(len(axis), 11)
        self.assertTrue(all(value % 2 == 0 for value in axis))

    def test_a_hole_is_allowed_when_it_turns_the_other_way(self) -> None:
        bai.check_outline(mark("M4 4H28V28H4ZM10 10V22H22V10Z"))  # clockwise, then anticlockwise
        bai.check_outline(mark("M4 4H12V12H4ZM20 20H28V28H20Z"))  # two apart, the same way
        # An island in the hole turns the outer contour's way again.
        bai.check_outline(mark("M2 2H30V30H2ZM8 8V24H24V8ZM12 12H20V20H12Z"))

    def test_outlines_the_rasteriser_could_not_fill_exactly_are_refused(self) -> None:
        for path, problem in (
            ("M4 4 28 28 28 4 4 28Z", "crosses itself near"),  # a bow tie
            ("M4 4H28V28H4ZM10 2H22V30H10Z", "crosses itself near"),  # two that overlap
            ("M16 4A8 8 0 0 1 16 20A8 8 0 0 1 16 4ZM4 12H28V14H4Z", "crosses itself near"),
            # Contours that touch: the same shape twice (every edge wound twice, so its edge
            # pixels would be filled whole), and a square inside another sharing its corner.
            ("M4.5 4.5H27.5V27.5H4.5ZM4.5 4.5H27.5V27.5H4.5Z", "touches itself near"),
            ("M4 4H28V28H4ZM4 4H16V16H4Z", "touches itself near"),
            ("M4 4H28V28H4ZM28 4H30V28H28Z", "touches itself near"),  # side by side, one edge
            ("M4 4H16V16H4ZM16 16H28V28H16Z", "touches itself near"),  # corner to corner
            ("M4 4H28V28H16V20H20V28H4Z", "touches itself near"),  # one contour, pinched
            ("M4 4 8 8 12 12Z", "encloses nothing"),
            ("M4 4H28V28H4ZM10 10H22V22H10Z", "must alternate direction"),  # a hole wound twice
            ("M4 4H12V12H4ZM20 20V28H28V20Z", "must alternate direction"),  # apart, opposite ways
        ):
            with self.subTest(path=path), self.assertRaisesRegex(bai.IconError, problem):
                bai.check_outline(mark(path))

    def test_arcs_are_judged_by_their_chords(self) -> None:
        # check_outline judges the polygon of chords within OUTLINE_FLATNESS of each arc, not the
        # arc itself, so an edge that comes that close to an arc can be judged either way. On a
        # circle of radius 8: the chord after its top, how far it sags inside the arc, and which
        # way is out.
        circle = "M8 16A8 8 0 0 1 24 16A8 8 0 0 1 8 16Z"
        (polygon,) = mark(circle).polygons(bai.OUTLINE_FLATNESS)
        top = polygon.index((16, 8))
        (x0, y0), (x1, y1) = polygon[top], polygon[top + 1]
        mx, my = (x0 + x1) / 2 - 16, (y0 + y1) / 2 - 16
        middle = math.hypot(mx, my)  # from the centre to the chord
        sag = 8 - middle
        self.assertTrue(1e-4 < sag <= bai.OUTLINE_FLATNESS)
        nx, ny = mx / middle, my / middle

        def triangle(depth: float, apex: float) -> str:
            """A triangle whose base, 0.1 long, runs along the chord [depth] outside it, and whose
            apex is [apex] further out: an island when that is outwards, else a hole."""
            d = middle + depth
            corners = [
                (16 + nx * d - ny * 0.05, 16 + ny * d + nx * 0.05),
                (16 + nx * d + ny * 0.05, 16 + ny * d - nx * 0.05),
                (16 + nx * (d + apex), 16 + ny * (d + apex)),
            ]
            if (bai._signed_area(corners) > 0) != (apex > 0):  # a hole turns the other way
                corners.reverse()
            return "M" + "L".join(f"{x!r} {y!r}" for x, y in corners) + "Z"

        # An island whose base lies between the chord and the arc overlaps the circle, yet passes;
        # a hole there lies wholly inside the circle, yet is refused.
        self.assertLess(middle + sag / 2, 8)  # the island's base runs inside the circle
        self.assertLess(math.hypot(middle + sag / 2, 0.05), 8)  # the hole's base, ends and all
        bai.check_outline(mark(circle + triangle(sag / 2, 1)))
        with self.assertRaisesRegex(bai.IconError, "crosses itself near"):
            bai.check_outline(mark(circle + triangle(sag / 2, -1)))
        # Inside the chord, the hole passes and the island is refused, as the arcs would be.
        bai.check_outline(mark(circle + triangle(-sag / 2, -1)))
        with self.assertRaisesRegex(bai.IconError, "crosses itself near"):
            bai.check_outline(mark(circle + triangle(-sag / 2, 1)))
        # At a corner an edge shares with an arc, the arc's last chord stands for the arc too: a
        # line that turns back from the arc's end 0.005 radians inside its tangent crosses the arc
        # 0.08 units on and leaves the circle, yet the outline passes. (The twin gables' walls
        # meet their arches along the tangent, outside the circle.)
        turn = 0.005
        back = (24 - math.sin(turn) * 0.2, 16 - math.cos(turn) * 0.2)
        self.assertGreater(math.dist(back, (16, 16)), 8)  # outside the circle again
        crossing = (16 + 8 * math.cos(2 * turn), 16 - 8 * math.sin(2 * turn))  # on the arc
        self.assertLess(abs(bai._side((24, 16), back, crossing)), 1e-12)  # and on the line
        self.assertAlmostEqual(math.dist((24, 16), crossing), 0.08, places=6)
        cusp = f"M8 16A8 8 0 0 1 24 16L{back[0]!r} {back[1]!r}L30 {back[1]!r}L30 2L2 2L2 16Z"
        bai.check_outline(mark(cusp))

    def test_an_outline_too_detailed_to_check_is_refused(self) -> None:
        # A long arc of a circle 1e9 units across would take millions of chords, compared in
        # pairs: the check stops once the outline passes its limit, before drawing the rest.
        with self.assertRaisesRegex(bai.IconError, "needs more than 4096 straight sides"):
            bai.check_outline(mark("M10 16A12000 12000 0 1 1 22 16Z"))
        # An arc counts its chords and a line one side, up to the limit and not past it.
        half = mark("M12 16A4 4 0 0 1 20 16Z")
        sides = sum(len(polygon) for polygon in half.polygons(bai.OUTLINE_FLATNESS))
        self.assertEqual(sides, 129)  # 128 chords and the line back
        with mock.patch.object(bai, "OUTLINE_MOST_SIDES", sides):
            bai.check_outline(half)
        with (
            mock.patch.object(bai, "OUTLINE_MOST_SIDES", sides - 1),
            self.assertRaisesRegex(bai.IconError, "needs more than 128 straight sides"),
        ):
            bai.check_outline(half)
        with mock.patch.object(bai, "OUTLINE_MOST_SIDES", 6):
            bai.check_outline(mark("M10 4H22L28 16L22 28H10L4 16Z"))  # a hexagon
            with self.assertRaisesRegex(bai.IconError, "needs more than 6 straight sides"):
                bai.check_outline(mark("M10 4H22L28 14L26 24L16 28L6 24L4 14Z"))
        # The limit leaves room for eight whole circles as large as the safe zones allow (the
        # maskable one: 13.65 units), each 512 sides; the twin gables take 143.
        circle = mark("M2.4 16A13.6 13.6 0 1 1 29.6 16A13.6 13.6 0 1 1 2.4 16Z")
        bai.check_geometry(circle)
        self.assertEqual(sum(map(len, circle.polygons(bai.OUTLINE_FLATNESS))), 512)
        self.assertEqual(sum(map(len, mark(GABLES).polygons(bai.OUTLINE_FLATNESS))), 143)
        self.assertEqual(bai.OUTLINE_MOST_SIDES, 8 * 512)

    def test_the_doubled_outline_would_have_been_filled_wrongly(self) -> None:
        # Why touching is refused: the square drawn twice fills its edge pixels whole, where a
        # browser fills them by half, and adds 45 to its area.
        once = mark("M4.5 4.5H27.5V27.5H4.5Z")
        twice = mark("M4.5 4.5H27.5V27.5H4.5ZM4.5 4.5H27.5V27.5H4.5Z")
        single = bai.area_coverage(once.polygons(bai.FLATNESS), 32)
        double = bai.area_coverage(twice.polygons(bai.FLATNESS), 32)
        self.assertEqual((single[10 * 32 + 4], double[10 * 32 + 4]), (0.5, 1.0))
        self.assertEqual((sum(single), sum(double)), (23 * 23, 24 * 24 - 4 * 0.5))


class GeometryTest(unittest.TestCase):
    def test_the_twin_gables_sit_inside_every_safe_zone(self) -> None:
        gables = bai.read_mark(bai.ROOT / bai.BRAND)
        bai.check_geometry(gables)
        # From the tile's centre to the bottom corners (6, 24) and (26, 24), just past the eaves.
        self.assertAlmostEqual(gables.reach(), math.hypot(10, 8))
        self.assertEqual(gables.box(), (4, 6, 28, 24))
        dp = 72 / 32
        self.assertAlmostEqual(gables.reach() * dp, 28.81, places=2)  # under the 33 dp radius
        left, top, right, bottom = gables.box()
        self.assertEqual(((right - left) * dp, (bottom - top) * dp), (54, 40.5))  # over 48 dp
        # At the tile's own scale it would reach just past a maskable icon's 40% circle; at the
        # maskable icons' 15/16 it stays inside, at 37.5%.
        self.assertGreater(gables.reach() / 32, 0.4)
        self.assertAlmostEqual(gables.reach() * bai.MASKABLE_GLYPH_SCALE / 32, 0.3752, places=4)

    def test_a_reach_counts_an_arc_only_where_it_runs(self) -> None:
        # A half circle around (16, 6): over the top it passes (16, 2), 14 from the centre;
        # under, its ends are the farthest points.
        self.assertEqual(mark("M12 6A4 4 0 0 1 20 6Z").reach(), 14)
        self.assertAlmostEqual(mark("M12 6A4 4 0 0 0 20 6Z").reach(), math.hypot(4, 10))
        self.assertEqual(mark("M12 16A4 4 0 0 1 20 16Z").reach(), 4)  # around the centre itself

    def test_the_tile_corners_are_at_most_half_its_side(self) -> None:
        # SVG draws a rect's rx as at most half its width, so a larger MARK_TILE_RADIUS would draw
        # one tile on the website and another here. Half the side draws a circle.
        contours = bai.parse_path(GABLES)
        for radius in (0, 8, 16):
            bai.check_geometry(bai.Mark(32, radius, GABLES, contours))
        for radius in (16.25, 40, -1):
            with (
                self.subTest(radius=radius),
                self.assertRaisesRegex(
                    bai.IconError,
                    re.escape(
                        f"MARK_TILE_RADIUS must be from 0 to 16 (half the tile's side), not {radius:g}"
                    ),
                ),
            ):
                bai.check_geometry(bai.Mark(32, radius, GABLES, contours))

    def test_the_reach_limits_keep_the_house_inside_every_shaped_tile(self) -> None:
        # check_geometry's argument, on the real icons whose tile or circle leaves transparent
        # corners: a house that passes reaches at most the nearer of the two safe limits from the
        # tile's centre (13.65 of 32 units, the maskable one), so every pixel it touches has its
        # centre within that reach, at the icon's scale, and half a pixel's diagonal. Each such
        # pixel must be wholly opaque, whatever corner radius the tile has (render blends the
        # house into the tile's colour and takes the tile's alpha), down to the smallest tile.
        adaptive = bai.ADAPTIVE_SAFE_DIAMETER_DP / 2 / (bai.ADAPTIVE_VISIBLE_DP / 32)
        maskable = bai.MASKABLE_SAFE_SHARE / 2 / bai.MASKABLE_GLYPH_SCALE * 32
        limit = min(adaptive, maskable)
        palette = bai.read_palette(bai.ROOT / bai.TOKENS)
        shaped = [icon for icon in bai.icons(palette) if icon.alpha and icon.shape != "square"]
        self.assertEqual(len(shaped), 13)  # ten legacy icons, the favicon and two web icons
        self.assertGreaterEqual(min(icon.size * icon.share for icon in shaped), 17)
        for icon in shaped:
            side = icon.size * icon.share
            near = limit * side * icon.glyph_scale / 32 + math.sqrt(1 / 2)
            centre = icon.size / 2
            touched = [
                row * icon.size + column
                for row in range(icon.size)
                for column in range(icon.size)
                if math.hypot(column + 0.5 - centre, row + 0.5 - centre) <= near
            ]
            for radius in (0, 4, 8, 12, 16):
                shape = bai.shape_coverage(icon.shape, icon.size, side, radius * side / 32)
                with self.subTest(path=icon.path, radius=radius):
                    self.assertEqual({shape[index] for index in touched}, {255})

    def test_a_house_past_a_limit_is_refused(self) -> None:
        for path, problem in (
            # Corners past the adaptive icon's 66 dp circle (15.13 units, 34.05 dp).
            ("M1 14H31V18H1Z", "reaches 34.05 dp from the adaptive icon's centre"),
            # A dome whose top alone passes it: (16, 1) is 15 from the centre.
            ("M4 24V18H13V4A3 3 0 0 1 19 4V18H28V24Z", "reaches 33.75 dp"),
            # 20 units wide is 45 dp: smaller than Android's 48 dp logo.
            ("M6 10H26V22H6Z", "is 45.00 dp across in the adaptive icon, less than the 48 dp"),
            # Inside the adaptive circle, but past the maskable one even at 15/16 (13.84 units).
            ("M2.2 15H29.8V17H2.2Z", "reaches 40.54% of a maskable icon's width"),
            # The dome turned inwards: only its corners count, and they are past the maskable.
            ("M4 24V18H13V4A3 3 0 0 0 19 4V18H28V24Z", "reaches 42.25% of a maskable icon"),
        ):
            with self.subTest(path=path), self.assertRaisesRegex(bai.IconError, re.escape(problem)):
                bai.check_geometry(mark(path))
        # Either side of each limit, with a flat diamond whose side points are its reach and
        # whose width is twice that. The adaptive circle (14.67 units) lies outside the maskable
        # one (13.65 units at 15/16), so a house just inside the first stops at the second.
        for reach, problem in (
            (66 / 2 / 2.25 - 1e-4, "past its safe circle of 40%"),
            (66 / 2 / 2.25 + 1e-4, "past the 33 dp of its safe circle"),
            (0.4 * 32 * 16 / 15 - 1e-6, None),
            (0.4 * 32 * 16 / 15 + 1e-6, "past its safe circle of 40%"),
            (48 / 2 / 2.25 + 1e-6, None),
            (48 / 2 / 2.25 - 1e-6, "less than the 48 dp"),
        ):
            diamond = mark(f"M{16 - reach} 16L16 12L{16 + reach} 16L16 20Z")
            with self.subTest(reach=reach):
                if problem is None:
                    bai.check_geometry(diamond)
                else:
                    with self.assertRaisesRegex(bai.IconError, re.escape(problem)):
                        bai.check_geometry(diamond)


class RasterTest(unittest.TestCase):
    def test_coverage_ramps_across_one_pixel(self) -> None:
        self.assertEqual(
            [bai._coverage(d) for d in (-1, -0.5, -0.25, 0, 0.25, 0.5, 1)],
            [255, 255, 191, 128, 64, 0, 0],
        )

    def test_a_rectangle_covers_exactly_its_area(self) -> None:
        # From x 1.25 to 3.5 and y 0.5 to 2: a pixel's share is its overlap across times down.
        left, top, right, bottom = 1.25, 0.5, 3.5, 2.0
        expected = [
            max(0.0, min(x + 1, right) - max(x, left)) * max(0.0, min(y + 1, bottom) - max(y, top))
            for y in range(4)
            for x in range(4)
        ]
        rectangle = [(left, top), (right, top), (right, bottom), (left, bottom)]
        for polygon in (rectangle, rectangle[::-1]):  # either way round
            shares = bai.area_coverage([polygon], 4)
            self.assertEqual([round(share, 12) for share in shares], expected)
        self.assertEqual(
            list(bai.fill_coverage(mark(f"M{left} {top}H{right}V{bottom}H{left}Z"), 4, 1.0, 0.0)),
            [int(share * 255 + 0.5) for share in expected],
        )

    def test_sloping_edges_match_the_exact_reference(self) -> None:
        # Edges that cross many pixels in a row, two, and one; a triangle each way round.
        triangle = [(0.3, 0.2), (7.7, 1.1), (2.2, 7.9)]
        steep = [(3.1, 0.0), (3.9, 8.0), (2.6, 8.0)]
        for polygon in (triangle, triangle[::-1], steep):
            with self.subTest(polygon=polygon):
                shares = bai.area_coverage([polygon], 8)
                exact = exact_shares([polygon], 8)
                self.assertLess(max(abs(a - b) for a, b in zip(shares, exact, strict=True)), 1e-12)
        x0, y0, x1, y1, x2, y2 = (value for point in triangle for value in point)
        area = abs((x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)) / 2
        self.assertAlmostEqual(sum(bai.area_coverage([triangle], 8)), area, places=12)

    def test_holes_are_cut_out_exactly(self) -> None:
        outer = [(0, 0), (4, 0), (4, 4), (0, 4)]
        hole = [(1.5, 1.5), (1.5, 2.5), (2.5, 2.5), (2.5, 1.5)]  # the other way round
        shares = bai.area_coverage([outer, hole], 4)
        self.assertEqual(shares[0], 1)
        self.assertEqual(shares[1 * 4 + 1 : 1 * 4 + 3], [0.75, 0.75])
        self.assertEqual(shares[2 * 4 + 1 : 2 * 4 + 3], [0.75, 0.75])
        self.assertAlmostEqual(sum(shares), 16 - 1)

    def test_edges_on_the_canvas_edge_are_drawn(self) -> None:
        # Up to the right edge, where the last column's change falls into the next row's first
        # cell, and in the bottom right corner, two cells past the image.
        right = bai.area_coverage([[(2.5, 1), (4, 1), (4, 3), (2.5, 3)]], 4)
        self.assertEqual(right, [0, 0, 0, 0, 0, 0, 0.5, 1, 0, 0, 0.5, 1, 0, 0, 0, 0])
        corner = bai.area_coverage([[(1, 3), (4, 3), (4, 4), (1, 4)]], 4)
        self.assertEqual(corner, [0] * 12 + [0, 1, 1, 1])
        whole = bai.area_coverage([[(0, 0), (4, 0), (4, 4), (0, 4)]], 4)
        self.assertEqual(whole, [1] * 16)

    def test_a_shape_off_the_canvas_is_refused(self) -> None:
        # Moving corners onto the canvas would move sloping edges too: this triangle lies wholly
        # outside the canvas, yet clamped it would cover 2 pixels.
        for polygon in (
            [(-4, 2), (2, -4), (-4, -4)],
            [(-2, -2), (2.5, -2), (2.5, 2.5), (-2, 2.5)],
            [(2.5, 1), (4.001, 1), (4.001, 3), (2.5, 3)],
            [(1, 3), (4, 3), (4, 4.5), (1, 4.5)],
        ):
            with (
                self.subTest(polygon=polygon),
                self.assertRaisesRegex(bai.IconError, "runs off the 4 x 4 canvas"),
            ):
                bai.area_coverage([polygon], 4)

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
            bai.render(mark(GABLES), icon)

    def test_render_blends_the_colours_by_coverage(self) -> None:
        icon = bai.Icon("x.png", 32, "tile", 1, "#102030", "#F0E0D0", alpha=True)
        header, image = bai.render(mark(GABLES), icon)
        self.assertEqual(header, struct.pack(">IIBBBBB", 32, 32, 8, bai.RGBA, 0, 0, 0))
        self.assertEqual(len(image), 32 * 32 * 4)
        rows = pixels(header, image)
        tile, glyph = bytes([0x10, 0x20, 0x30]), bytes([0xF0, 0xE0, 0xD0])
        self.assertEqual(rows[0][:4], tile + b"\x00")  # transparent corner
        self.assertEqual(rows[16][:4], tile + b"\xff")  # edge of the tile
        self.assertEqual(rows[23][14 * 4 : 15 * 4], glyph + b"\xff")  # the pier
        self.assertEqual(rows[23][12 * 4 : 13 * 4], tile + b"\xff")  # a doorway
        # The level and upright edges lie on whole pixels, sharp (the wall at x 6); the roofs
        # and the doorway heads are anti-aliased, in colours between the two.
        self.assertEqual(rows[20][5 * 4 : 7 * 4], tile + b"\xff" + glyph + b"\xff")
        colours = {rows[y][x * 4 : x * 4 + 3] for y in range(32) for x in range(32)}
        self.assertGreater(len(colours - {tile, glyph}), 5)

    def test_a_smaller_glyph_shrinks_about_the_tile_centre(self) -> None:
        # At 15/16 on a 512 px square: 15 px a unit from 16 px in, so the outer walls at x 6
        # and 26 land on whole pixels, 106 and 406, and the ground at y 24 on 376.
        icon = bai.Icon("x.png", 512, "square", 1, "#000000", "#FFFFFF", False, 15 / 16)
        coverage = bai.fill_coverage(mark(GABLES), 512, 15, 16)
        self.assertEqual(bai.render(mark(GABLES), icon)[1][::3], coverage)
        row = coverage[370 * 512 : 371 * 512]
        self.assertEqual((row[105], row[106], row[405], row[406]), (0, 255, 255, 0))
        self.assertEqual((coverage[375 * 512 + 256], coverage[376 * 512 + 256]), (255, 0))


class ExactRenderTest(unittest.TestCase):
    """The generator's coverage of the real mark, at every size and place an icon draws it,
    against an exact render made here from the designer's description."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.gables = bai.read_mark(bai.ROOT / bai.BRAND)
        placements = set()
        for icon in bai.icons(bai.read_palette(bai.ROOT / bai.TOKENS)):
            scale = icon.size * icon.share * icon.glyph_scale / 32
            placements.add((icon.size, scale, (icon.size - 32 * scale) / 2))
        cls.placements = sorted(placements)

    def test_every_pixel_is_the_exact_share_rounded(self) -> None:
        # Ten legacy icons; Play and the 512 px web icon; iOS; the favicon; the 192 px web icon;
        # the iOS touch icon; and the two maskable icons.
        self.assertEqual(len(self.placements), 17)
        for size, scale, offset in self.placements:
            with self.subTest(size=size, scale=scale):
                exact = exact_shares([twin_gables(scale, offset)], size)
                worst = worst_rounding(bai.fill_coverage(self.gables, size, scale, offset), exact)
                # Half a level of rounding, a quarter for the chords (FLATNESS), and the
                # reference's own chords, a thousandth.
                self.assertLessEqual(worst, 0.5 + 0.25 + 0.001)
                self.assertAlmostEqual(sum(exact) / scale**2, 228 - 4 * math.pi, places=4)

    def test_the_comparison_sees_a_coarser_or_turned_arc(self) -> None:
        exact = exact_shares([twin_gables(32, 0)], 1024)
        bai.fill_coverage.cache_clear()
        self.addCleanup(bai.fill_coverage.cache_clear)
        with mock.patch.object(bai, "FLATNESS", bai.FLATNESS * 1000):
            coarse = bai.fill_coverage(self.gables, 1024, 32.0, 0.0)
        self.assertGreater(worst_rounding(coarse, exact), 1)
        turned = mark(GABLES.replace("A2 2 0 0 0", "A2 2 0 0 1"))  # doorways with round sills
        self.assertGreater(worst_rounding(bai.fill_coverage(turned, 1024, 32.0, 0.0), exact), 100)


class PngTest(unittest.TestCase):
    def test_a_written_png_reads_back(self) -> None:
        icon = bai.Icon("x.png", 8, "square", 1, "#000000", "#FFFFFF", alpha=False)
        content = bai.render(mark(GABLES), icon)
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
            header, image = bai.render(mark(GABLES), icon)
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
        cls.gables = bai.read_mark(bai.ROOT / bai.BRAND)

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
            f"{bai.WEB}/icons/Icon-apple-180.png": (180, 180, bai.RGB),
        }
        self.assertEqual({path: self.size_and_type(path) for path in self.outputs.images}, expected)

    def test_full_square_icons_are_opaque_to_the_corners(self) -> None:
        primary = bytes.fromhex(self.palette.primary[1:])
        for path, channels in (
            (bai.PLAY_ICON, 4),
            (f"{bai.APP_ICON_SET}/AppIcon.png", 3),
            (f"{bai.WEB}/icons/Icon-apple-180.png", 3),
        ):
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

    def test_the_tinted_icon_is_the_glyphs_coverage_in_grey(self) -> None:
        rows = pixels(*self.outputs.images[f"{bai.APP_ICON_SET}/AppIcon-tinted.png"])
        self.assertTrue(all(row[0::3] == row[1::3] == row[2::3] for row in rows))
        # Black to white: each pixel's grey is the house's coverage, checked against an exact
        # render in ExactRenderTest.
        coverage = bai.fill_coverage(self.gables, 1024, 32.0, 0.0)
        self.assertEqual(b"".join(row[0::3] for row in rows), coverage)

    def test_the_dark_icon_uses_the_dark_theme(self) -> None:
        rows = pixels(*self.outputs.images[f"{bai.APP_ICON_SET}/AppIcon-dark.png"])
        self.assertEqual(rows[0][:3], bytes.fromhex(self.palette.dark_on_primary[1:]))
        pier = rows[20 * 32][16 * 32 * 3 : 16 * 32 * 3 + 3]  # the pier between the doorways
        self.assertEqual(pier, bytes.fromhex(self.palette.dark_primary[1:]))

    def reach(self, path: str) -> float:
        """How far from the centre the farthest corner of any pixel the house touches lies, as
        a share of the icon's width."""
        header, image = self.outputs.images[path]
        size, channels = struct.unpack(">I", header[:4])[0], 4 if header[9] == bai.RGBA else 3
        primary = bytes.fromhex(self.palette.primary[1:])
        return (
            max(
                math.hypot(abs(x + 0.5 - size / 2) + 0.5, abs(y + 0.5 - size / 2) + 0.5)
                for y, row in enumerate(pixels(header, image))
                for x in range(size)
                if row[x * channels : x * channels + 3] != primary
            )
            / size
        )

    def test_the_house_lies_where_the_tile_is_opaque(self) -> None:
        # check_geometry's argument, on every icon with an alpha channel: each pixel the house
        # touches is wholly opaque, inside the tile's or the circle's anti-aliased edge.
        found = 0
        for icon in bai.icons(self.palette):
            if icon.alpha:
                _, image = self.outputs.images[icon.path]
                scale = icon.size * icon.share * icon.glyph_scale / 32
                offset = (icon.size - 32 * scale) / 2
                glyph = bai.fill_coverage(self.gables, icon.size, scale, offset)
                alphas = {a for a, cover in zip(image[3::4], glyph, strict=True) if cover}
                with self.subTest(path=icon.path):
                    self.assertEqual(alphas, {255})
                    self.assertLess(min(image[3::4]), 255 if icon.shape != "square" else 256)
                found += 1
        self.assertEqual(found, 14)  # ten legacy icons, Play, the favicon and two web icons

    def test_the_maskable_icons_keep_the_house_inside_the_safe_circle(self) -> None:
        for size in (192, 512):
            with self.subTest(size=size):
                self.assertLess(self.reach(f"{bai.WEB}/icons/Icon-maskable-{size}.png"), 0.4)
                # At the tile's own scale, the plain icon's house reaches past that circle.
                self.assertGreater(self.reach(f"{bai.WEB}/icons/Icon-{size}.png"), 0.4)

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

    def test_the_foreground_fills_the_mark_in_the_safe_zone(self) -> None:
        vector = xml(self.outputs.texts[f"{bai.RES}/drawable/ic_launcher_foreground.xml"])
        self.assertEqual(vector.get(f"{ANDROID}viewportWidth"), "108")
        group = vector.find("group")
        self.assertEqual(group.get(f"{ANDROID}translateX"), "18")
        self.assertEqual(group.get(f"{ANDROID}scaleX"), "2.25")
        (path,) = group.findall("path")
        self.assertEqual(
            dict(path.attrib),
            {f"{ANDROID}pathData": GABLES, f"{ANDROID}fillColor": self.palette.on_primary},
        )  # filled, with no stroke: the monochrome layer is this drawable too

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

    def test_icon_links_are_read_as_browsers_read_rel(self) -> None:
        # rel is a set of space-separated tokens, in any case: a link in capitals or with spaces
        # around its token is an icon link all the same, and one without rel is none.
        self.assertEqual(
            icon_links(
                '<link rel="ICON" href="a.png"><link href="b.png" rel=" Apple-Touch-Icon ">'
                '<link rel="icon " href="c.png"><link rel="stylesheet" href="d.css"><link rel>'
            ),
            [("icon", "a.png"), ("apple-touch-icon", "b.png"), ("icon", "c.png")],
        )

    def test_the_web_page_links_generated_icons(self) -> None:
        # Each icon link's rel with its own href, whatever the attributes' order: two links that
        # swapped their files would fail here, and so would another icon link in any case.
        page = (bai.ROOT / bai.WEB / "index.html").read_text(encoding="utf-8")
        expected = [("apple-touch-icon", "icons/Icon-apple-180.png"), ("icon", "favicon.png")]
        icons = icon_links(page)
        self.assertEqual(sorted(icons), expected)
        self.assertIn('rel="icon"', page)
        self.assertEqual(sorted(icon_links(page.replace('rel="icon"', 'rel="icon "'))), expected)
        extra = page.replace("</head>", '<link rel="ICON" href="old.ico"></head>')
        self.assertNotEqual(sorted(icon_links(extra)), expected)
        # Each points to a generated icon, committed as generated: the favicon is the 32 px tile,
        # transparent outside its rounded corners.
        for _, href in icons:
            path = f"{bai.WEB}/{href}"
            with self.subTest(href=href):
                self.assertIsNone(bai._image_problem(bai.ROOT, path, *self.outputs.images[path]))
        self.assertEqual(self.size_and_type(f"{bai.WEB}/favicon.png"), (32, 32, bai.RGBA))
        self.assertEqual(pixels(*self.outputs.images[f"{bai.WEB}/favicon.png"])[0][3], 0)
        # iOS shows transparency as black, so its touch icon is an opaque full square; and it
        # applies no maskable circle, so the house there is at the tile's scale, as on the iOS
        # app icon, not shrunk as on the maskable icons.
        touch = f"{bai.WEB}/icons/Icon-apple-180.png"
        self.assertEqual(self.size_and_type(touch), (180, 180, bai.RGB))
        self.assertAlmostEqual(self.reach(touch), self.reach(f"{bai.WEB}/icons/Icon-512.png"), 2)
        self.assertGreater(self.reach(touch), self.reach(f"{bai.WEB}/icons/Icon-maskable-192.png"))


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

    def test_a_rerun_writes_the_same_bytes(self) -> None:
        bai.write(self.root)
        written = {
            path: path.read_bytes() for path in sorted(self.root.rglob("*")) if path.is_file()
        }
        for path in written:
            if path.suffix == ".png":
                path.unlink()
        bai.fill_coverage.cache_clear()
        bai.write(self.root)
        self.assertEqual(
            {path: path.read_bytes() for path in sorted(self.root.rglob("*")) if path.is_file()},
            written,
        )

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

    def test_a_changed_mark_is_reported_and_a_bad_one_refused(self) -> None:
        bai.write(self.root)
        brand = self.root / bai.BRAND
        source = brand.read_text(encoding="utf-8")
        # Doorways 1 unit narrower: the vector and every PNG change.
        brand.write_text(source.replace("H22V16.5A2 2", "H21V16.5A1 1"), encoding="utf-8")
        self.assertEqual(
            set(bai.problems(self.root)),
            {
                f"{bai.RES}/drawable/ic_launcher_foreground.xml is missing or stale",
                f"{bai.APP_ICON_SET}/AppIcon.png does not hold the generated pixels",
                f"{bai.WEB}/favicon.png does not hold the generated pixels",
            },
        )
        # Eaves 2 units wider pass the maskable circle: refused, and nothing is written.
        before = {path: path.read_bytes() for path in self.root.rglob("*.png")}
        wide = source.replace("H4L12 6", "H2L12 6").replace("L28 18", "L30 18")
        self.assertNotEqual(wide, source)
        brand.write_text(wide, encoding="utf-8")
        with self.assertRaisesRegex(bai.IconError, "maskable"):
            bai.write(self.root)
        self.assertEqual({path: path.read_bytes() for path in self.root.rglob("*.png")}, before)

    def test_a_house_past_the_safe_zone_is_refused_before_its_outline_is_drawn(self) -> None:
        # check_geometry measures each arc where it runs, so it refuses this long arc of a
        # circle 1e9 units across before check_outline would draw it as chords.
        brand = self.root / bai.BRAND
        source = brand.read_text(encoding="utf-8")
        huge = source.replace(GABLES, "M10 16A12000 12000 0 1 1 22 16Z")
        self.assertNotEqual(huge, source)
        brand.write_text(huge, encoding="utf-8")
        with self.assertRaisesRegex(bai.IconError, r"reaches \d+\.\d\d dp from the adaptive icon"):
            bai.problems(self.root)

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
                (self.root / bai.WEB / "manifest.json").write_text("{", encoding="utf-8")
                self.assertEqual(bai.main([]), 1)
                self.assertIn("error: app/web/manifest.json is not valid JSON", err.getvalue())
                (self.root / bai.TOKENS).write_text("{}", encoding="utf-8")
                self.assertEqual(bai.main(["--check"]), 1)
                self.assertIn("error: no colour token light.primary", err.getvalue())

    def test_the_script_runs_main(self) -> None:
        err = io.StringIO()
        with (
            mock.patch.object(sys, "argv", ["build_app_icons.py", "--bogus"]),
            contextlib.redirect_stderr(err),
            self.assertRaises(SystemExit) as caught,
        ):
            runpy.run_path(str(Path(bai.__file__)), run_name="__main__")
        self.assertEqual(caught.exception.code, 2)
        self.assertIn("usage: tool/design/build_app_icons.py [--check]", err.getvalue())


if __name__ == "__main__":
    unittest.main()
