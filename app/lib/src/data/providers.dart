import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The build configuration; bootstrap provides it.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider is set up in bootstrap'),
);

/// The Supabase client; bootstrap provides it after initialising Supabase.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) =>
      throw UnimplementedError('supabaseClientProvider is set up in bootstrap'),
);

/// The query cache; bootstrap provides it over the platform preferences.
final swrCacheProvider = Provider<SwrCache>(
  (ref) => throw UnimplementedError('swrCacheProvider is set up in bootstrap'),
);
