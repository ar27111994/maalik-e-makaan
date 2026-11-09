#!/usr/bin/env python3
"""Summarise or compare the data of `supabase db dump --data-only --use-copy` files.

Usage:
    tool/db/dump_digest.py summary data.sql            # one line per table: rows and digest
    tool/db/dump_digest.py compare original.sql again.sql

A data-only dump in COPY format holds one section per table:

    COPY "public"."leases" ("id", ...) FROM stdin;
    <one line per row, tab-separated, newlines escaped>
    \\.

The digest of a table is the SHA-256 of its rows sorted, so it does not depend on the order the
server returned them in. `compare` is how the restore rehearsal (.github/workflows/backup.yml)
proves that a dump restored into a new project and dumped again holds exactly the same rows: it
prints each table whose rows differ, or that only one side has, and exits 0 when every table
matches, 1 when any differs and 2 on usage errors. A table that only one side has, with no rows,
counts as matching (pg_dump writes an empty section for some tables and none for others).

The output names tables and counts rows; it never prints row contents.
"""

from __future__ import annotations

import hashlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

COPY_START = re.compile(r"^COPY (?P<table>\S+(?:\.\S+)?) (?:\(.*\) )?FROM stdin;$")
COPY_END = "\\."


@dataclass(frozen=True)
class TableData:
    rows: int
    digest: str


def parse(text: str) -> dict[str, TableData]:
    """Return each COPY section's row count and order-independent digest."""
    tables: dict[str, list[str]] = {}
    current: list[str] | None = None
    for number, line in enumerate(text.split("\n"), start=1):
        if current is None:
            match = COPY_START.match(line)
            if match:
                name = match.group("table")
                if name in tables:
                    raise ValueError(f"line {number}: second COPY section for {name}")
                current = tables[name] = []
            continue
        if line == COPY_END:
            current = None
        else:
            current.append(line)
    if current is not None:
        raise ValueError("the last COPY section has no terminating \\. line")
    return {
        name: TableData(
            rows=len(rows),
            digest=hashlib.sha256("\n".join(sorted(rows)).encode("utf-8")).hexdigest(),
        )
        for name, rows in tables.items()
    }


def compare(left: dict[str, TableData], right: dict[str, TableData]) -> list[str]:
    """Describe every table whose data differs; an empty list means the dumps match."""
    problems = []
    for name in sorted(left.keys() | right.keys()):
        a, b = left.get(name), right.get(name)
        if a is None or b is None:
            present = a or b
            if present is not None and present.rows == 0:
                continue
            side = "first" if b is None else "second"
            problems.append(f"{name}: only in the {side} dump ({present.rows} rows)")
        elif a != b:
            detail = f"{a.rows} rows, then {b.rows}" if a.rows != b.rows else f"{a.rows} rows"
            problems.append(f"{name}: rows differ ({detail})")
    return problems


def read(path: str) -> dict[str, TableData]:
    return parse(Path(path).read_text(encoding="utf-8"))


def main(argv: list[str]) -> int:
    try:
        if len(argv) == 3 and argv[1] == "summary":
            for name, data in sorted(read(argv[2]).items()):
                print(f"{name}\t{data.rows}\t{data.digest[:16]}")
            return 0
        if len(argv) == 4 and argv[1] == "compare":
            left, right = read(argv[2]), read(argv[3])
            problems = compare(left, right)
            for problem in problems:
                print(problem)
            if problems:
                return 1
            rows = sum(data.rows for data in left.values())
            print(f"data match: {len(left)} tables, {rows} rows")
            return 0
    except (OSError, ValueError) as error:
        print(f"dump_digest: {error}", file=sys.stderr)
        return 2
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
