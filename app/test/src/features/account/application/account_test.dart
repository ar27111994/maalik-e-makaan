import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/application/account_deletion.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

void main() {
  group('profile', () {
    test('loads through the cache', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      final snapshot = container.read(profileProvider(testUserId)).value!;
      expect(snapshot.value, ayesha);
      expect(snapshot.source, SnapshotSource.network);
      expect(app.profiles.calls.single.$2, [testUserId]);
    });

    test('saving details shows what the server stored', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      await container
          .read(profileProvider(testUserId).notifier)
          .saveDetails(fullName: '  Ayesha  K. ', phone: null);
      final profile = container.read(profileProvider(testUserId)).value!.value;
      expect(profile.fullName, 'Ayesha K.');
      expect(profile.phone, isNull);
      expect(app.profiles.calls.last.$2, [testUserId, '  Ayesha  K. ', null]);
      // The cache holds it for next time.
      final saved = await app.cache.read(
        testUserId,
        ProfileController.query,
        Profile.fromRow,
      );
      expect(saved!.value, profile);
    });

    test('saving the language updates the shown profile', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      await container
          .read(profileProvider(testUserId).notifier)
          .saveLanguage(AppLanguage.urdu);
      expect(
        container.read(profileProvider(testUserId)).value!.value.language,
        AppLanguage.urdu,
      );
    });

    test('a profile that comes back after the device was wiped is not '
        'kept, nor one saved after it', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      final notifier = container.read(profileProvider(testUserId).notifier);
      app.profiles.gate.close();
      final saving = notifier.saveDetails(fullName: 'Ayesha K.', phone: null);
      await pumpEventQueue();
      // The session ends while the save is on its way.
      await app.cache.clear();
      app.profiles.gate.open();
      await saving;
      expect(app.store.values, isEmpty);
      expect(
        container.read(profileProvider(testUserId)).value!.value.fullName,
        'Ayesha K.',
      );
      // Nor what the profile, built for that session, saves after.
      await notifier.saveLanguage(AppLanguage.urdu);
      expect(app.store.values, isEmpty);
    });

    test('a profile asked for before a portfolio left the list is not '
        'kept, nor one made from it, and one asked for after it is', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      final notifier = container.read(profileProvider(testUserId).notifier);
      app.profiles.gate.close();
      final saving = notifier.saveDetails(fullName: 'Ayesha K.', phone: null);
      await pumpEventQueue();
      await app.cache.forgetUser(testUserId, keep: PortfoliosController.query);
      app.profiles.gate.open();
      await saving;
      expect(app.store.values, isEmpty);
      // Made from the profile on show, asked for before the removal.
      await notifier.saveLanguage(AppLanguage.urdu);
      expect(app.store.values, isEmpty);
      expect(
        container.read(profileProvider(testUserId)).value!.value.language,
        AppLanguage.urdu,
      );
      // The server's answer to a request made after it.
      await notifier.saveDetails(fullName: 'Ayesha Khan', phone: null);
      final saved = await app.cache.read(
        testUserId,
        ProfileController.query,
        Profile.fromRow,
      );
      expect(saved!.value.fullName, 'Ayesha Khan');
      // And a language saved now, made from that one, is kept with it.
      await notifier.saveLanguage(AppLanguage.english);
      final again = await app.cache.read(
        testUserId,
        ProfileController.query,
        Profile.fromRow,
      );
      expect(again!.value.language, AppLanguage.english);
    });

    test('a language saved after a portfolio left the list does not save '
        'the profile shown before it again', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      expect(app.store.values, hasLength(1));
      // A portfolio leaves: the saved profile goes, the shown one stays.
      await app.cache.forgetUser(testUserId, keep: PortfoliosController.query);
      expect(app.store.values, isEmpty);
      await container
          .read(profileProvider(testUserId).notifier)
          .saveLanguage(AppLanguage.urdu);
      expect(app.store.values, isEmpty);
      expect(
        container.read(profileProvider(testUserId)).value!.value.language,
        AppLanguage.urdu,
      );
      // Read again, it is saved as the server has it.
      container.invalidate(profileProvider(testUserId));
      await pumpEventQueue();
      expect(app.store.values, hasLength(1));
    });

    for (final (what, remove) in <(String, Future<void> Function(SwrCache))>[
      ('the device was wiped', (cache) => cache.clear()),
      (
        'a portfolio left the list',
        (cache) =>
            cache.forgetUser(testUserId, keep: PortfoliosController.query),
      ),
    ]) {
      test('a language whose save was on its way when $what is shown and '
          'not kept', () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, profileProvider(testUserId));
        await pumpEventQueue();
        app.profiles.gate.close();
        final saving = container
            .read(profileProvider(testUserId).notifier)
            .saveLanguage(AppLanguage.urdu);
        await pumpEventQueue();
        // Removed, all of it, while the request is on its way.
        await remove(app.cache);
        app.profiles.gate.open();
        await saving;
        expect(app.store.values, isEmpty);
        expect(
          container.read(profileProvider(testUserId)).value!.value.language,
          AppLanguage.urdu,
        );
      });
    }

    test(
      'saving the language before the profile loaded saves it only',
      () async {
        final app = TestApp()..profiles.gate.close();
        final container = containerFor(app);
        listen(container, profileProvider(testUserId));
        final saving = container
            .read(profileProvider(testUserId).notifier)
            .saveLanguage(AppLanguage.urdu);
        app.profiles.gate.open();
        await saving;
        expect(app.profiles.calls.map((c) => c.$1), contains('updateLanguage'));
      },
    );

    test('a refused save throws and keeps the profile', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      app.profiles.gate.failure = const RejectedFailure('constraint_violation');
      await expectLater(
        container
            .read(profileProvider(testUserId).notifier)
            .saveDetails(
              fullName: 'x',
              phone: PhoneNumber.fromE164('+923001234567'),
            ),
        throwsA(isA<RejectedFailure>()),
      );
      expect(container.read(profileProvider(testUserId)).value!.value, ayesha);
    });
  });

  group('account deletion', () {
    test('previews what goes', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      await pumpEventQueue();
      expect(
        container.read(accountDeletionProvider).value,
        app.account.preview,
      );
    });

    test('signs in again, deletes, then signs out for good', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      await container
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
      expect(app.auth.calls.first.$1, 'reauthenticate');
      expect(app.auth.calls.first.$2, ['Secret1234']);
      expect(app.account.calls.last.$2, [testEmail]);
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
      await pumpEventQueue();
      expect(
        container.read(authStatusProvider),
        const SignedOut(cause: SignOutCause.accountDeleted),
      );
    });

    test('a refused deletion signs nobody out and wipes nothing', () async {
      final app = TestApp();
      app.account.gate.failure = const RejectedFailure(
        'does_not_match_account',
      );
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      await pumpEventQueue();
      await expectLater(
        container
            .read(accountDeletionProvider.notifier)
            .deleteAccount(password: 'Secret1234', confirmEmail: 'x@y.pk'),
        throwsA(isA<RejectedFailure>()),
      );
      expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
    });

    for (final failure in [
      const NetworkFailure(),
      const ServerFailure('function:502'),
      UnexpectedFailure(StateError('lost')),
    ]) {
      test('an answer lost on the way (${failure.runtimeType}) signs out as '
          'a deletion that may have happened', () async {
        final app = TestApp();
        app.account.gate.failure = failure;
        final container = containerFor(app);
        listen(container, accountDeletionProvider);
        listen(container, authStatusProvider);
        await pumpEventQueue();
        await container
            .read(accountDeletionProvider.notifier)
            .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
        expect(app.auth.calls.last.$2, [SignOutCause.deletionUnconfirmed]);
        await pumpEventQueue();
        expect(
          container.read(authStatusProvider),
          const SignedOut(cause: SignOutCause.deletionUnconfirmed),
        );
      });
    }

    test('only an outcome that may have deleted counts as one', () {
      for (final failure in <AppFailure>[
        const RejectedFailure('does_not_match_account'),
        const ReauthenticationRequired(),
        const SessionExpired(),
        const Forbidden(),
        const RateLimited(null),
        const TemporarilyUnavailable(),
        const NotFoundFailure(),
        const ConflictFailure(),
      ]) {
        expect(mayHaveDeleted(failure), isFalse, reason: '$failure');
      }
    });

    test('a wrong password deletes nothing', () async {
      final app = TestApp();
      app.auth.gate.failure = const RejectedFailure('invalid_credentials');
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      await pumpEventQueue();
      await expectLater(
        container
            .read(accountDeletionProvider.notifier)
            .deleteAccount(password: 'x', confirmEmail: testEmail),
        throwsA(isA<RejectedFailure>()),
      );
      expect(app.account.calls.map((c) => c.$1), ['deletionPreview']);
    });
  });
}
