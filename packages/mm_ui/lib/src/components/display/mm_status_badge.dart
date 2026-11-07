import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The state of a due, a payment or a record, with its colour roles and
/// default icon. Colour never carries a status alone: it always travels
/// with an icon and a word (see [MmStatusBadge]).
enum MmStatus {
  /// Settled: the rent or bill is paid.
  paid,

  /// Past its grace period; also errors.
  overdue,

  /// Inside the reminder window; also warnings.
  dueSoon,

  /// A tenant's advance or credit; also information.
  credit,

  /// No particular state: vacant, draft, archived.
  neutral;

  /// The strong colour of this status, for icons and text on the page.
  Color colorIn(MmColorTokens colors) => switch (this) {
    MmStatus.paid => colors.paid,
    MmStatus.overdue => colors.overdue,
    MmStatus.dueSoon => colors.dueSoon,
    MmStatus.credit => colors.credit,
    MmStatus.neutral => colors.inkMuted,
  };

  /// The tonal fill of this status, for badges and banners.
  Color containerIn(MmColorTokens colors) => switch (this) {
    MmStatus.paid => colors.paidContainer,
    MmStatus.overdue => colors.overdueContainer,
    MmStatus.dueSoon => colors.dueSoonContainer,
    MmStatus.credit => colors.creditContainer,
    MmStatus.neutral => colors.surfaceSunken,
  };

  /// The colour of words and icons on [containerIn].
  Color onContainerIn(MmColorTokens colors) => switch (this) {
    MmStatus.paid => colors.onPaidContainer,
    MmStatus.overdue => colors.onOverdueContainer,
    MmStatus.dueSoon => colors.onDueSoonContainer,
    MmStatus.credit => colors.onCreditContainer,
    MmStatus.neutral => colors.ink,
  };

  /// The icon this status shows unless a component is given another.
  IconData get icon => switch (this) {
    MmStatus.paid => MmIcons.success,
    MmStatus.overdue => MmIcons.error,
    MmStatus.dueSoon => MmIcons.dueDate,
    MmStatus.credit => MmIcons.deposit,
    MmStatus.neutral => MmIcons.info,
  };
}

/// A status chip: the status's container colour, an icon and a word
/// ("Paid", "Overdue 12 days"), so the status never relies on colour alone.
///
/// The [label] comes from the app's localisations and says the status in
/// words. Long labels and large text wrap onto more lines rather than
/// overflowing; the icon stays on the first line. Screen readers hear only
/// the label: the icon is decorative.
///
/// Use it in list rows, cards and detail rows. Don't use it as a filter or
/// a choice (use `MmFilterChips`) or for a message about the whole screen
/// (use `MmBanner`).
///
/// ```dart
/// MmStatusBadge(status: MmStatus.overdue, label: l10n.overdueDays(12))
/// ```
class MmStatusBadge extends StatelessWidget {
  /// Creates a badge saying [label] for [status].
  const new({required this.status, required this.label, this.icon, super.key});

  /// The status shown, which picks the colours and the default icon.
  final MmStatus status;

  /// The status in words ("Paid", "Due in 3 days").
  final String label;

  /// An icon in place of the status's default one.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final onContainer = status.onContainerIn(colors);
    // One node the size of the badge, reading the word.
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: status.containerIn(colors),
          borderRadius: const BorderRadius.all(Radius.circular(MmRadius.xs)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: MmSpace.s2,
            vertical: MmSpace.sHalf,
          ),
          child: MmIconLabel(
            icon: icon ?? status.icon,
            label: label,
            iconColor: onContainer,
            style: Theme.of(context).textTheme.labelLarge!
                .copyWith(color: onContainer),
            // Wrapped words keep the badge as wide as its longest line,
            // without empty fill after it.
            textWidthBasis: TextWidthBasis.longestLine,
          ),
        ),
      ),
    );
  }
}
