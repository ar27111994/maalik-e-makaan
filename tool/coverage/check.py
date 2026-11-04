#!/usr/bin/env python3
"""Coverage gate for LCOV reports.

    python3 tool/coverage/check.py LCOV_FILE --min 100
        [--min-branches 100] [--min-functions 100] [--exclude GLOB ...]

Line coverage is always gated. Branch (BRDA) and function (FN/FNDA) coverage
are gated when the matching --min-* option is given; the report must then
contain that kind of data, so a tool change that silently stops emitting it
fails the gate instead of passing vacuously.

Prints the files below 100% with what they miss, then one summary line per
gated metric, and exits 1 when any metric is below its minimum (2 on usage or
parse errors). Generated code (*.g.dart, *.freezed.dart, localisation output)
is excluded by default because it is not hand-written.
"""

from __future__ import annotations

import argparse
import fnmatch
import sys
from collections.abc import Callable
from dataclasses import dataclass, field

DEFAULT_EXCLUDES = [
    "*.g.dart",
    "*.freezed.dart",
    "*/l10n/generated/*",
    "*/generated_plugin_registrant.dart",
]


@dataclass
class FileCoverage:
    path: str
    lines: dict[int, int] = field(default_factory=dict)
    # (line, block, branch) -> times taken; 0 also covers LCOV's "-" (never evaluated).
    branches: dict[tuple[int, str, str], int] = field(default_factory=dict)
    # function name -> hit count
    functions: dict[str, int] = field(default_factory=dict)


@dataclass(frozen=True)
class Metric:
    name: str
    hit: int
    found: int

    @property
    def percent(self) -> float:
        return 100.0 if self.found == 0 else self.hit * 100.0 / self.found


def _merge(target: dict, key, value: int) -> None:
    target[key] = max(target.get(key, 0), value)


def parse_lcov(text: str) -> list[FileCoverage]:
    """Parses an LCOV tracefile. Records for the same file are merged."""
    by_path: dict[str, FileCoverage] = {}
    current: FileCoverage | None = None
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        try:
            if line.startswith("SF:"):
                path = line[3:]
                current = by_path.setdefault(path, FileCoverage(path))
            elif current is None:
                continue
            elif line.startswith("DA:"):
                line_no, hits = line[3:].split(",")[:2]
                _merge(current.lines, int(line_no), int(hits))
            elif line.startswith("BRDA:"):
                line_no, block, branch, taken = line[5:].split(",", 3)
                _merge(current.branches, (int(line_no), block, branch), 0 if taken == "-" else int(taken))
            elif line.startswith("FN:"):
                _, name = line[3:].split(",", 1)
                current.functions.setdefault(name, 0)
            elif line.startswith("FNDA:"):
                hits, name = line[5:].split(",", 1)
                _merge(current.functions, name, int(hits))
            elif line == "end_of_record":
                current = None
        except ValueError as error:
            raise ValueError(f"line {number}: malformed record {line!r}") from error
    return list(by_path.values())


def metrics(files: list[FileCoverage]) -> dict[str, Metric]:
    return {
        "lines": Metric(
            "Line",
            sum(1 for f in files for hits in f.lines.values() if hits > 0),
            sum(len(f.lines) for f in files),
        ),
        "branches": Metric(
            "Branch",
            sum(1 for f in files for taken in f.branches.values() if taken > 0),
            sum(len(f.branches) for f in files),
        ),
        "functions": Metric(
            "Function",
            sum(1 for f in files for hits in f.functions.values() if hits > 0),
            sum(len(f.functions) for f in files),
        ),
    }


def describe_gaps(f: FileCoverage) -> str | None:
    missed_lines = sorted(n for n, hits in f.lines.items() if hits == 0)
    missed_branches = sorted({n for (n, _, _), taken in f.branches.items() if taken == 0})
    missed_functions = sorted(name for name, hits in f.functions.items() if hits == 0)
    if not (missed_lines or missed_branches or missed_functions):
        return None
    parts = []
    if missed_lines:
        shown = ",".join(map(str, missed_lines[:20])) + ("…" if len(missed_lines) > 20 else "")
        parts.append(f"lines {shown}")
    if missed_branches:
        parts.append("branches at " + ",".join(map(str, missed_branches[:20])))
    if missed_functions:
        parts.append("functions " + ", ".join(missed_functions[:10]))
    return f"  {f.path}: " + "; ".join(parts)


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def run(argv: list[str], read: Callable[[str], str] = _read) -> int:
    parser = argparse.ArgumentParser(description="LCOV coverage gate")
    parser.add_argument("lcov")
    parser.add_argument("--min", type=float, required=True, help="minimum line coverage (percent)")
    parser.add_argument("--min-branches", type=float, help="minimum branch coverage (percent)")
    parser.add_argument("--min-functions", type=float, help="minimum function coverage (percent)")
    parser.add_argument("--exclude", action="append", default=[], help="glob of paths to ignore")
    args = parser.parse_args(argv)

    try:
        parsed = parse_lcov(read(args.lcov))
    except OSError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    except ValueError as error:
        print(f"error: {args.lcov}: {error}", file=sys.stderr)
        return 2

    patterns = DEFAULT_EXCLUDES + args.exclude
    files = [f for f in parsed if not any(fnmatch.fnmatch(f.path, p) for p in patterns)]
    if not files:
        print(f"error: {args.lcov} contains no coverage records", file=sys.stderr)
        return 2

    for f in sorted(files, key=lambda f: f.path):
        gaps = describe_gaps(f)
        if gaps:
            print(gaps)

    totals = metrics(files)
    gates = [("lines", args.min), ("branches", args.min_branches), ("functions", args.min_functions)]
    failed = False
    for key, minimum in gates:
        if minimum is None:
            continue
        metric = totals[key]
        if metric.found == 0 and key != "lines":
            print(f"{metric.name} coverage: no {key} data in the report (minimum {minimum}%)")
            failed = True
            continue
        print(f"{metric.name} coverage: {metric.hit}/{metric.found} = {metric.percent:.2f}% (minimum {minimum}%)")
        if metric.percent + 1e-9 < minimum:
            failed = True
    if failed:
        print("Coverage gate FAILED", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    return run(sys.argv[1:])


if __name__ == "__main__":
    sys.exit(main())
