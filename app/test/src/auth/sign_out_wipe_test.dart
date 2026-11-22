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
import 'package:maalik_e_makaan/src/features/account/application/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:maalik_e_makaan/src/features/team/application/invitation.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';
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

/// Another account, whose e-mail link may be opened on the device.
const _otherId = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91';

sb.Session _session({String id = testUserId, String token = 'a'}) => sb.Session(
  accessToken: token,
  tokenType: 'bearer',
  user: sb.User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: id == testUserId ? testEmail : 'sana.malik@example.com',
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
  late SwrCache cache;
  late MemorySettingsStore settings;
  late FakeDeviceScratch scratch;
  late FakeAccountRepository account;
  late FakePortfolioRepository portfolios;
  late FakeTeamRepository team;
  late FakeProfileRepository profiles;
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
    cache = SwrCache(store);
    await cache.seed(testUserId, 'tenants', 1);
    settings = MemorySettingsStore({
      AppSettings.localeKey: 'ur',
      AppSettings.themeKey: 'dark',
      AppSettings.currentPortfolioKey: '$testUserId/p1',
      AppSettings.cameraTargetKey: '{}',
      AppSettings.pendingInvitationKey: 'invitation.verifier',
    });
    scratch = FakeDeviceScratch();
    account = FakeAccountRepository();
    portfolios = FakePortfolioRepository([gulberg]);
    team = FakeTeamRepository();
    profiles = FakeProfileRepository(ayesha);
    container =
        ProviderContainer.test(
            // As the app retries a query that could not reach the server.
            retry: (count, error) => count < 3 && error is NetworkFailure
                ? const Duration(milliseconds: 50)
                : null,
            overrides: [
              swrCacheProvider.overrideWithValue(cache),
              settingsStoreProvider.overrideWithValue(settings),
              deviceScratchProvider.overrideWithValue(scratch),
              accountRepositoryProvider.overrideWithValue(account),
              portfolioRepositoryProvider.overrideWithValue(portfolios),
              teamRepositoryProvider.overrideWithValue(team),
              profileRepositoryProvider.overrideWithValue(profiles),
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

  test('a deletion the server refused wipes nothing', () async {
    container.listen(accountDeletionProvider, (_, _) {});
    await pumpEventQueue();
    account.gate.failure = const RejectedFailure('does_not_match_account');
    await expectLater(
      container
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: 'Secret1234', confirmEmail: testEmail),
      throwsA(isA<RejectedFailure>()),
    );
    expect(container.read(authStatusProvider), isA<SignedIn>());
    expect(store.values, isNotEmpty);
    expect(settings.values, hasLength(5));
  });

  test(
    'a deletion whose answer was lost wipes as a deletion, at once',
    () async {
      container.listen(accountDeletionProvider, (_, _) {});
      await pumpEventQueue();
      // The connection broke after the request went: the server may have
      // deleted the account.
      account.gate.failure = const NetworkFailure();
      await container
          .read(accountDeletionProvider.notifier)
          .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
      await pumpEventQueue();
      expect(
        container.read(authStatusProvider),
        const SignedOut(cause: SignOutCause.deletionUnconfirmed),
      );
      expect(store.values, isEmpty);
      expect(settings.values, {
        AppSettings.localeKey: 'ur',
        AppSettings.themeKey: 'dark',
      });
    },
  );

  // The session is signed out in another tab while the deletion is on its
  // way. The router then leaves the delete screen, the provider's only
  // listener, so the provider is gone when the answer comes. That sign-out's
  // wipe kept the invitation; the deletion's answer removes it.
  test('a deletion answered after its session was signed out in another '
      'tab, its screen gone, wipes the invitation', () async {
    final screen = container.listen(accountDeletionProvider, (_, _) {});
    await pumpEventQueue();
    account.gate.close();
    final deleting = container
        .read(accountDeletionProvider.notifier)
        .deleteAccount(password: 'Secret1234', confirmEmail: testEmail);
    await pumpEventQueue();
    expect(account.calls.last.$1, 'deleteAccount');
    session = null;
    changes.add(const sb.AuthState(sb.AuthChangeEvent.signedOut, null));
    await pumpEventQueue();
    expect(container.read(authStatusProvider), const SignedOut());
    expect(settings.values.keys, contains(AppSettings.pendingInvitationKey));
    screen.close();
    await pumpEventQueue();
    expect(container.read(accountDeletionProvider.exists), isFalse);
    account.gate.open();
    await deleting;
    await pumpEventQueue();
    expect(
      container.read(authStatusProvider),
      const SignedOut(cause: SignOutCause.accountDeleted),
    );
    expect(settings.values, {
      AppSettings.localeKey: 'ur',
      AppSettings.themeKey: 'dark',
    });
    expect(container.read(pendingInvitationProvider), isNull);
  });

  test('a list still loading when the user signs out leaves no copy', () async {
    store.values.clear();
    portfolios.gate.close();
    container.listen(portfoliosProvider(testUserId), (_, _) {});
    await pumpEventQueue();
    expect(portfolios.calls.map((call) => call.$1), ['listMine']);
    await container.read(authStatusProvider.notifier).signOut();
    await pumpEventQueue();
    // The server answers after the wipe, with a token still valid.
    portfolios.gate.open();
    await pumpEventQueue();
    await container.read(deviceDataWipeProvider).settled;
    expect(
      store.values.keys.where((key) => key.startsWith('mm.swr.')),
      isEmpty,
    );
  });

  group("the session's life cycle", () {
    /// What each status found, as it was applied: the status, whether the
    /// cache served the signed-in user then, and whether the store was
    /// empty.
    late List<(AuthStatus, bool, bool)> applied;

    /// The signed-in user, and whether the cache served them, at each wipe
    /// as it told the app (before the status).
    late List<(String?, bool)> wiped;

    setUp(() {
      applied = [];
      wiped = [];
      container
        ..listen(authStatusProvider, (_, next) {
          applied.add((
            next,
            next is SignedIn && cache.serves(next.userId, cache.epoch),
            store.values.isEmpty,
          ));
        })
        ..listen(deviceDataWipesProvider, (_, _) {
          final user = container.read(currentUserIdProvider);
          wiped.add((user, cache.serves(user, cache.epoch)));
        });
    });

    test('a sign-out serves nobody from the moment the wipe begins, before '
        'the status', () async {
      final epoch = cache.epoch;
      await container.read(authStatusProvider.notifier).signOut();
      await pumpEventQueue();
      // The user still reads as signed in when the wipe has run, but the
      // cache serves them no more.
      expect(wiped, [(testUserId, false)]);
      expect(cache.epoch, epoch + 1);
      // The status finds the account's copies gone.
      expect(applied, hasLength(1));
      expect(applied.single.$1, isA<SignedOut>());
      expect(applied.single.$3, isTrue);
      expect(container.read(sessionProvider), isNull);
    });

    test('a session replaced by another account serves that account only, '
        'once its status comes', () async {
      final epoch = cache.epoch;
      session = _session(id: _otherId);
      changes.add(sb.AuthState(sb.AuthChangeEvent.signedIn, session));
      await pumpEventQueue();
      expect(wiped, [(testUserId, false)]);
      expect(applied.single.$1, isA<SignedIn>());
      expect(applied.single.$2, isTrue);
      expect(applied.single.$3, isTrue);
      expect(cache.epoch, epoch + 2);
      expect(cache.serves(_otherId, cache.epoch), isTrue);
      expect(cache.serves(testUserId, cache.epoch), isFalse);
    });

    for (final (name, event) in [
      ('a new link of the same account', sb.AuthChangeEvent.signedIn),
      ('a refreshed token', sb.AuthChangeEvent.tokenRefreshed),
      ('a changed user', sb.AuthChangeEvent.userUpdated),
    ]) {
      test('$name keeps the session it serves', () async {
        final epoch = cache.epoch;
        session = _session(token: 'b');
        changes.add(sb.AuthState(event, session));
        await pumpEventQueue();
        expect(wiped, isEmpty);
        expect(cache.epoch, epoch);
        expect(cache.serves(testUserId, epoch), isTrue);
        expect(store.values, isNotEmpty);
      });
    }

    test('a password recovery by the signed-in account serves nobody until '
        'the new password, then a new session', () async {
      final epoch = cache.epoch;
      changes.add(sb.AuthState(sb.AuthChangeEvent.passwordRecovery, session));
      await pumpEventQueue();
      expect(applied.last.$1, const RecoveringPassword(userId: testUserId));
      expect(cache.epoch, epoch + 1);
      expect(cache.serves(testUserId, cache.epoch), isFalse);
      changes.add(sb.AuthState(sb.AuthChangeEvent.userUpdated, session));
      await pumpEventQueue();
      expect(applied.last.$2, isTrue);
      expect(cache.epoch, epoch + 2);
      // Nothing was wiped: the account's saved copies stay.
      expect(wiped, isEmpty);
      expect(store.values, isNotEmpty);
    });

    test("a password recovery with another account's link wipes, and serves "
        'nobody', () async {
      session = _session(id: _otherId);
      changes.add(sb.AuthState(sb.AuthChangeEvent.passwordRecovery, session));
      await pumpEventQueue();
      expect(wiped, [(testUserId, false)]);
      expect(applied.single.$1, const RecoveringPassword(userId: _otherId));
      expect(container.read(sessionProvider), isNull);
      expect(store.values, isEmpty);
    });

    test('an old sign-out and an older session replayed to a listener while '
        'signed in change nothing', () async {
      final epoch = cache.epoch;
      changes
        ..add(const sb.AuthState(sb.AuthChangeEvent.signedOut, null))
        ..add(
          sb.AuthState(
            sb.AuthChangeEvent.initialSession,
            _session(id: _otherId),
          ),
        );
      await pumpEventQueue();
      expect(wiped, isEmpty);
      expect(cache.epoch, epoch);
      expect(container.read(authStatusProvider), isA<SignedIn>());
      expect(container.read(currentUserIdProvider), testUserId);
      expect(store.values.keys, [cacheKey(testUserId, 'tenants')]);
    });

    test('the same account back while the wipe waits for the store is '
        'served again: the list and the team are read and saved', () async {
      container
        ..listen(portfoliosProvider(testUserId), (_, _) {})
        ..listen(teamProvider(gulberg), (_, _) {});
      await pumpEventQueue();
      final listed = portfolios.calls.length;
      final read = team.calls.length;
      store.keysHeld = Completer();
      final ending = container.read(authStatusProvider.notifier).signOut();
      await pumpEventQueue();
      // The account's session comes back (its e-mail link, another tab)
      // before the wipe's listing answers.
      session = _session();
      changes.add(sb.AuthState(sb.AuthChangeEvent.signedIn, session));
      store.keysHeld!.complete();
      store.keysHeld = null;
      await ending;
      await pumpEventQueue();
      expect(container.read(currentUserIdProvider), testUserId);
      expect(cache.serves(testUserId, cache.epoch), isTrue);
      expect(portfolios.calls.length, greaterThan(listed));
      expect(team.calls.length, greaterThan(read));
      await container.read(portfoliosProvider(testUserId).notifier).reload();
      await container.read(teamProvider(gulberg).notifier).reload();
      expect(
        store.values.keys,
        containsAll([
          cacheKey(testUserId, 'portfolios'),
          cacheKey(testUserId, 'team.${gulberg.id}', portfolio: gulberg.id),
        ]),
      );
    });

    for (final replaced in [false, true]) {
      test('a query first built between the wipe and the status asks for '
          'nothing (${replaced ? 'replaced' : 'signed out'})', () async {
        store.keysHeld = Completer();
        team.gate.close();
        final Future<void> ending;
        if (replaced) {
          session = _session(id: _otherId);
          changes.add(sb.AuthState(sb.AuthChangeEvent.signedIn, session));
          ending = Future.value();
        } else {
          ending = container.read(authStatusProvider.notifier).signOut();
        }
        await pumpEventQueue();
        // The window: the cache serves nobody, the user still reads as the
        // one who signed out.
        expect(container.read(currentUserIdProvider), testUserId);
        expect(cache.serves(testUserId, cache.epoch), isFalse);
        // A screen opened now.
        container
          ..listen(teamProvider(plaza), (_, _) {})
          ..listen(profileProvider(testUserId), (_, _) {});
        await pumpEventQueue();
        expect(team.calls, isEmpty);
        expect(profiles.calls, isEmpty);
        store.keysHeld!.complete();
        store.keysHeld = null;
        await ending;
        await pumpEventQueue();
        team.gate.open();
        await pumpEventQueue();
        await container.read(deviceDataWipeProvider).settled;
        expect(profiles.calls, isEmpty);
        expect(
          store.values.keys.where((key) => key.contains(testUserId)),
          isEmpty,
        );
        if (!replaced) {
          expect(team.calls, isEmpty);
          expect(store.values, isEmpty);
        }
      });
    }

    test('a failed query retried between the wipe and the status asks for '
        'nothing', () async {
      team.readFailure = const NetworkFailure();
      container.listen(teamProvider(plaza), (_, _) {});
      await pumpEventQueue();
      expect(container.read(teamProvider(plaza)).error, isA<NetworkFailure>());
      // The connection is back; the wipe's listing waits for the store
      // while the retry timer fires.
      team.readFailure = null;
      store.keysHeld = Completer();
      final ending = container.read(authStatusProvider.notifier).signOut();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(container.read(currentUserIdProvider), testUserId);
      expect(team.calls.map((call) => call.$1), ['members']);
      store.keysHeld!.complete();
      store.keysHeld = null;
      await ending;
      await pumpEventQueue();
      await container.read(deviceDataWipeProvider).settled;
      expect(team.calls.map((call) => call.$1), ['members']);
      expect(store.values, isEmpty);
    });
  });
}
