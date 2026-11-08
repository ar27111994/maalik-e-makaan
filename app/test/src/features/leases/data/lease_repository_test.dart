import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease_repository.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

/// A `leases` row with its embeds, as PostgREST returns it.
final Map<String, Object?> _row = {
  'id': aliLease.id,
  'unit_id': groundFloor.id,
  'tenant_id': aliRaza.id,
  'status': 'active',
  'start_date': '2026-01-15',
  'end_date': '2026-12-14',
  'monthly_rent': 85000,
  'rent_due_day': 5,
  'grace_days': 5,
  'security_deposit': 170000.0,
  'increment_percent': 10,
  'increment_interval_months': 12,
  'late_fee_type': 'daily',
  'late_fee_value': 500,
  'late_fee_cap': 5000,
  'prorate_first_month': true,
  'billing_starts_on': '2026-01-15',
  'notice_period_days': 30,
  'permitted_use': 'Family residence',
  'subletting_allowed': false,
  'agreement_signed_on': '2026-01-12',
  'e_stamp_number': 'PB-LHR-2026-445566',
  'e_stamp_amount': 1200,
  'rent_registrar_status': 'not_presented',
  'rent_registrar_office': null,
  'rent_registration_number': null,
  'rent_registered_on': null,
  'police_status': 'pending',
  'police_channel': null,
  'police_station': null,
  'police_reference': null,
  'police_registered_on': null,
  'police_fee': null,
  'utilities_note': 'Tenant pays electricity and gas.',
  'notes': null,
  'moved_out_on': null,
  'end_reason': null,
  'created_at': '2026-01-10T07:00:00+00:00',
  'tenant': {'full_name': 'Ali Raza'},
  'unit': {
    'label': 'Ground floor',
    'property_id': gulbergHouse.id,
    'property': {'name': 'Gulberg House', 'province': 'punjab'},
  },
};

const Map<String, Object?> _occupantRow = {
  'id': 'occ-1',
  'full_name': 'Sana Raza',
  'relation': 'Wife',
  'cnic': '3520276543212',
  'phone': '+923004445566',
};

const Map<String, Object?> _changeRow = {
  'id': 'rc-1',
  'effective_from': '2026-01-01',
  'monthly_rent': 85000,
  'reason': 'initial',
  'note': null,
};

