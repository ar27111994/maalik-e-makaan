import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/team/application/invitation.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../support/fakes.dart';

class _MockAuth extends Mock implements sb.GoTrueClient;

/// A store that never answers, as a platform call that hangs.
final class _HangingStore implements KeyValueStore {
  @override
  Future<String?> read(String key) => Completer<String?>().future;

  @override
  Future<void> write(String key, String value) => Completer<void>().future;

  @override
  Future<void> delete(String key) => Completer<void>().future;

  @override
  Future<Set<String>> keys() => Completer<Set<String>>().future;
}

/// A store that lists its keys only once the test lets it, as a platform
/// call that hangs and answers later.
final class _LateStore implements KeyValueStore {
  final inner = MemoryStore();
  final listing = Completer<void>();

  @override
  Future<String?> read(String key) => inner.read(key);

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<Set<String>> keys() => listing.future.then((_) => inner.keys());
}

/// Settings whose removal of [stuck] never answers.
final class _StuckSettings implements SettingsStore {
  new(this.inner, this.stuck);

  final MemorySettingsStore inner;
  final String stuck;

  @override
  String? getString(String key) => inner.getString(key);

  @override
  bool? getBool(String key) => inner.getBool(key);

  @override
  Future<void> setString(String key, String value) =>
      inner.setString(key, value);

  @override
  Future<void> setBool(String key, {required bool value}) =>
      inner.setBool(key, value: value);

  @override
  Future<void> remove(String key) =>
      key == stuck ? Completer<void>().future : inner.remove(key);
}

/// The display settings, which belong to the device and are never wiped.
const _display = <String, Object>{
  AppSettings.localeKey: 'ur',
  AppSettings.themeKey: 'dark',
  AppSettings.highContrastKey: true,
  AppSettings.groupingKey: 'southAsian',
};

/// Everything the app keeps in the preferences for an account.
Map<String, Object> _everything() => {
  ..._display,
  AppSettings.currentPortfolioKey: '$testUserId/p1',
  AppSettings.cameraTargetKey: '{"user":"$testUserId"}',
  AppSettings.pendingInvitationKey: 'invitation.verifier',
};

final _now = DateTime.utc(2026, 11, 13, 9);

