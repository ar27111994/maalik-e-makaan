import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _postgrest(
  String? code, [
  String message = 'm',
  String? hint,
]) => PostgrestException(message: message, code: code, hint: hint);

FunctionException _function(int status, [Object? details]) =>
    FunctionException(status: status, details: details);

Map<String, Object?> _envelope(String code, [Map<String, Object?>? details]) =>
    {
      'error': {'code': code, 'message': 'x', 'details': details},
    };

void main() {
  group('database errors', () {
    test('rate limits carry the wait from the hint', () {
      final failure = AppFailure.from(
        _postgrest('rate_limited', 'Too many', '30'),
      );
      expect(failure, isA<RateLimited>());
      expect((failure as RateLimited).retryAfter, const Duration(seconds: 30));
      expect(
        (AppFailure.from(
          _postgrest('rate_limited', 'x', 'soon'),
        ) as RateLimited).retryAfter,
        isNull,
      );
      expect(
        (AppFailure.from(
          _postgrest('rate_limited', 'x', '0'),
        ) as RateLimited).retryAfter,
        isNull,
      );
    });

    test('maps SQLSTATEs and PostgREST codes', () {
      final cases = <String?, Type>{
        'PGRST301': SessionExpired,
        'PGRST302': SessionExpired,
        'PGRST303': SessionExpired,
        '42501': Forbidden,
        '23505': ConflictFailure,
        'PGRST116': NotFoundFailure,
        '40P01': TemporarilyUnavailable,
        '40001': TemporarilyUnavailable,
        '55P03': TemporarilyUnavailable,
        '57014': TemporarilyUnavailable,
        'PGRST300': ServerFailure,
        'XX000': ServerFailure,
      };
      for (final MapEntry(key: code, value: type) in cases.entries) {
        expect(
          AppFailure.from(_postgrest(code)).runtimeType,
          type,
          reason: code,
        );
      }
    });

    test('a domain refusal carries its stable key', () {
      final failure = AppFailure.from(_postgrest('22023', 'last_owner'));
      expect((failure as RejectedFailure).reason, 'last_owner');
      for (final code in ['23503', '23514', '22P02']) {
        expect(
          (AppFailure.from(_postgrest(code)) as RejectedFailure).reason,
          'constraint_violation',
          reason: code,
        );
      }
    });

    test('an empty code is a network failure when the message says so', () {
      expect(
        AppFailure.from(_postgrest('', 'ClientException: Connection refused')),
        isA<NetworkFailure>(),
      );
      expect(
        AppFailure.from(_postgrest(null, 'request timed out')),
        isA<NetworkFailure>(),
      );
      final other = AppFailure.from(_postgrest('', 'bad gateway'));
      expect((other as ServerFailure).code, 'database');
    });
  });

  group('auth errors', () {
    test('network and missing sessions', () {
      expect(
        AppFailure.from(AuthRetryableFetchException(message: 'offline')),
        isA<NetworkFailure>(),
      );
      expect(
        AppFailure.from(AuthSessionMissingException()),
        isA<SessionExpired>(),
      );
    });

    test('maps GoTrue error codes to reasons', () {
      final reasons = {
        'invalid_credentials': 'invalid_credentials',
        'email_not_confirmed': 'email_not_confirmed',
        'user_already_exists': 'email_taken',
        'email_exists': 'email_taken',
        'weak_password': 'weak_password',
        'same_password': 'same_password',
      };
      for (final MapEntry(key: code, value: reason) in reasons.entries) {
        final failure = AppFailure.from(
          AuthException('m', code: code, statusCode: '400'),
        );
        expect((failure as RejectedFailure).reason, reason, reason: code);
      }
    });

    test('rate limits and ended sessions', () {
      for (final code in [
        'over_email_send_rate_limit',
        'over_request_rate_limit',
        'over_sms_send_rate_limit',
      ]) {
        expect(
          AppFailure.from(AuthException('m', code: code)),
          isA<RateLimited>(),
          reason: code,
        );
      }
      expect(
        AppFailure.from(const AuthException('m', statusCode: '429')),
        isA<RateLimited>(),
      );
      for (final code in [
        'session_not_found',
        'session_expired',
        'refresh_token_not_found',
      ]) {
        expect(
          AppFailure.from(AuthException('m', code: code)),
          isA<SessionExpired>(),
          reason: code,
        );
      }
      expect(
        AppFailure.from(const AuthException('m', statusCode: '401')),
        isA<SessionExpired>(),
      );
    });

    test('anything else is a server failure naming the code or status', () {
      expect(
        (AppFailure.from(
          const AuthException('m', code: 'unexpected_failure'),
        ) as ServerFailure).code,
        'auth:unexpected_failure',
      );
      expect(
        (AppFailure.from(
          const AuthException('m', statusCode: '500'),
        ) as ServerFailure).code,
        'auth:500',
      );
      expect(
        (AppFailure.from(const AuthException('m')) as ServerFailure).code,
        'auth:unknown',
      );
    });
  });

  group('edge function errors', () {
    test('maps statuses and envelope codes', () {
      expect(
        AppFailure.from(_function(401, _envelope('reauthentication_required'))),
        isA<ReauthenticationRequired>(),
      );
      expect(
        AppFailure.from(_function(401, _envelope('unauthorized'))),
        isA<SessionExpired>(),
      );
      expect(AppFailure.from(_function(401)), isA<SessionExpired>());
      expect(
        AppFailure.from(_function(403, _envelope('forbidden'))),
        isA<Forbidden>(),
      );
      expect(AppFailure.from(_function(404)), isA<NotFoundFailure>());
      expect(AppFailure.from(_function(409)), isA<ConflictFailure>());
      expect(AppFailure.from(_function(503)), isA<TemporarilyUnavailable>());
      expect(
        (AppFailure.from(_function(502)) as ServerFailure).code,
        'function:502',
      );
    });

    test('a 429 carries the retry_after detail when there is one', () {
      final failure = AppFailure.from(
        _function(429, _envelope('rate_limited', {'retry_after': 12})),
      );
      expect((failure as RateLimited).retryAfter, const Duration(seconds: 12));
      expect(
        (AppFailure.from(_function(429)) as RateLimited).retryAfter,
        isNull,
      );
    });

    test('a 422 or 400 is refused for the reason given, else the code', () {
      expect(
        (AppFailure.from(
          _function(
            422,
            _envelope('validation_failed', {'reason': 'not_an_email'}),
          ),
        ) as RejectedFailure).reason,
        'not_an_email',
      );
      expect(
        (AppFailure.from(
          _function(400, _envelope('invalid_json')),
        ) as RejectedFailure).reason,
        'invalid_json',
      );
      expect(
        (AppFailure.from(
          _function(422, 'plain text'),
        ) as RejectedFailure).reason,
        'rejected',
      );
    });
  });

  test('network exceptions, existing failures and anything else', () {
    expect(AppFailure.from(TimeoutException('slow')), isA<NetworkFailure>());
    expect(
      AppFailure.from(ClientException('Connection reset')),
      isA<NetworkFailure>(),
    );
    const forbidden = Forbidden();
    expect(identical(AppFailure.from(forbidden), forbidden), isTrue);
    final error = StateError('bug');
    expect((AppFailure.from(error) as UnexpectedFailure).error, same(error));
  });
}
