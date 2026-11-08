import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The locale whose date formats [context]'s language uses: Pakistan puts
/// the day first in both languages ("14 Nov 2026"). Flutter has no
/// Pakistani English, so English dates follow Indian English, as the
/// design system's date fields do.
String _dateLocale(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return locale.languageCode == 'en' ? 'en_IN' : locale.toLanguageTag();
}

/// [date] in the app's language: "14 Nov 2026".
String dateLabel(BuildContext context, CalendarDate date) =>
    DateFormat.yMMMd(_dateLocale(context)).format(date.toDateTimeUtc());

/// The moment [at] in Pakistan time and the app's language:
/// "14 Nov 2026, 10:42 AM".
String momentLabel(BuildContext context, DateTime at) {
  final local = at.toUtc().add(pakistanUtcOffset);
  final urdu = Localizations.localeOf(context).languageCode == 'ur';
  return '${DateFormat.yMMMd(_dateLocale(context)).format(local)}'
      '${urdu ? '، ' : ', '}${timeLabel(context, local)}';
}

/// The time of day of [local], a time already in Pakistan: "10:42 AM".
///
/// Urdu's own pattern marks the half of the day with a bare "a" or "p"
/// ("10:42 a"), which reads as a stray letter, so the Urdu UI shows the
/// time as English does, kept left to right inside its sentence.
String timeLabel(BuildContext context, DateTime local) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'ur') {
    return DateFormat.jm(locale.toLanguageTag()).format(local);
  }
  // English puts a narrow no-break space before "AM", which neither app
  // face draws; a plain one becomes a no-break space here.
  final time = DateFormat.jm('en').format(local).replaceAll('\u202F', ' ');
  return MmSemantics.leftToRight(time);
}

/// The month of [period] in the app's language: "November 2026".
String monthLabel(BuildContext context, MonthPeriod period) =>
    DateFormat.yMMMM(_dateLocale(context)).format(period.first.toDateTimeUtc());

/// The Pakistan calendar date of the moment [at].
CalendarDate pakistanDate(DateTime at) =>
    CalendarDate.fromDateTime(at.toUtc().add(pakistanUtcOffset));

/// Today in Pakistan. Screens read it through [today], so tests can fix
/// the day their dates and deadlines are measured from.
final Provider<CalendarDate> todayProvider = Provider.autoDispose<CalendarDate>(
  (ref) => CalendarDate.todayInPakistan(),
);

/// Today in Pakistan, as [todayProvider] says.
CalendarDate today(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false).read(todayProvider);
