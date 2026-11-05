import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/testing.dart';

const _formatter = MmCleanTextFormatter();

TextEditingValue _format(TextEditingValue value) =>
    _formatter.formatEditUpdate(TextEditingValue.empty, value);

void main() {
  group('MmCleanTextFormatter', () {
    test('leaves clean text exactly as it was', () {
      const value = TextEditingValue(
        text: 'Ayesha Khan\nHouse 12, Gulberg III',
        selection: TextSelection.collapsed(offset: 5),
      );
      expect(identical(_format(value), value), isTrue);
    });

    test('removes controls, bidi overrides and invisible characters', () {
      final cleaned = _format(
        const TextEditingValue(
          text: 'Ali\u202ERaza\u0007 \u200Bkhan\u2066\uFEFF',
          selection: TextSelection.collapsed(offset: 19),
        ),
      );
      expect(cleaned.text, 'AliRaza khan');
      expect(cleaned.selection, const TextSelection.collapsed(offset: 12));
    });

    test('keeps what Urdu needs, spaces and line breaks', () {
      const text = 'می\u200Cخواہم\u200Dنام\t\n';
      expect(_format(const TextEditingValue(text: text)).text, text);
    });

    test('moves the selection with the text', () {
      final cleaned = _format(
        const TextEditingValue(
          text: 'a\u200Bbc\u200Bd',
          selection: TextSelection(baseOffset: 1, extentOffset: 5),
        ),
      );
      expect(cleaned.text, 'abcd');
      expect(
        cleaned.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
    });

    test('keeps an invalid selection invalid', () {
      final cleaned = _format(const TextEditingValue(text: 'a\u200Bb'));
      expect(cleaned.text, 'ab');
      expect(cleaned.selection.isValid, isFalse);
    });

    test('moves the composing region, or drops it when it empties', () {
      var cleaned = _format(
        const TextEditingValue(
          text: '\u200Bنام',
          composing: TextRange(start: 0, end: 4),
        ),
      );
      expect(cleaned.text, 'نام');
      expect(cleaned.composing, const TextRange(start: 0, end: 3));

      cleaned = _format(
        const TextEditingValue(
          text: 'نام\u200B',
          composing: TextRange(start: 3, end: 4),
        ),
      );
      expect(cleaned.composing, TextRange.empty);
    });

    test('keeps characters beyond the basic plane whole', () {
      final cleaned = _format(
        const TextEditingValue(
          text: '😀\u200B😀',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(cleaned.text, '😀😀');
      expect(cleaned.selection.baseOffset, 4);
    });

    testWidgets('cleans pasted text in a plain TextField', (tester) async {
      await pumpThemed(
        tester,
        const TextField(inputFormatters: [MmCleanTextFormatter()]),
      );
      await tester.enterText(find.byType(TextField), 'Gulberg\u202E III');
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, 'Gulberg III');
    });
  });
}
