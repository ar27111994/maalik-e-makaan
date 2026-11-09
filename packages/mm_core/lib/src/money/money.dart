import 'package:meta/meta.dart';

/// How to round a result that falls between two representable amounts.
enum RoundingMode {
  /// Round to the nearest value; ties go away from zero (commercial rounding).
  halfUp,

  /// Round to the nearest value; ties go to the even neighbour
  /// (banker's rounding).
  halfEven,

  /// Always round toward zero (truncate).
  down,

  /// Always round away from zero.
  up,

  /// Always round toward negative infinity.
  floor,

  /// Always round toward positive infinity.
  ceiling,
}

/// An exact amount of Pakistani Rupees, stored as an integer number of paisa
/// (1 rupee = 100 paisa).
///
/// Floating-point numbers are never used for arithmetic: every operation that
/// can produce a fraction of a paisa takes an explicit [RoundingMode] and is
/// computed with arbitrary-precision integers, so results are identical on the
/// Dart VM and on the web (where `int` is a JavaScript double).
///
/// The supported range mirrors the database column type `numeric(14,2)`:
/// ±999,999,999,999.99.
@immutable
final class Money implements Comparable<Money> {
  /// Creates an amount from a whole number of [paisa].
  const new fromPaisa(this.paisa);

  /// Creates an amount from a whole number of [rupees].
  const new fromRupees(int rupees) : paisa = rupees * paisaPerRupee;

  /// Parses an exact decimal string such as `1500`, `1500.5` or `-20.75`.
  ///
  /// At most two fraction digits are accepted. Throws a [FormatException] for
  /// anything else, including grouping separators — use `parseMoneyInput` for
  /// human-typed input.
  factory parseDecimal(String value) {
    final parsed = tryParseDecimal(value);
    if (parsed == null) {
      throw FormatException('Not a valid decimal money amount', value);
    }
    return parsed;
  }

  /// Decodes an amount produced by the database API (PostgREST serialises
  /// `numeric` columns as JSON numbers, but strings are accepted too).
  ///
  /// Throws a [FormatException] for `null` or malformed input.
  factory fromJson(Object? json) {
    switch (json) {
      case final int whole:
        return Money.fromRupees(whole);
      case final double fractional:
        if (!fractional.isFinite) {
          throw FormatException('Money must be finite', '$json');
        }
        // `toStringAsFixed(2)` rounds via the shortest round-trip decimal,
        // which is exact for every value the database can hold.
        return Money.parseDecimal(fractional.toStringAsFixed(2));
      case final String text:
        return Money.parseDecimal(text.trim());
      default:
        throw FormatException('Unsupported money JSON value', '$json');
    }
  }

  /// The number of paisa in one rupee.
  static const int paisaPerRupee = 100;

  /// Zero rupees.
  static const Money zero = Money.fromPaisa(0);

  /// Largest representable amount (matches `numeric(14,2)`).
  static const Money maxValue = Money.fromPaisa(99999999999999);

  /// Smallest representable amount (matches `numeric(14,2)`).
  static const Money minValue = Money.fromPaisa(-99999999999999);

  static final RegExp _decimalPattern = RegExp(
    r'^([+-])?(\d+)(?:\.(\d{1,2}))?$',
  );

  /// Parses an exact decimal string, returning `null` when it is malformed,
  /// has more than two fraction digits, or is out of range.
  static Money? tryParseDecimal(String value) {
    final match = _decimalPattern.firstMatch(value);
    if (match == null) return null;
    final negative = match.group(1) == '-';
    final whole = BigInt.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final paisa = whole * BigInt.from(paisaPerRupee) + BigInt.parse(fraction);
    final signed = negative ? -paisa : paisa;
    if (signed > BigInt.from(maxValue.paisa) ||
        signed < BigInt.from(minValue.paisa)) {
      return null;
    }
    return Money.fromPaisa(signed.toInt());
  }

  /// The smaller of [a] and [b].
  static Money min(Money a, Money b) => a <= b ? a : b;

  /// The larger of [a] and [b].
  static Money max(Money a, Money b) => a >= b ? a : b;

  /// Sums [amounts]; an empty iterable sums to [zero].
  static Money sum(Iterable<Money> amounts) =>
      amounts.fold(zero, (total, amount) => total + amount);

