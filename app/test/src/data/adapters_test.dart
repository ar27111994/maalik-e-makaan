import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('PreferencesStore reads, writes, lists and deletes', () async {
    final store = PreferencesStore(SharedPreferencesAsync());
    await store.write('a', '1');
    await store.write('b', '2');
    expect(await store.read('a'), '1');
    expect(await store.keys(), {'a', 'b'});
    await store.delete('a');
    expect(await store.read('a'), isNull);
  });

  test('PreferencesSettingsStore keeps the settings keys', () async {
    final preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PreferencesSettingsStore.keys,
      ),
    );
    final store = PreferencesSettingsStore(preferences);
    await store.setString(AppSettings.localeKey, 'ur');
    await store.setBool(AppSettings.highContrastKey, value: true);
    expect(store.getString(AppSettings.localeKey), 'ur');
    expect(store.getBool(AppSettings.highContrastKey), isTrue);
    await store.remove(AppSettings.localeKey);
    expect(store.getString(AppSettings.localeKey), isNull);
    expect(AppSettings.read(store).highContrast, isTrue);
  });

  test('the platform providers must be set up by bootstrap', () {
    final container = ProviderContainer.test();
    expect(() => container.read(appConfigProvider), throwsA(anything));
    expect(() => container.read(supabaseClientProvider), throwsA(anything));
    expect(() => container.read(swrCacheProvider), throwsA(anything));
  });
}
