import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insight_rules.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/harness.dart';

Dashboard _dashboard([void Function(Map<String, Object?> json)? edit]) {
  final json = dashboardJson();
  edit?.call(json);
  return Dashboard.fromJson(json);
}

Map<String, Object?> _object(Map<String, Object?> json, String key) =>
    json[key]! as Map<String, Object?>;

T _one<T>(List<Insight> insights) => insights.whereType<T>().single;

void main() {
  final positions = FakeHandoverRepository().positions;
  final roll = [for (final r in rentRollJson()) RentRollEntry.fromRow(r)];

  test('every finding of the full dashboard, most pressing first', () {
    final insights = insightsFor(
      _dashboard(),
      positions: positions,
      rentRoll: roll,
    );
    expect(insights.map((i) => i.runtimeType), [
      LongArrearsInsight,
      PoliceInsight,
      IncrementInsight,
      UtilityRiskInsight,
      ExpiringInsight,
      DepositCoverInsight,
      VacancyInsight,
      ExpenseSpikeInsight,
      CashInsight,
      UnderpricedInsight,
    ]);
    expect(
      insights.map((i) => i.level),
      orderedEquals(
        <InsightLevel>[...insights.map((i) => i.level)]
          ..sort((a, b) => a.index.compareTo(b.index)),
      ),
    );
    expect(
      _one<LongArrearsInsight>(insights).amount,
      const Money.fromRupees(25000),
    );
    // 65% collected: the month's figures say it, with no card.
    expect(insights.whereType<CollectionInsight>(), isEmpty);
    final police = _one<PoliceInsight>(insights);
    expect(police.level, InsightLevel.alert);
    expect(police.unregistered.single.leaseId, techLeaseId);
    expect(police.submitted.single.leaseId, sanaLeaseId);
    expect(police.pastLegalDeadline, 1);
    final increments = _one<IncrementInsight>(insights);
    // A missed increase is already late.
    expect(increments.level, InsightLevel.alert);
    expect(increments.missedMonthly, const Money.fromRupees(8500));
    expect(_one<ExpiringInsight>(insights).level, InsightLevel.warning);
    expect(_one<DepositCoverInsight>(insights).cover, 8461);
    final vacancy = _one<VacancyInsight>(insights);
    expect(vacancy.monthlyLoss, const Money.fromRupees(40000));
    expect(vacancy.longestDays, 45);
    final utilities = _one<UtilityRiskInsight>(insights);
    expect(utilities.level, InsightLevel.alert);
    expect((utilities.overTariff, utilities.nearTariff), (1, 0));
    expect(_one<ExpenseSpikeInsight>(insights).ratio, 21333);
    final underpriced = _one<UnderpricedInsight>(insights);
    // Indus Tech's 120,000 is within 10% of 125,000: not underpriced.
    expect(underpriced.units.single.leaseId, aliLease.id);
    expect(underpriced.monthlyGap, const Money.fromRupees(15000));
    final cash = _one<CashInsight>(insights);
    expect(cash.holders.single.fullName, 'Bilal Ahmed');
    expect(cash.held, const Money.fromRupees(80500));
    expect(cash.cashShare, 5429);
    expect(cash.level, InsightLevel.warning);
  });

  test('a quiet portfolio has nothing to say', () {
    final quiet = Dashboard.fromJson(quietDashboardJson());
    expect(insightsFor(quiet), isEmpty);
    expect(
      insightsFor(quiet, positions: const [], rentRoll: const []),
      isEmpty,
    );
  });

  test('the collection rate speaks up only when very good or poor', () {
    InsightLevel? levelAt(double rate) => insightsFor(
      _dashboard((j) => _object(j, 'month')['collection_rate'] = rate),
    ).whereType<CollectionInsight>().singleOrNull?.level;
    expect(levelAt(1), InsightLevel.good);
    expect(levelAt(0.9), InsightLevel.good);
    expect(levelAt(0.8999), isNull);
    expect(levelAt(0.6), isNull);
    expect(levelAt(0.5), isNull);
    expect(levelAt(0.4999), InsightLevel.alert);
    expect(levelAt(0.2), InsightLevel.alert);
  });

  group('police registration', () {
    List<Map<String, Object?>> rows(Map<String, Object?> j) =>
        (j['police_pending']! as List).cast<Map<String, Object?>>();

    test("one submitted past a law's deadline raises no alarm", () {
      // Both submitted, both past a statutory deadline.
      final police = _one<PoliceInsight>(
        insightsFor(
          _dashboard((j) {
            for (final p in rows(j)) {
              p
                ..['status'] = 'submitted'
                ..['overdue'] = true
                ..['statutory'] = true;
            }
          }),
        ),
      );
      expect(police.level, InsightLevel.info);
      expect(police.unregistered, isEmpty);
      expect(police.submitted, hasLength(2));
      expect(police.pastLegalDeadline, 0);
      expect(police.submitted.first.pastLegalDeadline, isFalse);
    });

    test('only those still to register are late', () {
      final police = _one<PoliceInsight>(
        insightsFor(
          _dashboard((j) {
            final [indus, sana] = rows(j);
            indus['overdue'] = false;
            sana
              ..['overdue'] = true
              ..['statutory'] = true;
          }),
        ),
      );
      expect(police.level, InsightLevel.warning);
      expect(police.pastLegalDeadline, 0);
      expect(police.unregistered.single.pastLegalDeadline, isFalse);
    });

    test("a date passed under the app's own reminder is not the law's", () {
      final police = _one<PoliceInsight>(
        insightsFor(
          _dashboard((j) {
            rows(j).first['statutory'] = false;
          }),
        ),
      );
      expect(police.level, InsightLevel.warning);
      expect(police.pastLegalDeadline, 0);
    });
  });

  group('shares of money', () {
    const max = Money.maxValue;
    final belowMax = max - const Money.fromPaisa(1);

    test('round down exactly where a double rounds up', () {
      // 9998.99999999999999… basis points: a double division says 9999.
      const held = Money.fromPaisa(99989999999999);
      expect(basisPointsOf(held, max, roundDown: true), 9998);
      expect(const DepositCoverInsight(held: held, overdue: max).cover, 9998);
    });

    test('are exact for the largest amounts', () {
      // 99,999,999,999,998 over 99,999,999,999,999 paisa: 9999.99999…
      // basis points; a double rounds it up to 10000.
      expect(basisPointsOf(belowMax, max, roundDown: true), 9999);
      expect(basisPointsOf(belowMax, max), 10000);
      expect(basisPointsOf(max, belowMax, roundDown: true), 10000);
      expect(basisPointsOf(Money.zero, max), 0);
      expect(basisPointsOf(const Money.fromPaisa(1), max), 0);
      // Half a basis point rounds up.
      expect(
        basisPointsOf(const Money.fromPaisa(1), const Money.fromPaisa(20000)),
        1,
      );
      expect(
        basisPointsOf(
          const Money.fromPaisa(1),
          const Money.fromPaisa(20000),
          roundDown: true,
        ),
        0,
      );
    });

    test('meet a threshold exactly at its edge', () {
      // 1.5 times an amount whose times 15000 passes 2^53.
      const average = Money.fromPaisa(66666666666666);
      const spike = Money.maxValue;
      expect(atLeastShare(spike, average, 15000), isTrue);
      expect(
        atLeastShare(spike - const Money.fromPaisa(1), average, 15000),
        isFalse,
      );
      expect(atLeastShare(Money.zero, max, 0), isTrue);
    });

    test('drive the expense spike for the largest amounts', () {
      final insights = insightsFor(
        _dashboard((j) {
          j['expenses'] = {
            'this_month': '999999999999.99',
            'trailing_3m_avg': '666666666666.66',
          };
        }),
      );
      expect(_one<ExpenseSpikeInsight>(insights).ratio, 15000);
    });
  });

  test('levels follow how pressing each finding is', () {
    final insights = insightsFor(
      _dashboard((j) {
        j['increments_missed'] = <Object?>[];
        ((j['leases_expiring']! as List).single as Map)['days_left'] = 60;
        for (final p
            in (j['police_pending']! as List).cast<Map<String, Object?>>()) {
          p['overdue'] = false;
        }
        _object(j, 'utilities')
          ..['unpaid_landlord_name_count'] = 0
          ..['overdue_count'] = 0;
        _object(j, 'month')['by_method'] = {'bank_transfer': 175000};
      }),
      positions: [
        for (final p in positions)
          if (p.role == MemberRole.owner) p,
      ],
    );
    expect(_one<IncrementInsight>(insights).level, InsightLevel.info);
    expect(_one<ExpiringInsight>(insights).level, InsightLevel.info);
    expect(_one<PoliceInsight>(insights).level, InsightLevel.warning);
    expect(_one<UtilityRiskInsight>(insights).level, InsightLevel.warning);
    // No caretaker holds cash and little came in cash: nothing to say.
    expect(insights.whereType<CashInsight>(), isEmpty);
  });

  test('mostly cash with no caretaker holding any is worth knowing', () {
    final cash = _one<CashInsight>(insightsFor(_dashboard()));
    expect(cash.level, InsightLevel.info);
    expect(cash.holders, isEmpty);
    expect(cash.held, Money.zero);
  });

  test('deposits that cover the arrears, and steady expenses, say nothing', () {
    final insights = insightsFor(
      _dashboard((j) {
        _object(j, 'deposits')['held'] = 130000;
        _object(j, 'expenses')['this_month'] = 44999.99;
      }),
    );
    expect(insights.whereType<DepositCoverInsight>(), isEmpty);
    expect(insights.whereType<ExpenseSpikeInsight>(), isEmpty);
  });

  test('underpriced units are listed by the largest gap', () {
    final [ali, indus] = rentRollJson();
    final underpriced = _one<UnderpricedInsight>(
      insightsFor(
        _dashboard(),
        rentRoll: [
          RentRollEntry.fromRow(ali),
          RentRollEntry.fromRow({
            ...indus,
            'unit': const {
              'label': 'Shop 3',
              'asking_rent': 160000,
              'property': {'name': 'Saddar Plaza'},
            },
          }),
        ],
      ),
    );
    expect(underpriced.units.map((u) => u.leaseId), [techLeaseId, aliLease.id]);
    expect(underpriced.monthlyGap, const Money.fromRupees(55000));
  });

  test('units without an asking rent are never underpriced', () {
    final insights = insightsFor(
      _dashboard(),
      rentRoll: [
        RentRollEntry.fromRow({
          ...rentRollJson().first,
          'unit': const {
            'label': 'Ground floor',
            'asking_rent': null,
            'property': {'name': 'Gulberg House'},
          },
        }),
        RentRollEntry.fromRow({
          ...rentRollJson().first,
          'unit': const {
            'label': 'Ground floor',
            'asking_rent': 0,
            'property': {'name': 'Gulberg House'},
          },
        }),
      ],
    );
    expect(insights.whereType<UnderpricedInsight>(), isEmpty);
  });

  test('the cash share is unknown when no money came in', () {
    final cash = _one<CashInsight>(
      insightsFor(
        _dashboard((j) => _object(j, 'month')['cash_received'] = 0),
        positions: const [
          CashPosition(
            userId: caretakerId,
            fullName: 'Bilal Ahmed',
            role: MemberRole.accountant,
            collected: Money.fromRupees(1000),
            handedOver: Money.zero,
            spent: Money.zero,
            inHand: Money.fromRupees(1000),
          ),
        ],
      ),
    );
    expect(cash.cashShare, isNull);
  });
}
