"""Tests of the amount lexicon and vector checks, and the Dart tables built from the lexicon.

    python3 -m unittest discover -s tool/contracts -p 'test_*.py'

The committed files must pass, and a copy broken in each way the checks name must fail.
"""

from __future__ import annotations

import copy
import unittest

import amounts


def lexicon() -> dict:
    return copy.deepcopy(LEXICON)


def vectors() -> dict:
    return copy.deepcopy(VECTORS)


LEXICON = amounts.load(amounts.LEXICON)
VECTORS = amounts.load(amounts.VECTORS)


def entry(lex: dict, section: str, **match) -> dict:
    return next(e for e in lex[section] if all(e[k] == v for k, v in match.items()))


class LexiconTest(unittest.TestCase):
    def broken(self, change, message: str) -> None:
        lex = lexicon()
        change(lex)
        with self.assertRaisesRegex(amounts.ContractError, message):
            amounts.check_lexicon(lex)

    def test_the_committed_lexicon_passes_and_is_unreviewed(self) -> None:
        found = amounts.check_lexicon(lexicon())
        self.assertEqual(found["lakh"], ("multiplier", 5, True))
        self.assertEqual(found["ڈیڑھ"][0], "fraction")
        self.assertEqual(found["twenty-one"], ("number", 21, True))
        self.assertFalse(LEXICON["reviewed"])
        self.assertTrue(LEXICON["review"]["check_first"])

    def test_a_spelling_with_two_meanings_fails(self) -> None:
        self.broken(lambda x: x["numbers"][3]["roman"].append("do"), "means both")

    def test_a_number_that_is_also_a_multiplier_fails(self) -> None:
        self.broken(lambda x: x["numbers"][7]["roman"].append("lakh"), "means both")

    def test_an_always_token_with_a_meaning_fails(self) -> None:
        self.broken(lambda x: x["numbers"][9]["roman"].append("no"), "must not have a meaning")

    def test_a_free_text_token_without_a_meaning_fails(self) -> None:
        self.broken(lambda x: x["numbers"][70]["roman"].remove("sattar"), "must have a meaning")

    def test_an_arabic_keyboard_spelling_fails(self) -> None:
        # Arabic yeh (U+064A): normalise folds it, so the spelling is not in normal form.
        self.broken(lambda x: x["numbers"][1]["ur"].append("اي" + "ک"), "normal form")

    def test_an_upper_case_spelling_fails(self) -> None:
        self.broken(lambda x: x["numbers"][1]["roman"].append("Ek"), "normal form")

    def test_a_spelling_with_a_space_fails(self) -> None:
        self.broken(lambda x: x["numbers"][1]["en"].append("a one"), "one word")

    def test_a_fraction_that_leaves_part_of_a_paisa_fails(self) -> None:
        self.broken(lambda x: entry(x, "fractions", id="sawa").update(den=3), "whole paisa")

    def test_a_prefix_needs_its_rules(self) -> None:
        self.broken(lambda x: entry(x, "fractions", id="sawa").pop("alone"), "missing")
        self.broken(lambda x: entry(x, "fractions", id="sawa").update(min_number=0), "from 1")
        self.broken(lambda x: entry(x, "fractions", id="sawa").update(alone="yes"), "boolean")
        self.broken(lambda x: entry(x, "fractions", id="derh").update(num=0), "more than")
        self.broken(lambda x: entry(x, "fractions", id="derh").update(kind="other"), "kind")
        self.broken(lambda x: entry(x, "fractions", id="derh").update(den=0), "den above 0")
        self.broken(lambda x: x["fractions"].append(x["fractions"][0]), "repeated id")

    def test_numbers_must_be_0_to_99(self) -> None:
        self.broken(lambda x: x["numbers"].pop(), "0 to 99")
        self.broken(lambda x: x["numbers"][5]["en"].clear(), "must not be empty")
        self.broken(lambda x: x["numbers"][5]["en"].append("five"), "repeats")
        self.broken(lambda x: x["numbers"][5].update(en="five"), "list of non-empty strings")

    def test_multipliers_must_rise(self) -> None:
        self.broken(lambda x: x["multipliers"].reverse(), "must rise")
        self.broken(lambda x: x["multipliers"][0]["ur"].clear(), "Urdu spelling")

    def test_write_forms_must_be_spellings_of_the_section(self) -> None:
        self.broken(lambda x: x["currency"]["write"]["roman"].update(one="rupaiya"), "spellings")
        self.broken(lambda x: x["paisa"]["write"].pop("en"), "missing")

    def test_symbols_are_one_character(self) -> None:
        self.broken(lambda x: x["foreign_currency"]["symbols"].append("US$"), "one character")

    def test_policies(self) -> None:
        self.broken(lambda x: x["ambiguous"][0].update(refuse="sometimes"), "refuse must")
        self.broken(lambda x: x["ambiguous"].append(x["ambiguous"][0]), "repeated token")
        self.broken(
            lambda x: entry(x, "ambiguous", token="aadha").update(read_after=["fraction"]),
            "read_after",
        )
        self.broken(
            lambda x: entry(x, "ambiguous", token="do").update(read_after=["number"]),
            "read_after",
        )
        self.broken(
            lambda x: x["ambiguous"].append({"token": "Do", "refuse": "always", "why": "."}),
            "normal form",
        )

    def test_homographs_and_left_out_spellings(self) -> None:
        self.broken(lambda x: x["homographs"].append({"token": "xyz", "why": "."}), "no meaning")
        self.broken(lambda x: x["not_included"].append({"token": "ek", "why": "."}), "is included")

    def test_header_and_normalise_rules(self) -> None:
        self.broken(lambda x: x.update(version=2), "version")
        self.broken(lambda x: x.pop("paisa"), "missing")
        self.broken(lambda x: x["review"].update(process="docs/none.md"), "no such file")
        self.broken(lambda x: x["review"].update(status="Draft."), "Not reviewed")
        self.broken(lambda x: x["sources"].append(x["sources"][0]), "repeated id")
        self.broken(
            lambda x: x["normalise"]["remove"].append(
                {"from": "U+0010", "to": "U+0001", "label": "."}
            ),
            "empty range",
        )
        self.broken(
            lambda x: x["normalise"]["fold"].append(x["normalise"]["fold"][0]), "folds twice"
        )
        self.broken(
            lambda x: x["normalise"]["spaces"].append({"code_point": "U+002C", "label": "."}),
            "both a space",
        )
        self.broken(lambda x: x.update(extra=1), "unexpected")

    def test_a_forbidden_character_fails(self) -> None:
        # Word joiner (U+2060): the Unicode guard forbids it, and normalise keeps it.
        self.broken(lambda x: x["numbers"][1]["roman"].append("e" + chr(0x2060) + "k"), "forbids")


