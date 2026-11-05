import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

final _cnic = Cnic.parse('35202-1234567-1');

/// [text] as the widget lays it out: breakable after each dash.
String _shown(String text) => text.replaceAll('-', '-\u200B');

void main() {
  group('MmCnicText', () {
    testEveryVariant('is masked until the button reveals it', (
      tester,
      variant,
    ) async {
      final strings = MmLocalizations.forLocale(variant.locale);
      await pumpThemed(tester, MmCnicText(cnic: _cnic), variant: variant);
      expect(find.text(_shown('35202-•••••••-1')), findsOneWidget);
      expect(find.textContaining('1234567'), findsNothing);
      expect(find.byIcon(MmIcons.show), findsOneWidget);

      await tester.tap(find.byTooltip(strings.showFullCnic));
      await tester.pump();
      expect(find.text(_shown('35202-1234567-1')), findsOneWidget);
      expect(find.byIcon(MmIcons.hide), findsOneWidget);

      await tester.tap(find.byTooltip(strings.hideFullCnic));
      await tester.pump();
      expect(find.text(_shown('35202-•••••••-1')), findsOneWidget);
    });

    testWidgets('never speaks the hidden digits while masked', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      final masked = tester.getSemantics(find.text(_shown('35202-•••••••-1')));
      // The digits on screen, and how many are hidden between them.
      expect(masked.label, '35202, 7 hidden digits, 1');
      expect(masked.label, isNot(contains('1234567')));
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(tooltip: 'Show full CNIC', isButton: true),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(
        tester.getSemantics(find.text(_shown('35202-1234567-1'))),
        isSemantics(label: '35202-1234567-1'),
      );
      handle.dispose();
    });

    testWidgets('says how many digits are hidden in Urdu', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        MmCnicText(cnic: _cnic),
        variant: MmVariant.urdu,
      );
      expect(
        tester.getSemantics(find.text(_shown('35202-•••••••-1'))).label,
        '35202, ${MmLocalizations.urdu.hiddenDigits(7)}, 1',
      );
      handle.dispose();
    });

    testWidgets('can start revealed', (tester) async {
      await pumpThemed(tester, MmCnicText(cnic: _cnic, initiallyMasked: false));
      expect(find.text(_shown('35202-1234567-1')), findsOneWidget);
      expect(find.byTooltip('Hide CNIC'), findsOneWidget);
    });

    testWidgets('a different CNIC starts masked again', (tester) async {
      Widget build(Cnic cnic) => themed(MmCnicText(cnic: cnic));
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      // The same CNIC keeps its state.
      await tester.pumpWidget(build(Cnic.parse('3520212345671')));
      expect(find.text(_shown('35202-1234567-1')), findsOneWidget);
      await tester.pumpWidget(build(Cnic.parse('42101-7654321-2')));
      expect(find.text(_shown('42101-•••••••-2')), findsOneWidget);
    });

    testWidgets('the button works from the keyboard', (tester) async {
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text(_shown('35202-1234567-1')), findsOneWidget);
    });

    testWidgets('takes a style and keeps the Latin face in Urdu', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmCnicText(cnic: _cnic, style: const TextStyle(fontSize: 22)),
        variant: MmVariant.urdu,
      );
      final text = tester.widget<Text>(find.text(_shown('35202-•••••••-1')));
      expect(text.style!.fontSize, 22);
      expect(text.style!.fontFamily, contains(MmFontFamily.latin));
      expect(text.textDirection, TextDirection.ltr);
      // The button sits at the end: to the left in right to left.
      expect(
        tester.getRect(find.byType(IconButton)).center.dx,
        lessThan(tester.getRect(find.text(_shown('35202-•••••••-1'))).left),
      );
    });

    testWidgets('fits 200% text on a 320 dp wide screen', (tester) async {
      final cnic = MmCnicText(cnic: _cnic, initiallyMasked: false);
      await expectFitsNarrowLargeText(tester, cnic);
      // The number keeps one line; the button moves below it instead.
      await pumpLargeNarrow(tester, cnic);
      final number = tester.getRect(find.text(_shown('35202-1234567-1')));
      expect(number.height, lessThan(60));
      expect(
        tester.getRect(find.byType(IconButton)).top,
        greaterThanOrEqualTo(number.bottom),
      );
    });

    testWidgets('a larger style wraps only between digit groups', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) => MmCnicText(
            cnic: _cnic,
            initiallyMasked: false,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(_shown('35202-1234567-1')),
          matching: find.byType(RichText),
        ),
      );
      final text = _shown('35202-1234567-1');
      double topOf(int index) => paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1),
          )
          .first
          .top;
      var lines = 1;
      for (var index = 1; index < text.length; index++) {
        if (topOf(index) > topOf(index - 1)) {
          lines++;
          // A new line starts a digit group, after a dash.
          expect(text[index - 1], '\u200B');
        }
      }
      expect(lines, greaterThan(1));
    });
  });
}
