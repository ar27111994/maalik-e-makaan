import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/display/mm_amount.dart';
import 'package:mm_ui/src/components/display/mm_no_controls.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';
import 'package:mm_ui/src/foundation/mm_wrap.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A label and its value on one line, as on a raseed: "Monthly rent ...
/// Rs 45,000".
///
/// The [label] sits at the start in muted ink, the value at the end in ink
/// with tabular figures, so a column of rows lines its figures up. A rupee
/// amount goes in [MmDetailRow.amount], which sets it as `MmAmount` does:
/// the Latin face with tabular figures in both languages, never breaking
/// inside the number, read to screen readers as "45000 rupees". When the
/// label and value do not fit on one line (a narrow screen, large text, a
/// long address) the value moves under the label and keeps to the end edge,
/// so the values of a card's rows end on one edge whichever rows had to
/// move; a value too long for one line wraps across the row. A [trailing]
/// widget that does not fit beside the value goes under it. Set
/// [emphasized] for a total.
///
/// The row is one node for screen readers, "Monthly rent, 45000 rupees",
/// with its [trailing] status ("Paid") read after it. A control for the
/// value (copy a CNIC, call a phone number) goes in [action], which stays a
/// separate button at the end of the row, and moves under the row when the
/// two do not fit side by side, so the value never breaks to make room for
/// it. A control in [trailing] would be merged into the row, and debug
/// builds report one.
///
/// Use rows inside an `MmCard` or a receipt to show a record's details.
/// Don't use it for a row that opens something (use `MmListTile`) or for a
/// value the landlord edits (use a field).
///
/// ```dart
/// MmDetailRow.amount(label: l10n.monthlyRent, amount: lease.rent)
/// MmDetailRow(
///   label: l10n.cnic,
///   value: tenant.cnic,
///   action: IconButton(
///     tooltip: l10n.copy,
///     icon: const Icon(MmIcons.copy),
///     onPressed: () => copy(tenant.cnic),
///   ),
/// )
/// ```
class MmDetailRow extends StatelessWidget {
  /// Creates a row showing the text [value] for [label].
  const new({
    required this.label,
    required String this.value,
    this.emphasized = false,
    this.userData = true,
    this.semanticValue,
    this.trailing,
    this.action,
    super.key,
  }) : amount = null,
       creditLabel = null;

  /// Creates a row showing [amount] for [label], set and read as an
  /// `MmAmount` is: a negative amount shows a minus sign, or the absolute
  /// amount and [creditLabel] when that is given ("Rs 5,000 credit").
  const new amount({
    required this.label,
    required Money this.amount,
    this.creditLabel,
    this.emphasized = false,
    this.trailing,
    this.action,
    super.key,
  }) : value = null,
       userData = false,
       semanticValue = null;

  /// What the value is ("Monthly rent"), from the app's localisations.
  final String label;

  /// The text value ("Ali Raza", "35202-1234567-1"), or null for a row
  /// made with [MmDetailRow.amount].
  final String? value;

  /// The amount of a row made with [MmDetailRow.amount], or null for a text
  /// value.
  final Money? amount;

  /// The word that follows a negative [amount] in place of its minus sign
  /// ("credit", "advance"), from the app's localisations.
  final String? creditLabel;

  /// Whether the row is a total: the label in the semibold title style, in
  /// ink, and a text value in that style too.
  final bool emphasized;

  /// Whether [value] is the landlord's data (a name, an address, a CNIC).
  /// Such a value is set in its own script's face (in the Urdu UI, a name
  /// typed in English in the Latin face) and keeps its own direction (a
  /// CNIC stays left to right in Urdu). Pass false for words from the app's
  /// localisations.
  final bool userData;

  /// How a screen reader says [value] when that differs from how it looks:
  /// a date in words.
  final String? semanticValue;

  /// A status after the value, such as an `MmStatusBadge`, read with the
  /// row. Not a control: put a control in [action].
  final Widget? trailing;

  /// A control for the value at the end of the row, such as an
  /// `IconButton` that copies a CNIC. It keeps its own node for screen
  /// readers and its own place in the keyboard's tab order.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final labelStyle = emphasized
        ? text.titleMedium!.copyWith(color: colors.ink)
        : text.bodyMedium!.copyWith(color: colors.inkMuted);
    final trailing = this.trailing;
    final action = this.action;
    final amount = this.amount;
    final Widget shown;
    final String spoken;
    if (amount != null) {
      shown = MmAmount(amount: amount, creditLabel: creditLabel);
      spoken = MmAmount.spokenLabel(context, amount, creditLabel: creditLabel);
    } else {
      final value = this.value!;
      final valueStyle = MmSemantics.withTabularFigures(
        (emphasized ? text.titleMedium! : text.bodyLarge!).copyWith(
          color: colors.ink,
        ),
      );
      // A value that wraps under its label ends its lines on the end edge
      // too, where the other values end.
      shown = userData
          ? MmUserText(value, style: valueStyle, textAlign: TextAlign.end)
          : Text(value, style: valueStyle, textAlign: TextAlign.end);
      spoken = semanticValue ?? value;
    }
    final Widget valueText = ExcludeSemantics(child: shown);
    final Widget row = MergeSemantics(
      child: Semantics(
        label: MmLocalizations.of(context).joined([label, spoken]),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: MmSpace.s2),
          child: MmReflow(
            alignment: MmReflowAlignment.baseline,
            // Under the label the value keeps to the end edge, where the
            // values beside their labels end.
            stackedAtEnd: true,
            start: ExcludeSemantics(child: Text(label, style: labelStyle)),
            // The trailing widget wraps under the value rather than
            // squeezing it: a value never breaks to make room for it.
            end: trailing == null
                ? valueText
                : MmWrap(
                    spacing: MmSpace.s2,
                    runSpacing: MmSpace.s1,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      valueText,
                      MmNoControls(
                        summary:
                            'The trailing widget of an MmDetailRow holds a '
                            'control.',
                        description:
                            'A detail row is one node for screen readers, '
                            'read with its trailing widget, so a button or '
                            'field there would be merged into the row and '
                            'could not be reached.',
                        hint:
                            'Pass the control as the action of the row: it '
                            'stays a separate button at the end of the row.',
                        child: trailing,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    if (action == null) return row;
    // Beside the row while both fit; otherwise under it, at the end edge,
    // so the label and value keep the whole width.
    return MmReflow(start: row, end: action, stackedAtEnd: true);
  }
}
