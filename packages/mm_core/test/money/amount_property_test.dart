// Property tests of the amount grammar, seeded so a failure repeats:
//
// * words round-trip: parseAmount(formatAmountWords(n, script)) == n for
//   random amounts up to the numeric(14,2) maximum, in every script;
// * the reading does not change with the digit script, the grouping, the
//   spacing or direction marks;
// * whatever the input, a found amount is never negative and never above the
//   maximum, and parseAmount never throws.
import 'dart:math';

import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

const int _cases = 10000;
const int _seed = 20261114;

/// Half uniform up to the maximum (mostly large amounts), half with a random
/// number of digits (small amounts as often as large ones).
int _amount(Random random) {
  if (random.nextBool()) {
    return random.nextInt(100000) * 1000000000 + random.nextInt(1000000000);
  }
  final digits = 1 + random.nextInt(14);
  var paisa = 0;
  for (var i = 0; i < digits; i++) {
    paisa = paisa * 10 + random.nextInt(10);
  }
  return paisa;
}

const _marks = ['\u200E', '\u200F', '\u061C', '\u200C'];
const _spaces = [' ', '  ', '\t', '\u00A0', '\u2009', '\u202F', ' \u00A0 '];

/// [text] with each space replaced by a random run of spaces and random
/// direction marks and joiners put between characters.
String _respace(String text, Random random) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    out.write(ch == ' ' ? _spaces[random.nextInt(_spaces.length)] : ch);
    if (random.nextInt(4) == 0) {
      out.write(_marks[random.nextInt(_marks.length)]);
    }
  }
  return out.toString();
}

/// [text] with its ASCII digits in Urdu, Arabic-Indic or full-width digits.
String _digits(String text, int zero) => String.fromCharCodes(
  text.runes.map((r) => r >= 0x30 && r <= 0x39 ? zero + r - 0x30 : r),
);

void main() {
  for (final script in AmountScript.values) {
    test('$_cases amounts round-trip through ${script.name} words', () {
      final random = Random(_seed + script.index);
      for (var i = 0; i < _cases; i++) {
        final money = Money.fromPaisa(_amount(random));
        final words = formatAmountWords(money, script);
        expect(
          parseAmount(words, context: AmountContext.field),
          AmountFound(money),
          reason: words,
        );
      }
    });

    test('${script.name} words read the same respaced and with marks', () {
      final random = Random(_seed + 10 + script.index);
      for (var i = 0; i < _cases ~/ 10; i++) {
        final money = Money.fromPaisa(_amount(random));
        final words = _respace(formatAmountWords(money, script), random);
        expect(
          parseAmount(words, context: AmountContext.field),
          AmountFound(money),
          reason: words,
        );
      }
    });
  }

  test('$_cases digit amounts read the same in any script, grouping, '
      'spacing and direction marks', () {
    final random = Random(_seed + 20);
    const zeros = [0x30, 0x0660, 0x06F0, 0xFF10];
    for (var i = 0; i < _cases; i++) {
      final money = Money.fromPaisa(_amount(random));
      final format = MoneyFormat(
        grouping: DigitGrouping.values[random.nextInt(2)],
        currency: CurrencyDisplay.values[random.nextInt(3)],
        paisa: random.nextBool() ? PaisaDisplay.auto : PaisaDisplay.always,
        language: MoneyLanguage.values[random.nextInt(2)],
      );
      final text = _respace(
        _digits(format.format(money), zeros[random.nextInt(zeros.length)]),
        random,
      );
      for (final context in AmountContext.values) {
        expect(
          parseAmount(text, context: context),
          AmountFound(money),
          reason: '$text (${context.name})',
        );
      }
    }
  });

  test('$_cases random token strings never give a negative amount, one '
      'above the maximum, or an error', () {
    final random = Random(_seed + 30);
    const pieces = [
      'ek',
      'do',
      'pachas',
      'ninyanwe',
      'sau',
      'hazar',
      'lakh',
      'crore',
      'arab',
      'million',
      'k',
      'm',
      'sawa',
      'sarhe',
      'paune',
      'derh',
      'dhai',
      'rupay',
      'Rs',
      'paise',
      'only',
      'and',
      'aur',
      r'$',
      '-',
      '/-',
      '0',
      '7',
      '99',
      '1,50,000',
      '12,345',
      '1.5',
      '0.001',
      '999999999999',
      'ایک',
      'دو',
      'سو',
      'ہزار',
      'لاکھ',
      'کروڑ',
      'ارب',
      'روپے',
      'پیسے',
      'ڈیڑھ',
      'سوا',
      'twenty',
      'one',
      'hundred',
      'thousand',
      'xyz',
      '.',
    ];
    final outcomes = <Type>{};
    for (var i = 0; i < _cases; i++) {
      final text = [
        for (var n = random.nextInt(7); n >= 0; n--)
          pieces[random.nextInt(pieces.length)],
      ].join(random.nextBool() ? ' ' : '');
      for (final context in AmountContext.values) {
        final reading = parseAmount(text, context: context);
        outcomes.add(reading.runtimeType);
        if (reading is AmountFound) {
          expect(
            reading.money.paisa,
            inInclusiveRange(0, Money.maxValue.paisa),
            reason: text,
          );
        }
      }
    }
    expect(outcomes, {AmountFound, AmountAmbiguous, AmountNotFound});
  });
}
