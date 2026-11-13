import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Who is using the app, as far as routing and screens care.
@immutable
sealed class AuthStatus {
  const new();
}

/// Why the last session on this device ended, when the app ended it.
enum SignOutCause {
  /// The user chose "Sign out".
  userRequest,

  /// The account was deleted.
  accountDeleted,

  /// Deleting the account was asked for, but its answer never came (the
  /// connection broke, or the server failed part-way): it may be gone. The
  /// device forgets it as for a deletion; signing in again tells.
  deletionUnconfirmed,
}

/// Nobody is signed in.
final class SignedOut extends AuthStatus {
  const new({this.cause});

  /// Why the app signed the user out; null when nobody was signed in or the
  /// session ended by itself (it expired or was revoked elsewhere), in
  /// which case the user is returned to where they were after signing in.
  final SignOutCause? cause;

  @override
  bool operator ==(Object other) => other is SignedOut && other.cause == cause;

  @override
  int get hashCode => Object.hash(SignedOut, cause);
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

  /// Signs the current user in again with [password], as sensitive actions
  /// (deleting the account) require a recent sign-in.
  Future<void> reauthenticate(String password);

  /// Completes the sign-in an e-mail link started (confirming the address
  /// or resetting the password): exchanges the link's one-time code for a
  /// session. The link must be opened on the device that asked for it,
  /// which holds the code's verifier (PKCE).
  ///
  /// Throws [RejectedFailure] with `link_expired` (too old or used),
  /// `link_invalid` (not a sign-in link) or `link_other_device` (asked for
  /// on another device or browser).
  Future<void> completeEmailLink(Uri link);

  /// Signs out of this device, and wipes what the device kept for the
  /// account ([DeviceDataWipe]).
  Future<void> signOut({SignOutCause cause = SignOutCause.userRequest});
}

/// [AuthRepository] over Supabase Auth.
final class SupabaseAuthRepository implements AuthRepository {
  /// [nativeLinks]: e-mail links come back through the app's own URL scheme
  /// (iOS), not the web address.
  new({
    required this._auth,
    required this._wipe,
    required AppConfig config,
    bool nativeLinks = false,
  }) : _callbackUrl = config
           .authCallbackUrlFor(nativeScheme: nativeLinks)
           .toString(),
       _userId = _auth.currentSession?.user.id;

  final sb.GoTrueClient _auth;
  final DeviceDataWipe _wipe;
  final String _callbackUrl;
  bool _recovering = false;
  SignOutCause? _signOutCause;

  /// Whether the device was wiped since [signOut] began: gotrue's
  /// announcement of the sign-out did it, and [signOut] need not again.
  bool _wiped = false;

  /// The user whose session the device holds: at first the stored one,
  /// then as the events say.
  String? _userId;

  @override
  AuthStatus get status => _statusOf(_auth.currentSession);

  AuthStatus _statusOf(sb.Session? session) {
    final user = session?.user;
    if (user == null) return SignedOut(cause: _signOutCause);
    if (_recovering) return RecoveringPassword(userId: user.id);
    return SignedIn(userId: user.id, email: user.email);
  }

  @override
  Stream<AuthStatus> watch() => Stream.multi((controller) {
    controller.add(status);
    // asyncMap keeps the events in order while a sign-out wipes the device.
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
    if (event == sb.AuthChangeEvent.signedIn) {
      _signOutCause = null;
    } else if (event == sb.AuthChangeEvent.passwordRecovery) {
      _signOutCause = null;
      _recovering = true;
    } else if (event == sb.AuthChangeEvent.userUpdated) {
      // A new password ends the recovery.
      _recovering = false;
    } else if (event == sb.AuthChangeEvent.signedOut) {
      _recovering = false;
      // Also when the session ended elsewhere (revoked, expired, refused at
      // a refresh, or signed out in another tab).
      await _forgetAccount();
    }
    await _forgetReplaced(change.session);
    return _statusOf(change.session);
  }

  /// Wipes what the device kept for the account whose session [session]
  /// replaced without a sign-out between them: an e-mail link of another
  /// account, opened while signed in, swaps one session for the other and
  /// gotrue announces only the new one. Only an event about the session the
  /// device holds now counts: gotrue replays its latest event to a new
  /// listener, and it may be about an earlier one.
  Future<void> _forgetReplaced(sb.Session? session) async {
    final current = _auth.currentSession?.user.id;
    if (current == null) {
      _userId = null;
      return;
    }
    final user = session?.user.id;
    if (user != current) return;
    final previous = _userId;
    _userId = user;
    if (previous != null && previous != user) {
      await _wipe.wipe(WipeReason.signedOut);
    }
  }

  /// Wipes what the device kept for the account that signed out, before
  /// the signed-out status is shown: the preferences at once, the files
  /// after ([DeviceDataWipe.wipe]).
  ///
  /// Not while a session exists: gotrue replays its latest event to a new
  /// listener, an old sign-out included, and the user signed in since
  /// keeps their data. gotrue drops the session before it announces a
  /// sign-out, so a real one always finds none.
  Future<void> _forgetAccount() async {
    if (_auth.currentSession != null) return;
    _wiped = true;
    await _wipe.wipe(switch (_signOutCause) {
      SignOutCause.accountDeleted ||
      SignOutCause.deletionUnconfirmed => WipeReason.accountDeleted,
      SignOutCause.userRequest || null => WipeReason.signedOut,
    });
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
      emailRedirectTo: _callbackUrl,
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
      emailRedirectTo: _callbackUrl,
    ),
  );

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(email.trim(), redirectTo: _callbackUrl),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(sb.UserAttributes(password: newPassword)));

  @override
  Future<void> reauthenticate(String password) => _guard(() async {
    final email = _auth.currentUser?.email;
    if (email == null) throw const SessionExpired();
    await _auth.signInWithPassword(email: email, password: password);
  });

  @override
  Future<void> completeEmailLink(Uri link) => _guard(() async {
    // Supabase reports a refused link in the query or the fragment.
    final parameters = {
      ...Uri.splitQueryString(link.fragment),
      ...link.queryParameters,
    };
    final error = parameters['error_code'] ?? parameters['error'];
    if (error != null) {
      throw RejectedFailure(
        error == 'otp_expired' ? 'link_expired' : 'link_invalid',
      );
    }
    final code = parameters['code'];
    if (code == null || code.isEmpty) {
      throw const RejectedFailure('link_invalid');
    }
    try {
      await _auth.exchangeCodeForSession(code);
    } on sb.AuthException catch (error) {
      // A plain AuthException (no subclass: not the server's answer, not the
      // network) is raised before any request, when this device holds no
      // verifier for the code: the link was asked for on another device or
      // browser.
      if (error.runtimeType == sb.AuthException) {
        throw const RejectedFailure('link_other_device');
      }
      rethrow;
    }
  });

  @override
  Future<void> signOut({SignOutCause cause = SignOutCause.userRequest}) =>
      _guard(() async {
        _signOutCause = cause;
        _wiped = false;
        try {
          await _auth.signOut();
        } finally {
          // Even when the server cannot be reached, or gotrue failed before
          // it announced the sign-out (whose wipe is otherwise enough), the
          // device is wiped. gotrue's listeners have its announcement one
          // microtask after it is made, before signOut returns to here; only
          // when they are still busy with an earlier event does it come
          // after, and the device is wiped twice, which does no harm.
          if (!_wiped) await _forgetAccount();
        }
      });
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(
    auth: ref.watch(supabaseClientProvider).auth,
    wipe: ref.watch(deviceDataWipeProvider),
    config: ref.watch(appConfigProvider),
    nativeLinks: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
  ),
);
