"""Tests of the place-name generator (tool/l10n/place_names.py).

    python3 -m unittest discover -s tool/l10n -p 'test_*.py'

The committed Dart table must be current, every stored country and zone must be named in both
languages, and every way the inputs can be incomplete or unclean must fail the generator.
"""

from __future__ import annotations

import copy
import io
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

import place_names as pn

ZWSP = chr(0x200B)


def inputs() -> tuple[dict, dict, dict, list[tuple[int, int, str]]]:
    """The committed inputs, as fresh copies a test may change."""
    return (
        pn.read_json(pn.EXTRACT),
        pn.read_json(pn.OVERRIDES),
        pn.read_json(pn.VECTORS),
        pn.forbidden_ranges(pn.read_json(pn.CLEAN_TEXT)),
    )


class CommittedTableTest(unittest.TestCase):
    def test_the_committed_table_is_current(self) -> None:
        self.assertEqual(pn.OUTPUT.read_text(encoding="utf-8"), pn.generate())

    def test_every_stored_country_and_zone_is_named_in_both_languages(self) -> None:
        extract, overrides, vectors, ranges = inputs()
        places = pn.build(extract, overrides, vectors, ranges)
        countries, cities = places.countries, places.cities
        codes, zones = pn.stored_lists(vectors)
        self.assertEqual([c.code for c in countries], codes)
        self.assertEqual([c.zone for c in cities], zones)
        for country in countries:
            self.assertTrue(country.en and country.ur, country)
        for city in cities:
            self.assertTrue(city.en and city.ur, city)

    def test_names_take_the_overrides_and_old_cldr_ids(self) -> None:
        places = pn.build(*inputs())
        countries, cities = places.countries, places.cities
        named = {c.code: c for c in countries}
        self.assertEqual(named["US"].ur, "امریکا")
        self.assertEqual(named["HM"].ur, "ہیرڈ جزیرہ اور میکڈونلڈ جزائر")
        self.assertEqual(named["GB"].ur, "برطانیہ")
        self.assertIn("UK", named["GB"].search_terms)
        self.assertIn("یو کے", named["GB"].search_terms)
        city = {c.zone: c for c in cities}
        # CLDR keys Kolkata's names on Asia/Calcutta.
        self.assertEqual(city["Asia/Kolkata"].ur, "کولکاتا")
        self.assertEqual(city["America/Sao_Paulo"].en, "São Paulo")
        # Without an English exemplar city, the place in the zone's name.
        self.assertEqual(city["America/Argentina/Buenos_Aires"].en, "Buenos Aires")

    def test_urdu_names_have_urdu_letters_and_no_vowel_marks(self) -> None:
        places = pn.build(*inputs())
        countries, cities = places.countries, places.cities
        for name in [c.ur for c in countries] + [c.ur for c in cities]:
            for char in name:
                self.assertNotIn(char, pn.URDU_LETTERS, name)
                self.assertNotIn(ord(char), pn.HARAKAT, name)

    def test_the_urdu_order_follows_the_urdu_alphabet(self) -> None:
        text = pn.OUTPUT.read_text(encoding="utf-8")
        order = text.split("countriesByUrdu = [")[1]
        self.assertLess(order.index("'IN'"), order.index("'PK'"))  # بھارت, پاکستان
        self.assertLess(order.index("'TZ'"), order.index("'TO'"))  # تنزانیہ, ٹونگا


class OrderTest(unittest.TestCase):
    def test_urdu_letters_sort_in_the_alphabet_s_order(self) -> None:
        names = ["ٹب", "تب", "کس", "قس", "پس", "بس", "گس"]
        expected = ["بس", "پس", "تب", "ٹب", "قس", "کس", "گس"]
        self.assertEqual(sorted(names, key=pn.urdu_key), expected)

    def test_a_marked_letter_sorts_with_its_base_after_it(self) -> None:
        self.assertEqual(sorted(["آب", "اب", "اث"], key=pn.urdu_key), ["اب", "آب", "اث"])

    def test_spaces_sort_first_and_latin_letters_last(self) -> None:
        latin = "کت" + "X"
        self.assertEqual(sorted(["کتب", "کت ب", latin], key=pn.urdu_key), ["کت ب", "کتب", latin])

    def test_english_ignores_case_and_accents(self) -> None:
        names = ["Albania", "Åland Islands", "afghanistan"]
        self.assertEqual(
            sorted(names, key=pn.english_key), ["afghanistan", "Åland Islands", "Albania"]
        )


class CleaningTest(unittest.TestCase):
    def test_arabic_letters_become_urdu_and_vowel_marks_go(self) -> None:
        arabic = "".join(chr(p) for p in (0x064A, 0x0643, 0x0647, 0x0649))
        self.assertEqual(pn.plain_urdu(arabic), "یکہی")
        self.assertEqual(pn.plain_urdu("امّان"), "امان")
        self.assertEqual(pn.plain_urdu("کِیف"), "کیف")

    def test_dart_strings_are_escaped(self) -> None:
        self.assertEqual(pn._dart("St John's $1 \\"), "'St John\\'s \\$1 \\\\'")
        self.assertEqual(pn._dart("line\n"), "'line\\n'")

    def test_the_licence_is_kept_line_by_line(self) -> None:
        text = pn.render(pn.Places("49.0.0", [], [], {}), "A\n\nB")
        self.assertIn("const String cldrLicence =\n    'A\\n'\n    '\\n'\n    'B\\n';\n", text)


