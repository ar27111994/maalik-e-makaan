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

    // The delete screen is the provider's only listener in the app, and the
    // provider is autoDispose: leaving the screen disposes it. Once the
    // request is on its way, only the router at a sign-out leaves the
    // screen, before the answer comes. The command goes on without
    // its screen: what it asks the device and the server, it read before
    // its first wait.
    for (final failure in <AppFailure?>[null, const NetworkFailure()]) {
      final cause = failure == null
          ? SignOutCause.accountDeleted
          : SignOutCause.deletionUnconfirmed;
      test('a deletion (${failure?.runtimeType ?? 'deleted'}) whose screen '
          'is gone while the deletion is on its way deletes and signs out as '
          '$cause', () async {
        final app = TestApp();
        final container = containerFor(app);
        final screen = listen(container, accountDeletionProvider);
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
        screen.close();
        await pumpEventQueue();
        expect(container.read(accountDeletionProvider.exists), isFalse);
        app.account.gate.open();
        await deleting;
        expect(app.auth.calls.map((c) => c.$1), ['reauthenticate', 'signOut']);
        expect(app.auth.calls.last.$2, [cause]);
        await pumpEventQueue();
        expect(container.read(authStatusProvider), SignedOut(cause: cause));
      });
    }

    // Back while the password is checked cancels: the router asks
    // `leave` as the screen goes, whichever way it goes, and the command
    // then sends nothing once the check answers, whether or not the screen
    // is gone by then (it leaves through a transition, and Riverpod disposes
    // the provider a frame after that).
    for (final gone in [false, true]) {
      test('left while it signs in again (Back), it sends no deletion and '
          'signs nobody out${gone ? ', its screen gone' : ''}', () async {
        final app = TestApp();
        final container = containerFor(app);
        final screen = listen(container, accountDeletionProvider);
        listen(container, authStatusProvider);
        await pumpEventQueue();
        app.auth.gate.close();
        final deletion = container.read(accountDeletionProvider.notifier);
        var returned = false;
        final deleting = deletion
            .deleteAccount(password: 'Secret1234', confirmEmail: testEmail)
            .whenComplete(() => returned = true);
        await pumpEventQueue();
        expect(deletion.sending.value, isFalse);
        expect(returned, isFalse);
        expect(deletion.leave(), isTrue);
        // It returns at once, before the check answers, so a screen still
        // shown (left for another section, which keeps it) is not busy.
        await pumpEventQueue();
        expect(returned, isTrue);
        if (gone) {
          screen.close();
          await pumpEventQueue();
          expect(container.read(accountDeletionProvider.exists), isFalse);
        }
        app.auth.gate.open();
        expect(await deleting, isFalse);
        await pumpEventQueue();
        expect(
          app.account.calls.map((c) => c.$1),
          isNot(contains('deleteAccount')),
        );
        expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
        expect(container.read(authStatusProvider), signedIn);
        expect(deletion.sending.value, isFalse);
      });
    }

    test('a deletion started again after one left while signing in sends '
        'once, the later one', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      final deletion = container.read(accountDeletionProvider.notifier);
      app.auth.gate.close();
      final earlier = deletion.deleteAccount(
        password: 'Secret1234',
        confirmEmail: 'earlier@example.com',
      );
      await pumpEventQueue();
      expect(deletion.leave(), isTrue);
      // A screen opened again starts another while the first is checked.
      final releaseEarlier = app.auth.gate.holdLaterCallsApart();
      final later = deletion.deleteAccount(
        password: 'Secret1234',
        confirmEmail: testEmail,
      );
      await pumpEventQueue();
      // The earlier check answers first: it was left, so it sends nothing.
      releaseEarlier();
      expect(await earlier, isFalse);
      expect(
        app.account.calls.map((c) => c.$1),
        isNot(contains('deleteAccount')),
      );
      app.auth.gate.open();
      expect(await later, isTrue);
      expect(
        app.account.calls
            .where((c) => c.$1 == 'deleteAccount')
            .map((c) => c.$2),
        [
          [testEmail],
        ],
      );
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
    });

    test('with no deletion running, its screen may be left', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      await pumpEventQueue();
      final deletion = container.read(accountDeletionProvider.notifier);
      expect(deletion.leave(), isTrue);
      expect(deletion.sending.value, isFalse);
      // Leaving before a deletion starts cancels nothing of it.
      expect(
        await deletion.deleteAccount(
          password: 'Secret1234',
          confirmEmail: testEmail,
        ),
        isTrue,
      );
      expect(app.account.calls.last.$1, 'deleteAccount');
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
    });

    // Once the request is on its way, Back waits for its answer:
    // `leave` says no while anyone is signed in, also another account (the
    // router keeps a settings screen open for whoever is signed in), and
    // the deletion completes and signs out as before.
    for (final (name, since) in <(String, AuthStatus?)>[
      ('the deleting account', null),
      ('another account', _otherAccount),
    ]) {
      test('while the deletion is on its way, with $name signed in, its '
          'screen may not be left', () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, accountDeletionProvider);
        listen(container, authStatusProvider);
        await pumpEventQueue();
        app.account.gate.close();
        final deletion = container.read(accountDeletionProvider.notifier);
        final sent = <bool>[];
        deletion.sending.addListener(() => sent.add(deletion.sending.value));
        final deleting = deletion.deleteAccount(
          password: 'Secret1234',
          confirmEmail: testEmail,
        );
        await pumpEventQueue();
        expect(app.account.calls.last.$1, 'deleteAccount');
        expect(deletion.sending.value, isTrue);
        if (since != null) {
          await app.cache.clear();
          app.auth.emit(since);
          await pumpEventQueue();
        }
        expect(deletion.leave(), isFalse);
        expect(deletion.leave(), isFalse);
        app.account.gate.open();
        if (since == null) {
          await deleting;
          expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
        } else {
          await expectLater(deleting, throwsA(isA<SessionExpired>()));
          expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
        }
        expect(sent, [true, false]);
        expect(deletion.sending.value, isFalse);
      });
    }

    // Another account signed in meanwhile may start its own deletion while
    // the earlier one's request is still on its way. The screen stays until
    // neither is: the earlier answer does not let it go.
    test('two deletions on their way at once: its screen may be left only '
        'once both are answered', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      app.account.gate.close();
      final deletion = container.read(accountDeletionProvider.notifier);
      final sent = <bool>[];
      deletion.sending.addListener(() => sent.add(deletion.sending.value));
      final earlier = deletion.deleteAccount(
        password: 'Secret1234',
        confirmEmail: testEmail,
      );
      await pumpEventQueue();
      final answerEarlier = app.account.gate.holdLaterCallsApart();
      await app.cache.clear();
      app.auth.emit(_otherAccount);
      await pumpEventQueue();
      final later = deletion.deleteAccount(
        password: 'Other1234',
        confirmEmail: _otherAccount.email!,
      );
      await pumpEventQueue();
      expect(
        app.account.calls
            .where((c) => c.$1 == 'deleteAccount')
            .map((c) => c.$2),
        [
          [testEmail],
          [_otherAccount.email],
        ],
      );
      answerEarlier();
      await expectLater(earlier, throwsA(isA<SessionExpired>()));
      expect(deletion.sending.value, isTrue);
      expect(deletion.leave(), isFalse);
      app.account.gate.open();
      expect(await later, isTrue);
      expect(app.auth.calls.map((c) => c.$1), [
        'reauthenticate',
        'reauthenticate',
        'signOut',
      ]);
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
      expect(sent, [true, false]);
      expect(deletion.sending.value, isFalse);
      expect(deletion.leave(), isTrue);
    });

    // The later deletion stops at its password check (refused) while the
    // earlier request is on its way: once that one answers, nothing is on
    // its way any more, and the screen may be left.
    test('the earlier answer frees its screen when a later deletion stopped '
        'at its password check', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      app.account.gate.close();
      final deletion = container.read(accountDeletionProvider.notifier);
      final earlier = deletion.deleteAccount(
        password: 'Secret1234',
        confirmEmail: testEmail,
      );
      await pumpEventQueue();
      final answerEarlier = app.account.gate.holdLaterCallsApart();
      await app.cache.clear();
      app.auth.emit(_otherAccount);
      await pumpEventQueue();
      app.auth.gate.failure = const RejectedFailure('invalid_credentials');
      await expectLater(
        deletion.deleteAccount(
          password: 'Wrong1234',
          confirmEmail: _otherAccount.email!,
        ),
        throwsA(isA<RejectedFailure>()),
      );
      app.auth.gate.failure = null;
      expect(deletion.sending.value, isTrue);
      answerEarlier();
      await expectLater(earlier, throwsA(isA<SessionExpired>()));
      expect(deletion.sending.value, isFalse);
      expect(deletion.leave(), isTrue);
      expect(
        app.account.calls.where((c) => c.$1 == 'deleteAccount'),
        hasLength(1),
      );
      app.account.gate.open();
    });

    // The session ends elsewhere while the request is on its way: the
    // router leaves the screen for the sign-in screen (or the new password),
    // and `leave` lets it, so the screen never fights that redirect; the
    // deletion's answer still signs out as a deletion.
    for (final ended in <AuthStatus>[
      const SignedOut(),
      const RecoveringPassword(userId: testUserId),
    ]) {
      test('while the deletion is on its way, the router leaves its screen '
          'once the session ended (${ended.runtimeType})', () async {
        final app = TestApp();
        final container = containerFor(app);
        listen(container, accountDeletionProvider);
        listen(container, authStatusProvider);
        await pumpEventQueue();
        app.account.gate.close();
        final deletion = container.read(accountDeletionProvider.notifier);
        final deleting = deletion.deleteAccount(
          password: 'Secret1234',
          confirmEmail: testEmail,
        );
        await pumpEventQueue();
        await app.cache.clear();
        app.auth.emit(ended);
        await pumpEventQueue();
        expect(deletion.leave(), isTrue);
        app.account.gate.open();
        await deleting;
        expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
      });
    }

    // The deleting session ends elsewhere (signed out in another tab) while
    // the deletion is on its way: its own wipe was a plain sign-out's, so
    // the deletion's answer still signs the device out as a deletion,
    // which removes the invitation and says the account is gone. The same
    // account signed in again is signed out too: it was just deleted. In
    // the app the router leaves the delete screen at that sign-out, which
    // disposes the provider before the answer comes.
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
        for (final screenLeft in [false, true]) {
          test('a deletion answered (${failure?.runtimeType ?? 'deleted'}) '
              'after its session signed out elsewhere, $name, '
              '${screenLeft ? 'its screen left' : 'its screen open'}, signs '
              'out as $cause', () async {
            final app = TestApp();
            final container = containerFor(app);
            final screen = listen(container, accountDeletionProvider);
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
            if (screenLeft) {
              screen.close();
              await pumpEventQueue();
              expect(container.read(accountDeletionProvider.exists), isFalse);
            }
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
    }

    test('once the device is wiped, before the next status, it asks for '
        'nothing', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      listen(container, authStatusProvider);
      await pumpEventQueue();
      await app.cache.clear();
      expect(container.read(authStatusProvider), signedIn);
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

    // Another account's e-mail link replaces the session; or another tab
    // signs it out and the same account signs in again there (or the
    // re-authentication's own sign-in brings it back): the cache then
    // serves that account again, in a new epoch, which asks no deletion
    // either.
    for (final (who, statuses) in [
      ('another account', [_otherAccount]),
      ('the same account', [const SignedOut(), signedIn]),
    ]) {
      test('a session that ends while it signs in again asks for no '
          'deletion, with $who signed in after it', () async {
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
        for (final status in statuses) {
          app.auth.emit(status);
          await pumpEventQueue();
        }
        expect(container.read(authStatusProvider), statuses.last);
        app.auth.gate.open();
        await expectLater(deleting, throwsA(isA<SessionExpired>()));
        expect(
          app.account.calls.map((c) => c.$1),
          isNot(contains('deleteAccount')),
        );
        expect(app.auth.calls.map((c) => c.$1), ['reauthenticate']);
        expect(container.read(authStatusProvider), statuses.last);
      });
    }

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
