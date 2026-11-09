import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/choices/mm_choice_frame.dart';
import 'package:mm_ui/src/components/choices/mm_option.dart';
import 'package:mm_ui/src/components/choices/mm_tile_bleed.dart';
import 'package:mm_ui/src/foundation/mm_field_label.dart';
import 'package:mm_ui/src/foundation/mm_focus_within.dart';
import 'package:mm_ui/src/foundation/mm_line_icon.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One of a few exclusive options, all in view, under a [label]: how a
/// payment was received, which day rent falls due, who pays the
/// electricity bill.
///
/// Each option is a row with its radio button at the start, as a checkbox
/// row has its box, then its icon (when it has one) and label, and an
/// optional description under the label; the whole row is the target, and
/// it lines up with the fields around it, its highlight reaching into the
/// page's gutter. The chosen option's button is filled, not only coloured. From
/// the keyboard, Tab enters the group at the chosen option, the arrow keys
/// move the choice, and Space chooses the focused option.
///
/// The label sits above the rows as a field's label does, with "Required"
/// or "Optional" after it when the group says so, and helper or error text
/// below them, so a group lines up with the fields of a form. Assistive
/// technology hears the group as a radio group named [label] (with the
/// marker word as its hint), each row as one radio button with its checked
/// state, and the error as a live region.
///
/// Use it for two to about six options that deserve to be compared side by
/// side. For more, or when space is short, use an `MmSelectField`; for
/// switching views, a segmented control.
///
/// ```dart
/// MmRadioGroup<PaymentMethod>(
///   label: l10n.receivedBy,
///   options: [
///     MmOption(value: PaymentMethod.cash, label: l10n.cash),
///     MmOption(value: PaymentMethod.bank, label: l10n.bankTransfer),
///   ],
///   value: method,
///   onChanged: (method) => setState(() => this.method = method),
/// )
/// ```
class MmRadioGroup<T> extends StatelessWidget {
  /// Creates a group named [label] choosing among [options].
  const new({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.helper,
    this.errorText,
    this.required = false,
    this.optional = false,
    super.key,
  }) : assert(
         !(required && optional),
         'A group is either required or optional, not both.',
       );

  /// The group's name, shown above the options and announced as the
  /// group's name.
  final String label;

  /// The options, in reading order.
  final List<MmOption<T>> options;

  /// The value of the chosen option; null (or a value no option has)
  /// leaves every option unchosen.
  final T? value;

  /// Called with the value of the option the landlord chooses. When null
  /// the group is disabled.
  final ValueChanged<T?>? onChanged;

  /// Shown below the options in muted ink.
  final String? helper;

  /// Shown below the options instead of [helper], with the error icon.
  final String? errorText;

  /// Whether the label says "Required".
  final bool required;

  /// Whether the label says "Optional".
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final enabled = onChanged != null;
    final titleStyle = text.bodyLarge!.copyWith(
      color: enabled ? colors.ink : colors.inkMuted,
    );
    final note = text.bodyMedium!.copyWith(color: colors.inkMuted);
    // The radio buttons grow with the text as the option icons beside them
    // do, so a radio is never smaller than its option's icon.
    final scale = MmTileBleed.scaleOf(context);
    return MmChoiceFrame(
      label: label,
      helper: helper,
      errorText: errorText,
      required: required,
      optional: optional,
      enabled: enabled,
      child: RadioGroup<T>(
        groupValue: value,
        // RadioGroup needs a handler; a disabled group's rows cannot be
        // chosen, so its handler is never called.
        onChanged: onChanged ?? (_) {},
        // Inside the group's own semantics node, so the label names it.
        child: Semantics(
          label: label,
          hint: MmFieldLabel.markerOf(
            context,
            required: required,
            optional: optional,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                // The row reaches into the gutter, so its radio lines up
                // with the fields and headings around it (see MmTileBleed).
                MmTileBleed(
                  child: MmFocusWithin(
                    radius: MmRadius.none,
                    child: RadioListTile<T>(
                      radioScaleFactor: scale,
                      contentPadding: EdgeInsetsDirectional.only(
                        start: MmTileBleed.leadingPadding(scale),
                        end: MmSpace.s4,
                      ),
                      value: option.value,
                      enabled: enabled,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: option.icon == null
                          ? MmUserText(option.label, style: titleStyle)
                          : _withIcon(option, option.icon!, titleStyle, note),
                      subtitle:
                          option.icon != null || option.description == null
                          ? null
                          : MmUserText(option.description!, style: note),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The label of [option] in [style] after its [icon], with its
  /// description in [note] under the label: the icon belongs to the words,
  /// so it sits beside them, not across a wide row at the far edge, and the
  /// description lines up with the label it explains, not with the icon.
  Widget _withIcon(
    MmOption<T> option,
    IconData icon,
    TextStyle style,
    TextStyle note,
  ) {
    final description = option.description;
    return Builder(
      builder: (context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s3,
        children: [
          MmLineIcon(
            icon: icon,
            color: context.mm.colors.inkMuted,
            style: style,
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MmUserText(option.label, style: style),
                if (description != null) MmUserText(description, style: note),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
