import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeDigits maps Urdu, Arabic-Indic and full-width digits', () {
    expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    expect(normalizeDigits('０１２３'), '0123');
    expect(normalizeDigits('Rs ۵۰۰ only'), 'Rs 500 only');
    expect(normalizeDigits(''), '');
    expect(normalizeDigits('کرایہ'), 'کرایہ');
  });

  test('isAsciiDigits', () {
    expect(isAsciiDigits('0123'), isTrue);
    expect(isAsciiDigits(''), isFalse);
    expect(isAsciiDigits('12a'), isFalse);
    expect(isAsciiDigits('۱۲'), isFalse);
  });

  test('digitsOnly keeps only digits after normalisation', () {
    expect(digitsOnly('+92 (300) 123-4567'), '923001234567');
    expect(digitsOnly('۳۵۲۰۲-۱'), '352021');
    expect(digitsOnly('none'), '');
  });
}