class RefusalTest(unittest.TestCase):
    def assert_refused(self, change, message: str) -> None:
        extract, overrides, vectors, ranges = inputs()
        change(extract, overrides, vectors)
        with self.assertRaisesRegex(pn.PlaceNameError, message):
            pn.build(extract, overrides, vectors, ranges)

    def test_a_stored_country_without_a_name(self) -> None:
        self.assert_refused(lambda e, o, v: e["countries"].pop("GB"), "GB: CLDR has no name")

    def test_a_stored_country_without_an_urdu_name(self) -> None:
        self.assert_refused(lambda e, o, v: e["countries"]["GB"].pop("ur"), "GB ur: no name")

    def test_an_empty_name(self) -> None:
        def change(e, o, v):
            e["countries"]["FR"]["en"] = "  "

        self.assert_refused(change, "FR en: no name")

    def test_a_forbidden_character(self) -> None:
        def change(e, o, v):
            e["countries"]["FR"]["ur"] = "فرا" + ZWSP + "نس"

        self.assert_refused(change, "FR ur: U[+]200B")

    def test_a_forbidden_character_in_a_search_term(self) -> None:
        def change(e, o, v):
            o["searchTerms"]["GB"]["terms"].append("U" + ZWSP + "K")

        self.assert_refused(change, "GB search term: U[+]200B")

    def test_a_stored_zone_cldr_does_not_know(self) -> None:
        def change(e, o, v):
            e["zones"] = [z for z in e["zones"] if "Europe/London" not in z["ids"]]

        self.assert_refused(change, "Europe/London: CLDR does not know the zone")

    def test_a_stored_zone_without_an_urdu_city(self) -> None:
        def change(e, o, v):
            for zone in e["zones"]:
                if "Europe/London" in zone["ids"]:
                    zone.pop("ur")

        self.assert_refused(change, "Europe/London ur: no name")

    def test_an_override_for_a_country_not_stored(self) -> None:
        def change(e, o, v):
            o["countries"]["XK"] = {"ur": "کوسووو", "reason": "a test"}

        self.assert_refused(change, "countries: XK is not stored")

    def test_an_override_for_a_zone_not_stored(self) -> None:
        def change(e, o, v):
            o["cities"]["Asia/Calcutta"] = {"ur": "کلکتہ", "reason": "a test"}

        self.assert_refused(change, "cities: Asia/Calcutta is not stored")

    def test_search_terms_for_a_country_not_stored(self) -> None:
        def change(e, o, v):
            o["searchTerms"]["EU"] = {"terms": ["Europe"], "reason": "a test"}

        self.assert_refused(change, "searchTerms: EU is not stored")

    def test_an_override_without_a_reason(self) -> None:
        def change(e, o, v):
            o["countries"]["US"]["reason"] = " "

        self.assert_refused(change, "countries: US gives no reason")

    def test_a_suggested_zone_of_another_country(self) -> None:
        def change(e, o, v):
            o["suggestedZones"]["AU"]["zones"].append("Europe/London")

        self.assert_refused(change, "Europe/London is not a zone of AU")

    def test_a_suggestion_without_zones(self) -> None:
        def change(e, o, v):
            o["suggestedZones"]["AU"]["zones"] = []

        self.assert_refused(change, "AU lists no zones")

    def test_suggestions_for_a_country_not_stored(self) -> None:
        def change(e, o, v):
            o["suggestedZones"]["XK"] = {"zones": ["Europe/Belgrade"], "reason": "a test"}

        self.assert_refused(change, "suggestedZones: XK is not stored")

    def test_overrides_that_are_not_an_object(self) -> None:
        def change(e, o, v):
            o["cities"] = []

        self.assert_refused(change, "cities: not an object")

    def test_a_city_override_applies(self) -> None:
        extract, overrides, vectors, ranges = inputs()
        overrides = copy.deepcopy(overrides)
        overrides["cities"]["Asia/Kolkata"] = {"ur": "کلکتہ", "reason": "a test"}
        cities = pn.build(extract, overrides, vectors, ranges).cities
        self.assertIn(pn.City("Asia/Kolkata", "Kolkata", "کلکتہ"), cities)


class MainTest(unittest.TestCase):
    def run_main(self, output: Path, *args: str) -> tuple[int, str]:
        err = io.StringIO()
        with (
            mock.patch.object(pn, "OUTPUT", output),
            mock.patch.object(pn, "ROOT", output.parent),
            redirect_stderr(err),
            redirect_stdout(io.StringIO()),
        ):
            return pn.main(["place_names.py", *args]), err.getvalue()

    def test_write_then_check(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "place_names.g.dart"
            self.assertEqual(self.run_main(output, "--check")[0], 1)  # missing
            self.assertEqual(self.run_main(output)[0], 0)
            self.assertEqual(self.run_main(output, "--check"), (0, ""))
            output.write_text("stale", encoding="utf-8")
            code, err = self.run_main(output, "--check")
            self.assertEqual(code, 1)
            self.assertIn("is stale", err)

    def test_a_refusal_fails_without_writing(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "place_names.g.dart"
            with mock.patch.object(pn, "build", side_effect=pn.PlaceNameError("broken")):
                code, err = self.run_main(output)
            self.assertEqual(code, 1)
            self.assertIn("place_names: broken", err)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
