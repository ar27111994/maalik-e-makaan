import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';

import '../../support/fakes.dart';

ProviderContainer _container(MemorySettingsStore store) =>
    ProviderContainer.test(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );

void main() {
  test('defaults: no language yet, system theme, Western grouping', () {
    final settings = AppSettings.read(MemorySettingsStore());
    expect(settings, const AppSettings());
    expect(settings.languageChosen, isFalse);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.highContrast, isFalse);
    expect(settings.grouping, DigitGrouping.western);
  });

  test('reads stored values and ignores unknown ones', () {
    final settings = AppSettings.read(
      MemorySettingsStore({
        AppSettings.localeKey: 'ur',
        AppSettings.themeKey: 'dark',
        AppSettings.highContrastKey: true,
        AppSettings.groupingKey: 'southAsian',
      }),
    );
    expect(settings.locale, const Locale('ur'));
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.highContrast, isTrue);
    expect(settings.grouping, DigitGrouping.southAsian);

    final unknown = AppSettings.read(
      MemorySettingsStore({
        AppSettings.localeKey: 'fr',
        AppSettings.themeKey: 'sepia',
        AppSettings.groupingKey: 'indian',
      }),
    );
    expect(unknown, const AppSettings());
  });

  test('the controller persists every change', () async {
    final store = MemorySettingsStore();
    final container = _container(store);
    final controller = container.read(settingsProvider.notifier);

    await controller.setLocale(const Locale('ur', 'PK'));
    await controller.setThemeMode(ThemeMode.light);
    await controller.setHighContrast(enabled: true);
    await controller.setGrouping(DigitGrouping.southAsian);

    expect(
      container.read(settingsProvider),
      const AppSettings(
        locale: Locale('ur'),
        themeMode: ThemeMode.light,
        highContrast: true,
        grouping: DigitGrouping.southAsian,
      ),
    );
    expect(store.values, {
      AppSettings.localeKey: 'ur',
      AppSettings.themeKey: 'light',
      AppSettings.highContrastKey: true,
      AppSettings.groupingKey: 'southAsian',
    });
    expect(AppSettings.read(store), container.read(settingsProvider));
  });

  test('any language other than Urdu is stored as English', () async {
    final store = MemorySettingsStore();
    await _container(store)
        .read(settingsProvider.notifier)
        .setLocale(const Locale('pa'));
    expect(store.values[AppSettings.localeKey], 'en');
  });

  test('value equality and copyWith', () {
    const base = AppSettings(locale: Locale('en'));
    expect(base.copyWith(), base);
    expect(base.copyWith().hashCode, base.hashCode);
    expect(base.copyWith(highContrast: true), isNot(base));
    expect(base == Object(), isFalse);
  });

  test('the store must be provided', () {
    final container = ProviderContainer.test();
    expect(() => container.read(settingsProvider), throwsA(anything));
  });
}
