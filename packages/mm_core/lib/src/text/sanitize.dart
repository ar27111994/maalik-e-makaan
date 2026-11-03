/// Defensive text sanitisation for every piece of free text a user can enter.
///
/// The goals are, in order:
///
/// 1. **Safety** – strip characters that can disguise content: C0/C1 control
///    characters, Unicode bidirectional *override/embedding/isolate* controls
///    (the "Trojan Source" family, U+202A–U+202E and U+2066–U+2069) and
///    invisible zero-width code points that enable look-alike spoofing on
///    receipts and reminders.
/// 2. **Fidelity** – keep everything needed to write Urdu correctly, including
///    the zero-width non-joiner (U+200C) and joiner (U+200D) and the
///    left-to-right / right-to-left marks used when mixing scripts.
/// 3. **Tidiness** – normalise exotic spaces, collapse runs of whitespace and
///    truncate on grapheme-cluster boundaries so a limit never splits a
///    character or an emoji in half.
library;

import 'package:characters/characters.dart';

/// Strips control and spoofing characters and collapses all whitespace
/// (including newlines) into single spaces, then trims.
///
/// When [maxLength] is given the result is truncated to at most that many
/// user-perceived characters (grapheme clusters).
String sanitizeSingleLine(String input, {int? maxLength}) {
  final cleaned = _clean(input, keepNewlines: false);
  final collapsed = cleaned.replaceAll(_whitespaceRun, ' ').trim();
  return _truncate(collapsed, maxLength);
}

/// Like [sanitizeSingleLine] but preserves line breaks: CRLF/CR become LF,
/// spaces around each line are trimmed, and more than one consecutive blank
/// line is collapsed into one.
String sanitizeMultiline(String input, {int? maxLength}) {
  final cleaned = _clean(input, keepNewlines: true);
  final joined = cleaned
      .split('\n')
      .map((line) => line.replaceAll(_horizontalWhitespaceRun, ' ').trim())
      .join('\n')
      .replaceAll(_threeOrMoreNewlines, '\n\n')
      .trim();
  return _truncate(joined, maxLength);
}

/// Returns `null` when [input] is `null` or sanitises to an empty string;
/// otherwise the single-line sanitised value. Handy for optional fields.
String? sanitizeOptional(String? input, {int? maxLength}) {
  if (input == null) return null;
  final value = sanitizeSingleLine(input, maxLength: maxLength);
  return value.isEmpty ? null : value;
}

/// Whether [input] contains a control, bidi-override or invisible character
/// that the sanitisers would remove. Ordinary whitespace is not "unsafe".
bool containsUnsafeCharacters(String input) => input.runes.any(_isUnsafe);

/// Counts user-perceived characters (grapheme clusters) in [input].
int graphemeLength(String input) => input.characters.length;

final RegExp _whitespaceRun = RegExp(r'\s+');
final RegExp _horizontalWhitespaceRun = RegExp(r'[ \t]+');
final RegExp _threeOrMoreNewlines = RegExp(r'\n{3,}');

const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _lineSeparator = 0x2028;
const int _paragraphSeparator = 0x2029;

String _clean(String input, {required bool keepNewlines}) {
  final buffer = StringBuffer();
  final runes = input.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    if (rune == _carriageReturn) {
      // CRLF counts as one break; a lone CR is also a break.
      if (i + 1 < runes.length && runes[i + 1] == _lineFeed) i++;
      buffer.write(keepNewlines ? '\n' : ' ');
    } else if (rune == _lineFeed ||
        rune == _lineSeparator ||
        rune == _paragraphSeparator) {
      buffer.write(keepNewlines ? '\n' : ' ');
    } else if (_isOtherWhitespace(rune)) {
      buffer.write(' ');
    } else if (!_isUnsafe(rune)) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Whitespace other than line breaks that is converted to a plain space.
bool _isOtherWhitespace(int rune) =>
    rune == 0x09 || // tab
    rune == 0x0B || // vertical tab
    rune == 0x0C || // form feed
    rune == 0x00A0 || // no-break space
    rune == 0x1680 || // ogham space mark
    (rune >= 0x2000 && rune <= 0x200A) || // en/em/thin/hair spaces
    rune == 0x202F || // narrow no-break space
    rune == 0x205F || // medium mathematical space
    rune == 0x3000; // ideographic space

const Set<int> _invisible = {
  0x00AD, // soft hyphen
  0x180E, // Mongolian vowel separator
  0x200B, // zero-width space
  0x2060, // word joiner
  0x2061, 0x2062, 0x2063, 0x2064, // invisible math operators
  0xFEFF, // byte-order mark / zero-width no-break space
  0xFFF9, 0xFFFA, 0xFFFB, // interlinear annotation controls
};

/// Characters that are always removed: controls, bidi overrides/isolates,
/// invisible spoofing characters and Unicode non-characters.
bool _isUnsafe(int rune) {
  if (rune == _lineFeed ||
      rune == _carriageReturn ||
      rune == _lineSeparator ||
      rune == _paragraphSeparator ||
      _isOtherWhitespace(rune)) {
    return false;
  }
  // C0 controls, DEL and C1 controls.
  if (rune < 0x20 || rune == 0x7F || (rune >= 0x80 && rune <= 0x9F)) {
    return true;
  }
  // Bidirectional embedding / override controls (LRE, RLE, PDF, LRO, RLO).
  if (rune >= 0x202A && rune <= 0x202E) return true;
  // Bidirectional isolates (LRI, RLI, FSI, PDI).
  if (rune >= 0x2066 && rune <= 0x2069) return true;
  if (_invisible.contains(rune)) return true;
  // Unicode non-characters (U+FDD0–U+FDEF and U+xxFFFE / U+xxFFFF).
  if (rune >= 0xFDD0 && rune <= 0xFDEF) return true;
  if ((rune & 0xFFFE) == 0xFFFE) return true;
  return false;
}

String _truncate(String input, int? maxLength) {
  if (maxLength == null) return input;
  if (maxLength < 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'must be >= 0');
  }
  final characters = input.characters;
  if (characters.length <= maxLength) return input;
  return characters.take(maxLength).toString().trimRight();
}
