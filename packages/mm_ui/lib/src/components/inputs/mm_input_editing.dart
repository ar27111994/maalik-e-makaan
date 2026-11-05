/// Editing helpers the formatters of the inputs family share: they lay a
/// value's significant characters (digits, a decimal point, a leading plus)
/// out with separators (dashes, spaces, grouping commas) while keeping the
/// caret beside the character the user was editing.
///
/// Not exported: the fields use these internally.
library;

import 'package:flutter/services.dart';

/// Whether [character] is one ASCII digit.
bool isAsciiDigit(String character) =>
    character.length == 1 &&
    character.codeUnitAt(0) >= 0x30 &&
    character.codeUnitAt(0) <= 0x39;

/// The caret of [value]: its selection's extent, or the end of the text
/// when the selection is invalid.
int caretOf(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) return value.text.length;
  return selection.extentOffset.clamp(0, value.text.length);
}

/// When the edit from [oldValue] to [newValue] deleted a lone separator
/// (backspace just after a dash, forward delete just before one), deletes
/// the significant character beside it too, so the deletion is not undone
/// when the separators are laid out again.
///
/// Returns [newValue] unchanged for every other edit.
TextEditingValue deleteThroughSeparator(
  TextEditingValue oldValue,
  TextEditingValue newValue, {
  required bool Function(String character) isSignificant,
}) {
  final before = oldValue.text;
  final after = newValue.text;
  if (before.length != after.length + 1 ||
      !oldValue.selection.isValid ||
      !oldValue.selection.isCollapsed ||
      !newValue.selection.isValid ||
      !newValue.selection.isCollapsed) {
    return newValue;
  }
  final caret = newValue.selection.extentOffset;
  if (caret > after.length ||
      before.substring(0, caret) != after.substring(0, caret) ||
      before.substring(caret + 1) != after.substring(caret)) {
    return newValue;
  }
  if (isSignificant(before[caret])) return newValue;
  final backspace = oldValue.selection.extentOffset == caret + 1;
  final target = backspace ? caret - 1 : caret;
  if (target < 0 || target >= after.length || !isSignificant(after[target])) {
    return newValue;
  }
  return TextEditingValue(
    text: after.replaceRange(target, target + 1, ''),
    selection: TextSelection.collapsed(offset: target),
  );
}

/// The characters of [value]'s text that [keep] accepts (given each
/// character and its index), and how many of them stand before the caret.
({String kept, int before}) keepCharacters(
  TextEditingValue value,
  bool Function(String character, int index) keep,
) {
  final text = value.text;
  final caret = caretOf(value);
  final kept = StringBuffer();
  var before = 0;
  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (!keep(character, index)) continue;
    kept.write(character);
    if (index < caret) before++;
  }
  return (kept: kept.toString(), before: before);
}

/// The offset in [text] just after its [count]th character that is not a
/// separator, or the end of [text] when it has fewer.
int offsetAfterKept(
  String text,
  int count, {
  required bool Function(String character) isSeparator,
}) {
  var offset = 0;
  var seen = 0;
  while (seen < count && offset < text.length) {
    if (!isSeparator(text[offset])) seen++;
    offset++;
  }
  return offset;
}
