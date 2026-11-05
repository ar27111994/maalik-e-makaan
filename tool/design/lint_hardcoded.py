#!/usr/bin/env python3
"""Design lint for Flutter UI code: values must come from the design tokens.

Flags, in Dart files under the given directories (default: the design system's
and the app's lib/ folders):

- colours written in code: ``Color(0x…)``, ``Color.fromARGB/fromRGBO`` and
  ``Colors.*`` (only ``Colors.transparent`` is neutral);
- font sizes as numbers (``fontSize: 14``): use the text theme;
- spacing and radii as numbers: ``EdgeInsets…(16)``, ``SizedBox(height: 8)``,
  ``BorderRadius.circular(12)``, ``Radius.circular(12)``: use MmSpace/MmRadius;
- durations as numbers (``Duration(milliseconds: 200)``): use MmMotion;
- physical left/right geometry that breaks right-to-left layouts:
  ``EdgeInsets.only(left: …)``/``fromLTRB``, ``Alignment.centerLeft`` and
  friends, ``Positioned(left: …)``: use the Directional variants.

Zero is always allowed. Generated token files and generated localisations are
skipped. A reviewed exception carries ``// design-lint: allow <reason>`` at the
end of the line, or ``// design-lint: allow-next-line <reason>`` on its own line
just above it (where the formatter would move a trailing comment); the reason is
required.

Usage: lint_hardcoded.py [DIR-OR-FILE ...]   Exits 1 when it finds anything.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIRS = ("packages/mm_ui/lib", "app/lib")
SKIP = (re.compile(r"\.g\.dart$"), re.compile(r"/l10n/generated/"))
ALLOW = re.compile(r"//\s*design-lint:\s*allow\s+\S")
ALLOW_NEXT = re.compile(r"^\s*//\s*design-lint:\s*allow-next-line\s+\S")
ALLOW_WITHOUT_REASON = re.compile(r"//\s*design-lint:\s*allow(?:-next-line)?\s*$")

# A non-zero numeric literal (12, 12.5, .5), not part of an identifier.
NUM = r"(?<![\w.])(?:[1-9]\d*(?:\.\d+)?|0?\.\d*[1-9]\d*)(?![\w.])"

RULES: tuple[tuple[str, re.Pattern[str], str], ...] = (
    ("colour", re.compile(r"\bColor\(0x|\bColor\.from(?:ARGB|RGBO)\("), "use a colour role"),
    (
        "colour",
        re.compile(r"\bColors\.(?!transparent\b)[a-z]\w*"),
        "use a colour role (only Colors.transparent is neutral)",
    ),
    ("font-size", re.compile(rf"\bfontSize:\s*{NUM}"), "use the text theme"),
    (
        "spacing",
        re.compile(rf"\bEdgeInsets(?:Directional)?\.\w+\([^)]*{NUM}"),
        "use MmSpace",
    ),
    ("spacing", re.compile(rf"\bSizedBox\(\s*(?:height|width):\s*{NUM}"), "use MmSpace"),
    ("radius", re.compile(rf"\b(?:BorderRadius|Radius)\.circular\(\s*{NUM}"), "use MmRadius"),
    ("motion", re.compile(rf"\bDuration\(\s*milliseconds:\s*{NUM}"), "use MmMotion"),
    (
        "rtl",
        re.compile(r"\bEdgeInsets\.only\([^)]*\b(?:left|right):|\bEdgeInsets\.fromLTRB\("),
        "use EdgeInsetsDirectional (start/end)",
    ),
    (
        "rtl",
        re.compile(
            r"\bAlignment\.(?:centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b"
        ),
        "use AlignmentDirectional (start/end)",
    ),
    ("rtl", re.compile(r"\bPositioned\([^)]*\b(?:left|right):"), "use PositionedDirectional"),
)


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    rule: str
    text: str
    hint: str

    def __str__(self) -> str:
        where = self.path.relative_to(ROOT) if self.path.is_relative_to(ROOT) else self.path
        return f"{where}:{self.line}: [{self.rule}] {self.hint}: {self.text.strip()}"


def _code(line: str) -> str:
    """The line without a trailing // comment (good enough for this lint)."""
    quote: str | None = None
    for i, char in enumerate(line):
        if quote:
            if char == quote and line[i - 1] != "\\":
                quote = None
        elif char in "'\"":
            quote = char
        elif line.startswith("//", i):
            return line[:i]
    return line


def lint_text(path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    allow_next = False
    for number, line in enumerate(text.splitlines(), start=1):
        allowed, allow_next = allow_next, False
        if ALLOW_WITHOUT_REASON.search(line):
            findings.append(Finding(path, number, "allow", line, "an allowance needs a reason"))
            continue
        if ALLOW_NEXT.search(line):
            allow_next = True
            continue
        stripped = line.lstrip()
        if allowed or stripped.startswith(("//", "///", "*", "/*")):
            continue
        if ALLOW.search(line):
            continue
        code = _code(line)
        for rule, pattern, hint in RULES:
            if pattern.search(code):
                findings.append(Finding(path, number, rule, line, hint))
    return findings


def dart_files(paths: list[Path]) -> list[Path]:
    """The Dart files in [paths] (directories are searched), minus generated ones."""
    candidates: list[Path] = []
    for path in paths:
        candidates += sorted(path.rglob("*.dart")) if path.is_dir() else [path]
    return [
        path
        for path in candidates
        if path.suffix == ".dart" and not any(skip.search(path.as_posix()) for skip in SKIP)
    ]


def main(argv: list[str]) -> int:
    directories = [ROOT / d for d in (argv or DEFAULT_DIRS)]
    missing = [d for d in directories if not d.exists()]
    if missing:
        print(f"no such file or directory: {', '.join(map(str, missing))}", file=sys.stderr)
        return 2
    findings = [
        finding
        for path in dart_files(directories)
        for finding in lint_text(path, path.read_text(encoding="utf-8"))
    ]
    for finding in findings:
        print(finding)
    if findings:
        print(f"\n{len(findings)} design-lint finding(s).", file=sys.stderr)
        return 1
    print(f"design-lint: {len(dart_files(directories))} files clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
