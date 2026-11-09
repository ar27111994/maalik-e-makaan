import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_urdu_material_localizations.dart';

/// Gives [child] the date conventions of Pakistan: the day before the
/// month in both languages ("5 Nov 2026", "5 نومبر، 2026"), dates typed
/// day first (05/11/2026 is 5 November), and calendar weeks that start on
/// Sunday.
///
/// Material formats and pickers dates through `MaterialLocalizations`,
/// and its plain English ones are American: "Nov 5, 2026", typed
/// mm/dd/yyyy, so a landlord who types 05/11/2026 would record 11 May.
/// Flutter has no Pakistani English, so in English this subtree takes the
/// formats of Indian English ([forLocale]), which follow the same
/// conventions as Pakistan and as the Urdu formats: the day first, typed
/// d/M/y, weeks from Sunday. (British English also puts the day first, but
/// starts its weeks on Monday, unlike the Urdu calendar beside it.) Urdu
/// keeps its own formats, but its date picker heads its columns with Urdu
/// day names ([MmUrduMaterialLocalizations]) instead of the English initials
/// Flutter gives Urdu. The locale is internal: no screen shows its name.
///
/// Wrap what formats a date with `MaterialLocalizations.of(context)`
/// (`formatShortDate`, `formatFullDate` and the like), and pass
/// `locale: MmDateLocale.forLocale(...)` to `showDatePicker`. The subtree
/// keeps the app's language, direction and every other localisation the
/// app registered for it.
///
/// ```dart
/// MmDateLocale(
///   child: Builder(
///     builder: (context) => Text(
///       MaterialLocalizations.of(context).formatShortDate(paidOn),
///     ),
///   ),
/// )
/// ```
///
/// Internal to mm_ui: any component family may use it.
class MmDateLocale extends StatelessWidget {
  /// Gives [child] Pakistan's date conventions.
  const new({required this.child, super.key});

  /// The locale whose Material date formats a screen in [locale] uses:
  /// Indian English for English, [locale] itself otherwise.
  static Locale forLocale(Locale locale) =>
      locale.languageCode == 'en' ? const Locale('en', 'IN') : locale;

  /// The subtree that formats dates.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final dates = forLocale(locale);
    if (locale.languageCode == 'ur') {
      // A date picker opened from here takes its localisations from this
      // subtree's delegates, so it gets the Urdu day names too.
      final material = MaterialLocalizations.of(context);
      return Localizations.override(
        context: context,
        delegates: [
          MmUrduMaterialLocalizationsDelegate(
            material is MmUrduMaterialLocalizations ? material.base : material,
            WidgetsLocalizations.of(context),
          ),
        ],
        child: child,
      );
    }
    if (dates == locale) return child;
    return Localizations.override(
      context: context,
      locale: dates,
      child: child,
    );
  }
}
