import 'dart:math';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  OpenCharge charge(String id, String due, int rupees) => OpenCharge(
    id: id,
    dueDate: CalendarDate.parse(due),
    outstanding: Money.fromRupees(rupees),
  );

  final sep = charge('c1', '2026-09-05', 45000);
  final oct = charge('c2', '2026-10-05', 45000);
  final elec = charge('c0', '2026-10-05', 6200); // same due date, lower id
  final nov = charge('c3', '2026-11-05', 45000);

  test('OpenCharge requires a positive outstanding amount', () {
    expect(() => charge('x', '2026-01-01', 0), throwsArgumentError);
  });

  test('allocates oldest first, ties broken by id', () {
    final plan = planFifoAllocation(const Money.fromRupees(100000), [
      nov,
      oct,
      elec,
      sep,
    ]);
    expect(plan.allocations, [
      const ChargeAllocation(chargeId: 'c1', amount: Money.fromRupees(45000)),
      const ChargeAllocation(chargeId: 'c0', amount: Money.fromRupees(6200)),
      const ChargeAllocation(chargeId: 'c2', amount: Money.fromRupees(45000)),
      const ChargeAllocation(chargeId: 'c3', amount: Money.fromRupees(3800)),
    ]);
    expect(plan.unallocated, Money.zero);
    expect(plan.allocated, const Money.fromRupees(100000));
    expect(plan.settledChargeIds([sep, oct, elec, nov]), ['c1', 'c0', 'c2']);
  });

  test('overpayment becomes credit; zero payment allocates nothing', () {
    final over = planFifoAllocation(const Money.fromRupees(50000), [sep]);
    expect(over.unallocated, const Money.fromRupees(5000));
    final none = planFifoAllocation(Money.zero, [sep]);
    expect(none.allocations, isEmpty);
    expect(none.unallocated, Money.zero);
    expect(
      planFifoAllocation(const Money.fromRupees(5), const []).unallocated,
      const Money.fromRupees(5),
    );
    expect(
      () => planFifoAllocation(const Money.fromRupees(-1), [sep]),
      throwsArgumentError,
    );
  });

  test('chosen charges come first, in the order given', () {
    final plan = planFifoAllocation(
      const Money.fromRupees(50000),
      [sep, oct, nov],
      chosenChargeIds: ['c3', 'c2'],
    );
    expect(plan.allocations, [
      const ChargeAllocation(chargeId: 'c3', amount: Money.fromRupees(45000)),
      const ChargeAllocation(chargeId: 'c2', amount: Money.fromRupees(5000)),
    ]);
    expect(
      () => planFifoAllocation(
        const Money.fromRupees(1),
        [sep],
        chosenChargeIds: ['nope'],
      ),
      throwsArgumentError,
    );
  });

  test('a deposit adjustment never pays the security deposit', () {
    final deposit = OpenCharge(
      id: 'c-1',
      dueDate: CalendarDate.parse('2026-09-01'),
      outstanding: const Money.fromRupees(90000),
      isSecurityDeposit: true,
    );
    final adjustment = planFifoAllocation(const Money.fromRupees(50000), [
      deposit,
      sep,
    ], depositAdjustment: true);
    expect(adjustment.allocations, [
      const ChargeAllocation(chargeId: 'c1', amount: Money.fromRupees(45000)),
    ]);
    expect(adjustment.unallocated, const Money.fromRupees(5000));
    // An ordinary payment settles the deposit first (it is due first).
    final payment = planFifoAllocation(const Money.fromRupees(50000), [
      deposit,
      sep,
    ]);
    expect(payment.allocations.single.chargeId, 'c-1');
  });

  test('ChargeAllocation value semantics', () {
    const a = ChargeAllocation(chargeId: 'x', amount: Money.fromRupees(1));
    expect(
      a,
      const ChargeAllocation(chargeId: 'x', amount: Money.fromRupees(1)),
    );
    expect(
      a.hashCode,
      const ChargeAllocation(
        chargeId: 'x',
        amount: Money.fromRupees(1),
      ).hashCode,
    );
    expect(a == Object(), isFalse);
    expect('$a', 'ChargeAllocation(x, Money(1.00 PKR))');
  });

  test('property: conservation and ordering hold for random ledgers', () {
    final random = Random(7);
    for (var run = 0; run < 500; run++) {
      final charges = [
        for (var i = 0; i < 1 + random.nextInt(12); i++)
          OpenCharge(
            id: 'c${random.nextInt(1000).toString().padLeft(4, '0')}-$i',
            dueDate: CalendarDate(2026, 1 + random.nextInt(12), 1),
            outstanding: Money.fromPaisa(1 + random.nextInt(10000000)),
          ),
      ];
      final payment = Money.fromPaisa(random.nextInt(60000000));
      final plan = planFifoAllocation(payment, charges);
      // Conservation: allocated + unallocated == payment.
      expect(plan.allocated + plan.unallocated, payment);
      // No charge receives more than it owes.
      final byId = {for (final c in charges) c.id: c};
      for (final allocation in plan.allocations) {
        expect(
          allocation.amount <= byId[allocation.chargeId]!.outstanding,
          isTrue,
        );
        expect(allocation.amount.isPositive, isTrue);
      }
      // Credit only remains when every charge is fully settled.
      if (plan.unallocated.isPositive) {
        expect(plan.settledChargeIds(charges).length, charges.length);
      }
    }
  });
}
