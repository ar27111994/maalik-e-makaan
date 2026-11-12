"""Tests for the plain-Urdu guard (python3 -m unittest discover -s tool -p 'test_*.py').

The sample words (کتاب، قلم، گھر) are ordinary words the glossary does not avoid, so this file
passes the guard it tests.
"""

from __future__ import annotations

import contextlib
import fnmatch
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import check_unicode
import check_urdu_words

BOOK = "کتاب"
BOOKS = "کتابیں"
BOOKSHOP = "کتاب گھر"
PEN = "قلم"
ZER = chr(0x0650)
ZWNJ = chr(0x200C)
FULL_STOP = chr(0x06D4)  # the Urdu full stop


def entry(avoid: str, match: list[str], **extra: object) -> dict[str, object]:
    return {
        "avoid": avoid,
        "prefer": f"not {avoid}",
        "english": f"english for {avoid}",
        "note": "a note",
        "match": match,
        **extra,
    }


def glossary_file(folder: str, entries: list[dict], exceptions: list[dict] | None = None) -> Path:
    path = Path(folder) / "glossary.json"
    data: dict[str, object] = {"entries": entries}
    if exceptions is not None:
        data["exceptions"] = exceptions
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return path


def sample(exceptions: list[dict] | None = None) -> check_urdu_words.Glossary:
    with tempfile.TemporaryDirectory() as folder:
        path = glossary_file(
            folder,
            [entry(BOOK, [BOOK, BOOKSHOP]), entry(PEN, [PEN]), entry("review only", [])],
            exceptions,
        )
        return check_urdu_words.load_glossary(path)


def found(text: str, glossary: check_urdu_words.Glossary, rel: str = "a.md") -> list[str]:
    return [f.form.text for f in check_urdu_words.findings_in_text(text, glossary, rel)]


class RepositoryGlossaryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.data = json.loads(check_urdu_words.GLOSSARY.read_text(encoding="utf-8"))

    def test_the_repository_glossary_loads(self) -> None:
        glossary = check_urdu_words.load_glossary()
        self.assertGreater(len(glossary.forms), 300)
        self.assertGreater(len(glossary.exceptions), 0)

    def test_every_entry_says_what_to_avoid_and_what_to_write(self) -> None:
        for item in self.data["entries"]:
            for field in ("avoid", "prefer", "english", "note"):
                self.assertTrue(item[field].strip(), f"{item['avoid']}: {field}")
            self.assertIsInstance(item["match"], list, item["avoid"])

    def test_the_style_sheet_is_kept_beside_the_entries(self) -> None:
        self.assertGreater(len(self.data["sentenceRules"]), 0)
        self.assertGreater(len(self.data["keep"]), 0)

    def test_every_exception_names_files_that_exist(self) -> None:
        tracked = [
            p.relative_to(check_urdu_words.ROOT).as_posix() for p in check_unicode.tracked_files()
        ]
        for item in self.data["exceptions"]:
            self.assertTrue(item["reason"].strip(), item)
            self.assertTrue(
                any(fnmatch.fnmatchcase(rel, item["path"]) for rel in tracked),
                f"no tracked file matches {item['path']}",
            )

    def test_the_glossary_is_never_scanned(self) -> None:
        glossary = check_urdu_words.load_glossary()
        self.assertEqual(check_urdu_words.problems_in(check_urdu_words.GLOSSARY, glossary), [])


