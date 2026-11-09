import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

import '../../support/container.dart';
import '../../support/harness.dart';

void main() {
  test('follows the repository, synchronously from the start', () async {
    final app = TestApp(auth: const SignedOut());
    final container = containerFor(app);
    listen(container, authStatusProvider);
    expect(container.read(authStatusProvider), const SignedOut());
    expect(container.read(currentUserIdProvider), isNull);
    app.auth.emit(signedIn);
    await pumpEventQueue();
    expect(container.read(authStatusProvider), signedIn);
    expect(container.read(currentUserIdProvider), testUserId);
    app.auth.emit(const RecoveringPassword(userId: testUserId));
    await pumpEventQueue();
    // Nothing is read while a new password is being chosen.
    expect(container.read(currentUserIdProvider), isNull);
  });

  test('signing in saves the device language to the profile', () async {
    final app = TestApp(auth: const SignedOut(), language: 'ur');
    final container = containerFor(app);
    await container
        .read(authStatusProvider.notifier)
        .signIn(email: testEmail, password: 'Secret1234');
    expect(app.auth.calls.single.$1, 'signIn');
    expect(app.profiles.calls.single.$1, 'updateLanguage');
    expect(app.profiles.calls.single.$2, [testUserId, AppLanguage.urdu]);
  });

  test(
    'saving the language is a courtesy: its failure is not a sign-in failure',
    () async {
      final app = TestApp(auth: const SignedOut());
      app.profiles.gate.failure = const NetworkFailure();
      final container = containerFor(app);
      await container
          .read(authStatusProvider.notifier)
          .signIn(email: testEmail, password: 'Secret1234');
      expect(app.auth.status, isA<SignedIn>());
    },
  );

  test('a failed sign-in saves nothing', () async {
    final app = TestApp(auth: const SignedOut());
    app.auth.gate.failure = const RejectedFailure('invalid_credentials');
    final container = containerFor(app);
    await expectLater(
      container
          .read(authStatusProvider.notifier)
          .signIn(email: testEmail, password: 'x'),
      throwsA(isA<RejectedFailure>()),
    );
    expect(app.profiles.calls, isEmpty);
  });

  test('an e-mail link that signs in saves the language too', () async {
    final app = TestApp(auth: const SignedOut());
    final container = containerFor(app);
    final link = Uri.parse('/auth/callback?code=abc');
    await container.read(authStatusProvider.notifier).completeEmailLink(link);
    expect(app.auth.calls.single.$2, [link]);
    expect(app.profiles.calls.single.$2, [testUserId, AppLanguage.english]);
  });

  test('signing up asks in the device language', () async {
    final app = TestApp(auth: const SignedOut(), language: 'ur');
    final container = containerFor(app);
    final outcome = await container
        .read(authStatusProvider.notifier)
        .signUp(email: testEmail, password: 'Secret1234', fullName: 'Ayesha');
    expect(outcome, SignUpOutcome.confirmationSent);
    expect(app.auth.calls.single.$2, [testEmail, 'Secret1234', 'Ayesha', 'ur']);
  });

  test('the other commands go to the repository', () async {
    final app = TestApp();
    final container = containerFor(app);
    final auth = container.read(authStatusProvider.notifier);
    await auth.resendConfirmation(testEmail);
    await auth.sendPasswordReset(testEmail);
    await auth.updatePassword('NewSecret12');
    await auth.reauthenticate('Secret1234');
    expect(app.auth.calls.map((call) => call.$1), [
      'resendConfirmation',
      'sendPasswordReset',
      'updatePassword',
      'reauthenticate',
    ]);
  });

  test('signing out cannot fail on this device', () async {
    final app = TestApp();
    app.auth.gate.failure = const NetworkFailure();
    final container = containerFor(app);
    listen(container, authStatusProvider);
    await container
        .read(authStatusProvider.notifier)
        .signOut(cause: SignOutCause.accountDeleted);
    await pumpEventQueue();
    expect(
      container.read(authStatusProvider),
      const SignedOut(cause: SignOutCause.accountDeleted),
    );
  });

  test('errors on the session stream do not change the status', () async {
    final app = TestApp();
    final container = ProviderContainer.test(
      overrides: [
        settingsStoreProvider.overrideWithValue(app.settings),
        authRepositoryProvider.overrideWithValue(_FailingStream(app.auth)),
      ],
    );
    listen(container, authStatusProvider);
    await pumpEventQueue();
    expect(container.read(authStatusProvider), signedIn);
  });

  test('the pending e-mail is remembered in memory', () {
    final container = containerFor(TestApp());
    final pending = container.read(pendingEmailProvider.notifier);
    expect(pending.email, isNull);
    const email = PendingEmail(
      address: testEmail,
      purpose: EmailPurpose.passwordReset,
    );
    pending.email = email;
    expect(container.read(pendingEmailProvider), email);
    expect(
      email,
      isNot(
        const PendingEmail(
          address: testEmail,
          purpose: EmailPurpose.confirmation,
        ),
      ),
    );
    expect(
      email.hashCode,
      const PendingEmail(
        address: testEmail,
        purpose: EmailPurpose.passwordReset,
      ).hashCode,
    );
  });
}

/// A repository whose session stream reports a failed refresh.
final class _FailingStream implements AuthRepository {
  new(this._inner);

  final FakeAuthRepository _inner;

  @override
  AuthStatus get status => _inner.status;

  @override
  Stream<AuthStatus> watch() =>
      Stream.error(const NetworkFailure(), StackTrace.empty);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
