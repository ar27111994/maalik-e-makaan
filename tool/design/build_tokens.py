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

DESIGN.md's component recipes are linted here the way the Stitch CLI
(@google/design.md) lints them: every {reference} must resolve, and every
component pairing text with a background must reach 4.5:1.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "design" / "tokens" / "maalik.tokens.json"
DART_OUT = ROOT / "packages" / "mm_ui" / "lib" / "src" / "tokens" / "mm_tokens.g.dart"
CSS_OUT = ROOT / "design" / "tokens" / "maalik.tokens.css"
DESIGN_MD = ROOT / "DESIGN.md"

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
]

# Font families as the mm_ui package declares them in pubspec.yaml.
FLUTTER_FAMILIES = {
    "Atkinson Hyperlegible Next": "AtkinsonHyperlegibleNext",
    "Noto Nastaliq Urdu": "NotoNastaliqUrdu",
}


class TokenError(ValueError):
    """The token file is malformed or violates a design rule."""


# --- colour maths --------------------------------------------------------------------


def _channel(value: float) -> float:
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def relative_luminance(hex_: str) -> float:
    r, g, b = (int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5))
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
    _require(isinstance(hex_, str) and len(hex_) == 7 and hex_.startswith("#"), f"{where}: hex must be #RRGGBB")
    try:
        channels = [int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    except ValueError:
        raise TokenError(f"{where}: hex must be #RRGGBB") from None
    components = value.get("components")
    _require(
        isinstance(components, list) and len(components) == 3
        and all(isinstance(c, (int, float)) for c in components),
        f"{where}: components must be three numbers",
    )
    _require(
        all(abs(c - h) <= 0.5 / 255 + 1e-6 for c, h in zip(components, channels)),
        f"{where}: components {components} disagree with {hex_}",
    )
    _require(value.get("alpha", 1) == 1, f"{where}: colours must be opaque")
    return hex_.upper()


def dimension(token: dict, where: str) -> float:
    value = token.get("$value")
    _require(
        isinstance(value, dict) and value.get("unit") == "px" and isinstance(value.get("value"), (int, float)),
        f"{where}: dimension $value must be {{value, unit: px}}",
    )
    return value["value"]


def duration_ms(token: dict, where: str) -> int:
    value = token.get("$value")
    _require(
        isinstance(value, dict) and value.get("unit") == "ms" and isinstance(value.get("value"), int),
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
        _require(list(modes[mode]) == roles, f"color.{mode} must define the same roles as color.light, in order")

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

    families = {
        name: token["$value"] for name, token in _tokens(raw["font"]["family"]).items()
    }
    for name, stack in families.items():
        _require(isinstance(stack, list) and stack and stack[0] in FLUTTER_FAMILIES,
                 f"font.family.{name}: the first family must be one mm_ui bundles")

    typography = {}
    for script, styles in _tokens(raw["typography"]).items():
        for role, token in _tokens(styles).items():
            value = token["$value"]
            where = f"typography.{script}.{role}"
            family_ref = value.get("fontFamily", "")
            _require(family_ref.startswith("{font.family.") and family_ref.endswith("}"), f"{where}: fontFamily must reference a font.family token")
            family = family_ref[len("{font.family."):-1]
            _require(family in families, f"{where}: unknown family {family}")
            size = value["fontSize"]["value"]
            weight = value["fontWeight"]
            _require(weight in (100, 200, 300, 400, 500, 600, 700, 800, 900), f"{where}: fontWeight must be a multiple of 100")
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
        _require(isinstance(value, list) and len(value) == 4, f"easing.{name}: must be four numbers")
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
    out += _members([
        _doc(model["modes"]["light"][role][1], "  ") + [f"  final Color {role};"] for role in roles
    ])
    out += ["}", "", "/// The four colour modes; every pairing the UI uses is contrast-checked at build time.",
            "abstract final class MmColorModes {"]
    labels = {
        "light": "Light mode.",
        "dark": "Dark mode.",
        "lightHighContrast": "Light high-contrast mode (7:1 text).",
        "darkHighContrast": "Dark high-contrast mode (7:1 text).",
    }
    out += _members([
        [f"  /// {labels[mode]}", f"  static const MmColorTokens {mode} = MmColorTokens("]
        + [f"    {role}: Color(0xFF{hex_[1:]})," for role, (hex_, _) in palette.items()]
        + ["  );"]
        for mode, palette in model["modes"].items()
    ])
    out.append("}")

    def numbers(cls: str, doc: str, group: str) -> None:
        out.extend(["", f"/// {doc}", f"abstract final class {cls} {{"])
        out.extend(_members([
            _doc(description, "  ") + [f"  static const double {name} = {_num(value)};"]
            for name, (value, description) in model[group].items()
        ]))
        out.append("}")

    numbers("MmSpace", "Spacing on the 4 dp grid.", "space")
    numbers("MmRadius", "Corner radii.", "radius")
    numbers("MmSize", "Fixed sizes: touch targets, controls, icons.", "size")
    numbers("MmBreakpoint", "Window widths where the layout changes.", "breakpoint")

    out += ["", "/// Motion durations (zero when the platform asks for reduced motion).",
            "abstract final class MmDuration {"]
    out += _members([
        _doc(description, "  ") + [f"  static const Duration {name} = Duration(milliseconds: {ms});"]
        for name, (ms, description) in model["duration"].items()
    ])
    out += ["}", "", "/// Easing curves.", "abstract final class MmEasing {"]
    out += _members([
        [f"  /// The {name} curve.",
         f"  static const Cubic {name} = Cubic({_num(x1)}, {_num(y1)}, {_num(x2)}, {_num(y2)});"]
        for name, (x1, y1, x2, y2) in model["easing"].items()
    ])
    out += ["}", "", "/// Font families bundled with mm_ui (pass `package: 'mm_ui'`).",
            "abstract final class MmFontFamily {"]
    out += _members([
        [f"  /// {stack[0]}.", f"  static const String {name} = '{FLUTTER_FAMILIES[stack[0]]}';"]
        for name, stack in model["families"].items()
    ])
    out += ["}", "", "/// Text styles of each script (Latin for English, Nastaliq for Urdu).",
            "abstract final class MmTypeScale {"]
    styles = []
    for (script, role), style in model["typography"].items():
        name = f"{script}{role[0].upper()}{role[1:]}"
        family = FLUTTER_FAMILIES[model["families"][style["family"]][0]]
        styles.append([
            f"  /// {script.capitalize()} {role}: {_num(style['size'])} px on a {_num(round(style['size'] * style['height'], 2))} px line.",
            f"  static const TextStyle {name} = TextStyle(",
            f"    fontFamily: '{family}',",
            "    package: 'mm_ui',",
            f"    fontSize: {_num(style['size'])},",
            f"    height: {_num(style['height'])},",
            f"    fontWeight: FontWeight.w{style['weight']},",
            f"    letterSpacing: {_num(style['tracking'])},",
            "  );",
        ])
    out += _members(styles)
    out.append("}")
    return "\n".join(out) + "\n"


def _kebab(name: str) -> str:
    return "".join("-" + c.lower() if c.isupper() else c for c in name)


def render_css(model: dict) -> str:
    def colors(mode: str, indent: str) -> list[str]:
        return [f"{indent}--mm-color-{_kebab(role)}: {hex_};" for role, (hex_, _) in model["modes"][mode].items()]

    out = [
        "/* GENERATED by tool/design/build_tokens.py from design/tokens/maalik.tokens.json. */",
        "/* Do not edit by hand: change the tokens and run `make tokens`. */",
        "",
        ":root {",
        "  color-scheme: light dark;",
    ]
    for group in ("space", "radius", "size", "breakpoint"):
        out += [f"  --mm-{group}-{_kebab(name)}: {_num(value)}px;" for name, (value, _) in model[group].items()]
    out += [f"  --mm-duration-{name}: {ms}ms;" for name, (ms, _) in model["duration"].items()]
    out += [
        f"  --mm-easing-{name}: cubic-bezier({', '.join(_num(v) for v in value)});"
        for name, value in model["easing"].items()
    ]
    out += [
        f"  --mm-font-{name}: {', '.join(repr(f) if ' ' in f else f for f in stack)};".replace("'", '"')
        for name, stack in model["families"].items()
    ]
    out += colors("light", "  ") + ["}", ""]
    out += ["@media (prefers-color-scheme: dark) {", "  :root:not([data-theme]) {"] + colors("dark", "    ") + ["  }", "}", ""]
    out += ['[data-theme="dark"] {'] + colors("dark", "  ") + ["}", ""]
    out += ["@media (prefers-contrast: more) {", "  :root:not([data-theme]) {"] + colors("lightHighContrast", "    ") + ["  }", "}", ""]
    out += ["@media (prefers-contrast: more) and (prefers-color-scheme: dark) {", "  :root:not([data-theme]) {"]
    out += colors("darkHighContrast", "    ") + ["  }", "}", ""]
    out += ["@media (prefers-reduced-motion: reduce) {", "  :root {"]
    out += [f"    --mm-duration-{name}: 0ms;" for name in model["duration"]] + ["  }", "}", ""]
    return "\n".join(out)


# Component recipes for DESIGN.md (Stitch format: fixed properties, token references).
DESIGN_COMPONENTS = {
    "page": {"backgroundColor": "{colors.bg}", "textColor": "{colors.ink}"},
    "button-primary": {
        "backgroundColor": "{colors.primary}", "textColor": "{colors.onPrimary}",
        "typography": "{typography.label}", "rounded": "{rounded.sm}", "height": "48px", "padding": "16px",
    },
    "button-secondary": {
        "backgroundColor": "{colors.surface}", "textColor": "{colors.primary}",
        "typography": "{typography.label}", "rounded": "{rounded.sm}", "height": "48px", "padding": "16px",
    },
    "card": {
        "backgroundColor": "{colors.surface}", "textColor": "{colors.ink}",
        "rounded": "{rounded.md}", "padding": "16px",
    },
    "field": {
        "backgroundColor": "{colors.surface}", "textColor": "{colors.ink}",
        "typography": "{typography.body}", "rounded": "{rounded.sm}", "height": "56px",
    },
    "caption": {"backgroundColor": "{colors.surface}", "textColor": "{colors.inkMuted}", "typography": "{typography.caption}"},
    "chip-paid": {
        "backgroundColor": "{colors.paidContainer}", "textColor": "{colors.onPaidContainer}",
        "typography": "{typography.label}", "rounded": "{rounded.xs}",
    },
    "chip-overdue": {
        "backgroundColor": "{colors.overdueContainer}", "textColor": "{colors.onOverdueContainer}",
        "typography": "{typography.label}", "rounded": "{rounded.xs}",
    },
    "chip-due-soon": {
        "backgroundColor": "{colors.dueSoonContainer}", "textColor": "{colors.onDueSoonContainer}",
        "typography": "{typography.label}", "rounded": "{rounded.xs}",
    },
    "chip-credit": {
        "backgroundColor": "{colors.creditContainer}", "textColor": "{colors.onCreditContainer}",
        "typography": "{typography.label}", "rounded": "{rounded.xs}",
    },
    "nameplate": {
        "backgroundColor": "{colors.brassContainer}", "textColor": "{colors.onBrassContainer}",
        "typography": "{typography.title}", "rounded": "{rounded.xs}", "padding": "12px",
    },
    "amount": {"backgroundColor": "{colors.surface}", "textColor": "{colors.ink}", "typography": "{typography.amount}"},
}

DESIGN_DESCRIPTION = (
    "A raseed book made trustworthy on a phone: carbon-copy cobalt ink on cool white paper, "
    "a brass nameplate for what deserves honour, Atkinson Hyperlegible Next and Noto Nastaliq Urdu."
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
                _require(value.endswith("}"), f"DESIGN.md components.{component}.{key}: malformed reference")
                group, _, name = value[1:-1].partition(".")
                _require(
                    group in groups and name in groups[group],
                    f"DESIGN.md components.{component}.{key}: broken reference {value}",
                )
                resolved[key] = groups[group][name]
        if "textColor" in resolved and "backgroundColor" in resolved:
            ratio = contrast_ratio(resolved["textColor"], resolved["backgroundColor"])
            _require(ratio >= 4.5, f"DESIGN.md components.{component}: text contrast {ratio:.2f}:1 is below 4.5:1")


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
    return render_design_frontmatter(model) + current[end + len("\n---\n"):]


def outputs(model: dict) -> dict[Path, str]:
    return {
        DART_OUT: render_dart(model),
        CSS_OUT: render_css(model),
        DESIGN_MD: render_design_md(model, DESIGN_MD.read_text(encoding="utf-8")),
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
