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
