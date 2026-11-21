import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/data/retry.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Starts the app: reads the build configuration, loads the settings, opens
/// the Supabase client and runs [MaalikApp]. A build without a valid
/// configuration shows what is missing instead of crashing.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _reportErrors();
  // The fonts' and icons' licences, for the licence page in Settings.
  MmLicenses.register();
  // Paths without a `#` on the web, so e-mail links to /auth/callback open
  // that route (the host serves index.html for every path). The fragment is
  // kept: an invitation link carries its token there (/invite#token=…),
  // which browsers never send to a server.
  setUrlStrategy(PathUrlStrategy(BrowserPlatformLocation(), true));

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on ConfigException catch (error) {
    runApp(ConfigErrorApp(error: error));
    return;
  }

  final preferences = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: PreferencesSettingsStore.keys,
    ),
  );
  final supabase = await Supabase.initialize(
    url: config.supabaseUrl.toString(),
    publishableKey: config.supabasePublishableKey,
    // E-mail links are completed by the /auth/callback screen, which shows
    // progress and says why a link failed (AuthRepository.completeEmailLink);
    // the PKCE flow stays the default.
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  final settings = PreferencesSettingsStore(preferences);
  final cache = SwrCache(PreferencesStore(SharedPreferencesAsync()));
  // Supabase has read the stored session by now.
  tidyDeviceAtStart(
    cache,
    settings,
    auth: supabase.client.auth,
    photoMayReturn: lostPhotoMayReturn,
  );

  runApp(
    ProviderScope(
      retry: retryTransientFailures,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(supabase.client),
        settingsStoreProvider.overrideWithValue(settings),
        swrCacheProvider.overrideWithValue(cache),
      ],
      child: const MaalikApp(),
    ),
  );
}

/// Uncaught errors go to the console in debug builds; release builds record
/// them without crashing the app (no third-party crash reporter is used).
void _reportErrors() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };
}

/// Shown when the build was compiled without its settings: a developer
/// error, so the message names the missing `--dart-define`. The title follows
/// the device's language and the brand theme; the technical details stay in
/// English, left to right.
class ConfigErrorApp extends StatelessWidget {
  const new({required this.error, super.key});

  final ConfigException error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    theme: MmTheme.data(brightness: Brightness.light),
    darkTheme: MmTheme.data(brightness: Brightness.dark),
    // The script, and so the font, follows the language the device chose.
    builder: (context, child) => Theme(
      data: MmTheme.data(
        brightness: Theme.of(context).brightness,
        script: MmScript.of(Localizations.localeOf(context)),
      ),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MmSpace.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AppLocalizations.of(context).configErrorTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: MmSpace.s3),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('${error.variable} ${error.problem}.'),
                      const SizedBox(height: MmSpace.s3),
                      const SelectableText(
                        'Build with --dart-define-from-file=config/<environment>.json '
                        '(see app/config/*.example.json).',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
