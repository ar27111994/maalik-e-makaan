import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// The editable text of the field [field] finds (the only one by default).
Finder editableIn([Finder? field]) => field == null
    ? find.byType(EditableText)
    : find.descendant(of: field, matching: find.byType(EditableText));

/// The text and selection the field [field] finds currently holds.
TextEditingValue valueOf(WidgetTester tester, [Finder? field]) =>
    tester.widget<EditableText>(editableIn(field)).controller.value;

/// The render object that lays out and paints the text of the field
/// [field] finds.
RenderEditable renderEditableOf(WidgetTester tester, [Finder? field]) =>
    tester.state<EditableTextState>(editableIn(field)).renderEditable;

/// The text scale the text of the field [field] finds is set at.
double textScaleOf(WidgetTester tester, [Finder? field]) =>
    MediaQuery.textScalerOf(tester.element(editableIn(field))).scale(1);

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

/// The colour the glyph of [icon] is painted in.
Color? iconInkOf(WidgetTester tester, IconData icon) => tester
    .widget<RichText>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

/// Asserts that every value in [field] shows whole on one line at 200%
/// text on a 320 dp wide phone, in English and in Urdu: each field's text
/// needs no more width than its box gives it (a text field scrolls a text
/// that does not fit instead of reporting an overflow), and nothing
/// overflows. [check] runs after each language, for more expectations.
Future<void> expectWholeValues(
  WidgetTester tester,
  Widget field, {
  Future<void> Function(Locale locale)? check,
}) async {
  tester.view
    ..physicalSize = const Size(320, 740)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  for (final locale in const [Locale('en'), Locale('ur')]) {
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(MmSpace.s4),
            child: field,
          ),
        ),
        variant: MmVariant.largeText,
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: locale.languageCode);
    final editables = find.byType(EditableText);
    expect(editables, findsWidgets);
    for (var index = 0; index < editables.evaluate().length; index++) {
      final state = tester.state<EditableTextState>(editables.at(index));
      final editable = state.renderEditable;
      final text = state.widget.controller.text;
      expect(
        editable.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(editable.size.width),
        reason: '"$text" in ${locale.languageCode}',
      );
    }
    await check?.call(locale);
  }
}
