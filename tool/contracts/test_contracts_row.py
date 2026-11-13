"""docs/agents/commands.md names every file `make contracts` writes.

    python3 -m unittest discover -s tool/contracts -p 'test_*.py'

generate.outputs() is the source: the row must name each output that is not a pgTAP suite by
its path, list the generated suites by number, and name nothing else.
"""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

import generate

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from commands_doc import code_spans, commands_row

SUITE = re.compile(r"supabase/tests/database/(\d+)_[^/]+\.test\.sql")


class ContractsRowTest(unittest.TestCase):
    def test_the_row_names_exactly_the_generator_outputs(self) -> None:
        row = commands_row("`make contracts`")
        outputs = [path.relative_to(generate.ROOT).as_posix() for path in generate.outputs()]
        suites = {int(m[1]) for m in map(SUITE.fullmatch, outputs) if m}
        files = {path for path in outputs if not SUITE.fullmatch(path)}
        self.assertTrue(suites and files)

        cell = row.strip("|").split("|")[1]
        named_files = {span for span in code_spans(cell) if "/" in span} - {
            "tool/contracts/generate.py"
        }
        self.assertEqual(named_files, files)
        listed = re.search(r"pgTAP suites ([\d, and]+)", cell)
        self.assertIsNotNone(listed, cell)
        self.assertEqual({int(n) for n in re.findall(r"\d+", listed[1])}, suites)


if __name__ == "__main__":
    unittest.main()