void main() {
  late MemoryStore store;
  late SwrCache cache;
  late MemorySettingsStore settings;
  late FakeDeviceScratch scratch;
  late List<WipeReason> wiped;
  late DeviceDataWipe wipe;

  setUp(() async {
    store = MemoryStore();
    cache = SwrCache(store);
    await cache.seed(testUserId, 'tenants', [
      {'cnic': '35202-0000000-1'},
    ]);
    // Not the cache's: kept.
    await store.write('other', '1');
    settings = MemorySettingsStore(_everything());
    scratch = FakeDeviceScratch()..lostPicks = ['/cache/scaled_lost.jpg'];
    wiped = [];
    wipe = DeviceDataWipe(
      cache: cache,
      settings: settings,
      scratch: scratch,
      onWiped: wiped.add,
      clock: () => _now,
    );
  });

  List<String> asked() => [for (final call in scratch.calls) call.$1];

  /// The calls, as lists (records compare lists by identity).
  List<List<Object?>> calls() => [
    for (final call in scratch.calls) [call.$1, ...call.$2],
  ];

  group('WipeReason', () {
    test('says which end a session', () {
      expect(WipeReason.startedSignedOut.endsSession, isFalse);
      expect(WipeReason.signedOut.endsSession, isTrue);
      expect(WipeReason.accountDeleted.endsSession, isTrue);
    });
  });

  group('a session that ends', () {
    test('takes the account, keeps the display and the invitation', () async {
      await wipe.wipe(WipeReason.signedOut);
      expect(store.values, {'other': '1'});
      expect(settings.values, {
        ..._display,
        AppSettings.pendingInvitationKey: 'invitation.verifier',
      });
      expect(wiped, [WipeReason.signedOut]);
      await wipe.settled;
      expect(calls(), [
        // The steps start together; the lost picks' copies go once the
        // record is drained.
        ['drainLostPicks'],
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), _now],
        ['discard', '/cache/scaled_lost.jpg'],
      ]);
    });

    testWidgets('a store that never answers does not hold the wipe up', (
      tester,
    ) async {
      // Made in the test's fake time, as its timers are.
      final stuck = DeviceDataWipe(
        cache: SwrCache(_HangingStore()),
        settings: settings,
        scratch: scratch,
      );
      var done = 0;
      unawaited(stuck.wipe(WipeReason.signedOut).then((_) => done++));
      // A second call runs its own, within the same limit.
      unawaited(stuck.wipe(WipeReason.signedOut).then((_) => done++));
      await tester.pump(wipePreferencesLimit - const Duration(seconds: 1));
      expect(done, 0);
      // The files did not wait for it.
      expect(asked(), contains('sweep'));
      await tester.pump(const Duration(seconds: 1));
      expect(done, 2);
    });

    test('a deleted account takes the invitation too', () async {
      await wipe.wipe(WipeReason.accountDeleted);
      expect(settings.values, _display);
      expect(wiped, [WipeReason.accountDeleted]);
      await wipe.settled;
      expect(asked(), [
        'drainLostPicks',
        'clearPickerCopies',
        'sweep',
        'discard',
      ]);
    });

    test('returns before the files are done', () async {
      scratch.sweeping = Completer();
      await wipe.wipe(WipeReason.signedOut);
      expect(store.values, {'other': '1'});
      var settled = false;
      unawaited(wipe.settled.then((_) => settled = true));
      await pumpEventQueue();
      expect(settled, isFalse);
      scratch.sweeping!.complete();
      await pumpEventQueue();
      expect(settled, isTrue);
    });

    test('a cache entry that cannot be deleted leaves the others to '
        'go', () async {
      await cache.seed(testUserId, 'leases', [1]);
      await cache.seed('another-user', 'tenants', [1]);
      store.undeletable.add(cacheKey(testUserId, 'tenants'));
      await wipe.wipe(WipeReason.signedOut);
      expect(store.values.keys, [cacheKey(testUserId, 'tenants'), 'other']);
      expect(settings.values, {
        ..._display,
        AppSettings.pendingInvitationKey: 'invitation.verifier',
      });
      expect(wiped, [WipeReason.signedOut]);
    });

    test('a step that fails leaves the others to run', () async {
      settings.writeFailure = Exception('read-only');
      scratch.failure = Exception('no activity');
      final failing = DeviceDataWipe(
        cache: cache,
        settings: settings,
        scratch: scratch,
        onWiped: (_) => throw StateError('disposed'),
      );
      await expectLater(failing.wipe(WipeReason.accountDeleted), completes);
      await failing.settled;
      // The cache went although the preferences could not be written, and
      // every plugin step ran although the one before failed.
      expect(store.values, {'other': '1'});
      expect(asked(), [
        'drainLostPicks',
        'clearPickerCopies',
        'sweep',
        'discard',
      ]);
      expect(calls().last, ['discard']);
    });
  });

  group('a file step that never answers', () {
    test('picker copies that never go hold up neither the lost picks nor '
        'the sweep', () async {
      scratch.clearing = Completer();
      await wipe.wipe(WipeReason.signedOut);
      await pumpEventQueue();
      expect(calls(), [
        ['drainLostPicks'],
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), _now],
        ['discard', '/cache/scaled_lost.jpg'],
      ]);
    });

    test('a record of lost picks that never comes holds up neither the '
        'picker copies nor the sweep', () async {
      scratch.draining = Completer();
      await wipe.wipe(WipeReason.signedOut);
      await pumpEventQueue();
      expect(calls(), [
        ['drainLostPicks'],
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), _now],
      ]);
      // When it comes, its copies go.
      scratch.draining!.complete();
      await wipe.settled;
      expect(calls().last, ['discard', '/cache/scaled_lost.jpg']);
    });

    testWidgets('the next pass waits for it at most the files limit', (
      tester,
    ) async {
      // Made in the test's fake time, as its timers are.
      final slow = DeviceDataWipe(
        cache: cache,
        settings: settings,
        scratch: scratch..clearing = Completer(),
        clock: () => _now,
      );
      await slow.wipe(WipeReason.signedOut);
      slow.atResume();
      await tester.pump(wipeFilesLimit - const Duration(seconds: 1));
      expect(asked().where((name) => name == 'sweep'), hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(asked().where((name) => name == 'sweep'), hasLength(2));
    });
  });

  group('a store that does not answer', () {
    /// When each pass over the files began.
    List<Object?> sweeps() => [
      for (final call in scratch.calls)
        if (call.$1 == 'sweep') call.$2.last,
    ];

    testWidgets('holds up neither the other preferences nor what is kept in '
        'memory', (tester) async {
      // Made in the test's fake time, as its timers are.
      final stuck = DeviceDataWipe(
        cache: SwrCache(_HangingStore()),
        settings: settings,
        scratch: scratch,
        onWiped: wiped.add,
        clock: () => _now,
      );
      var done = false;
      unawaited(stuck.wipe(WipeReason.accountDeleted).then((_) => done = true));
      await tester.pump();
      // The account's preferences do not wait for the cache: they go at
      // once.
      expect(settings.values, _display);
      expect(done, isFalse);
      expect(wiped, isEmpty);
      await tester.pump(wipePreferencesLimit);
      // The wipe has returned to the sign-out, and what is kept in memory
      // is told.
      expect(done, isTrue);
      expect(wiped, [WipeReason.accountDeleted]);
    });

    for (final key in [
      AppSettings.currentPortfolioKey,
      AppSettings.cameraTargetKey,
      AppSettings.pendingInvitationKey,
    ]) {
      testWidgets('for $key leaves the others to go, and the wipe to '
          'end', (tester) async {
        final stuck = DeviceDataWipe(
          cache: cache,
          settings: _StuckSettings(settings, key),
          scratch: scratch,
          onWiped: wiped.add,
          clock: () => _now,
        );
        var done = false;
        unawaited(
          stuck.wipe(WipeReason.accountDeleted).then((_) => done = true),
        );
        await tester.pump();
        expect(store.values, {'other': '1'});
        expect(settings.values, {..._display, key: _everything()[key]});
        expect(done, isFalse);
        expect(wiped, isEmpty);
        await tester.pump(wipePreferencesLimit);
        expect(done, isTrue);
        expect(wiped, [WipeReason.accountDeleted]);
      });
    }

    testWidgets('for the camera at a signed-in start does not hold the '
        'start up', (tester) async {
      final stuck = DeviceDataWipe(
        cache: cache,
        settings: _StuckSettings(settings, AppSettings.cameraTargetKey),
        scratch: scratch,
        onWiped: wiped.add,
        clock: () => _now,
      );
      var done = false;
      unawaited(
        stuck
            .atStart(signedInAs: testUserId, photoMayReturn: false)
            .then((_) => done = true),
      );
      await tester.pump();
      expect(done, isFalse);
      await tester.pump(wipePreferencesLimit);
      expect(done, isTrue);
      // The signed-in account's own stay.
      expect(settings.values, _everything());
      expect(store.values, hasLength(2));
      expect(wiped, isEmpty);
    });

    testWidgets('for one cache entry leaves the other entries and the '
        'preferences to go', (tester) async {
      await cache.seed('another-user', 'tenants', [1]);
      store.silent.add(cacheKey(testUserId, 'tenants'));
      var done = false;
      unawaited(wipe.wipe(WipeReason.signedOut).then((_) => done = true));
      await tester.pump();
      expect(store.values.keys, [cacheKey(testUserId, 'tenants'), 'other']);
      expect(
        settings.values,
        {..._everything()}
          ..remove(AppSettings.currentPortfolioKey)
          ..remove(AppSettings.cameraTargetKey),
      );
      expect(done, isFalse);
      await tester.pump(wipePreferencesLimit);
      expect(done, isTrue);
      expect(wiped, [WipeReason.signedOut]);
    });

    testWidgets('leaves a later wipe its own work: someone may have signed '
        'in', (tester) async {
      var time = _now;
      final stuck = DeviceDataWipe(
        cache: SwrCache(_HangingStore()),
        settings: settings,
        scratch: scratch,
        onWiped: wiped.add,
        clock: () => time,
      );
      unawaited(stuck.wipe(WipeReason.signedOut));
      await tester.pump(wipePreferencesLimit);
      expect(sweeps(), [_now]);
      // The next account signs in once the first wipe has returned,
      // chooses a portfolio, photographs a document, and signs out.
      await settings.setString(AppSettings.currentPortfolioKey, 'next/p2');
      time = _now.add(const Duration(minutes: 3));
      var done = false;
      unawaited(stuck.wipe(WipeReason.signedOut).then((_) => done = true));
      await tester.pump();
      expect(settings.values, isNot(contains(AppSettings.currentPortfolioKey)));
      await tester.pump(wipePreferencesLimit);
      expect(done, isTrue);
      expect(wiped, [WipeReason.signedOut, WipeReason.signedOut]);
      // Its own pass over the files, from its own time.
      expect(sweeps(), [_now, time]);
    });

    testWidgets('and answers later finishes what it was asked, and touches '
        'nothing of the account signed in since', (tester) async {
      final late = _LateStore();
      final lateCache = SwrCache(late);
      await lateCache.seed(testUserId, 'tenants', 1);
      final stuck = DeviceDataWipe(
        cache: lateCache,
        settings: settings,
        scratch: scratch,
        onWiped: wiped.add,
        clock: () => _now,
      );
      var done = false;
      unawaited(stuck.wipe(WipeReason.accountDeleted).then((_) => done = true));
      await tester.pump(wipePreferencesLimit);
      expect(done, isTrue);
      expect(wiped, [WipeReason.accountDeleted]);
      expect(late.inner.values, isNotEmpty);
      // The next account signs in right after, chooses a portfolio and
      // opens an invitation.
      const next = {
        AppSettings.currentPortfolioKey: 'next/p2',
        AppSettings.pendingInvitationKey: 'next.invitation',
      };
      for (final MapEntry(:key, :value) in next.entries) {
        await settings.setString(key, value);
      }
      // The store answers at last: the first account's copies go.
      late.listing.complete();
      await tester.pump();
      expect(late.inner.values, isEmpty);
      // The next account's choices stay, and nothing is told twice.
      expect(settings.values, {..._display, ...next});
      expect(wiped, [WipeReason.accountDeleted]);
      // A fetch of the first account that was on its way is still dropped.
      await lateCache.write(
        testUserId,
        'tenants',
        scopeOf('tenants', portfolio: gulberg.id),
        2,
        (value) => value,
        epoch: 0,
      );
      expect(late.inner.values, isEmpty);
    });
  });

  group('start-up', () {
    test('signed out, it forgets what an earlier run left of an account, '
        'but not a photo the camera may still bring back', () async {
      await wipe.atStart(signedInAs: null, photoMayReturn: true);
      expect(store.values, {'other': '1'});
      expect(settings.values, {
        ..._display,
        AppSettings.cameraTargetKey: '{"user":"$testUserId"}',
        AppSettings.pendingInvitationKey: 'invitation.verifier',
      });
      expect(wiped, [WipeReason.startedSignedOut]);
      await wipe.settled;
      expect(calls(), [
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), null],
      ]);
    });

    test('signed out, with no photo to bring back, the camera goes too '
        "(an older version's photos, a record nobody came back for)", () async {
      await wipe.atStart(signedInAs: null, photoMayReturn: false);
      expect(settings.values, {
        ..._display,
        AppSettings.pendingInvitationKey: 'invitation.verifier',
      });
      await wipe.settled;
      expect(calls(), [
        // The steps start together; the lost picks' copies go once the
        // record is drained.
        ['drainLostPicks'],
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), _now],
        ['discard', '/cache/scaled_lost.jpg'],
      ]);
    });

    test(
      "signed in, it keeps the user's own, and tidies the old files",
      () async {
        await wipe.atStart(signedInAs: testUserId, photoMayReturn: true);
        await wipe.settled;
        expect(settings.values, _everything());
        expect(store.values, hasLength(2));
        expect(wiped, isEmpty);
        expect(calls(), [
          ['clearPickerCopies', _now],
          ['sweep', _now.subtract(sharedFileGrace), null],
        ]);
      },
    );

    test("signed in, it removes what another account's wipe could not: its "
        'records and its chosen portfolio', () async {
      const other = 'another-user';
      final key = cacheKey(other, 'tenants.p1');
      await cache.seed(other, 'tenants.p1', [
        {'cnic': '00000-0000000-0'},
      ]);
      await settings.setString(AppSettings.currentPortfolioKey, '$other/p1');
      // Its session ended, and its wipe could not delete the records.
      store.undeletable.add(key);
      await wipe.wipe(WipeReason.signedOut);
      expect(store.values.keys, containsAll([key, 'other']));
      store.undeletable.clear();
      await settings.setString(AppSettings.currentPortfolioKey, '$other/p1');
      await cache.seed(testUserId, 'tenants', [1]);
      // The next start, signed in as the test user.
      final next = DeviceDataWipe(
        cache: SwrCache(store),
        settings: settings,
        scratch: scratch,
        clock: () => _now,
      );
      await next.atStart(signedInAs: testUserId, photoMayReturn: true);
      await next.settled;
      expect(store.values.keys.toSet(), {
        cacheKey(testUserId, 'tenants'),
        'other',
      });
      expect(settings.values, isNot(contains(AppSettings.currentPortfolioKey)));
    });

    test('signed in, one removal that never answers holds up neither the '
        'other nor the start', () async {
      final key = cacheKey('another-user', 'tenants');
      await cache.seed('another-user', 'tenants', [1]);
      await settings.setString(
        AppSettings.currentPortfolioKey,
        'another-user/p1',
      );
      store.silent.add(key);
      final quick = DeviceDataWipe(
        cache: cache,
        settings: settings,
        scratch: scratch,
        clock: () => _now,
        preferencesLimit: const Duration(milliseconds: 20),
      );
      await quick
          .atStart(signedInAs: testUserId, photoMayReturn: true)
          .timeout(const Duration(seconds: 10));
      expect(settings.values, isNot(contains(AppSettings.currentPortfolioKey)));
      expect(store.values.keys, contains(cacheKey(testUserId, 'tenants')));
    });

    test('signed in, with no photo to bring back, the camera goes', () async {
      await wipe.atStart(signedInAs: testUserId, photoMayReturn: false);
      await wipe.settled;
      expect(
        settings.values,
        {..._everything()}..remove(AppSettings.cameraTargetKey),
      );
      expect(store.values, hasLength(2));
      expect(wiped, isEmpty);
      expect(asked(), [
        'drainLostPicks',
        'clearPickerCopies',
        'sweep',
        'discard',
      ]);
      expect(calls()[2], ['sweep', _now.subtract(sharedFileGrace), _now]);
    });

    test(
      'bootstrap starts it without waiting, from the session read',
      () async {
        final auth = _MockAuth();
        final asks = <DateTime>[];
        bool photo(SettingsStore read, DateTime now) {
          expect(read, same(settings));
          asks.add(now);
          return true;
        }

        when(() => auth.currentSession).thenReturn(
          sb.Session(
            accessToken: 'a',
            tokenType: 'bearer',
            user: const sb.User(
              id: testUserId,
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-11-01T00:00:00Z',
            ),
          ),
        );
        tidyDeviceAtStart(
          cache,
          settings,
          auth: auth,
          photoMayReturn: photo,
          scratch: scratch,
          clock: () => _now,
        );
        await pumpEventQueue();
        // Signed in: the account stays.
        expect(settings.values, _everything());
        expect(store.values, hasLength(2));
        expect(asked(), ['clearPickerCopies', 'sweep']);
        expect(asks, [_now]);

        when(() => auth.currentSession).thenReturn(null);
        tidyDeviceAtStart(
          cache,
          settings,
          auth: auth,
          photoMayReturn: photo,
          scratch: scratch,
        );
        await pumpEventQueue();
        expect(store.values, {'other': '1'});
        expect(
          settings.values,
          isNot(contains(AppSettings.currentPortfolioKey)),
        );
        expect(settings.values, contains(AppSettings.cameraTargetKey));
        // Without a clock, the device's.
        expect(asks.last, isNot(_now));
      },
    );

    test('off a phone, the default scratch touches nothing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final auth = _MockAuth();
      when(() => auth.currentSession).thenReturn(null);
      tidyDeviceAtStart(
        cache,
        settings,
        auth: auth,
        photoMayReturn: (_, _) => false,
      );
      await pumpEventQueue();
      expect(store.values, {'other': '1'});
      expect(settings.values, {
        ..._display,
        AppSettings.pendingInvitationKey: 'invitation.verifier',
      });
    });
  });

  group('coming back to the foreground', () {
    test('sweeps only the old shared files', () async {
      wipe.atResume();
      await wipe.settled;
      expect(calls(), [
        ['sweep', _now.subtract(sharedFileGrace), null],
      ]);
      expect(settings.values, _everything());
      expect(store.values, hasLength(2));
      expect(wiped, isEmpty);
    });
  });

  group('wipes that meet', () {
    test('a start-up wipe that keeps the camera leaves one that removes it '
        'its work', () async {
      await Future.wait([
        wipe.atStart(signedInAs: null, photoMayReturn: true),
        wipe.atStart(signedInAs: null, photoMayReturn: false),
      ]);
      expect(wiped, [WipeReason.startedSignedOut, WipeReason.startedSignedOut]);
      expect(settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    test('each removes the preferences on its own, while another is on its '
        'way', () async {
      await Future.wait([
        wipe.wipe(WipeReason.accountDeleted),
        wipe.wipe(WipeReason.signedOut),
      ]);
      expect(wiped, [WipeReason.accountDeleted, WipeReason.signedOut]);
      await Future.wait([
        wipe.wipe(WipeReason.signedOut),
        wipe.wipe(WipeReason.accountDeleted),
      ]);
      expect(wiped, hasLength(4));
      expect(settings.values, _display);
    });

    test('a session that begins and ends while a wipe waits for the store '
        'is wiped by its own: its entries, its choice and its fetch on the '
        'way', () async {
      final late = _LateStore();
      final lateCache = SwrCache(late);
      await lateCache.seed(testUserId, 'tenants', 1);
      final timed = DeviceDataWipe(
        cache: lateCache,
        settings: settings,
        scratch: scratch,
        onWiped: wiped.add,
        clock: () => _now,
      );
      final first = timed.wipe(WipeReason.signedOut);
      await pumpEventQueue();
      // The next account signs in, chooses a portfolio, and signs out with
      // a fetch of its still on its way.
      await settings.setString(AppSettings.currentPortfolioKey, 'next/p2');
      late.inner.holding.add(cacheKey('next-user', 'tenants'));
      final writing = lateCache.write(
        'next-user',
        'tenants',
        scopeOf('tenants'),
        2,
        (value) => value,
        epoch: lateCache.epoch,
      );
      await pumpEventQueue();
      final second = timed.wipe(WipeReason.signedOut);
      await pumpEventQueue();
      expect(settings.values, isNot(contains(AppSettings.currentPortfolioKey)));
      late.inner.finishHeldWritesOldestFirst();
      await writing;
      late.listing.complete();
      await Future.wait([first, second]);
      expect(late.inner.values, isEmpty);
      expect(wiped, [WipeReason.signedOut, WipeReason.signedOut]);
    });

    test('a later one wipes again: someone may have signed in', () async {
      var time = _now;
      final timed = DeviceDataWipe(
        cache: cache,
        settings: settings,
        scratch: scratch..sweeping = Completer(),
        onWiped: wiped.add,
        clock: () => time,
      );
      await timed.wipe(WipeReason.signedOut);
      // The next account signs in while the files are still going, and
      // signs out in turn.
      await cache.seed('next-user', 'tenants', 1);
      await settings.setString(AppSettings.currentPortfolioKey, 'next/p2');
      time = _now.add(const Duration(minutes: 3));
      await timed.wipe(WipeReason.signedOut);
      expect(store.values, {'other': '1'});
      expect(settings.values, isNot(contains(AppSettings.currentPortfolioKey)));
      expect(wiped, [WipeReason.signedOut, WipeReason.signedOut]);
      // One pass over the files at a time, each with its own time.
      await pumpEventQueue();
      expect(asked().where((name) => name == 'sweep'), hasLength(1));
      scratch.sweeping!.complete();
      await timed.settled;
      final sweeps = [
        for (final call in scratch.calls)
          if (call.$1 == 'sweep') call.$2.last,
      ];
      expect(sweeps, [_now, time]);
    });

    testWidgets('files that take too long stop being waited for', (
      tester,
    ) async {
      // Made in the test's fake time, as its timers are.
      final slow = DeviceDataWipe(
        cache: cache,
        settings: settings,
        scratch: scratch..sweeping = Completer(),
      );
      await slow.wipe(WipeReason.signedOut);
      var settled = false;
      unawaited(slow.settled.then((_) => settled = true));
      await tester.pump(wipeFilesLimit - const Duration(seconds: 1));
      expect(settled, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(settled, isTrue);
    });
  });

  group('the app', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    ProviderContainer container() => ProviderContainer.test(
      overrides: [
        swrCacheProvider.overrideWithValue(cache),
        settingsStoreProvider.overrideWithValue(settings),
        deviceScratchProvider.overrideWithValue(scratch),
      ],
    );

    test('reads its preferences again after a wipe', () async {
      final app = container();
      expect(app.read(selectedPortfolioProvider(testUserId)), 'p1');
      expect(app.read(pendingInvitationProvider), 'invitation.verifier');
      final before = app.read(settingsProvider);

      await app.read(deviceDataWipeProvider).wipe(WipeReason.signedOut);
      expect(app.read(deviceDataWipesProvider), 1);
      expect(app.read(selectedPortfolioProvider(testUserId)), isNull);
      expect(app.read(pendingInvitationProvider), 'invitation.verifier');
      // The display settings survive.
      expect(app.read(settingsProvider), before);
      expect(
        before,
        const AppSettings(
          locale: Locale('ur'),
          themeMode: ThemeMode.dark,
          highContrast: true,
          grouping: DigitGrouping.southAsian,
        ),
      );

      await app.read(deviceDataWipeProvider).wipe(WipeReason.accountDeleted);
      expect(app.read(deviceDataWipesProvider), 2);
      expect(app.read(pendingInvitationProvider), isNull);
    });

    test('drops decoded images when a session ends', () async {
      final image = await _image();
      final key = Object();
      imageCache.putIfAbsent(key, () => _Completer(image));
      expect(imageCache.containsKey(key), isTrue);

      final app = container();
      await app
          .read(deviceDataWipeProvider)
          .atStart(signedInAs: null, photoMayReturn: true);
      expect(imageCache.containsKey(key), isTrue);
      await app.read(deviceDataWipeProvider).wipe(WipeReason.signedOut);
      expect(imageCache.containsKey(key), isFalse);
      image.dispose();
    });

    test('sweeps the shared files each time it comes back', () async {
      final app = container()..listen(deviceTidyOnResumeProvider, (_, _) {});
      final binding = TestWidgetsFlutterBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(scratch.calls, isEmpty);
      binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await app.read(deviceDataWipeProvider).settled;
      expect(asked(), ['sweep']);
      expect(scratch.calls.single.$2.last, isNull);
      // Once the app is closed, nothing listens.
      app.dispose();
      binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(asked(), ['sweep']);
    });

    test('takes the phone from the platform', () {
      expect(
        ProviderContainer.test().read(deviceScratchProvider),
        isA<PluginDeviceScratch>(),
      );
    });
  });
}

/// A one-pixel image, for the image cache.
Future<ui.Image> _image() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
  return recorder.endRecording().toImage(1, 1);
}

/// An image already decoded.
final class _Completer extends ImageStreamCompleter {
  new(ui.Image image) {
    setImage(ImageInfo(image: image));
  }
}
