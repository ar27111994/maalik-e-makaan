import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

/// A `properties` row as PostgREST returns it.
final Map<String, Object?> _propertyRow = {
  'id': gulbergHouse.id,
  'name': 'Gulberg House',
  'type': 'house',
  'address_line': '42-B, Main Boulevard',
  'locality': 'Gulberg III',
  'city': 'Lahore',
  'province': 'punjab',
  'plot_size': 10,
  'plot_size_unit': 'marla',
  'covered_area_sqft': 3200,
  'year_built': 2012,
  'purchase_price': 32000000,
  'purchased_on': '2015-03-01',
  'estimated_value': 60000000.0,
  'value_estimated_on': '2026-06-30',
  'property_tax_ref': 'LHR-GB-11234',
  'notes': 'Gate key with the guard.',
  'archived_at': null,
  'created_at': '2026-01-05T09:00:00+00:00',
};

final Map<String, Object?> _unitRow = {
  'id': groundFloor.id,
  'property_id': gulbergHouse.id,
  'label': 'Ground floor',
  'type': 'portion',
  'floor_label': 'Ground',
  'bedrooms': 3,
  'bathrooms': 3,
  'covered_area_sqft': 1600,
  'furnished': false,
  'asking_rent': 85000.0,
  'is_available': true,
  'notes': null,
  'archived_at': null,
  'created_at': '2026-01-05T09:01:00+00:00',
};

final Map<String, Object?> _occupancyRow = {
  'unit_id': groundFloor.id,
  'status': 'occupied',
  'vacant_since': null,
  'lease_id': 'lease-1',
  'tenant_id': 'tenant-1',
};

