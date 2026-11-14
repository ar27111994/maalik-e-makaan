#!/usr/bin/env python3
"""Generate the app's country and city names, in English and Urdu (`make place-names`).

The residence screen names every country a person may say they live in, and the city of each
time zone they may choose; dual times name the city of a person's own zone ("London"). The names
come from CLDR, through the trimmed extract tool/l10n/import_cldr.py writes
(tool/l10n/cldr_places.json), with the plain-Urdu fixes and search words reviewed in
app/lib/l10n/place_name_overrides.json. This script reads both, offline, with the stored lists
in contracts/residence_vectors.json, and writes app/lib/src/core/place_names.g.dart:

    python3 tool/l10n/place_names.py            # write the Dart table
    python3 tool/l10n/place_names.py --check    # fail when it is stale (CI)

On the way it:
  * reads the Arabic keyboard's yeh, kaf and heh as the Urdu letters, and drops the Arabic
    vowel marks (harakat), so the app's search and the plain-Urdu guard see ordinary spellings;
  * names every stored zone in English by CLDR's exemplar city, else by the place in its IANA
    name ("Buenos_Aires" is "Buenos Aires"), as TimeZoneId.exemplarCity does;
  * finds an Urdu name for every stored zone through all of its CLDR ids (CLDR keys some names
    on old ids, such as Asia/Calcutta for Asia/Kolkata);
  * sorts the countries twice: in English by name without case or accents, and in Urdu by the
    Urdu alphabet (URDU_ALPHABET), which Unicode's code-point order does not follow (it puts
    ٹ پ چ ڈ ڑ ک گ after ق);
  * keeps the reviewed zones to suggest first in countries whose zone.tab order puts a small
    place before the big city that shares its clock (Lord Howe Island before Sydney);
  * and fails when a stored country or zone has no name in either language, a name is empty or
    holds a character contracts/clean_text.json forbids, or an override names a code or zone the
    app does not store (or a suggested zone of another country), or gives no reason.
"""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXTRACT = ROOT / "tool" / "l10n" / "cldr_places.json"
OVERRIDES = ROOT / "app" / "lib" / "l10n" / "place_name_overrides.json"
VECTORS = ROOT / "contracts" / "residence_vectors.json"
CLEAN_TEXT = ROOT / "contracts" / "clean_text.json"
OUTPUT = ROOT / "app" / "lib" / "src" / "core" / "place_names.g.dart"

# The Arabic keyboard's letters and the Urdu ones a reader expects (as tool/check_urdu_words.py
# reads them): yeh, alef maksura, kaf and heh.
URDU_LETTERS = {
    chr(0x064A): chr(0x06CC),
    chr(0x0649): chr(0x06CC),
    chr(0x0643): chr(0x06A9),
    chr(0x0647): chr(0x06C1),
}
# The Arabic vowel marks, from fathatan to sukun: CLDR writes a few (امّان), Urdu readers do not.
HARAKAT = range(0x064B, 0x0653)

# The Urdu alphabet, in a dictionary's order. A letter written with a mark (آ, ؤ, ئ, ۂ) sorts
# with its base letter, after it when two names differ only there.
URDU_ALPHABET = "ابپتٹثجچحخدڈذرڑزژسشصضطظعغفقکگلمنںوہھءیے"
# Each pair is a marked letter and its base.
URDU_VARIANTS = dict(["آا", "ؤو", "ئء", "ۂہ", "ۓے"])


class PlaceNameError(Exception):
    """The inputs cannot make a complete, clean table."""


@dataclass(frozen=True)
class Country:
    code: str
    en: str
    ur: str
    search_terms: tuple[str, ...]


@dataclass(frozen=True)
class City:
    zone: str
    en: str
    ur: str


@dataclass(frozen=True)
class Places:
    """Everything the Dart table holds."""

    version: str
    countries: list[Country]
    cities: list[City]
    # By country code: the zones to suggest first, best first.
    suggested: dict[str, list[str]]


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def forbidden_ranges(contract: dict) -> list[tuple[int, int, str]]:
    """The code-point ranges contracts/clean_text.json forbids, with their labels."""
    return [
        (int(item["from"][2:], 16), int(item["to"][2:], 16), item["label"])
        for item in contract["forbidden"]
    ]


def plain_urdu(text: str) -> str:
    """[text] with the Arabic keyboard's letters read as Urdu and the vowel marks dropped."""
    return "".join(
        URDU_LETTERS.get(char, char) for char in text if ord(char) not in HARAKAT
    ).strip()


