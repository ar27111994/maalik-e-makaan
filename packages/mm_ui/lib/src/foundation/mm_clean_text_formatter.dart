import 'package:flutter/services.dart';
import 'package:mm_core/mm_core.dart';

/// Removes, as they are typed or pasted, the characters the database
/// rejects: control characters, bidirectional overrides and isolates,
/// invisible spoofing characters and Unicode non-characters (mm_core's
/// `removeUnsafeCharacters`).
///
/// Spaces, line breaks and everything a user can see are kept exactly as
/// typed, so the formatter never fights the caret; trimming and collapsing
/// spaces happens when the value is saved (`sanitizeSingleLine`). The
/// selection and composing region move with the text, so the caret stays
/// after the last character the user typed.
///
/// Every text field of mm_ui applies it already (the inputs family's fields
/// and `MmSearchField`); add it to a plain `TextField` that collects text
/// for the database.
///
/// ```dart
/// TextField(inputFormatters: const [MmCleanTextFormatter()])
/// ```
class MmCleanTextFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const new();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!containsUnsafeCharacters(text)) return newValue;

    final cleaned = StringBuffer();
    // offsets[i] is where code unit i of the old text lands in the cleaned
    // text; offsets[text.length] is the cleaned length.
    final offsets = List<int>.filled(text.length + 1, 0);
    var index = 0;
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      for (var unit = 0; unit < character.length; unit++) {
        offsets[index + unit] = cleaned.length;
      }
      if (!containsUnsafeCharacters(character)) cleaned.write(character);
      index += character.length;
    }
    offsets[text.length] = cleaned.length;

    int map(int offset) =>
        offset < 0 ? offset : offsets[offset.clamp(0, text.length)];

    final selection = newValue.selection;
    final composing = newValue.composing;
    final mappedComposing = composing.isValid
        ? TextRange(start: map(composing.start), end: map(composing.end))
        : composing;
    return TextEditingValue(
      text: cleaned.toString(),
      selection: selection.copyWith(
        baseOffset: map(selection.baseOffset),
        extentOffset: map(selection.extentOffset),
      ),
      composing: mappedComposing.isValid && !mappedComposing.isCollapsed
          ? mappedComposing
          : TextRange.empty,
    );
  }
}
