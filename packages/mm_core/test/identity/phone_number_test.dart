import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('Pakistani mobile numbers', () {
    test('normalise every common way of writing them', () {
      for (final input in [
        '03001234567',
        '0300-1234567',
        '0300 123 4567',
        '3001234567',
        '+92 300 1234567',
        '+923001234567',
        '00923001234567',
        '923001234567',
        '(0300) 1234567',
        '۰۳۰۰۱۲۳۴۵۶۷',
      ]) {
        final phone = PhoneNumber.tryParse(input);
        expect(phone?.e164, '+923001234567', reason: input);
        expect(phone?.type, PhoneNumberType.mobile, reason: input);
      }
    });

    test('formats for display, WhatsApp and dialling', () {
      final phone = PhoneNumber.fromE164('+923001234567');
      expect(phone.national, '0300 1234567');
      expect(phone.international, '+92 300 1234567');
      expect(phone.digits, '923001234567');
      expect(phone.telUri.toString(), 'tel:+923001234567');
      expect(phone.isMobile && phone.isPakistani, isTrue);
      expect('$phone', '+923001234567');
    });

    test('warns (but accepts) unallocated 3XX prefixes', () {
      expect(PhoneNumber.tryParse('03551234567')!.hasKnownMobilePrefix, isTrue);
      expect(PhoneNumber.tryParse('03491234567')!.hasKnownMobilePrefix, isTrue);
      expect(
        PhoneNumber.tryParse('03701234567')!.hasKnownMobilePrefix,
        isFalse,
      );
      expect(
        PhoneNumber.tryParse('03991234567')!.hasKnownMobilePrefix,
        isFalse,
      );
    });

    test('rejects wrong lengths', () {
      for (final bad in [
        '0300123456',
        '030012345678',
        '300123456',
        '+92300123',
      ]) {
        expect(PhoneNumber.tryParse(bad), isNull, reason: bad);
      }
    });
  });

  group('landlines', () {
    test('Lahore and Islamabad numbers', () {
      final lahore = PhoneNumber.tryParse('042-35761234')!;
      expect(lahore.e164, '+924235761234');
      expect(lahore.type, PhoneNumberType.landline);
      expect(lahore.national, '04235761234');
      expect(lahore.international, '+92 4235761234');
      expect(lahore.hasKnownMobilePrefix, isTrue);
      expect(PhoneNumber.tryParse('051-9252823')!.e164, '+92519252823');
      expect(PhoneNumber.tryParse('021-111-123-456')!.e164, '+9221111123456');
    });

    test('rejects implausible landlines', () {
      expect(PhoneNumber.tryParse('042-123'), isNull);
      expect(PhoneNumber.tryParse('0421234567890'), isNull);
      expect(PhoneNumber.tryParse('+92 0300 1234567'), isNull);
    });
  });

  group('international numbers', () {
    test('accepts E.164 abroad', () {
      final uk = PhoneNumber.tryParse('+44 7700 900123')!;
      expect(uk.e164, '+447700900123');
      expect(uk.type, PhoneNumberType.international);
      expect(uk.isPakistani, isFalse);
      expect(uk.national, '+447700900123');
      expect(uk.international, '+447700900123');
      expect(PhoneNumber.tryParse('00971501234567')!.e164, '+971501234567');
    });

    test('rejects too short, too long and zero country codes', () {
      expect(PhoneNumber.tryParse('+1234567'), isNull);
      expect(PhoneNumber.tryParse('+1234567890123456'), isNull);
      expect(PhoneNumber.tryParse('+0123456789'), isNull);
    });
  });

  group('malformed input', () {
    for (final bad in [
      '',
      '   ',
      'call me',
      '0300-12a4567',
      '03+001234567',
      '++923001234567',
      '1234567890',
      '0',
      '--',
    ]) {
      test('"$bad"', () => expect(PhoneNumber.tryParse(bad), isNull));
    }

    test('fromE164 requires canonical form', () {
      expect(() => PhoneNumber.fromE164('03001234567'), throwsFormatException);
      expect(() => PhoneNumber.fromE164('nope'), throwsFormatException);
    });
  });

  test('value equality', () {
    expect(
      PhoneNumber.tryParse('03001234567'),
      PhoneNumber.tryParse('+92 300 1234567'),
    );
    expect(
      PhoneNumber.tryParse('03001234567').hashCode,
      PhoneNumber.tryParse('+923001234567').hashCode,
    );
    expect(PhoneNumber.tryParse('03001234567') == Object(), isFalse);
  });
}
