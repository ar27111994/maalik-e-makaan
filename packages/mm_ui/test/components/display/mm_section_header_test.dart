import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _title = 'Tenants';
const _subtitle = '3 overdue this month';
const _action = 'See all';
const _long = 'Gulberg Heights, Block C, Main Boulevard, Lahore';

void main() {
  group('MmSectionHeader', () {
    testEveryVariant('sets the title in the title style, as written', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmSectionHeader(title: _title, subtitle: _subtitle),
        variant: variant,
      );
      final text = variant.theme.textTheme;
      final colors = colorsOf(variant);
      final title = styleOf(tester, _title);
      expect(title.fontSize, text.titleLarge!.fontSize);
      expect(title.fontWeight, text.titleLarge!.fontWeight);
      expect(title.letterSpacing, 0);
      expect(title.color, colors.ink);
      expect(find.textContaining(_title), findsOneWidget);
      expect(find.textContaining(_title.toUpperCase()), findsNothing);
      expect(styleOf(tester, _subtitle).color, colors.inkMuted);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('is announced as a heading', (tester) async {
      await pumpThemed(
        tester,
        const MmSectionHeader(title: _title, subtitle: _subtitle),
      );
      expect(
        tester.getSemantics(find.text(_title)),
        matchesSemantics(label: _title, isHeader: true),
      );
      expect(
        tester.getSemantics(find.text(_subtitle)),
        isNot(isSemantics(isHeader: true)),
      );
    });

    testWidgets('its action calls onAction on tap and from the keyboard', (
      tester,
    ) async {
      var actions = 0;
      await pumpThemed(
        tester,
        MmSectionHeader(
          title: _title,
          actionLabel: _action,
          onAction: () => actions++,
        ),
      );
      await tester.tap(find.text(_action));
      expect(actions, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _action), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(actions, 2);
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: _action, isButton: true, isEnabled: true),
      );
    });

    testWidgets('without onAction its action is disabled', (tester) async {
      await pumpThemed(
        tester,
        const MmSectionHeader(title: _title, actionLabel: _action),
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(
          label: _action,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    });

    test('an action needs a label', () {
      expect(
        () => MmSectionHeader(title: _title, onAction: () {}),
        throwsAssertionError,
      );
    });

    testWidgets("lines the action's words up with the end edge, mirrored "
        'right to left', (tester) async {
      await pumpThemed(
        tester,
        MmSectionHeader(title: _title, actionLabel: _action, onAction: () {}),
      );
      var header = tester.getRect(find.byType(MmSectionHeader));
      var button = tester.getRect(find.byType(TextButton));
      // The button's padding hangs past the edge; its words end on it.
      expect(tester.getRect(find.text(_action)).right, header.right);
      expect(button.right, header.right + MmSpace.s4);
      expect(button.height, MmSize.minTarget);
      expect(tester.getRect(find.text(_title)).left, header.left);

      await pumpThemed(
        tester,
        MmSectionHeader(
          title: 'کرایہ دار',
          actionLabel: 'سب دیکھیں',
          onAction: () {},
        ),
        variant: MmVariant.urdu,
      );
      header = tester.getRect(find.byType(MmSectionHeader));
      button = tester.getRect(find.byType(TextButton));
      expect(tester.getRect(find.text('سب دیکھیں')).left, header.left);
      expect(button.left, header.left - MmSpace.s4);
      expect(tester.getRect(find.text('کرایہ دار')).right, header.right);
    });

    group("lines every action's words up with the end edge", () {
      for (final variant in const [MmVariant.light, MmVariant.urdu]) {
        for (final enabled in const [true, false]) {
          for (final label in const [
            'See all',
            'Edit',
            'ایڈٹ کریں',
            'سب دیکھیں',
          ]) {
            testWidgets('${variant.name}, "$label", '
                '${enabled ? 'enabled' : 'disabled'}', (tester) async {
              await pumpThemed(
                tester,
                MmSectionHeader(
                  title: 'Gulberg Heights',
                  actionLabel: label,
                  onAction: enabled ? () {} : null,
                ),
                variant: variant,
              );
              final header = tester.getRect(find.byType(MmSectionHeader));
              final words = tester.getRect(find.text(label));
              final button = tester.getRect(find.byType(TextButton));
              if (variant == MmVariant.urdu) {
                expect(words.left, header.left);
                // A 48 dp target stays inside the column.
                expect(
                  button.right - header.left,
                  greaterThanOrEqualTo(MmSize.minTarget),
                );
              } else {
                expect(words.right, header.right);
                expect(
                  header.right - button.left,
                  greaterThanOrEqualTo(MmSize.minTarget),
                );
              }
            });
          }
        }
      }
    });

    testWidgets('keeps 48 dp of a short action inside the column', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmSectionHeader(title: _title, actionLabel: 'Edit', onAction: () {}),
      );
      final header = tester.getRect(find.byType(MmSectionHeader));
      final button = tester.getRect(find.byType(TextButton));
      // The button grows inward to a 48 dp target inside the column, its
      // padding still hanging past the edge and its words on the edge.
      expect(button.width, MmSize.minTarget + MmSpace.s4);
      expect(header.right - button.left, MmSize.minTarget);
      expect(button.right, header.right + MmSpace.s4);
      expect(tester.getRect(find.text('Edit')).right, header.right);
    });

    testWidgets('takes taps on the part of the action past the edge', (
      tester,
    ) async {
      var actions = 0;
      await pumpThemed(
        tester,
        Padding(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: MmSectionHeader(
            title: _title,
            actionLabel: _action,
            onAction: () => actions++,
          ),
        ),
      );
      final header = tester.getRect(find.byType(MmSectionHeader));
      final button = tester.getRect(find.byType(TextButton));
      await tester.tapAt(Offset(header.right + MmSpace.s2, button.center.dy));
      expect(actions, 1);
      // Below the header, still inside the padding around it, nothing is.
      await tester.tapAt(Offset(button.center.dx, header.bottom + MmSpace.s2));
      expect(actions, 1);
    });

    testWidgets('wraps a long title in whole words and moves the action '
        'under it at 200%, its words still on the end edge', (tester) async {
      await expectFitsNarrowLargeText(
        tester,
        MmSectionHeader(
          title: _long,
          subtitle: _subtitle,
          actionLabel: _action,
          onAction: () {},
        ),
        then: (locale) {
          final title = tester.getRect(find.textContaining(_long));
          final subtitle = tester.getRect(find.text(_subtitle));
          final words = tester.getRect(find.text(_action));
          expect(title.height, greaterThan(2 * 40));
          expect(words.top, greaterThanOrEqualTo(subtitle.bottom));
          final header = tester.getRect(find.byType(MmSectionHeader));
          if (locale.languageCode == 'ur') {
            expect(words.left, header.left);
          } else {
            expect(words.right, header.right);
          }
        },
      );
    });

    testWidgets('sets a Latin title in the Latin face, left to right, in '
        'the Urdu UI', (tester) async {
      await pumpThemed(
        tester,
        const MmSectionHeader(title: 'Gulberg Heights.'),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Gulberg Heights.').fontFamily,
        contains(MmFontFamily.latin),
      );
      // Its full stop stays at its end, on the right.
      final paragraph = paragraphOf(tester, 'Gulberg Heights.');
      final text = paragraph.text.toPlainText();
      double xOf(int offset) => paragraph
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dx;
      expect(xOf(text.indexOf('.')), greaterThan(xOf(text.indexOf('G'))));
      expect(
        tester.getSemantics(find.textContaining('Gulberg')),
        matchesSemantics(label: 'Gulberg Heights.', isHeader: true),
      );
    });
  });
}
