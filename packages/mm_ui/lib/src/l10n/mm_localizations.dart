import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The words mm_ui's components show or announce on their own: labels of
/// built-in actions (retry, close, show password) and accessibility labels.
///
/// Everything a screen says about the landlord's data comes from the app's
/// own localisations and is passed in; this class only covers what a
/// component adds by itself, in English and Urdu.
///
/// Add [MmLocalizations.delegate] to the app's `localizationsDelegates`.
/// Without it, components fall back to English.
enum MmLocalizations {
  /// English.
  english(
    retry: 'Try again',
    close: 'Close',
    cancel: 'Cancel',
    dismiss: 'Dismiss',
    showPassword: 'Show password',
    hidePassword: 'Hide password',
    showFullCnic: 'Show full CNIC',
    hideFullCnic: 'Hide CNIC',
    clearText: 'Clear',
    search: 'Search',
    loading: 'Loading',
    requiredField: 'Required',
    optionalField: 'Optional',
    moreOptions: 'More options',
    chooseDate: 'Choose a date',
    openNavigation: 'Open navigation menu',
    showAsTable: 'Show as a table',
    showAsChart: 'Show as a chart',
    copied: 'Copied',
    rupees: 'rupees',
  ),

  /// Urdu.
  urdu(
    retry: 'دوبارہ کوشش کریں',
    close: 'بند کریں',
    cancel: 'منسوخ کریں',
    dismiss: 'ہٹائیں',
    showPassword: 'پاس ورڈ دکھائیں',
    hidePassword: 'پاس ورڈ چھپائیں',
    showFullCnic: 'پورا شناختی کارڈ نمبر دکھائیں',
    hideFullCnic: 'شناختی کارڈ نمبر چھپائیں',
    clearText: 'صاف کریں',
    search: 'تلاش کریں',
    loading: 'لوڈ ہو رہا ہے',
    requiredField: 'لازمی',
    optionalField: 'اختیاری',
    moreOptions: 'مزید اختیارات',
    chooseDate: 'تاریخ منتخب کریں',
    openNavigation: 'نیویگیشن مینیو کھولیں',
    showAsTable: 'جدول کی شکل میں دکھائیں',
    showAsChart: 'چارٹ کی شکل میں دکھائیں',
    copied: 'کاپی ہو گیا',
    rupees: 'روپے',
  );

  new({
    required this.retry,
    required this.close,
    required this.cancel,
    required this.dismiss,
    required this.showPassword,
    required this.hidePassword,
    required this.showFullCnic,
    required this.hideFullCnic,
    required this.clearText,
    required this.search,
    required this.loading,
    required this.requiredField,
    required this.optionalField,
    required this.moreOptions,
    required this.chooseDate,
    required this.openNavigation,
    required this.showAsTable,
    required this.showAsChart,
    required this.copied,
    required this.rupees,
  });

  /// The delegate that loads these strings for English and Urdu.
  static const LocalizationsDelegate<MmLocalizations> delegate =
      _MmLocalizationsDelegate();

  /// The languages these strings exist in.
  static const supportedLanguages = {'en', 'ur'};

  /// The strings for [locale]: Urdu for `ur`, English otherwise.
  static MmLocalizations forLocale(Locale locale) =>
      locale.languageCode == 'ur' ? urdu : english;

  /// The strings of the nearest [Localizations], or English when the app
  /// did not register [delegate].
  static MmLocalizations of(BuildContext context) =>
      Localizations.of<MmLocalizations>(context, MmLocalizations) ?? english;

  /// Label of a retry action.
  final String retry;

  /// Label of an action that closes a sheet, dialog or banner.
  final String close;

  /// Label of an action that abandons a dialog without changing anything.
  final String cancel;

  /// Label of an action that dismisses a notice.
  final String dismiss;

  /// Accessibility label of the button that reveals a password.
  final String showPassword;

  /// Accessibility label of the button that hides a revealed password.
  final String hidePassword;

  /// Accessibility label of the button that reveals a masked CNIC.
  final String showFullCnic;

  /// Accessibility label of the button that masks a revealed CNIC.
  final String hideFullCnic;

  /// Accessibility label of the button that empties a field.
  final String clearText;

  /// Label and hint of search fields.
  final String search;

  /// Announced while content loads.
  final String loading;

  /// Marks a required field.
  final String requiredField;

  /// Marks an optional field.
  final String optionalField;

  /// Accessibility label of an overflow menu button.
  final String moreOptions;

  /// Accessibility label of a date field's picker button.
  final String chooseDate;

  /// Accessibility label of the button that opens the navigation drawer.
  final String openNavigation;

  /// Label of the toggle that shows a chart's data as a table.
  final String showAsTable;

  /// Label of the toggle that shows a table's data as a chart again.
  final String showAsChart;

  /// Announced after a value is copied to the clipboard.
  final String copied;

  /// The currency's name as a screen reader should say it after a plain
  /// number ("125000 rupees"), since grouped figures such as 1,25,000 are
  /// read out unreliably.
  final String rupees;
}

final class _MmLocalizationsDelegate
    extends LocalizationsDelegate<MmLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) =>
      MmLocalizations.supportedLanguages.contains(locale.languageCode);

  @override
  Future<MmLocalizations> load(Locale locale) =>
      SynchronousFuture(MmLocalizations.forLocale(locale));

  @override
  bool shouldReload(_MmLocalizationsDelegate old) => false;
}
