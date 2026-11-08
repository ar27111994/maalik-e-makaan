import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/place.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/operations_fakes.dart';

/// [value] read back from its own row, equal with an equal hash.
void _roundTrips<T>(
  T value,
  Object? Function(T) row,
  T Function(Object?) read,
) {
  final back = read(row(value));
  expect(back, value);
  expect(back.hashCode, value.hashCode);
}

void main() {
  group('expenses', () {
    test('read their rows strictly and survive the cache', () {
      for (final expense in [plumberExpense, taxExpense, accountantExpense]) {
        _roundTrips(expense, (e) => e.toRow(), Expense.fromRow);
      }
      expect(plumberExpense.cursor.id, plumberExpense.id);
      expect(plumberExpense == taxExpense, isFalse);
      final row = plumberExpense.toRow();
      expect(
        () => Expense.fromRow({...row, 'category': 'gold'}),
        throwsFormatException,
      );
      expect(
        () => Expense.fromRow(Map.of(row)..remove('spent_on')),
        throwsFormatException,
      );
      expect(
        () => Expense.fromRow({...row, 'amount': 'lots'}),
        throwsFormatException,
      );
      for (final category in ExpenseCategory.values) {
        expect(ExpenseCategory.parse(category.db), category);
      }
    });

    test('drafts write tidy text within the columns', () {
      final draft = ExpenseDraft(
        category: ExpenseCategory.repairsMaintenance,
        amount: const Money.fromRupees(4500),
        spentOn: CalendarDate(2026, 11, 5),
        unitId: groundFloor.id,
        payee: '  Aslam   Plumber ',
        reference: ' ',
        notes: ' First visit \r\n\n\n\nPipe fixed ',
      );
      expect(draft.toWrite(), {
        'property_id': null,
        // A unit needs its property.
        'unit_id': null,
        'maintenance_request_id': null,
        'category': 'repairs_maintenance',
        'amount': '4500.00',
        'spent_on': '2026-11-05',
        'payee': 'Aslam Plumber',
        'method': 'cash',
        'reference': null,
        'notes': 'First visit\n\nPipe fixed',
      });
      final of = ExpenseDraft.of(plumberExpense);
      expect(of.toWrite()['unit_id'], groundFloor.id);
      expect(of.toWrite()['maintenance_request_id'], seepageJob.id);
      expect(of, ExpenseDraft.of(plumberExpense));
      expect(of.hashCode, ExpenseDraft.of(plumberExpense).hashCode);
      // Text is cut to the column's length in code points: each Urdu
      // letter with a diacritic is one character but two code points.
      final long = 'بَ' * 100;
      expect(optionalText(long, 120)!.runes.length, 120);
      expect(optionalLines(long, 120)!.runes.length, 120);
      expect(optionalText(null, 5), isNull);
      expect(optionalLines(' \n ', 5), isNull);
    });
  });

  group('utilities', () {
    test('providers belong to their types, with the digits their bills '
        'carry', () {
      expect(UtilityType.gas.providers, [
        UtilityProvider.sngpl,
        UtilityProvider.ssgc,
        UtilityProvider.other,
      ]);
      expect(UtilityType.other.providers, [UtilityProvider.other]);
      expect(UtilityType.electricity.providers, hasLength(13));
      expect(UtilityProvider.lesco.referenceDigits, 14);
      expect(UtilityProvider.hazeco.referenceDigits, 14);
      expect(UtilityProvider.kElectric.referenceDigits, 13);
      expect(UtilityProvider.sngpl.referenceDigits, isNull);
      expect(UtilityProvider.other.referenceDigits, isNull);
      for (final value in [
        ...UtilityType.values.map((v) => (v.db, UtilityType.parse)),
      ]) {
        expect(value.$2(value.$1).db, value.$1);
      }
      for (final provider in UtilityProvider.values) {
        expect(UtilityProvider.parse(provider.db), provider);
      }
      for (final who in BillResponsibility.values) {
        expect(BillResponsibility.parse(who.db), who);
      }
      for (final status in BillStatus.values) {
        expect(BillStatus.parse(status.db), status);
      }
      for (final payer in BillPayer.values) {
        expect(BillPayer.parse(payer.db), payer);
      }
      for (final context in ReadingContext.values) {
        expect(ReadingContext.parse(context.db), context);
      }
      expect(() => UtilityProvider.parse('wapda'), throwsFormatException);
    });

    test('identifiers are stored upper case, without spaces, Urdu digits '
        'read', () {
      expect(normalizeIdentifier(' 0926 9330 553008 '), '09269330553008');
      expect(normalizeIdentifier('l-12۳45'), 'L-12345');
      expect(UtilityAccount.referencePattern.hasMatch('09269330553008'), true);
      expect(UtilityAccount.referencePattern.hasMatch('092'), false);
      expect(UtilityAccount.meterPattern.hasMatch('L/12-3'), true);
      expect(UtilityAccount.customerIdPattern.hasMatch('A' * 31), false);
    });

    test('connections, bills and readings survive the cache', () {
      for (final account in [lescoMeter, sngplMeter, oldWater]) {
        _roundTrips(account, (a) => a.toRow(), UtilityAccount.fromRow);
      }
      expect(oldWater.archived, isTrue);
      expect(lescoMeter.watchesProtectedTariff, isTrue);
      expect(sngplMeter.watchesProtectedTariff, isFalse);
      _roundTrips(
        lescoMeter.connection,
        (c) => c.toRow(),
        UtilityConnection.fromRow,
      );
      expect(lescoMeter.connection == sngplMeter.connection, isFalse);
      for (final bill in [novemberBill, octoberBill, gasBill]) {
        _roundTrips(bill, (b) => b.toRow(), UtilityBill.fromRow);
      }
      for (final reading in [moveInReading, octoberReading, novemberReading]) {
        _roundTrips(reading, (r) => r.toRow(), MeterReading.fromRow);
      }
      final charge = octoberBill.charge!;
      _roundTrips(charge, (c) => c.toRow(), BilledCharge.fromRow);
      final detail = UtilityAccountDetail(
        account: lescoMeter,
        bills: Paged([novemberBill]),
        readings: Paged([novemberReading]),
      );
      _roundTrips(detail, (d) => d.toJson(), UtilityAccountDetail.fromJson);
      expect(detail.copyWith(), detail);
      expect(detail.copyWith(account: sngplMeter).account, sngplMeter);
      final reading = ReadingDetail(
        reading: novemberReading,
        connection: lescoMeter.connection,
        previous: octoberReading,
      );
      _roundTrips(reading, (r) => r.toJson(), ReadingDetail.fromJson);
      final first = ReadingDetail(
        reading: moveInReading,
        connection: lescoMeter.connection,
      );
      _roundTrips(first, (r) => r.toJson(), ReadingDetail.fromJson);
      expect(first.consumption, isNull);
      expect(
        () => UtilityBill.fromRow({...novemberBill.toRow(), 'status': 'late'}),
        throwsFormatException,
      );
      expect(
        () =>
            UtilityAccount.fromRow(Map.of(lescoMeter.toRow())..remove('type')),
        throwsFormatException,
      );
    });

    test('a bill is billed while its charge is live, and is measured '
        'against the protected tariff', () {
      expect(octoberBill.liveCharge, octoberBill.charge);
      expect(novemberBill.liveCharge, isNull);
      final voided = UtilityBill.fromRow({
        ...octoberBill.toRow(),
        'charge': {
          'id': 'ch-1',
          'lease_id': aliLease.id,
          'voided_at': '2026-11-01T00:00:00Z',
        },
      });
      expect(voided.charge!.voided, isTrue);
      expect(voided.liveCharge, isNull);
      expect(novemberBill.protectedUse, ProtectedUse.over);
      expect(octoberBill.protectedUse, ProtectedUse.near);
      expect(gasBill.protectedUse, isNull);
      expect(ProtectedTariff.useOf(const Hundredths(20000)), ProtectedUse.near);
      expect(ProtectedTariff.useOf(const Hundredths(20001)), ProtectedUse.over);
      expect(
        ProtectedTariff.useOf(const Hundredths(17999)),
        ProtectedUse.within,
      );
    });

    test('bill drafts are paid exactly when they have a paid date', () {
      final unpaid = BillDraft(
        billingMonth: MonthPeriod(2026, 11),
        amount: const Money.fromRupees(9850),
        unitsConsumed: const Hundredths(21250),
        paidBy: BillPayer.tenant,
        notes: '  ',
      );
      expect(unpaid.toInsert('acc'), {
        'utility_account_id': 'acc',
        'billing_month': '2026-11-01',
        'amount': '9850.00',
        'due_date': null,
        'units_consumed': '212.5',
        'status': 'unpaid',
        'paid_on': null,
        'paid_by': null,
        'notes': null,
      });
      final paid = BillDraft(
        billingMonth: MonthPeriod(2026, 11),
        amount: const Money.fromRupees(9850),
        dueDate: CalendarDate(2026, 11, 5),
        paidOn: CalendarDate(2026, 11, 4),
        paidBy: BillPayer.landlord,
      );
      expect(paid.toInsert('acc'), containsPair('status', 'paid'));
      expect(paid.toInsert('acc'), containsPair('paid_by', 'landlord'));
      expect(paid == unpaid, isFalse);
      expect(paid.hashCode, isA<int>());
      // Saving a bill writes its details only: whether it is paid is
      // BillPayment's, and the connection and month are fixed once added.
      expect(paid.toWrite(), {
        'amount': '9850.00',
        'due_date': '2026-11-05',
        'units_consumed': null,
        'notes': null,
      });
      expect(BillDraft.of(octoberBill).toInsert('acc'), {
        'utility_account_id': 'acc',
        'billing_month': '2026-10-01',
        'amount': '7420.00',
        'due_date': '2026-10-06',
        'units_consumed': '186',
        'status': 'paid',
        'paid_on': '2026-10-04',
        'paid_by': 'tenant',
        'notes': null,
      });
    });

    test('marking a bill paid or unpaid writes only that', () {
      final paid = BillPayment(
        paidOn: CalendarDate(2026, 11, 6),
        paidBy: BillPayer.landlord,
      );
      expect(paid.toWrite(), {
        'status': 'paid',
        'paid_on': '2026-11-06',
        'paid_by': 'landlord',
      });
      expect(const BillPayment.unpaid().toWrite(), {
        'status': 'unpaid',
        'paid_on': null,
        'paid_by': null,
      });
      expect(paid == const BillPayment.unpaid(), isFalse);
      expect(
        BillPayment(paidOn: CalendarDate(2026, 11, 6)).hashCode,
        BillPayment(paidOn: CalendarDate(2026, 11, 6)).hashCode,
      );
    });

    test('drafts write only the columns clients may update', () {
      // The `grant update (...)` lists of 20261103194151_operations.sql.
      const billGrant = {
        'amount',
        'due_date',
        'units_consumed',
        'status',
        'paid_on',
        'paid_by',
        'notes',
      };
      const readingGrant = {'reading', 'read_on', 'context', 'notes'};
      const accountGrant = {
        'unit_id',
        'type',
        'provider',
        'provider_other',
        'reference_number',
        'customer_id',
        'meter_number',
        'account_title',
        'in_landlord_name',
        'is_sub_meter',
        'is_protected_consumer',
        'responsibility',
        'notes',
        'archived_at',
      };
      const requestGrant = {
        'unit_id',
        'lease_id',
        'title',
        'description',
        'category',
        'priority',
        'status',
        'reported_by',
        'reported_on',
        'assigned_to',
        'vendor_phone',
        'estimated_cost',
        'resolved_on',
        'resolution_note',
      };
      const expenseGrant = {
        'property_id',
        'unit_id',
        'maintenance_request_id',
        'category',
        'amount',
        'spent_on',
        'payee',
        'method',
        'reference',
        'notes',
        'paid_by',
      };
      expect(BillDraft.of(novemberBill).toWrite().keys.toSet(), {
        'amount',
        'due_date',
        'units_consumed',
        'notes',
      });
      expect(billGrant, containsAll(BillDraft.of(novemberBill).toWrite().keys));
      expect(const BillPayment.unpaid().toWrite().keys.toSet(), {
        'status',
        'paid_on',
        'paid_by',
      });
      expect(
        ReadingDraft.of(moveInReading).toWrite().keys.toSet(),
        readingGrant,
      );
      expect(
        UtilityAccountDraft.of(lescoMeter).toWrite().keys.toSet(),
        accountGrant.difference({'archived_at'}),
      );
      expect(
        MaintenanceDraft.of(seepageJob).toWrite().keys.toSet(),
        requestGrant,
      );
      expect(
        const MaintenanceMove(MaintenanceStatus.open).toWrite().keys.toSet(),
        {'status', 'resolved_on', 'resolution_note'},
      );
      expect(
        expenseGrant,
        containsAll(ExpenseDraft.of(plumberExpense).toWrite().keys),
      );
    });

    test('drafts made from a stored row store it again', () {
      expect(ReadingDraft.of(moveInReading).toInsert(lescoMeter.id), {
        'utility_account_id': lescoMeter.id,
        'lease_id': aliLease.id,
        'reading': '10450',
        'read_on': '2026-01-15',
        'context': 'move_in',
        'notes': null,
      });
      expect(UtilityAccountDraft.of(lescoMeter).toInsert(), {
        'property_id': gulbergHouse.id,
        'unit_id': groundFloor.id,
        'type': 'electricity',
        'provider': 'lesco',
        'provider_other': null,
        'reference_number': '09269330553008',
        'customer_id': '4567890',
        'meter_number': 'L-12345',
        'account_title': 'Ayesha Khan',
        'in_landlord_name': true,
        'is_sub_meter': false,
        'is_protected_consumer': true,
        'responsibility': 'tenant',
        'notes': null,
      });
      expect(BillDraft.of(gasBill), BillDraft.of(gasBill));
      expect(BillDraft.of(gasBill) == BillDraft.of(novemberBill), isFalse);
    });

    test('connection drafts keep the protected tariff to electricity and '
        'a typed supplier to other', () {
      const draft = UtilityAccountDraft(
        propertyId: 'p',
        type: UtilityType.gas,
        provider: UtilityProvider.sngpl,
        providerOther: 'Ignored',
        referenceNumber: ' 1122 3344 556 ',
        customerId: '',
        meterNumber: 'g/55',
        isProtectedConsumer: true,
        notes: ' Meter by the gate ',
      );
      expect(draft.toInsert(), {
        'property_id': 'p',
        'unit_id': null,
        'type': 'gas',
        'provider': 'sngpl',
        'provider_other': null,
        'reference_number': '11223344556',
        'customer_id': null,
        'meter_number': 'G/55',
        'account_title': null,
        'in_landlord_name': true,
        'is_sub_meter': false,
        'is_protected_consumer': false,
        'responsibility': 'tenant',
        'notes': 'Meter by the gate',
      });
      const other = UtilityAccountDraft(
        propertyId: 'p',
        type: UtilityType.internet,
        providerOther: ' Nayatel ',
      );
      expect(other.toWrite()['provider_other'], 'Nayatel');
      expect(other == draft, isFalse);
      expect(other.hashCode, isA<int>());
    });

    test('readings measure what was used and its pace', () {
      final used = consumptionOf([
        novemberReading,
        moveInReading,
        octoberReading,
      ]);
      expect(used.keys, {octoberReading.id, novemberReading.id});
      final november = used[novemberReading.id]!;
      expect(november.units, const Hundredths(19500));
      expect(november.days, 31);
      // 195 units in 31 days: 188.7 units a month, to the nearest unit.
      expect(november.perMonth, const Hundredths(18900));
      expect(november, Consumption.between(octoberReading, novemberReading));
      expect(november.hashCode, isA<int>());
      // The same day, or a meter that went back, measure nothing.
      expect(Consumption.between(novemberReading, novemberReading), isNull);
      expect(Consumption.between(novemberReading, octoberReading), isNull);
      final sameDay = MeterReading.fromRow({
        ...novemberReading.toRow(),
        'id': 'later',
        'created_at': '2026-11-01T10:00:00+00:00',
      });
      expect(consumptionOf([sameDay, novemberReading]), isEmpty);
      expect(
        latestReading([octoberReading, sameDay, novemberReading]),
        sameDay,
      );
      expect(latestReading(const []), isNull);
      // A reading is measured against the readings around its own day.
      final all = [novemberReading, octoberReading, moveInReading, sameDay];
      expect(readingsAround(all, CalendarDate(2026, 10, 15)), (
        octoberReading,
        novemberReading,
      ));
      // Of the same day, the reading recorded first comes after it.
      expect(
        readingsAround(all, CalendarDate(2026, 10, 31)).$2,
        novemberReading,
      );
      expect(readingsAround(all, CalendarDate(2026, 11, 1)), (sameDay, null));
      expect(readingsAround(all, CalendarDate(2026, 1, 1)), (
        null,
        moveInReading,
      ));
      expect(readingsAround(const [], CalendarDate(2026, 1, 1)), (null, null));
      expect(
        ReadingDetail(
          reading: novemberReading,
          connection: lescoMeter.connection,
          previous: octoberReading,
        ).consumption,
        november,
      );
      final draft = ReadingDraft(
        reading: const Hundredths(1220550),
        readOn: CalendarDate(2026, 11, 1),
        context: ReadingContext.moveOut,
        leaseId: aliLease.id,
        notes: ' ',
      );
      expect(draft.toInsert('acc'), {
        'utility_account_id': 'acc',
        'lease_id': aliLease.id,
        'reading': '12205.5',
        'read_on': '2026-11-01',
        'context': 'move_out',
        'notes': null,
      });
      expect(
        draft,
        isNot(
          equals(
            ReadingDraft(
              reading: const Hundredths(1),
              readOn: CalendarDate(2026, 11, 1),
            ),
          ),
        ),
      );
      expect(draft.hashCode, isA<int>());
    });
  });

  group('maintenance', () {
    test('requests survive the cache and statuses split into to do and '
        'closed', () {
      for (final request in [seepageJob, gateLightJob, tapJob]) {
        _roundTrips(request, (r) => r.toRow(), MaintenanceRequest.fromRow);
      }
      expect(MaintenanceStatus.where(pending: true), [
        MaintenanceStatus.open,
        MaintenanceStatus.inProgress,
        MaintenanceStatus.onHold,
      ]);
      expect(MaintenanceStatus.where(pending: false), [
        MaintenanceStatus.resolved,
        MaintenanceStatus.cancelled,
      ]);
      for (final value in MaintenanceCategory.values) {
        expect(MaintenanceCategory.parse(value.db), value);
      }
      for (final value in MaintenancePriority.values) {
        expect(MaintenancePriority.parse(value.db), value);
      }
      expect(
        () => MaintenanceRequest.fromRow({
          ...seepageJob.toRow(),
          'vendor_phone': '12',
        }),
        throwsFormatException,
      );
    });

    test('drafts keep the resolution only while resolved', () {
      final draft = MaintenanceDraft.of(seepageJob);
      final write = draft.toWrite();
      expect(write['title'], 'Seepage in the bedroom wall');
      expect(write['vendor_phone'], '+923001112233');
      expect(write['estimated_cost'], '12000.00');
      expect(write['resolved_on'], isNull);
      // A resolved job's draft keeps when and how it was resolved.
      final tap = MaintenanceDraft.of(tapJob).toInsert();
      expect(tap['property_id'], gulbergHouse.id);
      expect(tap['status'], 'resolved');
      expect(tap['resolved_on'], '2026-09-12');
      expect(tap['resolution_note'], 'Washer replaced.');
      expect(MaintenanceDraft.of(tapJob) == draft, isFalse);
      expect(draft.hashCode, MaintenanceDraft.of(seepageJob).hashCode);
    });

    test('a move writes the status, and when and how it was resolved while '
        'it is', () {
      final resolved = MaintenanceMove(
        MaintenanceStatus.resolved,
        resolvedOn: CalendarDate(2026, 11, 7),
        resolutionNote: ' Wall sealed ',
      );
      expect(resolved.toWrite(), {
        'status': 'resolved',
        'resolved_on': '2026-11-07',
        'resolution_note': 'Wall sealed',
      });
      // Any other status clears them, whatever it is given.
      final reopened = MaintenanceMove(
        MaintenanceStatus.open,
        resolvedOn: CalendarDate(2026, 11, 7),
        resolutionNote: 'Wall sealed',
      );
      expect(reopened.toWrite(), {
        'status': 'open',
        'resolved_on': null,
        'resolution_note': null,
      });
      expect(resolved == reopened, isFalse);
      expect(reopened, const MaintenanceMove(MaintenanceStatus.open));
      expect(
        reopened.hashCode,
        const MaintenanceMove(MaintenanceStatus.open).hashCode,
      );
    });
  });

  test('places leave archived units out and survive the cache', () {
    final place = PropertyPlace.fromRow(const {
      'id': 'p',
      'name': 'Gulberg House',
      'units': [
        {'id': 'u1', 'label': 'Ground floor', 'archived_at': null},
        {
          'id': 'u2',
          'label': 'Old shop',
          'archived_at': '2026-01-01T00:00:00Z',
        },
      ],
    });
    expect(place.units, const [UnitPlace(id: 'u1', label: 'Ground floor')]);
    _roundTrips(place, (p) => p.toRow(), PropertyPlace.fromRow);
    expect(place.unitLabel('u1'), 'Ground floor');
    expect(place.unitLabel('u2'), isNull);
    expect(placeOf([place], 'p'), place);
    expect(placeOf([place], 'q'), isNull);
    expect(const UnitPlace(id: 'a', label: 'b').hashCode, isA<int>());
  });

  test('payment methods the database refuses for expenses are not offered', () {
    expect(
      PaymentMethod.received,
      isNot(contains(PaymentMethod.depositAdjustment)),
    );
  });
}
