// Runs the real mm_core code on the cases gen_cases.py wrote, for the
// differential check of formal/bend/SPEC.bend against Dart (compare.py).
//
//   dart --packages=<repo>/.dart_tool/package_config.json \
//     formal/bend/fidelity/dart_cases.dart <cases.json> <results.json>
//
// Amounts are whole paisa and dates ISO strings, as gen_cases.py writes them.
import 'dart:convert';
import 'dart:io';

import 'package:mm_core/mm_core.dart';
// divideRounded is internal to mm_core; the model checks it directly.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member
import 'package:mm_core/src/money/money.dart' show divideRounded;

CalendarDate _date(Object? iso) => CalendarDate.parse(iso! as String);

Money _money(Object? paisa) => Money.fromPaisa(paisa! as int);

Map<String, Object?> _fifo(Map<String, Object?> c) {
  final charges = [
    for (final raw
        in (c['charges']! as List<Object?>).cast<Map<String, Object?>>())
      OpenCharge(
        id: raw['id']! as String,
        dueDate: _date(raw['due']),
        outstanding: _money(raw['outstanding']),
        isSecurityDeposit: raw['deposit']! as bool,
      ),
  ];
  final plan = planFifoAllocation(
    _money(c['payment']),
    charges,
    chosenChargeIds: [
      for (final id in c['chosen']! as List<Object?>) id! as String,
    ],
    depositAdjustment: c['deposit_adjustment']! as bool,
  );
  return {
    'allocations': [
      for (final a in plan.allocations) [a.chargeId, a.amount.paisa],
    ],
    'unallocated': plan.unallocated.paisa,
  };
}

List<int> _split(Map<String, Object?> c) => [
  for (final part in _money(c['amount']).splitEvenly(c['count']! as int))
    part.paisa,
];

int _divide(Map<String, Object?> c) => divideRounded(
  BigInt.from(c['n']! as int),
  BigInt.from(c['d']! as int),
  RoundingMode.halfUp,
).toInt();

int _prorate(Map<String, Object?> c) {
  final end = c['end'];
  return RentMath.proratedRent(
    monthlyRent: _money(c['rent']),
    period: MonthPeriod(c['year']! as int, c['month']! as int),
    occupancy: DateRange(_date(c['start']), end == null ? null : _date(end)),
  ).paisa;
}

int _billed(Map<String, Object?> c) => RentMath.billedRent(
  monthlyRent: _money(c['rent']),
  period: MonthPeriod(c['year']! as int, c['month']! as int),
  billingStartsOn: _date(c['billing_starts_on']),
  prorateFirstMonth: c['prorate']! as bool,
).paisa;

int _fee(Map<String, Object?> c) {
  final cap = c['cap'];
  return DailyLateFee(_money(c['rate']), cap: cap == null ? null : _money(cap))
      .feeFor(
        overdueAmount: _money(c['overdue']),
        daysLate: c['days']! as int,
        graceDays: c['grace']! as int,
      )
      .paisa;
}

void main(List<String> args) {
  final cases =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>;
  List<Object?> run(String key, Object? Function(Map<String, Object?>) f) => [
    for (final c in cases[key]! as List<Object?>) f(c! as Map<String, Object?>),
  ];
  final results = {
    'fifo': run('fifo', _fifo),
    'split': run('split', _split),
    'divide': run('divide', _divide),
    'prorate': run('prorate', _prorate),
    'billed': run('billed', _billed),
    'fee': run('fee', _fee),
  };
  File(args[1]).writeAsStringSync(jsonEncode(results));
}
