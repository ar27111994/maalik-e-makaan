import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  int? paisa(String input, {bool allowNegative = false}) =>
      parseMoneyInput(input, allowNegative: allowNegative)?.paisa;

  group('parseMoneyInput accepts how Pakistanis type amounts', () {
    final cases = <String, int>{
      '150000': 15000000,
      '150,000': 15000000,
      '1,50,000': 15000000,
      '1 50 000': 15000000,
      'Rs 25,000': 2500000,
      'Rs.25000': 2500000,
      'rs. 25,000/-': 2500000,
      'PKR 1,000': 100000,
      '₨ 500': 50000,
      '500 rupees': 50000,
      '1500.5': 150050,
      '1500.50': 150050,
      '50k': 5000000,
      '50 K': 5000000,
      '5 thousand': 500000,
      '5 hazar': 500000,
      '1.5 lakh': 15000000,
      '1.5 lac': 15000000,
      '2 lakhs': 20000000,
      '1.2 crore': 1200000000,
      '1.25cr': 1250000000,
      '3 million': 300000000,
      '2.5m': 250000000,
      '1 arab': 100000000000,
      '۱۵۰۰۰۰': 15000000,
      '٢٥٠٠٠': 2500000,
      '1.5 لاکھ': 15000000,
      '2 کروڑ': 2000000000,
      '5 ہزار': 500000,
      '25,000 روپے': 2500000,
      '1٫5': 150,
      '1٬500': 150000,
      '+500': 50000,
      '0': 0,
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test('"$input"', () => expect(paisa(input), expected));
    }

    test('unit words round half-up to the nearest paisa', () {
      expect(paisa('1.234567 lakh'), 12345670);
      expect(paisa('0.0000001 crore'), 100);
      expect(paisa('0.00000001 crore'), 10);
    });
  });

  group('parseMoneyInput rejects invalid input', () {
    for (final bad in [
      '',
      '   ',
      'abc',
      '12abc',
      '1.234',
      '1..5',
      '.',
      'lakh',
      'rs',
      '1,5,0.0.0',
      '1e5',
      '0x10',
      '9999999999999',
    ]) {
      test('"$bad"', () => expect(parseMoneyInput(bad), isNull));
    }

    test('negatives are rejected unless allowed', () {
      expect(paisa('-500'), isNull);
      expect(paisa('Rs -500'), isNull);
      expect(paisa('-500', allowNegative: true), -50000);
      expect(paisa('−500', allowNegative: true), -50000);
      expect(paisa('Rs -500', allowNegative: true), -50000);
    });
  });

  test('round-trips with MoneyFormat for random amounts', () {
    const formats = [
      MoneyFormat(),
      MoneyFormat(grouping: DigitGrouping.southAsian),
      MoneyFormat(language: MoneyLanguage.urdu),
      MoneyFormat(language: MoneyLanguage.urdu, nativeDigits: true),
      MoneyFormat(currency: CurrencyDisplay.code),
    ];
    for (var paisaValue = 0; paisaValue < 5000000000; paisaValue += 7777777) {
      final amount = Money.fromPaisa(paisaValue);
      for (final format in formats) {
        expect(
          parseMoneyInput(format.format(amount)),
          amount,
          reason: format.format(amount),
        );
      }
    }
  });
}