class VectorsTest(unittest.TestCase):
    def broken(self, change, message: str) -> None:
        vec = vectors()
        change(vec)
        with self.assertRaisesRegex(amounts.ContractError, message):
            amounts.check_vectors(vec, LEXICON)

    def test_the_committed_vectors_pass(self) -> None:
        parse, words = amounts.check_vectors(vectors(), LEXICON)
        self.assertGreater(parse, 200)
        self.assertEqual(words, 30)

    def test_every_promised_example_is_required(self) -> None:
        def drop(v: dict) -> None:
            v["parse"] = [c for c in v["parse"] if c["input"] != "1.5 lac"]

        self.broken(drop, "promised examples")

    def test_bounds(self) -> None:
        self.broken(lambda v: v["parse"][0].update(expected=amounts.MAX_PAISA + 1), "from 0")
        self.broken(lambda v: v["parse"][0].update(expected=-1), "from 0")
        self.broken(lambda v: v["parse"][0].update(expected=True), "from 0")
        self.broken(lambda v: v["parse"][0].update(expected=1.5), "from 0")
        self.broken(lambda v: v["words"][0].update(paisa=amounts.MAX_PAISA + 1), "from 0")
        self.broken(lambda v: v.update(max_paisa=10**14), "max_paisa")

        def no_maximum(v: dict) -> None:
            v["parse"] = [c for c in v["parse"] if c["expected"] != amounts.MAX_PAISA]

        self.broken(no_maximum, "the maximum")

    def test_each_context_covers_every_outcome(self) -> None:
        def no_null_text(v: dict) -> None:
            v["parse"] = [
                c for c in v["parse"] if not (c["context"] == "text" and c["expected"] is None)
            ]

        self.broken(no_null_text, "text vectors")

    def test_shape(self) -> None:
        self.broken(lambda v: v["parse"][1].update(name=v["parse"][0]["name"]), "unique")
        self.broken(lambda v: v["parse"][0].update(context="chat"), "context")
        self.broken(lambda v: v["parse"][0].update(input=5), "string")
        self.broken(lambda v: v["parse"][0].pop("expected"), "missing")
        self.broken(lambda v: v["parse"].append(dict(v["parse"][0], name="copy")), "twice")
        self.broken(lambda v: v["words"][0].update(script="hindi"), "script")
        self.broken(lambda v: v["words"].append(v["words"][0]), "twice")
        self.broken(lambda v: v["words"][0].update(words=""), "non-empty")
        self.broken(lambda v: v.update(version=2), "version")

        def no_english_zero(v: dict) -> None:
            v["words"] = [w for w in v["words"] if (w["paisa"], w["script"]) != (0, "english")]

        self.broken(no_english_zero, "english must cover")

    def test_inputs_pass_the_unicode_guard(self) -> None:
        # The Arabic letter mark (U+061C) is one the guard forbids, so a vector must not carry it;
        # mm_core's unit tests build it from its code point instead.
        self.broken(lambda v: v["parse"][0].update(input="50" + chr(0x061C)), "Arabic letter mark")
        self.broken(lambda v: v["words"][0].update(words="x" + chr(0x202E)), "U\\+202E")


class DartTest(unittest.TestCase):
    def test_the_tables_name_every_spelling_and_the_review_state(self) -> None:
        dart = amounts.render_dart(lexicon())
        self.assertIn("const bool amountLexiconReviewed = false;", dart)
        self.assertIn("NOT YET REVIEWED", dart)
        self.assertIn("  'lakh': (AmountWordKind.multiplier, 5, true),", dart)
        self.assertIn("  r'$': (AmountWordKind.foreignCurrency, 0, false),", dart)
        self.assertIn("  'do': [AmountWordKind.fraction, AmountWordKind.currency],", dart)
        self.assertIn("const Set<String> amountSpaced = {\n  'k',\n};", dart)
        for line in dart.splitlines():
            self.assertLessEqual(len(line), 80, line)

    def test_a_reviewed_lexicon_says_so(self) -> None:
        lex = lexicon()
        lex["reviewed"] = True
        lex["review"]["status"] = "Reviewed by a native speaker."
        dart = amounts.render_dart(lex)
        self.assertIn("const bool amountLexiconReviewed = true;", dart)
        self.assertNotIn("NOT YET REVIEWED", dart)

    def test_a_quote_in_a_spelling_is_escaped(self) -> None:
        self.assertEqual(amounts._dart_string("it's"), "'it\\'s'")
        self.assertEqual(amounts._dart_string("$"), "r'$'")
        self.assertEqual(amounts._dart_string("a$'"), "'a\\$\\''")


if __name__ == "__main__":
    unittest.main()