  /// The amount in paisa. Negative values represent credits or refunds.
  final int paisa;

  /// Whole rupees, truncated toward zero.
  int get wholeRupees => paisa ~/ paisaPerRupee;

  /// The paisa component (0–99) of the absolute amount.
  int get paisaComponent => paisa.abs() % paisaPerRupee;

  /// Whether the amount is exactly zero.
  bool get isZero => paisa == 0;

  /// Whether the amount is greater than zero.
  bool get isPositive => paisa > 0;

  /// Whether the amount is less than zero.
  bool get isNegative => paisa < 0;

  /// Whether the amount has a non-zero paisa component.
  bool get hasPaisa => paisaComponent != 0;

  /// Whether the amount lies within [minValue]..[maxValue].
  bool get isWithinStorageRange =>
      paisa <= maxValue.paisa && paisa >= minValue.paisa;

  /// Sum of two amounts.
  Money operator +(Money other) => Money.fromPaisa(paisa + other.paisa);

  /// Difference of two amounts.
  Money operator -(Money other) => Money.fromPaisa(paisa - other.paisa);

  /// The negated amount.
  Money operator -() => Money.fromPaisa(-paisa);

  /// Whether this amount is less than [other].
  bool operator <(Money other) => paisa < other.paisa;

  /// Whether this amount is less than or equal to [other].
  bool operator <=(Money other) => paisa <= other.paisa;

  /// Whether this amount is greater than [other].
  bool operator >(Money other) => paisa > other.paisa;

  /// Whether this amount is greater than or equal to [other].
  bool operator >=(Money other) => paisa >= other.paisa;

  /// The absolute amount.
  Money abs() => paisa < 0 ? -this : this;

  /// Restricts the amount to the inclusive range [lower]..[upper].
  Money clamp(Money lower, Money upper) {
    if (lower > upper) {
      throw ArgumentError('lower ($lower) must not exceed upper ($upper)');
    }
    if (this < lower) return lower;
    if (this > upper) return upper;
    return this;
  }

  /// Multiplies by the exact ratio [numerator]/[denominator], rounding the
  /// result to whole paisa with [mode].
  Money multiply(
    int numerator, [
    int denominator = 1,
    RoundingMode mode = RoundingMode.halfUp,
  ]) {
    if (denominator == 0) {
      throw ArgumentError.value(denominator, 'denominator', 'must not be 0');
    }
    final product = BigInt.from(paisa) * BigInt.from(numerator);
    return Money.fromPaisa(
      divideRounded(product, BigInt.from(denominator), mode).toInt(),
    );
  }

  /// Multiplies by the exact ratio [numerator]/[denominator] and rounds the
  /// result **once** to a multiple of [stepRupees] whole rupees.
  ///
  /// Prefer this to chaining [multiply] and [roundToStep]: that rounds twice
  /// (first to paisa, then to the step), which can differ from the
  /// database's single rounding — e.g. an exact Rs 12.495 would become 12.50
  /// and then 13 instead of 12.
  Money multiplyToStep(
    int numerator,
    int denominator, {
    int stepRupees = 1,
    RoundingMode mode = RoundingMode.halfUp,
  }) {
    if (denominator == 0) {
      throw ArgumentError.value(denominator, 'denominator', 'must not be 0');
    }
    if (stepRupees <= 0) {
      throw ArgumentError.value(stepRupees, 'stepRupees', 'must be > 0');
    }
    final step = BigInt.from(stepRupees * paisaPerRupee);
    final steps = divideRounded(
      BigInt.from(paisa) * BigInt.from(numerator),
      BigInt.from(denominator) * step,
      mode,
    );
    return Money.fromPaisa((steps * step).toInt());
  }

  /// [basisPoints] hundredths of a percent of this amount
  /// (10% = 1000 basis points).
  Money percentage(
    int basisPoints, {
    RoundingMode mode = RoundingMode.halfUp,
  }) => multiply(basisPoints, 10000, mode);

  /// Rounds to a multiple of [stepRupees] whole rupees (e.g. `100` rounds
  /// 52,030 to 52,000).
  Money roundToStep(int stepRupees, {RoundingMode mode = RoundingMode.halfUp}) {
    if (stepRupees <= 0) {
      throw ArgumentError.value(stepRupees, 'stepRupees', 'must be > 0');
    }
    final step = BigInt.from(stepRupees * paisaPerRupee);
    final steps = divideRounded(BigInt.from(paisa), step, mode);
    return Money.fromPaisa((steps * step).toInt());
  }

