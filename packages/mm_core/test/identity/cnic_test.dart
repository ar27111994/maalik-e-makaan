import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('Cnic.tryParse', () {
    test('accepts official, compact, spaced and Urdu-digit input', () {
      for (final input in [
        '35202-1234567-1',
        '3520212345671',
        ' 35202 1234567 1 ',
        '۳۵۲۰۲-۱۲۳۴۵۶۷-۱',
      ]) {
        expect(Cnic.tryParse(input)?.digits, '3520212345671', reason: input);
      }
    });

    test(
      'rejects wrong lengths, letters, misplaced dashes and placeholders',
      () {
        for (final bad in [
          '',
          '3520212345',
          '35202123456712',
          '35202-123456-71',
          '352-0212345671',
          '35202_1234567_1',
          'ABCDE-1234567-1',
          '0000000000000',
          '1111111111111',
          '0520212345671',
          '35202-1234567-1x',
        ]) {
          expect(Cnic.tryParse(bad), isNull, reason: bad);
        }
        expect(() => Cnic.parse('123'), throwsFormatException);
      },
    );
  });

  group('Cnic presentation', () {
    final cnic = Cnic.parse('3520212345671');

    test('formats and masks', () {
      expect(cnic.formatted, '35202-1234567-1');
      expect(cnic.masked, '35202-•••••••-1');
      expect('$cnic', cnic.masked, reason: 'toString never leaks the CNIC');
    });

    test('maps every documented region and flags unknown digits', () {
      expect(cnic.region, CnicRegion.punjab);
      expect(cnic.hasKnownRegion, isTrue);
      expect(Cnic.parse('9120212345671').region, isNull);
      expect(Cnic.parse('9120212345671').hasKnownRegion, isFalse);
      for (final region in CnicRegion.values) {
        expect(CnicRegion.fromDigit(region.code), region);
      }
      expect(CnicRegion.fromDigit(0), isNull);
    });

    test('value equality', () {
      expect(Cnic.parse('35202-1234567-1'), cnic);
      expect(Cnic.parse('35202-1234567-1').hashCode, cnic.hashCode);
      expect(cnic == Object(), isFalse);
    });
  });
}
