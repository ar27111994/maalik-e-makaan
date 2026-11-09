import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:mm_core/mm_core.dart';

/// When cached data was saved, in Pakistan time and the app's language:
/// the time alone for today ("10:42 AM"), with the date before ("Nov 5,
/// 10:42 AM"; in Urdu "5 نومبر، 10:42 صبح").
String savedAtLabel(BuildContext context, DateTime savedAt, {DateTime? now}) {
  final locale = Localizations.localeOf(context);
  final local = savedAt.toUtc().add(pakistanUtcOffset);
  final today = CalendarDate.todayInPakistan(now: now);
  final time = timeLabel(context, local);
  if (CalendarDate.fromDateTime(local) == today) return time;
  final comma = locale.languageCode == 'ur' ? '،' : ',';
  return '${DateFormat.MMMd(locale.toLanguageTag()).format(local)}$comma $time';
}
