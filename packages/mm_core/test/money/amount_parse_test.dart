// Unit tests of parseAmount: every reading and every refusal, with its
// reason. contracts/amount_vectors.json (test/contract/) holds the cases
// every port must agree on; these pin the Dart reasons and edges.
import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  AmountReading field(String input) =>
      parseAmount(input, context: AmountContext.field);
  AmountReading text(String input) => parseAmount(input);
  AmountFound rupees(int rupees) => AmountFound(Money.fromRupees(rupees));
  AmountFound paisa(int paisa) => AmountFound(Money.fromPaisa(paisa));
  AmountAmbiguous ambiguous(AmountAmbiguity reason) => AmountAmbiguous(reason);
  AmountNotFound none(AmountAbsence reason) => AmountNotFound(reason);

  group('reads', () {
    test('word numbers with multipliers', () {
      expect(text('ek lakh pachas hazar'), rupees(150000));
      expect(text('ایک لاکھ پچاس ہزار روپے'), rupees(150000));
      expect(text('teen crore chalees lakh'), rupees(34000000));
      expect(text('nau sau ninyanwe'), rupees(999));
      expect(text('gyarah sau'), rupees(1100));
    });

    test('compound quantities before a multiplier', () {
      expect(text('ek sau pachas crore'), rupees(1500000000));
      expect(text('teen hazar crore'), rupees(30000000000));
      expect(field('pachas hazar crore'), rupees(500000000000));
      expect(field('ek sau pachas hazar'), rupees(150000));
      expect(text('pachees sau crore'), rupees(25000000000));
      expect(field('sau hazar'), rupees(100000));
    });

    test('fractions and decimal quantities', () {
      expect(text('ڈیڑھ لاکھ'), rupees(150000));
      expect(text('dhai hazar'), rupees(2500));
      expect(text('sawa lakh'), rupees(125000));
      expect(text('sawa 2 lakh'), rupees(225000));
      expect(text('paune sau'), rupees(75));
      expect(text('sarhe gyarah lakh'), rupees(1150000));
      expect(text('derh lakh crore'), none(AmountAbsence.outOfRange));
      expect(text('derh sau hazar'), rupees(150000));
      expect(text('1.5 lac'), rupees(150000));
      expect(text('0.5 lakh'), rupees(50000));
      expect(text('2.25 crores'), rupees(22500000));
    });

    test('digits, units and paisa', () {
      expect(text('Rs 1,500.50'), paisa(150050));
      expect(text('ek hazar 500.50'), paisa(150050));
      expect(text('Rs.25,000'), rupees(25000));
      expect(text('/- 500'), rupees(500));
      expect(text('500 rupay only'), rupees(500));
      expect(text('pachas rupay bees paise'), paisa(5020));
      expect(text('50 rupay 5 paise sirf'), paisa(5005));
      expect(field('0300'), rupees(300));
    });

    test('English words', () {
      expect(field('one hundred and fifty thousand'), rupees(150000));
      expect(text('twenty-one thousand'), rupees(21000));
      expect(text('twenty one thousand'), rupees(21000));
      expect(text('ninety nine'), rupees(99));
      expect(text('twenty one hundred'), rupees(2100));
      expect(field('one thousand and five'), rupees(1005));
      expect(text('five million two hundred thousand'), rupees(5200000));
    });

    test('free-text words after a cue', () {
      expect(text('sawa do lakh'), rupees(225000));
      expect(text('paune do lakh'), rupees(175000));
      expect(text('Rs do hazar'), rupees(2000));
      expect(text('50k'), rupees(50000));
      expect(field('50 k'), rupees(50000));
      expect(field('5m'), rupees(5000000));
    });

    test('zero only on its own', () {
      expect(text('0'), rupees(0));
      expect(text('sifar rupay'), rupees(0));
      expect(text('sifar rupay pachas paise'), paisa(50));
    });

    test('direction marks, joiners and keyboard letters', () {
      final rlm = String.fromCharCode(0x200F);
      final alm = String.fromCharCode(0x061C);
      expect(text('$rlmپچاس$alm ہزار'), rupees(50000));
      expect(text('تین هزار'), rupees(3000));
      expect(
        text('دو ہزار ${String.fromCharCode(0x06D3)}'),
        isA<AmountAmbiguous>(),
      );
    });
  });

  group('refuses as ambiguous', () {
    void expectReason(
      AmountAmbiguity reason,
      List<String> fields, [
      List<String> texts = const [],
    ]) {
      for (final input in fields) {
        expect(field(input), ambiguous(reason), reason: input);
      }
      for (final input in texts) {
        expect(text(input), ambiguous(reason), reason: input);
      }
    }

    test('refused words', () {
      expectReason(AmountAmbiguity.refusedWord, [
        'aadha lakh',
        'lakhon rupay',
        'do lakh aur pachas hazar',
        'sare do lakh',
        'do point paanch lakh',
        '50b',
      ]);
    });

    test('foreign currencies', () {
      expectReason(AmountAmbiguity.foreignCurrency, [
        r'$500',
        '500 dollars',
        '۵۰۰ ڈالر',
        '₹500',
      ]);
    });

    test('unknown words and signs', () {
      expectReason(AmountAmbiguity.unknownWord, [
        'chaleess hazar',
        '500-600',
        '500!',
        'Rs 500 (rent)',
        'پچاس ہزار۔',
        'lakh.',
        '1,500,',
        'twenty-',
        '500 é',
        '5 / 2',
      ]);
    });

    test('grouping', () {
      expectReason(AmountAmbiguity.grouping, [
        '1,5,000',
        '15,00',
        '1,2345',
        '1234,567',
        '1.500',
        '12,345,67,890',
      ]);
    });

    test('leading zeros in free text', () {
      expectReason(AmountAmbiguity.leadingZero, [], ['0300', 'Rs 05,000']);
    });

    test('free-text words', () {
      expectReason(AmountAmbiguity.freeTextWord, [], [
        'do hazar',
        '50 k',
        'k 50',
        '5m',
        '5 cr',
        'one hundred and fifty',
        'sattar hazar',
      ]);
    });

    test('markers out of place', () {
      expectReason(AmountAmbiguity.misplacedMarker, [
        '2 lakh rupay 50 hazar',
        '50 paise',
        'Rs 50 paise',
        'rupay 20 paise',
        '150 rupay 150 paise',
        '150 rupay 0 paise',
        '150 rupay 1.5 paise',
        'pachas hazar paise',
        '150.50 rupay 20 paise',
        'pachas sirf hazar',
        'paise 50 rupay',
      ]);
    });

    test('fractions out of place', () {
      expectReason(AmountAmbiguity.misplacedFraction, [
        'sawa do lakh pachas hazar',
        'ek lakh sawa do hazar',
        'sarhe do lakh',
        'sarhe lakh',
        'paune ek lakh',
        'sawa 0 lakh',
        'sawa 2.5 lakh',
        'derh',
        'sawa',
        'sawa do',
        'derh 2 lakh',
        'derh lakh hazar',
        '2.5 lakh 30 hazar',
        'ek lakh 1.5 hazar',
      ]);
    });

    test('numbers with no multiplier between them', () {
      expectReason(AmountAmbiguity.adjacentNumbers, [
        'do pachas',
        '2 50',
        'twenty twenty',
        '150 000',
      ]);
    });

    test('bare multipliers in free text', () {
      expectReason(AmountAmbiguity.bareMultiplier, [], ['lakh', 'sau crore']);
      expect(text('lakh rupay'), rupees(100000));
      expect(field('lakh'), rupees(100000));
    });

    test('order', () {
      expectReason(AmountAmbiguity.order, [
        'pachas hazar do lakh',
        'do hazar do lakh',
        'ek hazar paanch sau crore',
        'pachees sau pachas crore',
        'das sau pachas hazar',
        'hazar hazar',
        'hazar sau',
        'ek lakh hazar',
        'ek hazar sifar',
        'sifar lakh',
        'lakhs',
        'm',
        'k',
        'mn',
        'one million and fifty thousand',
        'one thousand and',
        'and fifty',
        'one hundred and lakh',
        'ek lakh 500 hazar',
        'ek hazar 1500',
        'lakh hazar crore',
      ]);
    });
  });

  group('finds nothing', () {
    test('empty', () {
      expect(field(''), none(AmountAbsence.empty));
      expect(
        text(' \t${String.fromCharCode(0xA0)} '),
        none(AmountAbsence.empty),
      );
      expect(text(String.fromCharCode(0x200E)), none(AmountAbsence.empty));
    });

    test('no amount', () {
      for (final input in ['kal milte hain', 'Rs', 'lakhon', r'$', 'paise']) {
        expect(text(input), none(AmountAbsence.noAmount), reason: input);
      }
    });

    test('negative', () {
      for (final input in ['-500', 'Rs -500', '−500', '- lakh', 'only -5']) {
        expect(field(input), none(AmountAbsence.negative), reason: input);
      }
    });

    test('out of range', () {
      expect(field('999,999,999,999.99'), paisa(Money.maxValue.paisa));
      expect(field('1,000,000,000,000'), none(AmountAbsence.outOfRange));
      expect(field('ek lakh crore'), none(AmountAbsence.outOfRange));
      expect(
        field('999,999,999,999 rupay 99 paise'),
        paisa(Money.maxValue.paisa),
      );
      expect(
        field('1,000,000,000,000 rupay 1 paisa'),
        none(AmountAbsence.outOfRange),
      );
    });

    test('below a paisa', () {
      expect(field('1.23456789 lakh'), none(AmountAbsence.belowPaisa));
      expect(field('0.000000001 lakh'), none(AmountAbsence.belowPaisa));
      expect(field('0.0000001 lakh'), paisa(1));
    });
  });

  group('results', () {
    test('compare by value and describe themselves', () {
      expect(rupees(5), rupees(5));
      expect(rupees(5).hashCode, rupees(5).hashCode);
      expect(rupees(5), isNot(rupees(6)));
      expect(rupees(5).toString(), 'AmountFound(500 paisa)');
      const a = AmountAmbiguous(AmountAmbiguity.order);
      expect(a, ambiguous(AmountAmbiguity.order));
      expect(a.hashCode, AmountAmbiguity.order.hashCode);
      expect(a, isNot(ambiguous(AmountAmbiguity.grouping)));
      expect(a.toString(), 'AmountAmbiguous(order)');
      const n = AmountNotFound(AmountAbsence.empty);
      expect(n, none(AmountAbsence.empty));
      expect(n.hashCode, AmountAbsence.empty.hashCode);
      expect(n, isNot(none(AmountAbsence.negative)));
      expect(n.toString(), 'AmountNotFound(empty)');
    });

    test('the lexicon is not reviewed yet', () {
      expect(amountLexiconReviewed, isFalse);
      expect(amountLexiconVersion, 1);
    });
  });
}
