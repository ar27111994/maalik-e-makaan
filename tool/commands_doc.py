"""Reads docs/agents/commands.md and the Makefile for the checks that keep the two in step
(tool/test_commands_doc.py, tool/contracts/test_contracts_row.py)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def recipe(target: str) -> list[str]:
    """The recipe lines of a Makefile target."""
    lines = (ROOT / "Makefile").read_text(encoding="utf-8").splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith(f"{target}:"))
    body = []
    for line in lines[start + 1 :]:
        if not line.startswith("\t"):
            break
        body.append(line.strip())
    return body


def commands_row(cell: str) -> str:
    """The row of docs/agents/commands.md whose cells include `cell` exactly."""
    text = (ROOT / "docs" / "agents" / "commands.md").read_text(encoding="utf-8")
    rows = [
        line
        for line in text.splitlines()
        if line.startswith("|") and cell in [c.strip() for c in line.strip("|").split("|")]
    ]
    if len(rows) != 1:
        raise AssertionError(f"expected one row with {cell} in docs/agents/commands.md, got {rows}")
    return rows[0]


def code_spans(text: str) -> list[str]:
    """Each `code span`, with tool/{a,b} expanded to tool/a and tool/b."""
    spans = []
    for span in re.findall(r"`([^`]+)`", text):
        brace = re.fullmatch(r"(.*)\{([^}]*)\}(.*)", span)
        if brace:
            spans += [f"{brace[1]}{item}{brace[3]}" for item in brace[2].split(",")]
        else:
            spans.append(span)
    return spans
