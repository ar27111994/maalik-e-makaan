import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

/// A `tenants` row as PostgREST returns it.
final Map<String, Object?> _row = {
  'id': aliRaza.id,
  'kind': 'individual',
  'full_name': 'Ali Raza',
  'guardian_name': 'Ahmed Raza',
  'guardian_relation': 'son_of',
  'cnic': '3520212345671',
  'cnic_expiry': '2030-04-30',
  'ntn': null,
  'phone': '+923001112233',
  'alt_phone': '+924235761234',
  'email': 'ali.raza@example.com',
  'occupation': 'Bank officer',
  'employer': 'Meezan Bank',
  'permanent_address': 'House 7, Street 3, Sargodha',
  'previous_address': null,
  'emergency_contact_name': 'Sana Raza',
  'emergency_contact_phone': '+923004445566',
  'emergency_contact_relation': 'Wife',
  'reference1_name': 'Usman Tariq',
  'reference1_phone': '+923217778899',
  'reference2_name': null,
  'reference2_phone': null,
  'household_size': 4,
  'deducts_withholding_tax': false,
  'consent_recorded_at': '2026-01-10T06:00:00+00:00',
  'consent_note': 'Told about CNIC copy and police form.',
  'notes': null,
  'archived_at': null,
  'created_at': '2026-01-10T06:00:00+00:00',
};

