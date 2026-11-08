import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';

/// How much an insight asks of the landlord, most first.
enum InsightLevel {
  /// Money or the law is at risk: act now.
  alert,

  /// Worth acting on soon.
  warning,

  /// Worth knowing.
  info,

  /// Good news.
  good,
}

/// One insight card (INS-04): a finding about the portfolio, with the
/// figures that support it. The app words each kind in both languages.
@immutable
sealed class Insight {
  const new(this.level);

  final InsightLevel level;
}

/// The share of this month's dues paid so far.
final class CollectionInsight extends Insight {
  const new(super.level, {required this.rate, required this.unpaid});

  /// Paid over due, in basis points.
  final int rate;

  /// What fell due this month and is not paid.
  final Money unpaid;
}

/// Rent owed for more than 90 days: the hardest to recover.
final class LongArrearsInsight extends Insight {
  const new({required this.amount}) : super(InsightLevel.alert);

  final Money amount;
}

/// Rent increases due within 30 days, and increases missed.
final class IncrementInsight extends Insight {
  const new(super.level, {required this.upcoming, required this.missed});

  final List<IncrementDue> upcoming;
  final List<IncrementDue> missed;

  /// What the missed increases would add to the rent each month.
  Money get missedMonthly =>
      Money.sum([for (final i in missed) i.newRent - i.currentRent]);
}

/// Tenancies ending within 90 days.
final class ExpiringInsight extends Insight {
  const new(super.level, {required this.leases});

  /// The soonest first.
  final List<ExpiringLease> leases;
}

/// Tenancies not registered with the police, and those whose registration
/// was submitted and is not confirmed yet.
final class PoliceInsight extends Insight {
  const new(super.level, {required this.unregistered, required this.submitted});

  /// Not registered: the landlord still has to register them.
  final List<PolicePending> unregistered;

  /// Submitted and waiting for the police to confirm: the landlord has done
  /// what the law asks, whatever the deadline.
  final List<PolicePending> submitted;

  /// The unregistered tenancies past a law's deadline.
  int get pastLegalDeadline => [
    for (final p in unregistered)
      if (p.pastLegalDeadline) p,
  ].length;
}

/// Units standing empty: the rent they lose each month.
final class VacancyInsight extends Insight {
  const new({
    required this.vacant,
    required this.monthlyLoss,
    required this.longestDays,
  }) : super(InsightLevel.warning);

  final int vacant;

  /// The asking rent of the vacant units.
  final Money monthlyLoss;

  /// How long the longest-vacant unit has stood empty.
  final int longestDays;
}

/// Overdue rent larger than the deposits held: the deposits no longer
/// cover what tenants owe.
final class DepositCoverInsight extends Insight {
  const new({required this.held, required this.overdue})
    : super(InsightLevel.warning);

  final Money held;
  final Money overdue;

  /// Deposits held over overdue rent, in basis points (below 10000).
  int get cover => basisPointsOf(held, overdue, roundDown: true);
}

/// Utility bills unpaid: those in the landlord's name (the landlord is
/// liable, and the connection can be cut), those past due, and
/// protected-tariff meters near or over 200 units.
final class UtilityRiskInsight extends Insight {
  const new(
    super.level, {
    required this.arrears,
    required this.overTariff,
    required this.nearTariff,
  });

  final UtilityArrears arrears;
  final int overTariff;
  final int nearTariff;
}

/// This month's expenses well above the average of the three before.
final class ExpenseSpikeInsight extends Insight {
  const new({required this.thisMonth, required this.average})
    : super(InsightLevel.warning);

  final Money thisMonth;
  final Money average;

  /// This month over the average, in basis points (15000 is half again).
  int get ratio => basisPointsOf(thisMonth, average);
}

/// Units let for clearly less than the asking rent the landlord set.
final class UnderpricedInsight extends Insight {
  const new({required this.units}) : super(InsightLevel.info);

  /// The largest gap first.
  final List<RentRollEntry> units;

  /// What the rents fall short of the asking rents each month.
  Money get monthlyGap =>
      Money.sum([for (final u in units) u.askingRent! - u.monthlyRent]);
}

