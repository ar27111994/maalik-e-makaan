import 'package:mm_core/src/money/money.dart';
import 'package:mm_core/src/time/calendar_date.dart';
import 'package:mm_core/src/time/date_range.dart';
import 'package:mm_core/src/time/month_period.dart';

/// The granularity a rent is rounded to after an increment.
///
/// Rents in Pakistan are quoted in round figures; a 10% increment on
/// Rs 47,300 is normally agreed as Rs 52,000 rather than Rs 52,030.
enum RentRounding {
  /// Keep the exact amount (rounded to whole rupees).
  none(1),

  /// Nearest Rs 10.
  nearest10(10),

  /// Nearest Rs 50.
  nearest50(50),

  /// Nearest Rs 100 (the default).
  nearest100(100),

  /// Nearest Rs 500.
  nearest500(500),

  /// Nearest Rs 1,000.
  nearest1000(1000);

  new(this.stepRupees);

  /// Size of one rounding step in rupees.
  final int stepRupees;
}

/// Pure rent calculations shared by the app's previews.
///
/// The database performs the authoritative versions of these calculations
/// when it generates charges; both sides are tested against the same
/// contract vectors (`contracts/rent_math_vectors.json`) so a preview never
/// disagrees with the ledger.
abstract final class RentMath {
  /// The due date of [period] for a lease whose rent falls due on day
  /// [dueDay] of each month; clamped to the month's length.
  static CalendarDate dueDate(MonthPeriod period, int dueDay) {
    if (dueDay < 1 || dueDay > 31) {
      throw ArgumentError.value(dueDay, 'dueDay', 'must be within 1..31');
    }
    return period.dayClamped(dueDay);
  }

  /// The due date of a billed month: [dueDate], but never before the day
  /// billing starts — a tenant who moves in on the 15th is not due on the 5th.
  /// Mirrors the database's generated rent charges.
  static CalendarDate billingDueDate(
    MonthPeriod period,
    int dueDay,
    CalendarDate billingStartsOn,
  ) => CalendarDate.max(dueDate(period, dueDay), billingStartsOn);

  /// Number of days of [period] covered by [occupancy].
  static int occupiedDays(MonthPeriod period, DateRange occupancy) {
    final overlap = DateRange(
      period.first,
      period.last,
    ).intersection(occupancy);
    return overlap?.lengthInDays ?? 0;
  }

  /// Rent payable for [period] when the tenancy [occupancy] covers only part
  /// of the month: `monthlyRent × occupiedDays ÷ daysInMonth`, rounded
  /// half-up to whole rupees. A fully-occupied month returns [monthlyRent].
  static Money proratedRent({
    required Money monthlyRent,
    required MonthPeriod period,
    required DateRange occupancy,
  }) {
    final days = occupiedDays(period, occupancy);
    if (days == period.lengthInDays) return monthlyRent;
    if (days == 0) return Money.zero;
    // One rounding, half-up to whole rupees — identical to the database's
    // app.prorated_rent (verified by the shared contract vectors).
    return monthlyRent.multiplyToStep(days, period.lengthInDays);
  }

  /// The rent after an increment of [basisPoints] (10% = 1000), rounded to
  /// [rounding]. Rounding is half-up.
  static Money incrementedRent(
    Money currentRent, {
    required int basisPoints,
    RentRounding rounding = RentRounding.nearest100,
  }) {
    if (basisPoints < 0) {
      throw ArgumentError.value(basisPoints, 'basisPoints', 'must be >= 0');
    }
    return currentRent.multiplyToStep(
      10000 + basisPoints,
      10000,
      stepRupees: rounding.stepRupees,
    );
  }

  /// The first anniversary of [leaseStart] (every [intervalMonths]) that is
  /// on or after [asOf]. Before the first anniversary this is
  /// `leaseStart + intervalMonths`.
  static CalendarDate nextAnniversary(
    CalendarDate leaseStart,
    CalendarDate asOf, {
    int intervalMonths = 12,
  }) {
    if (intervalMonths <= 0) {
      throw ArgumentError.value(
        intervalMonths,
        'intervalMonths',
        'must be > 0',
      );
    }
    var cycles = 1;
    if (asOf.isAfter(leaseStart)) {
      final monthsElapsed = MonthPeriod.of(asOf)
          .monthsSince(MonthPeriod.of(leaseStart));
      cycles = (monthsElapsed ~/ intervalMonths).clamp(1, 1 << 20);
    }
    var candidate = leaseStart.addMonths(cycles * intervalMonths);
    while (candidate.isBefore(asOf)) {
      cycles++;
      candidate = leaseStart.addMonths(cycles * intervalMonths);
    }
    return candidate;
  }

  /// Every rent period from the month containing [start] through the month
  /// containing [until] (inclusive), clipped to the lease [end] if any.
  static List<MonthPeriod> billablePeriods({
    required CalendarDate start,
    required CalendarDate until,
    CalendarDate? end,
  }) {
    final last = end == null ? until : CalendarDate.min(until, end);
    if (last.isBefore(start)) return const [];
    return MonthPeriod.range(MonthPeriod.of(start), MonthPeriod.of(last));
  }
}
