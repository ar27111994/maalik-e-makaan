// Contract tests: the Dart previews must agree with the database for every
// vector in contracts/rent_math_vectors.json (the SQL side is asserted by
// supabase/tests/database/10_contract_vectors.test.sql).
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(
    File('../../contracts/rent_math_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<Map<String, dynamic>> cases(String key) =>
      (vectors[key] as List<dynamic>).cast<Map<String, dynamic>>();

  CalendarDate date(Object? value) => CalendarDate.parse(value! as String);
  MonthPeriod month(Object? value) => MonthPeriod.parse(value! as String);
  Money money(Object? value) => Money.parseDecimal(value! as String);

  group('due_date', () {
    for (final v in cases('due_date')) {
      test('${v['month']} day ${v['due_day']}', () {
        expect(
          RentMath.dueDate(month(v['month']), v['due_day'] as int),
          date(v['expected']),
        );
      });
    }
  });

  group('billing_due_date', () {
    for (final v in cases('billing_due_date')) {
      test('${v['month']} from ${v['billing_starts_on']}', () {
        expect(
          RentMath.billingDueDate(
            month(v['month']),
            v['due_day'] as int,
            date(v['billing_starts_on']),
          ),
          date(v['expected']),
        );
      });
    }
  });

  group('prorated_rent', () {
    for (final v in cases('prorated_rent')) {
      test('${v['monthly_rent']} from ${v['billing_starts_on']}', () {
        expect(
          RentMath.proratedRent(
            monthlyRent: money(v['monthly_rent']),
            period: month(v['month']),
            occupancy: DateRange(date(v['billing_starts_on'])),
          ),
          money(v['expected']),
        );
      });
    }
  });

  group('next_anniversary', () {
    for (final v in cases('next_anniversary')) {
      test('${v['start']} as of ${v['as_of']}', () {
        expect(
          RentMath.nextAnniversary(
            date(v['start']),
            date(v['as_of']),
            intervalMonths: v['interval_months'] as int,
          ),
          date(v['expected']),
        );
      });
    }
  });

  group('late_fee', () {
    for (final v in cases('late_fee')) {
      test('${v['type']} ${v['value']} on ${v['outstanding']}', () {
        final policy = LateFeePolicy.fromColumns(
          type: v['type'] as String,
          value: v['value'],
          cap: v['cap'],
        );
        expect(
          policy.feeFor(
            overdueAmount: money(v['outstanding']),
            daysLate: v['days_late'] as int,
            graceDays: v['grace_days'] as int,
          ),
          money(v['expected']),
        );
      });
    }
  });
}