/// Cash held by caretakers (members who are not owners), and how much of
/// this month's money came in cash.
final class CashInsight extends Insight {
  const new(
    super.level, {
    required this.holders,
    required this.held,
    this.cashShare,
  });

  /// Members other than owners holding cash, the most first.
  final List<CashPosition> holders;
  final Money held;

  /// Cash over all money received this month, in basis points.
  final int? cashShare;
}

/// [part] over [whole] in basis points, rounded half up (or down with
/// [roundDown]), for amounts of zero or more and a positive [whole].
///
/// Computed with [BigInt]: on the web an `int` is a double, exact only to
/// 2^53, and a paisa amount times 10000 can exceed that (Money.maxValue
/// times 10000 is about 10^18), so plain arithmetic would answer differently
/// on the web than on a phone.
int basisPointsOf(Money part, Money whole, {bool roundDown = false}) {
  assert(!part.isNegative && whole.isPositive, 'a share of a positive whole');
  final numerator = BigInt.from(part.paisa) * BigInt.from(10000);
  final denominator = BigInt.from(whole.paisa);
  return (roundDown
          ? numerator ~/ denominator
          : (numerator * BigInt.two + denominator) ~/
                (denominator * BigInt.two))
      .toInt();
}

/// Whether [part] is at least [basisPoints] of [whole], exactly (see
/// [basisPointsOf]).
bool atLeastShare(Money part, Money whole, int basisPoints) =>
    BigInt.from(part.paisa) * BigInt.from(10000) >=
    BigInt.from(whole.paisa) * BigInt.from(basisPoints);

/// When an insight speaks up.
abstract final class InsightThresholds {
  /// A collection rate at or above this is good news.
  static const goodCollection = 9000;

  /// A collection rate below this needs action now. Between the two, the
  /// month's figures say enough without a card.
  static const poorCollection = 5000;

  /// A tenancy ending within this many days needs a decision now.
  static const expiringSoonDays = 30;

  /// Expenses at this ratio of the trailing average are a spike.
  static const expenseSpike = 15000;

  /// A rent this much below the asking rent is underpriced.
  static const underpricedGap = 1000;

  /// More of the month's money than this in cash is a lot to carry.
  static const highCashShare = 5000;
}

