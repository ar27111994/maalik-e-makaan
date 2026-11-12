import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

final Map<String, Object?> _row = {
  'residence_country': 'GB',
  'time_zone': 'Europe/London',
  'stated_at': '2026-11-12T10:15:00+00:00',
};

final _london = AccountResidence(
  residence: Residence(
    country: CountryCode.parse('GB'),
    timeZone: TimeZoneId.parse('Europe/London'),
  ),
  statedAt: DateTime.utc(2026, 11, 12, 10, 15),
);

void main() {
  late MockSupabase supabase;
  late SupabaseResidenceRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse(_row));
    repository = SupabaseResidenceRepository(supabase.client);
  });

  group('AccountResidence.fromRow', () {
    test('reads what the person stated', () {
      final residence = AccountResidence.fromRow(_row);
      expect(residence, _london);
      expect(residence.hashCode, _london.hashCode);
      expect(residence.stated, isTrue);
      expect(residence.alertZone.name, 'Europe/London');
      expect(AccountResidence.fromRow(residence.toRow()), residence);
    });

    test('nothing stated is Pakistan time, and may be asked once', () {
      final empty = AccountResidence.fromRow(const {
        'residence_country': null,
        'time_zone': null,
        'stated_at': null,
      });
      expect(empty, AccountResidence.notStated);
      expect(empty.stated, isFalse);
      expect(empty.alertZone, TimeZoneId.pakistan);
      expect(empty.residence.status, ResidenceStatus.notStated);
      expect(AccountResidence.fromRow(empty.toRow()), empty);
      // Chose not to say: answered, nothing stated.
      final declined = AccountResidence.fromRow({
        ...empty.toRow(),
        'stated_at': '2026-11-12T10:15:00Z',
      });
      expect(declined.stated, isTrue);
      expect(declined, isNot(empty));
    });

    test('a country or zone a newer app stored is kept, alerts in PKT', () {
      final newer = AccountResidence.fromRow({
        ..._row,
        'residence_country': 'XK',
        'time_zone': 'America/Somewhere_New',
      });
      expect(newer.residence.country!.isKnown, isFalse);
      expect(newer.residence.timeZone!.isKnown, isFalse);
      expect(newer.alertZone, TimeZoneId.pakistan);
    });

    test('refuses malformed rows', () {
      for (final row in <Object?>[
        null,
        {..._row}..remove('stated_at'),
        {..._row}..remove('time_zone'),
        {..._row, 'residence_country': 'gb'},
        {..._row, 'residence_country': 44},
        {..._row, 'time_zone': 'UTC'},
        {..._row, 'stated_at': 'yesterday'},
      ]) {
        expect(
          () => AccountResidence.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
    });
  });

  group('requests', () {
    test('fetch reads the own row', () async {
      expect(await repository.fetch(testUserId), _london);
      final request = supabase.request;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/profile_residences');
      expect(request.url.queryParameters, {
        'select': 'residence_country,time_zone,stated_at',
        'user_id': 'eq.$testUserId',
      });
      expect(request.headers['accept'], 'application/vnd.pgrst.object+json');
    });

    test('update writes the two answers and reads back the stamp', () async {
      final saved = await repository.update(
        testUserId,
        country: CountryCode.parse('GB'),
        timeZone: TimeZoneId.parse('Europe/London'),
      );
      expect(saved, _london);
      final request = supabase.request;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters, {
        'user_id': 'eq.$testUserId',
        'select': 'residence_country,time_zone,stated_at',
      });
      expect(bodyOf(request), {
        'residence_country': 'GB',
        'time_zone': 'Europe/London',
      });
      await repository.update(testUserId, country: null, timeZone: null);
      expect(bodyOf(supabase.requests.last), {
        'residence_country': null,
        'time_zone': null,
      });
    });

    test('maps the refusals', () async {
      final cases = {
        postgrestError(
          '22023',
          message: 'account_deleted',
        ): isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'account_deleted',
        ),
        postgrestError('23514'): isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'constraint_violation',
        ),
        postgrestError('42501', status: 403): isA<Forbidden>(),
      };
      for (final MapEntry(key: response, value: matcher) in cases.entries) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.update(
            testUserId,
            country: CountryCode.pakistan,
            timeZone: null,
          ),
          throwsA(matcher),
        );
      }
      supabase.respond = (_) async =>
          postgrestError('PGRST116', status: 406, message: '0 rows');
      await expectLater(
        repository.fetch(testUserId),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
