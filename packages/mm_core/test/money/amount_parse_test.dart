// Unit tests of parseAmount: every reading and every refusal, with its
// reason. contracts/amount_vectors.json (test/contract/) holds the cases
// every port must agree on; these pin the Dart reasons and edges.
import 'package:mm_core/mm_core.dart';
import 'package:mm_core/src/money/amount_lexicon.g.dart';
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
      expect(text('arhai lakh'), rupees(250000));
      expect(text('اڑھائی لاکھ'), rupees(250000));
      expect(text('ساڑے تین ہزار'), rupees(3500));
      expect(field('sarhe 11 lakh'), rupees(1150000));
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
      expect(field('Rs 500/='), rupees(500));
      expect(
        field(
          '${String.fromCharCode(0xFF15)}0${String.fromCharCode(0xFF0C)}000',
        ),
        rupees(50000),
      );
      expect(field('1${String.fromCharCode(0xFF0E)}5 lakh'), rupees(150000));
      expect(field('2.5 cr'), rupees(25000000));
    });

    test('a rupee word after a number pins it as rupees', () {
      expect(text('ek lakh bees rupay'), rupees(100020));
      expect(text('ایک لاکھ بیس روپے'), rupees(100020));
      expect(field('1 crore 20/-'), rupees(10000020));
      expect(field('ek lakh bees rupay pachas paise'), paisa(10002050));
      expect(field('ek lakh 500'), rupees(100500));
      expect(field('1 crore 500'), rupees(10000500));
      expect(field('1 million 1000'), rupees(1001000));
      expect(field('das hazar paanch'), rupees(10005));
    });

    test('long digit runs cost no more than short ones', () {
      final stopwatch = Stopwatch()..start();
      final nines = '9' * 1000000;
      expect(field(nines), none(AmountAbsence.outOfRange));
      expect(field('0.${'0' * 1000000}1 lakh'), none(AmountAbsence.belowPaisa));
      expect(field('${'0' * 1000000}5'), rupees(5));
      expect(field('1.5${'0' * 1000000} lakh'), rupees(150000));
      expect(field('$nines.$nines lakh'), none(AmountAbsence.belowPaisa));
      expect(field('$nines lakh'), none(AmountAbsence.outOfRange));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('long digit runs read as their exact value', () {
      expect(field('1.000000000000001 lakh'), none(AmountAbsence.belowPaisa));
      expect(field('1.00000000000001 کھرب'), none(AmountAbsence.belowPaisa));
      expect(field('0.0000000000001 کھرب'), paisa(1));
      expect(field('${'0' * 20}500'), rupees(500));
      expect(field('100000000000000'), none(AmountAbsence.outOfRange));
      expect(
        field('ek hazar 99999999999999.5'),
        ambiguous(AmountAmbiguity.order),
      );
      expect(
        field('ek lakh 20.50'),
        ambiguous(AmountAmbiguity.elidedMultiplier),
      );
    });

    // A decimal is read exactly however many places it has, up to the most
    // any chain of multipliers can make whole paisa; nothing stands in for
    // its digits. '0.0000000000000001 sau hazar lakh crore' once read as
    // Rs 100: a stand-in for the 16 places reached the result.
    group('long decimals under multipliers read exactly', () {
      // One significant digit after `places` decimal places.
      String tiny(int places) => '0.${'0' * (places - 1)}1';
      // Every one of `places` decimal places significant.
      String full(int places) => '0.${'1' * places}';
      const one = 'lakh';
      const two = 'hazar lakh';
      const four = 'sau hazar lakh crore';
      const seven = 'sau hazar lakh million crore billion کھرب';
      void both(String input, AmountReading expected) {
        expect(field(input), expected, reason: '$input (field)');
        expect(text(input), expected, reason: '$input (text)');
      }

      test('the reported inputs', () {
        both('${tiny(16)} $four', paisa(1000));
        both('${tiny(15)} $four', paisa(10000));
      });

      test('14, 15, 16 and 40 places alone', () {
        for (final places in [14, 15, 16, 40]) {
          both(tiny(places), ambiguous(AmountAmbiguity.grouping));
          both(full(places), ambiguous(AmountAmbiguity.grouping));
        }
      });

      test('under one, two and four multipliers', () {
        for (final places in [14, 15, 16, 40]) {
          both('${tiny(places)} $one', none(AmountAbsence.belowPaisa));
          both('${tiny(places)} $two', none(AmountAbsence.belowPaisa));
          both('${full(places)} $one', none(AmountAbsence.belowPaisa));
          both('${full(places)} $two', none(AmountAbsence.belowPaisa));
        }
        both('${tiny(14)} $four', paisa(100000));
        both('${tiny(40)} $four', none(AmountAbsence.belowPaisa));
        both('${full(14)} $four', none(AmountAbsence.outOfRange));
        both('${full(15)} $four', none(AmountAbsence.outOfRange));
        both('${full(16)} $four', none(AmountAbsence.outOfRange));
        both('${full(40)} $four', none(AmountAbsence.belowPaisa));
        both('${full(40)} $seven', none(AmountAbsence.outOfRange));
      });

      test('significant digits after leading zeros', () {
        // 19 places, 14 of them significant, times 10^17: whole paisa.
        both('0.0000012345678901234 $four', paisa(12345678901234));
        both('0.00000123456789012345 $four', none(AmountAbsence.belowPaisa));
        both('0.0000123456789012345 $four', none(AmountAbsence.outOfRange));
        both('0.00001${'0' * 14}1 $four', none(AmountAbsence.belowPaisa));
        both('0.00001${'0' * 13}1 $four', none(AmountAbsence.outOfRange));
      });

      test('the most places any multipliers make whole paisa', () {
        both('${tiny(40)} $seven', paisa(100000));
        both('${tiny(45)} $seven', paisa(1));
        both('${tiny(46)} $seven', none(AmountAbsence.belowPaisa));
        both('${tiny(45)}${'0' * 1000} $seven', paisa(1));
        both('${tiny(1000)} $seven', none(AmountAbsence.belowPaisa));
      });

      test('with a currency marker', () {
        both('Rs ${tiny(16)} $four', paisa(1000));
        both('${tiny(16)} $four rupay', paisa(1000));
        both('Rs. ${tiny(16)} $four /-', paisa(1000));
        both('Rs ${full(40)} $four', none(AmountAbsence.belowPaisa));
      });

      test('after a fraction, which takes only a whole number', () {
        for (final places in [14, 15, 16, 40]) {
          both(
            'sawa ${tiny(places)} $four',
            ambiguous(AmountAmbiguity.misplacedFraction),
          );
          both(
            'derh ${tiny(places)} $four',
            ambiguous(AmountAmbiguity.misplacedFraction),
          );
        }
      });

      test('as the paise or the units of an amount', () {
        expect(
          field('ek hazar rupay ${tiny(16)} paise'),
          ambiguous(AmountAmbiguity.misplacedMarker),
        );
        expect(
          field('ek hazar ${tiny(16)}'),
          ambiguous(AmountAmbiguity.grouping),
        );
      });
    });

    // A whole part of more than 14 digits is at least Rs 10^14, wherever it
    // stands (a quantity, the units, the number after a fraction, or even the
    // paise, at 10^14 paisa): every reading is above the maximum.
    test(
      'a whole part beyond 14 digits is out of range wherever it stands',
      () {
        final big = '1${'0' * 14}';
        expect(field(big), none(AmountAbsence.outOfRange));
        expect(field('$big.5 rupay 50 paise'), none(AmountAbsence.outOfRange));
        expect(field('Rs 5 $big paise'), none(AmountAbsence.outOfRange));
        expect(field('5 $big'), none(AmountAbsence.outOfRange));
        expect(field('ek hazar $big'), none(AmountAbsence.outOfRange));
        expect(field('sawa $big lakh'), none(AmountAbsence.outOfRange));
        expect(field('$big.25 lakh'), none(AmountAbsence.outOfRange));
        expect(text('$big hazar'), none(AmountAbsence.outOfRange));
        // A word or sign the reader refuses is still the reason given first.
        expect(field('$big aed'), ambiguous(AmountAmbiguity.foreignCurrency));
        expect(text('0$big'), ambiguous(AmountAmbiguity.leadingZero));
        expect(field('-$big'), none(AmountAbsence.negative));
        // 14 digits are read exactly, as any other number.
        expect(field('99999999999999'), none(AmountAbsence.outOfRange));
        expect(field('9999999999.99'), paisa(999999999999));
        expect(
          field('ek hazar 99999999999999'),
          ambiguous(AmountAmbiguity.order),
        );
      },
    );

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
      expect(text('PKR do lakh'), rupees(200000));
      expect(text('₨ do hazar'), rupees(2000));
      expect(text('Rs سوا دو لاکھ'), rupees(225000));
      expect(text('5mn'), rupees(5000000));
      expect(text('2bn'), rupees(2000000000));
      expect(field('5 mn'), rupees(5000000));
      expect(field('nawasi hazar'), rupees(89000));
      expect(text('50k'), rupees(50000));
      expect(field('50 k'), rupees(50000));
      expect(field('5m'), rupees(5000000));
    });

    test('zero only as the whole rupee amount', () {
      expect(text('0'), rupees(0));
      expect(text('sifar rupay'), rupees(0));
      expect(text('sifar rupay pachas paise'), paisa(50));
    });

    test('direction marks, joiners and keyboard letters', () {
      final rlm = String.fromCharCode(0x200F);
      final alm = String.fromCharCode(0x061C);
      expect(text('$rlmپچاس$alm ہزار'), rupees(50000));
      String c(int code) => String.fromCharCode(code);
      // Zero-width space, word joiner, soft hyphen, the byte-order mark, the
      // bidi embeddings, overrides and isolates: copying carries them.
      expect(text('5${c(0x200B)}0 hazar'), rupees(50000));
      expect(text('50${c(0x2068)} hazar${c(0x2069)}'), rupees(50000));
      expect(text('${c(0x2066)}500${c(0x2069)}'), rupees(500));
      expect(text('${c(0x2067)}پچاس ہزار${c(0x2069)}'), rupees(50000));
      expect(text('50 ${c(0x202B)}hazar${c(0x202C)}'), rupees(50000));
      expect(text('${c(0x202A)}${c(0x202D)}${c(0x202E)}500'), rupees(500));
      expect(text('50${c(0x00AD)}hazar'), rupees(50000));
      expect(text('pach${c(0x00AD)}as hazar'), rupees(50000));
      expect(text('${c(0xFEFF)}500'), rupees(500));
      expect(text('ek${c(0x2060)} lakh'), rupees(100000));
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
        'Rs-500',
        'Rs 500.',
        '500 /x',
      ]);
    });

    test('grouping', () {
      expectReason(
        AmountAmbiguity.grouping,
        [
          '1,5,000',
          '15,00',
          '1,2345',
          '1234,567',
          '1.500',
          '12,345,67,890',
          '0,500',
          '0,050',
          '0,000,001',
          '00,500',
          'Rs 05,000',
        ],
        ['0,500', 'Rs 05,000'],
      );
    });

    test('leading zeros in free text', () {
      expectReason(AmountAmbiguity.leadingZero, [], ['0300', '0500 rupay']);
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
        'rupay do',
        'روپے دو',
        'rupees do',
        'rs do',
        'pkr do',
        '/- do',
        'روپے دو ہزار',
        'Rs do sawa',
        '5 mn',
        '50 hazar mn',
        '5000 mn',
        '2 bn',
        '50 hazar bn',
        'nawasi hazar rupay',
        'نواسی ہزار روپے',
      ]);
      expectReason(AmountAmbiguity.freeTextWord, [
        'Rs 25000 Cr',
        '25,000.00 Cr',
        'Rs 5 cr',
        'PKR 2.5 cr',
      ]);
    });

    test('a lower unit that may have been left out', () {
      expectReason(
        AmountAmbiguity.elidedMultiplier,
        [
          'ek lakh bees',
          '1 lakh 20',
          '5 lakh 50',
          '1 crore 20',
          '1 crore 20 lakh 5',
          '5 lakhs 20',
          '1 million 20',
          '1 million 999',
          'ek arab 50',
          '1 arab 999',
          'ایک کھرب ننانوے',
          '1 lakh 99.5',
          'ek lakh bees only',
          'Rs ek lakh bees',
        ],
        ['das lakh pachas', 'paanch lakh pachas'],
      );
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
        'sawa 100 hazar',
        'paune 100 hazar',
        'sarhe 100 hazar',
        'sawa 200 hazar',
        'sawa 150 hazar',
        'sawa 1000 lakh',
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
        'ek million das lakh',
        '1 crore 10 million',
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
      for (final input in [
        '-500',
        'Rs -500',
        '−500',
        '- lakh',
        'only -5',
        'Rs - 500',
      ]) {
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
    // _elidedBelow has an entry for every multiplier power above hazar, and
    // _maxDecimals (45) is two plus the sum of these powers: a new power
    // changes both, and this test, in the same change.
    test('the multiplier powers the grammar is built for', () {
      final powers = {
        for (final m in amountWords.values)
          if (m.$1 == AmountWordKind.multiplier ||
              m.$1 == AmountWordKind.plural)
            m.$2,
      };
      expect(powers, {2, 3, 5, 6, 7, 9, 11});
    });

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
