import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mm_core/mm_core.dart';

/// When cached data was saved, in Pakistan time and the app's language:
/// the time alone for today ("10:42 AM"), with the date before ("5 Nov,
/// 10:42 AM").
String savedAtLabel(BuildContext context, DateTime savedAt, {DateTime? now}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final local = savedAt.toUtc().add(pakistanUtcOffset);
  final today = CalendarDate.todayInPakistan(now: now);
  final time = DateFormat.jm(locale).format(local);
  if (CalendarDate.fromDateTime(local) == today) return time;
  return '${DateFormat.MMMd(locale).format(local)}, $time';
}
