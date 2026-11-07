import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';
import 'support.dart';

const _title = 'No tenants yet';
const _message = 'Add your first tenant to start tracking rent in Gulberg.';
const _action = 'Add tenant';

void main() {
  group('MmEmptyState', () {
    testEveryVariant('shows a muted icon, a title and a muted message', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: _message,
        ),
        variant: variant,
      );
      final text = variant.theme.textTheme;
      final colors = colorsOf(variant);
      final icon = tester.widget<Icon>(find.byIcon(MmIcons.tenants));
      expect(icon.size, 48);
      expect(icon.color, colors.inkMuted);
      final title = styleOf(tester, _title);
      expect(title.fontSize, text.titleLarge!.fontSize);
      expect(title.fontWeight, text.titleLarge!.fontWeight);
      expect(title.color, colors.ink);
      final message = styleOf(tester, _message);
      expect(message.fontSize, text.bodyLarge!.fontSize);
      expect(message.color, colors.inkMuted);
      expect(
        tester.widget<Text>(find.text(_message)).textAlign,
        TextAlign.center,
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the icon sits on the page, with no tile behind it', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: _message,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(MmEmptyState),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox ||
                widget is ColoredBox ||
                widget is Material ||
                widget is Container,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('announces the title as a heading and hides the icon', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: _message,
        ),
      );
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
      );
      expect(
        tester.getSemantics(find.text(_message)),
        isSemantics(label: _message, isHeader: false, isLiveRegion: false),
      );
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byIcon(MmIcons.tenants),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('its action calls onAction on tap and from the keyboard', (
      tester,
    ) async {
      var actions = 0;
      await pumpThemed(
        tester,
        MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: _message,
          actionLabel: _action,
          onAction: () => actions++,
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text(_action));
      expect(actions, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _action), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(actions, 2);
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(label: _action, isButton: true, isEnabled: true),
      );
    });

    testWidgets('without onAction its action is disabled', (tester) async {
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: _message,
          actionLabel: _action,
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(label: _action, isButton: true, isEnabled: false),
      );
    });

    test('an action without a label is a programming error', () {
      expect(
        () => MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: _message,
          onAction: tapped,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('stays at most 400 dp wide on a wide window', (tester) async {
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: _title,
          message: '$_message $_message $_message',
        ),
        size: const Size(1200, 800),
      );
      final message = tester.getRect(find.textContaining(_message));
      expect(message.width, lessThanOrEqualTo(400));
      // Centred in the window.
      expect(message.center.dx, closeTo(600, 1));
    });

    testWidgets('fills a bounded height, centred, and scrolls when taller', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          height: 600,
          child: MmEmptyState(
            icon: MmIcons.tenants,
            title: _title,
            message: _message,
            actionLabel: _action,
            onAction: tapped,
          ),
        ),
      );
      final box = tester.getRect(find.byType(MmEmptyState));
      final content = tester
          .getRect(find.byIcon(MmIcons.tenants))
          .expandToInclude(tester.getRect(find.byType(FilledButton)));
      expect(content.center.dy, closeTo(box.center.dy, 1));

      // At 200% text on a short space, the action scrolls into reach.
      tester.view
        ..physicalSize = const Size(320, 300)
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        themed(
          const SizedBox(
            height: 200,
            child: MmEmptyState(
              icon: MmIcons.tenants,
              title: _title,
              message: _message,
              actionLabel: _action,
              onAction: tapped,
            ),
          ),
          variant: MmVariant.largeText,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byType(FilledButton));
      expect(button.bottom, lessThanOrEqualTo(300));
    });

    testWidgets('in a list it is as tall as its content', (tester) async {
      await pumpThemed(
        tester,
        ListView(
          children: const [
            MmEmptyState(
              icon: MmIcons.tenants,
              title: _title,
              message: _message,
            ),
          ],
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.getSize(find.byType(MmEmptyState)).height, lessThan(300));
    });

    testWidgets('wraps at 200% text on a 320 dp phone without overflow', (
      tester,
    ) async {
      const long =
          'Add the tenants of Flat 3, Gulberg III, Lahore to start '
          'tracking rent, deposits and utility bills.';
      // In English and in Urdu, on a scrolling page as a screen holds it.
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final say = sayIn(context);
            return MmEmptyState(
              icon: MmIcons.tenants,
              title: say(
                'No tenants in Gulberg Heights yet',
                'گلبرگ ہائٹس میں ابھی کوئی کرایہ دار نہیں',
              ),
              message: say(
                long,
                'کرایہ، ڈپازٹ اور بل درج کرنے کے لیے فلیٹ 3، گلبرگ III، '
                'لاہور کے کرایہ دار شامل کریں۔',
              ),
              actionLabel: say(
                'Add your first tenant',
                'پہلا کرایہ دار شامل کریں',
              ),
              onAction: tapped,
            );
          },
        ),
      );
      await pumpLargeNarrow(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: 'No tenants in Gulberg Heights yet',
          message: long,
          actionLabel: 'Add your first tenant',
          onAction: tapped,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in [long, 'No tenants in Gulberg Heights yet']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.getRect(find.text(long)).width, lessThanOrEqualTo(288));
    });

    testWidgets('sets figures in Urdu text in the Latin face', (tester) async {
      const title = 'فلیٹ 3 میں کوئی کرایہ دار نہیں';
      const message =
          'گلبرگ III میں 45,000 روپے کا کرایہ درج کرنے کے لیے شامل کریں۔';
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: title,
          message: message,
        ),
        variant: MmVariant.urdu,
      );
      expect(isLatinFace(runStyleIn(tester, title, '3')), isTrue);
      expect(isLatinFace(runStyleIn(tester, message, '45,000')), isTrue);
      expect(isLatinFace(runStyleIn(tester, message, 'روپے')), isFalse);
    });

    testWidgets('lays out right to left in Urdu', (tester) async {
      await pumpThemed(
        tester,
        const MmEmptyState(
          icon: MmIcons.tenants,
          title: 'ابھی کوئی کرایہ دار نہیں',
          message: 'پہلا کرایہ دار شامل کریں۔',
          actionLabel: 'کرایہ دار شامل کریں',
          onAction: tapped,
        ),
        variant: MmVariant.urdu,
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('ابھی کوئی کرایہ دار نہیں'),
      );
      expect(paragraph.textDirection, TextDirection.rtl);
      expect(
        styleOf(tester, 'ابھی کوئی کرایہ دار نہیں').fontFamily,
        contains(MmFontFamily.urdu),
      );
    });
  });
}
