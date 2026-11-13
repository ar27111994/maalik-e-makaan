"""docs/agents/commands.md names what `make test-tools` runs.

    python3 -m unittest discover -s tool -p 'test_*.py'

The Makefile is the source: every folder its test-tools recipe discovers tests in must be in
the Tooling row, and the row must name no other. (tool/contracts/test_contracts_row.py does the
same for `make contracts` and the generator's outputs.)
"""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from commands_doc import code_spans, commands_row, recipe


class TestToolsRowTest(unittest.TestCase):
    def test_the_row_names_exactly_the_folders_the_recipe_discovers(self) -> None:
        folders = set()
        for line in recipe("test-tools"):
            match = re.search(r"unittest discover -s (\S+)", line)
            if match:
                folders.add(match[1].rstrip("/"))
        self.assertIn("tool/contracts", folders)
        named = {
            span.rstrip("/")
            for span in code_spans(commands_row("`make test-tools`"))
            if span.startswith("tool")
        }
        self.assertEqual(named, folders)

    def test_code_spans_expand_braces(self) -> None:
        self.assertEqual(
            code_spans("in `tool/` and `tool/{db,web}` with `make x`"),
            ["tool/", "tool/db", "tool/web", "make x"],
        )


if __name__ == "__main__":
    unittest.main()