void main() {
  late MockSupabase supabase;
  late SupabasePropertyRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse([_propertyRow]));
    repository = SupabasePropertyRepository(
      supabase.client,
      clock: () => DateTime.utc(2026, 11, 7, 5),
    );
  });

  group('models', () {
    test('a property reads every column, exactly', () {
      final property = Property.fromRow(_propertyRow);
      expect(property, gulbergHouse);
      expect(property.hashCode, gulbergHouse.hashCode);
      expect(Property.fromRow(property.toRow()), property);
      expect(
        property.cursor,
        PageCursor(createdAt: '2026-01-05T09:00:00+00:00', id: gulbergHouse.id),
      );
      final bare = Property.fromRow({
        for (final MapEntry(:key, :value) in _propertyRow.entries)
          key:
              const {
                'id',
                'name',
                'type',
                'city',
                'province',
                'created_at',
              }.contains(key)
              ? value
              : null,
        'archived_at': '2026-05-01T07:00:00+00:00',
      });
      expect(bare.archived, isTrue);
      expect(bare.plotSize, isNull);
      expect(Property.fromRow(bare.toRow()), bare);
    });

    test('malformed rows are refused', () {
      for (final row in <Object?>[
        null,
        {..._propertyRow}..remove('province'),
        {..._propertyRow, 'type': 'castle'},
        {..._propertyRow, 'province': 'kashmir'},
        {..._propertyRow, 'plot_size': 'ten'},
        {..._propertyRow, 'purchased_on': '01/03/2015'},
        {..._propertyRow, 'archived_at': 'soon'},
        {..._propertyRow, 'plot_size_unit': 'bigha'},
      ]) {
        expect(
          () => Property.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
      for (final row in <Object?>[
        {..._unitRow}..remove('furnished'),
        {..._unitRow, 'type': 'tent'},
        {..._unitRow, 'asking_rent': true},
      ]) {
        expect(() => Unit.fromRow(row), throwsFormatException, reason: '$row');
      }
      expect(
        () => Occupancy.fromRow({..._occupancyRow, 'vacant_since': 3}),
        throwsFormatException,
      );
    });

    test('writes are tidied and keep only the editable columns', () {
      final write = const Property(
        id: 'p',
        name: '  Gulberg   House ',
        type: PropertyType.apartmentBuilding,
        city: ' Lahore ',
        province: Province.khyberPakhtunkhwa,
        addressLine: '  ',
        plotSize: Hundredths(250),
        notes: 'Line one  \r\n\r\n\r\n line two',
      ).toWrite();
      expect(write, {
        'name': 'Gulberg House',
        'type': 'apartment_building',
        'address_line': null,
        'locality': null,
        'city': 'Lahore',
        'province': 'khyber_pakhtunkhwa',
        'plot_size': '2.5',
        'plot_size_unit': null,
        'covered_area_sqft': null,
        'year_built': null,
        'purchase_price': null,
        'purchased_on': null,
        'estimated_value': null,
        'value_estimated_on': null,
        'property_tax_ref': null,
        'notes': 'Line one\n\nline two',
      });
      expect(
        const Unit(
          id: 'u',
          propertyId: 'p',
          label: 'x',
          type: UnitType.bed,
          notes: ' ',
        ).toWrite()['notes'],
        isNull,
      );
    });

    test('units and their occupancy', () {
      final unit = Unit.fromRow(_unitRow);
      expect(unit, groundFloor);
      expect(unit.hashCode, groundFloor.hashCode);
      final summary = UnitSummary(unit, Occupancy.fromRow(_occupancyRow));
      expect(UnitSummary.fromJson(summary.toJson()), summary);
      expect(UnitSummary.fromJson(summary.toJson()).hashCode, summary.hashCode);
      expect(
        UnitSummary.fromJson(UnitSummary(unit, null).toJson()).occupancy,
        isNull,
      );
      for (final status in OccupancyStatus.values) {
        expect(OccupancyStatus.parse(status.db), status);
      }
      expect(OccupancyStatus.parse('haunted'), OccupancyStatus.unknown);
    });

    test('hundredths read and write exactly', () {
      expect(Hundredths.fromJson(10.5), const Hundredths(1050));
      expect(Hundredths.tryParse(' ۵.۲۵ '), const Hundredths(525));
      expect(Hundredths.tryParse('5.255'), isNull);
      expect('${const Hundredths(500)}', '5');
      expect('${const Hundredths(550)}', '5.5');
      expect('${const Hundredths(505)}', '5.05');
      expect(const Hundredths(1).compareTo(const Hundredths(2)), isNegative);
      expect(const Hundredths(1).hashCode, const Hundredths(1).hashCode);
      expect(const Hundredths(0).isPositive, isFalse);
    });

    test('every database value has a case', () {
      for (final type in PropertyType.values) {
        expect(PropertyType.parse(type.db), type);
      }
      for (final province in Province.values) {
        expect(Province.parse(province.db), province);
      }
      for (final unit in AreaUnit.values) {
        expect(AreaUnit.parse(unit.db), unit);
      }
      for (final type in UnitType.values) {
        expect(UnitType.parse(type.db), type);
      }
    });

    test('police rules follow app.police_registration_rule', () {
      final start = CalendarDate(2026, 11, 1);
      final signed = CalendarDate(2026, 10, 28);
      final deadlines = {
        for (final province in Province.values)
          province: province.policeRule.deadline(start, signed),
      };
      expect(deadlines, {
        Province.punjab: CalendarDate(2026, 11, 16),
        Province.sindh: CalendarDate(2026, 11, 3),
        Province.khyberPakhtunkhwa: CalendarDate(2026, 11, 4),
        Province.balochistan: CalendarDate(2026, 10, 31),
        Province.islamabad: CalendarDate(2026, 11, 2),
        Province.gilgitBaltistan: CalendarDate(2026, 11, 2),
        Province.azadKashmir: CalendarDate(2026, 11, 2),
      });
      // Without an agreement date the agreement clock starts at the start.
      expect(
        Province.balochistan.policeRule.deadline(start, null),
        CalendarDate(2026, 11, 4),
      );
      expect(Province.islamabad.policeRule.statutory, isFalse);
      expect(Province.punjab.policeRule, PoliceRule.of(Province.punjab));
      expect(
        Province.punjab.policeRule.hashCode,
        PoliceRule.of(Province.punjab).hashCode,
      );
    });
  });

  group('properties', () {
    test('a page in use, oldest first, 50 at a time', () async {
      final page = await repository.properties(gulberg.id, archived: false);
      expect(page.items.single, gulbergHouse);
      expect(page.hasMore, isFalse);
      expect(supabase.request.url.path, '/rest/v1/properties');
      expect(supabase.request.url.queryParameters, {
        'select': Property.columns,
        'portfolio_id': 'eq.${gulberg.id}',
        'archived_at': 'is.null',
        'order': 'created_at.asc.nullslast,id.asc.nullslast',
        'limit': '50',
      });
    });

    test('the next page of the archived starts after the cursor', () async {
      supabase.respond = (_) async =>
          jsonResponse(List.filled(pageSize, _propertyRow));
      final page = await repository.properties(
        gulberg.id,
        archived: true,
        after: const PageCursor(
          createdAt: '2026-01-05T09:00:00.5+00:00',
          id: 'p1',
        ),
      );
      expect(page.next, gulbergHouse.cursor);
      final query = supabase.request.url.queryParameters;
      expect(query['archived_at'], 'not.is.null');
      expect(
        query['or'],
        '(created_at.gt."2026-01-05T09:00:00.5+00:00",'
        'and(created_at.eq."2026-01-05T09:00:00.5+00:00",id.gt."p1"))',
      );
    });

    test('one property', () async {
      supabase.respond = (_) async => jsonResponse(_propertyRow);
      expect(await repository.property(gulbergHouse.id), gulbergHouse);
      expect(
        supabase.request.url.queryParameters['id'],
        'eq.${gulbergHouse.id}',
      );
    });

    test('adding inserts the granted columns with the attempt id', () async {
      supabase.respond = (_) async => jsonResponse(_propertyRow, status: 201);
      expect(
        await repository.createProperty(gulberg.id, gulbergHouse),
        gulbergHouse,
      );
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.queryParameters, {'select': Property.columns});
      expect(bodyOf(request), {
        'id': gulbergHouse.id,
        'portfolio_id': gulberg.id,
        ...gulbergHouse.toWrite(),
      });
    });

    test('a retried add returns the property already added', () async {
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(_propertyRow);
      expect(
        await repository.createProperty(gulberg.id, gulbergHouse),
        gulbergHouse,
      );
      expect(
        supabase.requests.last.url.queryParameters['id'],
        'eq.${gulbergHouse.id}',
      );
    });

    test('a name in use is refused', () async {
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(<Object?>[]);
      await expectLater(
        repository.createProperty(gulberg.id, gulbergHouse),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'duplicate_property_name',
          ),
        ),
      );
      supabase.respond = (_) async => postgrestError('23505', status: 409);
      await expectLater(
        repository.updateProperty(gulbergHouse),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'duplicate_property_name',
          ),
        ),
      );
      supabase.respond = (_) async => postgrestError('23514');
      await expectLater(
        repository.createProperty(gulberg.id, gulbergHouse),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
    });

    test('editing patches the editable columns', () async {
      supabase.respond = (_) async => jsonResponse(_propertyRow);
      await repository.updateProperty(gulbergHouse);
      final request = supabase.request;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters, {
        'id': 'eq.${gulbergHouse.id}',
        'select': Property.columns,
      });
      expect(bodyOf(request), gulbergHouse.toWrite());
    });

    test('archiving sets the time, restoring clears it', () async {
      supabase.respond = (_) async => jsonResponse(_propertyRow);
      await repository.archiveProperty(gulbergHouse.id, archived: true);
      expect(bodyOf(supabase.requests.last), {
        'archived_at': '2026-11-07T05:00:00.000Z',
      });
      await repository.archiveProperty(gulbergHouse.id, archived: false);
      expect(bodyOf(supabase.requests.last), {'archived_at': null});
    });

    test('deleting: done, refused when in use, or not allowed', () async {
      supabase.respond = (_) async => jsonResponse([
        {'id': gulbergHouse.id},
      ]);
      await repository.deleteProperty(gulbergHouse.id);
      expect(supabase.request.method, 'DELETE');
      expect(supabase.request.url.queryParameters, {
        'id': 'eq.${gulbergHouse.id}',
        'select': 'id',
      });
      supabase.respond = (_) async => postgrestError('23503', status: 409);
      await expectLater(
        repository.deleteProperty(gulbergHouse.id),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'still_in_use',
          ),
        ),
      );
      supabase.respond = (_) async => jsonResponse(<Object?>[]);
      await expectLater(
        repository.deleteUnit(groundFloor.id),
        throwsA(isA<Forbidden>()),
      );
      supabase.respond = (_) async => postgrestError('42501', status: 403);
      await expectLater(
        repository.deleteUnit(groundFloor.id),
        throwsA(isA<Forbidden>()),
      );
    });
  });

  group('units', () {
    setUp(() {
      supabase.respond = (request) async =>
          request.url.path.endsWith('/unit_occupancy')
          ? jsonResponse([_occupancyRow])
          : request.url.queryParameters.containsKey('limit')
          ? jsonResponse([
              _unitRow,
              {..._unitRow, 'id': 'u2'},
            ])
          : jsonResponse(_unitRow);
    });

    test('a page of a property with their occupancy', () async {
      final page = await repository.units(gulbergHouse.id);
      expect(page.items.first.unit, groundFloor);
      expect(page.items.first.occupancy!.status, OccupancyStatus.occupied);
      expect(page.items.last.occupancy, isNull);
      final [units, occupancy] = supabase.requests;
      expect(units.url.queryParameters, {
        'select': Unit.columns,
        'property_id': 'eq.${gulbergHouse.id}',
        'order': 'created_at.asc.nullslast,id.asc.nullslast',
        'limit': '50',
      });
      expect(occupancy.url.queryParameters, {
        'select': Occupancy.columns,
        'unit_id': 'in.("${groundFloor.id}","u2")',
      });
    });

    test('a property without units reads no occupancy', () async {
      supabase.respond = (_) async => jsonResponse(<Object?>[]);
      expect((await repository.units(gulbergHouse.id)).items, isEmpty);
      expect(supabase.requests, hasLength(1));
    });

    test('one unit', () async {
      final summary = await repository.unit(groundFloor.id);
      expect(summary.unit, groundFloor);
      expect(summary.occupancy!.leaseId, 'lease-1');
    });

    test('adding, editing and archiving', () async {
      await repository.createUnit(gulberg.id, groundFloor);
      expect(bodyOf(supabase.requests.last), {
        'id': groundFloor.id,
        'portfolio_id': gulberg.id,
        'property_id': gulbergHouse.id,
        ...groundFloor.toWrite(),
      });
      await repository.updateUnit(groundFloor);
      expect(bodyOf(supabase.requests.last), groundFloor.toWrite());
      await repository.archiveUnit(groundFloor.id, archived: true);
      expect(bodyOf(supabase.requests.last), {
        'archived_at': '2026-11-07T05:00:00.000Z',
      });
      supabase.respond = (_) async => jsonResponse([
        {'id': groundFloor.id},
      ]);
      await repository.deleteUnit(groundFloor.id);
      expect(supabase.requests.last.url.path, '/rest/v1/units');
    });

    test('a label in use is refused', () async {
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(<Object?>[]);
      await expectLater(
        repository.createUnit(gulberg.id, groundFloor),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'duplicate_unit_label',
          ),
        ),
      );
    });

    test('read failures are AppFailures', () async {
      supabase.respond = (_) async => postgrestError('PGRST301', status: 401);
      await expectLater(
        repository.units(gulbergHouse.id),
        throwsA(isA<SessionExpired>()),
      );
      await expectLater(
        repository.unit(groundFloor.id),
        throwsA(isA<SessionExpired>()),
      );
    });
  });

  test('the provider builds the Supabase repository', () {
    expect(
      SupabasePropertyRepository(supabase.client),
      isA<PropertyRepository>(),
    );
  });
}
