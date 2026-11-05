import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/display/mm_reflow.dart';
import 'package:mm_ui/src/components/display/mm_user_text.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A label and its value on one line, as on a raseed: "Monthly rent ...
/// Rs 45,000".
///
/// The [label] sits at the start in muted ink, the [value] at the end in ink
/// with tabular figures, so a column of rows lines its figures up. When the
/// two do not fit on one line (a narrow screen, large text, a long address)
/// the value moves under the label, aligned to the start, and wraps; a
/// [trailing] widget that does not fit beside the value goes under it. Set
/// [emphasized] for a total. The row is one node for screen readers:
/// "Monthly rent, Rs 45,000" (or [semanticValue] in place of the value).
///
/// Use rows inside an `MmCard` or a receipt to show a record's details.
/// Don't use it for a row that opens something (use `MmListTile`) or for a
/// value the landlord edits (use a field).
///
/// ```dart
/// final format = MmFormats.moneyOf(context);
/// MmDetailRow(
///   label: l10n.monthlyRent,
///   value: format.format(lease.rent),
///   semanticValue: '${MmAmount.spokenNumber(lease.rent, format)} '
///       '${MmLocalizations.of(context).rupees}',
///   userData: false,
/// )
/// ```
class MmDetailRow extends StatelessWidget {
  /// Creates a row showing [value] for [label].
  const new({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.userData = true,
    this.semanticValue,
    this.trailing,
    super.key,
  });

  /// What the value is ("Monthly rent"), from the app's localisations.
  final String label;

  /// The value ("Rs 45,000", "Ali Raza", "35202-1234567-1").
  final String value;

  /// Whether the row is a total: label and value in the semibold title
  /// style, both in ink.
  final bool emphasized;

  /// Whether [value] is the landlord's data (a name, an address, a CNIC).
  /// In the Urdu UI such a value written in Latin script is set in the
  /// Latin face. Pass false for words from the app's localisations.
  final bool userData;

  /// How a screen reader says the value when that differs from how it
  /// looks: a grouped amount as "45000 rupees" (see
  /// `MmAmount.spokenNumber`), a date in words.
  final String? semanticValue;

  /// A widget after the value, such as an `MmStatusBadge` or a copy button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final labelStyle = emphasized
        ? text.titleMedium!.copyWith(color: colors.ink)
        : text.bodyMedium!.copyWith(color: colors.inkMuted);
    final valueStyle = (emphasized ? text.titleMedium! : text.bodyLarge!)
        .copyWith(
          color: colors.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final trailing = this.trailing;
    final Widget valueText = ExcludeSemantics(
      child: Text(
        value,
        style: userData ? mm.userStyleFor(value, valueStyle) : valueStyle,
      ),
    );
    return MergeSemantics(
      child: Semantics(
        label: '$label, ${semanticValue ?? value}',
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: MmSpace.s2),
          child: MmReflow(
            alignment: MmReflowAlignment.baseline,
            start: ExcludeSemantics(child: Text(label, style: labelStyle)),
            // The trailing widget wraps under the value rather than
            // squeezing it: a value never breaks to make room for it.
            end: trailing == null
                ? valueText
                : Wrap(
                    spacing: MmSpace.s2,
                    runSpacing: MmSpace.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [valueText, trailing],
                  ),
          ),
        ),
      ),
    );
  }
}
