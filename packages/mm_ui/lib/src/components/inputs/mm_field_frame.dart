import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_field_label.dart';

/// The anatomy every field of the inputs family shares, around the field
/// itself ([child], a [TextFormField] decorated with [decoration]):
///
/// * the label sits above the field as static text, never floating, with
///   "Required" or "Optional" in words after it when the field says so;
/// * the label is the field's accessible name: it is set on the text
///   field's own semantics node (with the required state and the marker
///   word as its hint), and the visible copy is hidden from assistive
///   technology so it is not read twice;
/// * helper text sits below the field in muted ink, and an error replaces
///   it in the overdue colour with the error icon (`MmFieldError`, the
///   text field's error builder), announced as a live region.
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

  /// The text field.
  final Widget child;

  /// The decoration of a framed field: [hint] inside it while it is empty,
  /// [helper] below it in muted ink (wrapping, never cut short), and the
  /// optional affixes, sized within [affixConstraints] (by default at least
  /// the 48 dp touch target, for icons and buttons). Errors come from the
  /// field's `forceErrorText` or validator, shown by `MmFieldError`.
  static InputDecoration decoration(
    BuildContext context, {
    String? hint,
    String? helper,
    Widget? prefixIcon,
    String? prefixText,
    Widget? suffixIcon,
    BoxConstraints? affixConstraints,
  }) {
    final helperStyle = Theme.of(context).inputDecorationTheme.helperStyle;
    return InputDecoration(
      hintText: hint,
      helper: helper == null ? null : Text(helper, style: helperStyle),
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      suffixIcon: suffixIcon,
      prefixIconConstraints: affixConstraints,
      suffixIconConstraints: affixConstraints,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
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
        hint: MmFieldLabel.markerOf(
          context,
          required: required,
          optional: optional,
        ),
        isRequired: required ? true : (optional ? false : null),
        child: child,
      ),
    ],
  );
}
