import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Starts the app: reads the build configuration, loads the settings, opens
/// the Supabase client and runs [MaalikApp]. A build without a valid
/// configuration shows what is missing instead of crashing.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _reportErrors();

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
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseClientProvider.overrideWithValue(supabase.client),
        settingsStoreProvider.overrideWithValue(
          PreferencesSettingsStore(preferences),
        ),
        swrCacheProvider.overrideWithValue(
          SwrCache(PreferencesStore(SharedPreferencesAsync())),
        ),
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
/// error, so the message names the missing `--dart-define`.
class ConfigErrorApp extends StatelessWidget {
  const new({required this.error, super.key});

  final ConfigException error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This build is not set up',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              SelectableText('${error.variable} ${error.problem}.'),
              const SizedBox(height: 12),
              const SelectableText(
                'Build with --dart-define-from-file=config/<environment>.json '
                '(see app/config/*.example.json).',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
