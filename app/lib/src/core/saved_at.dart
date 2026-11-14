import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:mm_core/mm_core.dart';

/// When cached data was saved, in Pakistan time and the app's language:
/// the time alone for today ("10:42 AM"), with the date before ("Nov 5,
/// 10:42 AM"; in Urdu "5 نومبر، 10:42 صبح"). It is the reader's own time
/// (when their device last read the data), so a reader whose clocks follow
/// another [zone] sees it beside Pakistan's ([withOwnTime]).
String savedAtLabel(
  BuildContext context,
  DateTime savedAt, {
  DateTime? now,
  TimeZoneId zone = TimeZoneId.pakistan,
}) {
  final locale = Localizations.localeOf(context);
  final local = savedAt.toUtc().add(pakistanUtcOffset);
  final today = CalendarDate.todayInPakistan(now: now);
  final time = timeLabel(context, local);
  final comma = locale.languageCode == 'ur' ? '،' : ',';
  final pakistan = CalendarDate.fromDateTime(local) == today
      ? time
      : '${DateFormat.MMMd(locale.toLanguageTag()).format(local)}$comma $time';
  return withOwnTime(context, pakistan, savedAt, zone);
}
