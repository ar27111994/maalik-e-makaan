import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The longest start of [text] that holds at most [max] code points, in
/// whole characters (grapheme clusters), so a letter never loses its
/// diacritic and an emoji is never cut in half.
///
/// The database limits text with `char_length`, which counts code points,
/// while a field's `maxLength` counts characters as a reader sees them: an
/// Urdu word with diacritics, or an emoji, is one character but several
/// code points, so text a field accepts can still be too long to save.
String fitCodePoints(String text, int max) {
  if (text.runes.length <= max) return text;
  final kept = StringBuffer();
  var count = 0;
  for (final character in text.characters) {
    final size = character.runes.length;
    if (count + size > max) break;
    kept.write(character);
    count += size;
  }
  return kept.toString();
}

/// Keeps a field's text within [max] code points, as the database counts
/// its length (see [fitCodePoints]); give it beside the field's
/// `maxLength`, which counts characters. Text beyond the limit is cut, as
/// `maxLength` cuts it.
class CodePointLimit extends TextInputFormatter {
  const new(this.max);

  /// The most code points the field's column holds.
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    // A change that only adds to text already at the limit is refused, so
    // typing in the middle does not cut the end off.
    if (oldValue.text.runes.length == max &&
        newValue.text.length > oldValue.text.length) {
      return oldValue;
    }
    final text = fitCodePoints(newValue.text, max);
    int clamp(int offset) => offset < 0 ? offset : offset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: newValue.selection.copyWith(
        baseOffset: clamp(newValue.selection.baseOffset),
        extentOffset: clamp(newValue.selection.extentOffset),
      ),
    );
  }
}

/// The formatters that keep a field within [max] code points.
List<TextInputFormatter> codePointLimit(int max) => [CodePointLimit(max)];
