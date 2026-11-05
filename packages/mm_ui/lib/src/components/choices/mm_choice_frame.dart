import 'package:flutter/material.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The anatomy the fields of the choices family share with text fields,
/// around the control itself ([child]):
///
/// * the label sits above the control as static text, with "Required" or
///   "Optional" in words after it when the field says so ([markerOf]);
/// * the label is the control's accessible name: the control carries it on
///   its own semantics node, so the visible copy here is hidden from
///   assistive technology and not read twice;
/// * helper text sits below in muted ink, and an error replaces it in the
///   overdue colour with the error icon ([errorLine]), announced as a live
///   region.
///
/// Internal to the choices family: the public fields build it.
class MmChoiceFrame extends StatelessWidget {
  /// Frames [child] with [label] above it and [helper] or [errorText]
  /// below it.
  const new({
    required this.label,
    required this.child,
    this.helper,
    this.errorText,
    this.required = false,
    this.optional = false,
    this.enabled = true,
    super.key,
  }) : assert(
         !(required && optional),
         'A field is either required or optional, not both.',
       );

  /// The field's name, shown above the control.
  final String label;

  /// The control.
  final Widget child;

  /// Shown below the control in muted ink, unless there is an error.
  final String? helper;

  /// Shown below the control instead of [helper], with the error icon.
  final String? errorText;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  /// Whether the control accepts input; a disabled field's label is muted.
  final bool enabled;

  /// The word after a label, from [MmLocalizations]: "Required",
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

  /// The error line below a field: the error icon and [message] in the
  /// overdue colour (never colour alone), announced as a live region. The
  /// icon grows with the text and is hidden from assistive technology.
  static Widget errorLine(BuildContext context, String message) {
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
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: colors.overdue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    final marker = markerOf(context, required: required, optional: optional);
    final error = errorText;
    final helper = this.helper;
    const below = EdgeInsetsDirectional.only(
      start: MmSpace.s4,
      end: MmSpace.s4,
      top: MmSpace.s1,
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
              style: text.labelLarge?.copyWith(
                color: enabled ? colors.ink : colors.inkMuted,
              ),
            ),
          ),
        ),
        child,
        // Aligned rather than stretched, so the text is only as wide as it
        // needs: assistive technology outlines the words, not the row.
        if (error != null)
          Padding(
            padding: below,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: errorLine(context, error),
            ),
          )
        else if (helper != null)
          Padding(
            padding: below,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                helper,
                style: text.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
            ),
          ),
      ],
    );
  }
}
