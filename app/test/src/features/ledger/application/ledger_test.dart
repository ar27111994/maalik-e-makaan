import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/leases/application/leases.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/payment_preview.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

/// How many times the fake was asked for [name].
int _count(List<Call> calls, String name) =>
    calls.where((c) => c.$1 == name).length;

Receivable _owing(
  String id, {
  required int overdue,
  int? days,
  int owed = 0,
  String name = 'Tenant',
}) => Receivable(
  leaseId: id,
  active: true,
  tenantId: 't-$id',
  tenantName: name,
  unitId: 'u-$id',
  unitLabel: 'Unit',
  propertyId: 'p',
  propertyName: 'Property',
  monthlyRent: const Money.fromRupees(50000),
  balance: LeaseBalance(
    outstanding: Money.fromRupees(owed + overdue),
    overdue: Money.fromRupees(overdue),
    daysOverdue: days,
  ),
);

void main() {
  group('the tenancy commands', () {
    test('every change to a tenancy reads its money again', () async {
      final app = TestApp();
      final container = containerFor(app);
      final lease = leaseProvider(aliLease.id);
      final ledger = tenancyLedgerProvider(aliLease.id);
      final receivables = receivablesProvider(gulberg);
      listen(container, lease);
      listen(container, ledger);
      listen(container, receivables);
      await pumpEventQueue();
      final controller = container.read(lease.notifier);

      Future<void> expectReread(Future<void> Function() change) async {
        final ledgerReads = _count(app.ledger.calls, 'ledger');
        final listReads = _count(app.ledger.calls, 'receivables');
        await change();
        await pumpEventQueue();
        expect(_count(app.ledger.calls, 'ledger'), greaterThan(ledgerReads));
        expect(_count(app.ledger.calls, 'receivables'), greaterThan(listReads));
      }

      // A new deposit or rent day re-bills; a rent change re-prices; ending
      // voids later dues and keeps their money as credit; deleting takes
      // the tenancy off the list.
      await expectReread(() => controller.save(aliLease.terms));
      await expectReread(
        () => controller.changeRent(
          from: MonthPeriod(2027, 1),
          rent: const Money.fromRupees(93500),
          reason: RentChangeReason.annualIncrement,
        ),
      );
      await expectReread(
        () => controller.end(
          movedOutOn: CalendarDate(2026, 11, 30),
          reason: EndReason.tenantMovedOut,
        ),
      );
      await expectReread(controller.delete);
    });

    test('recording a payment reads the list and the receipt again', () async {
      final app = TestApp();
      final container = containerFor(app);
      final ledger = tenancyLedgerProvider(aliLease.id);
      final receipt = paymentProvider('pay-oct');
      listen(container, ledger);
      listen(container, receivablesProvider(gulberg));
      listen(container, receipt);
      await pumpEventQueue();
      final listReads = _count(app.ledger.calls, 'receivables');
      final receiptReads = _count(app.ledger.calls, 'payment');
      final result = await container
          .read(ledger.notifier)
          .recordPayment(
            PaymentDraft(
              leaseId: aliLease.id,
              amount: const Money.fromRupees(25000),
              paidOn: CalendarDate(2026, 11, 7),
              method: PaymentMethod.cash,
              idempotencyKey: 'k',
            ),
          );
      await pumpEventQueue();
      expect(_count(app.ledger.calls, 'receivables'), greaterThan(listReads));
      expect(_count(app.ledger.calls, 'payment'), greaterThan(receiptReads));
      expect(
        container.read(ledger).value!.value.payments.items.map((p) => p.id),
        contains(result.payment.id),
      );
    });

    test(
      'a refund whose answer was lost is found, or the failure kept',
      () async {
        final app = TestApp();
        final container = containerFor(app);
        final ledger = tenancyLedgerProvider(aliLease.id);
        listen(container, ledger);
        await pumpEventQueue();
        final controller = container.read(ledger.notifier);
        app.ledger.lostAnswers.add('refundDeposit');
        final found = await controller.refundDeposit(
          amount: const Money.fromRupees(20000),
          refundedOn: CalendarDate(2026, 11, 7),
          method: PaymentMethod.cash,
        );
        expect(found.amount, const Money.fromRupees(20000));
        expect(
          container.read(ledger).value!.value.deposit.held,
          const Money.fromRupees(150000),
        );
        // Not recorded: the failure stands, and the ledger is read again.
        app.ledger.writeFailures.add(const NetworkFailure());
        final reads = _count(app.ledger.calls, 'ledger');
        await expectLater(
          controller.refundDeposit(
            amount: const Money.fromRupees(20000),
            refundedOn: CalendarDate(2026, 11, 7),
            method: PaymentMethod.cash,
          ),
          throwsA(isA<NetworkFailure>()),
        );
        expect(_count(app.ledger.calls, 'ledger'), reads + 1);
        // The read failing too leaves the failure as it was.
        app.ledger
          ..writeFailures.add(const NetworkFailure())
          ..readFailure = const NetworkFailure();
        await expectLater(
          controller.refundDeposit(
            amount: const Money.fromRupees(20000),
            refundedOn: CalendarDate(2026, 11, 7),
            method: PaymentMethod.cash,
          ),
          throwsA(isA<NetworkFailure>()),
        );
      },
    );
  });

  group('the billing catch-up', () {
    test('runs once per portfolio per day in Pakistan', () async {
      final app = TestApp();
      final container = containerFor(app);
      final list = receivablesProvider(gulberg);
      listen(container, list);
      await pumpEventQueue();
      expect(app.ledger.syncs, 1);
      // Read again the same day: no second run.
      container.invalidate(list);
      await pumpEventQueue();
      expect(app.ledger.syncs, 1);
      expect(
        container.exists(
          billingSyncProvider((
            portfolioId: gulberg.id,
            day: CalendarDate(2026, 11, 7),
          )),
        ),
        isTrue,
      );
      // The next day (an app left open past midnight) runs it again.
      await container.read(
        billingSyncProvider((
          portfolioId: gulberg.id,
          day: CalendarDate(2026, 11, 8),
        )).future,
      );
      expect(app.ledger.syncs, 2);
    });

    test('a failed run is tried again on the next read', () async {
      final app = TestApp()
        ..ledger.writeFailures.add(const TemporarilyUnavailable());
      final container = containerFor(app);
      final sync = billingSyncProvider((
        portfolioId: gulberg.id,
        day: CalendarDate(2026, 11, 7),
      ));
      expect(await container.read(sync.future), 0);
      await pumpEventQueue();
      await container.read(sync.future);
      expect(app.ledger.syncs, 1);
      expect(_count(app.ledger.calls, 'syncBilling'), 2);
    });
  });

  test('who owes what lists the longest overdue first', () {
    final sorted = byDaysOverdue([
      _owing('a', overdue: 200000, days: 5),
      _owing('b', overdue: 1000, days: 60),
      _owing('c', overdue: 0, owed: 90000),
      _owing('d', overdue: 5000, days: 60),
      _owing('e', overdue: 0, owed: 10000, name: 'Aslam'),
      _owing('f', overdue: 0, owed: 10000, name: 'Bushra'),
    ]);
    expect(sorted.map((r) => r.leaseId), ['d', 'b', 'a', 'c', 'e', 'f']);
  });

  group('the payment preview', () {
    final rent = Charge(
      id: 'rent',
      leaseId: 'l',
      kind: ChargeKind.rent,
      source: ChargeSource.autoRent,
      dueDate: CalendarDate(2026, 10, 5),
      amount: const Money.fromRupees(85000),
      paidAmount: const Money.fromRupees(60000),
    );
    final fee = Charge(
      id: 'fee',
      leaseId: 'l',
      kind: ChargeKind.lateFee,
      source: ChargeSource.autoLateFee,
      dueDate: CalendarDate(2026, 10, 11),
      amount: const Money.fromRupees(5000),
      relatedChargeId: 'rent',
    );
    final next = Charge(
      id: 'next',
      leaseId: 'l',
      kind: ChargeKind.rent,
      source: ChargeSource.autoRent,
      dueDate: CalendarDate(2026, 11, 5),
      amount: const Money.fromRupees(85000),
    );
    final open = [rent, fee, next];

    PaymentPreview preview(
      int rupees,
      CalendarDate paidOn, {
      List<Charge>? charges,
      List<String> chosen = const [],
    }) => previewPayment(
      applied: Money.fromRupees(rupees),
      open: charges ?? open,
      paidOn: paidOn,
      graceDays: 5,
      chosen: chosen,
    );

    List<(String, Money)> slices(PaymentPreview p) => [
      for (final a in p.plan.allocations) (a.chargeId, a.amount),
    ];

    test('a rent settled within grace cancels its fee', () {
      // 10 October: the last day of grace.
      final within = preview(30000, CalendarDate(2026, 10, 10));
      expect(within.cancelledFees, [fee]);
      expect(slices(within), [
        ('rent', const Money.fromRupees(25000)),
        ('next', const Money.fromRupees(5000)),
      ]);
      // A day later the fee stands and is paid.
      final after = preview(30000, CalendarDate(2026, 10, 11));
      expect(after.cancelledFees, isEmpty);
      expect(slices(after), [
        ('rent', const Money.fromRupees(25000)),
        ('fee', const Money.fromRupees(5000)),
      ]);
    });

    test('a rent left part paid, or a fee already paid on, keeps it', () {
      expect(preview(20000, CalendarDate(2026, 10, 8)).cancelledFees, isEmpty);
      final paidOn = Charge.fromRow({
        ...fee.toRow(),
        'paid_amount': '1000.00',
        'outstanding': '4000.00',
      });
      expect(
        preview(
          30000,
          CalendarDate(2026, 10, 8),
          charges: [rent, paidOn, next],
        ).cancelledFees,
        isEmpty,
      );
      // A fee added by hand is not the automatic one.
      final manual = Charge.fromRow({...fee.toRow(), 'source': 'manual'});
      expect(
        preview(
          30000,
          CalendarDate(2026, 10, 8),
          charges: [rent, manual, next],
        ).cancelledFees,
        isEmpty,
      );
    });

    test('chosen dues stay first, without the cancelled fee', () {
      final chosen = preview(
        30000,
        CalendarDate(2026, 10, 8),
        chosen: ['fee', 'rent'],
      );
      expect(chosen.cancelledFees, [fee]);
      expect(slices(chosen), [
        ('rent', const Money.fromRupees(25000)),
        ('next', const Money.fromRupees(5000)),
      ]);
    });
  });
}
