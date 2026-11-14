import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  String words(int paisa, AmountScript script) =>
      formatAmountWords(Money.fromPaisa(paisa), script);

  group('formatAmountWords', () {
    test('writes lakh and crore in Urdu and Roman Urdu', () {
      expect(words(150000 * 100, AmountScript.urdu), 'ایک لاکھ پچاس ہزار روپے');
      expect(
        words(150000 * 100, AmountScript.roman),
        'ek lakh pachas hazar rupay',
      );
      expect(
        words(34000000 * 100, AmountScript.roman),
        'teen crore chalees lakh rupay',
      );
      expect(words(900 * 100, AmountScript.roman), 'nau sau rupay');
      expect(
        words(123456789012 * 100, AmountScript.roman),
        'ek sau teis arab paintalees crore sarsath lakh nawasi hazar '
        'barah rupay',
      );
    });

    test('writes thousands and millions in British English', () {
      expect(
        words(150000 * 100, AmountScript.english),
        'one hundred and fifty thousand rupees',
      );
      expect(
        words(1005 * 100, AmountScript.english),
        'one thousand and five rupees',
      );
      expect(
        words(1100 * 100, AmountScript.english),
        'one thousand one hundred rupees',
      );
      expect(
        words(200000 * 100, AmountScript.english),
        'two hundred thousand rupees',
      );
      expect(
        words(1000050 * 100, AmountScript.english),
        'one million and fifty rupees',
      );
    });

    test('writes one rupee and one paisa in the singular', () {
      expect(words(100, AmountScript.urdu), 'ایک روپیہ');
      expect(words(101, AmountScript.roman), 'ek rupaya ek paisa');
      expect(words(1, AmountScript.english), 'zero rupees one paisa');
      expect(words(250, AmountScript.english), 'two rupees fifty paise');
    });

    test('refuses a negative amount or one above the maximum', () {
      expect(
        () => formatAmountWords(const Money.fromPaisa(-1), AmountScript.urdu),
        throwsArgumentError,
      );
      expect(
        () => formatAmountWords(
          Money.fromPaisa(Money.maxValue.paisa + 1),
          AmountScript.roman,
        ),
        throwsArgumentError,
      );
    });
  });
}
