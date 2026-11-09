import 'package:mm_core/src/money/money.dart';
import 'package:mm_core/src/text/digits.dart';

/// Parses an amount the way a Pakistani user types it.
///
/// Accepts, in any combination:
///
/// * currency markers: `Rs`, `Rs.`, `PKR`, `₨`, `rupees`, `روپے`, `روپیہ`;
/// * grouping separators in any position: `1,50,000`, `150,000`, `150 000`;
/// * Urdu / Arabic-Indic digits: `۱۵۰۰۰۰`;
/// * the Arabic decimal separator `٫` and thousands separator `٬`;
/// * unit words: `k`/`thousand`/`hazar`/`ہزار` (10³), `lakh`/`lac`/`لاکھ`
///   (10⁵), `million`/`mn`/`m` (10⁶), `crore`/`cr`/`کروڑ` (10⁷),
///   `arab`/`ارب` (10⁹).
///
/// Plain numbers may have at most two decimal places. Amounts written with a
/// unit word are rounded half-up to the nearest paisa (`1.234567 lakh`).
///
/// Direction marks (U+200E, U+200F and the Arabic letter mark U+061C) are
/// ignored wherever they appear: `MoneyFormat` writes one before the minus
/// sign of a negative amount, and text copied from right-to-left messages
/// often carries them.
///
/// Returns `null` for empty, malformed, negative (unless [allowNegative]) or
/// out-of-range input.
Money? parseMoneyInput(String input, {bool allowNegative = false}) {
  var text = normalizeDigits(input.replaceAll(_directionMarks, ''))
      .toLowerCase()
      .trim();
  if (text.isEmpty) return null;

  var negative = false;
  if (text.startsWith('-') || text.startsWith('−')) {
    negative = true;
    text = text.substring(1).trim();
  } else if (text.startsWith('+')) {
    text = text.substring(1).trim();
  }

  text = _stripCurrencyMarkers(text);
  // Leading sign may follow the currency marker: "Rs -500".
  if (!negative && text.startsWith('-')) {
    negative = true;
    text = text.substring(1).trim();
  }
  if (negative && !allowNegative) return null;

  text = text
      .replaceAll('٫', '.') // Arabic decimal separator
      .replaceAll('٬', '') // Arabic thousands separator
      .replaceAll(',', '')
      .replaceAll('_', '')
      .replaceAll("'", '');

  var multiplier = BigInt.one;
  for (final unit in _units) {
    final match = unit.pattern.firstMatch(text);
    if (match != null) {
      multiplier = unit.multiplier;
      text = text.substring(0, match.start);
      break;
    }
  }
  text = text.replaceAll(RegExp(r'\s+'), '');

  final match = _numberPattern.firstMatch(text);
  if (match == null) return null;
  final wholeDigits = match.group(1)!;
  final fractionDigits = match.group(2) ?? '';
  if (multiplier == BigInt.one && fractionDigits.length > 2) return null;

  // value = (whole.fraction) * multiplier, expressed in paisa, exactly.
  final scale = BigInt.from(10).pow(fractionDigits.length);
  final numerator =
      BigInt.parse('$wholeDigits$fractionDigits') *
      multiplier *
      BigInt.from(Money.paisaPerRupee);
  final paisa = divideRounded(numerator, scale, RoundingMode.halfUp);
  final signed = negative ? -paisa : paisa;
  if (signed > BigInt.from(Money.maxValue.paisa) ||
      signed < BigInt.from(Money.minValue.paisa)) {
    return null;
  }
  return Money.fromPaisa(signed.toInt());
}

final RegExp _numberPattern = RegExp(r'^(\d+)(?:\.(\d+))?$');

/// The left-to-right, right-to-left and Arabic letter marks.
final RegExp _directionMarks = RegExp('[\u200E\u200F\u061C]');

final List<RegExp> _currencyMarkers = [
  RegExp(r'^(?:rs\.?|pkr|₨|rupees?|روپے|روپیہ|روپیے)\s*'),
  RegExp(r'\s*(?:rs\.?|pkr|₨|rupees?|روپے|روپیہ|روپیے|/-)$'),
];

String _stripCurrencyMarkers(String input) {
  var text = input;
  var changed = true;
  while (changed) {
    changed = false;
    for (final marker in _currencyMarkers) {
      final stripped = text.replaceFirst(marker, '').trim();
      if (stripped != text) {
        text = stripped;
        changed = true;
      }
    }
  }
  return text;
}

typedef _Unit = ({RegExp pattern, BigInt multiplier});

final List<_Unit> _units = [
  (pattern: RegExp(r'\s*(?:arab|ارب)$'), multiplier: BigInt.from(1000000000)),
  (
    pattern: RegExp(r'\s*(?:crores?|cr|karor|کروڑ)$'),
    multiplier: BigInt.from(10000000),
  ),
  (
    pattern: RegExp(r'\s*(?:millions?|mn|m)$'),
    multiplier: BigInt.from(1000000),
  ),
  (
    pattern: RegExp(r'\s*(?:lakhs?|lacs?|لاکھ)$'),
    multiplier: BigInt.from(100000),
  ),
  (
    pattern: RegExp(r'\s*(?:thousand|hazar|hazaar|ہزار|k)$'),
    multiplier: BigInt.from(1000),
  ),
];
