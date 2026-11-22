import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/application/account_deletion.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

const _otherAccount = SignedIn(
  userId: 'another-user',
  email: 'other@example.com',
);

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
      final saved = await app.cache.saved(
        testUserId,
        ProfileController.query,
        ProfileController.scope,
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

    for (final from in ['the server', 'saving the details']) {
      test('a language saved in a session after an earlier one ended saves '
          'the profile on show, from $from', () async {
        final app = TestApp();
        await app.cache.clear();
        // The first read never answers when the details show the profile.
        if (from == 'saving the details') app.profiles.gate.close();
        final container = containerFor(app);
        listen(container, profileProvider(testUserId));
        await pumpEventQueue();
        final notifier = container.read(profileProvider(testUserId).notifier);
        if (from == 'saving the details') {
          app.profiles.gate.holdLaterCallsApart();
          final saving = notifier.saveDetails(
            fullName: 'Ayesha Khan',
            phone: null,
          );
          app.profiles.gate.open();
          await saving;
        }
        await notifier.saveLanguage(AppLanguage.urdu);
        final saved = await app.cache.saved(
          testUserId,
          ProfileController.query,
          ProfileController.scope,
          Profile.fromRow,
        );
        expect(saved!.value.language, AppLanguage.urdu);
      });
    }

    test('a profile that comes back after the device was wiped is neither '
        'kept nor shown, and the profile built for that session asks for '
        'nothing after', () async {
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
        container.read(profileProvider(testUserId)).value?.value.fullName,
        isNot('Ayesha K.'),
      );
      // The profile, built for that session, asks for nothing after.
      final asked = app.profiles.calls.length;
      await expectLater(
        notifier.saveLanguage(AppLanguage.urdu),
        throwsA(isA<SessionExpired>()),
      );
      expect(app.profiles.calls, hasLength(asked));
      expect(app.store.values, isEmpty);
    });

    test('a portfolio leaving the list keeps the profile: one asked for '
        'before is kept, and so is a language saved after', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      final notifier = container.read(profileProvider(testUserId).notifier);
      app.profiles.gate.close();
      final saving = notifier.saveDetails(fullName: 'Ayesha K.', phone: null);
      await pumpEventQueue();
      await app.cache.seed(testUserId, 'tenants.${gulberg.id}', [
        1,
      ], portfolio: gulberg.id);
      // Gulberg leaves the user's list.
      await app.cache.answer(testUserId, [plaza.id]);
      expect(app.store.values.keys, [
        cacheKey(testUserId, ProfileController.query),
      ]);
      app.profiles.gate.open();
      await saving;
      final saved = await app.cache.saved(
        testUserId,
        ProfileController.query,
        ProfileController.scope,
        Profile.fromRow,
      );
      expect(saved!.value.fullName, 'Ayesha K.');
      // Made from the profile on show, asked for before the removal.
      await notifier.saveLanguage(AppLanguage.urdu);
      final again = await app.cache.saved(
        testUserId,
        ProfileController.query,
        ProfileController.scope,
        Profile.fromRow,
      );
      expect(again!.value.language, AppLanguage.urdu);
    });

    test('a language whose save was on its way when the device was wiped is '
        'neither shown nor kept', () async {
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
      await app.cache.clear();
      app.profiles.gate.open();
      await saving;
      expect(app.store.values, isEmpty);
      expect(
        container.read(profileProvider(testUserId)).value?.value.language,
        isNot(AppLanguage.urdu),
      );
    });

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

  group('the session it serves: profile', () {
    const other = SignedIn(
      userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
      email: 'sana.malik@example.com',
    );

    test(
      'built first, it loads: the session is read before its epoch',
      () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, profileProvider(testUserId));
        await pumpEventQueue();
        expect(container.read(profileProvider(testUserId)).value, isNotNull);
      },
    );

    test('built for another account than the one signed in, it asks for '
        'nothing', () async {
      final app = TestApp();
      final container = containerFor(app);
      await pumpEventQueue();
      await app.cache.clear();
      app.auth.emit(other);
      await pumpEventQueue();
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      expect(app.profiles.calls, isEmpty);
      expect(
        container.read(profileProvider(testUserId)).error,
        isA<SessionExpired>(),
      );
      expect(app.store.values, isEmpty);
    });

    for (final (name, command)
        in <(String, Future<void> Function(ProfileController))>[
          (
            'saving the language',
            (profile) => profile.saveLanguage(AppLanguage.urdu),
          ),
          (
            'saving the details',
            (profile) =>
                profile.saveDetails(fullName: 'Ayesha K.', phone: null),
          ),
        ]) {
      test('$name for another account than the one signed in sends '
          'nothing', () async {
        final app = TestApp();
        final container = containerFor(app);
        await pumpEventQueue();
        await app.cache.clear();
        app.auth.emit(other);
        await pumpEventQueue();
        // As a screen built for the first account calls it after an await.
        await expectLater(
          command(container.read(profileProvider(testUserId).notifier)),
          throwsA(isA<SessionExpired>()),
        );
        expect(app.profiles.calls, isEmpty);
        expect(app.store.values, isEmpty);
      });

      test('$name once the device is wiped, before the next status, sends '
          'nothing', () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, profileProvider(testUserId));
        await pumpEventQueue();
        final asked = app.profiles.calls.length;
        // The wipe has begun; the status after it has not come yet.
        await app.cache.clear();
        await expectLater(
          command(container.read(profileProvider(testUserId).notifier)),
          throwsA(isA<SessionExpired>()),
        );
        expect(app.profiles.calls, hasLength(asked));
        expect(app.store.values, isEmpty);
      });
    }

    test("a language saved in the same account's next session, before its "
        'profile comes, does not save the profile shown in the session that '
        'ended', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      // The device is wiped, and the same account signs in again offline:
      // the earlier profile stays on show, and no new one comes.
      app.profiles.fetchFailure = const NetworkFailure();
      await app.cache.clear();
      app.auth.emit(signedIn);
      await pumpEventQueue();
      expect(container.read(profileProvider(testUserId)).value, isNotNull);
      await container
          .read(profileProvider(testUserId).notifier)
          .saveLanguage(AppLanguage.urdu);
      expect(
        [for (final (name, _) in app.profiles.calls) name],
        ['fetch', 'fetch', 'updateLanguage'],
      );
      expect(app.store.values, isEmpty);
    });

    test('kept alive across a sign-out by the same account, it saves in the '
        'next session', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, profileProvider(testUserId));
      await pumpEventQueue();
      app.profiles.gate.close();
      final saving = container
          .read(profileProvider(testUserId).notifier)
          .saveLanguage(AppLanguage.urdu);
      await pumpEventQueue();
      await app.cache.clear();
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      app.auth.emit(signedIn);
      await pumpEventQueue();
      app.profiles.gate.open();
      await saving;
      await pumpEventQueue();
      // Built again for the new session: it read the profile and saved it.
      expect(
        [for (final (name, _) in app.profiles.calls) name],
        ['fetch', 'updateLanguage', 'fetch'],
      );
      expect(app.store.values.keys, [cacheKey(testUserId, 'profile')]);
      expect(container.read(profileProvider(testUserId)).value, isNotNull);
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

    // Another tab of the same browser signs in as someone else while the
    // deletion is on its way: the device now holds that account's session,
    // and the deletion's answer must not sign it out or wipe it.
    for (final failure in <AppFailure?>[null, const NetworkFailure()]) {
      test('a deletion answered (${failure?.runtimeType ?? 'deleted'}) after '
          'another account signed in signs nobody out', () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, accountDeletionProvider);
        listen(container, authStatusProvider);
        await pumpEventQueue();
        app.account.gate
          ..failure = failure
          ..close();
        final deleting = container
            .read(accountDeletionProvider.notifier)
            .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
        await pumpEventQueue();
        expect(app.account.calls.last.$1, 'deleteAccount');
        expect(app.account.calls.last.$2, [testEmail]);
        await app.cache.clear();
        app.auth.emit(_otherAccount);
        await pumpEventQueue();
        app.account.gate.open();
        await expectLater(deleting, throwsA(isA<SessionExpired>()));
        expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
        expect(container.read(authStatusProvider), _otherAccount);
      });

      // gotrue changes the session it holds before its listeners hear of
      // it, and the repository announces the change only after its wipe:
      // until then the status and the cache may still name the deleting
      // account, and signing out would sign the other one out.
      for (final holder in <AuthStatus>[
        _otherAccount,
        RecoveringPassword(userId: _otherAccount.userId),
      ]) {
        test('a deletion answered (${failure?.runtimeType ?? 'deleted'}) '
            'while the device holds another account '
            '(${holder.runtimeType}), not yet announced, signs nobody '
            'out', () async {
          final app = TestApp();
          final container = containerFor(app);
          listen(container, accountDeletionProvider);
          listen(container, authStatusProvider);
          await pumpEventQueue();
          app.account.gate
            ..failure = failure
            ..close();
          final deleting = container
              .read(accountDeletionProvider.notifier)
              .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
          await pumpEventQueue();
          expect(app.account.calls.last.$1, 'deleteAccount');
          app.auth.status = holder; // Not announced.
          expect(container.read(authStatusProvider), signedIn);
          app.account.gate.open();
          await expectLater(deleting, throwsA(isA<SessionExpired>()));
          expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
          expect(app.auth.status, holder);
        });
      }
    }

    // The deleting session ends elsewhere (signed out in another tab) while
    // the deletion is on its way: its own wipe was a plain sign-out's, so
    // the deletion's answer still signs the device out as a deletion,
    // which removes the invitation and says the account is gone. The same
    // account signed in again is signed out too: it was just deleted.
    for (final failure in <AppFailure?>[null, const NetworkFailure()]) {
      final cause = failure == null
          ? SignOutCause.accountDeleted
          : SignOutCause.deletionUnconfirmed;
      for (final (name, since) in <(String, AuthStatus?)>[
        ('with nobody signed in since', null),
        ('with the same account signed in again', signedIn),
        (
          'with the same account recovering its password',
          const RecoveringPassword(userId: testUserId),
        ),
      ]) {
        test('a deletion answered (${failure?.runtimeType ?? 'deleted'}) '
            'after its session signed out elsewhere, $name, signs out as '
            '$cause', () async {
          final app = TestApp();
          final container = containerFor(app);
          listen(container, accountDeletionProvider);
          listen(container, authStatusProvider);
          await pumpEventQueue();
          app.account.gate
            ..failure = failure
            ..close();
          final deleting = container
              .read(accountDeletionProvider.notifier)
              .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
          await pumpEventQueue();
          expect(app.account.calls.last.$1, 'deleteAccount');
          await app.cache.clear();
          app.auth.emit(const SignedOut());
          await pumpEventQueue();
          if (since != null) {
            app.auth.emit(since);
            await pumpEventQueue();
            expect(container.read(authStatusProvider), since);
          }
          app.account.gate.open();
          await deleting;
          expect(app.auth.calls.map((c) => c.$1), [
            'reauthenticate',
            'signOut',
          ]);
          expect(app.auth.calls.last.$2, [cause]);
          await pumpEventQueue();
          expect(container.read(authStatusProvider), SignedOut(cause: cause));
        });
      }
    }

    test('a session that ends while it signs in again asks for no '
        'deletion', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      app.auth.gate.close();
      final deleting = container
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
      await pumpEventQueue();
      await app.cache.clear();
      app.auth.emit(_otherAccount);
      await pumpEventQueue();
      app.auth.gate.open();
      await expectLater(deleting, throwsA(isA<SessionExpired>()));
      expect(
        app.account.calls.map((c) => c.$1),
        isNot(contains('deleteAccount')),
      );
      expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
      expect(container.read(authStatusProvider), _otherAccount);
    });

    test('with nobody signed in it asks for nothing', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      await app.cache.clear();
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      await expectLater(
        container
            .read(accountDeletionProvider.notifier)
            .deleteAccount(password: 'Secret1234', confirmEmail: testEmail),
        throwsA(isA<SessionExpired>()),
      );
      expect(app.auth.calls, isEmpty);
      expect(
        app.account.calls.map((c) => c.$1),
        isNot(contains('deleteAccount')),
      );
    });

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
