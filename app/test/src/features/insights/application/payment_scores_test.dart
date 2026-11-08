import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/insights/application/payment_scores.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/harness.dart';

PaymentFact _due(
  String dueDate, {
  num amount = 50000,
  num outstanding = 0,
  num waived = 0,
  String? settledOn,
  String tenant = 't1',
  num rent = 50000,
}) => PaymentFact.fromRow(
  factJson(
    leaseId: 'l-$tenant',
    tenantId: tenant,
    dueDate: dueDate,
    amount: amount,
    outstanding: outstanding,
    waived: waived,
    settledOn: settledOn,
    rent: rent,
  ),
);

void main() {
  final today = CalendarDate(2026, 11, 7);

  test('always on time and owing nothing is 100', () {
    final score = paymentScoreOf([
      _due('2026-09-01', settledOn: '2026-09-01'),
      // On the last day of grace (due date plus 5 days) is on time.
      _due('2026-10-01', settledOn: '2026-10-06'),
    ], today)!;
    expect(score.score, 100);
    expect(score.duesCounted, 2);
    expect(score.onTime, 2);
    expect(score.averageDaysLate, 0);
    expect(score.arrears, Money.zero);
    expect(score.arrearsMonths, 0);
  });

  test('follows the formula of INS-03', () {
    // One on time, one 10 days late, one unpaid 30 days past grace.
    final score = paymentScoreOf([
      _due('2026-08-01', settledOn: '2026-08-03'),
      _due('2026-09-01', settledOn: '2026-09-16'),
      _due('2026-10-03', outstanding: 25000),
    ], today)!;
    // Late days: 0, 10 and 30 (7 Nov less 8 Oct); average 13.33.
    expect(score.averageDaysLate, 133);
    expect(score.arrears, const Money.fromRupees(25000));
    expect(score.arrearsMonths, 5);
    const expected =
        50 * (1 / 3) + 30 * (1 - (40 / 3) / 30) + 20 * (1 - 0.5 / 3);
    expect(score.score, expected.round());
  });

  test('caps days late at 30 and arrears at three months', () {
    final score = paymentScoreOf([
      _due('2026-01-01', outstanding: 200000, amount: 200000),
    ], today)!;
    expect(score.onTime, 0);
    expect(score.arrearsMonths, 40);
    expect(score.score, 0);
  });

  test('dues not yet judged or waived in full are left out', () {
    expect(
      paymentScoreOf([
        // Still within its grace.
        _due('2026-11-05', outstanding: 50000),
        // Waived in full.
        _due('2026-10-01', waived: 50000),
        // Settled with no payment date (nothing to judge by).
        _due('2026-09-01'),
      ], today),
      isNull,
    );
  });

  test('the latest tenancy rent measures the arrears', () {
    final score = paymentScoreOf([
      _due('2026-09-01', outstanding: 40000, rent: 40000),
      _due('2026-10-01', settledOn: '2026-10-02', rent: 80000),
    ], today)!;
    expect(score.monthlyRent, const Money.fromRupees(80000));
    expect(score.arrearsMonths, 5);
  });

  test('without a rent, arrears count as nothing owed in months', () {
    final score = paymentScoreOf([
      _due('2026-09-01', outstanding: 5000, rent: 0),
    ], today)!;
    expect(score.arrearsMonths, 0);
  });

  test('scores each tenant of a portfolio', () {
    final scores = paymentScores([
      for (final row in factsJson()) PaymentFact.fromRow(row),
      _due('2026-11-05', outstanding: 50000, tenant: 'new'),
    ], today);
    expect(scores.keys, unorderedEquals([aliRaza.id, techCorp.id]));
    expect(scores[techCorp.id]!.score, 100);
    expect(scores[aliRaza.id]!.score, 22);
    expect(scores[aliRaza.id], isNot(scores[techCorp.id]));
    final again = paymentScoreOf([
      for (final row in factsJson().take(4)) PaymentFact.fromRow(row),
    ], today);
    expect(again, scores[aliRaza.id]);
    const base = PaymentScore(
      score: 50,
      duesCounted: 4,
      onTime: 2,
      averageDaysLate: 30,
      arrears: Money.fromRupees(100),
      monthlyRent: Money.fromRupees(1000),
    );
    for (final other in [
      const PaymentScore(
        score: 50,
        duesCounted: 5,
        onTime: 2,
        averageDaysLate: 30,
        arrears: Money.fromRupees(100),
        monthlyRent: Money.fromRupees(1000),
      ),
      const PaymentScore(
        score: 50,
        duesCounted: 4,
        onTime: 3,
        averageDaysLate: 30,
        arrears: Money.fromRupees(100),
        monthlyRent: Money.fromRupees(1000),
      ),
      const PaymentScore(
        score: 50,
        duesCounted: 4,
        onTime: 2,
        averageDaysLate: 31,
        arrears: Money.fromRupees(100),
        monthlyRent: Money.fromRupees(1000),
      ),
      const PaymentScore(
        score: 50,
        duesCounted: 4,
        onTime: 2,
        averageDaysLate: 30,
        arrears: Money.fromRupees(101),
        monthlyRent: Money.fromRupees(1000),
      ),
      const PaymentScore(
        score: 50,
        duesCounted: 4,
        onTime: 2,
        averageDaysLate: 30,
        arrears: Money.fromRupees(100),
        monthlyRent: Money.fromRupees(1001),
      ),
    ]) {
      expect(other, isNot(base));
    }
    expect(
      scores[aliRaza.id]!.hashCode,
      paymentScoreOf([
        for (final row in factsJson().take(4)) PaymentFact.fromRow(row),
      ], today).hashCode,
    );
  });
}