class LoadTest(unittest.TestCase):
    def assert_refused(self, entries: list[dict], exceptions: list[dict] | None = None) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = glossary_file(folder, entries, exceptions)
            with self.assertRaises(ValueError):
                check_urdu_words.load_glossary(path)

    def test_refuses_an_entry_without_its_fields(self) -> None:
        for field in ("avoid", "prefer", "english", "note"):
            broken = entry(BOOK, [BOOK])
            broken[field] = " "
            self.assert_refused([broken])
        self.assert_refused(["not an object"])  # type: ignore[list-item]

    def test_refuses_a_missing_or_malformed_match(self) -> None:
        missing = entry(BOOK, [BOOK])
        del missing["match"]
        self.assert_refused([missing])
        self.assert_refused([entry(BOOK, [""])])
        self.assert_refused([entry(BOOK, [f" {BOOK}"])])
        self.assert_refused([entry(BOOK, [7])])  # type: ignore[list-item]

    def test_refuses_a_form_listed_twice(self) -> None:
        self.assert_refused([entry(BOOK, [BOOK]), entry("again", [BOOK])])

    def test_refuses_an_exception_that_allows_no_avoided_form(self) -> None:
        self.assert_refused([entry(BOOK, [BOOK])], [{"path": "*", "avoid": PEN, "reason": "x"}])
        self.assert_refused([entry(BOOK, [BOOK])], [{"path": "*", "avoid": BOOKS, "reason": "x"}])
        self.assert_refused([entry(BOOK, [BOOK])], [{"path": "*", "avoid": BOOK, "reason": ""}])
        self.assert_refused([entry(BOOK, [BOOK])], ["not an object"])  # type: ignore[list-item]

    def test_refuses_a_file_without_entries_or_with_bad_exceptions(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "glossary.json"
            for data in ({"entries": {}}, [], {"entries": [], "exceptions": {}}):
                path.write_text(json.dumps(data), encoding="utf-8")
                with self.assertRaises(ValueError):
                    check_urdu_words.load_glossary(path)


class MatchTest(unittest.TestCase):
    def test_a_form_matches_only_as_a_whole_word(self) -> None:
        glossary = sample()
        self.assertEqual(found(f"یہ {BOOK} ہے", glossary), [BOOK])
        self.assertEqual(found(f"{BOOK}{FULL_STOP}", glossary), [BOOK])
        self.assertEqual(found(f"({BOOK})", glossary), [BOOK])
        self.assertEqual(found(f"یہ {BOOKS} ہیں", glossary), [])
        self.assertEqual(found(f"نئی{BOOK}", glossary), [])

    def test_marks_and_joiners_continue_a_word(self) -> None:
        glossary = sample()
        self.assertEqual(found(f"{BOOK}{ZER} نو", glossary), [])
        self.assertEqual(found(f"{BOOK}{ZWNJ}یں", glossary), [])
        self.assertEqual(found(f"{BOOK}1", glossary), [])

    def test_the_longer_of_two_overlapping_forms_is_reported_once(self) -> None:
        glossary = sample()
        self.assertEqual(found(f"ایک {BOOKSHOP} اور ایک {BOOK}", glossary), [BOOKSHOP, BOOK])

    def test_review_only_entries_and_text_without_urdu_find_nothing(self) -> None:
        glossary = sample()
        self.assertEqual(found("review only, in English", glossary), [])
        self.assertEqual(found("", glossary), [])

    def test_reports_line_and_column(self) -> None:
        findings = check_urdu_words.findings_in_text(f"first\nab {PEN}\n", sample(), "a.md")
        self.assertEqual([(f.line, f.column) for f in findings], [(2, 4)])
        self.assertEqual(
            findings[0].describe("a.md"),
            f"a.md:2:4: {PEN} (english for {PEN}); write instead: not {PEN}",
        )


class ExceptionTest(unittest.TestCase):
    def test_a_form_is_allowed_only_where_the_path_matches(self) -> None:
        glossary = sample([{"path": "docs/*", "avoid": PEN, "reason": "a quotation"}])
        self.assertEqual(found(PEN, glossary, "docs/notes/a.md"), [])
        self.assertEqual(found(PEN, glossary, "website/a.md"), [PEN])

    def test_a_phrase_allows_the_form_only_inside_it(self) -> None:
        name = f"{PEN} گھر"
        glossary = sample([{"path": "*", "avoid": name, "reason": "an official name"}])
        self.assertEqual(found(f"{name} اور {PEN}", glossary), [PEN])

    def test_a_bracketed_phrase_may_touch_the_words_beside_it(self) -> None:
        glossary = sample([{"path": "*", "avoid": f"({PEN})", "reason": "a term of art"}])
        self.assertEqual(found(f"لکھنے کی چیز({PEN})اور", glossary), [])
        self.assertEqual(found(f"لکھنے کی چیز {PEN}", glossary), [PEN])

    def test_used_exceptions_are_recorded(self) -> None:
        glossary = sample([{"path": "*", "avoid": PEN, "reason": "x"}])
        used: set[check_urdu_words.Allowance] = set()
        check_urdu_words.findings_in_text(BOOK, glossary, "a.md", used)
        self.assertEqual(used, set())
        check_urdu_words.findings_in_text(PEN, glossary, "a.md", used)
        self.assertEqual(used, set(glossary.exceptions))


class FileTest(unittest.TestCase):
    def test_files_binary_non_utf8_and_missing_are_skipped(self) -> None:
        glossary = sample()
        with tempfile.TemporaryDirectory() as folder:
            text = Path(folder) / "page.md"
            text.write_text(f"# {PEN}\n", encoding="utf-8")
            image = Path(folder) / "shot.png"
            image.write_bytes(PEN.encode("utf-8"))
            latin = Path(folder) / "latin.txt"
            latin.write_bytes(b"caf\xe9")
            self.assertEqual(len(check_urdu_words.problems_in(text, glossary)), 1)
            self.assertEqual(check_urdu_words.problems_in(image, glossary), [])
            self.assertEqual(check_urdu_words.problems_in(latin, glossary), [])
            self.assertEqual(check_urdu_words.problems_in(Path(folder) / "gone.md", glossary), [])

    def test_paths_are_reported_relative_to_the_repository(self) -> None:
        here = Path(check_urdu_words.__file__)
        self.assertEqual(check_urdu_words.repository_path(here), "tool/check_urdu_words.py")
        self.assertEqual(
            check_urdu_words.repository_path(Path("/elsewhere/a.md")), "/elsewhere/a.md"
        )


class MainTest(unittest.TestCase):
    def run_main(self, argv: list[str], glossary: Path, tracked: list[Path]) -> tuple[int, str]:
        err = io.StringIO()
        with (
            mock.patch.object(check_urdu_words, "GLOSSARY", glossary),
            mock.patch.object(check_unicode, "tracked_files", return_value=tracked),
            contextlib.redirect_stderr(err),
        ):
            code = check_urdu_words.main(argv)
        return code, err.getvalue()

    def test_main_reports_and_fails_or_passes(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            glossary = glossary_file(folder, [entry(PEN, [PEN])])
            bad = Path(folder) / "bad.md"
            bad.write_text(f"{PEN}\n", encoding="utf-8")
            good = Path(folder) / "good.md"
            good.write_text(f"{BOOK}\n", encoding="utf-8")
            code, err = self.run_main([str(bad)], glossary, [])
            self.assertEqual(code, 1)
            self.assertIn(f"bad.md:1:1: {PEN}", err)
            self.assertIn("1 avoided Urdu word(s) found", err)
            self.assertEqual(self.run_main([str(good)], glossary, []), (0, ""))

    def test_a_full_scan_warns_about_an_exception_that_allows_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            glossary = glossary_file(
                folder,
                [entry(PEN, [PEN])],
                [{"path": "*", "avoid": PEN, "reason": "no longer needed"}],
            )
            good = Path(folder) / "good.md"
            good.write_text(f"{BOOK}\n", encoding="utf-8")
            code, err = self.run_main([], glossary, [good, glossary])
            self.assertEqual(code, 0)
            self.assertIn(f"warning: the exception for '{PEN}' in * allows nothing", err)
            # A scan of named files does not judge the exceptions.
            self.assertEqual(self.run_main([str(good)], glossary, []), (0, ""))


if __name__ == "__main__":
    unittest.main()
