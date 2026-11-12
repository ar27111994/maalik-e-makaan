#!/usr/bin/env python3
"""Builds the design-token outputs from design/tokens/maalik.tokens.json (DTCG 2025.10).

    python3 tool/design/build_tokens.py           # validate and write the outputs
    python3 tool/design/build_tokens.py --check   # validate; exit 1 if an output is stale

Validation fails the build when the tokens are malformed, when a colour's
components disagree with its hex, when the four colour modes do not define the
same roles, or when a colour pairing the UI relies on misses its WCAG 2.2
contrast minimum (AA in the standard modes; 7:1 for text and 4.5:1 for
non-text in the high-contrast modes).

Outputs (all committed):
  packages/mm_ui/lib/src/tokens/mm_tokens.g.dart  Flutter constants
  design/tokens/maalik.tokens.css                 CSS custom properties for the website
  DESIGN.md (frontmatter only)                    the agent-facing design context: its YAML
                                                  tokens are written from the tokens file and
                                                  its markdown body is kept as written
  supabase/functions/_shared/email_typography.g.ts
                                                  the e-mails' Urdu type, for the invitation
  supabase/templates/*.html (Urdu type only)      the Auth e-mails: the font-family, font-size
                                                  and line-height of their Urdu elements are
                                                  written from the tokens, everything else is
                                                  kept

DESIGN.md's component recipes are linted here the way the Stitch CLI
(@google/design.md) lints them: every {reference} must resolve, and every
component pairing text with a background must reach 4.5:1.

The e-mails' Urdu type follows D-19: Urdu text in the Urdu stack, with installed sans faces
added for e-mail (EMAIL_URDU_FALLBACKS), at the size and on the whole-pixel line of an Urdu type
role (a template names it with data-mm-type), and Nastaliq for the brand name only where it
stands as the wordmark. A template whose Urdu is set in anything else is stale, so `--check`
fails.
"""

from __future__ import annotations

import json
import re
import sys
from decimal import ROUND_CEILING, Decimal
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "design" / "tokens" / "maalik.tokens.json"
DART_OUT = ROOT / "packages" / "mm_ui" / "lib" / "src" / "tokens" / "mm_tokens.g.dart"
CSS_OUT = ROOT / "design" / "tokens" / "maalik.tokens.css"
DESIGN_MD = ROOT / "DESIGN.md"
EMAIL_TS_OUT = ROOT / "supabase" / "functions" / "_shared" / "email_typography.g.ts"
EMAIL_TEMPLATES = ROOT / "supabase" / "templates"
URDU_ARB = ROOT / "app" / "lib" / "l10n" / "arb" / "app_ur.arb"

COLOR_MODES = ("light", "dark", "lightHighContrast", "darkHighContrast")
HIGH_CONTRAST_MODES = {"lightHighContrast", "darkHighContrast"}

# (foreground, background, AA minimum, what the pairing is used for).
CONTRAST_PAIRS = [
    ("ink", "bg", 4.5, "body text on the page"),
    ("ink", "surface", 4.5, "body text on cards"),
    ("ink", "surfaceSunken", 4.5, "text on sunken surfaces"),
    ("inkMuted", "bg", 4.5, "secondary text on the page"),
    ("inkMuted", "surface", 4.5, "secondary text on cards"),
    ("outline", "surface", 3.0, "field and control borders"),
    ("outline", "bg", 3.0, "control borders on the page"),
    ("primary", "surface", 4.5, "primary text and links on cards"),
    ("primary", "bg", 4.5, "primary text on the page"),
    ("onPrimary", "primary", 4.5, "labels on filled buttons"),
    ("onPrimaryContainer", "primaryContainer", 4.5, "text on primary containers"),
    ("brass", "surface", 3.0, "brass marks and icons"),
    ("brassText", "surface", 4.5, "brass-coloured text"),
    ("onBrassContainer", "brassContainer", 4.5, "text on brass containers"),
    ("paid", "surface", 4.5, "paid status text"),
    ("onPaidContainer", "paidContainer", 4.5, "paid chip text"),
    ("overdue", "surface", 4.5, "overdue status text"),
    ("onOverdueContainer", "overdueContainer", 4.5, "overdue chip text"),
    ("dueSoon", "surface", 4.5, "due-soon status text"),
    ("onDueSoonContainer", "dueSoonContainer", 4.5, "due-soon chip text"),
    ("credit", "surface", 4.5, "credit status text"),
    ("onCreditContainer", "creditContainer", 4.5, "credit chip text"),
    ("focus", "surface", 3.0, "focus ring on cards"),
    ("focus", "bg", 3.0, "focus ring on the page"),
    ("focus", "surfaceSunken", 3.0, "focus ring on sunken wells"),
    ("inkMuted", "surfaceSunken", 4.5, "labels of disabled filled controls"),
]

# Font families as the mm_ui package declares them in pubspec.yaml.
FLUTTER_FAMILIES = {
    "Atkinson Hyperlegible Next": "AtkinsonHyperlegibleNext",
    "Noto Sans Arabic": "NotoSansArabic",
    "Noto Nastaliq Urdu": "NotoNastaliqUrdu",
}


class TokenError(ValueError):
    """The token file is malformed or violates a design rule."""


# --- colour maths --------------------------------------------------------------------


