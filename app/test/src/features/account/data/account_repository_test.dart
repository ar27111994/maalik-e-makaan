import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

const Map<String, Object?> _previewJson = {
  'portfolios_to_delete': [
    {'id': 'p1', 'name': 'Gulberg Houses', 'other_members': 2},
  ],
  'reauth_max_age_seconds': 600,
  'second_factor_required': false,
};

void main() {
  late MockSupabase supabase;
  late SupabaseAccountRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse(_previewJson));
    repository = SupabaseAccountRepository(supabase.client);
  });

  group('DeletionPreview.fromJson', () {
    test('reads the function answer', () {
      final preview = DeletionPreview.fromJson(_previewJson);
      expect(
        preview,
        const DeletionPreview(
          portfoliosToDelete: [
            DoomedPortfolio(id: 'p1', name: 'Gulberg Houses', otherMembers: 2),
          ],
          reauthMaxAge: Duration(minutes: 10),
          secondFactorRequired: false,
        ),
      );
      expect(preview.hashCode, DeletionPreview.fromJson(_previewJson).hashCode);
      expect(
        preview.portfoliosToDelete.single.hashCode,
        const DoomedPortfolio(
          id: 'p1',
          name: 'Gulberg Houses',
          otherMembers: 2,
        ).hashCode,
      );
    });

    test('refuses malformed answers', () {
      for (final json in <Object?>[
        null,
        {..._previewJson}..remove('second_factor_required'),
        {..._previewJson, 'portfolios_to_delete': <String, Object?>{}},
        {..._previewJson, 'reauth_max_age_seconds': '600'},
        {
          ..._previewJson,
          'portfolios_to_delete': [
            {'id': 'p1', 'name': 'x'},
          ],
        },
      ]) {
        expect(
          () => DeletionPreview.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  group('requests', () {
    test('the preview is a GET to delete-account', () async {
      final preview = await repository.deletionPreview();
      expect(preview.portfoliosToDelete.single.name, 'Gulberg Houses');
      final request = supabase.request;
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$supabaseUrl/functions/v1/delete-account',
      );
      expect(request.body, isEmpty);
    });

    test('deleting posts the typed e-mail alone', () async {
      supabase.respond = (_) async => jsonResponse({
        'deleted': true,
        'deleted_portfolio_ids': ['p1', 'p2'],
        'files_removed': 3,
      });
      expect(await repository.deleteAccount(confirmEmail: ' $testEmail '), 2);
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '$supabaseUrl/functions/v1/delete-account',
      );
      expect(request.headers['content-type'], startsWith('application/json'));
      expect(bodyOf(request), {'confirm_email': testEmail});
    });

    test('an answer that is not a deletion is a ServerFailure', () async {
      for (final body in <Object?>[
        {'deleted': false, 'deleted_portfolio_ids': <String>[]},
        {'deleted': true},
        'deleted',
      ]) {
        supabase.respond = (_) async => jsonResponse(body);
        await expectLater(
          repository.deleteAccount(confirmEmail: testEmail),
          throwsA(isA<ServerFailure>()),
          reason: '$body',
        );
      }
    });
  });

  group('failures', () {
    Matcher rejected(String reason) =>
        isA<RejectedFailure>().having((f) => f.reason, 'reason', reason);

    test('map from the function envelope', () async {
      final cases = {
        functionError(
          401,
          'reauthentication_required',
          details: {'reauth_max_age_seconds': 600},
        ): isA<ReauthenticationRequired>(),
        functionError(
          401,
          'unauthorized',
          details: {'reason': 'session_ended'},
        ): isA<SessionExpired>(),
        functionError(
          422,
          'validation_failed',
          details: {
            'field': 'confirm_email',
            'reason': 'does_not_match_account',
          },
        ): rejected(
          'does_not_match_account',
        ),
        functionError(403, 'mfa_required'): rejected('mfa_required'),
        functionError(
          429,
          'rate_limited',
          details: {'retry_after': 120},
        ): isA<RateLimited>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 120),
        ),
        functionError(503, 'temporarily_unavailable'):
            isA<TemporarilyUnavailable>(),
        functionError(502, 'upstream_error'): isA<ServerFailure>(),
      };
      for (final MapEntry(key: response, value: matcher) in cases.entries) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.deleteAccount(confirmEmail: testEmail),
          throwsA(matcher),
        );
      }
    });

    test('no connection is a NetworkFailure', () async {
      supabase.respond = (_) async => throw http.ClientException('offline');
      await expectLater(
        repository.deletionPreview(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
