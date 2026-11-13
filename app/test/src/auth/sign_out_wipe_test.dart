import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/application/account_deletion.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/team/application/invitation.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../support/fakes.dart';

class _MockAuth extends Mock implements sb.GoTrueClient;

final _config = AppConfig.parse({
  'SUPABASE_URL': 'https://abcdefgh.supabase.co',
  'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_abc',
  'APP_URL': 'https://app.example.pk',
});

sb.Session _session() => sb.Session(
  accessToken: 'a',
  tokenType: 'bearer',
  user: const sb.User(
    id: testUserId,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    email: testEmail,
    createdAt: '2026-11-01T00:00:00Z',
  ),
);

/// The app's sign-out and account deletion, from the controllers down to
/// the device: the real repository over a stand-in for Supabase Auth, the
/// real wipe over in-memory preferences and a recording phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuth gotrue;
  late StreamController<sb.AuthState> changes;
  late sb.Session? session;
  late MemoryStore store;
  late MemorySettingsStore settings;
  late FakeDeviceScratch scratch;
  late FakeAccountRepository account;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(sb.SignOutScope.local));

  setUp(() async {
    gotrue = _MockAuth();
    changes = StreamController<sb.AuthState>.broadcast();
    session = _session();
    when(() => gotrue.onAuthStateChange).thenAnswer((_) => changes.stream);
    when(() => gotrue.currentSession).thenAnswer((_) => session);
    when(() => gotrue.currentUser).thenAnswer((_) => session?.user);
    when(
      () => gotrue.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => sb.AuthResponse(session: session));
    // As gotrue does: the session goes, then the sign-out is announced,
    // then the server is told.
    when(() => gotrue.signOut()).thenAnswer((_) async {
      session = null;
      changes.add(const sb.AuthState(sb.AuthChangeEvent.signedOut, null));
    });
    store = MemoryStore();
    final cache = SwrCache(store);
    await cache.write(testUserId, 'tenants', 1);
    settings = MemorySettingsStore({
      AppSettings.localeKey: 'ur',
      AppSettings.themeKey: 'dark',
      AppSettings.currentPortfolioKey: '$testUserId/p1',
      AppSettings.cameraTargetKey: '{}',
      AppSettings.pendingInvitationKey: 'invitation.verifier',
    });
    scratch = FakeDeviceScratch();
    account = FakeAccountRepository();
    container =
        ProviderContainer.test(
            overrides: [
              swrCacheProvider.overrideWithValue(cache),
              settingsStoreProvider.overrideWithValue(settings),
              deviceScratchProvider.overrideWithValue(scratch),
              accountRepositoryProvider.overrideWithValue(account),
              authRepositoryProvider.overrideWith(
                (ref) => SupabaseAuthRepository(
                  auth: gotrue,
                  wipe: ref.watch(deviceDataWipeProvider),
                  config: _config,
                ),
              ),
            ],
          )
          ..listen(authStatusProvider, (_, _) {})
          ..listen(selectedPortfolioProvider(testUserId), (_, _) {})
          ..listen(pendingInvitationProvider, (_, _) {});
    await pumpEventQueue();
  });

  tearDown(() => changes.close());

  test('signing out wipes the account and keeps the display', () async {
    expect(container.read(selectedPortfolioProvider(testUserId)), 'p1');
    final display = container.read(settingsProvider);

    await container.read(authStatusProvider.notifier).signOut();
    await pumpEventQueue();
    await container.read(deviceDataWipeProvider).settled;

    expect(container.read(authStatusProvider), isA<SignedOut>());
    expect(store.values, isEmpty);
    expect(settings.values, {
      AppSettings.localeKey: 'ur',
      AppSettings.themeKey: 'dark',
      AppSettings.pendingInvitationKey: 'invitation.verifier',
    });
    expect(container.read(settingsProvider), display);
    expect(display.themeMode, ThemeMode.dark);
    expect(container.read(selectedPortfolioProvider(testUserId)), isNull);
    // Kept, for "sign out, then sign in with the invited address".
    expect(container.read(pendingInvitationProvider), 'invitation.verifier');
    expect(
      scratch.calls.map((call) => call.$1),
      containsAll(['drainLostPicks', 'clearPickerCopies', 'sweep']),
    );
  });

  test('a session that ends by itself wipes the same', () async {
    session = null;
    changes.add(const sb.AuthState(sb.AuthChangeEvent.signedOut, null));
    await pumpEventQueue();
    expect(container.read(authStatusProvider), const SignedOut());
    expect(store.values, isEmpty);
    expect(settings.values.keys, {
      AppSettings.localeKey,
      AppSettings.themeKey,
      AppSettings.pendingInvitationKey,
    });
  });

  test('deleting the account wipes the invitation too', () async {
    container.listen(accountDeletionProvider, (_, _) {});
    await pumpEventQueue();
    await container
        .read(accountDeletionProvider.notifier)
        .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
    await pumpEventQueue();

    expect(account.calls.last.$1, 'deleteAccount');
    expect(
      container.read(authStatusProvider),
      const SignedOut(cause: SignOutCause.accountDeleted),
    );
    expect(store.values, isEmpty);
    expect(settings.values, {
      AppSettings.localeKey: 'ur',
      AppSettings.themeKey: 'dark',
    });
    expect(container.read(pendingInvitationProvider), isNull);
  });

  test('a deletion that fails wipes nothing', () async {
    container.listen(accountDeletionProvider, (_, _) {});
    await pumpEventQueue();
    account.gate.failure = const NetworkFailure();
    await expectLater(
      container
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: 'Secret1234', confirmEmail: testEmail),
      throwsA(isA<NetworkFailure>()),
    );
    expect(store.values, isNotEmpty);
    expect(settings.values, hasLength(5));
  });
}
