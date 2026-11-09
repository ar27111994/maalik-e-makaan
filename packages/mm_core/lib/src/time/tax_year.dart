import 'package:meta/meta.dart';
import 'package:mm_core/src/time/calendar_date.dart';
import 'package:mm_core/src/time/month_period.dart';

/// A Pakistani income-tax year.
///
/// Under the Income Tax Ordinance, 2001 the normal tax year is the twelve
/// months ending on 30 June and is named after the calendar year in which it
/// ends: **tax year 2026 runs from 1 July 2025 to 30 June 2026**. Rental
/// income summaries and annual reports in the app are grouped by tax year.
@immutable
final class TaxYear implements Comparable<TaxYear> {
  /// The tax year ending on 30 June of [endYear].
  new(this.endYear) {
    if (endYear < 2 || endYear > 9999) {
      throw ArgumentError.value(endYear, 'endYear', 'must be within 2..9999');
    }
  }

  /// The tax year that contains [date].
  factory containing(CalendarDate date) =>
      TaxYear(date.month >= startMonth ? date.year + 1 : date.year);

  /// The month (July) in which every tax year starts.
  static const int startMonth = 7;

  /// The calendar year in which this tax year ends (e.g. 2026).
  final int endYear;

  /// 1 July of the previous calendar year.
  CalendarDate get start => CalendarDate(endYear - 1, startMonth, 1);

  /// 30 June of [endYear].
  CalendarDate get end => CalendarDate(endYear, 6, 30);

  /// The twelve months of the tax year, July through June.
  List<MonthPeriod> get months =>
      MonthPeriod.range(MonthPeriod.of(start), MonthPeriod.of(end));

  /// The following tax year.
  TaxYear get next => TaxYear(endYear + 1);

  /// The preceding tax year.
  TaxYear get previous => TaxYear(endYear - 1);

  /// Whether [date] falls within this tax year.
  bool contains(CalendarDate date) =>
      date.isOnOrAfter(start) && date.isOnOrBefore(end);

  /// Short label, e.g. `TY2026`.
  String get label => 'TY$endYear';

  /// Span label, e.g. `2025-26`.
  String get spanLabel =>
      '${endYear - 1}-${(endYear % 100).toString().padLeft(2, '0')}';

  @override
  int compareTo(TaxYear other) => endYear.compareTo(other.endYear);

  @override
  bool operator ==(Object other) =>
      other is TaxYear && other.endYear == endYear;

  @override
  int get hashCode => endYear.hashCode;

  @override
  String toString() => label;
}
