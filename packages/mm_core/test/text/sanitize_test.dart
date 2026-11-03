import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeSingleLine', () {
    test('collapses whitespace and trims', () {
      expect(sanitizeSingleLine('  Ali   Khan \n\t Raza  '), 'Ali Khan Raza');
      expect(sanitizeSingleLine('a\r\nb\rc'), 'a b c');
      expect(sanitizeSingleLine('a\u00A0b\u2003c\u3000d'), 'a b c d');
      expect(sanitizeSingleLine('a\u2028b\u2029c'), 'a b c');
    });

    test('strips control, bidi-override and invisible characters', () {
      // "Trojan Source" style override that would visually reverse text.
      expect(sanitizeSingleLine('Rent\u202E 0005 sR\u202C'), 'Rent 0005 sR');
      expect(sanitizeSingleLine('a\u2066b\u2069c'), 'abc');
      expect(sanitizeSingleLine('a\u0000b\u0007c\u007Fd\u0085e'), 'abcde');
      expect(sanitizeSingleLine('pay\u200Bpal'), 'paypal');
      expect(sanitizeSingleLine('\uFEFFname'), 'name');
      expect(sanitizeSingleLine('soft\u00ADhyphen'), 'softhyphen');
      expect(sanitizeSingleLine('x\uFDD0y\uFFFEz'), 'xyz');
    });

    test('keeps Urdu joiners, directional marks and emoji intact', () {
      const urdu = 'مالکِ\u200Cمکان';
      expect(sanitizeSingleLine(urdu), urdu);
      expect(sanitizeSingleLine('\u200Fسلام\u200E'), '\u200Fسلام\u200E');
      const family = '👨\u200D👩\u200D👧';
      expect(sanitizeSingleLine(family), family);
    });

    test('truncates on grapheme boundaries', () {
      expect(sanitizeSingleLine('abcdef', maxLength: 3), 'abc');
      expect(sanitizeSingleLine('ab cdef', maxLength: 3), 'ab');
      const family = '👨\u200D👩\u200D👧';
      expect(sanitizeSingleLine('${family}x', maxLength: 1), family);
      expect(sanitizeSingleLine('abc', maxLength: 10), 'abc');
      expect(sanitizeSingleLine('abc', maxLength: 0), '');
      expect(() => sanitizeSingleLine('a', maxLength: -1), throwsArgumentError);
    });
  });

  group('sanitizeMultiline', () {
    test('preserves single line breaks, collapses blank-line runs', () {
      expect(
        sanitizeMultiline('  line 1  \r\n\r\n\r\n\r\nline\t\t2\u2028line 3 '),
        'line 1\n\nline 2\nline 3',
      );
      expect(sanitizeMultiline('a\u202Eb\nc'), 'ab\nc');
      expect(sanitizeMultiline('abcdef\nxyz', maxLength: 5), 'abcde');
    });
  });

  group('helpers', () {
    test('sanitizeOptional returns null for blank input', () {
      expect(sanitizeOptional(null), isNull);
      expect(sanitizeOptional('   \u200B '), isNull);
      expect(sanitizeOptional(' x '), 'x');
      expect(sanitizeOptional('xyz', maxLength: 2), 'xy');
    });

    test('containsUnsafeCharacters ignores ordinary whitespace', () {
      expect(containsUnsafeCharacters('a b\tc\nd\r\n'), isFalse);
      expect(containsUnsafeCharacters('a\u202Eb'), isTrue);
      expect(containsUnsafeCharacters('a\u0001b'), isTrue);
      expect(containsUnsafeCharacters('مالکِ\u200Cمکان'), isFalse);
    });

    test('graphemeLength counts user-perceived characters', () {
      expect(graphemeLength('👨\u200D👩\u200D👧'), 1);
      expect(graphemeLength('abc'), 3);
    });
  });
}
