"""The amount lexicon and the amount vectors: checks, and the Dart tables built from the lexicon.

contracts/amount_lexicon.json (the words an amount is written with) and
contracts/amount_vectors.json (what mm_core's parseAmount and formatAmountWords must give) are
both written by hand: they are the contract. generate.py --check runs check_lexicon and
check_vectors on them, and writes packages/mm_core/lib/src/money/amount_lexicon.g.dart from the
lexicon, so mm_core never reads JSON at run time. docs/roadmap/amount-parser.md has the design.
"""

from __future__ import annotations

import json
import sys
from fractions import Fraction
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import check_unicode

ROOT = Path(__file__).resolve().parents[2]
LEXICON = ROOT / "contracts" / "amount_lexicon.json"
VECTORS = ROOT / "contracts" / "amount_vectors.json"

# numeric(14,2): the largest amount the database stores, in paisa.
MAX_PAISA = 99_999_999_999_999

SCRIPTS = ("ur", "roman", "en")
POLICIES = ("free_text", "spaced", "always")
READ_AFTER = ("fraction", "currency")
CONTEXTS = ("field", "text")
WORD_SCRIPTS = ("urdu", "roman", "english")

# The examples the plan, the roadmap issue and the investor deck promise, each of which must be
# an input in the vectors (docs/roadmap/amount-parser.md, "Done when").
PROMISED_EXAMPLES = (
    "ek lakh pachas hazar",
    "2 lakh 50 hazar",
    "pachees sau",
    "ڈیڑھ لاکھ",
    "sawa do lakh",
    "sarhe teen hazar",
    "paune do lakh",
    "ek sau pachas crore",
    "1.5 lac",
    "پچاس ہزار",
    "50k",
    "Rs. 25,000/-",
    "dedh lakh",
    "pachas hazar",
    "پچیس ہزار روپے",
)


class ContractError(ValueError):
    """A hand-written contract file breaks its own rules."""


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def code_point(text: str) -> int:
    return check_unicode.code_point(text)


# --- normalisation, as the lexicon states it -----------------------------------------------


def _digit(ch: str) -> str:
    cp = ord(ch)
    for zero in (0x0660, 0x06F0, 0xFF10):
        if zero <= cp <= zero + 9:
            return chr(0x30 + cp - zero)
    return ch


def normaliser(lexicon: dict):
    """A function applying the lexicon's normalise rules to a string."""
    rules = lexicon["normalise"]
    removed = [(code_point(r["from"]), code_point(r["to"])) for r in rules["remove"]]
    folds = {
        code_point(f["from"]): "".join(chr(code_point(p)) for p in f["to"].split())
        for f in rules["fold"]
    }

    def normalise(text: str) -> str:
        out = []
        for ch in text:
            cp = ord(ch)
            if any(low <= cp <= high for low, high in removed):
                continue
            ch = folds.get(cp, _digit(ch))
            out.append(ch.lower() if ch.isascii() else ch)
        return "".join(out)

    return normalise


# --- the lexicon -----------------------------------------------------------------------------


def _strings(value, where: str, *, empty: bool = True) -> list[str]:
    if not isinstance(value, list) or not all(isinstance(s, str) and s for s in value):
        raise ContractError(f"{where}: expected a list of non-empty strings")
    if not empty and not value:
        raise ContractError(f"{where}: must not be empty")
    if len(set(value)) != len(value):
        raise ContractError(f"{where}: repeats a spelling")
    return value


def _keys(obj, where: str, required: set[str], optional: set[str] = frozenset()) -> None:
    if not isinstance(obj, dict):
        raise ContractError(f"{where}: expected an object")
    missing = required - obj.keys()
    extra = obj.keys() - required - optional
    if missing or extra:
        raise ContractError(f"{where}: missing {sorted(missing)}, unexpected {sorted(extra)}")


def _write(obj, where: str, spellings: dict[str, list[str]]) -> None:
    _keys(obj, where, set(SCRIPTS))
    for script in SCRIPTS:
        _keys(obj[script], f"{where}.{script}", {"one", "other"})
        for count in ("one", "other"):
            if obj[script][count] not in spellings[script]:
                raise ContractError(
                    f"{where}.{script}.{count}: {obj[script][count]!r} is not one of the "
                    f"section's {script} spellings"
                )


