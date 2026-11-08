import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/handovers/application/handovers.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/application/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/application/places.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

int _count(List<Call> calls, String name) =>
    calls.where((c) => c.$1 == name).length;

void main() {
  test('places and tenancies are read and kept for offline use', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, placesProvider(gulberg.id));
    final tenancies = tenanciesProvider((
      propertyId: gulbergHouse.id,
      unitId: null,
    ));
    listen(container, tenancies);
    await pumpEventQueue();
    expect(
      container.read(placesProvider(gulberg.id)).value!.value.single.units,
      hasLength(3),
    );
    expect(container.read(tenancies).value!.value, hasLength(2));
    // A second container reads the saved copies first.
    final again = containerFor(app);
    listen(again, placesProvider(gulberg.id));
    listen(again, tenancies);
    await pumpEventQueue();
    expect(again.read(placesProvider(gulberg.id)).value!.value, hasLength(1));
    expect(again.read(tenancies).value!.value, hasLength(2));
    expect(
      PlacesController(gulberg.id).decode(
        PlacesController(gulberg.id)
            .encode(container.read(placesProvider(gulberg.id)).value!.value),
      ),
      hasLength(1),
    );
  });

  test('expenses page, add, save and delete, and change the cash in '
      'hand', () async {
    final app = TestApp();
    app.operations.pageLimit = 2;
    final container = containerFor(app);
    final list = expensesProvider((portfolioId: gulberg.id, requestId: null));
    listen(container, list);
    listen(container, cashBookProvider(gulberg.id));
    await pumpEventQueue();
    expect(container.read(list).value!.value.items, hasLength(2));
    await container.read(list.notifier).loadMore();
    expect(container.read(list).value!.value.items, hasLength(3));
    expect(container.read(list).value!.value.hasMore, isFalse);
    // Nothing more to read.
    await container.read(list.notifier).loadMore();
    final cash = _count(app.handovers.calls, 'cashBook');
    final created = await container
        .read(list.notifier)
        .create(
          'e-new',
          ExpenseDraft(
            category: ExpenseCategory.bankCharges,
            amount: const Money.fromRupees(250),
            spentOn: CalendarDate(2026, 11, 7),
          ),
        );
    expect(created.id, 'e-new');
    await pumpEventQueue();
    expect(container.read(list).value!.value.items.first.id, 'e-new');
    expect(_count(app.handovers.calls, 'cashBook'), cash + 1);

    final one = expenseProvider('e-new');
    listen(container, one);
    await pumpEventQueue();
    final saved = await container
        .read(one.notifier)
        .save(
          ExpenseDraft(
            category: ExpenseCategory.bankCharges,
            amount: const Money.fromRupees(300),
            spentOn: CalendarDate(2026, 11, 7),
          ),
        );
    expect(saved.amount, const Money.fromRupees(300));
    expect(container.read(one).value!.value.amount, saved.amount);
    await container.read(one.notifier).delete();
    await pumpEventQueue();
    expect(
      container.read(list).value!.value.items.map((e) => e.id),
      isNot(contains('e-new')),
    );
  });

  test("a job's expenses are its own", () async {
    final app = TestApp();
    final container = containerFor(app);
    final list = expensesProvider((
      portfolioId: gulberg.id,
      requestId: seepageJob.id,
    ));
    listen(container, list);
    await pumpEventQueue();
    expect(container.read(list).value!.value.items.single, plumberExpense);
  });

  test('connections page, add, save, archive and delete', () async {
    final app = TestApp();
    app.operations.pageLimit = 1;
    final container = containerFor(app);
    final list = utilityAccountsProvider((
      portfolioId: gulberg.id,
      archived: false,
    ));
    listen(container, list);
    listen(container, unpaidBillsProvider(gulberg.id));
    await pumpEventQueue();
    await container.read(list.notifier).loadMore();
    expect(container.read(list).value!.value.items, [lescoMeter, sngplMeter]);
    await container.read(list.notifier).loadMore();
    final created = await container
        .read(list.notifier)
        .create(
          'a-new',
          UtilityAccountDraft(
            propertyId: gulbergHouse.id,
            unitId: firstFloor.id,
            type: UtilityType.water,
            provider: UtilityProvider.wasa,
          ),
        );
    expect(created.unitLabel, firstFloor.label);

    final account = utilityAccountProvider('a-new');
    listen(container, account);
    await pumpEventQueue();
    final unpaidReads = _count(app.operations.calls, 'unpaidBills');
    await container
        .read(account.notifier)
        .save(
          UtilityAccountDraft(
            propertyId: gulbergHouse.id,
            type: UtilityType.water,
            provider: UtilityProvider.wasa,
            referenceNumber: 'W-1234',
          ),
        );
    expect(
      container.read(account).value!.value.account.referenceNumber,
      'W-1234',
    );
    await pumpEventQueue();
    expect(_count(app.operations.calls, 'unpaidBills'), unpaidReads + 1);
    await container.read(account.notifier).archive(archived: true);
    expect(container.read(account).value!.value.account.archived, isTrue);
    await container.read(account.notifier).delete();
    expect(
      app.operations.accountList.map((a) => a.id),
      isNot(contains('a-new')),
    );
  });

  test("a connection's bills and readings page and are added", () async {
    final app = TestApp();
    app.operations.pageLimit = 1;
    final container = containerFor(app);
    final account = utilityAccountProvider(lescoMeter.id);
    listen(container, account);
    await pumpEventQueue();
    final controller = container.read(account.notifier);
    await controller.loadMoreBills();
    await controller.loadMoreReadings();
    var detail = container.read(account).value!.value;
    expect(detail.bills.items, hasLength(2));
    expect(detail.readings.items, hasLength(2));
    await controller.loadMoreReadings();
    // At the end there is nothing more.
    await controller.loadMoreBills();
    final bill = await controller.addBill(
      id: 'b-new',
      portfolioId: gulberg.id,
      draft: BillDraft(
        billingMonth: MonthPeriod(2026, 12),
        amount: const Money.fromRupees(5000),
      ),
    );
    expect(bill.connection.id, lescoMeter.id);
    final reading = await controller.addReading(
      id: 'r-new',
      portfolioId: gulberg.id,
      draft: ReadingDraft(
        reading: const Hundredths(1230000),
        readOn: CalendarDate(2026, 11, 7),
        leaseId: aliLease.id,
      ),
    );
    expect(reading.tenantName, 'Ali Raza');
    detail = container.read(account).value!.value;
    expect(detail.bills.items.first.id, 'b-new');
    expect(detail.readings.items.first.id, 'r-new');
  });

  test('a bill is saved, billed to the tenant (whose money is read again) '
      'and deleted', () async {
    final app = TestApp();
    final container = containerFor(app);
    final bill = utilityBillProvider(novemberBill.id);
    listen(container, bill);
    final ledger = tenancyLedgerProvider(aliLease.id);
    listen(container, ledger);
    final unpaid = unpaidBillsProvider(gulberg.id);
    listen(container, unpaid);
    await pumpEventQueue();
    // Saving the details leaves whether it is paid alone.
    final edited = await container
        .read(bill.notifier)
        .save(
          BillDraft(
            billingMonth: novemberBill.billingMonth,
            amount: const Money.fromRupees(9900),
            dueDate: novemberBill.dueDate,
          ),
        );
    expect(edited.amount, const Money.fromRupees(9900));
    expect(edited.paid, isFalse);
    final saved = await container
        .read(bill.notifier)
        .setPayment(
          BillPayment(
            paidOn: CalendarDate(2026, 11, 7),
            paidBy: BillPayer.landlord,
          ),
        );
    expect(saved.paid, isTrue);
    expect(saved.amount, const Money.fromRupees(9900));
    expect(app.operations.calls.last.$1, 'setBillPayment');
    expect(app.operations.calls.last.$2, [
      novemberBill.id,
      BillPayment(
        paidOn: CalendarDate(2026, 11, 7),
        paidBy: BillPayer.landlord,
      ),
    ]);
    final unpaidAgain = await container
        .read(bill.notifier)
        .setPayment(const BillPayment.unpaid());
    expect(unpaidAgain.paid, isFalse);
    expect(unpaidAgain.paidOn, isNull);
    final reads = _count(app.ledger.calls, 'ledger');
    final unpaidReads = _count(app.operations.calls, 'unpaidBills');
    final charge = await container
        .read(bill.notifier)
        .billToTenant(aliLease.id);
    expect(charge.leaseId, aliLease.id);
    await pumpEventQueue();
    expect(_count(app.ledger.calls, 'ledger'), reads + 1);
    // The bills to pay show the bill with its charge.
    expect(_count(app.operations.calls, 'unpaidBills'), unpaidReads + 1);
    expect(
      container
          .read(unpaid)
          .value!
          .value
          .firstWhere((b) => b.id == novemberBill.id)
          .liveCharge,
      isNotNull,
    );
    expect(container.read(bill).value!.value.liveCharge?.leaseId, aliLease.id);
    await container.read(bill.notifier).delete();
    expect(
      app.operations.billList.map((b) => b.id),
      isNot(contains(novemberBill.id)),
    );
  });

  test('a reading is read with the one before it, saved and deleted', () async {
    final app = TestApp();
    final container = containerFor(app);
    final reading = meterReadingProvider(novemberReading.id);
    listen(container, reading);
    await pumpEventQueue();
    expect(container.read(reading).value!.value.previous, octoberReading);
    final saved = await container
        .read(reading.notifier)
        .save(
          ReadingDraft(
            reading: const Hundredths(1220600),
            readOn: CalendarDate(2026, 11, 1),
          ),
        );
    expect(saved.reading, const Hundredths(1220600));
    expect(
      container.read(reading).value!.value.consumption!.units,
      const Hundredths(19600),
    );
    await container.read(reading.notifier).delete();
    expect(
      app.operations.readingList.map((r) => r.id),
      isNot(contains(novemberReading.id)),
    );
  });

  test('repairs page, add, move along and refuse deleting with '
      'expenses', () async {
    final app = TestApp();
    app.operations.pageLimit = 1;
    final container = containerFor(app);
    final list = maintenanceListProvider((
      portfolioId: gulberg.id,
      pending: true,
    ));
    listen(container, list);
    await pumpEventQueue();
    await container.read(list.notifier).loadMore();
    expect(container.read(list).value!.value.items, [gateLightJob, seepageJob]);
    await container.read(list.notifier).loadMore();
    final created = await container
        .read(list.notifier)
        .create(
          'm-new',
          MaintenanceDraft(
            propertyId: gulbergHouse.id,
            title: 'Paint the gate',
            reportedOn: CalendarDate(2026, 11, 7),
          ),
        );
    expect(created.status, MaintenanceStatus.open);
    final request = maintenanceRequestProvider(seepageJob.id);
    listen(container, request);
    await pumpEventQueue();
    final saved = await container
        .read(request.notifier)
        .move(
          MaintenanceMove(
            MaintenanceStatus.resolved,
            resolvedOn: CalendarDate(2026, 11, 7),
          ),
        );
    expect(saved.status, MaintenanceStatus.resolved);
    expect(container.read(request).value!.value.resolvedOn, isNotNull);
    expect(app.operations.calls.last.$1, 'moveMaintenanceRequest');
    expect(app.operations.calls.last.$2, [
      seepageJob.id,
      MaintenanceMove(
        MaintenanceStatus.resolved,
        resolvedOn: CalendarDate(2026, 11, 7),
      ),
    ]);
    expect(container.read(request).value!.value, saved);
    await expectLater(
      container.read(request.notifier).delete(),
      throwsA(isA<Object>()),
    );
    final gate = maintenanceRequestProvider('m-new');
    listen(container, gate);
    await pumpEventQueue();
    await container.read(gate.notifier).delete();
    expect(
      app.operations.requestList.map((r) => r.id),
      isNot(contains('m-new')),
    );
  });
}
