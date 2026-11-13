import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/routing/app_router.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The localisation delegates of the app: its own strings, the design
/// system's, and Flutter's (Material dialogs, date pickers) in both languages.
const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  AppLocalizations.delegate,
  MmLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The root widget: themes, language, number style and routing all follow
/// the landlord's settings.
class MaalikApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    // Files shared ten minutes ago or more go when the app comes back.
    ref.watch(deviceTidyOnResumeProvider);
    final locale = settings.locale;
    // Until a language is chosen, the first-launch screen shows in English
    // with both choices written in their own script.
    final script = MmScript.of(locale ?? const Locale('en'));
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale ?? const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      themeMode: settings.themeMode,
      theme: MmTheme.data(
        brightness: Brightness.light,
        script: script,
        highContrast: settings.highContrast,
      ),
      darkTheme: MmTheme.data(
        brightness: Brightness.dark,
        script: script,
        highContrast: settings.highContrast,
      ),
      highContrastTheme: MmTheme.data(
        brightness: Brightness.light,
        script: script,
        highContrast: true,
      ),
      highContrastDarkTheme: MmTheme.data(
        brightness: Brightness.dark,
        script: script,
        highContrast: true,
      ),
      builder: (context, child) => MmFormats(
        money: MoneyFormat(
          grouping: settings.grouping,
          language: script == MmScript.urdu
              ? MoneyLanguage.urdu
              : MoneyLanguage.english,
        ),
        child: child!,
      ),
    );
  }
}
