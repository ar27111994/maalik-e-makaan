#!/usr/bin/env python3
"""Import the country and city names the app shows from CLDR, pinned and hash-checked.

The app names the countries a person may say they live in, and the city of each time zone they
may choose, in English and Urdu. Those names come from the Unicode CLDR (cldr-json, tag
CLDR_TAG): five data files and the licence, each checked against the SHA-256 in FILES before
anything is read. This script keeps only what the app needs and writes it to
tool/l10n/cldr_places.json, which is committed; tool/l10n/place_names.py reads that extract, offline, to generate the app's Dart
table (`make place-names`).

Run it by hand when CLDR is bumped (it needs the network), then `make place-names`:

    python3 tool/l10n/import_cldr.py                 # download the pinned files
    python3 tool/l10n/import_cldr.py --from DIR      # read them from a checkout of cldr-json

To bump CLDR: change CLDR_TAG and every hash in FILES (taken from the files at the new tag), run
both commands, and review the diff of cldr_places.json and of the generated names, in both
languages, before committing. The raw files are never committed: they carry far more text than
the app uses, which the Unicode and plain-Urdu guards would then have to read.

What the extract holds:
  * licence: the text of the Unicode License v3 the data comes under (the repository's
    LICENSE), which the app shows on its licence page;
  * countries: every two-letter region CLDR names (not ZZ, its "Unknown Region"), with its
    en-GB and ur names and their alternative forms (short, variant), which the app finds a
    country by;
  * zones: every time zone of a place CLDR knows (its bcp47 list, without UTC, the Etc/
    offsets, the old rule zones such as EST5EDT and the placeholders), with all its IANA names (CLDR keys names on old ids, such as Asia/Calcutta
    for Asia/Kolkata) and its exemplar city in en and ur where CLDR has one.

A name holding a character contracts/clean_text.json forbids is refused, as is a file whose
hash differs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXTRACT = ROOT / "tool" / "l10n" / "cldr_places.json"
CLEAN_TEXT = ROOT / "contracts" / "clean_text.json"

CLDR_TAG = "49.0.0"
REPOSITORY_URL = f"https://raw.githubusercontent.com/unicode-org/cldr-json/{CLDR_TAG}/"

# The Unicode License v3 the data comes under, at the repository's root: the app shows it on its
# licence page.
LICENCE = "LICENSE"

TERRITORIES_EN = "cldr-localenames-full/main/en-GB/territories.json"
TERRITORIES_UR = "cldr-localenames-full/main/ur/territories.json"
ZONES_EN = "cldr-dates-full/main/en/timeZoneNames.json"
ZONES_UR = "cldr-dates-full/main/ur/timeZoneNames.json"
BCP47 = "cldr-bcp47/bcp47/timezone.json"

DATA = [TERRITORIES_EN, TERRITORIES_UR, ZONES_EN, ZONES_UR, BCP47]

# The pinned files and their SHA-256 at CLDR_TAG. The data files are under cldr-json/.
FILES = {
    LICENCE: "220ba0e1c43b99530d2d5bdb892a99dca0989414f51ab695ecd90163eaa1ec3b",
    TERRITORIES_EN: "67964e025acffe2106c9315b68365dbf25da72e6a594e43383f0e0cae8623575",
    TERRITORIES_UR: "7c123754c28150cf860e51541004c338ddf0a9cee739980c8869385dc27a7a7a",
    ZONES_EN: "094ebe6164483f3c3745496d0810ae52049b2e28ba4aaed22a7c435f65944e91",
    ZONES_UR: "1e5f8515b2277eba572871842a21baeb771ba061113da156464cbc26ebada6ac",
    BCP47: "e9ba00dc084c02f427660e5009724159478efac4e1663d2d0cacab17d733a7af",
}

REGION = re.compile(r"^[A-Z]{2}$")
# Not places: CLDR's "Unknown Region", and its zones that are offsets or placeholders
# (Etc/UTC, Etc/GMT+5, Etc/Unknown, Factory). A zone none of whose names is Area/Place (UTC,
# GMT, the old rule zones such as EST5EDT) is not a place either.
NOT_A_REGION = {"ZZ"}
NOT_A_ZONE = re.compile(r"^(Etc/|Factory$)")
ALTERNATIVE = re.compile(r"^([A-Z]{2})-alt-([a-z]+)$")


class CldrError(Exception):
    """A pinned file is missing, differs from its hash, or holds a name the app refuses."""


def forbidden_ranges(contract: Path = CLEAN_TEXT) -> list[tuple[int, int, str]]:
    """The code-point ranges contracts/clean_text.json forbids, with their labels."""
    data = json.loads(contract.read_text(encoding="utf-8"))
    return [
        (int(item["from"][2:], 16), int(item["to"][2:], 16), item["label"])
        for item in data["forbidden"]
    ]


def check_clean(name: str, where: str, ranges: list[tuple[int, int, str]]) -> str:
    """[name] when it is non-empty and holds no forbidden character; else CldrError."""
    if not name.strip():
        raise CldrError(f"{where}: an empty name")
    for char in name:
        point = ord(char)
        for low, high, label in ranges:
            if low <= point <= high:
                raise CldrError(f"{where}: U+{point:04X} ({label}) in {name!r}")
    return name


def read_pinned(name: str, data: bytes) -> object:
    """The pinned file [name], once its bytes match the pinned hash: the licence's text, or the
    JSON of a data file."""
    digest = hashlib.sha256(data).hexdigest()
    if digest != FILES[name]:
        raise CldrError(f"{name}: SHA-256 {digest}, pinned {FILES[name]}")
    text = data.decode("utf-8")
    return text if name == LICENCE else json.loads(text)


def source_path(name: str) -> str:
    """Where the pinned file [name] is in the cldr-json repository."""
    return name if name == LICENCE else f"cldr-json/{name}"


def download(name: str) -> bytes:
    """The bytes of the pinned file [name] at CLDR_TAG."""
    url = REPOSITORY_URL + source_path(name)
    with urllib.request.urlopen(url, timeout=60) as response:  # noqa: S310
        return response.read()


def _territories(document: object, locale: str) -> dict[str, str]:
    return document["main"][locale]["localeDisplayNames"]["territories"]  # type: ignore[index]


def _zone_tree(document: object, locale: str) -> dict[str, object]:
    return document["main"][locale]["dates"]["timeZoneNames"]["zone"]  # type: ignore[index]


def exemplar_city(tree: dict[str, object], name: str) -> str | None:
    """The exemplar city CLDR's [tree] gives the IANA [name], or None."""
    node: object = tree
    for part in name.split("/"):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    city = node.get("exemplarCity") if isinstance(node, dict) else None
    return city if isinstance(city, str) else None


