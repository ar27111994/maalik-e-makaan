import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How large an [MmAmount] is set.
enum MmAmountSize {
  /// The Latin body-small size (14 px): amounts in captions and dense rows.
  small,

  /// The amount style (16 px, semibold): amounts in lists, chips and forms.
  regular,

  /// The large amount style (32 px, bold): the one big figure of a screen,
  /// such as the total due.
  large,
}

/// The colour an [MmAmount] is set in. A tone adds emphasis to an amount
/// whose status is said elsewhere (an `MmStatusBadge`, a row's words): it
/// never carries the status alone.
enum MmAmountTone {
  /// Ink: the default for amounts.
  ink,

  /// Muted ink: amounts that are context, not the point ("of Rs 45,000").
  muted,

  /// The paid colour: settled amounts.
  paid,

  /// The overdue colour: amounts past their grace period.
  overdue,

  /// The credit colour: a tenant's advance.
  credit;

  /// The colour of this tone in [colors].
  Color colorIn(MmColorTokens colors) => switch (this) {
    MmAmountTone.ink => colors.ink,
    MmAmountTone.muted => colors.inkMuted,
    MmAmountTone.paid => colors.paid,
    MmAmountTone.overdue => colors.overdue,
    MmAmountTone.credit => colors.credit,
  };
}

/// A rupee amount, formatted the way the landlord chose (Western or
/// lakh/crore grouping, set once with `MmFormats`) in the Latin face with
/// tabular figures, in both languages.
///
/// An amount never breaks inside its number: it stays on one line, and when
/// its space is too narrow it scales down to fit rather than wrapping or
/// overflowing. A negative amount shows a minus sign, unless [creditLabel]
/// is given: then it shows the absolute amount followed by that word ("Rs
/// 5,000 credit") in the credit colour, because a tenant's advance should
/// read as credit, not as a minus sign alone.
///
/// Screen readers hear the plain number and the currency ("125000 rupees",
/// "5000 rupees credit"), since grouped figures such as 1,25,000 are read
/// out unreliably.
///
/// Don't use it for an amount the landlord types (use `MmMoneyField`).
///
/// ```dart
/// MmAmount(
///   amount: tenant.balance,
///   size: MmAmountSize.large,
///   creditLabel: l10n.credit,
/// )
/// ```
class MmAmount extends StatelessWidget {
  /// Shows [amount].
  const new({
    required this.amount,
    this.size = MmAmountSize.regular,
    this.tone = MmAmountTone.ink,
    this.creditLabel,
    this.textAlign,
    super.key,
  });

  /// The amount shown.
  final Money amount;

  /// How large the amount is set.
  final MmAmountSize size;

  /// The colour of the amount. A credit shown with [creditLabel] always
  /// takes the credit tone.
  final MmAmountTone tone;

  /// The word that follows a negative amount in place of its minus sign
  /// ("credit", "advance"), from the app's localisations. When null a
  /// negative amount shows a minus sign.
  final String? creditLabel;

  /// Where the amount sits when it is given more width than it needs.
  /// Defaults to the start edge; lists of money align amounts to the end.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final format = MmFormats.moneyOf(context);
    final creditLabel = this.creditLabel;
    final credit = creditLabel != null && amount.isNegative;
    final shown = credit ? amount.abs() : amount;
    final words = credit ? ' $creditLabel' : '';
    final rupees = MmLocalizations.of(context).rupees;
    final colors = context.mm.colors;
    final style = _style(context).copyWith(
      color: (credit ? MmAmountTone.credit : tone).colorIn(colors),
      // The Urdu currency word and credit label are set in Nastaliq: the
      // Latin face has no Arabic-script letters.
      fontFamilyFallback: const [MmFontFamily.urdu],
      package: 'mm_ui',
    );
    return Semantics(
      container: true,
      label: '${spokenNumber(shown, format)} $rupees$words',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: _alignment(textAlign ?? TextAlign.start),
        child: Text(
          '${_isolated(format.format(shown))}$words',
          style: style,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }

  /// The style of [size]: always the Latin face with tabular figures.
  TextStyle _style(BuildContext context) => switch (size) {
    MmAmountSize.large => context.mm.amountLarge,
    MmAmountSize.regular => context.mm.amount,
    MmAmountSize.small => MmTypeScale.latinBodySmall.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  };

  /// Where the amount sits for [align] when it is narrower than its box.
  static AlignmentGeometry _alignment(TextAlign align) => switch (align) {
    TextAlign.start || TextAlign.justify => AlignmentDirectional.centerStart,
    TextAlign.end => AlignmentDirectional.centerEnd,
    TextAlign.center => Alignment.center,
    // The caller asked for a physical side; honour it.
    TextAlign.left =>
      Alignment.centerLeft, // design-lint: allow explicit TextAlign.left
    TextAlign.right =>
      Alignment.centerRight, // design-lint: allow explicit TextAlign.right
  };

  /// [formatted] with a left-to-right mark before a leading minus sign, so
  /// in right-to-left text the sign stays before the digits ("-5,000")
  /// instead of drifting to their other side. Other amounts are unchanged.
  static String _isolated(String formatted) =>
      formatted.startsWith('-') ? '\u200E$formatted' : formatted;

  /// [amount] as a screen reader should say it: the plain number without
  /// grouping, with paisa only when [format] shows them ("125000",
  /// "1500.50", "-5000").
  static String spokenNumber(Money amount, MoneyFormat format) {
    final shown = format.paisa == PaisaDisplay.never
        ? amount.roundToRupee()
        : amount;
    return shown.hasPaisa ? shown.toDecimalString() : '${shown.wholeRupees}';
  }
}
