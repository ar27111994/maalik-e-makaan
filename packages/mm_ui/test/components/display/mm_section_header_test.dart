import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

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
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_title.toUpperCase()), findsNothing);
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

    testWidgets('puts the action at the end, mirrored right to left', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmSectionHeader(title: _title, actionLabel: _action, onAction: () {}),
      );
      var header = tester.getRect(find.byType(MmSectionHeader));
      var button = tester.getRect(find.byType(TextButton));
      expect(button.right, header.right);
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
      expect(button.left, header.left);
      expect(tester.getRect(find.text('کرایہ دار')).right, header.right);
    });

    testWidgets('wraps a long title and moves the action under it at 200%', (
      tester,
    ) async {
      await pumpLargeNarrow(
        tester,
        MmSectionHeader(
          title: _long,
          subtitle: _subtitle,
          actionLabel: _action,
          onAction: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text(_long));
      final subtitle = tester.getRect(find.text(_subtitle));
      final button = tester.getRect(find.byType(TextButton));
      expect(title.height, greaterThan(2 * 40));
      expect(button.top, greaterThanOrEqualTo(subtitle.bottom));
      expect(button.left, title.left);
    });

    testWidgets('sets a Latin title in the Latin face in the Urdu UI', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmSectionHeader(title: 'Gulberg Heights'),
        variant: MmVariant.urdu,
      );
      expect(
        styleOf(tester, 'Gulberg Heights').fontFamily,
        contains(MmFontFamily.latin),
      );
    });
  });
}
