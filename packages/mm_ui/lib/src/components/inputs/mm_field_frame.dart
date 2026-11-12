import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_field_label.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';

/// The anatomy every field of the inputs family shares, around the field
/// itself ([child], a [TextFormField] decorated with [decoration]):
///
/// * the label sits above the field as static text, never floating, with
///   "Required" or "Optional" in words after it when the field says so;
/// * the label is the field's accessible name: it is set on the text
///   field's own semantics node (with the required state and the marker
///   word as its hint), and the visible copy is hidden from assistive
///   technology so it is not read twice;
/// * the text, the hint, the helper and the error all start at the field's
///   content padding (16 dp), as the values and helper lines of the
///   choice fields do, so a form that mixes them lines up;
/// * helper text sits below the field in muted ink, and an error replaces
///   it in the overdue colour with the error icon (`MmFieldError`, the
///   text field's error builder), announced as a live region.
///
/// Material animates a field's outline and its helper and error line
/// (167 ms fades, the error sliding a quarter of its height into place)
/// whatever the platform's reduced-motion setting says: the durations are
/// fixed inside Flutter's `InputDecorator` and cannot be set from here.
///
/// Internal to the inputs family: the public fields build it.
class MmFieldFrame extends StatelessWidget {
  /// Frames [child] with [label] above it.
  const new({
    required this.label,
    required this.child,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    this.hint,
    super.key,
  }) : assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// The field's name, shown above it and announced as its accessible name.
  final String label;

  /// Whether the field says "Required" after its label.
  final bool required;

  /// Whether the field says "Optional" after its label.
  final bool optional;

  /// Whether the field accepts input; a disabled field's label is muted.
  final bool enabled;

  /// More words for assistive technology after "Required" or "Optional"
  /// (the unit an empty amount is in), on a line of their own.
  final String? hint;

  /// The text field.
  final Widget child;

  /// The decoration of a framed field: [hint] inside it while it is empty
  /// and [helper] below it, both in muted ink and wrapping rather than cut
  /// short at large text sizes (a hint that wraps makes the field as tall
  /// as it, typed in or not, so the field does not jump), and the
  /// optional affixes, sized within [affixConstraints] (by default at least
  /// the 48 dp touch target, for icons and buttons). Errors come from the
  /// field's `forceErrorText` or validator, shown by `MmFieldError`.
  ///
  /// The theme's outline leaves no gap for a floating label (the label sits
  /// above the field), so Material does not inset the text, the hint and
  /// the helper line by that gap either: they start at the content padding.
  ///
  /// [subtextScaler], when set, is the text scale of the helper line, for a
  /// field whose own line is set at another scale (see [atScale]).
  static InputDecoration decoration(
    BuildContext context, {
    String? hint,
    String? helper,
    Widget? prefixIcon,
    String? prefixText,
    Widget? suffixIcon,
    BoxConstraints? affixConstraints,
    TextScaler? subtextScaler,
  }) {
    final theme = Theme.of(context).inputDecorationTheme;
    return InputDecoration(
      // Set as MmScriptText sets them, so the figures of an amount in an
      // Urdu helper ("ذمے باقی: 122,450 روپے") match the same amount typed
      // in the field above, in the Latin face.
      hint: hint == null ? null : MmScriptText(hint, style: theme.hintStyle!),
      helper: helper == null
          ? null
          : atScale(
              subtextScaler,
              MmScriptText(helper, style: theme.helperStyle!),
            ),
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      prefixIconConstraints: affixConstraints,
      suffixIconConstraints: affixConstraints,
    );
  }

  /// [child] at the text scale [scaler], or as it is when [scaler] is null.
  static Widget atScale(TextScaler? scaler, Widget child) {
    if (scaler == null) return child;
    return Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marker = MmFieldLabel.markerOf(
      context,
      required: required,
      optional: optional,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MmFieldLabel(
          label: label,
          required: required,
          optional: optional,
          enabled: enabled,
        ),
        Semantics(
          label: label,
          hint: [?marker, ?hint].join('\n'),
          isRequired: required ? true : (optional ? false : null),
          child: child,
        ),
      ],
    );
  }
}
