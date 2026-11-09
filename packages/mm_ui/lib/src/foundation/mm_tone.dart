import 'package:flutter/painting.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The colour families a component can take: cobalt, the four status
/// colours and a neutral, each with a strong colour, a tonal container and
/// a colour for words and icons on that container.
///
/// It is the one place these families map to colour roles, so a meter, a
/// timeline marker, a score band and a status chip in the same tone always
/// agree. A tone echoes what words say; it never carries a meaning alone.
///
/// Internal to mm_ui: any component family may use it.
enum MmTone {
  /// No particular state: a tenant moved in, a draft, an archived record.
  neutral,

  /// Cobalt: progress or an event with no status, such as units let or a
  /// lease signed.
  primary,

  /// Settled: rent or a bill paid.
  paid,

  /// Inside the reminder window; also warnings.
  dueSoon,

  /// Past the grace period; also errors.
  overdue,

  /// A tenant's advance or a refund; also information.
  credit;

  /// The strong colour of this tone in [colors]: a fill, a dot, an icon or
  /// words on the page.
  Color colorIn(MmColorTokens colors) => switch (this) {
    MmTone.neutral => colors.inkMuted,
    MmTone.primary => colors.primary,
    MmTone.paid => colors.paid,
    MmTone.dueSoon => colors.dueSoon,
    MmTone.overdue => colors.overdue,
    MmTone.credit => colors.credit,
  };

  /// The tonal fill of this tone in [colors]: a chip, a banner, a track.
  Color containerIn(MmColorTokens colors) => switch (this) {
    MmTone.neutral => colors.surfaceSunken,
    MmTone.primary => colors.primaryContainer,
    MmTone.paid => colors.paidContainer,
    MmTone.dueSoon => colors.dueSoonContainer,
    MmTone.overdue => colors.overdueContainer,
    MmTone.credit => colors.creditContainer,
  };

  /// The colour of words and icons on [containerIn] in [colors].
  Color onContainerIn(MmColorTokens colors) => switch (this) {
    MmTone.neutral => colors.ink,
    MmTone.primary => colors.onPrimaryContainer,
    MmTone.paid => colors.onPaidContainer,
    MmTone.dueSoon => colors.onDueSoonContainer,
    MmTone.overdue => colors.onOverdueContainer,
    MmTone.credit => colors.onCreditContainer,
  };
}
