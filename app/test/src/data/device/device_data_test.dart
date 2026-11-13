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
    await cache.write(testUserId, 'tenants', [
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
    test('orders what each removes', () {
      expect(WipeReason.startedSignedOut.endsSession, isFalse);
      expect(WipeReason.signedOut.endsSession, isTrue);
      expect(WipeReason.accountDeleted.endsSession, isTrue);
      expect(WipeReason.accountDeleted.covers(WipeReason.signedOut), isTrue);
      expect(WipeReason.signedOut.covers(WipeReason.signedOut), isTrue);
      expect(WipeReason.signedOut.covers(WipeReason.accountDeleted), isFalse);
      expect(WipeReason.startedSignedOut.covers(WipeReason.signedOut), isFalse);
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
        ['drainLostPicks'],
        ['discard', '/cache/scaled_lost.jpg'],
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), _now],
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
      // A second call shares the stuck step, within the same limit.
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
        'discard',
        'clearPickerCopies',
        'sweep',
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
        'discard',
        'clearPickerCopies',
        'sweep',
      ]);
      expect(calls()[1], ['discard']);
    });
  });

  group('start-up', () {
    test('signed out, it forgets what an earlier run left of an account, '
        'but not a photo the camera may still bring back', () async {
      await wipe.atStart(signedIn: false, photoMayReturn: true);
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
      await wipe.atStart(signedIn: false, photoMayReturn: false);
      expect(settings.values, {
        ..._display,
        AppSettings.pendingInvitationKey: 'invitation.verifier',
      });
      await wipe.settled;
      expect(calls(), [
        ['drainLostPicks'],
        ['discard', '/cache/scaled_lost.jpg'],
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), _now],
      ]);
    });

    test('signed in, it only tidies the old files', () async {
      await wipe.atStart(signedIn: true, photoMayReturn: true);
      await wipe.settled;
      expect(settings.values, _everything());
      expect(store.values, hasLength(2));
      expect(wiped, isEmpty);
      expect(calls(), [
        ['clearPickerCopies', _now],
        ['sweep', _now.subtract(sharedFileGrace), null],
      ]);
    });

    test('signed in, with no photo to bring back, the camera goes', () async {
      await wipe.atStart(signedIn: true, photoMayReturn: false);
      await wipe.settled;
      expect(
        settings.values,
        {..._everything()}..remove(AppSettings.cameraTargetKey),
      );
      expect(store.values, hasLength(2));
      expect(wiped, isEmpty);
      expect(asked(), [
        'drainLostPicks',
        'discard',
        'clearPickerCopies',
        'sweep',
      ]);
      expect(scratch.calls.last.$2.last, _now);
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
    test('a start-up wipe that keeps the camera does not cover one that '
        'removes it', () async {
      await Future.wait([
        wipe.atStart(signedIn: false, photoMayReturn: true),
        wipe.atStart(signedIn: false, photoMayReturn: false),
      ]);
      expect(wiped, [WipeReason.startedSignedOut, WipeReason.startedSignedOut]);
      expect(settings.values, isNot(contains(AppSettings.cameraTargetKey)));
      await Future.wait([
        wipe.atStart(signedIn: false, photoMayReturn: false),
        wipe.atStart(signedIn: false, photoMayReturn: true),
      ]);
      expect(wiped, hasLength(3));
    });

    test('share the preferences while they are being removed', () async {
      await Future.wait([
        wipe.wipe(WipeReason.accountDeleted),
        wipe.wipe(WipeReason.signedOut),
      ]);
      expect(wiped, [WipeReason.accountDeleted]);
      // A wipe that removes more is not covered by one that removes less.
      await Future.wait([
        wipe.wipe(WipeReason.signedOut),
        wipe.wipe(WipeReason.accountDeleted),
      ]);
      expect(wiped, [
        WipeReason.accountDeleted,
        WipeReason.signedOut,
        WipeReason.accountDeleted,
      ]);
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
      await cache.write('next-user', 'tenants', 1);
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
          .atStart(signedIn: false, photoMayReturn: true);
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