  /// Rounds to whole rupees.
  Money roundToRupee({RoundingMode mode = RoundingMode.halfUp}) =>
      roundToStep(1, mode: mode);

  /// Splits this amount in proportion to [ratios] without losing a paisa,
  /// using the largest-remainder method. The parts always sum to this amount.
  List<Money> allocate(List<int> ratios) {
    if (ratios.isEmpty) {
      throw ArgumentError.value(ratios, 'ratios', 'must not be empty');
    }
    if (ratios.any((ratio) => ratio < 0)) {
      throw ArgumentError.value(ratios, 'ratios', 'must be non-negative');
    }
    final total = ratios.fold<int>(0, (sum, ratio) => sum + ratio);
    if (total == 0) {
      throw ArgumentError.value(ratios, 'ratios', 'must not all be zero');
    }
    final magnitude = BigInt.from(paisa.abs());
    final totalBig = BigInt.from(total);
    final parts = <int>[];
    final remainders = <({int index, BigInt remainder})>[];
    var allocated = 0;
    for (var i = 0; i < ratios.length; i++) {
      final share = magnitude * BigInt.from(ratios[i]);
      final part = (share ~/ totalBig).toInt();
      parts.add(part);
      allocated += part;
      remainders.add((index: i, remainder: share.remainder(totalBig)));
    }
    var leftover = paisa.abs() - allocated;
    remainders.sort((a, b) {
      final byRemainder = b.remainder.compareTo(a.remainder);
      return byRemainder != 0 ? byRemainder : a.index.compareTo(b.index);
    });
    for (final entry in remainders) {
      if (leftover == 0) break;
      parts[entry.index] += 1;
      leftover -= 1;
    }
    final sign = paisa < 0 ? -1 : 1;
    return [for (final part in parts) Money.fromPaisa(part * sign)];
  }

  /// Splits into [count] near-equal parts that sum exactly to this amount.
  List<Money> splitEvenly(int count) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'must be > 0');
    }
    return allocate(List<int>.filled(count, 1));
  }

  /// Exact decimal representation with two fraction digits, e.g. `1500.05`.
  String toDecimalString() {
    final sign = paisa < 0 ? '-' : '';
    final fraction = paisaComponent.toString().padLeft(2, '0');
    return '$sign${wholeRupees.abs()}.$fraction';
  }

  /// JSON representation: the exact decimal string accepted by `numeric`.
  String toJson() => toDecimalString();

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  bool operator ==(Object other) => other is Money && other.paisa == paisa;

  @override
  int get hashCode => paisa.hashCode;

  @override
  String toString() => 'Money(${toDecimalString()} PKR)';
}

/// Divides [numerator] by [denominator], rounding the quotient with [mode].
@internal
BigInt divideRounded(BigInt numerator, BigInt denominator, RoundingMode mode) {
  if (denominator == BigInt.zero) {
    throw ArgumentError.value(denominator, 'denominator', 'must not be 0');
  }
  var n = numerator;
  var d = denominator;
  if (d.isNegative) {
    n = -n;
    d = -d;
  }
  final quotient = n ~/ d; // truncates toward zero
  final remainder = n.remainder(d); // carries the sign of n
  if (remainder == BigInt.zero) return quotient;
  final awayFromZero = n.isNegative
      ? quotient - BigInt.one
      : quotient + BigInt.one;
  final twiceRemainder = remainder.abs() * BigInt.two;
  switch (mode) {
    case RoundingMode.down:
      return quotient;
    case RoundingMode.up:
      return awayFromZero;
    case RoundingMode.floor:
      return n.isNegative ? quotient - BigInt.one : quotient;
    case RoundingMode.ceiling:
      return n.isNegative ? quotient : quotient + BigInt.one;
    case RoundingMode.halfUp:
      return twiceRemainder >= d ? awayFromZero : quotient;
    case RoundingMode.halfEven:
      if (twiceRemainder > d) return awayFromZero;
      if (twiceRemainder < d) return quotient;
      return quotient.isEven ? quotient : awayFromZero;
  }
}
