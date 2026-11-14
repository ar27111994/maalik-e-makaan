import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/place_names.dart';
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
  return '${DateFormat.yMMMd(_dateLocale(context)).format(local)}'
      '${_comma(context)}${timeLabel(context, local)}';
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

/// [date] with its day and month only, day first, in the app's language:
/// "6 Nov" ("6 نومبر").
String shortDateLabel(BuildContext context, CalendarDate date) =>
    DateFormat.MMMd(_dateLocale(context)).format(date.toDateTimeUtc());

/// What [zone]'s clocks read at [at], when they read differently from
/// Pakistan's; else null (Pakistan itself, another UTC+05:00 zone such as
/// Tashkent, or a zone this build does not know).
LocalDateTime? _ownClock(DateTime at, TimeZoneId zone) {
  if (!zone.isKnown) return null;
  return DualTime.at(at, own: zone).own?.local;
}

/// [local] as a [DateTime] whose fields read the same, for the formatters.
DateTime _wall(LocalDateTime local) => DateTime.utc(
  local.date.year,
  local.date.month,
  local.date.day,
  local.hour,
  local.minute,
  local.second,
);

/// The moment [at] for its reader, whose own clocks follow [zone]: in
/// Pakistan time, and in [zone] beside it when the two clocks differ, the
/// Pakistan side first and the reader's named by its city (Q6): "7 Nov
/// 2026, 10:00 AM Pakistan time (5:00 AM London)". The reader's side
/// carries its date when it falls on another day ("6 Nov, 11:00 PM"). For
/// a reader whose clocks read Pakistan's, exactly [momentLabel].
///
/// For the reader's own times: their notifications, when their reminders
/// were sent, when this device last read the data.
String dualMomentLabel(BuildContext context, DateTime at, TimeZoneId zone) =>
    withOwnTime(context, momentLabel(context, at), at, zone);

/// [pakistan], the moment [at] as Pakistan's clocks read it, with [zone]'s
/// time beside it when that zone's clocks read differently (see
/// [dualMomentLabel]); else [pakistan] itself.
String withOwnTime(
  BuildContext context,
  String pakistan,
  DateTime at,
  TimeZoneId zone,
) {
  final own = _ownClock(at, zone);
  if (own == null) return pakistan;
  final time = timeLabel(context, _wall(own));
  final text = own.date == pakistanDate(at)
      ? time
      : '${shortDateLabel(context, own.date)}${_comma(context)}$time';
  return AppLocalizations.of(context)
      .dualTime(pakistan, text, cityName(context, zone));
}

/// The time of day of [at] for its reader, as [dualMomentLabel] writes it
/// but without dates: "8:00 AM Pakistan time (3:00 AM London)".
String dualTimeLabel(BuildContext context, DateTime at, TimeZoneId zone) {
  final pakistan = timeLabel(context, at.toUtc().add(pakistanUtcOffset));
  final own = _ownClock(at, zone);
  if (own == null) return pakistan;
  return AppLocalizations.of(
    context,
  ).dualTime(pakistan, timeLabel(context, _wall(own)), cityName(context, zone));
}

/// A moment that belongs to Pakistan's clock (a deadline, when a record
/// was made), said to be Pakistan time for a reader whose own clocks
/// ([zone]) read differently: "14 Nov 2026, 10:42 AM Pakistan time". For
/// anyone else, exactly [momentLabel].
String pakistanMomentLabel(BuildContext context, DateTime at, TimeZoneId zone) {
  final moment = momentLabel(context, at);
  return _ownClock(at, zone) == null
      ? moment
      : AppLocalizations.of(context).inPakistanTime(moment);
}

/// The comma between a date and a time in the app's language.
String _comma(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ur' ? '، ' : ', ';

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

/// Now, as an instant in UTC: for the reminders' etiquette, when a
/// question may be asked again, and the person's own time beside Pakistan
/// time. Tests fix it.
final Provider<DateTime Function()> nowProvider = Provider(
  (ref) =>
      () => clock.now().toUtc(),
);
