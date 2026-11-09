"""Tests of dump_digest.py (make test-tools)."""

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from dump_digest import TableData, compare, main, parse

DUMP = """--
-- PostgreSQL database dump
--
SET session_replication_role = replica;

COPY "auth"."users" ("id", "email") FROM stdin;
1\ta@example.test
2\tb@example.test
\\.

COPY "public"."portfolios" ("id", "name") FROM stdin;
\\.

COPY "public"."charges" ("id", "description") FROM stdin;
7\tline one\\nline two
8\t\\N
\\.

RESET ALL;
"""


class ParseTest(unittest.TestCase):
    def test_counts_rows_per_section(self):
        tables = parse(DUMP)
        self.assertEqual(
            {name: data.rows for name, data in tables.items()},
            {'"auth"."users"': 2, '"public"."portfolios"': 0, '"public"."charges"': 2},
        )

    def test_digest_ignores_row_order(self):
        reordered = DUMP.replace(
            "1\ta@example.test\n2\tb@example.test", "2\tb@example.test\n1\ta@example.test"
        )
        self.assertEqual(parse(DUMP), parse(reordered))

    def test_digest_sees_a_changed_value(self):
        changed = DUMP.replace("b@example.test", "c@example.test")
        self.assertNotEqual(parse(DUMP)['"auth"."users"'], parse(changed)['"auth"."users"'])

    def test_unquoted_names_and_no_column_list(self):
        tables = parse("COPY public.t FROM stdin;\nx\n\\.\n")
        self.assertEqual(tables["public.t"].rows, 1)

    def test_unterminated_section_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "terminating"):
            parse('COPY "public"."t" ("a") FROM stdin;\n1\n')

    def test_unrecognised_copy_line_is_an_error(self):
        with self.assertRaisesRegex(ValueError, "unrecognised COPY line"):
            parse('COPY "public"."t" ("a") FROM \'/tmp/x\';\n1\n\\.\n')

    def test_duplicate_section_is_an_error(self):
        section = 'COPY "public"."t" ("a") FROM stdin;\n1\n\\.\n'
        with self.assertRaisesRegex(ValueError, "second COPY section"):
            parse(section + section)


class CompareTest(unittest.TestCase):
    def test_equal_dumps_match(self):
        self.assertEqual(compare(parse(DUMP), parse(DUMP)), [])

    def test_missing_rows_are_reported_with_counts(self):
        fewer = DUMP.replace("2\tb@example.test\n", "")
        self.assertEqual(
            compare(parse(DUMP), parse(fewer)), ['"auth"."users": rows differ (2 rows, then 1)']
        )

    def test_same_count_different_rows(self):
        changed = DUMP.replace("8\t\\N", "8\tother")
        self.assertEqual(
            compare(parse(DUMP), parse(changed)), ['"public"."charges": rows differ (2 rows)']
        )

    def test_empty_table_on_one_side_only_matches(self):
        left = {"a": TableData(0, "x")}
        self.assertEqual(compare(left, {}), [])

    def test_table_with_rows_on_one_side_only_is_reported(self):
        right = {"a": TableData(3, "x")}
        self.assertEqual(compare({}, right), ["a: only in the second dump (3 rows)"])


class MainTest(unittest.TestCase):
    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(["dump_digest.py", *args])
        return code, out.getvalue(), err.getvalue()

    def write(self, directory, name, text):
        path = Path(directory) / name
        path.write_text(text, encoding="utf-8")
        return str(path)

    def test_summary_never_prints_row_contents(self):
        with tempfile.TemporaryDirectory() as directory:
            code, out, _ = self.run_main("summary", self.write(directory, "a.sql", DUMP))
        self.assertEqual(code, 0)
        self.assertIn('"auth"."users"\t2\t', out)
        self.assertNotIn("example.test", out)

    def test_compare_exit_codes(self):
        with tempfile.TemporaryDirectory() as directory:
            a = self.write(directory, "a.sql", DUMP)
            b = self.write(directory, "b.sql", DUMP.replace("line one", "line 1"))
            self.assertEqual(
                self.run_main("compare", a, a)[:2], (0, "data match: 3 tables, 4 rows\n")
            )
            self.assertEqual(self.run_main("compare", a, b)[0], 1)
            self.assertEqual(self.run_main("compare", a, str(Path(directory) / "none.sql"))[0], 2)

    def test_usage(self):
        code, _, err = self.run_main("compare", "only-one")
        self.assertEqual(code, 2)
        self.assertIn("Usage", err)


if __name__ == "__main__":
    unittest.main()
