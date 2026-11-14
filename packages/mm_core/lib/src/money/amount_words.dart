import 'package:mm_core/src/money/amount_lexicon.g.dart';
import 'package:mm_core/src/money/money.dart';

/// The words [formatAmountWords] writes an amount in.
enum AmountScript {
  /// Urdu script, in lakh and crore: `پچیس ہزار روپے`.
  urdu,

  /// Roman Urdu, in lakh and crore: `pachees hazar rupay`.
  roman,

  /// British English, in thousands and millions: `twenty-five thousand
  /// rupees`, `one hundred and fifty thousand rupees`.
  english,
}

/// Writes [money] in words, for the read-back shown beside the digits
/// before a parsed amount is saved: `پچیس ہزار روپے` beside `Rs 25,000`.
///
/// Every amount from zero to `Money.maxValue` is written, paise included
/// (`ek sau rupay pachas paise`; `sifar rupay pachas paise` below a rupee),
/// with the first spelling of each word in `contracts/amount_lexicon.json`.
/// No fraction words are written (`ek lakh pachas hazar`, not `derh lakh`),
/// so the words are never ambiguous: `parseAmount` with
/// `AmountContext.field` reads back exactly [money] for every script.
///
/// Throws an [ArgumentError] for a negative amount or one above
/// `Money.maxValue`, which a parsed amount never is.
String formatAmountWords(Money money, AmountScript script) {
  if (money.paisa < 0 || money.paisa > Money.maxValue.paisa) {
    throw ArgumentError.value(
      money,
      'money',
      'must be from zero to the maximum',
    );
  }
  final rupees = money.paisa ~/ Money.paisaPerRupee;
  final paisa = money.paisa % Money.paisaPerRupee;
  final (numbers, rupee, coin) = switch (script) {
    AmountScript.urdu => (amountNumbersUrdu, amountRupeeUrdu, amountPaisaUrdu),
    AmountScript.roman => (
      amountNumbersRoman,
      amountRupeeRoman,
      amountPaisaRoman,
    ),
    AmountScript.english => (
      amountNumbersEnglish,
      amountRupeeEnglish,
      amountPaisaEnglish,
    ),
  };
  final words = switch (script) {
    AmountScript.urdu => _southAsian(rupees, numbers, amountMultipliersUrdu),
    AmountScript.roman => _southAsian(rupees, numbers, amountMultipliersRoman),
    AmountScript.english => _western(rupees),
  };
  if (rupees == 0) words.add(numbers[0]);
  words.add(rupees == 1 ? rupee.one : rupee.other);
  if (paisa > 0) {
    words
      ..add(numbers[paisa])
      ..add(paisa == 1 ? coin.one : coin.other);
  }
  return words.join(' ');
}

/// Arab, crore, lakh, hazar, sau and the units; only arab can take more
/// than 99, written with sau (`nau sau ninyanwe arab`).
List<String> _southAsian(
  int rupees,
  List<String> numbers,
  Map<int, String> multipliers,
) {
  final words = <String>[];
  var rest = rupees;
  for (final (power, size) in const [
    (9, 1000000000),
    (7, 10000000),
    (5, 100000),
    (3, 1000),
    (2, 100),
  ]) {
    final count = rest ~/ size;
    rest %= size;
    if (count == 0) continue;
    words
      ..addAll(_hundreds(count, numbers, multipliers[2]!, null))
      ..add(multipliers[power]!);
  }
  if (rest > 0) words.add(numbers[rest]);
  return words;
}

/// Billions, millions, thousands, then the last three digits, with 'and'
/// before a last number below a hundred (`one thousand and five`).
List<String> _western(int rupees) {
  const numbers = amountNumbersEnglish;
  final hundred = amountMultipliersEnglish[2]!;
  final words = <String>[];
  var rest = rupees;
  for (final (power, size) in const [
    (9, 1000000000),
    (6, 1000000),
    (3, 1000),
  ]) {
    final count = rest ~/ size;
    rest %= size;
    if (count == 0) continue;
    words
      ..addAll(_hundreds(count, numbers, hundred, amountConnectorEnglish))
      ..add(amountMultipliersEnglish[power]!);
  }
  if (rest > 0) {
    if (words.isNotEmpty && rest < 100) words.add(amountConnectorEnglish);
    words.addAll(_hundreds(rest, numbers, hundred, amountConnectorEnglish));
  }
  return words;
}

/// 1 to 999: the hundreds, then [connector] if given, then the rest.
List<String> _hundreds(
  int count,
  List<String> numbers,
  String hundred,
  String? connector,
) {
  if (count < 100) return [numbers[count]];
  final rest = count % 100;
  return [
    numbers[count ~/ 100],
    hundred,
    if (rest > 0 && connector != null) connector,
    if (rest > 0) numbers[rest],
  ];
}
