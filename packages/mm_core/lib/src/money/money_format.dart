import 'package:meta/meta.dart';
import 'package:mm_core/src/money/money.dart';

/// How digits are grouped in the integer part of a formatted amount.
enum DigitGrouping {
  /// Groups of three: `1,234,567` (banking and most printed media).
  western,

  /// Indian/Pakistani numbering: `12,34,567` (lakh/crore grouping).
  southAsian,
}

/// Whether amounts are written in full or abbreviated with lakh/crore.
enum MoneyNotation {
  /// The full amount, e.g. `Rs 1,250,000`.
  standard,

  /// Abbreviated using the South Asian units lakh (10⁵) and crore (10⁷),
  /// e.g. `Rs 12.5 lakh`. Amounts below one lakh are written in full.
  compact,
}

/// How the currency is identified in the formatted string.
enum CurrencyDisplay {
  /// `Rs` in English, `روپے` in Urdu.
  symbol,

  /// The ISO 4217 code `PKR`.
  code,

  /// No currency marker.
  none,
}

/// Whether the paisa component is rendered.
enum PaisaDisplay {
  /// Show paisa only when the amount is not a whole number of rupees.
  auto,

  /// Always show two fraction digits.
  always,

  /// Never show paisa (the amount is rounded half-up to whole rupees).
  never,
}

/// The language the amount is rendered in.
enum MoneyLanguage {
  /// English: `Rs 1,500` / `Rs 1.5 lakh`.
  english,

  /// Urdu: `1,500 روپے` / `1.5 لاکھ روپے`.
  urdu,
}

/// Formats [Money] the way Pakistani landlords and tenants read amounts.
///
/// ```dart
/// const MoneyFormat().format(Money.fromRupees(150000));           // Rs 150,000
/// const MoneyFormat(grouping: DigitGrouping.southAsian)
///     .format(Money.fromRupees(150000));                          // Rs 1,50,000
/// const MoneyFormat(notation: MoneyNotation.compact)
///     .format(Money.fromRupees(2350000));                         // Rs 23.5 lakh
/// const MoneyFormat(language: MoneyLanguage.urdu)
///     .format(Money.fromRupees(5000));                            // 5,000 روپے
/// ```
///
/// A negative amount starts with an invisible left-to-right mark (U+200E)
/// before its minus sign, so the sign stays on the left of the figures in
/// right-to-left text as well (see [format]).
@immutable
final class MoneyFormat {
  /// Creates a formatter. All options have sensible Pakistani defaults.
  const new({
    this.grouping = DigitGrouping.western,
    this.notation = MoneyNotation.standard,
    this.currency = CurrencyDisplay.symbol,
    this.paisa = PaisaDisplay.auto,
    this.language = MoneyLanguage.english,
    this.nativeDigits = false,
  });

  /// Digit grouping for the integer part.
  final DigitGrouping grouping;

  /// Full or lakh/crore-abbreviated output.
  final MoneyNotation notation;

  /// Currency marker style.
  final CurrencyDisplay currency;

  /// Paisa rendering policy.
  final PaisaDisplay paisa;

  /// Output language.
  final MoneyLanguage language;

  /// When `true` and [language] is Urdu, digits are written with Urdu
  /// (Extended Arabic-Indic) numerals `۰۱۲۳۴۵۶۷۸۹`.
  final bool nativeDigits;

  /// U+200E LEFT-TO-RIGHT MARK, which [format] puts before the minus sign
  /// of a negative amount.
  static const String leftToRightMark = '\u200E';

  static const int _lakhPaisa = 100000 * Money.paisaPerRupee;
  static const int _crorePaisa = 10000000 * Money.paisaPerRupee;

  /// Formats [amount].
  ///
  /// A negative amount is written with a minus sign before it, preceded by
  /// [leftToRightMark]: `\u200E-5,000 روپے`, `\u200E-Rs 5,000`. In
  /// right-to-left text (an Urdu sentence or screen) the bidirectional
  /// algorithm would otherwise give the minus the paragraph's direction and
  /// show it on the right of the figures (`5,000-`); after the mark, the
  /// sign, figures and Latin currency markers form one left-to-right run, so
  /// the amount reads `-5,000` in either direction. The mark is invisible, is
  /// kept by the text sanitisers (it is not a bidi override or isolate) and
  /// is ignored by `parseMoneyInput`.
  String format(Money amount) {
    final negative = amount.isNegative;
    final number =
        notation == MoneyNotation.compact && amount.abs().paisa >= _lakhPaisa
        ? _compactNumber(amount.abs())
        : _standardNumber(amount.abs());
    final localized = nativeDigits && language == MoneyLanguage.urdu
        ? _toUrduDigits(number)
        : number;
    return _decorate(localized, negative: negative);
  }

