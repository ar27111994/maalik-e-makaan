// Reproduction of a review finding (Greptile P1, device_data.dart 353-361):
// a cache whose clear never answers blocks the rest of the preferences step,
// and the stuck step then swallows every later covered wipe. Not committed.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

import '../../../support/fakes.dart';

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

const _display = <String, Object>{
  AppSettings.localeKey: 'ur',
  AppSettings.themeKey: 'dark',
  AppSettings.highContrastKey: true,
  AppSettings.groupingKey: 'southAsian',
};

Map<String, Object> _everything() => {
  ..._display,
  AppSettings.currentPortfolioKey: '$testUserId/p1',
  AppSettings.cameraTargetKey: '{"user":"$testUserId"}',
  AppSettings.pendingInvitationKey: 'invitation.verifier',
};

final _now = DateTime.utc(2026, 11, 13, 9);

void main() {
  late MemorySettingsStore settings;
  late FakeDeviceScratch scratch;
  late List<WipeReason> wiped;

  setUp(() {
    settings = MemorySettingsStore(_everything());
    scratch = FakeDeviceScratch();
    wiped = [];
  });

  List<Object?> sweeps() => [
    for (final call in scratch.calls)
      if (call.$1 == 'sweep') call.$2.last,
  ];

  group('a cache that never answers (repro)', () {
    testWidgets('the other preferences and the in-memory wipe still happen', (
      tester,
    ) async {
      final stuck = DeviceDataWipe(
        cache: SwrCache(_HangingStore()),
        settings: settings,
        scratch: scratch,
        onWiped: wiped.add,
        clock: () => _now,
      );
      var done = false;
      unawaited(stuck.wipe(WipeReason.accountDeleted).then((_) => done = true));
      await tester.pump(wipePreferencesLimit);
      // The bounded wipe has returned to the sign-out.
      expect(done, isTrue);
      // The account's preferences are independent of the cache: they go.
      expect(settings.values, _display);
      // State kept in memory is told.
      expect(wiped, [WipeReason.accountDeleted]);
    });

    testWidgets(
      'a later covered wipe still makes its own pass over the files',
      (tester) async {
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
        // The next account signs in, photographs a document, and signs out
        // long after the first wipe returned.
        time = _now.add(const Duration(minutes: 3));
        unawaited(stuck.wipe(WipeReason.signedOut));
        await tester.pump(wipePreferencesLimit);
        expect(sweeps(), [_now, time]);
      },
    );

    testWidgets("a later covered wipe still removes the next account's "
        'preferences', (tester) async {
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
      // The next account signs in and chooses a portfolio, and signs out.
      await settings.setString(AppSettings.currentPortfolioKey, 'next/p2');
      time = _now.add(const Duration(minutes: 3));
      unawaited(stuck.wipe(WipeReason.signedOut));
      await tester.pump(wipePreferencesLimit);
      expect(settings.values, isNot(contains(AppSettings.currentPortfolioKey)));
    });
  });
}
