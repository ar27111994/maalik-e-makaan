import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Who is using the app, as far as routing and screens care.
@immutable
sealed class AuthStatus {
  const new();
}

/// Nobody is signed in.
final class SignedOut extends AuthStatus {
  const new();

  @override
  bool operator ==(Object other) => other is SignedOut;

  @override
  int get hashCode => (SignedOut).hashCode;
}

/// A signed-in user.
final class SignedIn extends AuthStatus {
  const new({required this.userId, required this.email});

  final String userId;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is SignedIn && other.userId == userId && other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);
}

/// The user followed a password-reset link and must choose a new password
/// before doing anything else.
final class RecoveringPassword extends AuthStatus {
  const new({required this.userId});

  final String userId;

  @override
  bool operator ==(Object other) =>
      other is RecoveringPassword && other.userId == userId;

  @override
  int get hashCode => Object.hash(RecoveringPassword, userId);
}

/// What signing up led to.
enum SignUpOutcome {
  /// Signed in at once (e-mail confirmation is off).
  signedIn,

  /// A confirmation e-mail was sent; the user signs in after confirming.
  confirmationSent,
}

/// Authentication, in the app's terms. Every method throws [AppFailure].
abstract interface class AuthRepository {
  AuthStatus get status;

  /// Every change of [status], starting with the current one.
  Stream<AuthStatus> watch();

  Future<void> signIn({required String email, required String password});

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String languageCode,
  });

  Future<void> resendConfirmation(String email);

  /// Sends a password-reset link (silently does nothing for unknown e-mails,
  /// so the form never reveals who has an account).
  Future<void> sendPasswordReset(String email);

  Future<void> updatePassword(String newPassword);

  /// Signs out of this device and forgets everything cached for the account.
  Future<void> signOut();
}

/// [AuthRepository] over Supabase Auth.
final class SupabaseAuthRepository implements AuthRepository {
  new({required this._auth, required this._cache, required this._config});

  final sb.GoTrueClient _auth;
  final SwrCache _cache;
  final AppConfig _config;
  bool _recovering = false;

  @override
  AuthStatus get status => _statusOf(_auth.currentSession);

  AuthStatus _statusOf(sb.Session? session) {
    final user = session?.user;
    if (user == null) return const SignedOut();
    if (_recovering) return RecoveringPassword(userId: user.id);
    return SignedIn(userId: user.id, email: user.email);
  }

  @override
  Stream<AuthStatus> watch() => Stream.multi((controller) {
    controller.add(status);
    // asyncMap keeps the events in order while a sign-out clears the cache.
    final subscription = _auth.onAuthStateChange
        .asyncMap(_apply)
        .listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
    controller.onCancel = subscription.cancel;
  });

  Future<AuthStatus> _apply(sb.AuthState change) async {
    final event = change.event;
    if (event == sb.AuthChangeEvent.passwordRecovery) {
      _recovering = true;
    } else if (event == sb.AuthChangeEvent.userUpdated) {
      // A new password ends the recovery.
      _recovering = false;
    } else if (event == sb.AuthChangeEvent.signedOut) {
      _recovering = false;
      // Also when the session ended elsewhere (revoked, expired).
      await _cache.clear();
    }
    return _statusOf(change.session);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String languageCode,
  }) => _guard(() async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _config.authCallbackUrl.toString(),
      data: {'full_name': fullName.trim(), 'locale': languageCode},
    );
    return response.session == null
        ? SignUpOutcome.confirmationSent
        : SignUpOutcome.signedIn;
  });

  @override
  Future<void> resendConfirmation(String email) => _guard(
    () => _auth.resend(
      type: sb.OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _config.authCallbackUrl.toString(),
    ),
  );

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: _config.authCallbackUrl.toString(),
    ),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(sb.UserAttributes(password: newPassword)));

  @override
  Future<void> signOut() => _guard(() async {
    try {
      await _auth.signOut();
    } finally {
      // Even when the server cannot be reached, nothing of the account stays
      // on the device.
      await _cache.clear();
    }
  });
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(
    auth: ref.watch(supabaseClientProvider).auth,
    cache: ref.watch(swrCacheProvider),
    config: ref.watch(appConfigProvider),
  ),
);

/// The current [AuthStatus], kept up to date.
final authStatusProvider = StreamProvider<AuthStatus>(
  (ref) => ref.watch(authRepositoryProvider).watch(),
);
