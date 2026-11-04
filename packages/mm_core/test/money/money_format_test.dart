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
      expect(const MoneyFormat().format(rs(150000)), 'Rs 150,000');
      expect(const MoneyFormat().format(Money.zero), 'Rs 0');
      expect(
        const MoneyFormat().format(const Money.fromPaisa(150050)),
        'Rs 1,500.50',
      );
    });

    test('negative amounts carry a leading sign', () {
      expect(const MoneyFormat().format(rs(-5000)), '-Rs 5,000');
      expect(
        const MoneyFormat(language: MoneyLanguage.urdu).format(rs(-5000)),
        '-5,000 روپے',
      );
    });

    test('paisa display policies', () {
      const amount = Money.fromPaisa(123456);
      expect(
        const MoneyFormat(paisa: PaisaDisplay.always).format(rs(5)),
        'Rs 5.00',
      );
      expect(
        const MoneyFormat(paisa: PaisaDisplay.never).format(amount),
        'Rs 1,235',
      );
      expect(
        const MoneyFormat(paisa: PaisaDisplay.never)
            .format(const Money.fromPaisa(123449)),
        'Rs 1,234',
      );
    });

    test('currency display and grouping options', () {
      expect(
        const MoneyFormat(currency: CurrencyDisplay.code).format(rs(2000)),
        'PKR 2,000',
      );
      expect(
        const MoneyFormat(currency: CurrencyDisplay.none).format(rs(2000)),
        '2,000',
      );
      expect(
        const MoneyFormat(grouping: DigitGrouping.southAsian)
            .format(rs(150000)),
        'Rs 1,50,000',
      );
    });

    test('Urdu places the unit after the amount, optionally native digits', () {
      expect(
        const MoneyFormat(language: MoneyLanguage.urdu).format(rs(5000)),
        '5,000 روپے',
      );
      expect(
        const MoneyFormat(
          language: MoneyLanguage.urdu,
          nativeDigits: true,
        ).format(rs(5000)),
        '۵,۰۰۰ روپے',
      );
      // Native digits only apply to Urdu.
      expect(const MoneyFormat(nativeDigits: true).format(rs(5)), 'Rs 5');
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
      expect(compact.format(rs(99999)), 'Rs 99,999');
    });

    test('lakh with up to two trimmed decimals', () {
      expect(compact.format(rs(100000)), 'Rs 1 lakh');
      expect(compact.format(rs(150000)), 'Rs 1.5 lakh');
      expect(compact.format(rs(1234567)), 'Rs 12.35 lakh');
      expect(compact.format(rs(2350000)), 'Rs 23.5 lakh');
      expect(compact.format(rs(105000)), 'Rs 1.05 lakh');
    });

    test('crore, including promotion when lakh rounds to 100', () {
      expect(compact.format(rs(10000000)), 'Rs 1 crore');
      expect(compact.format(rs(12500000)), 'Rs 1.25 crore');
      expect(compact.format(rs(9999999)), 'Rs 1 crore');
      expect(compact.format(rs(1500000000)), 'Rs 150 crore');
      expect(compact.format(rs(-250000)), '-Rs 2.5 lakh');
    });

    test('Urdu compact units', () {
      expect(compactUrdu.format(rs(150000)), '1.5 لاکھ روپے');
      expect(compactUrdu.format(rs(12500000)), '1.25 کروڑ روپے');
    });

    test('grouping still applies to large crore values', () {
      expect(compact.format(rs(123456000000)), 'Rs 12,345.6 crore');
    });
  });
}