def meanings(lexicon: dict) -> dict[str, tuple[str, int, bool]]:
    """Every spelling and what it means: (kind, value, English), checking each has one meaning.

    The kinds are number (value 0 to 99), fraction (value: its index in fractions), multiplier
    and plural (value: the power of ten), currency, paisa, foreign, filler and connector.
    """
    found: dict[str, tuple[str, int, bool]] = {}
    owner: dict[str, str] = {}

    def add(spelling: str, kind: str, value: int, english: bool, entry: str) -> None:
        meaning = (kind, value)
        if spelling in found and found[spelling][:2] != meaning:
            raise ContractError(f"{spelling!r} means both {owner[spelling]} and {entry}")
        previous = found.get(spelling, (kind, value, False))
        found[spelling] = (kind, value, previous[2] or english)
        owner[spelling] = entry

    for number in lexicon["numbers"]:
        for script in SCRIPTS:
            for s in number[script]:
                add(s, "number", number["value"], script == "en", f"number {number['value']}")
    for index, fraction in enumerate(lexicon["fractions"]):
        for script in SCRIPTS:
            for s in fraction[script]:
                add(s, "fraction", index, script == "en", f"fraction {fraction['id']}")
    for m in lexicon["multipliers"]:
        for script in SCRIPTS:
            for s in m[script]:
                add(s, "multiplier", m["power"], script == "en", f"10^{m['power']}")
        for s in m["plural"]:
            add(s, "plural", m["power"], False, f"10^{m['power']} (plural)")
    for section, kind, scripts in (
        ("currency", "currency", ("ur", "roman", "en", "symbols", "suffixes")),
        ("paisa", "paisa", SCRIPTS),
        ("foreign_currency", "foreign", ("ur", "latin", "symbols")),
        ("fillers", "filler", SCRIPTS),
        ("connectors", "connector", ("en",)),
    ):
        for script in scripts:
            for s in lexicon[section][script]:
                add(s, kind, 0, script == "en", section)
    return found


