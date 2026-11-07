import 'package:flutter/widgets.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The component families, one gallery page each, in navigation order.
enum GalleryFamily {
  actions,
  inputs,
  choices,
  display,
  records,
  feedback,
  layout,
  charts;

  /// The family named [name] (`charts`), or null.
  static GalleryFamily? named(String? name) {
    for (final family in values) {
      if (family.name == name) return family;
    }
    return null;
  }
}

/// The text sizes the gallery offers: 100%, 150% and 200%.
const galleryTextScales = [1.0, 1.5, 2.0];

/// How the gallery is shown: mode, contrast, language, text size and digit
/// grouping. Testers change it from the display settings sheet; the web
/// build also reads it from the address (`?lang=ur&theme=dark&page=charts`).
@immutable
final class GallerySettings {
  const new({
    this.brightness = Brightness.light,
    this.highContrast = false,
    this.locale = const Locale('en'),
    this.textScale = 1,
    this.grouping = DigitGrouping.southAsian,
  });

  /// The settings an address asks for. Unknown or missing values keep the
  /// defaults: `theme` (`light`, `dark`), `contrast` (`high`), `lang`
  /// (`en`, `ur`), `text` (`100`, `150`, `200`) and `grouping` (`lakh`,
  /// `western`).
  factory fromQuery(Map<String, String> query) {
    final percent = int.tryParse(query['text'] ?? '');
    final scale = percent == null ? null : percent / 100;
    return GallerySettings(
      brightness: query['theme'] == 'dark' ? Brightness.dark : Brightness.light,
      highContrast: query['contrast'] == 'high',
      locale: Locale(query['lang'] == 'ur' ? 'ur' : 'en'),
      textScale: galleryTextScales.contains(scale) ? scale! : 1,
      grouping: query['grouping'] == 'western'
          ? DigitGrouping.western
          : DigitGrouping.southAsian,
    );
  }

  final Brightness brightness;
  final bool highContrast;
  final Locale locale;
  final double textScale;
  final DigitGrouping grouping;

  /// The script of [locale]: Nastaliq for Urdu.
  MmScript get script => MmScript.of(locale);

  /// The money format every amount in the gallery follows.
  MoneyFormat get money => MoneyFormat(
    grouping: grouping,
    language: script == MmScript.urdu
        ? MoneyLanguage.urdu
        : MoneyLanguage.english,
  );

  GallerySettings copyWith({
    Brightness? brightness,
    bool? highContrast,
    Locale? locale,
    double? textScale,
    DigitGrouping? grouping,
  }) => GallerySettings(
    brightness: brightness ?? this.brightness,
    highContrast: highContrast ?? this.highContrast,
    locale: locale ?? this.locale,
    textScale: textScale ?? this.textScale,
    grouping: grouping ?? this.grouping,
  );

  @override
  bool operator ==(Object other) =>
      other is GallerySettings &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.locale == locale &&
      other.textScale == textScale &&
      other.grouping == grouping;

  @override
  int get hashCode =>
      Object.hash(brightness, highContrast, locale, textScale, grouping);
}

/// Gives the gallery's pages the settings and a way to change them.
class GallerySettingsScope
    extends InheritedNotifier<ValueNotifier<GallerySettings>> {
  const new({
    required ValueNotifier<GallerySettings> super.notifier,
    required super.child,
    super.key,
  });

  /// The settings notifier above [context].
  static ValueNotifier<GallerySettings> of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GallerySettingsScope>()!
      .notifier!;
}
