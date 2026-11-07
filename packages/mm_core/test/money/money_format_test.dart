import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  const rs = Money.fromRupees;

  group('groupDigits', () {
    test('western grouping', () {
      expect(groupDigits('0', DigitGrouping.western), '0');
      expect(groupDigits('999', DigitGrouping.western), '999');
      expect(groupDigits('1000', DigitGrouping.western), '1,000');
      expect(groupDigits('1234567', DigitGrouping.western), '1,234,567');
    });

    test('South Asian lakh/crore grouping', () {
      expect(groupDigits('1000', DigitGrouping.southAsian), '1,000');
      expect(groupDigits('100000', DigitGrouping.southAsian), '1,00,000');
      expect(groupDigits('1234567', DigitGrouping.southAsian), '12,34,567');
      expect(
        groupDigits('123456789', DigitGrouping.southAsian),
        '12,34,56,789',
      );
    });
  });

  group('MoneyFormat standard', () {
    test('defaults: Rs, western grouping, no paisa for whole amounts', () {
      expect(const MoneyFormat().format(rs(150000)), 'Rs\u00A0150,000');
      expect(const MoneyFormat().format(Money.zero), 'Rs\u00A00');
      expect(
        const MoneyFormat().format(const Money.fromPaisa(150050)),
        'Rs\u00A01,500.50',
      );
    });

    test(
      'negative amounts carry a leading sign after a left-to-right mark',
      () {
        expect(MoneyFormat.leftToRightMark, '\u200E');
        expect(const MoneyFormat().format(rs(-5000)), '\u200E-Rs\u00A05,000');
        expect(
          const MoneyFormat(language: MoneyLanguage.urdu).format(rs(-5000)),
          '\u200E-5,000\u00A0روپے',
        );
        expect(
          const MoneyFormat(
            language: MoneyLanguage.urdu,
            nativeDigits: true,
          ).format(rs(-5000)),
          '\u200E-۵,۰۰۰\u00A0روپے',
        );
        expect(
          const MoneyFormat(currency: CurrencyDisplay.code).format(rs(-5000)),
          '\u200E-PKR\u00A05,000',
        );
        expect(
          const MoneyFormat(language: MoneyLanguage.urdu)
              .formatNumber(const Money.fromPaisa(-150050)),
          '\u200E-1,500.50',
        );
      },
    );

    test('the mark is the only addition, and only for negative amounts', () {
      for (final format in [
        const MoneyFormat(),
        const MoneyFormat(language: MoneyLanguage.urdu),
        const MoneyFormat(notation: MoneyNotation.compact),
      ]) {
        final positive = format.format(rs(250000));
        final negative = format.format(rs(-250000));
        expect(positive, isNot(contains(MoneyFormat.leftToRightMark)));
        expect(negative, '${MoneyFormat.leftToRightMark}-$positive');
        expect(format.format(Money.zero), isNot(startsWith('-')));
      }
    });

    test('a negative amount survives the text sanitisers, its sign intact', () {
      // The mark and the no-break space are allowed by the clean-text
      // contract (unlike bidi isolates), so a formatted amount can go into
      // a saved note or a reminder message. Sanitising before saving keeps
      // the mark and, as for any no-break space, writes an ordinary space.
      final formatted = const MoneyFormat(language: MoneyLanguage.urdu)
          .format(rs(-5000));
      expect(containsUnsafeCharacters(formatted), isFalse);
      expect(removeUnsafeCharacters(formatted), formatted);
      expect(sanitizeSingleLine(formatted), '\u200E-5,000 روپے');
    });

    test('joins the figures and the words beside them with a no-break '
        'space', () {
      expect(MoneyFormat.noBreakSpace, '\u00A0');
      const urdu = MoneyFormat(language: MoneyLanguage.urdu);
      final cases = {
        const MoneyFormat().format(rs(45000)): ['Rs', '45,000'],
        const MoneyFormat(currency: CurrencyDisplay.code).format(rs(45000)): [
          'PKR',
          '45,000',
        ],
        urdu.format(rs(45000)): ['45,000', 'روپے'],
        const MoneyFormat(notation: MoneyNotation.compact)
            .format(rs(2350000)): [
          'Rs',
          '23.5',
          'lakh',
        ],
        urdu.copyWith(notation: MoneyNotation.compact).format(rs(12500000)): [
          '1.25',
          'کروڑ',
          'روپے',
        ],
      };
      for (final MapEntry(key: formatted, value: parts) in cases.entries) {
        // No ordinary space is left to break the line at.
        expect(formatted.contains(' '), isFalse, reason: formatted);
        expect(formatted.split(MoneyFormat.noBreakSpace), parts);
      }
    });

    test('a formatted amount parses back to itself', () {
      for (final format in const [
        MoneyFormat(),
        MoneyFormat(currency: CurrencyDisplay.code),
        MoneyFormat(language: MoneyLanguage.urdu),
        MoneyFormat(grouping: DigitGrouping.southAsian),
      ]) {
        for (final amount in [rs(45000), rs(125000), rs(-5000)]) {
          expect(
            parseMoneyInput(format.format(amount), allowNegative: true),
            amount,
            reason: format.format(amount),
          );
        }
      }
    });

    test('paisa display policies', () {
      const amount = Money.fromPaisa(123456);
      expect(
        const MoneyFormat(paisa: PaisaDisplay.always).format(rs(5)),
        'Rs\u00A05.00',
      );
      expect(
        const MoneyFormat(paisa: PaisaDisplay.never).format(amount),
        'Rs\u00A01,235',
      );
      expect(
        const MoneyFormat(paisa: PaisaDisplay.never)
            .format(const Money.fromPaisa(123449)),
        'Rs\u00A01,234',
      );
    });

    test('currency display and grouping options', () {
      expect(
        const MoneyFormat(currency: CurrencyDisplay.code).format(rs(2000)),
        'PKR\u00A02,000',
      );
      expect(
        const MoneyFormat(currency: CurrencyDisplay.none).format(rs(2000)),
        '2,000',
      );
      expect(
        const MoneyFormat(grouping: DigitGrouping.southAsian)
            .format(rs(150000)),
        'Rs\u00A01,50,000',
      );
    });

    test('Urdu places the unit after the amount, optionally native digits', () {
      expect(
        const MoneyFormat(language: MoneyLanguage.urdu).format(rs(5000)),
        '5,000\u00A0روپے',
      );
      expect(
        const MoneyFormat(
          language: MoneyLanguage.urdu,
          nativeDigits: true,
        ).format(rs(5000)),
        '۵,۰۰۰\u00A0روپے',
      );
      // Native digits only apply to Urdu.
      expect(const MoneyFormat(nativeDigits: true).format(rs(5)), 'Rs\u00A05');
    });

    test('formatNumber omits the currency', () {
      expect(const MoneyFormat().formatNumber(rs(1234)), '1,234');
    });
  });

  group('MoneyFormat value semantics', () {
    const base = MoneyFormat();

    test('equal options make equal formats', () {
      // Built at run time, so not canonicalised like const instances.
      final built = MoneyFormat(grouping: DigitGrouping.values.first);
      expect(built, base);
      expect(built.hashCode, base.hashCode);
      expect(identical(built, base), isFalse);
    });

    test('each option takes part in equality', () {
      final variants = [
        base.copyWith(grouping: DigitGrouping.southAsian),
        base.copyWith(notation: MoneyNotation.compact),
        base.copyWith(currency: CurrencyDisplay.code),
        base.copyWith(paisa: PaisaDisplay.always),
        base.copyWith(language: MoneyLanguage.urdu),
        base.copyWith(nativeDigits: true),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base), reason: variant.toString());
      }
      expect(variants.toSet(), hasLength(variants.length));
      expect(base == Object(), isFalse);
    });

    test('copyWith keeps the options it is not given', () {
      const urdu = MoneyFormat(
        grouping: DigitGrouping.southAsian,
        language: MoneyLanguage.urdu,
        nativeDigits: true,
      );
      expect(urdu.copyWith(), urdu);
      final compact = urdu.copyWith(notation: MoneyNotation.compact);
      expect(compact.grouping, DigitGrouping.southAsian);
      expect(compact.language, MoneyLanguage.urdu);
      expect(compact.nativeDigits, isTrue);
      expect(compact.notation, MoneyNotation.compact);
    });

    test('toString names every option', () {
      expect(
        base.toString(),
        'MoneyFormat(western, standard, symbol, auto, english, '
        'nativeDigits: false)',
      );
    });
  });

  group('MoneyFormat compact (lakh/crore)', () {
    const compact = MoneyFormat(notation: MoneyNotation.compact);
    const compactUrdu = MoneyFormat(
      notation: MoneyNotation.compact,
      language: MoneyLanguage.urdu,
    );

    test('below one lakh is written in full', () {
      expect(compact.format(rs(99999)), 'Rs\u00A099,999');
    });

    test('lakh with up to two trimmed decimals', () {
      expect(compact.format(rs(100000)), 'Rs\u00A01\u00A0lakh');
      expect(compact.format(rs(150000)), 'Rs\u00A01.5\u00A0lakh');
      expect(compact.format(rs(1234567)), 'Rs\u00A012.35\u00A0lakh');
      expect(compact.format(rs(2350000)), 'Rs\u00A023.5\u00A0lakh');
      expect(compact.format(rs(105000)), 'Rs\u00A01.05\u00A0lakh');
    });

    test('crore, including promotion when lakh rounds to 100', () {
      expect(compact.format(rs(10000000)), 'Rs\u00A01\u00A0crore');
      expect(compact.format(rs(12500000)), 'Rs\u00A01.25\u00A0crore');
      expect(compact.format(rs(9999999)), 'Rs\u00A01\u00A0crore');
      expect(compact.format(rs(1500000000)), 'Rs\u00A0150\u00A0crore');
      expect(compact.format(rs(-250000)), '\u200E-Rs\u00A02.5\u00A0lakh');
    });

    test('Urdu compact units', () {
      expect(compactUrdu.format(rs(150000)), '1.5\u00A0لاکھ\u00A0روپے');
      expect(compactUrdu.format(rs(12500000)), '1.25\u00A0کروڑ\u00A0روپے');
    });

    test('grouping still applies to large crore values', () {
      expect(compact.format(rs(123456000000)), 'Rs\u00A012,345.6\u00A0crore');
    });
  });
}
