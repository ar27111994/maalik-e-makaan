import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mm_core/mm_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous preference reads (cached at start), so the first frame
/// already has the language, theme and number style.
abstract interface class SettingsStore {
  String? getString(String key);
  bool? getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, {required bool value});
  Future<void> remove(String key);
}

/// [SettingsStore] over the platform preferences.
final class PreferencesSettingsStore implements SettingsStore {
  new(this._preferences);

  /// The preference keys the app reads at start.
  static const Set<String> keys = {
    AppSettings.localeKey,
    AppSettings.themeKey,
    AppSettings.highContrastKey,
    AppSettings.groupingKey,
  };

  final SharedPreferencesWithCache _preferences;

  @override
  String? getString(String key) => _preferences.getString(key);

  @override
  bool? getBool(String key) => _preferences.getBool(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> setBool(String key, {required bool value}) =>
      _preferences.setBool(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// The landlord's display preferences. They belong to the device (they are
/// kept after signing out); the language is also saved to the profile.
@immutable
final class AppSettings {
  const new({
    this.locale,
    this.themeMode = ThemeMode.system,
    this.highContrast = false,
    this.grouping = DigitGrouping.western,
  });

  factory read(SettingsStore store) => AppSettings(
    locale: switch (store.getString(localeKey)) {
      'en' => const Locale('en'),
      'ur' => const Locale('ur'),
      _ => null,
    },
    themeMode:
        ThemeMode.values.asNameMap()[store.getString(themeKey)] ??
        ThemeMode.system,
    highContrast: store.getBool(highContrastKey) ?? false,
    grouping:
        DigitGrouping.values.asNameMap()[store.getString(groupingKey)] ??
        DigitGrouping.western,
  );

  static const localeKey = 'mm.settings.locale';
  static const themeKey = 'mm.settings.theme';
  static const highContrastKey = 'mm.settings.high_contrast';
  static const groupingKey = 'mm.settings.grouping';

  /// The chosen language; null until it is picked on first launch.
  final Locale? locale;

  final ThemeMode themeMode;

  /// High-contrast colours, on top of the platform's own setting.
  final bool highContrast;

  /// Western (1,250,000) or lakh/crore (12,50,000) digit grouping.
  final DigitGrouping grouping;

  bool get languageChosen => locale != null;

  AppSettings copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? highContrast,
    DigitGrouping? grouping,
  }) => AppSettings(
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    grouping: grouping ?? this.grouping,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.locale == locale &&
      other.themeMode == themeMode &&
      other.highContrast == highContrast &&
      other.grouping == grouping;

  @override
  int get hashCode => Object.hash(locale, themeMode, highContrast, grouping);
}

/// The preference store; bootstrap overrides it with the platform one.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) =>
      throw UnimplementedError('settingsStoreProvider is set up in bootstrap'),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Reads and changes [AppSettings], persisting every change.
final class SettingsController extends Notifier<AppSettings> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  AppSettings build() => AppSettings.read(ref.watch(settingsStoreProvider));

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode == 'ur' ? 'ur' : 'en';
    state = state.copyWith(locale: Locale(code));
    await _store.setString(AppSettings.localeKey, code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.setString(AppSettings.themeKey, mode.name);
  }

  Future<void> setHighContrast({required bool enabled}) async {
    state = state.copyWith(highContrast: enabled);
    await _store.setBool(AppSettings.highContrastKey, value: enabled);
  }

  Future<void> setGrouping(DigitGrouping grouping) async {
    state = state.copyWith(grouping: grouping);
    await _store.setString(AppSettings.groupingKey, grouping.name);
  }
}
