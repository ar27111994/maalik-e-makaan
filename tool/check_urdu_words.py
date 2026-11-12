#!/usr/bin/env python3
"""Keep the Urdu plain: fail when a tracked file uses a word the glossary avoids.

contracts/urdu_glossary.json is the owner's plain-Urdu glossary. Each entry names a word to
avoid, the plain word to write instead ("prefer"), the English it stands for and a note; its
"match" list holds the exact forms this guard looks for. An entry whose "match" is empty depends
on meaning (a word that is right in one sense and wrong in another, such as مکان for a home and
for a shop), so a person judges it in review and the guard does not.

A form matches only as a whole word: the characters on either side must not be letters,
combining marks, digits or the Urdu joiners (U+200C, U+200D), so a form کتاب would not match
کتابیں. Where a longer form and a shorter one overlap, only the longer is reported.

The glossary's "exceptions" let an official name keep a formal word. Each is
{"path", "avoid", "reason"}: "path" is a glob over repository paths (fnmatch, so * also crosses
folders), and "avoid" is either an avoided form, allowed anywhere in those files, or a longer
phrase that contains one, such as a law's official name, and then only occurrences inside that
phrase are allowed. A full scan warns about an exception that allows nothing.

The glossary itself is never scanned.

Usage:
    python3 tool/check_urdu_words.py            # scan every git-tracked file
    python3 tool/check_urdu_words.py FILE...    # scan the given files
"""

from __future__ import annotations

import fnmatch
import json
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path

import check_unicode

ROOT = check_unicode.ROOT
GLOSSARY = ROOT / "contracts" / "urdu_glossary.json"

ENTRY_FIELDS = ("avoid", "prefer", "english", "note")
EXCEPTION_FIELDS = ("path", "avoid", "reason")
JOINERS = {chr(0x200C), chr(0x200D)}


@dataclass(frozen=True)
class Form:
    """One exact form the guard looks for, and the entry it belongs to."""

    text: str
    avoid: str
    prefer: str
    english: str


@dataclass(frozen=True)
class Allowance:
    """An exception: [phrase] may appear in files whose path matches [path]."""

    path: str
    phrase: str
    reason: str


@dataclass(frozen=True)
class Glossary:
    forms: tuple[Form, ...]
    exceptions: tuple[Allowance, ...]


@dataclass(frozen=True)
class Finding:
    line: int
    column: int
    form: Form

    def describe(self, name: str) -> str:
        return (
            f"{name}:{self.line}:{self.column}: {self.form.text} ({self.form.english}); "
            f"write instead: {self.form.prefer}"
        )


def is_word_char(ch: str) -> bool:
    """Letters, combining marks (zer, hamza above) and digits continue a word."""
    return ch in JOINERS or unicodedata.category(ch)[0] in "LMN"


def whole_word_spans(text: str, needle: str) -> list[tuple[int, int]]:
    """Every (start, end) where [needle] stands in [text] as a whole word.

    The edges are checked only where [needle] itself starts or ends with a letter, so a phrase
    in brackets, such as an exception's "(term)", may sit directly beside a word.
    """
    spans = []
    open_start = not is_word_char(needle[0])
    open_end = not is_word_char(needle[-1])
    start = text.find(needle)
    while start != -1:
        end = start + len(needle)
        before_ok = open_start or start == 0 or not is_word_char(text[start - 1])
        after_ok = open_end or end == len(text) or not is_word_char(text[end])
        if before_ok and after_ok:
            spans.append((start, end))
        start = text.find(needle, start + 1)
    return spans


def _text_field(item: dict, field: str, where: str) -> str:
    value = item.get(field)
    if not isinstance(value, str) or value.strip() == "":
        raise ValueError(f"{where}: '{field}' must be a non-empty string")
    return value


