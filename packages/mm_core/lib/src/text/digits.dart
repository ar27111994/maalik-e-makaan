/// Digit normalisation for input typed on Urdu, Arabic or Persian keyboards.
///
/// Pakistani users frequently type numbers with the Urdu keyboard, which
/// produces Extended Arabic-Indic digits (`۰۱۲۳۴۵۶۷۸۹`, U+06F0–U+06F9). Some
/// keyboards emit Arabic-Indic digits (`٠١٢٣٤٥٦٧٨٩`, U+0660–U+0669) instead.
/// Every parser in this package runs input through [normalizeDigits] first so
/// that `۰۳۰۰۱۲۳۴۵۶۷` and `03001234567` are treated identically.
library;

const int _asciiZero = 0x30;
const int _arabicIndicZero = 0x0660;
const int _extendedArabicIndicZero = 0x06F0;
const int _fullwidthZero = 0xFF10;

/// Returns [input] with every Arabic-Indic, Extended Arabic-Indic (Urdu) and
/// full-width digit replaced by its ASCII equivalent. All other characters
/// are preserved unchanged.
String normalizeDigits(String input) {
  if (input.isEmpty) return input;
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    buffer.writeCharCode(_asciiDigitFor(rune) ?? rune);
  }
  return buffer.toString();
}

/// Whether [input] consists solely of ASCII digits (and is non-empty).
bool isAsciiDigits(String input) {
  if (input.isEmpty) return false;
  for (final unit in input.codeUnits) {
    if (unit < _asciiZero || unit > _asciiZero + 9) return false;
  }
  return true;
}

/// Extracts only the digits from [input] (after [normalizeDigits]).
String digitsOnly(String input) {
  final normalized = normalizeDigits(input);
  final buffer = StringBuffer();
  for (final unit in normalized.codeUnits) {
    if (unit >= _asciiZero && unit <= _asciiZero + 9) {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

int? _asciiDigitFor(int rune) {
  for (final zero in const [
    _arabicIndicZero,
    _extendedArabicIndicZero,
    _fullwidthZero,
  ]) {
    if (rune >= zero && rune <= zero + 9) return _asciiZero + (rune - zero);
  }
  return null;
}
