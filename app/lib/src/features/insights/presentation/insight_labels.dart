import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insight_rules.dart';
import 'package:maalik_e_makaan/src/features/insights/application/payment_scores.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// [basisPoints] as a percentage ("82%"), with [decimals] places when it
/// is not whole ("4.5%").
String percentText(AppLocalizations l10n, int basisPoints, {int decimals = 0}) {
  final value = basisPoints / 100;
  final shown = decimals == 0 || value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(decimals);
  return l10n.percentValue(shown);
}

/// A number in tenths as figures, without a trailing zero: 25 is "2.5",
/// 20 is "2".
String tenthsText(int tenths) =>
    tenths % 10 == 0 ? '${tenths ~/ 10}' : (tenths / 10).toStringAsFixed(1);

/// [amount] in the app's money format, for a sentence or a detail line:
/// its currency word and figures are joined by a no-break space, so they
/// never part at a line end (the whole amount wraps as one word). Only a
/// badge too narrow for a whole amount uses [wrappableAmount].
String moneyText(BuildContext context, Money amount) =>
    MmFormats.moneyOf(context).format(amount);

/// [amount] as screen readers say a figure: plain, without grouping.
String spokenFigure(BuildContext context, Money amount) =>
    MmFormats.spokenNumber(amount, MmFormats.moneyOf(context));

/// The badge word of an insight's [level].
String insightLevelLabel(AppLocalizations l10n, InsightLevel level) =>
    switch (level) {
      InsightLevel.alert => l10n.insightAlert,
      InsightLevel.warning => l10n.insightWarning,
      InsightLevel.info => l10n.insightInfo,
      InsightLevel.good => l10n.insightGood,
    };

/// The badge icon of an insight's [level]: a warning is about something
/// worth a look, not always about time, so it does not take the due-soon
/// clock.
IconData? insightLevelIcon(InsightLevel level) => switch (level) {
  InsightLevel.warning => MmIcons.warning,
  _ => null,
};

/// The status colour family of an insight's [level].
MmStatus insightStatus(InsightLevel level) => switch (level) {
  InsightLevel.alert => MmStatus.overdue,
  InsightLevel.warning => MmStatus.dueSoon,
  InsightLevel.info => MmStatus.neutral,
  InsightLevel.good => MmStatus.paid,
};

/// The name of a member holding cash, or their role when they have not
/// given a name ("Manager"), so a row or sentence never starts empty.
String holderName(AppLocalizations l10n, CashPosition position) {
  final name = position.fullName.trim();
  return name.isEmpty ? roleLabel(l10n, position.role) : position.fullName;
}

/// How late a tenant pays on average, in words: never, under a day, or
/// about how many whole days.
String averageLateText(AppLocalizations l10n, PaymentScore score) {
  final tenths = score.averageDaysLate;
  if (tenths == 0) return l10n.scoreNeverLate;
  if (tenths < 10) return l10n.scoreUnderADayLate;
  return l10n.scoreDaysLate((tenths / 10).round());
}

/// The word of a payment score's [band].
String scoreBandLabel(AppLocalizations l10n, MmScoreBand band) =>
    switch (band) {
      MmScoreBand.good => l10n.scoreBandGood,
      MmScoreBand.fair => l10n.scoreBandFair,
      MmScoreBand.poor => l10n.scoreBandPoor,
    };
