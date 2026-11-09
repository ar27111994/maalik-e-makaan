#!/usr/bin/env python3
"""Rejects migration statements that the Supabase CLI cannot apply.

The Supabase CLI (``supabase start``, ``db reset``, ``db push``) sends the
statements of a migration file as one pipelined batch: one implicit
transaction, atomic, but not a transaction *block*. PostgreSQL refuses some
statements outside a block, so a file the local harness applies with
``psql --single-transaction`` (an explicit block) can still stop the CLI:

- ``LOCK TABLE`` fails with "can only be used in transaction blocks"
  (SQLSTATE 25P01). This stopped ``supabase start`` at
  20261108200216_identity_checks.sql (docs/uat.md, D1).
- ``SAVEPOINT``, ``RELEASE`` and ``ROLLBACK TO`` fail the same way.

Such a statement must therefore sit between an explicit top-level ``begin;``
and ``commit;``. ``SET LOCAL`` is not refused: inside the CLI's implicit
transaction it holds until the batch ends (checked with CLI 2.122.1 against
PostgreSQL 17.11: a later statement reads the new lock_timeout).

A file that opens a transaction must also close it, and must not open a
second one inside the first.

    tool/db/check_migration_transactions.py FILE...
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Statements PostgreSQL accepts only inside a transaction block
# (RequireTransactionBlock in src/backend/access/transam/xact.c).
_NEEDS_BLOCK = (
    (re.compile(r"lock(\s+table)?\b"), "LOCK TABLE"),
    (re.compile(r"savepoint\b"), "SAVEPOINT"),
    (re.compile(r"release(\s+savepoint)?\b"), "RELEASE SAVEPOINT"),
    (
        re.compile(r"rollback(\s+(work|transaction))?\s+to\b"),
        "ROLLBACK TO SAVEPOINT",
    ),
)
_BEGIN = re.compile(r"(begin|start\s+transaction)(\s+(work|transaction|isolation|read))?\b")
_END = re.compile(r"(commit|end|rollback|abort)(\s+(work|transaction))?$")
_DOLLAR_TAG = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)?\$")


@dataclass(frozen=True)
class Statement:
    """A top-level statement: its text without comments, and its first line."""

    text: str
    line: int


def split_statements(sql: str) -> list[Statement]:
    """Splits SQL into top-level statements, skipping comments, string
    literals, quoted identifiers and dollar-quoted bodies."""
    statements: list[Statement] = []
    current: list[str] = []
    start_line: int | None = None
    line = 1
    i = 0
    n = len(sql)

    def keep(chunk: str) -> None:
        nonlocal start_line
        if start_line is None and chunk.strip():
            start_line = line
        current.append(chunk)

    while i < n:
        ch = sql[i]
        if sql.startswith("--", i):
            end = sql.find("\n", i)
            i = n if end == -1 else end
            continue
        if sql.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if sql.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif sql.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            line += sql.count("\n", i, j)
            current.append(" ")
            i = j
            continue
        if ch in "'\"":
            escapes = ch == "'" and i > 0 and sql[i - 1] in "eE"
            j = i + 1
            while j < n:
                if escapes and sql[j] == "\\":
                    j += 2
                    continue
                if sql[j] == ch:
                    if j + 1 < n and sql[j + 1] == ch:
                        j += 2
                        continue
                    break
                j += 1
            keep(sql[i : j + 1])
            line += sql.count("\n", i, j + 1)
            i = j + 1
            continue
        if ch == "$":
            tag = _DOLLAR_TAG.match(sql, i)
            if tag and not (i > 0 and (sql[i - 1].isalnum() or sql[i - 1] == "_")):
                close = sql.find(tag.group(0), tag.end())
                j = n if close == -1 else close + len(tag.group(0))
                keep(sql[i:j])
                line += sql.count("\n", i, j)
                i = j
                continue
        if ch == ";":
            text = " ".join("".join(current).split())
            if text:
                statements.append(Statement(text, start_line or line))
            current, start_line = [], None
            i += 1
            continue
        if ch == "\n":
            line += 1
        keep(ch)
        i += 1

    text = " ".join("".join(current).split())
    if text:
        statements.append(Statement(text, start_line or line))
    return statements


def check(sql: str) -> list[str]:
    """Returns the problems of one migration, as "line N: message"."""
    problems: list[str] = []
    open_at: int | None = None
    for statement in split_statements(sql):
        lowered = statement.text.lower()
        if _BEGIN.match(lowered):
            if open_at is not None:
                problems.append(
                    f"line {statement.line}: a transaction is already open " f"(line {open_at})"
                )
            open_at = statement.line
            continue
        if _END.match(lowered):
            if open_at is None:
                problems.append(f"line {statement.line}: no transaction is open")
            open_at = None
            continue
        if open_at is None:
            for pattern, name in _NEEDS_BLOCK:
                if pattern.match(lowered):
                    problems.append(
                        f"line {statement.line}: {name} needs an explicit "
                        "transaction block (begin; ... commit;): the Supabase "
                        "CLI applies a migration outside one (SQLSTATE 25P01)"
                    )
                    break
    if open_at is not None:
        problems.append(f"line {open_at}: the transaction opened here is never committed")
    return problems


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    failed = False
    for name in argv:
        for problem in check(Path(name).read_text(encoding="utf-8")):
            print(f"{name}: {problem}", file=sys.stderr)
            failed = True
    if not failed:
        print(f"migration transactions: {len(argv)} files checked")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
