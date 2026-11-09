import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';

/// The gallery app: the design system's theme for the chosen mode,
/// contrast and script, English and Urdu localisations, the chosen text
/// size and the chosen digit grouping for every amount.
class GalleryApp extends StatefulWidget {
  const new({
    this.settings = const GallerySettings(),
    this.family = GalleryFamily.actions,
    super.key,
  });

  /// The settings the gallery starts with.
  final GallerySettings settings;

  /// The page the gallery opens on.
  final GalleryFamily family;

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  late final ValueNotifier<GallerySettings> _settings = ValueNotifier(
    widget.settings,
  );

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GallerySettingsScope(
    notifier: _settings,
    child: ValueListenableBuilder(
      valueListenable: _settings,
      builder: (context, settings, _) => MaterialApp(
        title: 'mm_ui gallery',
        debugShowCheckedModeBanner: false,
        theme: MmTheme.data(
          brightness: settings.brightness,
          script: settings.script,
          highContrast: settings.highContrast,
        ),
        locale: settings.locale,
        supportedLocales: const [Locale('en'), Locale('ur')],
        localizationsDelegates: const [
          MmLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(settings.textScale)),
          child: MmFormats(money: settings.money, child: child!),
        ),
        home: GalleryShell(initialFamily: widget.family),
      ),
    ),
  );
}
