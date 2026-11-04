import 'package:flutter/widgets.dart';
import 'package:mm_core/mm_core.dart';

/// How a subtree formats rupee amounts, set once by the app from the
/// landlord's settings (Western or lakh/crore grouping) and language.
///
/// Components that show money (`MmAmount`, stat tiles, charts, money fields)
/// read it with [MmFormats.moneyOf], so one setting changes every amount on
/// every screen.
class MmFormats extends InheritedWidget {
  /// Provides [money] to [child].
  const new({required this.money, required super.child, super.key});

  /// The money format of this subtree.
  final MoneyFormat money;

  /// The default format for [locale]: Western grouping, `Rs` (English) or
  /// `روپے` (Urdu), paisa only when present, Western digits (amounts are set
  /// in the Latin face in both languages).
  static MoneyFormat defaultFor(Locale locale) => MoneyFormat(
    language: locale.languageCode == 'ur'
        ? MoneyLanguage.urdu
        : MoneyLanguage.english,
  );

  /// The money format of the nearest [MmFormats], or [defaultFor] the
  /// ambient locale when there is none.
  static MoneyFormat moneyOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MmFormats>()?.money ??
      defaultFor(Localizations.maybeLocaleOf(context) ?? const Locale('en'));

  @override
  bool updateShouldNotify(MmFormats oldWidget) => money != oldWidget.money;
}