def check_lexicon(lexicon: dict) -> dict[str, tuple[str, int, bool]]:
    """Raises ContractError unless the lexicon keeps its own rules; returns its meanings."""
    _keys(
        lexicon,
        "lexicon",
        {
            "$comment",
            "version",
            "reviewed",
            "review",
            "sources",
            "normalise",
            "numbers",
            "fractions",
            "multipliers",
            "currency",
            "paisa",
            "foreign_currency",
            "fillers",
            "connectors",
            "ambiguous",
            "homographs",
            "not_included",
        },
    )
    if lexicon["version"] != 1 or not isinstance(lexicon["reviewed"], bool):
        raise ContractError("lexicon: version must be 1 and reviewed a boolean")
    _keys(lexicon["review"], "review", {"status", "process", "check_first"})
    if not (ROOT / lexicon["review"]["process"]).is_file():
        raise ContractError("review.process: no such file")
    if not lexicon["reviewed"] and "Not reviewed" not in lexicon["review"]["status"]:
        raise ContractError("review.status: an unreviewed lexicon must say 'Not reviewed'")
    for item in lexicon["review"]["check_first"]:
        _keys(item, "review.check_first", {"what", "why"})
    ids = [s["id"] for s in lexicon["sources"]]
    for source in lexicon["sources"]:
        _keys(source, "sources", {"id", "title", "url", "reached", "used_for"})
    if len(set(ids)) != len(ids):
        raise ContractError("sources: repeated id")

    rules = lexicon["normalise"]
    _keys(
        rules,
        "normalise",
        {
            "$comment",
            "digits",
            "lower_case",
            "remove",
            "fold",
            "spaces",
            "grouping_separators",
            "decimal_separators",
        },
    )
    for r in rules["remove"]:
        if code_point(r["from"]) > code_point(r["to"]):
            raise ContractError(f"normalise.remove: empty range {r['label']}")
    folded = [code_point(f["from"]) for f in rules["fold"]]
    if len(set(folded)) != len(folded):
        raise ContractError("normalise.fold: a code point folds twice")
    separators = [
        code_point(c["code_point"])
        for key in ("spaces", "grouping_separators", "decimal_separators")
        for c in rules[key]
    ]
    if len(set(separators)) != len(separators):
        raise ContractError("normalise: a code point is both a space and a separator")

    numbers = lexicon["numbers"]
    if [n["value"] for n in numbers] != list(range(100)):
        raise ContractError("numbers: must list 0 to 99 once each, in order")
    for n in numbers:
        _keys(n, f"number {n['value']}", {"value", *SCRIPTS}, {"note"})
        for script in SCRIPTS:
            _strings(n[script], f"number {n['value']}.{script}", empty=False)

    fraction_ids = [f["id"] for f in lexicon["fractions"]]
    if len(set(fraction_ids)) != len(fraction_ids):
        raise ContractError("fractions: repeated id")
    powers = [m["power"] for m in lexicon["multipliers"]]
    for f in lexicon["fractions"]:
        where = f"fraction {f['id']}"
        if f["kind"] == "prefix":
            _keys(f, where, {"id", "kind", "num", "den", "min_number", "alone", *SCRIPTS, "note"})
            if not (isinstance(f["min_number"], int) and f["min_number"] >= 1):
                raise ContractError(f"{where}: min_number must be a whole number from 1")
            if not isinstance(f["alone"], bool):
                raise ContractError(f"{where}: alone must be a boolean")
        elif f["kind"] == "quantity":
            _keys(f, where, {"id", "kind", "num", "den", *SCRIPTS, "note"})
            if f["num"] <= 0:
                raise ContractError(f"{where}: a quantity must be more than nothing")
        else:
            raise ContractError(f"{where}: kind must be prefix or quantity")
        if not (isinstance(f["num"], int) and isinstance(f["den"], int) and f["den"] > 0):
            raise ContractError(f"{where}: num and den must be whole numbers, den above 0")
        for power in powers:
            if (Fraction(f["num"], f["den"]) * 10**power * 100).denominator != 1:
                raise ContractError(f"{where}: does not give whole paisa on 10^{power}")
        _strings(f["ur"], f"{where}.ur", empty=False)
        _strings(f["roman"], f"{where}.roman", empty=False)
        _strings(f["en"], f"{where}.en")

    if powers != sorted(set(powers)) or any(p < 2 for p in powers):
        raise ContractError("multipliers: powers must rise, each from 2")
    for m in lexicon["multipliers"]:
        _keys(m, f"10^{m['power']}", {"power", *SCRIPTS, "plural"}, {"note"})
        for script in (*SCRIPTS, "plural"):
            _strings(m[script], f"10^{m['power']}.{script}")
        if not m["ur"]:
            raise ContractError(f"10^{m['power']}: needs an Urdu spelling")

    currency = lexicon["currency"]
    _keys(currency, "currency", {"ur", "roman", "en", "symbols", "suffixes", "write", "note"})
    for key in ("ur", "roman", "en", "symbols", "suffixes"):
        _strings(currency[key], f"currency.{key}", empty=False)
    _write(currency["write"], "currency.write", currency)
    paisa = lexicon["paisa"]
    _keys(paisa, "paisa", {*SCRIPTS, "write", "note"})
    for script in SCRIPTS:
        _strings(paisa[script], f"paisa.{script}", empty=False)
    _write(paisa["write"], "paisa.write", paisa)
    foreign = lexicon["foreign_currency"]
    _keys(foreign, "foreign_currency", {"ur", "latin", "symbols", "note"})
    for key in ("ur", "latin", "symbols"):
        _strings(foreign[key], f"foreign_currency.{key}", empty=False)
    for symbol in currency["symbols"] + foreign["symbols"]:
        if len(symbol) != 1:
            raise ContractError(f"symbol {symbol!r}: must be one character")
    _keys(lexicon["fillers"], "fillers", {*SCRIPTS, "note"})
    for script in SCRIPTS:
        _strings(lexicon["fillers"][script], f"fillers.{script}", empty=False)
    _keys(lexicon["connectors"], "connectors", {"en", "note"})
    _strings(lexicon["connectors"]["en"], "connectors.en", empty=False)

    found = meanings(lexicon)
    normalise = normaliser(lexicon)
    spaces = {chr(code_point(c["code_point"])) for c in rules["spaces"]}
    forbidden = check_unicode.load_forbidden()
    for spelling in found:
        if normalise(spelling) != spelling:
            raise ContractError(f"{spelling!r}: not in normal form (normalise changes it)")
        if any(ch in spaces for ch in spelling):
            raise ContractError(f"{spelling!r}: a spelling is one word")
        if any(check_unicode.reason_for(ord(ch), forbidden) for ch in spelling):
            raise ContractError(f"{spelling!r}: has a character the Unicode guard forbids")

    tokens = [a["token"] for a in lexicon["ambiguous"]]
    if len(set(tokens)) != len(tokens):
        raise ContractError("ambiguous: repeated token")
    for a in lexicon["ambiguous"]:
        where = f"ambiguous {a['token']!r}"
        _keys(a, where, {"token", "refuse", "why"}, {"read_after"})
        if normalise(a["token"]) != a["token"]:
            raise ContractError(f"{where}: not in normal form")
        if a["refuse"] not in POLICIES:
            raise ContractError(f"{where}: refuse must be one of {POLICIES}")
        if a["refuse"] == "always" and a["token"] in found:
            raise ContractError(f"{where}: always refused, so it must not have a meaning")
        if a["refuse"] != "always" and a["token"] not in found:
            raise ContractError(f"{where}: {a['refuse']} tokens must have a meaning")
        if "read_after" in a:
            if a["refuse"] != "free_text" or not a["read_after"]:
                raise ContractError(f"{where}: read_after is only for free_text tokens")
            if not set(a["read_after"]) <= set(READ_AFTER):
                raise ContractError(f"{where}: read_after must name {READ_AFTER}")
    for h in lexicon["homographs"]:
        _keys(h, "homographs", {"token", "why"})
        if h["token"] not in found:
            raise ContractError(f"homograph {h['token']!r}: has no meaning to confuse")
    for n in lexicon["not_included"]:
        _keys(n, "not_included", {"token", "why"})
        if n["token"] in found or n["token"] in tokens:
            raise ContractError(f"not_included {n['token']!r}: is included")
    return found


