import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/application/account_deletion.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';

import '../../support/container.dart';
import '../../support/harness.dart';

const _other = SignedIn(userId: 'another-user', email: 'other@example.com');

/// A provider that reads for the session, and the gate of the request it
/// makes when it is built.
typedef _Reader = ({
  ProviderListenable<AsyncValue<Object?>> provider,
  Gate Function(TestApp app) gate,
});

/// The user's own list, profile and residence are read by providers keyed
/// by the user, and the deletion preview (which names the portfolios the
/// account would delete) by one that is not. Once the session is another
/// account's, or nobody's, none of them holds what it showed of the user
/// (`sessionChanged`): a screen that reads `state.value` finds nothing of
/// them. For a new session of the same account, each keeps it on show
/// until the new one comes.
void main() {
  final readers = <String, _Reader>{
    'the portfolio list': (
      provider: portfoliosProvider(testUserId),
      gate: (app) => app.portfolios.gate,
    ),
    'the profile': (
      provider: profileProvider(testUserId),
      gate: (app) => app.profiles.gate,
    ),
    'the residence': (
      provider: residenceProvider(testUserId),
      gate: (app) => app.residences.gate,
    ),
    'the deletion preview': (
      provider: accountDeletionProvider,
      gate: (app) => app.account.gate,
    ),
  };

  for (final MapEntry(key: name, value: (:provider, :gate))
      in readers.entries) {
    group('sessionChanged: $name', () {
      late TestApp app;
      late ProviderContainer container;

      setUp(() async {
        app = TestApp();
        container = containerFor(app);
        listen(container, provider);
        await pumpEventQueue();
        expect(container.read(provider).value, isNotNull);
      });

      test("is not on show once another account's status comes", () async {
        // What the next account asks for waits: until it answers, nothing
        // of the user is on show.
        gate(app).close();
        // Another account's e-mail link: the wipe, then its status.
        await app.cache.clear();
        app.auth.emit(_other);
        await pumpEventQueue();
        final state = container.read(provider);
        expect(state.value, isNull);
        expect(state.error, isA<SessionExpired>());
      });

      test('is not on show once the user signs out', () async {
        await app.cache.clear();
        app.auth.emit(const SignedOut());
        await pumpEventQueue();
        expect(container.read(provider).value, isNull);
      });

      test('stays on show for a new session of the same account, until '
          'its answer comes', () async {
        final before = container.read(provider).value;
        gate(app).close();
        // The device was wiped, and the same account signed in again.
        await app.cache.clear();
        app.auth.emit(signedIn);
        await pumpEventQueue();
        final waiting = container.read(provider);
        expect(waiting.isLoading, isTrue);
        expect(waiting.value, same(before));
        gate(app).open();
        await pumpEventQueue();
        final after = container.read(provider);
        expect(after.isLoading, isFalse);
        expect(after.value, isNotNull);
      });
    });
  }

  group('the deletion preview', () {
    test("is asked again for another account's session, and shows that "
        "account's", () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      await pumpEventQueue();
      app.account.preview = const DeletionPreview(
        portfoliosToDelete: [
          DoomedPortfolio(id: 'pb', name: 'Other Flats', otherMembers: 0),
        ],
        reauthMaxAge: Duration(minutes: 10),
        secondFactorRequired: false,
      );
      await app.cache.clear();
      app.auth.emit(_other);
      await pumpEventQueue();
      expect(
        [
          for (final portfolio
              in container
                  .read(accountDeletionProvider)
                  .value!
                  .portfoliosToDelete)
            portfolio.name,
        ],
        ['Other Flats'],
      );
      expect(app.account.calls, [
        ('deletionPreview', const <Object?>[]),
        ('deletionPreview', const <Object?>[]),
      ]);
    });

    test('with nobody signed in, asks for nothing', () async {
      final app = TestApp(auth: const SignedOut());
      final container = containerFor(app);
      listen(container, accountDeletionProvider);
      await pumpEventQueue();
      expect(
        container.read(accountDeletionProvider).error,
        isA<SessionExpired>(),
      );
      expect(app.account.calls, isEmpty);
    });
  });
}