/// The insight cards for [dashboard] (INS-04), the most pressing first.
/// [positions] and [rentRoll], read beside it, add the caretakers' cash
/// and underpriced units when they are known.
List<Insight> insightsFor(
  Dashboard dashboard, {
  List<CashPosition>? positions,
  List<RentRollEntry>? rentRoll,
}) {
  final month = dashboard.month;
  final insights = <Insight>[];

  if (dashboard.outstanding.over90.isPositive) {
    insights.add(LongArrearsInsight(amount: dashboard.outstanding.over90));
  }

  // The month's figures above the cards already say the rate and what is
  // still to collect: a card only adds something when the month is going
  // very well or badly.
  if (month.collectionRate case final rate? when month.expected.isPositive) {
    final level = rate >= InsightThresholds.goodCollection
        ? InsightLevel.good
        : rate < InsightThresholds.poorCollection
        ? InsightLevel.alert
        : null;
    if (level != null) {
      insights.add(CollectionInsight(level, rate: rate, unpaid: month.unpaid));
    }
  }

  if (dashboard.police.isNotEmpty) {
    final unregistered = [
      for (final p in dashboard.police)
        if (p.status == PoliceStatus.pending) p,
    ];
    final submitted = [
      for (final p in dashboard.police)
        if (p.status != PoliceStatus.pending) p,
    ];
    insights.add(
      PoliceInsight(
        unregistered.any((p) => p.pastLegalDeadline)
            ? InsightLevel.alert
            : unregistered.isNotEmpty
            ? InsightLevel.warning
            : InsightLevel.info,
        unregistered: unregistered,
        submitted: submitted,
      ),
    );
  }

  // A missed increase is already late: the rent it should add is lost
  // every month until it is made.
  if (dashboard.incrementsUpcoming.isNotEmpty ||
      dashboard.incrementsMissed.isNotEmpty) {
    insights.add(
      IncrementInsight(
        dashboard.incrementsMissed.isEmpty
            ? InsightLevel.info
            : InsightLevel.alert,
        upcoming: dashboard.incrementsUpcoming,
        missed: dashboard.incrementsMissed,
      ),
    );
  }

  if (dashboard.expiring.isNotEmpty) {
    final soon = dashboard.expiring.any(
      (l) => l.daysLeft <= InsightThresholds.expiringSoonDays,
    );
    insights.add(
      ExpiringInsight(
        soon ? InsightLevel.warning : InsightLevel.info,
        leases: dashboard.expiring,
      ),
    );
  }

  final overdue = dashboard.outstanding.overdue;
  if (overdue.isPositive && dashboard.deposits.held < overdue) {
    insights.add(
      DepositCoverInsight(held: dashboard.deposits.held, overdue: overdue),
    );
  }

  if (dashboard.occupancy.vacant > 0) {
    insights.add(
      VacancyInsight(
        vacant: dashboard.occupancy.vacant,
        monthlyLoss: dashboard.occupancy.vacantAskingRent,
        longestDays: dashboard.vacantUnits.fold(
          0,
          (longest, unit) =>
              unit.vacantDays > longest ? unit.vacantDays : longest,
        ),
      ),
    );
  }

  final utilities = dashboard.utilities;
  final overTariff = [
    for (final h in dashboard.highUsage)
      if (h.crossed) h,
  ].length;
  final nearTariff = dashboard.highUsage.length - overTariff;
  if (utilities.unpaidInLandlordNameCount > 0 ||
      utilities.overdueCount > 0 ||
      dashboard.highUsage.isNotEmpty) {
    insights.add(
      UtilityRiskInsight(
        utilities.unpaidInLandlordNameCount > 0 || utilities.overdueCount > 0
            ? InsightLevel.alert
            : InsightLevel.warning,
        arrears: utilities,
        overTariff: overTariff,
        nearTariff: nearTariff,
      ),
    );
  }

  final average = dashboard.expensesTrailingAverage;
  if (average.isPositive &&
      atLeastShare(
        dashboard.expensesThisMonth,
        average,
        InsightThresholds.expenseSpike,
      )) {
    insights.add(
      ExpenseSpikeInsight(
        thisMonth: dashboard.expensesThisMonth,
        average: average,
      ),
    );
  }

  if (rentRoll != null) {
    final underpriced =
        [
          for (final entry in rentRoll)
            if (entry.askingRent case final asking?
                when asking.isPositive &&
                    asking > entry.monthlyRent &&
                    atLeastShare(
                      asking - entry.monthlyRent,
                      asking,
                      InsightThresholds.underpricedGap,
                    ))
              entry,
        ]..sort(
          (a, b) => (b.askingRent! - b.monthlyRent).compareTo(
            a.askingRent! - a.monthlyRent,
          ),
        );
    if (underpriced.isNotEmpty) {
      insights.add(UnderpricedInsight(units: underpriced));
    }
  }

  final cash = month.byMethod[PaymentMethod.cash] ?? Money.zero;
  final cashShare = month.cashReceived.isPositive
      ? basisPointsOf(cash, month.cashReceived)
      : null;
  final holders = [
    for (final p in positions ?? const <CashPosition>[])
      if (p.role != MemberRole.owner && p.inHand.isPositive) p,
  ]..sort((a, b) => b.inHand.compareTo(a.inHand));
  if (holders.isNotEmpty ||
      (cashShare != null && cashShare >= InsightThresholds.highCashShare)) {
    insights.add(
      CashInsight(
        holders.isEmpty ? InsightLevel.info : InsightLevel.warning,
        holders: holders,
        held: Money.sum([for (final h in holders) h.inHand]),
        cashShare: cashShare,
      ),
    );
  }

  // Most pressing first; the order above breaks ties.
  final ordered = [...insights.indexed]
    ..sort((a, b) {
      final level = a.$2.level.index.compareTo(b.$2.level.index);
      return level != 0 ? level : a.$1.compareTo(b.$1);
    });
  return [for (final (_, insight) in ordered) insight];
}
