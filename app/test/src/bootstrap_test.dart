import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/bootstrap.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('a build without its settings explains what is missing', (
    tester,
  ) async {
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;
    });

    // Tests are compiled without --dart-define, so the configuration fails.
    await bootstrap();
    await tester.pumpAndSettle();
    expect(find.text('This build is not set up'), findsOneWidget);
    expect(find.text('SUPABASE_URL is required.'), findsOneWidget);
    expect(find.textContaining('--dart-define-from-file'), findsOneWidget);

    // Uncaught errors are reported, not fatal.
    expect(
      PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty),
      isTrue,
    );
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('y')));
  });

  testWidgets('a configured build tidies the device for the session Supabase '
      'read, then runs the app over the same stores', (tester) async {
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    // Off a phone the device's scratch has no files to touch.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    // Supabase keeps its session here: none is stored.
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'mm.swr.v2.earlier-user.own.portfolios':
              '{"saved_at":"2026-11-01T00:00:00Z","value":[]}',
          AppSettings.currentPortfolioKey: 'earlier-user/p1',
          AppSettings.localeKey: 'en',
        });
    final config = AppConfig.parse({
      'SUPABASE_URL': 'https://abcdefgh.supabase.co',
      'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_abc123',
      'APP_URL': 'https://app.maalikemakaan.pk',
    });

    await bootstrap(readConfig: () => config);
    try {
      await tester.pumpAndSettle();

      // Nobody is signed in: what the earlier account left goes, and the
      // device's language stays (`tidyDeviceAtStart`).
      expect(await SharedPreferencesAsync().getKeys(), {AppSettings.localeKey});
      // The app reads the same stores: the language chosen, so sign-in.
      expect(find.text('Sign in'), findsWidgets);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaalikApp)),
      );
      expect(container.read(appConfigProvider), same(config));
      expect(
        container.read(supabaseClientProvider),
        same(Supabase.instance.client),
      );
      expect(
        container.read(settingsStoreProvider),
        isA<PreferencesSettingsStore>(),
      );
      final cache = container.read(swrCacheProvider);
      expect(cache.store, isA<PreferencesStore>());
      // The one the start-up wipe cleared, which started its first epoch.
      expect(cache.epoch, 1);
    } finally {
      // Before a failure is reported: the test's own handlers report it.
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;
      debugDefaultTargetPlatformOverride = null;
      await _disposeSupabase(tester);
    }
  });

  testWidgets('on an Urdu device the title is Urdu, the details stay LTR', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ur')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      ConfigErrorApp(error: ConfigException('APP_URL', 'is required')),
    );
    await tester.pumpAndSettle();
    final title = find.text('یہ بلڈ سیٹ اپ نہیں');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    final details = find.text('APP_URL is required.');
    expect(Directionality.of(tester.element(details)), TextDirection.ltr);
    expect(
      tester.getSemantics(title),
      matchesSemantics(label: 'یہ بلڈ سیٹ اپ نہیں', isHeader: true),
    );
  });
}

/// Disposes the Supabase client [bootstrap] opened. It decodes on an
/// isolate of its own, whose port keeps the test running until the client
/// is disposed, and whose answers come in real time while the test's
/// clock is fake: so the two take turns.
Future<void> _disposeSupabase(WidgetTester tester) async {
  var disposed = false;
  unawaited(Supabase.instance.dispose().whenComplete(() => disposed = true));
  for (var turn = 0; turn < 100 && !disposed; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(disposed, isTrue);
}
