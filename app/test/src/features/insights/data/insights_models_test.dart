import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/data/exports.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/harness.dart';

/// [json] after a trip through the cache's JSON text.
Object? _cached(Object? json) => jsonDecode(jsonEncode(json));

void main() {
  group('ratios', () {
    test('read numbers and numeric strings in basis points', () {
      expect(ratioBasisPoints(0.6531, 'r'), 6531);
      expect(ratioBasisPoints(1, 'r'), 10000);
      expect(ratioBasisPoints('0.0308', 'r'), 308);
      expect(ratioBasisPoints(null, 'r'), isNull);
      expect(() => ratioBasisPoints('lots', 'r'), throwsFormatException);
      expect(() => ratioBasisPoints(double.nan, 'r'), throwsFormatException);
      expect(() => ratioBasisPoints(true, 'r'), throwsFormatException);
      expect(ratioToJson(6531), '0.6531');
      expect(ratioToJson(null), isNull);
    });
  });

  group('dashboard', () {
    test('reads every part of get_dashboard', () {
      final dashboard = Dashboard.fromJson(dashboardJson());
      expect(dashboard.asOf, CalendarDate(2026, 11, 7));
      final month = dashboard.month;
      expect(month.period, MonthPeriod(2026, 11));
      expect(month.expected, const Money.fromRupees(245000));
      expect(month.paid, const Money.fromRupees(160000));
      expect(month.unpaid, const Money.fromRupees(85000));
      expect(month.collectionRate, 6531);
      expect(month.byMethod, {
        PaymentMethod.cash: const Money.fromRupees(95000),
        PaymentMethod.bankTransfer: const Money.fromRupees(80000),
      });
      expect(dashboard.outstanding.over90, const Money.fromRupees(25000));
      expect(dashboard.occupancy.rate, 8000);
      expect(dashboard.vacantUnits.single.vacantDays, 45);
      final ali = dashboard.topArrears.first;
      expect(ali.tenantPhone?.e164, '+923001112233');
      expect(ali.lastRemindedAt, DateTime.utc(2026, 11, 1, 5, 30));
      expect(dashboard.topArrears.last.tenantPhone, isNull);
      expect(dashboard.expiring.single.daysLeft, 24);
      final missed = dashboard.incrementsMissed.single;
      expect(missed.status, IncrementStatus.missed);
      expect(missed.incrementBasisPoints, 1000);
      expect(missed.newRent, const Money.fromRupees(93500));
      final police = dashboard.police;
      expect(police.first.rule.statutory, isTrue);
      expect(police.first.province, Province.punjab);
      expect(police.last.status, PoliceStatus.submitted);
      expect(police.last.rule.clock, PoliceClock.possession);
      expect(dashboard.cnic.single.expired, isFalse);
      expect(dashboard.deposits.held, const Money.fromRupees(110000));
      expect(dashboard.utilities.unpaidInLandlordNameCount, 1);
      expect(dashboard.highUsage.single.unitsConsumed, const Hundredths(21250));
      expect(dashboard.expensesTrailingAverage, const Money.fromRupees(30000));
      expect(dashboard.counts.urgentMaintenance, 1);
    });

    test('survives the cache unchanged', () {
      for (final json in [dashboardJson(), quietDashboardJson()]) {
        final dashboard = Dashboard.fromJson(json);
        final again = Dashboard.fromJson(_cached(dashboard.toJson()));
        expect(again, dashboard);
        expect(again.hashCode, dashboard.hashCode);
        expect(again.month.hashCode, dashboard.month.hashCode);
        expect(again.outstanding.hashCode, dashboard.outstanding.hashCode);
        expect(again.occupancy, dashboard.occupancy);
        expect(again.occupancy.hashCode, dashboard.occupancy.hashCode);
      }
      expect(
        Dashboard.fromJson(dashboardJson()),
        isNot(Dashboard.fromJson(quietDashboardJson())),
      );
    });

    test('a phone the app cannot dial leaves out only that number', () {
      final json = dashboardJson();
      // The database takes any + and 8 to 15 digits; this is a Pakistani
      // mobile number a digit short.
      ((json['top_arrears']! as List).first as Map)['tenant_phone'] =
          '+92300123456';
      final dashboard = Dashboard.fromJson(json);
      expect(dashboard.topArrears.first.tenantPhone, isNull);
      expect(dashboard.topArrears.first.tenantName, 'Ali Raza');
      expect(dashboard.topArrears, hasLength(2));
      // A number written another way than the canonical one is not taken
      // either: the app never dials a number other than the one stored.
      ((json['top_arrears']! as List).first as Map)['tenant_phone'] =
          '+92 300 1112233';
      expect(Dashboard.fromJson(json).topArrears.first.tenantPhone, isNull);
      expect(
        Dashboard.fromJson(dashboardJson()).topArrears.first.tenantPhone,
        PhoneNumber.fromE164('+923001112233'),
      );
    });

    test('refuses a malformed answer', () {
      Map<String, Object?> changed(void Function(Map<String, Object?>) edit) {
        final json = dashboardJson();
        edit(json);
        return json;
      }

      expect(
        () => Dashboard.fromJson(changed((j) => j.remove('month'))),
        throwsFormatException,
      );
      expect(
        () => Dashboard.fromJson(
          changed((j) => (j['month']! as Map)['by_method'] = {'gold': 5}),
        ),
        throwsFormatException,
      );
      expect(
        () => Dashboard.fromJson(
          changed(
            (j) =>
                ((j['police_pending']! as List).first as Map)['clock'] = 'moon',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => Dashboard.fromJson(
          changed(
            (j) => ((j['increments_missed']! as List).first as Map)['status'] =
                'later',
          ),
        ),
        throwsFormatException,
      );
      expect(() => Dashboard.fromJson('dashboard'), throwsFormatException);
    });
  });

  group('reports', () {
    test('cash flow months', () {
      final month = CashflowMonth.fromRow(
        cashflowJson(MonthPeriod(2026, 3), 3),
      );
      expect(month.received, const Money.fromRupees(120000));
      expect(month.depositRefunds, const Money.fromRupees(15000));
      expect(month.net, const Money.fromRupees(120000 - 36000 - 15000));
      final again = CashflowMonth.fromRow(_cached(month.toRow()));
      expect(again, month);
      expect(again.hashCode, month.hashCode);
    });

    test('property performance, with and without a value', () {
      final [house, plaza] = [
        for (final row in performanceJson()) PropertyPerformance.fromRow(row),
      ];
      expect(house.grossYield, 340);
      expect(house.netYield, 308);
      expect(house.occupancy, 6667);
      expect(plaza.estimatedValue, isNull);
      expect(plaza.grossYield, isNull);
      final empty = PropertyPerformance.fromRow({
        ...performanceJson().last,
        'units': 0,
        'occupied_units': 0,
      });
      expect(empty.occupancy, isNull);
      final again = PropertyPerformance.fromRow(_cached(house.toRow()));
      expect(again, house);
      expect(again.hashCode, house.hashCode);
    });

    test('payment facts', () {
      final fact = PaymentFact.fromRow(factsJson().first);
      expect(fact.settledOn, CalendarDate(2026, 6, 4));
      expect(fact.graceDays, 5);
      final again = PaymentFact.fromRow(_cached(fact.toRow()));
      expect(again, fact);
      expect(again.hashCode, fact.hashCode);
    });

    test('a tax year sums its properties', () {
      final statement = TaxYearStatement(
        taxYear: TaxYear(2026),
        properties: [
          for (final row in taxYearJson()) TaxYearProperty.fromRow(row),
        ],
      );
      final house = statement.properties.first;
      expect(house.expensesByCategory, {
        ExpenseCategory.repairsMaintenance: const Money.fromRupees(45000),
        ExpenseCategory.propertyTax: Money.parseDecimal('18500.50'),
      });
      expect(statement.grossRent, const Money.fromRupees(2460000));
      expect(statement.taxWithheld, const Money.fromRupees(174000));
      expect(statement.repairsAllowance, const Money.fromRupees(492000));
      expect(statement.expensesTotal, Money.parseDecimal('99500.50'));
      expect(
        statement.netAfterRepairsAllowance,
        const Money.fromRupees(1968000),
      );
      final again = TaxYearStatement.fromJson(_cached(statement.toJson()));
      expect(again, statement);
      expect(again.hashCode, statement.hashCode);
      expect(again.properties.first.hashCode, house.hashCode);
      expect(
        () => TaxYearProperty.fromRow({
          ...taxYearJson().first,
          'expenses_by_category': const {'gold': 1},
        }),
        throwsFormatException,
      );
    });

    test('search results', () {
      final [tenant, property, unit] = [
        for (final row in searchJson()) SearchResult.fromRow(row),
      ];
      expect(tenant.kind, SearchKind.tenant);
      expect(property.subtitle, 'Gulberg III, Lahore');
      expect(unit.propertyId, isNull);
      final located = unit.inProperty(gulbergHouse.id);
      expect(located.propertyId, gulbergHouse.id);
      expect(located, isNot(unit));
      expect(located.hashCode, unit.inProperty(gulbergHouse.id).hashCode);
      expect(
        SearchResult.fromRow({...searchJson().first, 'subtitle': ' '}).subtitle,
        isNull,
      );
      expect(
        () => SearchResult.fromRow({...searchJson().first, 'entity_type': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('export rows', () {
    final tenancy = {
      'tenant': {'full_name': 'Ali Raza'},
      'unit': {
        'label': 'Ground floor',
        'property': {'name': 'Gulberg House'},
      },
    };

    test('a due and a payment carry whose they are', () {
      final ledger = FakeLedgerRepository();
      final charge = ledger.chargesOf[aliLease.id]!.first;
      final row = ExportCharge.fromRow({...charge.toRow(), 'lease': tenancy});
      expect(row.charge, charge);
      expect(row.tenancy.propertyName, 'Gulberg House');
      expect(row, ExportCharge.fromRow({...charge.toRow(), 'lease': tenancy}));
      expect(
        row.hashCode,
        ExportCharge(charge: charge, tenancy: row.tenancy).hashCode,
      );
      final payment = ledger.paymentsOf[aliLease.id]!.first;
      final paid = ExportPayment.fromRow({
        ...payment.toRow(),
        'lease': tenancy,
      });
      expect(paid.payment, payment);
      expect(paid, ExportPayment(payment: payment, tenancy: paid.tenancy));
      expect(
        paid.hashCode,
        ExportPayment(payment: payment, tenancy: paid.tenancy).hashCode,
      );
      expect(() => ExportCharge.fromRow(charge.toRow()), throwsFormatException);
    });

    test('the rent roll survives the cache', () {
      final entry = RentRollEntry.fromRow(rentRollJson().first);
      expect(entry.askingRent, const Money.fromRupees(100000));
      final again = RentRollEntry.fromRow(_cached(entry.toRow()));
      expect(again, entry);
      expect(again.hashCode, entry.hashCode);
    });
  });
}