void main() {
  late MockSupabase supabase;
  late SupabaseLeaseRepository repository;

  setUp(() {
    supabase = MockSupabase((request) async {
      final path = request.url.path;
      if (path.endsWith('/lease_occupants')) {
        return jsonResponse([_occupantRow]);
      }
      if (path.endsWith('/rent_changes')) return jsonResponse([_changeRow]);
      return jsonResponse(
        request.headers['accept'] == 'application/vnd.pgrst.object+json'
            ? _row
            : [_row],
      );
    });
    repository = SupabaseLeaseRepository(supabase.client);
  });

  group('models', () {
    test('a lease reads its terms, late fee and names', () {
      final lease = Lease.fromRow(_row);
      expect(lease, aliLease);
      expect(lease.hashCode, aliLease.hashCode);
      expect(Lease.fromRow(lease.toRow()), lease);
      expect(Lease.fromRow(endedLease.toRow()), endedLease);
      expect(lease.policeDeadline, CalendarDate(2026, 1, 30));
      expect(lease.active, isTrue);
      for (final (type, value, cap, policy) in [
        ('none', null, null, const NoLateFee()),
        ('flat', 1000, null, const FlatLateFee(Money.fromRupees(1000))),
        ('percent', 2.5, null, const PercentLateFee(250)),
      ]) {
        final read = Lease.fromRow({
          ..._row,
          'late_fee_type': type,
          'late_fee_value': value,
          'late_fee_cap': cap,
        });
        expect(read.terms.lateFee, policy);
        expect(Lease.fromRow(read.toRow()).terms.lateFee, policy);
      }
    });

    test('malformed rows are refused', () {
      for (final row in <Object?>[
        null,
        {..._row}..remove('tenant'),
        {..._row, 'status': 'paused'},
        {..._row, 'late_fee_type': 'flat', 'late_fee_value': null},
        {..._row, 'late_fee_type': 'weekly'},
        {..._row, 'police_status': 'lost'},
        {
          ..._row,
          'unit': {'label': 'x', 'property_id': 'p', 'property': null},
        },
      ]) {
        expect(() => Lease.fromRow(row), throwsFormatException, reason: '$row');
      }
      expect(
        () => Occupant.fromRow(Map.of(_occupantRow)..['cnic'] = '123'),
        throwsFormatException,
      );
      expect(
        () => RentChange.fromRow(Map.of(_changeRow)..['reason'] = 'whim'),
        throwsFormatException,
      );
    });

    test('every database value has a case', () {
      for (final values in <List<DbEnumProbe>>[
        [
          for (final v in LeaseStatus.values)
            (v.db, () => LeaseStatus.parse(v.db) == v),
        ],
        [
          for (final v in PoliceStatus.values)
            (v.db, () => PoliceStatus.parse(v.db) == v),
        ],
        [
          for (final v in PoliceChannel.values)
            (v.db, () => PoliceChannel.parse(v.db) == v),
        ],
        [
          for (final v in RegistrarStatus.values)
            (v.db, () => RegistrarStatus.parse(v.db) == v),
        ],
        [
          for (final v in EndReason.values)
            (v.db, () => EndReason.parse(v.db) == v),
        ],
        [
          for (final v in RentChangeReason.values)
            (v.db, () => RentChangeReason.parse(v.db) == v),
        ],
      ]) {
        for (final (name, matches) in values) {
          expect(matches(), isTrue, reason: name);
        }
      }
    });

    test('terms write what the client may, editing leaves the start', () {
      final write = aliLease.terms.toWrite();
      expect(write['start_date'], '2026-01-15');
      expect(write['monthly_rent'], '85000.00');
      expect(write['increment_percent'], '10');
      expect(write['late_fee_type'], 'daily');
      expect(write['late_fee_value'], '500.00');
      expect(write['late_fee_cap'], '5000.00');
      final edit = aliLease.terms.toWrite(editable: true);
      for (final column in [
        'start_date',
        'monthly_rent',
        'billing_starts_on',
        'prorate_first_month',
      ]) {
        expect(edit.containsKey(column), isFalse, reason: column);
      }
      final percent = LeaseTerms(
        startDate: CalendarDate(2026, 1, 1),
        monthlyRent: const Money.fromRupees(1),
        billingStartsOn: CalendarDate(2026, 1, 1),
        lateFee: const PercentLateFee(250),
        notes: '  ',
        permittedUse: '  Shop ',
      ).toWrite();
      expect(percent['late_fee_value'], '2.5');
      expect(percent['late_fee_cap'], isNull);
      expect(percent['notes'], isNull);
      expect(percent['permitted_use'], 'Shop');
      expect(
        LeaseTerms(
          startDate: CalendarDate(2026, 1, 1),
          monthlyRent: const Money.fromRupees(1),
          billingStartsOn: CalendarDate(2026, 1, 1),
          lateFee: const FlatLateFee(Money.fromRupees(300)),
        ).toWrite()['late_fee_value'],
        '300.00',
      );
    });

    test('a detail survives the cache', () {
      final detail = LeaseDetail(
        lease: aliLease,
        occupants: [Occupant.fromRow(_occupantRow)],
        rentChanges: [RentChange.fromRow(_changeRow)],
      );
      expect(LeaseDetail.fromJson(detail.toJson()), detail);
      expect(LeaseDetail.fromJson(detail.toJson()).hashCode, detail.hashCode);
      expect(
        detail.occupants.single.hashCode,
        Occupant.fromRow(_occupantRow).hashCode,
      );
      expect(
        detail.rentChanges.single.hashCode,
        RentChange.fromRow(_changeRow).hashCode,
      );
    });
  });

  group('requests', () {
    test('the tenancies of a unit, newest first', () async {
      final leases = await repository.leases(unitId: groundFloor.id);
      expect(leases.single, aliLease);
      expect(supabase.request.url.queryParameters, {
        'select': Lease.columns,
        'unit_id': 'eq.${groundFloor.id}',
        'order': 'start_date.desc.nullslast,id.desc.nullslast',
        'limit': '50',
      });
      await repository.leases(tenantId: aliRaza.id);
      expect(
        supabase.requests.last.url.queryParameters['tenant_id'],
        'eq.${aliRaza.id}',
      );
    });

    test('one tenancy with its occupants and rent history', () async {
      final detail = await repository.lease(aliLease.id);
      expect(detail.lease, aliLease);
      expect(detail.occupants.single.fullName, 'Sana Raza');
      expect(detail.rentChanges.single.reason, RentChangeReason.initial);
      final [_, occupants, changes] = supabase.requests;
      expect(occupants.url.queryParameters, {
        'select': Occupant.columns,
        'lease_id': 'eq.${aliLease.id}',
        'order': 'created_at.asc.nullslast',
      });
      expect(
        changes.url.queryParameters['order'],
        'effective_from.desc.nullslast',
      );
    });

    test('starting inserts the terms; a retry reads the tenancy', () async {
      final lease = await repository.createLease(
        id: aliLease.id,
        portfolioId: gulberg.id,
        unitId: groundFloor.id,
        tenantId: aliRaza.id,
        terms: aliLease.terms,
      );
      expect(lease, aliLease);
      expect(bodyOf(supabase.request), {
        'id': aliLease.id,
        'portfolio_id': gulberg.id,
        'unit_id': groundFloor.id,
        'tenant_id': aliRaza.id,
        ...aliLease.terms.toWrite(),
      });
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(_row);
      expect(
        await repository.createLease(
          id: aliLease.id,
          portfolioId: gulberg.id,
          unitId: groundFloor.id,
          tenantId: aliRaza.id,
          terms: aliLease.terms,
        ),
        aliLease,
      );
    });

    test('an overlapping or archived start is refused', () async {
      for (final (response, reason) in [
        (postgrestError('23P01', status: 409), 'lease_overlap'),
        (postgrestError('22023', message: 'unit_archived'), 'unit_archived'),
        (
          postgrestError('22023', message: 'tenant_archived'),
          'tenant_archived',
        ),
      ]) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.createLease(
            id: 'x',
            portfolioId: gulberg.id,
            unitId: groundFloor.id,
            tenantId: aliRaza.id,
            terms: aliLease.terms,
          ),
          throwsA(
            isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
    });

    test('editing patches the editable terms', () async {
      await repository.updateLease(aliLease.id, aliLease.terms);
      expect(supabase.request.method, 'PATCH');
      expect(bodyOf(supabase.request), aliLease.terms.toWrite(editable: true));
    });

    test('change_rent and end_lease', () async {
      supabase.respond = (_) async => jsonResponse(_row);
      await repository.changeRent(
        aliLease.id,
        from: MonthPeriod(2027, 1),
        rent: const Money.fromRupees(93500),
        reason: RentChangeReason.annualIncrement,
        note: '  Yearly  ',
      );
      expect(supabase.requests.last.url.path, '/rest/v1/rpc/change_rent');
      expect(bodyOf(supabase.requests.last), {
        'p_lease_id': aliLease.id,
        'p_effective_month': '2027-01-01',
        'p_monthly_rent': '93500.00',
        'p_reason': 'annual_increment',
        'p_note': 'Yearly',
      });
      await repository.endLease(
        aliLease.id,
        movedOutOn: CalendarDate(2026, 11, 7),
        reason: EndReason.termCompleted,
      );
      expect(supabase.requests.last.url.path, '/rest/v1/rpc/end_lease');
      expect(bodyOf(supabase.requests.last), {
        'p_lease_id': aliLease.id,
        'p_moved_out_on': '2026-11-07',
        'p_reason': 'term_completed',
      });
      for (final reason in [
        'lease_not_active',
        'invalid_date',
        'reason_required',
      ]) {
        supabase.respond = (_) async =>
            postgrestError('22023', message: reason);
        await expectLater(
          repository.endLease(
            aliLease.id,
            movedOutOn: CalendarDate(2026, 11, 7),
            reason: EndReason.other,
          ),
          throwsA(
            isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
    });

    test('deleting: done, holding records, or not allowed', () async {
      supabase.respond = (_) async => jsonResponse([
        {'id': aliLease.id},
      ]);
      await repository.deleteLease(aliLease.id);
      expect(supabase.request.method, 'DELETE');
      supabase.respond = (_) async =>
          postgrestError('22023', message: 'lease_has_records');
      await expectLater(
        repository.deleteLease(aliLease.id),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'lease_has_records',
          ),
        ),
      );
      supabase.respond = (_) async => jsonResponse(<Object?>[]);
      await expectLater(
        repository.deleteLease(aliLease.id),
        throwsA(isA<Forbidden>()),
      );
    });

    test('occupants are added, edited and removed', () async {
      final occupant = Occupant.fromRow(_occupantRow);
      supabase.respond = (_) async => jsonResponse(_occupantRow);
      await repository.addOccupant(
        portfolioId: gulberg.id,
        leaseId: aliLease.id,
        occupant: occupant,
      );
      expect(bodyOf(supabase.requests.last), {
        'id': 'occ-1',
        'portfolio_id': gulberg.id,
        'lease_id': aliLease.id,
        ...occupant.toWrite(),
      });
      await repository.updateOccupant(occupant);
      expect(bodyOf(supabase.requests.last), occupant.toWrite());
      supabase.respond = (_) async => jsonResponse([
        {'id': 'occ-1'},
      ]);
      await repository.deleteOccupant('occ-1');
      expect(supabase.requests.last.url.path, '/rest/v1/lease_occupants');
      supabase.respond = (_) async => jsonResponse(<Object?>[]);
      await expectLater(
        repository.deleteOccupant('occ-1'),
        throwsA(isA<Forbidden>()),
      );
    });
  });

  test('province rules give the police deadline', () {
    expect(Province.sindh.policeRule.days, 2);
  });
}

/// A database value and whether it reads back as its case.
typedef DbEnumProbe = (String, bool Function());
