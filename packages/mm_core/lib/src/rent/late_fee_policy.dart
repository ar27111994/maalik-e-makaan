import 'package:meta/meta.dart';
import 'package:mm_core/src/money/basis_points.dart';
import 'package:mm_core/src/money/money.dart';

/// How a lease charges for late rent. Mirrors the `late_fee_type`,
/// `late_fee_value` and `late_fee_cap` columns of the `leases` table.
@immutable
sealed class LateFeePolicy {
  const new();

  /// Decodes the database representation, where [value] and [cap] are the
  /// raw JSON column values.
  ///
  /// * `none`  – no late fee;
  /// * `flat`  – [value] rupees once the grace period has passed;
  /// * `percent` – [value] percent (`numeric(5,2)`) of the overdue amount;
  /// * `daily` – [value] rupees per day late, optionally capped at [cap].
  factory fromColumns({required String type, Object? value, Object? cap}) {
    switch (type) {
      case 'none':
        return const NoLateFee();
      case 'flat':
        return FlatLateFee(_requireMoney(value, type));
      case 'percent':
        if (value == null) {
          throw ArgumentError('late fee type "percent" requires a value');
        }
        return PercentLateFee(basisPointsFromPercent(value));
      case 'daily':
        return DailyLateFee(
          _requireMoney(value, type),
          cap: cap == null ? null : Money.fromJson(cap),
        );
      default:
        throw ArgumentError.value(type, 'type', 'unknown late fee type');
    }
  }

  static Money _requireMoney(Object? value, String type) {
    final money = value == null ? null : Money.fromJson(value);
    if (money == null || money.isNegative) {
      throw ArgumentError(
        'late fee type "$type" requires a non-negative value',
      );
    }
    return money;
  }

  /// The largest fee ever charged: whole rupees below the 10^12 limit of a
  /// `numeric(14,2)` charge amount. Mirrors `app.late_fee_amount`.
  static const Money maxFee = Money.fromRupees(999999999999);

  /// The database `late_fee_type` value.
  String get type;

  /// The fee owed on [overdueAmount] that is [daysLate] days past its due
  /// date, given a grace period of [graceDays] days.
  ///
  /// No fee is charged while `daysLate <= graceDays` or when nothing is owed.
  /// The fee is rounded half-up to whole rupees first and capped afterwards,
  /// so it never exceeds the policy's cap (see [capFee]) nor [maxFee] — the
  /// same order as the database.
  Money feeFor({
    required Money overdueAmount,
    required int daysLate,
    required int graceDays,
  }) {
    if (graceDays < 0) {
      throw ArgumentError.value(graceDays, 'graceDays', 'must be >= 0');
    }
    if (!overdueAmount.isPositive || daysLate <= graceDays) return Money.zero;
    final rounded = computeFee(
      overdueAmount: overdueAmount,
      daysLate: daysLate,
    ).roundToRupee();
    return Money.min(capFee(rounded), maxFee);
  }

  /// Policy-specific fee before grace handling, rounding and capping.
  @protected
  Money computeFee({required Money overdueAmount, required int daysLate});

  /// Applies the policy's own limit to the rounded fee. Uncapped by default.
  @protected
  Money capFee(Money roundedFee) => roundedFee;
}

/// No late fee.
final class NoLateFee extends LateFeePolicy {
  /// Creates the no-fee policy.
  const new();

  @override
  String get type => 'none';

  @override
  Money computeFee({required Money overdueAmount, required int daysLate}) =>
      Money.zero;

  @override
  bool operator ==(Object other) => other is NoLateFee;

  @override
  int get hashCode => type.hashCode;
}

/// A fixed fee once rent is late beyond the grace period.
final class FlatLateFee extends LateFeePolicy {
  /// Creates a flat fee of [amount].
  const new(this.amount);

  /// The fee charged.
  final Money amount;

  @override
  String get type => 'flat';

  @override
  Money computeFee({required Money overdueAmount, required int daysLate}) =>
      amount;

  @override
  bool operator ==(Object other) =>
      other is FlatLateFee && other.amount == amount;

  @override
  int get hashCode => Object.hash(type, amount);
}

/// A percentage of the overdue amount (e.g. 250 basis points = 2.5%).
final class PercentLateFee extends LateFeePolicy {
  /// Creates a percentage fee of [basisPoints] hundredths of a percent.
  const new(this.basisPoints);

  /// The fee rate in basis points.
  final int basisPoints;

  @override
  String get type => 'percent';

  @override
  Money computeFee({required Money overdueAmount, required int daysLate}) =>
      // Round once, straight to rupees, exactly like the database.
      overdueAmount.multiplyToStep(basisPoints, 10000);

  @override
  bool operator ==(Object other) =>
      other is PercentLateFee && other.basisPoints == basisPoints;

  @override
  int get hashCode => Object.hash(type, basisPoints);
}

/// A fee per day late (counted from the due date), optionally capped.
final class DailyLateFee extends LateFeePolicy {
  /// Creates a daily fee of [perDay], never exceeding [cap] when given.
  const new(this.perDay, {this.cap});

  /// The fee for each day late.
  final Money perDay;

  /// Maximum total fee, if any.
  final Money? cap;

  @override
  String get type => 'daily';

  @override
  Money computeFee({required Money overdueAmount, required int daysLate}) {
    // Exact product, held below maxFee so years of daily fees cannot
    // overflow (anything above it is clamped to maxFee after rounding anyway).
    final fee = BigInt.from(perDay.paisa) * BigInt.from(daysLate);
    final limit = BigInt.from(LateFeePolicy.maxFee.paisa);
    return Money.fromPaisa((fee > limit ? limit : fee).toInt());
  }

  @override
  Money capFee(Money roundedFee) {
    final limit = cap;
    return limit == null ? roundedFee : Money.min(roundedFee, limit);
  }

  @override
  bool operator ==(Object other) =>
      other is DailyLateFee && other.perDay == perDay && other.cap == cap;

  @override
  int get hashCode => Object.hash(type, perDay, cap);
}
