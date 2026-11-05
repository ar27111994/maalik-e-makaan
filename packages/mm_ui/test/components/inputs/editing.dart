import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editable text of the field [field] finds (the only one by default).
Finder editableIn([Finder? field]) => field == null
    ? find.byType(EditableText)
    : find.descendant(of: field, matching: find.byType(EditableText));

/// The text and selection the field [field] finds currently holds.
TextEditingValue valueOf(WidgetTester tester, [Finder? field]) =>
    tester.widget<EditableText>(editableIn(field)).controller.value;

/// Sends an edit as the platform's keyboard would: [text] with the caret at
/// [caret] (the end by default), through the field's formatters.
Future<void> edit(
  WidgetTester tester,
  String text, {
  int? caret,
  Finder? field,
}) async {
  await tester.showKeyboard(editableIn(field));
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    ),
  );
  await tester.pump();
}

/// The colour the text [finder] finds is painted in (its style merged with
/// the ambient default text style).
Color? inkOf(WidgetTester tester, Finder finder) {
  final paragraph = find.descendant(
    of: finder,
    matching: find.byType(RichText),
    matchRoot: true,
  );
  return tester.widget<RichText>(paragraph.first).text.style?.color;
}