  /// Formats only the number (no currency marker), honouring every other
  /// option. Useful for form fields and charts.
  String formatNumber(Money amount) =>
      copyWith(currency: CurrencyDisplay.none).format(amount);

  /// This format with the given options replaced.
  MoneyFormat copyWith({
    DigitGrouping? grouping,
    MoneyNotation? notation,
    CurrencyDisplay? currency,
    PaisaDisplay? paisa,
    MoneyLanguage? language,
    bool? nativeDigits,
  }) => MoneyFormat(
    grouping: grouping ?? this.grouping,
    notation: notation ?? this.notation,
    currency: currency ?? this.currency,
    paisa: paisa ?? this.paisa,
    language: language ?? this.language,
    nativeDigits: nativeDigits ?? this.nativeDigits,
  );

  @override
  bool operator ==(Object other) =>
      other is MoneyFormat &&
      other.grouping == grouping &&
      other.notation == notation &&
      other.currency == currency &&
      other.paisa == paisa &&
      other.language == language &&
      other.nativeDigits == nativeDigits;

  @override
  int get hashCode =>
      Object.hash(grouping, notation, currency, paisa, language, nativeDigits);

  @override
  String toString() =>
      'MoneyFormat(${grouping.name}, ${notation.name}, ${currency.name}, '
      '${paisa.name}, ${language.name}, nativeDigits: $nativeDigits)';

  String _standardNumber(Money magnitude) {
    final showPaisa = switch (paisa) {
      PaisaDisplay.always => true,
      PaisaDisplay.never => false,
      PaisaDisplay.auto => magnitude.hasPaisa,
    };
    if (!showPaisa) {
      final rounded = magnitude.roundToRupee();
      return groupDigits(rounded.wholeRupees.toString(), grouping);
    }
    final whole = groupDigits(magnitude.wholeRupees.toString(), grouping);
    final fraction = magnitude.paisaComponent.toString().padLeft(2, '0');
    return '$whole.$fraction';
  }

  String _compactNumber(Money magnitude) {
    int hundredthsOf(int unitPaisa) => divideRounded(
      BigInt.from(magnitude.paisa) * BigInt.from(100),
      BigInt.from(unitPaisa),
      RoundingMode.halfUp,
    ).toInt();
    // Two decimal places, rounded half-up, trailing zeros trimmed. A value
    // that rounds up to 100 lakh is promoted to crore ("1 crore", never
    // "100 lakh").
    var useCrore = magnitude.paisa >= _crorePaisa;
    var hundredths = hundredthsOf(useCrore ? _crorePaisa : _lakhPaisa);
    if (!useCrore && hundredths >= 100 * 100) {
      useCrore = true;
      hundredths = hundredthsOf(_crorePaisa);
    }
    final whole = hundredths ~/ 100;
    final fraction = hundredths % 100;
    var digits = groupDigits(whole.toString(), grouping);
    if (fraction != 0) {
      final fractionText = fraction
          .toString()
          .padLeft(2, '0')
          .replaceFirst(RegExp(r'0$'), '');
      digits = '$digits.$fractionText';
    }
    final unit = switch ((language, useCrore)) {
      (MoneyLanguage.english, true) => 'crore',
      (MoneyLanguage.english, false) => 'lakh',
      (MoneyLanguage.urdu, true) => 'کروڑ',
      (MoneyLanguage.urdu, false) => 'لاکھ',
    };
    return '$digits $unit';
  }

  String _decorate(String number, {required bool negative}) {
    final sign = negative ? '$leftToRightMark-' : '';
    switch ((currency, language)) {
      case (CurrencyDisplay.none, _):
        return '$sign$number';
      case (CurrencyDisplay.code, _):
        return '${sign}PKR $number';
      case (CurrencyDisplay.symbol, MoneyLanguage.english):
        return '${sign}Rs $number';
      case (CurrencyDisplay.symbol, MoneyLanguage.urdu):
        // Urdu places the unit after the amount ("پانچ ہزار روپے").
        return '$sign$number روپے';
    }
  }
}

/// Inserts thousands separators into a string of ASCII [digits].
///
/// [DigitGrouping.western] produces `1,234,567`; [DigitGrouping.southAsian]
/// produces `12,34,567`.
String groupDigits(String digits, DigitGrouping grouping) {
  if (digits.length <= 3) return digits;
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final groupSize = grouping == DigitGrouping.western ? 3 : 2;
  final groups = <String>[];
  var end = head.length;
  while (end > 0) {
    final start = end - groupSize < 0 ? 0 : end - groupSize;
    groups.insert(0, head.substring(start, end));
    end = start;
  }
  return '${groups.join(',')},$tail';
}

String _toUrduDigits(String input) {
  const urduZero = 0x06F0;
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buffer.writeCharCode(urduZero + (unit - 0x30));
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}
