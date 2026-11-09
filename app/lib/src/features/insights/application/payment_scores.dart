import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:mm_core/mm_core.dart';

/// A tenant's payment score (INS-03), from 0 to 100, with what it is made
/// of, so it can be explained:
///
/// `50·onTime + 30·(1 − min(avgDaysLate, 30)/30)
///   + 20·(1 − min(arrears/rent, 3)/3)`
///
/// over the rent dues of the last 12 months (`get_payment_facts`):
///
/// - a due is **on time** when it was settled by its last day of grace
///   (its due date plus the tenancy's grace days);
/// - a due counts once it is settled, or once its grace has run out
///   unpaid; one still within its grace is not judged yet, and one waived
///   in full is left out;
/// - **days late** are counted from the last day of grace to the day it was
///   settled, or to today while it is unpaid; [averageDaysLate] is over
///   every due counted (0 for those on time);
/// - **arrears** are the rent unpaid past its grace, against the monthly
///   rent of the tenant's latest tenancy.
@immutable
final class PaymentScore {
  const new({
    required this.score,
    required this.duesCounted,
    required this.onTime,
    required this.averageDaysLate,
    required this.arrears,
    required this.monthlyRent,
  });

  /// From 0 to 100.
  final int score;

  /// The rent dues the score is made of.
  final int duesCounted;

  /// How many of them were settled by the end of their grace.
  final int onTime;

  /// Days late on average, to one decimal place (in tenths: 25 is 2.5).
  final int averageDaysLate;

  /// Rent unpaid past its grace.
  final Money arrears;
  final Money monthlyRent;

  /// [arrears] in months of rent, in tenths (15 is 1.5 months).
  int get arrearsMonths => monthlyRent.isPositive
      ? (arrears.paisa * 10 / monthlyRent.paisa).round()
      : 0;

  @override
  bool operator ==(Object other) =>
      other is PaymentScore &&
      other.score == score &&
      other.duesCounted == duesCounted &&
      other.onTime == onTime &&
      other.averageDaysLate == averageDaysLate &&
      other.arrears == arrears &&
      other.monthlyRent == monthlyRent;

  @override
  int get hashCode => Object.hash(
    score,
    duesCounted,
    onTime,
    averageDaysLate,
    arrears,
    monthlyRent,
  );
}

/// The payment score of each tenant in [facts] on [today], by tenant id.
/// A tenant with no due to judge yet has none.
Map<String, PaymentScore> paymentScores(
  List<PaymentFact> facts,
  CalendarDate today,
) {
  final byTenant = <String, List<PaymentFact>>{};
  for (final fact in facts) {
    (byTenant[fact.tenantId] ??= []).add(fact);
  }
  return {
    for (final MapEntry(key: tenant, value: dues) in byTenant.entries)
      tenant: ?paymentScoreOf(dues, today),
  };
}

/// The score of one tenant's [dues] on [today] (see [PaymentScore]), or
/// null when none can be judged yet.
PaymentScore? paymentScoreOf(List<PaymentFact> dues, CalendarDate today) {
  var counted = 0;
  var onTime = 0;
  var daysLate = 0;
  var arrears = Money.zero;
  for (final due in dues) {
    // Waived in full: nothing was asked for.
    if (!(due.amount - due.waived).isPositive) continue;
    final lastDay = due.dueDate.addDays(due.graceDays);
    final settledOn = due.settledOn;
    if (!due.outstanding.isPositive) {
      // Settled without a payment date (no payment took it): cannot judge.
      if (settledOn == null) continue;
      counted++;
      final late = settledOn.differenceInDays(lastDay);
      if (late <= 0) {
        onTime++;
      } else {
        daysLate += late;
      }
    } else if (today.isAfter(lastDay)) {
      counted++;
      daysLate += today.differenceInDays(lastDay);
      arrears += due.outstanding;
    }
  }
  if (counted == 0) return null;
  final latest = dues.reduce((a, b) => b.dueDate.isAfter(a.dueDate) ? b : a);
  final rent = latest.monthlyRent;
  final average = daysLate / counted;
  final share = onTime / counted;
  final owed = rent.isPositive ? arrears.paisa / rent.paisa : 0.0;
  final score =
      50 * share +
      30 * (1 - (average < 30 ? average : 30) / 30) +
      20 * (1 - (owed < 3 ? owed : 3) / 3);
  return PaymentScore(
    score: score.round().clamp(0, 100),
    duesCounted: counted,
    onTime: onTime,
    averageDaysLate: (average * 10).round(),
    arrears: arrears,
    monthlyRent: rent,
  );
}
