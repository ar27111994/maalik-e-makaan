"""Tests for the repository text guard (python3 -m unittest discover -s tool -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
import check_unicode  # noqa: E402

RANGES = check_unicode.load_forbidden()


def char(cp: int) -> str:
    return chr(cp)


class ContractTest(unittest.TestCase):
    def test_the_guard_forbids_exactly_the_contract(self) -> None:
        contract = json.loads(check_unicode.CONTRACT.read_text(encoding="utf-8"))
        expected = {
            cp
            for r in contract["forbidden"]
            for cp in range(check_unicode.code_point(r["from"]), check_unicode.code_point(r["to"]) + 1)
        }
        flagged = {cp for cp in range(0x110000) if check_unicode.reason_for(cp, RANGES) is not None}
        self.assertEqual(flagged, expected)

    def test_text_file_essentials_and_urdu_are_allowed(self) -> None:
        for cp in (0x09, 0x0A, 0x0D, 0x200C, 0x200D, 0x200E, 0x200F, 0x0627):
            self.assertIsNone(check_unicode.reason_for(cp, RANGES), hex(cp))

    def test_rejects_malformed_contracts(self) -> None:
        with self.assertRaises(ValueError):
            check_unicode.code_point("202E")
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "contract.json"
            path.write_text(json.dumps({"forbidden": [{"from": "U+0010", "to": "U+0001", "label": "x"}]}))
            with self.assertRaises(ValueError):
                check_unicode.load_forbidden(path)


class ScanTest(unittest.TestCase):
    def test_reports_line_and_column(self) -> None:
        text = f"first line\nab{char(0x202E)}c\n"
        self.assertEqual(
            check_unicode.problems_in_text("f.ts", text, RANGES),
            ["f.ts:2:3: U+202E (bidi embeddings and overrides)"],
        )

    def test_characters_splitlines_treats_as_breaks_are_still_found(self) -> None:
        for cp in (0x0B, 0x0C, 0x1C, 0x85):
            problems = check_unicode.problems_in_text("f.txt", f"a{char(cp)}b\n", RANGES)
            self.assertEqual(len(problems), 1, hex(cp))
            self.assertTrue(problems[0].startswith("f.txt:1:2:"), problems[0])

    def test_crlf_files_are_clean(self) -> None:
        self.assertEqual(check_unicode.problems_in_text("w.txt", "a\r\nb\r\n", RANGES), [])

    def test_files_binary_and_non_utf8_are_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            bad = Path(folder) / "bad.ts"
            bad.write_text(f"x{char(0x2066)}y", encoding="utf-8")
            image = Path(folder) / "logo.png"
            image.write_bytes(b"\x00\x01")
            latin = Path(folder) / "latin.txt"
            latin.write_bytes(b"caf\xe9")
            self.assertEqual(len(check_unicode.problems_in(bad, RANGES)), 1)
            self.assertEqual(check_unicode.problems_in(image, RANGES), [])
            self.assertEqual(check_unicode.problems_in(latin, RANGES), [])
            self.assertEqual(check_unicode.problems_in(Path(folder) / "missing.ts", RANGES), [])

    def test_main_reports_and_fails(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            bad = Path(folder) / "bad.md"
            bad.write_text(f"{char(0xFEFF)}title\n", encoding="utf-8")
            good = Path(folder) / "good.md"
            good.write_text("fine\n", encoding="utf-8")
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                self.assertEqual(check_unicode.main([str(bad)]), 1)
            self.assertIn("U+FEFF", err.getvalue())
            self.assertEqual(check_unicode.main([str(good)]), 0)

    def test_tracked_files_lists_the_repository(self) -> None:
        files = check_unicode.tracked_files()
        self.assertIn(Path(check_unicode.__file__).resolve(), files)


if __name__ == "__main__":
    unittest.main()
