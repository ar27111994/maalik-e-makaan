import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an operation failed, in the terms the UI acts on.
///
/// Every error a repository can meet (PostgREST, Auth, Edge Functions, the
/// network) is mapped to one of these by [AppFailure.from], so screens never
/// inspect library exceptions or error strings.
sealed class AppFailure implements Exception {
  const new();

  /// Maps [error] to a failure. Anything unrecognised is an [UnexpectedFailure]
  /// carrying the original error for logging.
  factory from(Object error) => switch (error) {
    AppFailure() => error,
    PostgrestException() => _fromPostgrest(error),
    AuthException() => _fromAuth(error),
    // The request never reached the function (no connection, DNS, TLS).
    FunctionsFetchException() => const NetworkFailure(),
    FunctionException() => _fromFunction(error),
    // package:http wraps socket errors in ClientException on every platform.
    TimeoutException() || ClientException() => const NetworkFailure(),
    // A model refused the server's answer (a missing or mistyped field):
    // the server and this app version disagree.
    FormatException() => const ServerFailure('unexpected_response'),
    _ => UnexpectedFailure(error),
  };

  static AppFailure _fromPostgrest(PostgrestException error) {
    final code = error.code ?? '';
    return switch (code) {
      'rate_limited' => RateLimited(_seconds(error.hint)),
      'PGRST301' || 'PGRST302' || 'PGRST303' => const SessionExpired(),
      '42501' => const Forbidden(),
      '22023' => RejectedFailure(error.message),
      '23505' => const ConflictFailure(),
      '23503' ||
      '23514' ||
      '22P02' => const RejectedFailure('constraint_violation'),
      'PGRST116' => const NotFoundFailure(),
      '40P01' ||
      '40001' ||
      '55P03' ||
      '57014' => const TemporarilyUnavailable(),
      // postgrest-dart reports a failed fetch with an empty code.
      '' when _looksLikeNetwork(error.message) => const NetworkFailure(),
      _ => ServerFailure(code.isEmpty ? 'database' : code),
    };
  }

  static AppFailure _fromAuth(AuthException error) {
    if (error is AuthRetryableFetchException) return const NetworkFailure();
    if (error is AuthSessionMissingException) return const SessionExpired();
    // An e-mail link without a code, or with one the client cannot use.
    if (error is AuthPKCEGrantCodeExchangeError) {
      return const RejectedFailure('link_invalid');
    }
    return switch (error.code) {
      'invalid_credentials' => const RejectedFailure('invalid_credentials'),
      'email_not_confirmed' => const RejectedFailure('email_not_confirmed'),
      'user_already_exists' ||
      'email_exists' => const RejectedFailure('email_taken'),
      'weak_password' => const RejectedFailure('weak_password'),
      'same_password' => const RejectedFailure('same_password'),
      'email_address_invalid' => const RejectedFailure('invalid_email'),
      'signup_disabled' => const RejectedFailure('signup_disabled'),
      // An e-mail link that was used already or is too old.
      'otp_expired' ||
      'flow_state_expired' => const RejectedFailure('link_expired'),
      'flow_state_not_found' ||
      'bad_code_verifier' => const RejectedFailure('link_invalid'),
      // Changing the password needs a recent sign-in.
      'reauthentication_needed' ||
      'reauthentication_not_valid' => const ReauthenticationRequired(),
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' ||
      'over_sms_send_rate_limit' => const RateLimited(null),
      'session_not_found' ||
      'session_expired' ||
      'refresh_token_not_found' => const SessionExpired(),
      _ when error.statusCode == '429' => const RateLimited(null),
      _ when error.statusCode == '401' => const SessionExpired(),
      _ => ServerFailure('auth:${error.code ?? error.statusCode ?? 'unknown'}'),
    };
  }

  /// Edge Functions answer `{"error": {"code", "message", "details"}}`.
  static AppFailure _fromFunction(FunctionException error) {
    final envelope = error.details is Map
        ? (error.details as Map)['error']
        : null;
    final code = envelope is Map ? envelope['code'] : null;
    final details = envelope is Map ? envelope['details'] : null;
    final reason = details is Map ? details['reason'] : null;
    return switch ((error.status, code)) {
      (429, _) => RateLimited(
        _seconds(details is Map ? '${details['retry_after'] ?? ''}' : null),
      ),
      (401, 'reauthentication_required') => const ReauthenticationRequired(),
      (401, _) => const SessionExpired(),
      (403, 'mfa_required') => const RejectedFailure('mfa_required'),
      (403, _) => const Forbidden(),
      (404, _) => const NotFoundFailure(),
      (409, _) => const ConflictFailure(),
      (422 || 400, _) => RejectedFailure(
        reason is String ? reason : (code is String ? code : 'rejected'),
      ),
      (503, _) => const TemporarilyUnavailable(),
      _ => ServerFailure('function:${error.status}'),
    };
  }

  static Duration? _seconds(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds == null || seconds < 1 ? null : Duration(seconds: seconds);
  }

  static bool _looksLikeNetwork(String message) => RegExp(
    'fetch|socket|connection|network|timed? ?out',
    caseSensitive: false,
  ).hasMatch(message);
}

/// No connection, or the request did not complete. Retrying later may work.
final class NetworkFailure extends AppFailure {
  const new();
}

/// The session ended (expired, revoked or signed out elsewhere): sign in again.
final class SessionExpired extends AppFailure {
  const new();
}

/// A sensitive action needs a recent sign-in.
final class ReauthenticationRequired extends AppFailure {
  const new();
}

/// The signed-in user may not do this.
final class Forbidden extends AppFailure {
  const new();
}

/// The thing asked for does not exist (or is not visible to the user).
final class NotFoundFailure extends AppFailure {
  const new();
}

/// It already exists (a duplicate).
final class ConflictFailure extends AppFailure {
  const new();
}

/// The server refused the request for a stated reason, a stable key such as
/// `last_owner` or `confirmation_mismatch` that the UI turns into words.
final class RejectedFailure extends AppFailure {
  const new(this.reason);

  final String reason;
}

/// Too many requests; [retryAfter] says how long to wait when the server said.
final class RateLimited extends AppFailure {
  const new(this.retryAfter);

  final Duration? retryAfter;
}

/// The service is busy for a moment (a deadlock or timeout was retried away).
final class TemporarilyUnavailable extends AppFailure {
  const new();
}

/// The server failed; [code] identifies where, for support and logs.
final class ServerFailure extends AppFailure {
  const new(this.code);

  final String code;
}

/// A programming error or an unknown exception.
final class UnexpectedFailure extends AppFailure {
  const new(this.error);

  final Object error;
}