def load_glossary(path: Path | None = None) -> Glossary:
    """The glossary's forms and exceptions, checked for shape and consistency."""
    path = path or GLOSSARY
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not isinstance(data.get("entries"), list):
        raise ValueError(f"{path}: 'entries' must be a list")
    forms: list[Form] = []
    seen: dict[str, str] = {}
    for index, entry in enumerate(data["entries"]):
        where = f"{path}: entry {index + 1}"
        if not isinstance(entry, dict):
            raise ValueError(f"{where}: must be an object")
        avoid, prefer, english, _ = (_text_field(entry, f, where) for f in ENTRY_FIELDS)
        match = entry.get("match")
        if not isinstance(match, list):
            raise ValueError(f"{where} ({avoid}): 'match' must be a list, empty for review only")
        for text in match:
            if not isinstance(text, str) or text == "" or text != text.strip():
                raise ValueError(f"{where} ({avoid}): bad form {text!r}")
            if text in seen:
                raise ValueError(f"{where} ({avoid}): {text} is already a form of {seen[text]}")
            seen[text] = avoid
            forms.append(Form(text, avoid, prefer, english))
    exceptions = data.get("exceptions", [])
    if not isinstance(exceptions, list):
        raise ValueError(f"{path}: 'exceptions' must be a list")
    allowances = []
    for index, item in enumerate(exceptions):
        where = f"{path}: exception {index + 1}"
        if not isinstance(item, dict):
            raise ValueError(f"{where}: must be an object")
        allowance = Allowance(*(_text_field(item, f, where) for f in EXCEPTION_FIELDS))
        if not any(whole_word_spans(allowance.phrase, form.text) for form in forms):
            raise ValueError(f"{where}: '{allowance.phrase}' contains no avoided form")
        allowances.append(allowance)
    return Glossary(tuple(forms), tuple(allowances))


def repository_path(path: Path) -> str:
    """[path] relative to the repository, with forward slashes, as exceptions name it."""
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


ARABIC_BLOCK = range(0x0600, 0x0700)


def has_arabic_script(text: str) -> bool:
    """Whether [text] has a letter of the Arabic block, where every Urdu form lives."""
    return any(ord(ch) in ARABIC_BLOCK for ch in text)


def findings_in_text(
    text: str,
    glossary: Glossary,
    rel_path: str,
    used: set[Allowance] | None = None,
) -> list[Finding]:
    """Every avoided form in [text], outside the exceptions that apply to [rel_path]."""
    if not has_arabic_script(text):
        return []
    hits = [
        (start, end, form)
        for form in glossary.forms
        for start, end in whole_word_spans(text, form.text)
    ]
    hits.sort(key=lambda hit: (hit[0], hit[0] - hit[1]))
    kept: list[tuple[int, int, Form]] = []
    reach = -1
    for start, end, form in hits:
        if end <= reach:
            continue  # inside a longer form already reported
        kept.append((start, end, form))
        reach = max(reach, end)

    allowed: list[tuple[int, int, Allowance]] = [
        (start, end, allowance)
        for allowance in glossary.exceptions
        if fnmatch.fnmatchcase(rel_path, allowance.path)
        for start, end in whole_word_spans(text, allowance.phrase)
    ]
    findings = []
    for start, end, form in kept:
        cover = next((a for s, e, a in allowed if s <= start and end <= e), None)
        if cover is not None:
            if used is not None:
                used.add(cover)
            continue
        line = text.count("\n", 0, start) + 1
        column = start - (text.rfind("\n", 0, start) + 1) + 1
        findings.append(Finding(line, column, form))
    return findings


def problems_in(path: Path, glossary: Glossary, used: set[Allowance] | None = None) -> list[str]:
    if path.suffix.lower() in check_unicode.BINARY_SUFFIXES or not path.is_file():
        return []
    if path.resolve() == GLOSSARY.resolve():
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []  # binary or non-UTF-8 files are out of scope
    findings = findings_in_text(text, glossary, repository_path(path), used)
    return [finding.describe(repository_path(path)) for finding in findings]


def main(argv: list[str]) -> int:
    glossary = load_glossary()
    full_scan = not argv
    paths = check_unicode.tracked_files() if full_scan else [Path(a) for a in argv]
    used: set[Allowance] = set()
    problems = [p for path in paths for p in problems_in(path, glossary, used)]
    if full_scan:
        for allowance in glossary.exceptions:
            if allowance not in used:
                print(
                    f"warning: the exception for '{allowance.phrase}' in {allowance.path} "
                    "allows nothing; remove it from contracts/urdu_glossary.json",
                    file=sys.stderr,
                )
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        print(
            f"\n{len(problems)} avoided Urdu word(s) found. Write the plain word the glossary "
            "prefers (contracts/urdu_glossary.json). Where an official name must keep a formal "
            "word, add an exception there with the reason.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
