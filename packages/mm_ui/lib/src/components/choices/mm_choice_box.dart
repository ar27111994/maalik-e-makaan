import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_field_label.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The box of a field whose value is chosen somewhere else (a date picker,
/// a sheet of options): drawn like a text field (paper fill, outline,
/// 56 dp tall, a 2 dp ring while it has keyboard focus, the overdue outline
/// with an error), but read-only, and tapping it, or pressing Enter or
/// Space while it has focus, calls [onTap].
///
/// The tappable part is one button for assistive technology, named by
/// [label], with the shown text as its value, the placeholder and the
/// "Required" or "Optional" word as its hint, and invalid while the field
/// has an error. [actions] (a clear button, a picker button) sit inside the
/// box after it, as buttons of their own, styled by [buttonStyle].
///
/// Internal to the choices family: the public fields build it.
class MmChoiceBox extends StatefulWidget {
  /// Creates the box of the field named [label].
  const new({
    required this.label,
    required this.onTap,
    this.text,
    this.semanticValue,
    this.placeholder,
    this.leading,
    this.trailing,
    this.actions = const [],
    this.hasError = false,
    this.required = false,
    this.optional = false,
    this.latinFigures = false,
    this.focusNode,
    super.key,
  });

  /// The style of a button inside the box: its icon in [color] (muted ink
  /// while disabled, which stays readable), grown with the text size up
  /// to one and a half times, and its keyboard focus ring on its own edge.
  /// The theme draws an icon button's ring outside it, past a gap, which a
  /// 56 dp box has no room for: there the box's outline would run through
  /// the ring and its clip would cut it.
  static ButtonStyle buttonStyle(BuildContext context, {required Color color}) {
    final colors = context.mm.colors;
    final focused = BorderSide(color: colors.focus, width: MmSize.focusRing);
    return ButtonStyle(
      iconSize: WidgetStatePropertyAll(
        MmIconLabel.scaledSize(context, MmSize.iconLg),
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? colors.inkMuted : color,
      ),
      shape: WidgetStateProperty.resolveWith(
        (states) => StadiumBorder(
          side: states.contains(WidgetState.focused)
              ? focused
              : BorderSide.none,
        ),
      ),
    );
  }

  /// The field's name, its accessible name.
  final String label;

  /// Called when the box is tapped or activated from the keyboard; null
  /// disables it.
  final VoidCallback? onTap;

  /// The chosen value as shown; null shows [placeholder].
  final String? text;

  /// The chosen value as a screen reader should say it, when it differs
  /// from [text] (a date with its weekday); defaults to [text].
  final String? semanticValue;

  /// Shown in muted ink while nothing is chosen.
  final String? placeholder;

  /// A decorative icon before the text (the chosen option's icon).
  final IconData? leading;

  /// A decorative icon at the end of the tappable part (a chevron).
  final IconData? trailing;

  /// Buttons inside the box after the tappable part.
  final List<Widget> actions;

  /// Whether the field shows an error: the outline turns overdue.
  final bool hasError;

  /// Whether the field is required (announced, and marked by the frame).
  final bool required;

  /// Whether the field is optional (announced, and marked by the frame).
  final bool optional;

  /// Whether figures in [text] are set in the Latin face even when the
  /// rest is Urdu (a date: "5 نومبر، 2026"), as amounts and counts are, so
  /// they match the figures everywhere else in the Urdu UI.
  final bool latinFigures;

  /// The focus node of the tappable part.
  final FocusNode? focusNode;

  @override
  State<MmChoiceBox> createState() => _MmChoiceBoxState();
}

class _MmChoiceBoxState extends State<MmChoiceBox>
    with MmFocusHighlight<MmChoiceBox> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (focused != _focused) setState(() => _focused = focused);
  }

  BorderSide _side(MmColorTokens colors, {required bool enabled}) {
    final focused = _focused && showsFocusHighlights;
    if (!enabled) return BorderSide(color: colors.rule);
    if (focused) {
      return BorderSide(
        color: widget.hasError ? colors.overdue : colors.focus,
        width: MmSize.focusRing,
      );
    }
    return BorderSide(color: widget.hasError ? colors.overdue : colors.outline);
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final enabled = widget.onTap != null;
    final value = widget.text;
    final shown = value ?? widget.placeholder ?? '';
    final ink = value != null && enabled ? colors.ink : colors.inkMuted;
    final style = mm.styleFor(
      shown,
      Theme.of(context).textTheme.bodyLarge!.copyWith(color: ink),
    );
    final marker = MmFieldLabel.markerOf(
      context,
      required: widget.required,
      optional: widget.optional,
    );
    final hint = [
      if (value == null && widget.placeholder != null) widget.placeholder!,
      ?marker,
    ].join('\n');
    final leading = widget.leading;
    final trailing = widget.trailing;
    final iconSize = MmIconLabel.scaledSize(context, MmSize.iconLg);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MmSize.fieldHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: MmSpace.s4,
          end: widget.actions.isEmpty ? MmSpace.s4 : MmSpace.s2,
          top: MmSpace.s3,
          bottom: MmSpace.s3,
        ),
        child: Row(
          spacing: MmSpace.s3,
          children: [
            if (leading != null)
              Icon(leading, size: iconSize, color: colors.inkMuted),
            Expanded(
              child: widget.latinFigures
                  ? Text.rich(_byScript(shown, style, mm))
                  : Text(shown, style: style),
            ),
            if (trailing != null)
              Icon(trailing, size: iconSize, color: colors.inkMuted),
          ],
        ),
      ),
    );
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.sm)),
        side: _side(colors, enabled: enabled),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              enabled: enabled,
              label: widget.label,
              value: widget.semanticValue ?? value,
              hint: hint.isEmpty ? null : hint,
              isRequired: widget.required
                  ? true
                  : (widget.optional ? false : null),
              validationResult: widget.hasError
                  ? SemanticsValidationResult.invalid
                  : SemanticsValidationResult.none,
              child: InkWell(
                focusNode: widget.focusNode,
                canRequestFocus: enabled,
                onTap: widget.onTap,
                onFocusChange: _handleFocusChange,
                // The ring shows keyboard focus. A tint would cover only
                // the tappable part and stop short of the box's buttons.
                focusColor: Colors.transparent,
                child: ExcludeSemantics(child: content),
              ),
            ),
          ),
          ...widget.actions,
          if (widget.actions.isNotEmpty) const SizedBox(width: MmSpace.s1),
        ],
      ),
    );
  }
}

/// [text] in [style], with each run of characters outside the Arabic
/// script (figures, Latin letters and the spaces between them) set in the
/// Latin face as [MmSemantics.styleFor] sets them.
TextSpan _byScript(String text, TextStyle style, MmSemantics mm) {
  final runs = <TextSpan>[];
  final run = StringBuffer();
  bool? arabic;
  void flush() {
    if (run.isEmpty) return;
    final words = run.toString();
    runs.add(TextSpan(text: words, style: mm.styleFor(words, style)));
    run.clear();
  }

  for (final character in text.characters) {
    final isArabic = MmSemantics.hasArabicScript(character);
    if (isArabic != arabic) flush();
    arabic = isArabic;
    run.write(character);
  }
  flush();
  return TextSpan(style: style, children: runs);
}
