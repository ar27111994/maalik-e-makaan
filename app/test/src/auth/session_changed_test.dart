import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';

import '../../support/container.dart';
import '../../support/harness.dart';

const _other = SignedIn(userId: 'another-user', email: 'other@example.com');

/// The user's own list, profile and residence are read by providers keyed
/// by the user. Once the session is another account's, or nobody's, none
/// of them holds what it showed of the user (`sessionChanged`): a screen
/// that reads `state.value` finds nothing of them.
void main() {
  final providers = <String, ProviderListenable<AsyncValue<Snapshot<Object?>>>>{
    'the portfolio list': portfoliosProvider(testUserId),
    'the profile': profileProvider(testUserId),
    'the residence': residenceProvider(testUserId),
  };

  for (final MapEntry(key: name, value: provider) in providers.entries) {
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
    });
  }
}
