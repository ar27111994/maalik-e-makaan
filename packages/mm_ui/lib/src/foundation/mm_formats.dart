import 'package:flutter/widgets.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';

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

  /// [amount] as a screen reader should say it in [format]: the plain
  /// number without grouping, with paisa only when [format] shows them
  /// ("125000", "1500.50", "-5000"). Grouped figures such as 1,25,000 are
  /// read out unreliably.
  static String spokenNumber(Money amount, MoneyFormat format) {
    final shown = format.paisa == PaisaDisplay.never
        ? amount.roundToRupee()
        : amount;
    return shown.hasPaisa ? shown.toDecimalString() : '${shown.wholeRupees}';
  }

  /// [amount] as a screen reader should say it, followed by the currency's
  /// name in the ambient language: "125000 rupees", "125000 روپے". The
  /// number follows [format], or [moneyOf] the context when it is null.
  ///
  /// Use it as the semantics label of an amount shown with [moneyOf]'s
  /// format, so screen readers hear one figure instead of its groups.
  ///
  /// ```dart
  /// Semantics(
  ///   label: MmFormats.spokenMoney(context, lease.rent),
  ///   excludeSemantics: true,
  ///   child: Text(MmFormats.moneyOf(context).format(lease.rent)),
  /// )
  /// ```
  static String spokenMoney(
    BuildContext context,
    Money amount, {
    MoneyFormat? format,
  }) {
    final number = spokenNumber(amount, format ?? moneyOf(context));
    return '$number ${MmLocalizations.of(context).rupees}';
  }

  @override
  bool updateShouldNotify(MmFormats oldWidget) => money != oldWidget.money;
}