def checked(name: object, where: str, ranges: list[tuple[int, int, str]]) -> str:
    """[name] when it is a non-empty string without a forbidden character; else an error."""
    if not isinstance(name, str) or not name.strip():
        raise PlaceNameError(f"{where}: no name")
    for char in name:
        point = ord(char)
        for low, high, label in ranges:
            if low <= point <= high:
                raise PlaceNameError(f"{where}: U+{point:04X} ({label}) in {name!r}")
    return name.strip()


def english_key(name: str) -> str:
    """How English sorts [name]: without case or accents ("Åland" beside "Albania")."""
    decomposed = unicodedata.normalize("NFD", name.casefold())
    return "".join(char for char in decomposed if not unicodedata.combining(char))


_URDU_RANK = {letter: index for index, letter in enumerate(URDU_ALPHABET)}


def urdu_key(name: str) -> tuple[tuple[int, ...], tuple[int, ...]]:
    """How Urdu sorts [name]: letter by letter in the alphabet's order, marks second.

    Spaces and punctuation sort before every letter; a character outside the alphabet (a Latin
    letter) after them all, by code point.
    """
    primary: list[int] = []
    secondary: list[int] = []
    for char in name:
        base = URDU_VARIANTS.get(char, char)
        if base in _URDU_RANK:
            primary.append(1 + _URDU_RANK[base])
            secondary.append(0 if base == char else 1)
        elif char.isalpha():
            primary.append(1 + len(_URDU_RANK) + ord(char))
            secondary.append(0)
        else:
            primary.append(0)
            secondary.append(0)
    return tuple(primary), tuple(secondary)


def stored_lists(vectors: dict) -> tuple[list[str], list[str]]:
    """The country codes and zone names the database stores, in the vectors' order."""
    return (
        [country["code"] for country in vectors["countries"]],
        [zone["name"] for zone in vectors["timeZones"]],
    )


def _reasoned(entries: object, where: str, known: set[str]) -> dict[str, dict]:
    if not isinstance(entries, dict):
        raise PlaceNameError(f"{where}: not an object")
    for key, entry in entries.items():
        if key not in known:
            raise PlaceNameError(f"{where}: {key} is not stored by the app")
        if not isinstance(entry, dict) or not str(entry.get("reason", "")).strip():
            raise PlaceNameError(f"{where}: {key} gives no reason")
    return entries


def suggested_zones(overrides: dict, vectors: dict) -> dict[str, list[str]]:
    """The zones to suggest first per country, each one of that country's stored zones."""
    codes, _ = stored_lists(vectors)
    fixes = _reasoned(overrides.get("suggestedZones", {}), "suggestedZones", set(codes))
    own = {country["code"]: country["zones"] for country in vectors["countries"]}
    suggested = {}
    for code, entry in fixes.items():
        zones = entry.get("zones")
        if not isinstance(zones, list) or not zones:
            raise PlaceNameError(f"suggestedZones: {code} lists no zones")
        for zone in zones:
            if zone not in own[code]:
                raise PlaceNameError(f"suggestedZones: {zone} is not a zone of {code}")
        suggested[code] = list(zones)
    return suggested


def build(
    extract: dict, overrides: dict, vectors: dict, ranges: list[tuple[int, int, str]]
) -> Places:
    """The stored countries, the stored zones' cities and the suggested zones, checked."""
    codes, zones = stored_lists(vectors)
    country_fixes = _reasoned(overrides.get("countries", {}), "countries", set(codes))
    city_fixes = _reasoned(overrides.get("cities", {}), "cities", set(zones))
    search_fixes = _reasoned(overrides.get("searchTerms", {}), "searchTerms", set(codes))

    countries = []
    for code in codes:
        source = extract["countries"].get(code)
        if source is None:
            raise PlaceNameError(f"{code}: CLDR has no name")
        fix = country_fixes.get(code, {})
        en = checked(fix.get("en", source.get("en")), f"{code} en", ranges)
        ur = plain_urdu(checked(fix.get("ur", source.get("ur")), f"{code} ur", ranges))
        terms: list[str] = []
        alternatives = [
            *source.get("enAlternatives", {}).values(),
            *(plain_urdu(t) for t in source.get("urAlternatives", {}).values()),
            *search_fixes.get(code, {}).get("terms", []),
        ]
        for term in alternatives:
            term = checked(term, f"{code} search term", ranges)
            if term not in (en, ur) and term not in terms:
                terms.append(term)
        countries.append(Country(code, en, ur, tuple(terms)))

    by_id: dict[str, dict] = {}
    for entry in extract["zones"]:
        for zone_id in entry["ids"]:
            by_id.setdefault(zone_id, entry)
    cities = []
    for zone in zones:
        entry = by_id.get(zone)
        if entry is None:
            raise PlaceNameError(f"{zone}: CLDR does not know the zone")
        fix = city_fixes.get(zone, {})
        fallback = zone.rsplit("/", 1)[-1].replace("_", " ")
        en = checked(fix.get("en", entry.get("en", fallback)), f"{zone} en", ranges)
        ur = plain_urdu(checked(fix.get("ur", entry.get("ur")), f"{zone} ur", ranges))
        cities.append(City(zone, en, ur))
    return Places(str(extract["cldr"]), countries, cities, suggested_zones(overrides, vectors))


