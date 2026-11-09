"""Tests for the LCOV coverage gate (python3 -m unittest discover -s tool -p 'test_*.py')."""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check

FULL = """\
SF:/src/a.ts
FN:1,alpha
FNDA:3,alpha
DA:1,3
DA:2,1
BRDA:2,0,0,1
BRDA:2,0,1,2
end_of_record
"""

PARTIAL = """\
SF:/src/b.ts
FN:1,beta
FN:5,gamma
FNDA:1,beta
FNDA:0,gamma
DA:1,1
DA:2,0
DA:5,0
BRDA:1,0,0,1
BRDA:1,0,1,-
end_of_record
"""


def gate(*argv: str, text: str = FULL) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = check.run(["report.lcov", *argv], read=lambda _path: text)
    return code, out.getvalue(), err.getvalue()


class ParseTest(unittest.TestCase):
    def test_counts_lines_branches_and_functions(self) -> None:
        totals = check.metrics(check.parse_lcov(FULL + PARTIAL))
        self.assertEqual((totals["lines"].hit, totals["lines"].found), (3, 5))
        self.assertEqual((totals["branches"].hit, totals["branches"].found), (3, 4))
        self.assertEqual((totals["functions"].hit, totals["functions"].found), (2, 3))

    def test_merges_repeated_records_for_one_file(self) -> None:
        text = "SF:/x\nDA:1,0\nend_of_record\nSF:/x\nDA:1,2\nend_of_record\n"
        files = check.parse_lcov(text)
        self.assertEqual(len(files), 1)
        self.assertEqual(files[0].lines, {1: 2})

    def test_never_evaluated_branches_count_as_missed(self) -> None:
        files = check.parse_lcov(PARTIAL)
        self.assertEqual(files[0].branches[(1, "0", "1")], 0)

    def test_rejects_malformed_records(self) -> None:
        with self.assertRaises(ValueError):
            check.parse_lcov("SF:/x\nDA:not-a-number\nend_of_record\n")

    def test_metric_of_nothing_is_full(self) -> None:
        self.assertEqual(check.Metric("Line", 0, 0).percent, 100.0)


class GateTest(unittest.TestCase):
    def test_passes_when_every_metric_meets_its_minimum(self) -> None:
        code, out, _ = gate("--min", "100", "--min-branches", "100", "--min-functions", "100")
        self.assertEqual(code, 0)
        self.assertIn("Line coverage: 2/2 = 100.00%", out)
        self.assertIn("Branch coverage: 2/2", out)
        self.assertIn("Function coverage: 1/1", out)

    def test_fails_on_lines_and_lists_the_gaps(self) -> None:
        code, out, err = gate("--min", "100", text=PARTIAL)
        self.assertEqual(code, 1)
        self.assertIn("/src/b.ts: lines 2,5; branches at 1; functions gamma", out)
        self.assertIn("FAILED", err)

    def test_branch_and_function_gates_are_independent(self) -> None:
        text = PARTIAL.replace("DA:2,0", "DA:2,1").replace("DA:5,0", "DA:5,1")
        self.assertEqual(gate("--min", "100", text=text)[0], 0)
        self.assertEqual(gate("--min", "100", "--min-branches", "100", text=text)[0], 1)
        self.assertEqual(gate("--min", "100", "--min-functions", "100", text=text)[0], 1)
        self.assertEqual(
            gate("--min", "50", "--min-branches", "50", "--min-functions", "50", text=text)[0], 0
        )

    def test_requested_metrics_must_be_present(self) -> None:
        code, out, _ = gate(
            "--min", "100", "--min-branches", "100", text="SF:/x\nDA:1,1\nend_of_record\n"
        )
        self.assertEqual(code, 1)
        self.assertIn("no branches data", out)

    def test_excludes_generated_and_requested_paths(self) -> None:
        text = FULL + PARTIAL.replace("/src/b.ts", "/src/b.g.dart")
        self.assertEqual(gate("--min", "100", text=text)[0], 0)
        self.assertEqual(gate("--min", "100", "--exclude", "*/b.ts", text=FULL + PARTIAL)[0], 0)

    def test_empty_reports_and_parse_errors_are_usage_errors(self) -> None:
        self.assertEqual(gate("--min", "100", text="")[0], 2)
        self.assertEqual(gate("--min", "100", text="SF:/x\nDA:x\n")[0], 2)

    def test_reads_the_report_from_disk(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".lcov", delete=False) as handle:
            handle.write(FULL)
        try:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(check.run([handle.name, "--min", "100"]), 0)
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                self.assertEqual(check.run([handle.name + ".missing", "--min", "100"]), 2)
        finally:
            Path(handle.name).unlink()

    def test_main_uses_the_process_arguments(self) -> None:
        saved = sys.argv
        sys.argv = ["check.py", "/definitely/missing.lcov", "--min", "100"]
        try:
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(check.main(), 2)
        finally:
            sys.argv = saved


if __name__ == "__main__":
    unittest.main()
