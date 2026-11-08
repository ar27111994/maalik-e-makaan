import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
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

/// [date] as [dateLabel] writes it, with its day kept beside its month
/// (a no-break space between them): for a date inside a detail line or a
/// sentence, where a line could otherwise break between the day and the
/// month and leave the day beside an amount ("Rs 5,000 · 11" /
/// "Oct 2026"). The year may still go to the next line, so a date never
/// has to break inside a number at large text sizes.
String dateInLine(BuildContext context, CalendarDate date) =>
    dateLabel(context, date).replaceFirst(' ', '\u00A0');

/// The moment [at] in Pakistan time and the app's language:
/// "14 Nov 2026, 10:42 AM".
String momentLabel(BuildContext context, DateTime at) {
  final local = at.toUtc().add(pakistanUtcOffset);
  final urdu = Localizations.localeOf(context).languageCode == 'ur';
  return '${DateFormat.yMMMd(_dateLocale(context)).format(local)}'
      '${urdu ? '، ' : ', '}${timeLabel(context, local)}';
}

/// The time of day of [local], a time already in Pakistan: "10:42 AM" in
/// English, "10:42 صبح" in Urdu.
///
/// Urdu's own pattern in `intl` marks the half of the day with a bare "a"
/// or "p" ("10:42 a"), which reads as a stray letter, and the Latin "AM" is
/// foreign in an Urdu sentence. Urdu names the part of the day instead, as
/// CLDR's flexible day periods for Urdu do (its `Bhm` pattern, "h:mm B"):
/// صبح from 4:00, دوپہر from 12:00, سہ پہر from 16:00, شام from 18:00 and
/// رات from 20:00 to 3:59 ([dayPeriodOf]). No part is longer than twelve
/// hours, so no two times of a day read the same: "10:42 صبح" is 10:42 and
/// "10:42 رات" is 22:42.
///
/// English puts a narrow no-break space before "AM", which neither of the
/// app's faces draws: it is shown as a no-break space.
String timeLabel(BuildContext context, DateTime local) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'ur') {
    return MmSemantics.drawableSpaces(
      DateFormat.jm(locale.toLanguageTag()).format(local),
    );
  }
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return AppLocalizations.of(context)
      .timeOfDay('$hour:$minute', dayPeriodOf(local.hour));
}

/// The part of the day ([AppLocalizations.timeOfDay]'s `period`) the hour
/// [hour] (0 to 23) of the 24-hour clock falls in, after CLDR's day periods
/// for Urdu.
String dayPeriodOf(int hour) => switch (hour) {
  >= 4 && < 12 => 'morning',
  >= 12 && < 16 => 'noon',
  >= 16 && < 18 => 'afternoon',
  >= 18 && < 20 => 'evening',
  _ => 'night',
};

/// The month of [period] in the app's language: "November 2026".
String monthLabel(BuildContext context, MonthPeriod period) =>
    DateFormat.yMMMM(_dateLocale(context)).format(period.first.toDateTimeUtc());

/// The month of [period] in a word, as an axis names it: "Nov".
String shortMonthLabel(BuildContext context, MonthPeriod period) =>
    DateFormat.MMM(_dateLocale(context)).format(period.first.toDateTimeUtc());

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
