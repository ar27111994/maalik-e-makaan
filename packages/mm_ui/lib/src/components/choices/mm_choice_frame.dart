import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_field_error.dart';
import 'package:mm_ui/src/foundation/mm_field_label.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The anatomy the fields of the choices family share with text fields,
/// around the control itself ([child]):
///
/// * the label sits above the control as static text, with "Required" or
///   "Optional" in words after it when the field says so ([MmFieldLabel]);
/// * the label is the control's accessible name: the control carries it on
///   its own semantics node, so the visible copy is hidden from assistive
///   technology and not read twice;
/// * helper text sits below in muted ink, and an error replaces it in the
///   overdue colour with the error icon ([MmFieldError]), announced as a
///   live region.
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
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
        MmFieldLabel(
          label: label,
          required: required,
          optional: optional,
          enabled: enabled,
        ),
        child,
        // Aligned rather than stretched, so the text is only as wide as it
        // needs: assistive technology outlines the words, not the row.
        if (error != null)
          Padding(
            padding: below,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: MmFieldError(error),
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