def extract(documents: dict[str, object], ranges: list[tuple[int, int, str]]) -> dict:
    """The app's extract from the parsed files (keyed as FILES is)."""
    names = {
        "en": _territories(documents[TERRITORIES_EN], "en-GB"),
        "ur": _territories(documents[TERRITORIES_UR], "ur"),
    }
    countries: dict[str, dict[str, object]] = {}
    regions = (code for code in names["en"] if REGION.match(code) and code not in NOT_A_REGION)
    for code in sorted(regions):
        if code not in names["ur"]:
            raise CldrError(f"{code}: no Urdu name")
        entry: dict[str, object] = {}
        for language, table in names.items():
            entry[language] = check_clean(table[code], f"{code} {language}", ranges)
            alternatives = {
                match[2]: check_clean(value, f"{key} {language}", ranges)
                for key, value in table.items()
                if (match := ALTERNATIVE.match(key)) and match[1] == code
            }
            if alternatives:
                entry[f"{language}Alternatives"] = dict(sorted(alternatives.items()))
        countries[code] = entry

    trees = {
        "en": _zone_tree(documents[ZONES_EN], "en"),
        "ur": _zone_tree(documents[ZONES_UR], "ur"),
    }
    zones = []
    keys = documents[BCP47]["keyword"]["u"]["tz"]  # type: ignore[index]
    for key in sorted(keys):
        value = keys[key]
        if not isinstance(value, dict) or "_alias" not in value:
            continue
        ids = value["_alias"].split()
        if not any("/" in i and not NOT_A_ZONE.match(i) for i in ids):
            continue
        entry = {"ids": ids}
        for language, tree in trees.items():
            city = next((c for i in ids if (c := exemplar_city(tree, i)) is not None), None)
            if city is not None:
                entry[language] = check_clean(city, f"{ids[0]} {language}", ranges)
        zones.append(entry)
    return {
        "$comment": (
            f"An extract of CLDR {CLDR_TAG} (unicode-org/cldr-json, Unicode License v3), "
            "written by tool/l10n/import_cldr.py from six hash-checked files. Do not edit by "
            "hand: tool/l10n/place_names.py reads it, with app/lib/l10n/place_name_overrides.json, "
            "to generate app/lib/src/core/place_names.g.dart (make place-names)."
        ),
        "cldr": CLDR_TAG,
        "licence": documents[LICENCE],
        "countries": countries,
        "zones": zones,
    }


def render(data: dict) -> str:
    """The extract as committed: two-space JSON, keys in a stable order, a final newline."""
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--from", dest="source", type=Path, help="read the files from this folder")
    args = parser.parse_args(argv[1:])
    try:
        documents = {}
        for name in FILES:
            raw = (args.source / source_path(name)).read_bytes() if args.source else download(name)
            documents[name] = read_pinned(name, raw)
        data = extract(documents, forbidden_ranges())
    except (CldrError, OSError) as error:
        print(f"import_cldr: {error}", file=sys.stderr)
        return 1
    EXTRACT.write_text(render(data), encoding="utf-8")
    print(
        f"wrote {EXTRACT.relative_to(ROOT)}: CLDR {CLDR_TAG}, "
        f"{len(data['countries'])} countries, {len(data['zones'])} zones"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
