import 'package:flutter/material.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The label above a field (a text field, a date field, a select field):
/// static text that never floats, with "Required" or "Optional" in words
/// after it when the field says so ([markerOf]), muted while the field is
/// disabled.
///
/// The label is the field's accessible name, which the field itself
/// carries on its own semantics node (with the marker word as its hint), so
/// this visible copy is hidden from assistive technology and not read
/// twice.
///
/// Internal to mm_ui: the fields of every family use it.
class MmFieldLabel extends StatelessWidget {
  /// Shows [label] above a field.
  const new({
    required this.label,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    super.key,
  }) : assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// The field's name.
  final String label;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// Whether the field accepts input; a disabled field's label is muted.
  final bool enabled;

  /// The word after a field's label, from [MmLocalizations]: "Required",
  /// "Optional", or null when the field says neither.
  static String? markerOf(
    BuildContext context, {
    required bool required,
    required bool optional,
  }) {
    final strings = MmLocalizations.of(context);
    if (required) return strings.requiredField;
    return optional ? strings.optionalField : null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    final marker = markerOf(context, required: required, optional: optional);
    return ExcludeSemantics(
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
          style: text.labelLarge?.copyWith(
            color: enabled ? colors.ink : colors.inkMuted,
          ),
        ),
      ),
    );
  }
}
