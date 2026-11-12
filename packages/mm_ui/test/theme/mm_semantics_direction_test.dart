import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';

import '../support/testing.dart';

const _lri = '\u2066';
const _rli = '\u2067';
const _pdi = '\u2069';

void main() {
  group('MmSemantics.firstStrongDirection', () {
    test('is the direction of the first letter', () {
      expect(MmSemantics.firstStrongDirection('Ali Raza'), TextDirection.ltr);
      expect(MmSemantics.firstStrongDirection('علی رضا'), TextDirection.rtl);
      // Digits and punctuation do not decide it.
      expect(
        MmSemantics.firstStrongDirection('3، گلبرگ III'),
        TextDirection.rtl,
      );
      expect(
        MmSemantics.firstStrongDirection('12 Main Boulevard، لاہور'),
        TextDirection.ltr,
      );
      expect(MmSemantics.firstStrongDirection('שלום'), TextDirection.rtl);
      expect(MmSemantics.firstStrongDirection('Ünal'), TextDirection.ltr);
    });

    test('skips text kept apart in an isolate, as the bidi algorithm '
        'does', () {
      // An Urdu sentence that starts with an English name the app isolated.
      expect(
        MmSemantics.firstStrongDirection('\u2066Ali Raza\u2069 کا کرایہ'),
        TextDirection.rtl,
      );
      expect(
        MmSemantics.firstStrongDirection('\u2067علی\u2069 paid rent'),
        TextDirection.ltr,
      );
      // First-strong isolates and nested isolates are skipped too.
      expect(
        MmSemantics.firstStrongDirection(
          '\u2068Ali \u2067علی\u2069 Raza\u2069 کرایہ',
        ),
        TextDirection.rtl,
      );
      // An isolate left open runs to the end of the text.
      expect(MmSemantics.firstStrongDirection('\u2066Ali Raza'), isNull);
      // A stray pop outside any isolate changes nothing.
      expect(MmSemantics.firstStrongDirection('\u2069علی'), TextDirection.rtl);
    });

    test('is null for text without letters', () {
      expect(MmSemantics.firstStrongDirection('35202-1234567-1'), isNull);
      expect(MmSemantics.firstStrongDirection('0412 3345 6789'), isNull);
      // Arabic-Indic digits are not letters either.
      expect(MmSemantics.firstStrongDirection('۰۳۰۰'), isNull);
      expect(MmSemantics.firstStrongDirection(''), isNull);
    });
  });

  group('MmSemantics.drawableSpaces', () {
    test('turns the narrow no-break space the Latin face does not draw '
        'into a no-break space', () {
      expect(MmSemantics.drawableSpaces('10:42\u202FAM'), '10:42\u00A0AM');
      expect(
        MmSemantics.drawableSpaces('9\u202FAM \u2013 5\u202FPM'),
        '9\u00A0AM \u2013 5\u00A0PM',
      );
      expect(MmSemantics.drawableSpaces('Ali Raza'), 'Ali Raza');
    });
  });

  group('MmSemantics.isolated', () {
    test('leaves text that runs with the paragraph as it is', () {
      expect(MmSemantics.isolated('Ali Raza', TextDirection.ltr), 'Ali Raza');
      expect(MmSemantics.isolated('علی رضا', TextDirection.rtl), 'علی رضا');
      expect(MmSemantics.isolated('0412 3345', TextDirection.ltr), '0412 3345');
      expect(MmSemantics.isolated('', TextDirection.rtl), '');
    });

    test('keeps text in the other direction apart', () {
      expect(
        MmSemantics.isolated('Ali Raza.', TextDirection.rtl),
        '${_lri}Ali Raza.$_pdi',
      );
      expect(
        MmSemantics.isolated('علی رضا', TextDirection.ltr),
        '$_rliعلی رضا$_pdi',
      );
      // Numbers run left to right.
      expect(
        MmSemantics.isolated('0412 3345 6789', TextDirection.rtl),
        '${_lri}0412 3345 6789$_pdi',
      );
    });

    test('keeps the paragraph direction for text whose only letters are '
        'isolated', () {
      // A sentence the UI built around the landlord's words, each isolated:
      // nothing outside the isolates decides its direction, so it runs with
      // the paragraph, in the UI's order.
      const urduUi = '${_lri}Shop 3$_pdi، ${_lri}Saddar Plaza$_pdi';
      expect(MmSemantics.isolated(urduUi, TextDirection.rtl), urduUi);
      const englishUi = '$_rliدکان 3$_pdi, $_rliصدر پلازہ$_pdi';
      expect(MmSemantics.isolated(englishUi, TextDirection.ltr), englishUi);
      // Text with no letter at all still runs left to right.
      expect(
        MmSemantics.isolated('${_lri}0412$_pdi 3345', TextDirection.rtl),
        '$_lri${_lri}0412$_pdi 3345$_pdi',
      );
    });

    testWidgets('MmUserText sets a sentence of isolated parts in the UI '
        'order', (tester) async {
      const text = '${_lri}Shop 3$_pdi، ${_lri}Saddar Plaza$_pdi';
      await pumpThemed(
        tester,
        const SizedBox(width: 300, child: MmUserText(text, style: TextStyle())),
        variant: MmVariant.urdu,
      );
      final paragraph = paragraphOf(tester, 'Shop');
      final plain = paragraph.text.toPlainText();
      double xOf(String part) => paragraph
          .getOffsetForCaret(
            TextPosition(offset: plain.indexOf(part)),
            Rect.zero,
          )
          .dx;
      // Right to left: the first part sits to the right of the second.
      expect(xOf('Shop'), greaterThan(xOf('Saddar')));
    });

    test('leftToRight always keeps an identifier left to right, on one '
        'line', () {
      expect(MmSemantics.leftToRight('0412'), '${_lri}0412$_pdi');
      expect(MmSemantics.leftToRight('Ali'), '${_lri}Ali$_pdi');
      expect(
        MmSemantics.leftToRight('0412 3345 6789'),
        '${_lri}0412\u00A03345\u00A06789$_pdi',
      );
      // Text kept apart only for its direction may still wrap.
      expect(
        MmSemantics.isolated('Block C, Main Boulevard', TextDirection.rtl),
        '${_lri}Block C, Main Boulevard$_pdi',
      );
    });

    testWidgets("an isolated number keeps its groups' order in Urdu text", (
      tester,
    ) async {
      const number = '0412 3345 6789';
      for (final (text, ordered) in [
        ('صارف نمبر $number، واسا', false),
        ('صارف نمبر ${MmSemantics.leftToRight(number)}، واسا', true),
      ]) {
        await pumpThemed(
          tester,
          Text(text, key: const ValueKey('sentence')),
          variant: MmVariant.urdu,
        );
        final paragraph = paragraphOf(tester, 'صارف');
        final plain = paragraph.text.toPlainText();
        double xOf(String group) => paragraph
            .getOffsetForCaret(
              TextPosition(offset: plain.indexOf(group)),
              Rect.zero,
            )
            .dx;
        final inOrder = xOf('0412') < xOf('3345') && xOf('3345') < xOf('6789');
        expect(inOrder, ordered, reason: text);
      }
    });

    testWidgets('an identifier is not split across lines', (tester) async {
      final number = MmSemantics.leftToRight('0412 3345 6789');
      await pumpThemed(
        tester,
        SizedBox(width: 160, child: Text('صارف نمبر $number')),
        variant: MmVariant.urdu,
      );
      final paragraph = paragraphOf(tester, 'صارف');
      final plain = paragraph.text.toPlainText();
      double lineOf(String group) => paragraph
          .getOffsetForCaret(
            TextPosition(offset: plain.indexOf(group)),
            Rect.zero,
          )
          .dy;
      expect(lineOf('0412'), lineOf('6789'));
      expect(lineOf('0412'), greaterThan(lineOf('صارف')));
    });
  });
}