void main() {
  late MockSupabase supabase;
  late SupabaseTenantRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse([_row]));
    repository = SupabaseTenantRepository(
      supabase.client,
      clock: () => DateTime.utc(2026, 11, 7, 5),
    );
  });

  group('Tenant', () {
    test('reads every column; the CNIC stays a Cnic', () {
      final tenant = Tenant.fromRow(_row);
      expect(tenant, aliRaza);
      expect(tenant.hashCode, aliRaza.hashCode);
      expect(tenant.cnic.toString(), '35202-•••••••-1');
      expect(Tenant.fromRow(tenant.toRow()), tenant);
      expect(Tenant.fromRow(techCorp.toRow()), techCorp);
    });

    test('malformed rows are refused', () {
      for (final row in <Object?>[
        null,
        {..._row}..remove('kind'),
        {..._row, 'kind': 'alien'},
        {..._row, 'cnic': '0000000000000'},
        {..._row, 'phone': '03001112233'},
        {..._row, 'guardian_relation': 'cousin_of'},
        {..._row, 'deducts_withholding_tax': 'no'},
      ]) {
        expect(
          () => Tenant.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
      for (final relation in GuardianRelation.values) {
        expect(GuardianRelation.parse(relation.db), relation);
      }
      for (final kind in TenantKind.values) {
        expect(TenantKind.parse(kind.db), kind);
      }
    });

    test('writes are tidied', () {
      final write = Tenant(
        id: 't',
        fullName: '  Ali   Raza ',
        ntn: ' 1234567-8 ',
        email: ' Ali@Example.COM ',
        notes: '   ',
        consentRecordedAt: DateTime.utc(2026, 1, 10, 6),
        reference2: (name: ' ', phone: null),
      ).toWrite();
      expect(write['full_name'], 'Ali Raza');
      expect(write['ntn'], '1234567-8');
      expect(write['email'], 'ali@example.com');
      expect(write['notes'], isNull);
      expect(write['reference2_name'], isNull);
      expect(write['consent_recorded_at'], '2026-01-10T06:00:00.000Z');
      expect(write.keys, isNot(contains('id')));
      expect(write.keys, isNot(contains('archived_at')));
    });

    test('a search becomes safe filter terms', () {
      expect(searchTerms('Ali (Raza), *x*'), (
        text: 'Ali  Raza    x',
        digits: '',
      ));
      expect(searchTerms('0300 111'), (text: '0300 111', digits: '300111'));
      expect(searchTerms('۳۵۲۰۲-'), (text: '۳۵۲۰۲-', digits: '35202'));
      expect(searchTerms('12'), (text: '12', digits: ''));
    });
  });

  group('requests', () {
    test('a page of tenants in use, searched by name, phone or CNIC', () async {
      final page = await repository.tenants(
        gulberg.id,
        archived: false,
        search: 'Ali 0300',
        after: const PageCursor(
          createdAt: '2026-01-01T00:00:00+00:00',
          id: 't0',
        ),
      );
      expect(page.items.single, aliRaza);
      final query = supabase.request.url.queryParametersAll;
      expect(query['select'], [Tenant.columns]);
      expect(query['archived_at'], ['is.null']);
      const at = '"2026-01-01T00:00:00+00:00"';
      const search =
          '(full_name.ilike.*Ali 0300*,phone.ilike.*300*,cnic.ilike.*300*)';
      expect(query['or'], [
        search,
        '(created_at.gt.$at,and(created_at.eq.$at,id.gt."t0"))',
      ]);
      expect(query['limit'], ['50']);
    });

    test('without a search, archived tenants', () async {
      await repository.tenants(gulberg.id, archived: true);
      final query = supabase.request.url.queryParameters;
      expect(query['archived_at'], 'not.is.null');
      expect(query.containsKey('or'), isFalse);
    });

    test('one tenant', () async {
      supabase.respond = (_) async => jsonResponse(_row);
      expect(await repository.tenant(aliRaza.id), aliRaza);
    });

    test('matches by CNIC or phone, apart from the tenant itself', () async {
      supabase.respond = (_) async => jsonResponse([
        {'id': aliRaza.id, 'full_name': 'Ali Raza'},
      ]);
      final matches = await repository.matches(
        gulberg.id,
        cnic: aliRaza.cnic,
        phone: aliRaza.phone,
        exceptId: 'me',
      );
      expect(matches.single, (id: aliRaza.id, fullName: 'Ali Raza'));
      expect(supabase.request.url.queryParameters, {
        'select': 'id,full_name',
        'portfolio_id': 'eq.${gulberg.id}',
        'archived_at': 'is.null',
        'or': '(cnic.eq.3520212345671,phone.eq."+923001112233")',
        'id': 'neq.me',
        'limit': '5',
      });
      expect(await repository.matches(gulberg.id), isEmpty);
      expect(supabase.requests, hasLength(1));
      await repository.matches(gulberg.id, phone: aliRaza.phone);
      expect(
        supabase.requests.last.url.queryParameters['or'],
        '(phone.eq."+923001112233")',
      );
    });

    test('adding inserts the attempt; a retry returns it', () async {
      supabase.respond = (_) async => jsonResponse(_row, status: 201);
      expect(await repository.createTenant(gulberg.id, aliRaza), aliRaza);
      expect(bodyOf(supabase.request), {
        'id': aliRaza.id,
        'portfolio_id': gulberg.id,
        ...aliRaza.toWrite(),
      });
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse([_row]);
      expect(await repository.createTenant(gulberg.id, aliRaza), aliRaza);
    });

    test('a CNIC in use is refused', () async {
      supabase.respond = (request) async => request.method == 'POST'
          ? postgrestError('23505', status: 409)
          : jsonResponse(<Object?>[]);
      await expectLater(
        repository.createTenant(gulberg.id, aliRaza),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'duplicate_cnic',
          ),
        ),
      );
      supabase.respond = (_) async => postgrestError('23505', status: 409);
      await expectLater(
        repository.updateTenant(aliRaza),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'duplicate_cnic',
          ),
        ),
      );
    });

    test('editing, archiving, deleting', () async {
      supabase.respond = (_) async => jsonResponse(_row);
      await repository.updateTenant(aliRaza);
      expect(bodyOf(supabase.requests.last), aliRaza.toWrite());
      expect(supabase.requests.last.method, 'PATCH');
      await repository.archiveTenant(aliRaza.id, archived: true);
      expect(bodyOf(supabase.requests.last), {
        'archived_at': '2026-11-07T05:00:00.000Z',
      });
      await repository.archiveTenant(aliRaza.id, archived: false);
      expect(bodyOf(supabase.requests.last), {'archived_at': null});
      supabase.respond = (_) async => jsonResponse([
        {'id': aliRaza.id},
      ]);
      await repository.deleteTenant(aliRaza.id);
      expect(supabase.requests.last.method, 'DELETE');
      supabase.respond = (_) async => jsonResponse(<Object?>[]);
      await expectLater(
        repository.deleteTenant(aliRaza.id),
        throwsA(isA<Forbidden>()),
      );
      supabase.respond = (_) async => postgrestError('23503', status: 409);
      await expectLater(
        repository.deleteTenant(aliRaza.id),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'still_in_use',
          ),
        ),
      );
      supabase.respond = (_) async => postgrestError('PGRST301', status: 401);
      await expectLater(
        repository.tenant(aliRaza.id),
        throwsA(isA<SessionExpired>()),
      );
      supabase.respond = (_) async => jsonResponse({'id': 'x'});
      await expectLater(
        repository.tenant(aliRaza.id),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  test('the matched CNIC is the stored digits', () {
    expect(Cnic.parse('35202-1234567-1').digits, '3520212345671');
  });
}
