/// Helpers for percentages stored as `numeric(5,2)` (e.g. `10.00` for 10 %)
/// and handled in code as integer basis points (1 % = 100 bp) so percentage
/// arithmetic stays exact.
library;

final RegExp _percentPattern = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$');

/// Converts a percentage (JSON number or numeric string, at most two decimal
/// places, 0–100) into basis points: `10` → 1000, `2.5` → 250.
///
/// Throws a [FormatException] for malformed or out-of-range input.
int basisPointsFromPercent(Object? json) {
  final String text;
  switch (json) {
    case final int whole:
      text = '$whole';
    case final double fractional when fractional.isFinite:
      text = fractional.toStringAsFixed(2);
    case final String raw:
      text = raw.trim();
    default:
      throw FormatException('Expected a percentage', '$json');
  }
  final match = _percentPattern.firstMatch(text);
  if (match == null) throw FormatException('Expected a percentage', text);
  final whole = int.parse(match.group(1)!);
  final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
  final basisPoints = whole * 100 + fraction;
  if (basisPoints > 10000) {
    throw FormatException('Percentage must not exceed 100', text);
  }
  return basisPoints;
}

/// Formats basis points as a percentage string for the database or display:
/// 1000 → `10`, 250 → `2.5`, 1234 → `12.34`.
String percentFromBasisPoints(int basisPoints) {
  if (basisPoints < 0) {
    throw ArgumentError.value(basisPoints, 'basisPoints', 'must be >= 0');
  }
  final whole = basisPoints ~/ 100;
  final fraction = basisPoints % 100;
  if (fraction == 0) return '$whole';
  final digits = fraction
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0$'), '');
  return '$whole.$digits';
}