# --- the vectors -----------------------------------------------------------------------------


def check_vectors(vectors: dict, lexicon: dict) -> tuple[int, int]:
    """Raises ContractError unless the vectors keep their shape and bounds.

    Returns the number of parse and words vectors.
    """
    _keys(
        vectors,
        "vectors",
        {"$comment", "version", "lexicon_version", "max_paisa", "parse", "words"},
    )
    if vectors["version"] != 1 or vectors["lexicon_version"] != lexicon["version"]:
        raise ContractError("vectors: version must be 1 and lexicon_version the lexicon's")
    if vectors["max_paisa"] != MAX_PAISA:
        raise ContractError(f"vectors: max_paisa must be {MAX_PAISA}, numeric(14,2)'s largest")
    forbidden = check_unicode.load_forbidden()

    def clean(text: str, where: str) -> None:
        bad = check_unicode.problems_in_text(where, text, forbidden)
        if bad:
            raise ContractError("; ".join(bad))

    def paisa(value, where: str) -> None:
        if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= MAX_PAISA:
            raise ContractError(f"{where}: paisa must be a whole number from 0 to {MAX_PAISA}")

    names: set[str] = set()
    cases: set[tuple[str, str]] = set()
    for case in vectors["parse"]:
        where = f"parse {case.get('name')!r}"
        _keys(case, where, {"name", "input", "context", "expected"})
        if not isinstance(case["name"], str) or case["name"] in names:
            raise ContractError(f"{where}: names must be unique strings")
        names.add(case["name"])
        if not isinstance(case["input"], str):
            raise ContractError(f"{where}: input must be a string")
        clean(case["input"], where)
        if case["context"] not in CONTEXTS:
            raise ContractError(f"{where}: context must be one of {CONTEXTS}")
        if (case["input"], case["context"]) in cases:
            raise ContractError(f"{where}: the same input and context appear twice")
        cases.add((case["input"], case["context"]))
        if case["expected"] is not None and case["expected"] != "ambiguous":
            paisa(case["expected"], where)
    inputs = {case["input"] for case in vectors["parse"]}
    missing = [example for example in PROMISED_EXAMPLES if example not in inputs]
    if missing:
        raise ContractError(f"parse: the promised examples {missing} are not vectors")
    for context in CONTEXTS:
        outcomes = {
            "number" if isinstance(c["expected"], int) else c["expected"]
            for c in vectors["parse"]
            if c["context"] == context
        }
        if outcomes != {"number", "ambiguous", None}:
            raise ContractError(f"parse: {context} vectors must cover a number, ambiguous and null")
    bounds = {c["expected"] for c in vectors["parse"]}
    if not {0, 1, MAX_PAISA} <= bounds:
        raise ContractError("parse: zero, a paisa and the maximum must each be expected")

    pairs: set[tuple[int, str]] = set()
    for case in vectors["words"]:
        where = f"words {case.get('paisa')!r} {case.get('script')!r}"
        _keys(case, where, {"paisa", "script", "words"})
        paisa(case["paisa"], where)
        if case["script"] not in WORD_SCRIPTS:
            raise ContractError(f"{where}: script must be one of {WORD_SCRIPTS}")
        if (case["paisa"], case["script"]) in pairs:
            raise ContractError(f"{where}: appears twice")
        pairs.add((case["paisa"], case["script"]))
        if not isinstance(case["words"], str) or not case["words"]:
            raise ContractError(f"{where}: words must be a non-empty string")
        clean(case["words"], where)
    for script in WORD_SCRIPTS:
        if not {0, 1, MAX_PAISA} <= {p for p, s in pairs if s == script}:
            raise ContractError(f"words: {script} must cover zero, a paisa and the maximum")
    return len(vectors["parse"]), len(vectors["words"])


