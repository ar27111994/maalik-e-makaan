#!/usr/bin/env python3
"""Guard against "Trojan Source" and invisible-character attacks.

Fails when a tracked text file contains Unicode bidirectional override /
isolate controls (CVE-2021-42574), zero-width or other invisible characters
that are not legitimately needed, or stray C0/C1 control characters.

Urdu text legitimately uses the zero-width (non-)joiner (U+200C/U+200D) and
the LRM/RLM marks (U+200E/U+200F); those are allowed everywhere. Source code
that needs a forbidden character must spell it as an escape sequence
(e.g. '\\u202E' in Dart/TypeScript), which is also far more readable.

Usage:
    python3 tool/check_unicode.py            # scan every git-tracked file
    python3 tool/check_unicode.py FILE...    # scan the given files
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

FORBIDDEN = {
    **{cp: "bidi embedding/override" for cp in range(0x202A, 0x202F)},
    **{cp: "bidi isolate" for cp in range(0x2066, 0x206A)},
    0x061C: "Arabic letter mark",
    0x200B: "zero-width space",
    0x2060: "word joiner",
    0xFEFF: "byte-order mark / zero-width no-break space",
    0x00AD: "soft hyphen",
    0x180E: "Mongolian vowel separator",
}

BINARY_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".ico", ".ttf", ".otf",
    ".woff", ".woff2", ".pdf", ".jar", ".keystore", ".jks", ".zip",
    ".gz", ".mp4", ".webm", ".avif", ".heic", ".svgz",
}


def tracked_files() -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", "-z"], check=True, capture_output=True
    ).stdout.decode("utf-8")
    return [Path(p) for p in out.split("\0") if p]


def problems_in(path: Path) -> list[str]:
    if path.suffix.lower() in BINARY_SUFFIXES or not path.is_file():
        return []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []  # binary or non-UTF-8 files are out of scope
    found = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for col, ch in enumerate(line, start=1):
            cp = ord(ch)
            reason = FORBIDDEN.get(cp)
            if reason is None and (
                (cp < 0x20 and ch not in "\t\r\n") or 0x7F <= cp <= 0x9F
            ):
                reason = "control character"
            if reason:
                found.append(f"{path}:{line_no}:{col}: U+{cp:04X} ({reason})")
    return found


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] if argv else tracked_files()
    problems = [p for path in paths for p in problems_in(path)]
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        print(
            f"\n{len(problems)} forbidden character(s) found. Replace them with "
            "escape sequences or remove them.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