def _dart(text: str) -> str:
    """[text] as a single-quoted Dart string, on one line."""
    escaped = text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return "'" + escaped.replace(chr(10), "\\n") + "'"


def render(places: Places, licence: str) -> str:
    """The Dart table, as committed."""
    version, countries, cities = places.version, places.countries, places.cities
    licence_lines = [f"    {_dart(line + chr(10))}" for line in licence.splitlines()]
    licence_lines[-1] += ";"
    by_english = sorted(countries, key=lambda c: (english_key(c.en), c.code))
    by_urdu = sorted(countries, key=lambda c: (urdu_key(c.ur), c.code))
    lines = [
        "// GENERATED by tool/l10n/place_names.py from tool/l10n/cldr_places.json",
        f"// (CLDR {version}, Unicode License v3) and app/lib/l10n/place_name_overrides.json.",
        "// Do not edit by hand: change the overrides, or bump CLDR with",
        "// tool/l10n/import_cldr.py, and run `make place-names`.",
        "//",
        "// The names of the stored countries and of the stored zones' cities",
        "// (contracts/residence_vectors.json), in English and Urdu, read by",
        "// place_names.dart.",
        "",
        "// dart format off",
        "",
        "/// The CLDR release the names come from.",
        f"const String cldrVersion = {_dart(version)};",
        "",
        "/// The licence the names come under (the Unicode License v3), for the",
        "/// app's licence page.",
        "const String cldrLicence =",
        *licence_lines,
        "",
        "/// Every stored country: its English and Urdu names, and the other words",
        "/// a search finds it by (CLDR's short and variant forms, and the",
        "/// overrides' search terms).",
        "const Map<String, (String, String, List<String>)> placeCountries = {",
    ]
    for country in countries:
        terms = ", ".join(_dart(term) for term in country.search_terms)
        lines.append(
            f"  {_dart(country.code)}: ({_dart(country.en)}, {_dart(country.ur)}, [{terms}]),"
        )
    lines += [
        "};",
        "",
        "/// Every stored zone's city, in English and Urdu.",
        "const Map<String, (String, String)> placeCities = {",
    ]
    for city in cities:
        lines.append(f"  {_dart(city.zone)}: ({_dart(city.en)}, {_dart(city.ur)}),")
    lines += [
        "};",
        "",
        "/// The zones to suggest first when a phone gives only its clock's offset,",
        "/// best first, for the countries whose zone.tab order would suggest a",
        "/// small place before the big city that shares its clock.",
        "const Map<String, List<String>> suggestedZonesFirst = {",
    ]
    for code, zones in places.suggested.items():
        listed = ", ".join(_dart(zone) for zone in zones)
        lines.append(f"  {_dart(code)}: [{listed}],")
    lines += [
        "};",
        "",
        "/// The stored countries by English name, without case or accents.",
        "const List<String> countriesByEnglish = [",
        *(f"  {_dart(country.code)}," for country in by_english),
        "];",
        "",
        "/// The stored countries by Urdu name, in the Urdu alphabet's order.",
        "const List<String> countriesByUrdu = [",
        *(f"  {_dart(country.code)}," for country in by_urdu),
        "];",
        "",
    ]
    return "\n".join(lines)


def generate() -> str:
    """The Dart table from the committed inputs."""
    extract = read_json(EXTRACT)
    ranges = forbidden_ranges(read_json(CLEAN_TEXT))
    places = build(extract, read_json(OVERRIDES), read_json(VECTORS), ranges)
    licence = checked(extract.get("licence"), "licence", ranges)
    return render(places, licence)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true", help="fail when the output is stale")
    args = parser.parse_args(argv[1:])
    try:
        text = generate()
    except PlaceNameError as error:
        print(f"place_names: {error}", file=sys.stderr)
        return 1
    relative = OUTPUT.relative_to(ROOT)
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else None
        if current != text:
            print(f"place_names: {relative} is stale; run `make place-names`", file=sys.stderr)
            return 1
        return 0
    OUTPUT.write_text(text, encoding="utf-8")
    print(f"wrote {relative}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
