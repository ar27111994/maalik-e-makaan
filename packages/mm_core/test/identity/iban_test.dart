import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('Pakistani IBANs', () {
    test('accept valid IBANs in any spacing/case', () {
      for (final input in [
        'PK36SCBL0000001123456702',
        'pk36 scbl 0000 0011 2345 6702',
        'PK36-SCBL-0000-0011-2345-6702',
        'PK56MEZN0001234567890123',
        'PK72HABB0012345678901234',
        'PK46UNIL00A1B2C3D4E5F6G7',
      ]) {
        expect(Iban.tryParse(input), isNotNull, reason: input);
      }
    });

    test('exposes bank code, name and formatting', () {
      final iban = Iban.parse('PK36SCBL0000001123456702');
      expect(iban.value, 'PK36SCBL0000001123456702');
      expect(iban.countryCode, 'PK');
      expect(iban.bankCode, 'SCBL');
      expect(iban.bankName, 'Standard Chartered');
      expect(iban.formatted, 'PK36 SCBL 0000 0011 2345 6702');
      expect(iban.masked, 'PK36 •••• •••• •••• •••• 6702');
      expect('$iban', iban.formatted);
      expect(Iban.parse('PK56MEZN0001234567890123').bankName, 'Meezan Bank');
    });

    test('unknown bank codes have no name', () {
      // Valid checksum with an unlisted bank code.
      final iban = Iban.tryParse('PK94ZZZZ0000000000000001')!;
      expect(iban.bankCode, 'ZZZZ');
      expect(iban.bankName, isNull);
      expect(Iban.parse('PK46UNIL00A1B2C3D4E5F6G7').bankName, 'UBL');
    });

    test('reject bad checksums and structure', () {
      for (final bad in [
        'PK24MEZN0001234567890123', // checksum
        'PK36SCBL000000112345670', // 23 chars
        'PK36SCBL00000011234567020', // 25 chars
        'PK36SCB10000001123456702', // digit in bank code
        'PK3XSCBL0000001123456702',
        'PK36SCBL00000011234567!2',
        '',
        'PK',
      ]) {
        expect(Iban.tryParse(bad), isNull, reason: bad);
      }
      expect(() => Iban.parse('nope'), throwsFormatException);
    });
  });

  group('foreign IBANs', () {
    test('rejected by default, accepted when allowed', () {
      expect(Iban.tryParse('GB82WEST12345698765432'), isNull);
      final gb = Iban.tryParse('GB82WEST12345698765432', allowForeign: true)!;
      expect(gb.countryCode, 'GB');
      expect(gb.bankCode, isNull);
      expect(gb.bankName, isNull);
      expect(gb.formatted, 'GB82 WEST 1234 5698 7654 32');
      expect(gb.masked, 'GB82 •••• •••• •••• ••54 32');
      expect(
        Iban.tryParse('DE89370400440532013000', allowForeign: true),
        isNotNull,
      );
      expect(
        Iban.tryParse('DE89370400440532013001', allowForeign: true),
        isNull,
      );
    });
  });

  test('hasValidChecksum guards odd characters and short input', () {
    expect(Iban.hasValidChecksum('PK36'), isFalse);
    expect(Iban.hasValidChecksum('PK36SCBL000000112345670!'), isFalse);
    expect(Iban.hasValidChecksum('PK36SCBL0000001123456702'), isTrue);
  });

  test('equality', () {
    expect(
      Iban.parse('PK36 SCBL 0000 0011 2345 6702'),
      Iban.parse('PK36SCBL0000001123456702'),
    );
    expect(
      Iban.parse('PK36SCBL0000001123456702').hashCode,
      Iban.parse('pk36scbl0000001123456702').hashCode,
    );
    expect(Iban.parse('PK36SCBL0000001123456702') == Object(), isFalse);
  });
}
