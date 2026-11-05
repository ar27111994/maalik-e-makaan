#!/usr/bin/env python3
"""Guard against "Trojan Source" and invisible-character attacks.

Fails when a tracked text file contains a character that
contracts/clean_text.json forbids: Unicode bidirectional override / isolate
controls (CVE-2021-42574), zero-width and other invisible characters, or
C0/C1 control characters. Tab, line feed and carriage return are the only
controls a text file may contain. The same contract is enforced by the
database (app.is_clean_text), the Edge Functions and the app's sanitiser.

Urdu text legitimately uses the zero-width (non-)joiner (U+200C/U+200D) and
the LRM/RLM marks (U+200E/U+200F); the contract allows them. Source code that
needs a forbidden character must build it from its code point (for example
String.fromCodePoint(0x202E)), never spell it literally.

The whole text is scanned as is: characters such as vertical tab, form feed
or U+0085 are not treated as line breaks (str.splitlines would, hiding them).

Usage:
    python3 tool/check_unicode.py            # scan every git-tracked file
    python3 tool/check_unicode.py FILE...    # scan the given files
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "contracts" / "clean_text.json"

BINARY_SUFFIXES = {
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".ico",
    ".ttf",
    ".otf",
    ".woff",
    ".woff2",
    ".pdf",
    ".jar",
    ".keystore",
    ".jks",
    ".zip",
    ".gz",
    ".mp4",
    ".webm",
    ".avif",
    ".heic",
    ".svgz",
}


def code_point(text: str) -> int:
    """Parses the contract's "U+XXXX" notation."""
    if not text.startswith("U+"):
        raise ValueError(f"not a code point: {text!r}")
    return int(text[2:], 16)


def load_forbidden(path: Path = CONTRACT) -> list[tuple[int, int, str]]:
    """The contract's forbidden ranges as (low, high, label), sorted."""
    contract = json.loads(path.read_text(encoding="utf-8"))
    ranges = [
        (code_point(r["from"]), code_point(r["to"]), r["label"]) for r in contract["forbidden"]
    ]
    for low, high, label in ranges:
        if low > high:
            raise ValueError(f"empty range in {path}: {label}")
    return sorted(ranges)


def reason_for(cp: int, ranges: list[tuple[int, int, str]]) -> str | None:
    for low, high, label in ranges:
        if low <= cp <= high:
            return label
    return None


def tracked_files() -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "-z"],  # noqa: S607 - git from PATH, as in every git hook
        check=True,
        capture_output=True,
        cwd=ROOT,
    ).stdout.decode("utf-8")
    return [ROOT / p for p in out.split("\0") if p]


def problems_in_text(name: str, text: str, ranges: list[tuple[int, int, str]]) -> list[str]:
    """Every forbidden character of [text] as "name:line:column: U+XXXX (reason)"."""
    found = []
    line_no, col = 1, 0
    for ch in text:
        if ch == "\n":
            line_no, col = line_no + 1, 0
            continue
        col += 1
        reason = reason_for(ord(ch), ranges)
        if reason is not None:
            found.append(f"{name}:{line_no}:{col}: U+{ord(ch):04X} ({reason})")
    return found


def problems_in(path: Path, ranges: list[tuple[int, int, str]]) -> list[str]:
    if path.suffix.lower() in BINARY_SUFFIXES or not path.is_file():
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []  # binary or non-UTF-8 files are out of scope
    return problems_in_text(str(path), text, ranges)


def main(argv: list[str]) -> int:
    ranges = load_forbidden()
    paths = [Path(a) for a in argv] if argv else tracked_files()
    problems = [p for path in paths for p in problems_in(path, ranges)]
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        print(
            f"\n{len(problems)} forbidden character(s) found. Remove them, or build them "
            "from their code point in code.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