# --- the Dart tables -------------------------------------------------------------------------

KIND = {
    "number": "number",
    "fraction": "fraction",
    "multiplier": "multiplier",
    "plural": "plural",
    "currency": "currency",
    "paisa": "paisa",
    "foreign": "foreignCurrency",
    "filler": "filler",
    "connector": "connector",
}


def _dart_string(value: str) -> str:
    if "$" in value and "'" not in value and "\\" not in value:
        return "r'" + value + "'"
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def _hex(cp: int) -> str:
    return f"0x{cp:04X}"


def render_dart(lexicon: dict) -> str:
    """packages/mm_core/lib/src/money/amount_lexicon.g.dart."""
    found = check_lexicon(lexicon)
    rules = lexicon["normalise"]
    reviewed = "reviewed" if lexicon["reviewed"] else "NOT YET REVIEWED by a native speaker"
    out = [
        "// GENERATED by tool/contracts/generate.py from",
        f"// contracts/amount_lexicon.json, version {lexicon['version']},",
        f"// {reviewed}.",
        "// Do not edit by hand: edit the lexicon and run `make contracts`",
        "// (docs/roadmap/amount-parser.md).",
        "//",
        "// The words an amount is written with, read by amount_parse.dart and",
        "// amount_words.dart. Not exported.",
        "",
        "// dart format off",
        "",
        "/// The lexicon's version.",
        f"const int amountLexiconVersion = {lexicon['version']};",
        "",
        "/// Whether a native speaker has reviewed the lexicon (work item 2 of",
        "/// docs/roadmap/amount-parser.md, through docs/roadmap/urdu-review.md).",
        f"const bool amountLexiconReviewed = {'true' if lexicon['reviewed'] else 'false'};",
        "",
        "/// What a spelling is.",
        "enum AmountWordKind {",
        "  /// A number from 0 to 99; the value is the number.",
        "  number,",
        "",
        "  /// A fraction word; the value is its index in [amountFractions].",
        "  fraction,",
        "",
        "  /// A multiplier; the value is its power of ten.",
        "  multiplier,",
        "",
        "  /// A multiplier's plural, read only after a number; the value is its power.",
        "  plural,",
        "",
        "  /// A rupee marker.",
        "  currency,",
        "",
        "  /// A paisa word, read only after a rupee marker and a number at the end.",
        "  paisa,",
        "",
        "  /// Another currency: an amount next to it is never read as rupees.",
        "  foreignCurrency,",
        "",
        "  /// A word that never changes the amount ('only').",
        "  filler,",
        "",
        "  /// 'and' before the last number of a group.",
        "  connector,",
        "}",
        "",
        "/// Code points removed before matching, as inclusive ranges.",
        "const List<(int, int)> amountRemoved = [",
    ]
    for r in rules["remove"]:
        out.append(f"  // {r['label']}")
        out.append(f"  ({_hex(code_point(r['from']))}, {_hex(code_point(r['to']))}),")
    out += [
        "];",
        "",
        "/// Letters an Arabic keyboard types, to the Urdu letters they stand for.",
        "const Map<int, String> amountFolds = {",
    ]
    for f in rules["fold"]:
        target = "".join(f"\\u{{{code_point(p):04X}}}" for p in f["to"].split())
        out.append(f"  // {f['label']}")
        out.append(f"  {_hex(code_point(f['from']))}: '{target}',")
    out += ["};", ""]
    for name, key, what in (
        ("amountSpaces", "spaces", "Characters read as a space."),
        ("amountGroupingSeparators", "grouping_separators", "Digit grouping separators."),
        ("amountDecimalSeparators", "decimal_separators", "Decimal separators."),
    ):
        out.append(f"/// {what}")
        out.append(f"const Set<int> {name} = {{")
        for c in rules[key]:
            out.append(f"  // {c['label']}")
            out.append(f"  {_hex(code_point(c['code_point']))},")
        out += ["};", ""]
    out += [
        "/// Every spelling, in normal form, and what it means: its kind, its value",
        "/// and whether it is an English spelling.",
        "const Map<String, (AmountWordKind, int, bool)> amountWords = {",
    ]
    for spelling in sorted(found):
        kind, value, english = found[spelling]
        out.append(
            f"  {_dart_string(spelling)}: (AmountWordKind.{KIND[kind]}, {value}, "
            f"{'true' if english else 'false'}),"
        )
    out += [
        "};",
        "",
        "/// Tokens refused wherever they appear: reading them, or ignoring them,",
        "/// could misread the amount.",
        "const Set<String> amountRefused = {",
    ]
    for a in lexicon["ambiguous"]:
        if a["refuse"] == "always":
            out.append(f"  {_dart_string(a['token'])},")
    out += [
        "};",
        "",
        "/// Tokens read in a single amount field but refused in free text, unless",
        "/// the token before them is of one of the listed kinds.",
        "const Map<String, List<AmountWordKind>> amountFreeText = {",
    ]
    for a in lexicon["ambiguous"]:
        if a["refuse"] == "free_text":
            after = ", ".join(f"AmountWordKind.{KIND[k]}" for k in a.get("read_after", []))
            out.append(f"  {_dart_string(a['token'])}: [{after}],")
    out += [
        "};",
        "",
        "/// Tokens read in free text only when joined to the digits before them",
        "/// ('50k'), and anywhere in a single amount field.",
        "const Set<String> amountSpaced = {",
    ]
    for a in lexicon["ambiguous"]:
        if a["refuse"] == "spaced":
            out.append(f"  {_dart_string(a['token'])},")
    out += [
        "};",
        "",
        "/// The fraction words: a quantity (num/den on its own) or a prefix (num/den",
        "/// added to the number after it, from minNumber; alone: before a multiplier",
        "/// with no number, it takes one).",
        "typedef AmountFraction = ({",
        "  String id,",
        "  int num,",
        "  int den,",
        "  bool prefix,",
        "  int minNumber,",
        "  bool alone,",
        "});",
        "",
        "/// The fraction words, in the lexicon's order.",
        "const List<AmountFraction> amountFractions = [",
    ]
    for f in lexicon["fractions"]:
        prefix = f["kind"] == "prefix"
        out += [
            "  (",
            f"    id: {_dart_string(f['id'])},",
            f"    num: {f['num']},",
            f"    den: {f['den']},",
            f"    prefix: {'true' if prefix else 'false'},",
            f"    minNumber: {f.get('min_number', 0)},",
            f"    alone: {'true' if f.get('alone') else 'false'},",
            "  ),",
        ]
    out += ["];", ""]
    for script, name, label in (
        ("ur", "Urdu", "Urdu script"),
        ("roman", "Roman", "Roman Urdu"),
        ("en", "English", "English"),
    ):
        out += [
            f"/// The {label} spelling formatAmountWords writes for 0 to 99.",
            f"const List<String> amountNumbers{name} = [",
        ]
        for n in lexicon["numbers"]:
            out.append(f"  {_dart_string(n[script][0])},")
        out += [
            "];",
            "",
            f"/// The {label} spelling formatAmountWords writes for each multiplier.",
            f"const Map<int, String> amountMultipliers{name} = {{",
        ]
        for m in lexicon["multipliers"]:
            if m[script]:
                out.append(f"  {m['power']}: {_dart_string(m[script][0])},")
        out += ["};", ""]
        for section, what in (("currency", "Rupee"), ("paisa", "Paisa")):
            forms = lexicon[section]["write"][script]
            out += [
                f"/// The {label} {what.lower()} word formatAmountWords writes, for one and",
                "/// for any other count.",
                f"const ({{String one, String other}}) amount{what}{name} = (",
                f"  one: {_dart_string(forms['one'])},",
                f"  other: {_dart_string(forms['other'])},",
                ");",
                "",
            ]
    out += [
        "/// The English connector formatAmountWords writes before the last number.",
        f"const String amountConnectorEnglish = {_dart_string(lexicon['connectors']['en'][0])};",
        "",
        "// dart format on",
        "",
    ]
    return "\n".join(out)
