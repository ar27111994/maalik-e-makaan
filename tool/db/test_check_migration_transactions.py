"""Tests of check_migration_transactions.py (make test-tools)."""

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

from check_migration_transactions import check, main, split_statements

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = sorted((ROOT / "supabase" / "migrations").glob("*.sql"))


class SplitStatementsTest(unittest.TestCase):
    def test_skips_comments_strings_and_dollar_bodies(self):
        sql = (
            "-- lock table a;\n"
            "/* begin; /* nested; */ commit; */\n"
            "select 'x; lock table b' as s, \"a;b\";\n"
            "create function f() returns void language plpgsql as $body$\n"
            "begin\n  lock table c;\nend\n$body$;\n"
            "do $$ begin perform 1; end $$;\n"
            "select E'it\\'s; fine';\n"
            "select $1"
        )
        texts = [s.text for s in split_statements(sql)]
        self.assertEqual(len(texts), 5)
        self.assertTrue(texts[0].startswith("select 'x; lock table b'"))
        self.assertTrue(texts[1].startswith("create function f()"))
        self.assertEqual(texts[4], "select $1")

    def test_reports_the_first_line_of_each_statement(self):
        lines = [s.line for s in split_statements("\n\nselect 1;\n-- c\nselect\n 2;")]
        self.assertEqual(lines, [3, 5])


class CheckTest(unittest.TestCase):
    def test_refuses_lock_table_outside_a_block(self):
        problems = check("set local lock_timeout = '5s';\nlock table public.t in share mode;\n")
        self.assertEqual(len(problems), 1)
        self.assertIn("line 2: LOCK TABLE needs an explicit transaction block", problems[0])

    def test_refuses_savepoints_outside_a_block(self):
        problems = check("savepoint a;\nrelease savepoint a;\nrollback to savepoint a;\n")
        self.assertEqual(
            [p.split(":")[1].strip().split(" needs")[0] for p in problems],
            ["SAVEPOINT", "RELEASE SAVEPOINT", "ROLLBACK TO SAVEPOINT"],
        )

    def test_accepts_them_inside_begin_and_commit(self):
        sql = "begin;\nset local lock_timeout = '5s';\nlock table t;\nsavepoint a;\ncommit;\n"
        self.assertEqual(check(sql), [])

    def test_accepts_set_local_and_locks_inside_functions(self):
        sql = "set local lock_timeout = '5s';\ndo $$ begin lock table t; end $$;\n"
        self.assertEqual(check(sql), [])

    def test_refuses_unbalanced_transactions(self):
        self.assertEqual(
            check("begin;\nselect 1;\n"), ["line 1: the transaction opened here is never committed"]
        )
        self.assertEqual(check("commit;\n"), ["line 1: no transaction is open"])
        self.assertIn("already open", check("begin;\nstart transaction;\ncommit;\n")[0])

    def test_a_lock_after_the_commit_is_refused(self):
        self.assertEqual(len(check("begin;\ncommit;\nlock table t;\n")), 1)

    def test_every_committed_migration_passes(self):
        self.assertTrue(MIGRATIONS)
        for migration in MIGRATIONS:
            with self.subTest(migration=migration.name):
                self.assertEqual(check(migration.read_text(encoding="utf-8")), [])

    def test_the_d1_migration_without_its_transaction_is_refused(self):
        # The file as the hosted project applied it, before begin/commit were added.
        source = (ROOT / "supabase/migrations/20261108200216_identity_checks.sql").read_text(
            encoding="utf-8"
        )
        unwrapped = source.replace("\nbegin;\n", "\n").replace("\ncommit;\n", "\n")
        problems = check(unwrapped)
        self.assertEqual(len(problems), 1)
        self.assertIn("LOCK TABLE", problems[0])


class MainTest(unittest.TestCase):
    def run_main(self, *contents):
        with tempfile.TemporaryDirectory() as tmp:
            paths = []
            for index, content in enumerate(contents):
                path = Path(tmp) / f"{index}.sql"
                path.write_text(content, encoding="utf-8")
                paths.append(str(path))
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = main(paths)
            return code, out.getvalue(), err.getvalue()

    def test_exit_codes_and_messages(self):
        self.assertEqual(
            self.run_main("select 1;")[:2], (0, "migration transactions: 1 files checked\n")
        )
        code, _, err = self.run_main("select 1;", "lock table t;")
        self.assertEqual(code, 1)
        self.assertIn("1.sql: line 1: LOCK TABLE", err)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main([]), 2)


if __name__ == "__main__":
    unittest.main()
