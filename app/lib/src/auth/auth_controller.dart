import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

/// Who is using the app, kept up to date, with the authentication
/// commands. The router redirects on every change.
final authStatusProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

/// The signed-in user's id, or null (signed out, or choosing a new password
/// after a reset link, when no data is read).
final currentUserIdProvider = Provider<String?>(
  (ref) => switch (ref.watch(authStatusProvider)) {
    SignedIn(:final userId) => userId,
    _ => null,
  },
);

/// The current [AuthStatus] and the commands that change it. Every command
/// throws [AppFailure]; the status follows from the session, so screens
/// never navigate after signing in or out: the router does.
final class AuthController extends Notifier<AuthStatus> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthStatus build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.watch().listen(
      (status) => state = status,
      // Errors on this stream report a background refresh that failed; the
      // session lasts until it really ends, which arrives as a status.
      onError: (Object _) {},
    );
    ref.onDispose(subscription.cancel);
    return repository.status;
  }

  /// The language chosen on this device.
  AppLanguage get _language =>
      ref.read(settingsProvider).locale?.languageCode == AppLanguage.urdu.code
      ? AppLanguage.urdu
      : AppLanguage.english;

  Future<void> signIn({required String email, required String password}) async {
    await _repository.signIn(email: email, password: password);
    await _rememberLanguage();
  }

  /// Creates an account in the language chosen on this device.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) => _repository.signUp(
    email: email,
    password: password,
    fullName: fullName,
    languageCode: _language.code,
  );

  Future<void> resendConfirmation(String email) =>
      _repository.resendConfirmation(email);

  Future<void> sendPasswordReset(String email) =>
      _repository.sendPasswordReset(email);

  Future<void> updatePassword(String newPassword) =>
      _repository.updatePassword(newPassword);

  Future<void> reauthenticate(String password) =>
      _repository.reauthenticate(password);

  Future<void> completeEmailLink(Uri link) async {
    await _repository.completeEmailLink(link);
    await _rememberLanguage();
  }

  /// Signs out of this device. It cannot fail: the device forgets the
  /// session and its cache before the server is told, so when the server
  /// cannot be reached the user is still signed out here, and the session
  /// ends on the server when its refresh token expires.
  Future<void> signOut({SignOutCause cause = SignOutCause.userRequest}) async {
    try {
      await _repository.signOut(cause: cause);
    } on AppFailure {
      return;
    }
  }

  /// Saves the language chosen on this device (before signing in, on the
  /// first-launch screen) to the profile, so e-mails and reminders from the
  /// server use it too.
  ///
  /// It is a courtesy, not part of signing in: when it fails (offline, rate
  /// limited) the user is still signed in, the device keeps its language,
  /// and the next sign-in or language change saves it again.
  Future<void> _rememberLanguage() async {
    final status = _repository.status;
    if (status is! SignedIn) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateLanguage(status.userId, _language);
    } on AppFailure {
      return;
    }
  }
}

/// What an e-mail the app just asked Supabase to send is for.
enum EmailPurpose {
  /// Confirming the address of a new account.
  confirmation,

  /// Resetting a forgotten password.
  passwordReset,
}

/// An e-mail on its way: the address and why it was sent, for the "Check
/// your e-mail" screen. Kept in memory only, never in the address bar.
@immutable
final class PendingEmail {
  const new({required this.address, required this.purpose});

  final String address;
  final EmailPurpose purpose;

  @override
  bool operator ==(Object other) =>
      other is PendingEmail &&
      other.address == address &&
      other.purpose == purpose;

  @override
  int get hashCode => Object.hash(address, purpose);
}

/// The e-mail the app last sent, if any.
final pendingEmailProvider =
    NotifierProvider<PendingEmailController, PendingEmail?>(
      PendingEmailController.new,
    );

/// Holds the [PendingEmail].
final class PendingEmailController extends Notifier<PendingEmail?> {
  @override
  PendingEmail? build() => null;

  /// The e-mail last sent, if any.
  PendingEmail? get email => state;

  /// Records that [value] was sent.
  set email(PendingEmail? value) => state = value;
}
