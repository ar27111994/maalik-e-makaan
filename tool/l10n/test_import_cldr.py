"""Tests of the CLDR importer (tool/l10n/import_cldr.py), offline.

    python3 -m unittest discover -s tool/l10n -p 'test_*.py'

The importer itself downloads; these tests feed it small documents shaped like CLDR's and check
what it keeps, and that a changed file or an unclean name is refused.
"""

from __future__ import annotations

import hashlib
import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

import import_cldr as ic

RANGES = ic.forbidden_ranges()
ZWSP = chr(0x200B)


def territories(locale: str, names: dict[str, str]) -> dict:
    return {"main": {locale: {"localeDisplayNames": {"territories": names}}}}


def zone_names(locale: str, tree: dict) -> dict:
    return {"main": {locale: {"dates": {"timeZoneNames": {"zone": tree}}}}}


def documents() -> dict[str, object]:
    return {
        ic.LICENCE: "UNICODE LICENSE V3\n",
        ic.TERRITORIES_EN: territories(
            "en-GB",
            {"GB": "United Kingdom", "GB-alt-short": "UK", "ZZ": "Unknown Region", "001": "World"},
        ),
        ic.TERRITORIES_UR: territories("ur", {"GB": "برطانیہ", "ZZ": "کوئی علاقہ"}),
        ic.ZONES_EN: zone_names("en", {"Asia": {"Saigon": {"exemplarCity": "Ho Chi Minh City"}}}),
        ic.ZONES_UR: zone_names(
            "ur",
            {"Europe": {"London": {"exemplarCity": "لندن"}}, "Asia": {"Saigon": {"long": {}}}},
        ),
        ic.BCP47: {
            "keyword": {
                "u": {
                    "tz": {
                        "_description": "Time zone key",
                        "gblon": {"_alias": "Europe/London Europe/Belfast GB"},
                        "vnsgn": {"_alias": "Asia/Saigon Asia/Ho_Chi_Minh"},
                        "utc": {"_alias": "Etc/UTC Etc/UCT UTC"},
                        "unk": {"_alias": "Etc/Unknown Factory"},
                    }
                }
            }
        },
    }


class ExtractTest(unittest.TestCase):
    def test_it_keeps_regions_their_short_forms_and_zone_cities(self) -> None:
        data = ic.extract(documents(), RANGES)
        self.assertEqual(data["cldr"], ic.CLDR_TAG)
        self.assertEqual(data["licence"], "UNICODE LICENSE V3\n")
        self.assertEqual(
            data["countries"],
            {"GB": {"en": "United Kingdom", "enAlternatives": {"short": "UK"}, "ur": "برطانیہ"}},
        )
        self.assertEqual(
            data["zones"],
            [
                {"ids": ["Europe/London", "Europe/Belfast", "GB"], "ur": "لندن"},
                {"ids": ["Asia/Saigon", "Asia/Ho_Chi_Minh"], "en": "Ho Chi Minh City"},
            ],
        )

    def test_a_region_without_an_urdu_name_is_refused(self) -> None:
        docs = documents()
        docs[ic.TERRITORIES_EN]["main"]["en-GB"]["localeDisplayNames"]["territories"][
            "FR"
        ] = "France"
        with self.assertRaisesRegex(ic.CldrError, "FR: no Urdu name"):
            ic.extract(docs, RANGES)

    def test_a_forbidden_character_is_refused(self) -> None:
        docs = documents()
        docs[ic.TERRITORIES_UR]["main"]["ur"]["localeDisplayNames"]["territories"]["GB"] = (
            "برطا" + ZWSP + "نیہ"
        )
        with self.assertRaisesRegex(ic.CldrError, "GB ur: U[+]200B"):
            ic.extract(docs, RANGES)

    def test_an_empty_name_is_refused(self) -> None:
        with self.assertRaisesRegex(ic.CldrError, "an empty name"):
            ic.check_clean(" ", "GB en", RANGES)

    def test_a_city_is_found_only_at_its_full_path(self) -> None:
        tree = {"America": {"Argentina": {"Cordoba": {"exemplarCity": "Córdoba"}}}}
        self.assertEqual(ic.exemplar_city(tree, "America/Argentina/Cordoba"), "Córdoba")
        self.assertIsNone(ic.exemplar_city(tree, "America/Cordoba"))
        self.assertIsNone(ic.exemplar_city({"America": "x"}, "America/Cordoba"))


class PinnedTest(unittest.TestCase):
    def test_a_file_must_match_its_hash(self) -> None:
        name = ic.BCP47
        with self.assertRaisesRegex(ic.CldrError, "SHA-256"):
            ic.read_pinned(name, b"{}")
        data = b'{"ok": true}'
        with mock.patch.dict(ic.FILES, {name: hashlib.sha256(data).hexdigest()}):
            self.assertEqual(ic.read_pinned(name, data), {"ok": True})
        # The licence is text, read whole.
        with mock.patch.dict(ic.FILES, {ic.LICENCE: hashlib.sha256(data).hexdigest()}):
            self.assertEqual(ic.read_pinned(ic.LICENCE, data), '{"ok": true}')

    def test_the_data_files_are_under_cldr_json_and_the_licence_at_the_root(self) -> None:
        self.assertEqual(ic.source_path(ic.LICENCE), "LICENSE")
        self.assertEqual(ic.source_path(ic.BCP47), "cldr-json/cldr-bcp47/bcp47/timezone.json")

    def test_the_committed_licence_is_the_unicode_licence(self) -> None:
        data = json.loads(ic.EXTRACT.read_text("utf-8"))
        self.assertTrue(data["licence"].startswith("UNICODE LICENSE V3"))
        self.assertIn("SPDX-License-Identifier: Unicode-3.0", data["licence"])

    def test_main_reads_a_folder_and_writes_the_extract(self) -> None:
        docs = documents()
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "cldr"
            hashes = {}
            for name, document in docs.items():
                path = source / ic.source_path(name)
                path.parent.mkdir(parents=True, exist_ok=True)
                text = document if isinstance(document, str) else json.dumps(document)
                raw = text.encode("utf-8")
                path.write_bytes(raw)
                hashes[name] = hashlib.sha256(raw).hexdigest()
            extract = Path(folder) / "cldr_places.json"
            out = io.StringIO()
            with (
                mock.patch.dict(ic.FILES, hashes),
                mock.patch.object(ic, "EXTRACT", extract),
                mock.patch.object(ic, "ROOT", Path(folder)),
                redirect_stdout(out),
            ):
                self.assertEqual(ic.main(["import_cldr.py", "--from", str(source)]), 0)
            self.assertEqual(json.loads(extract.read_text("utf-8")), ic.extract(docs, RANGES))
            self.assertIn("1 countries, 2 zones", out.getvalue())
            # A changed file is refused, and nothing is written.
            (source / ic.source_path(ic.BCP47)).write_bytes(b"{}")
            extract.unlink()
            err = io.StringIO()
            with (
                mock.patch.dict(ic.FILES, hashes),
                mock.patch.object(ic, "EXTRACT", extract),
                redirect_stderr(err),
            ):
                self.assertEqual(ic.main(["import_cldr.py", "--from", str(source)]), 1)
            self.assertIn("SHA-256", err.getvalue())
            self.assertFalse(extract.exists())

    def test_the_committed_extract_is_the_pinned_release(self) -> None:
        data = json.loads(ic.EXTRACT.read_text("utf-8"))
        self.assertEqual(data["cldr"], ic.CLDR_TAG)
        self.assertEqual(ic.render(data), ic.EXTRACT.read_text("utf-8"))


if __name__ == "__main__":
    unittest.main()
