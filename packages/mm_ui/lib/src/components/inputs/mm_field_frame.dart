import 'package:flutter/material.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

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
///   it in the overdue colour with the error icon ([error]), announced as a
///   live region.
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
  /// field's `forceErrorText` or validator through [error].
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

  /// The error line below a field: the error icon and [message] in the
  /// overdue colour (never colour alone), announced as a live region. The
  /// icon grows with the text and is hidden from assistive technology.
  static Widget error(BuildContext context, String message) {
    final colors = context.mm.colors;
    return Semantics(
      liveRegion: true,
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: MmSpace.s1),
                child: Icon(
                  MmIcons.error,
                  size: MmSize.iconSm,
                  color: colors.overdue,
                ),
              ),
            ),
            TextSpan(text: message),
          ],
        ),
        semanticsLabel: message,
        style: Theme.of(context).inputDecorationTheme.errorStyle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    final strings = MmLocalizations.of(context);
    final marker = required
        ? strings.requiredField
        : optional
        ? strings.optionalField
        : null;
    final labelStyle = text.labelLarge?.copyWith(
      color: enabled ? colors.ink : colors.inkMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s2),
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (marker != null)
                    TextSpan(
                      text: '  $marker',
                      style: TextStyle(
                        color: colors.inkMuted,
                        fontWeight: text.bodyMedium?.fontWeight,
                      ),
                    ),
                ],
              ),
              style: labelStyle,
            ),
          ),
        ),
        Semantics(
          label: label,
          hint: marker,
          isRequired: required ? true : (optional ? false : null),
          child: child,
        ),
      ],
    );
  }
}
