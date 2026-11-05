import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/src/components/inputs/mm_input_editing.dart';

TextEditingValue _at(String text, int caret) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret),
);

void main() {
  group('isAsciiDigit', () {
    test('is true only for one Western digit', () {
      expect(isAsciiDigit('0'), isTrue);
      expect(isAsciiDigit('9'), isTrue);
      expect(isAsciiDigit('۵'), isFalse);
      expect(isAsciiDigit('a'), isFalse);
      expect(isAsciiDigit('12'), isFalse);
      expect(isAsciiDigit(''), isFalse);
    });
  });

  group('caretOf', () {
    test('is the selection extent, clamped, or the end when invalid', () {
      expect(caretOf(_at('1234', 2)), 2);
      expect(caretOf(const TextEditingValue(text: '1234')), 4);
      expect(
        caretOf(
          const TextEditingValue(
            text: '12',
            selection: TextSelection(baseOffset: 0, extentOffset: 9),
          ),
        ),
        2,
      );
    });
  });

  group('deleteThroughSeparator', () {
    bool digit(String character) => isAsciiDigit(character);

    test('backspace after a separator deletes the digit before it', () {
      final result = deleteThroughSeparator(
        _at('12-34', 3),
        _at('1234', 2),
        isSignificant: digit,
      );
      expect(result.text, '134');
      expect(result.selection, const TextSelection.collapsed(offset: 1));
    });

    test('delete before a separator deletes the digit after it', () {
      final result = deleteThroughSeparator(
        _at('12-34', 2),
        _at('1234', 2),
        isSignificant: digit,
      );
      expect(result.text, '124');
      expect(result.selection, const TextSelection.collapsed(offset: 2));
    });

    test('leaves every other edit alone', () {
      void unchanged(TextEditingValue before, TextEditingValue after) {
        expect(
          identical(
            deleteThroughSeparator(before, after, isSignificant: digit),
            after,
          ),
          isTrue,
        );
      }

      // A digit was deleted, not a separator.
      unchanged(_at('12-34', 2), _at('1-34', 1));
      // Typing, not deleting.
      unchanged(_at('1234', 2), _at('12534', 3));
      // A selection was replaced.
      unchanged(
        const TextEditingValue(
          text: '12-34',
          selection: TextSelection(baseOffset: 2, extentOffset: 3),
        ),
        _at('1234', 2),
      );
      unchanged(
        _at('12-34', 3),
        const TextEditingValue(
          text: '1234',
          selection: TextSelection(baseOffset: 1, extentOffset: 2),
        ),
      );
      unchanged(const TextEditingValue(text: '12-34'), _at('1234', 2));
      unchanged(_at('12-34', 3), const TextEditingValue(text: '1234'));
      // The caret does not stand where the character went.
      unchanged(_at('12-34', 3), _at('1234', 1));
      unchanged(_at('12-34', 3), _at('1234', 9));
      // No digit beside the separator.
      unchanged(_at('-12', 1), _at('12', 0));
      unchanged(_at('12-', 2), _at('12', 2));
      unchanged(_at('1--2', 3), _at('1-2', 2));
    });
  });

  group('keepCharacters', () {
    test('keeps what is accepted and counts it before the caret', () {
      final kept = keepCharacters(
        _at('03-00 12', 4),
        (character, _) => isAsciiDigit(character),
      );
      expect(kept.kept, '030012');
      expect(kept.before, 3);
    });

    test('passes each character its index', () {
      final kept = keepCharacters(
        _at('+1+2', 4),
        (character, index) => isAsciiDigit(character) || index == 0,
      );
      expect(kept.kept, '+12');
    });
  });

  group('offsetAfterKept', () {
    bool dash(String character) => character == '-';

    test('stands just after the counted character, before a separator', () {
      expect(offsetAfterKept('35202-1', 5, isSeparator: dash), 5);
      expect(offsetAfterKept('35202-1', 6, isSeparator: dash), 7);
      expect(offsetAfterKept('35202-1', 0, isSeparator: dash), 0);
    });

    test('stops at the end of the text', () {
      expect(offsetAfterKept('123', 9, isSeparator: dash), 3);
    });
  });
}
