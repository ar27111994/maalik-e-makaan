#!/usr/bin/env python3
"""Builds the Urdu fonts the app bundles from the upstream files in design/fonts/.

    python3 tool/design/build_fonts.py           # write the fonts
    python3 tool/design/build_fonts.py --check   # verify the committed fonts are current

Every font the app bundles is in every install, and Flutter on the web downloads all of them
before it starts the app, so the app ships only what it sets (D-19):

- Noto Sans Arabic, the Urdu interface face, at its normal width. The upstream variable font has
  a width axis (62.5 to 100) beside the weight axis, and the app sets Urdu at width 100 only. The
  width axis is removed (the font is instanced at 100) and every glyph and the weight axis are
  kept, so any Arabic-script letter a landlord types still has its glyph and every weight the
  type scale names is there: about 845 KB becomes about 495 KB.
- Noto Nastaliq Urdu, which sets only the brand name where it is the wordmark: cut to the
  letters of the app's Urdu name (`appName` in app/lib/l10n/arb/app_ur.arb), with every glyph
  and feature their shaping reaches and the weight axis: about 690 KB becomes about 54 KB.

Both stay under the SIL Open Font License 1.1, which allows modified and subset versions; neither
font names a Reserved Font Name. The name tables, with the copyright, the licence and its URL,
are kept whole.

Sources (verbatim upstream files, checked by SHA-256 so a changed source is noticed):
  design/fonts/NotoSansArabic-wdth-wght.ttf  Noto Sans Arabic 2.012, from google/fonts:
                                             ofl/notosansarabic/NotoSansArabic[wdth,wght].ttf
  design/fonts/NotoNastaliqUrdu-wght.ttf     Noto Nastaliq Urdu 3.009, the variable font the app
                                             bundled whole until D-19

Outputs (committed; the website, the deck and the Open Graph cards subset these again):
  packages/mm_ui/assets/fonts/NotoSansArabic-Variable.ttf
  packages/mm_ui/assets/fonts/NotoNastaliqUrdu-Wordmark.ttf
"""

from __future__ import annotations

import hashlib
import io
import json
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "design" / "fonts"
OUTPUTS = ROOT / "packages" / "mm_ui" / "assets" / "fonts"
URDU_ARB = ROOT / "app" / "lib" / "l10n" / "arb" / "app_ur.arb"

# The name table records the OFL asks every copy to keep: copyright (0), licence (13) and
# licence URL (14).
LICENCE_NAME_IDS = (0, 13, 14)


@dataclass(frozen=True)
class Font:
    """One bundled font: its upstream source and how the app's copy is cut from it."""

    source: str
    sha256: str
    output: str
    #: Axes removed from the variable font, each fixed at one value.
    pin: dict[str, float]
    #: Whether the font is cut to the letters of the app's Urdu name.
    wordmark: bool


FONTS = (
    Font(
        source="NotoSansArabic-wdth-wght.ttf",
        sha256="63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e",
        output="NotoSansArabic-Variable.ttf",
        pin={"wdth": 100},
        wordmark=False,
    ),
    Font(
        source="NotoNastaliqUrdu-wght.ttf",
        sha256="98a4787f34eb6fde57fb9a1121a8f216301196ab0da98ea110cad581be8abbcd",
        output="NotoNastaliqUrdu-Wordmark.ttf",
        pin={},
        wordmark=True,
    ),
)


class FontError(ValueError):
    """A source font or the app's name is unusable."""


def shown(path: Path) -> str:
    """[path] as messages show it: from the repository's root when it is inside it."""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def wordmark_text(arb: Path | None = None) -> str:
    """The app's Urdu name, which the Nastaliq wordmark sets (MmPage.wordmark)."""
    name = json.loads((arb or URDU_ARB).read_text(encoding="utf-8")).get("appName")
    if not isinstance(name, str) or not name.strip():
        raise FontError("app_ur.arb has no appName")
    return name


def check_source(font: Font, sources: Path | None = None) -> bytes:
    """The source font's bytes, once they are the upstream file named in [font]."""
    path = (sources or SOURCES) / font.source
    if not path.exists():
        raise FontError(f"{shown(path)} is missing")
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != font.sha256:
        raise FontError(
            f"{shown(path)} is not the upstream file (SHA-256 {digest}); "
            "replace it, or record the new file's SHA-256 in tool/design/build_fonts.py"
        )
    return data


def build(font: Font, data: bytes, text: str) -> bytes:
    """The app's copy of [font], cut from the source bytes [data]."""
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    ttf = TTFont(io.BytesIO(data), recalcTimestamp=False)
    axes = {axis.axisTag for axis in ttf["fvar"].axes}
    for tag in font.pin:
        if tag not in axes:
            raise FontError(f"{font.source} has no {tag} axis to pin")
    if font.pin:
        ttf = instancer.instantiateVariableFont(ttf, dict(font.pin))
    if font.wordmark:
        missing = [char for char in text if ord(char) not in ttf.getBestCmap()]
        if missing:
            raise FontError(f"{font.source} has no glyph for {missing!r}")
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.name_languages = ["*"]
        options.notdef_outline = True
        options.glyph_names = False
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(text=text)
        subsetter.subset(ttf)
    kept = {record.nameID for record in ttf["name"].names}
    lost = [name_id for name_id in LICENCE_NAME_IDS if name_id not in kept]
    if lost:
        raise FontError(f"{font.output} would lose its licence name records {lost}")
    out = io.BytesIO()
    ttf.save(out)
    return out.getvalue()


def main(argv: list[str]) -> int:
    check = argv == ["--check"]
    if argv and not check:
        print("usage: tool/design/build_fonts.py [--check]", file=sys.stderr)
        return 2
    try:
        text = wordmark_text()
        built = {font.output: build(font, check_source(font), text) for font in FONTS}
    except (FontError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if check:
        stale = [
            name
            for name, data in built.items()
            if not (OUTPUTS / name).exists() or (OUTPUTS / name).read_bytes() != data
        ]
        for name in stale:
            print(f"{shown(OUTPUTS / name)} is stale", file=sys.stderr)
        if stale:
            print("Run tool/design/build_fonts.py to rebuild the fonts.", file=sys.stderr)
            return 1
        return 0

    OUTPUTS.mkdir(parents=True, exist_ok=True)
    for name, data in built.items():
        (OUTPUTS / name).write_bytes(data)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