def _channel(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_: str) -> float:
    r, g, b = (int(hex_[i : i + 2], 16) / 255 for i in (1, 3, 5))
    return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b)


def contrast_ratio(a: str, b: str) -> float:
    la, lb = relative_luminance(a), relative_luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


# --- reading and validation ----------------------------------------------------------


def _tokens(group: dict) -> dict[str, dict]:
    return {key: value for key, value in group.items() if not key.startswith("$")}


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise TokenError(message)


def color_hex(token: dict, where: str) -> str:
    value = token.get("$value")
    _require(isinstance(value, dict), f"{where}: colour $value must be an object")
    _require(value.get("colorSpace") == "srgb", f"{where}: only srgb colours are supported")
    hex_ = value.get("hex", "")
    _require(
        isinstance(hex_, str) and len(hex_) == 7 and hex_.startswith("#"),
        f"{where}: hex must be #RRGGBB",
    )
    try:
        channels = [int(hex_[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    except ValueError:
        raise TokenError(f"{where}: hex must be #RRGGBB") from None
    components = value.get("components")
    _require(
        isinstance(components, list)
        and len(components) == 3
        and all(isinstance(c, (int, float)) for c in components),
        f"{where}: components must be three numbers",
    )
    _require(
        all(abs(c - h) <= 0.5 / 255 + 1e-6 for c, h in zip(components, channels, strict=True)),
        f"{where}: components {components} disagree with {hex_}",
    )
    _require(value.get("alpha", 1) == 1, f"{where}: colours must be opaque")
    return hex_.upper()


def dimension(token: dict, where: str) -> float:
    value = token.get("$value")
    _require(
        isinstance(value, dict)
        and value.get("unit") == "px"
        and isinstance(value.get("value"), (int, float)),
        f"{where}: dimension $value must be {{value, unit: px}}",
    )
    return value["value"]


def duration_ms(token: dict, where: str) -> int:
    value = token.get("$value")
    _require(
        isinstance(value, dict)
        and value.get("unit") == "ms"
        and isinstance(value.get("value"), int),
        f"{where}: duration $value must be {{value, unit: ms}}",
    )
    return value["value"]


def load(path: Path | None = None) -> dict:
    """Reads and validates the token file (default: SOURCE); returns the normalised model."""
    path = SOURCE if path is None else path
    raw = json.loads(path.read_text(encoding="utf-8"))
    colors = raw.get("color", {})
    modes = {}
    for mode in COLOR_MODES:
        _require(mode in colors, f"color.{mode} is missing")
        modes[mode] = {
            name: (color_hex(token, f"color.{mode}.{name}"), token.get("$description", ""))
            for name, token in _tokens(colors[mode]).items()
        }
    roles = list(modes["light"])
    for mode in COLOR_MODES[1:]:
        _require(
            list(modes[mode]) == roles,
            f"color.{mode} must define the same roles as color.light, in order",
        )

    for mode, palette in modes.items():
        for fg, bg, minimum, why in CONTRAST_PAIRS:
            _require(fg in palette and bg in palette, f"color.{mode}: missing {fg} or {bg}")
            need = minimum if mode not in HIGH_CONTRAST_MODES else (7.0 if minimum == 4.5 else 4.5)
            ratio = contrast_ratio(palette[fg][0], palette[bg][0])
            _require(
                ratio + 1e-9 >= need,
                f"color.{mode}: {fg} on {bg} ({why}) is {ratio:.2f}:1, needs {need}:1",
            )

    def dims(group: str) -> dict[str, tuple[float, str]]:
        return {
            name: (dimension(token, f"{group}.{name}"), token.get("$description", ""))
            for name, token in _tokens(raw[group]).items()
        }

    families = {name: token["$value"] for name, token in _tokens(raw["font"]["family"]).items()}
    for name, stack in families.items():
        _require(
            isinstance(stack, list) and stack and stack[0] in FLUTTER_FAMILIES,
            f"font.family.{name}: the first family must be one mm_ui bundles",
        )

    typography = {}
    for script, styles in _tokens(raw["typography"]).items():
        for role, token in _tokens(styles).items():
            value = token["$value"]
            where = f"typography.{script}.{role}"
            family_ref = value.get("fontFamily", "")
            _require(
                family_ref.startswith("{font.family.") and family_ref.endswith("}"),
                f"{where}: fontFamily must reference a font.family token",
            )
            family = family_ref[len("{font.family.") : -1]
            _require(family in families, f"{where}: unknown family {family}")
            size = value["fontSize"]["value"]
            weight = value["fontWeight"]
            _require(
                weight in (100, 200, 300, 400, 500, 600, 700, 800, 900),
                f"{where}: fontWeight must be a multiple of 100",
            )
            _require(size >= 12, f"{where}: text smaller than 12 px is not allowed")
            typography[(script, role)] = {
                "family": family,
                "size": size,
                "weight": weight,
                "height": value["lineHeight"],
                "tracking": value["letterSpacing"]["value"],
            }

    durations = {
        name: (duration_ms(token, f"duration.{name}"), token.get("$description", ""))
        for name, token in _tokens(raw["duration"]).items()
    }
    easings = {}
    for name, token in _tokens(raw["easing"]).items():
        value = token["$value"]
        _require(
            isinstance(value, list) and len(value) == 4, f"easing.{name}: must be four numbers"
        )
        easings[name] = value

    return {
        "modes": modes,
        "space": dims("space"),
        "radius": dims("radius"),
        "size": dims("size"),
        "breakpoint": dims("breakpoint"),
        "duration": durations,
        "easing": easings,
        "families": families,
        "typography": typography,
    }


# --- rendering -----------------------------------------------------------------------


def _num(value: float) -> str:
    return str(int(value)) if float(value).is_integer() else repr(float(value))


def _doc(description: str, indent: str) -> list[str]:
    if not description:
        return []
    return [f"{indent}/// {description}"]


def _members(members: list[list[str]]) -> list[str]:
    """Class members as dart format lays them out: a documented member after
    the first is preceded by a blank line."""
    lines: list[str] = []
    for index, member in enumerate(members):
        if index > 0 and member and member[0].lstrip().startswith("///"):
            lines.append("")
        lines.extend(member)
    return lines


def render_dart(model: dict) -> str:
    out = [
        "// GENERATED by tool/design/build_tokens.py from design/tokens/maalik.tokens.json.",
        "// Do not edit by hand: change the tokens and run `make tokens`.",
        "",
        "import 'package:flutter/animation.dart';",
        "import 'package:flutter/foundation.dart';",
        "import 'package:flutter/painting.dart';",
        "",
        "/// The colour roles of one theme mode.",
        "@immutable",
        "final class MmColorTokens {",
        "  /// Creates a set of colour roles.",
        "  const MmColorTokens({",
    ]
    roles = list(model["modes"]["light"])
    out += [f"    required this.{role}," for role in roles]
    out += ["  });", ""]
    out += _members(
        [
            [*_doc(model["modes"]["light"][role][1], "  "), f"  final Color {role};"]
            for role in roles
        ]
    )
    out += [
        "}",
        "",
        "/// The four colour modes; every pairing the UI uses is contrast-checked at build time.",
        "abstract final class MmColorModes {",
    ]
    labels = {
        "light": "Light mode.",
        "dark": "Dark mode.",
        "lightHighContrast": "Light high-contrast mode (7:1 text).",
        "darkHighContrast": "Dark high-contrast mode (7:1 text).",
    }
    out += _members(
        [
            [f"  /// {labels[mode]}", f"  static const MmColorTokens {mode} = MmColorTokens("]
            + [f"    {role}: Color(0xFF{hex_[1:]})," for role, (hex_, _) in palette.items()]
            + ["  );"]
            for mode, palette in model["modes"].items()
        ]
    )
    out.append("}")

    def numbers(cls: str, doc: str, group: str) -> None:
        out.extend(["", f"/// {doc}", f"abstract final class {cls} {{"])
        out.extend(
            _members(
                [
                    [*_doc(description, "  "), f"  static const double {name} = {_num(value)};"]
                    for name, (value, description) in model[group].items()
                ]
            )
        )
        out.append("}")

    numbers("MmSpace", "Spacing on the 4 dp grid.", "space")
    numbers("MmRadius", "Corner radii.", "radius")
    numbers("MmSize", "Fixed sizes: touch targets, controls, icons.", "size")
    numbers("MmBreakpoint", "Window widths where the layout changes.", "breakpoint")

    out += [
        "",
        "/// Motion durations (zero when the platform asks for reduced motion).",
        "abstract final class MmDuration {",
    ]
    out += _members(
        [
            [
                *_doc(description, "  "),
                f"  static const Duration {name} = Duration(milliseconds: {ms});",
            ]
            for name, (ms, description) in model["duration"].items()
        ]
    )
    out += ["}", "", "/// Easing curves.", "abstract final class MmEasing {"]
    out += _members(
        [
            [
                f"  /// The {name} curve.",
                f"  static const Cubic {name} = Cubic({_num(x1)}, {_num(y1)}, {_num(x2)}, {_num(y2)});",
            ]
            for name, (x1, y1, x2, y2) in model["easing"].items()
        ]
    )
    out += [
        "}",
        "",
        "/// Font families bundled with mm_ui (pass `package: 'mm_ui'`).",
        "abstract final class MmFontFamily {",
    ]
    out += _members(
        [
            [
                f"  /// {stack[0]}.",
                f"  static const String {name} = '{FLUTTER_FAMILIES[stack[0]]}';",
            ]
            for name, stack in model["families"].items()
        ]
    )
    out += [
        "}",
        "",
        "/// Text styles of each script: Atkinson Hyperlegible Next for English,",
        "/// Noto Sans Arabic for Urdu, and Noto Nastaliq Urdu for the Urdu wordmark",
        "/// only.",
        "abstract final class MmTypeScale {",
    ]
    styles = []
    for (script, role), style in model["typography"].items():
        name = f"{script}{role[0].upper()}{role[1:]}"
        family = FLUTTER_FAMILIES[model["families"][style["family"]][0]]
        styles.append(
            [
                f"  /// {script.capitalize()} {role}: {_num(style['size'])} px on a {_num(round(style['size'] * style['height'], 2))} px line.",
                f"  static const TextStyle {name} = TextStyle(",
                f"    fontFamily: '{family}',",
                "    package: 'mm_ui',",
                f"    fontSize: {_num(style['size'])},",
                f"    height: {_num(style['height'])},",
                f"    fontWeight: FontWeight.w{style['weight']},",
                f"    letterSpacing: {_num(style['tracking'])},",
                "  );",
            ]
        )
    out += _members(styles)
    out.append("}")
    return "\n".join(out) + "\n"


def _kebab(name: str) -> str:
    return "".join("-" + c.lower() if c.isupper() else c for c in name)


# CSS generic font families (CSS Fonts Level 4). A stack ends with one of them.
CSS_GENERIC_FAMILIES = frozenset(
    {
        "serif",
        "sans-serif",
        "monospace",
        "cursive",
        "fantasy",
        "system-ui",
        "ui-serif",
        "ui-sans-serif",
        "ui-monospace",
        "ui-rounded",
        "math",
        "emoji",
        "fangsong",
    }
)


def latin_urdu_stack(families: dict) -> list[str]:
    """The stack for text that mixes Latin figures with Urdu words, such as an amount and روپے.

    Every named face of the Latin stack, then of the Urdu stack, then the Latin stack's generic
    family. Writing the two stacks one after the other would put the Latin generic family (a
    system font, which usually has Urdu letters) before the Urdu face, so the Urdu words would
    be drawn in whatever font the device has.
    """
    latin, urdu = families["latin"], families["urdu"]
    named = [f for f in [*latin, *urdu] if f not in CSS_GENERIC_FAMILIES]
    generic = [f for f in latin if f in CSS_GENERIC_FAMILIES]
    _require(generic != [], "font.family.latin must end with a generic family")
    return list(dict.fromkeys(named)) + generic


def _css_stack(stack: list[str]) -> str:
    return ", ".join(f'"{f}"' if " " in f else f for f in stack)


def render_css(model: dict) -> str:
    def colors(mode: str, indent: str) -> list[str]:
        return [
            f"{indent}--mm-color-{_kebab(role)}: {hex_};"
            for role, (hex_, _) in model["modes"][mode].items()
        ]

    out = [
        "/* GENERATED by tool/design/build_tokens.py from design/tokens/maalik.tokens.json. */",
        "/* Do not edit by hand: change the tokens and run `make tokens`. */",
        "",
        ":root {",
        "  color-scheme: light dark;",
    ]
    for group in ("space", "radius", "size", "breakpoint"):
        out += [
            f"  --mm-{group}-{_kebab(name)}: {_num(value)}px;"
            for name, (value, _) in model[group].items()
        ]
    out += [f"  --mm-duration-{name}: {ms}ms;" for name, (ms, _) in model["duration"].items()]
    out += [
        f"  --mm-easing-{name}: cubic-bezier({', '.join(_num(v) for v in value)});"
        for name, value in model["easing"].items()
    ]
    out += [
        f"  --mm-font-{_kebab(name)}: {_css_stack(stack)};"
        for name, stack in model["families"].items()
    ]
    out.append(f"  --mm-font-latin-urdu: {_css_stack(latin_urdu_stack(model['families']))};")
    out += [*colors("light", "  "), "}", ""]
    out += [
        "@media (prefers-color-scheme: dark) {",
        "  :root:not([data-theme]) {",
        *colors("dark", "    "),
        "  }",
        "}",
        "",
    ]
    out += ['[data-theme="dark"] {', *colors("dark", "  "), "}", ""]
    out += [
        "@media (prefers-contrast: more) {",
        "  :root:not([data-theme]) {",
        *colors("lightHighContrast", "    "),
        "  }",
        "}",
        "",
    ]
    out += [
        "@media (prefers-contrast: more) and (prefers-color-scheme: dark) {",
        "  :root:not([data-theme]) {",
    ]
    out += [*colors("darkHighContrast", "    "), "  }", "}", ""]
    out += ["@media (prefers-reduced-motion: reduce) {", "  :root {"]
    out += [f"    --mm-duration-{name}: 0ms;" for name in model["duration"]] + ["  }", "}", ""]
    return "\n".join(out)


# Component recipes for DESIGN.md (Stitch format: fixed properties, token references).
DESIGN_COMPONENTS = {
    "page": {"backgroundColor": "{colors.bg}", "textColor": "{colors.ink}"},
    "button-primary": {
        "backgroundColor": "{colors.primary}",
        "textColor": "{colors.onPrimary}",
        "typography": "{typography.label}",
        "rounded": "{rounded.sm}",
        "height": "48px",
        "padding": "16px",
    },
    "button-secondary": {
        "backgroundColor": "{colors.surface}",
        "textColor": "{colors.primary}",
        "typography": "{typography.label}",
        "rounded": "{rounded.sm}",
        "height": "48px",
        "padding": "16px",
    },
    "card": {
        "backgroundColor": "{colors.surface}",
        "textColor": "{colors.ink}",
        "rounded": "{rounded.md}",
        "padding": "16px",
    },
    "field": {
        "backgroundColor": "{colors.surface}",
        "textColor": "{colors.ink}",
        "typography": "{typography.body}",
        "rounded": "{rounded.sm}",
        "height": "56px",
    },
    "caption": {
        "backgroundColor": "{colors.surface}",
        "textColor": "{colors.inkMuted}",
        "typography": "{typography.caption}",
    },
    "chip-paid": {
        "backgroundColor": "{colors.paidContainer}",
        "textColor": "{colors.onPaidContainer}",
        "typography": "{typography.label}",
        "rounded": "{rounded.xs}",
    },
    "chip-overdue": {
        "backgroundColor": "{colors.overdueContainer}",
        "textColor": "{colors.onOverdueContainer}",
        "typography": "{typography.label}",
        "rounded": "{rounded.xs}",
    },
    "chip-due-soon": {
        "backgroundColor": "{colors.dueSoonContainer}",
        "textColor": "{colors.onDueSoonContainer}",
        "typography": "{typography.label}",
        "rounded": "{rounded.xs}",
    },
    "chip-credit": {
        "backgroundColor": "{colors.creditContainer}",
        "textColor": "{colors.onCreditContainer}",
        "typography": "{typography.label}",
        "rounded": "{rounded.xs}",
    },
    "nameplate": {
        "backgroundColor": "{colors.brassContainer}",
        "textColor": "{colors.onBrassContainer}",
        "typography": "{typography.title}",
        "rounded": "{rounded.xs}",
        "padding": "12px",
    },
    "amount": {
        "backgroundColor": "{colors.surface}",
        "textColor": "{colors.ink}",
        "typography": "{typography.amount}",
    },
}

DESIGN_DESCRIPTION = (
    "A raseed book made trustworthy on a phone: carbon-copy cobalt ink on cool white paper, "
    "a brass nameplate for what deserves honour, Atkinson Hyperlegible Next and Noto Sans Arabic, "
    "with the Urdu wordmark in Noto Nastaliq Urdu."
)


def _px(value: float) -> str:
    return f"{_num(value)}px"


def design_groups(model: dict) -> dict[str, dict[str, object]]:
    """The DESIGN.md token groups, keyed the way component references name them."""
    typography = {}
    for (script, role), style in model["typography"].items():
        typography[role if script == "latin" else f"urdu-{_kebab(role)}"] = style
    return {
        "colors": {role: hex_ for role, (hex_, _) in model["modes"]["light"].items()},
        "typography": typography,
        "rounded": {name: value for name, (value, _) in model["radius"].items()},
        "spacing": {name: value for name, (value, _) in model["space"].items()},
    }


def lint_design_components(model: dict) -> None:
    """Every {reference} resolves; text on a background reaches 4.5:1."""
    groups = design_groups(model)
    for component, properties in DESIGN_COMPONENTS.items():
        resolved = {}
        for key, value in properties.items():
            if value.startswith("{"):
                _require(
                    value.endswith("}"),
                    f"DESIGN.md components.{component}.{key}: malformed reference",
                )
                group, _, name = value[1:-1].partition(".")
                _require(
                    group in groups and name in groups[group],
                    f"DESIGN.md components.{component}.{key}: broken reference {value}",
                )
                resolved[key] = groups[group][name]
        if "textColor" in resolved and "backgroundColor" in resolved:
            ratio = contrast_ratio(resolved["textColor"], resolved["backgroundColor"])
            _require(
                ratio >= 4.5,
                f"DESIGN.md components.{component}: text contrast {ratio:.2f}:1 is below 4.5:1",
            )


def render_design_frontmatter(model: dict) -> str:
    groups = design_groups(model)
    lines = ["---", "name: Maalik-e-Makaan", f'description: "{DESIGN_DESCRIPTION}"', "colors:"]
    lines += [f'  {role}: "{hex_}"' for role, hex_ in groups["colors"].items()]
    lines.append("typography:")
    for name, style in groups["typography"].items():
        family = model["families"][style["family"]][0]
        lines += [
            f"  {name}:",
            f"    fontFamily: {family}",
            f"    fontSize: {_px(style['size'])}",
            f"    fontWeight: {style['weight']}",
            f"    lineHeight: {_num(style['height'])}",
            f"    letterSpacing: {_px(style['tracking'])}",
        ]
    lines.append("rounded:")
    lines += [f"  {name}: {_px(value)}" for name, value in groups["rounded"].items()]
    lines.append("spacing:")
    lines += [f"  {name}: {_px(value)}" for name, value in groups["spacing"].items()]
    lines.append("components:")
    for component, properties in DESIGN_COMPONENTS.items():
        lines.append(f"  {component}:")
        lines += [f'    {key}: "{value}"' for key, value in properties.items()]
    lines.append("---")
    return "\n".join(lines) + "\n"


def render_design_md(model: dict, current: str) -> str:
    """DESIGN.md with its frontmatter regenerated and its body kept."""
    if not current.startswith("---\n"):
        raise TokenError("DESIGN.md must start with a YAML frontmatter block")
    end = current.find("\n---\n", 3)
    if end < 0:
        raise TokenError("DESIGN.md frontmatter is not closed")
    lint_design_components(model)
    return render_design_frontmatter(model) + current[end + len("\n---\n") :]


# --- e-mail --------------------------------------------------------------------------

# Installed faces with Urdu letters that the e-mails name after the Urdu stack's own faces and
# before its generic family. Gmail and Outlook load no web font (caniemail.com, @font-face), so
# an e-mail's Urdu is drawn in a font the reader already has:
# - Windows: Segoe UI and Tahoma, already in the Urdu stack (Firefox's own Arabic-script
#   sans-serif on Windows is "Segoe UI, Tahoma, Arial": modules/libpref/init/all.js).
# - Apple: Geeza Pro, Apple's Arabic-script sans, a system font on iOS and macOS
#   (developer.apple.com/fonts/system-fonts) and the Arabic-script sans-serif Firefox names on
#   both. Tahoma is only a download on iOS, and Apple also ships Noto Nastaliq Urdu as a system
#   font, so a stack that reached only the generic family could be drawn in Nastaliq there.
# - Android: nothing to name. Its Arabic-script faces (Noto Naskh Arabic and its UI cut) are
#   fallbacks without a family name (data/fonts/fonts.xml), reached through the generic family.
EMAIL_URDU_FALLBACKS = ("Geeza Pro",)

# Names of Nastaliq faces, matched in lower case. D-19 keeps Nastaliq for the wordmark only.
NASTALIQ_MARKERS = ("nastaliq", "nastaleeq", "urdu typesetting", "gulzar")

VOID_ELEMENTS = frozenset(
    {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "wbr"}
)
FONT_ELEMENTS = frozenset({"font", "basefont"})
FONT_ATTRIBUTES = frozenset({"face", "font-family"})
ARABIC_SCRIPT = re.compile(r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]")
STYLE_ATTRIBUTE = re.compile(r'(\sstyle=")([^"]*)(")')
ANY_STYLE_ATTRIBUTE = re.compile(r"\sstyle\s*=", re.IGNORECASE)
FONT_SHORTHAND = re.compile(r"(?<![-\w])font\s*:", re.IGNORECASE)


def _declaration(name: str) -> re.Pattern[str]:
    """A declaration's value in a style attribute (group 2), after its name and colon (group 1)."""
    return re.compile(rf"(?<![-\w])({name}\s*:\s*)([^;]*?)(\s*(?:;|$))", re.IGNORECASE)


FONT_FAMILY = _declaration("font-family")
FONT_SIZE = _declaration("font-size")
LINE_HEIGHT = _declaration("line-height")

# The attribute that names an Urdu element's type role in a template (data-mm-type="body"); the
# build writes that role's size and line height into the element's style.
EMAIL_ROLE_ATTRIBUTE = "data-mm-type"


def is_nastaliq(family: str) -> bool:
    lowered = family.lower()
    return any(marker in lowered for marker in NASTALIQ_MARKERS)


def _split_generic(stack: list[str], where: str) -> tuple[list[str], list[str]]:
    """The stack's named faces and its generic family, which must come last."""
    named = [f for f in stack if f not in CSS_GENERIC_FAMILIES]
    generic = [f for f in stack if f in CSS_GENERIC_FAMILIES]
    _require(
        len(generic) == 1 and stack[-1] == generic[0],
        f"{where} must end with one generic family",
    )
    return named, generic


def email_typography(model: dict) -> dict[str, dict]:
    """The e-mails' Urdu type: the Urdu stack with EMAIL_URDU_FALLBACKS before its generic
    family, the wordmark's stack as it is, and line heights from the Urdu styles."""
    families = model["families"]
    named, generic = _split_generic(families["urdu"], "font.family.urdu")
    urdu = list(dict.fromkeys([*named, *EMAIL_URDU_FALLBACKS])) + generic
    nastaliq = [f for f in urdu if is_nastaliq(f)]
    _require(
        nastaliq == [],
        f"the e-mails' Urdu stack names {', '.join(nastaliq)}: Nastaliq is for the wordmark only",
    )
    wordmark = families["urduWordmark"]
    _split_generic(wordmark, "font.family.urduWordmark")
    styles = {
        role: style
        for (script, role), style in model["typography"].items()
        if script == "urdu" and style["family"] == "urdu"
    }
    _require("body" in styles, "typography.urdu.body is missing")
    return {
        "urdu": {
            "fontFamily": urdu,
            "roles": {role: _email_role(role, style) for role, style in styles.items()},
        },
        "urduWordmark": {
            "fontFamily": wordmark,
            "lineHeight": _email_role("wordmark", model["typography"][("urdu", "wordmark")])[
                "lineHeight"
            ],
        },
    }


def _email_role(role: str, style: dict) -> dict:
    """An Urdu type role for e-mail: its size in pixels, and its line height as a multiple of the
    size (unitless, which Outlook for Windows handles better than px: caniemail.com,
    css-line-height, note 1) that makes the token's whole, even line of pixels."""
    size, line = style["size"], style["size"] * style["height"]
    _require(
        abs(line - round(line)) < 1e-6 and round(line) % 2 == 0,
        f"typography.urdu.{role}: a {size}px size on a {line:g}px line; "
        "Urdu lines are a whole, even number of pixels",
    )
    return {"fontSize": size, "lineHeight": line_ratio(round(line), size), "line": round(line)}


def line_ratio(line: int, size: float) -> str:
    """[line] / [size] to four decimal places, rounded up: the size times it is the whole line
    to within 0.003px, and never a hair short of it, which a browser can lay out a pixel short."""
    exact = Decimal(line) / Decimal(str(size))
    return format(exact.quantize(Decimal("0.0001"), rounding=ROUND_CEILING).normalize(), "f")


def email_stack(stack: list[str]) -> str:
    """A stack for a style attribute in double quotes: names with spaces in single quotes."""
    return ", ".join(f"'{f}'" if " " in f else f for f in stack)


def render_email_ts(email: dict[str, dict]) -> str:
    urdu, wordmark = email["urdu"], email["urduWordmark"]
    lines = [
        "// GENERATED by tool/design/build_tokens.py from design/tokens/maalik.tokens.json.",
        "// Do not edit by hand: change the tokens and run `make tokens`.",
        "",
        "/**",
        " * Urdu type for e-mail (D-19). An e-mail loads no web font, so the reader's installed",
        " * fonts draw it: Urdu text takes the tokens' Urdu stack with installed sans faces added",
        " * before its generic family, and Nastaliq is for the brand name only, where it stands as",
        " * the wordmark. Names are in single quotes, for a style attribute in double quotes.",
        " */",
        "export const EMAIL_TYPOGRAPHY = {",
        "  /**",
        "   * Urdu text: its stack, and the Urdu type roles. Urdu is set a size larger than Latin",
        "   * text in the same role (Noto Sans Arabic's letters are small for their size). A role's",
        "   * lineHeight is a multiple of its fontSize (px) that makes a whole, even number of",
        "   * pixels.",
        "   */",
        "  urdu: {",
        f'    fontFamily: "{email_stack(urdu["fontFamily"])}",',
        *(
            f"    {role}: {{ fontSize: {_num(value['fontSize'])}, "
            f"lineHeight: {value['lineHeight']} }}, // {value['line']}px lines"
            for role, value in urdu["roles"].items()
        ),
        "  },",
        "  /** The brand name where it stands as the wordmark, and nothing else. */",
        "  urduWordmark: {",
        f'    fontFamily: "{email_stack(wordmark["fontFamily"])}",',
        f"    lineHeight: {wordmark['lineHeight']},",
        "  },",
        "} as const;",
    ]
    return "\n".join(lines) + "\n"


def wordmark_name(arb: Path | None = None) -> str:
    """The app's Urdu name (`appName` in app_ur.arb), the only text the wordmark sets."""
    name = json.loads((arb or URDU_ARB).read_text(encoding="utf-8")).get("appName")
    _require(isinstance(name, str) and name.strip() != "", "app_ur.arb has no appName")
    return " ".join(name.split())


class _UrduElements(HTMLParser):
    """Collects every element in Urdu (lang="ur" on it or an ancestor), with where its start
    tag lies in the source and the text it holds."""

    def __init__(self, source: str, where: str) -> None:
        super().__init__(convert_charrefs=True)
        self.source, self.where = source, where
        self.line_starts = [0] + [match.end() for match in re.finditer("\n", source)]
        self.open: list[dict] = []
        self.urdu: list[dict] = []
        # Each run of text, and whether it is in Urdu.
        self.runs: list[tuple[str, bool]] = []

    def fail(self, message: str) -> None:
        raise TokenError(f"{self.where}:{self.getpos()[0]}: {message}")

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        # HTMLParser lowers the case of tag and attribute names, not of attribute values, and
        # rel holds a list of link types ("stylesheet preload").
        if tag == "style" or (
            tag == "link"
            and any(k == "rel" and "stylesheet" in (v or "").lower().split() for k, v in attrs)
        ):
            self.fail("e-mail styles are inline; a style sheet would escape this check")
        # A font element's face, and SVG's font-family attribute, set a face outside the style
        # attribute, and e-mail clients honour them.
        if tag in FONT_ELEMENTS or any(k in FONT_ATTRIBUTES for k, _ in attrs):
            self.fail(
                "set e-mail type with font-family in a style attribute, "
                "not a font element or a face or font-family attribute"
            )
        line, column = self.getpos()
        start = self.line_starts[line - 1] + column
        raw = self.get_starttag_text() or ""
        lang = next((v for k, v in attrs if k == "lang"), None)
        role = next((v for k, v in attrs if k == EMAIL_ROLE_ATTRIBUTE), None)
        inherited = self.open[-1]["urdu"] if self.open else False
        urdu = inherited if lang is None else lang.lower().split("-")[0] == "ur"
        if role is not None and not urdu:
            self.fail(f"{EMAIL_ROLE_ATTRIBUTE} names an Urdu type role, on an element not in Urdu")
        element = {
            "tag": tag,
            "urdu": urdu,
            "root": urdu and not inherited,
            "role": role,
            "start": start,
            "raw": raw,
            "line": line,
            "text": [],
        }
        if urdu:
            self.urdu.append(element)
        if tag not in VOID_ELEMENTS:
            self.open.append(element)

    def handle_endtag(self, tag: str) -> None:
        for index in range(len(self.open) - 1, -1, -1):
            if self.open[index]["tag"] == tag:
                del self.open[index:]
                return

    def handle_data(self, data: str) -> None:
        in_urdu = bool(self.open) and self.open[-1]["urdu"]
        urdu = ARABIC_SCRIPT.search(data)
        if urdu and not in_urdu:
            line = self.getpos()[0] + data.count("\n", 0, urdu.start())
            raise TokenError(
                f'{self.where}:{line}: Urdu text outside a lang="ur" element: {data.strip()!r}'
            )
        self.runs.append((data, in_urdu))
        for element in self.open:
            element["text"].append(data)


def _restyle(element: dict, email: dict[str, dict], wordmark: bool, where: str) -> str:
    """The element's start tag with its Urdu type written from [email]. The wordmark takes the
    wordmark's stack (and line height, if it sets one) and keeps the size of its line. Other
    Urdu text takes the Urdu stack, and the size and line height of the type role its
    data-mm-type names; an element without one sets neither. An Urdu root sets a face and
    names a role, so that what it holds inherits Urdu type."""
    raw, at = element["raw"], f"{where}:{element['line']}"
    tag = f'<{element["tag"]} lang="ur">' if element["root"] else f"<{element['tag']}>"
    found = STYLE_ATTRIBUTE.search(raw)
    if found is None:
        _require(
            ANY_STYLE_ATTRIBUTE.search(raw) is None,
            f"{at}: write the style attribute in double quotes",
        )
        style = ""
    else:
        style = found.group(2)
    _require(
        FONT_SHORTHAND.search(style) is None,
        f"{at}: set Urdu type with font-family, font-size and line-height, not the font shorthand",
    )
    # A CSS comment or escape, or a character reference, can hide a property name from the
    # patterns here ("font-family/**/:", "font&#45;family:") while a client still applies it.
    _require(
        not any(token in style for token in ("/*", "\\", "&")),
        f"{at}: write Urdu styles without CSS comments, CSS escapes or character references",
    )
    if element["root"]:
        _require(
            FONT_FAMILY.search(style) is not None,
            f"{at}: {tag} sets no font-family, so its Urdu would take the surrounding face",
        )
    urdu, roles = email["urdu"], email["urdu"]["roles"]
    names = ", ".join(roles)
    role_name = element["role"]
    if wordmark:
        _require(
            role_name is None,
            f"{at}: the wordmark takes no {EMAIL_ROLE_ATTRIBUTE}; it keeps the size of its line",
        )
        values = {
            FONT_FAMILY: email_stack(email["urduWordmark"]["fontFamily"]),
            LINE_HEIGHT: email["urduWordmark"]["lineHeight"],
        }
    elif role_name is None:
        _require(
            not element["root"],
            f'{at}: {tag} names no Urdu type role ({EMAIL_ROLE_ATTRIBUTE}="..."; one of '
            f"{names}), so its Urdu would take the surrounding size and line height",
        )
        for pattern, prop in ((FONT_SIZE, "font-size"), (LINE_HEIGHT, "line-height")):
            _require(
                pattern.search(style) is None,
                f"{at}: Urdu {prop} comes from a type role: name it with "
                f'{EMAIL_ROLE_ATTRIBUTE}="..." (one of {names})',
            )
        values = {FONT_FAMILY: email_stack(urdu["fontFamily"])}
    else:
        role = roles.get(role_name)
        _require(
            role is not None,
            f'{at}: {EMAIL_ROLE_ATTRIBUTE}="{role_name}" is not an Urdu type role; '
            f"the roles are {names}",
        )
        for pattern, prop in ((FONT_SIZE, "font-size"), (LINE_HEIGHT, "line-height")):
            _require(
                pattern.search(style) is not None,
                f'{at}: {tag[:-1]} {EMAIL_ROLE_ATTRIBUTE}="{role_name}"> sets no {prop} '
                "for the build to write the role's into",
            )
        values = {
            FONT_FAMILY: email_stack(urdu["fontFamily"]),
            FONT_SIZE: f"{_num(role['fontSize'])}px",
            LINE_HEIGHT: role["lineHeight"],
        }
    restyled = style
    for pattern, value in values.items():
        restyled = pattern.sub(lambda m, value=value: m.group(1) + value + m.group(3), restyled)
    if found is None:
        return raw
    return raw[: found.start(2)] + restyled + raw[found.end(2) :]


def render_email_template(email: dict[str, dict], html: str, name: str, where: str) -> str:
    """[html] with the type of its Urdu elements written from [email]: the wordmark's stack for
    an element that holds the brand name [name] alone, and the Urdu stack, with the size and
    line height of the role its data-mm-type names, for Urdu text. Everything else is kept as
    written."""
    parser = _UrduElements(html, where)
    parser.feed(html)
    parser.close()
    out = html
    for element in reversed(parser.urdu):
        wordmark = " ".join("".join(element["text"]).split()) == name
        start, end = element["start"], element["start"] + len(element["raw"])
        _require(out[start:end] == element["raw"], f"{where}:{element['line']}: unreadable tag")
        out = out[:start] + _restyle(element, email, wordmark, where) + out[end:]
    return out


def outputs(model: dict) -> dict[Path, str]:
    email = email_typography(model)
    name = wordmark_name()
    templates = {
        path: render_email_template(email, path.read_text(encoding="utf-8"), name, _display(path))
        for path in sorted(EMAIL_TEMPLATES.glob("*.html"))
    }
    return {
        DART_OUT: render_dart(model),
        CSS_OUT: render_css(model),
        DESIGN_MD: render_design_md(model, DESIGN_MD.read_text(encoding="utf-8")),
        EMAIL_TS_OUT: render_email_ts(email),
        **templates,
    }


def _display(path: Path) -> str:
    """[path] relative to the repository when it lies inside it."""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def main(argv: list[str]) -> int:
    check = argv == ["--check"]
    if argv and not check:
        print("usage: tool/design/build_tokens.py [--check]", file=sys.stderr)
        return 2
    try:
        model = load()
        rendered = outputs(model)
    except (TokenError, KeyError, json.JSONDecodeError) as error:
        print(f"error: {_display(SOURCE)}: {error}", file=sys.stderr)
        return 1
    stale = []
    for path, content in rendered.items():
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                stale.append(_display(path))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
    if stale:
        print("Token outputs are stale; run tool/design/build_tokens.py:", file=sys.stderr)
        for path in stale:
            print(f"  {path}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
