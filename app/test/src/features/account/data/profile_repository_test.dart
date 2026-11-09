import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

final Map<String, Object?> _row = {
  'id': testUserId,
  'email': testEmail,
  'full_name': 'Ayesha Khan',
  'phone': '+923001234567',
  'locale': 'ur',
};

void main() {
  late MockSupabase supabase;
  late SupabaseProfileRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse(_row));
    repository = SupabaseProfileRepository(supabase.client);
  });

  group('Profile.fromRow', () {
    test('reads a PostgREST row', () {
      final profile = Profile.fromRow(_row);
      expect(profile.id, testUserId);
      expect(profile.email, testEmail);
      expect(profile.fullName, 'Ayesha Khan');
      expect(profile.phone, PhoneNumber.fromE164('+923001234567'));
      expect(profile.language, AppLanguage.urdu);
      expect(Profile.fromRow(profile.toRow()), profile);
      expect(profile.hashCode, Profile.fromRow(_row).hashCode);
    });

    test('accepts a missing phone and e-mail', () {
      final profile = Profile.fromRow({..._row, 'phone': null, 'email': null});
      expect(profile.phone, isNull);
      expect(profile.email, isNull);
      expect(profile, isNot(Profile.fromRow(_row)));
    });

    test('refuses malformed rows', () {
      for (final row in <Object?>[
        null,
        [_row],
        {..._row}..remove('full_name'),
        {..._row, 'id': 7},
        {..._row, 'phone': '0300 1234567'},
        {..._row, 'locale': 'fr'},
        {..._row, 'email': false},
      ]) {
        expect(
          () => Profile.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
    });

    test('copyWith changes the language only', () {
      final profile = Profile.fromRow(_row);
      final english = profile.copyWith(language: AppLanguage.english);
      expect(english.language, AppLanguage.english);
      expect(english.fullName, profile.fullName);
      expect(profile.copyWith(), profile);
    });

    test('languages parse from their codes only', () {
      expect(AppLanguage.parse('en'), AppLanguage.english);
      expect(AppLanguage.parse('ur'), AppLanguage.urdu);
      expect(() => AppLanguage.parse('EN'), throwsFormatException);
    });
  });

  group('requests', () {
    test('fetch selects the profile columns of the user', () async {
      final profile = await repository.fetch(testUserId);
      expect(profile.fullName, 'Ayesha Khan');
      final request = supabase.request;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/profiles');
      expect(request.url.queryParameters, {
        'select': 'id,email,full_name,phone,locale',
        'id': 'eq.$testUserId',
      });
      expect(request.headers['accept'], 'application/vnd.pgrst.object+json');
      expect(request.headers['apikey'], 'sb_publishable_test');
    });

    test('updateDetails sends only the granted columns, tidied', () async {
      await repository.updateDetails(
        testUserId,
        fullName: '  Ayesha   Khan\u202e ',
        phone: PhoneNumber.fromE164('+923001234567'),
      );
      final request = supabase.request;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/rest/v1/profiles');
      expect(request.url.queryParameters, {
        'id': 'eq.$testUserId',
        'select': 'id,email,full_name,phone,locale',
      });
      expect(bodyOf(request), {
        'full_name': 'Ayesha Khan',
        'phone': '+923001234567',
      });
      expect(request.headers['prefer'], contains('return=representation'));
    });

    test('updateDetails can clear the phone', () async {
      await repository.updateDetails(testUserId, fullName: 'A', phone: null);
      expect(bodyOf(supabase.request), {'full_name': 'A', 'phone': null});
    });

    test('updateLanguage sends the locale alone', () async {
      supabase.respond = (_) async => http.Response('', 204);
      await repository.updateLanguage(testUserId, AppLanguage.urdu);
      final request = supabase.request;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters, {'id': 'eq.$testUserId'});
      expect(bodyOf(request), {'locale': 'ur'});
    });
  });

  group('failures', () {
    test('a refused update is a RejectedFailure', () async {
      supabase.respond = (_) async => postgrestError('23514');
      await expectLater(
        repository.updateDetails(testUserId, fullName: 'x', phone: null),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
    });

    test('a deleted account cannot write', () async {
      supabase.respond = (_) async =>
          postgrestError('22023', message: 'account_deleted');
      await expectLater(
        repository.updateLanguage(testUserId, AppLanguage.english),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'account_deleted',
          ),
        ),
      );
    });

    test(
      'a missing row is NotFound; a malformed one a ServerFailure',
      () async {
        supabase.respond = (_) async =>
            postgrestError('PGRST116', status: 406, message: 'no rows');
        await expectLater(
          repository.fetch(testUserId),
          throwsA(isA<NotFoundFailure>()),
        );
        supabase.respond = (_) async => jsonResponse({..._row, 'locale': 'fr'});
        await expectLater(
          repository.fetch(testUserId),
          throwsA(isA<ServerFailure>()),
        );
      },
    );

    test('no connection is a NetworkFailure', () async {
      supabase.respond = (_) async => throw http.ClientException('offline');
      await expectLater(
        repository.fetch(testUserId),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('rate limits carry the wait', () async {
      supabase.respond = (_) async =>
          postgrestError('rate_limited', status: 429, hint: '60');
      await expectLater(
        repository.updateLanguage(testUserId, AppLanguage.english),
        throwsA(
          isA<RateLimited>().having(
            (f) => f.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          ),
        ),
      );
    });
  });
}
