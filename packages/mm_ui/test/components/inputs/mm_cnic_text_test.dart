import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

final _cnic = Cnic.parse('35202-1234567-1');

/// The pieces the number is laid out in, one per digit group.
List<String> _pieces(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: find.byType(MmCnicText), matching: find.byType(Text)),
  ))
    ?text.data,
];

/// The node a screen reader reads for the number.
SemanticsNode _number(WidgetTester tester) => tester.getSemantics(
  find.ancestor(of: find.text('1'), matching: find.byType(Semantics)).first,
);

/// The spans of [label] spelled out digit by digit.
List<String> _spelledOut(AttributedString label) => [
  for (final attribute in label.attributes)
    if (attribute is SpellOutStringAttribute)
      attribute.range.textInside(label.string),
];

/// The shape of the reveal button.
ShapeBorder? _buttonShape(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(IconButton),
            matching: find.byType(Material),
          )
          .first,
    )
    .shape;

void main() {
  group('MmCnicText', () {
    testEveryVariant('is masked until the button reveals it', (
      tester,
      variant,
    ) async {
      final strings = MmLocalizations.forLocale(variant.locale);
      await pumpThemed(tester, MmCnicText(cnic: _cnic), variant: variant);
      expect(_pieces(tester), ['35202-', '•••••••-', '1']);
      expect(find.textContaining('1234567'), findsNothing);
      expect(find.byIcon(MmIcons.show), findsOneWidget);

      await tester.tap(find.byTooltip(strings.showFullCnic));
      await tester.pump();
      expect(_pieces(tester), ['35202-', '1234567-', '1']);
      expect(find.byIcon(MmIcons.hide), findsOneWidget);

      await tester.tap(find.byTooltip(strings.hideFullCnic));
      await tester.pump();
      expect(_pieces(tester), ['35202-', '•••••••-', '1']);
    });

    testWidgets('lays the number out without invisible characters', (
      tester,
    ) async {
      await pumpThemed(tester, MmCnicText(cnic: _cnic, initiallyMasked: false));
      // Copied from a selection, the pieces join into the number as
      // written: nothing hidden between the dash and the digits.
      expect(_pieces(tester).join(), _cnic.formatted);
    });

    testWidgets('never speaks the hidden digits while masked', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      final masked = _number(tester);
      // The digits on screen, and how many are hidden between them.
      expect(masked.label, '35202, 7 hidden digits, 1');
      expect(masked.label, isNot(contains('1234567')));
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(tooltip: 'Show full CNIC', isButton: true),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(_number(tester).label, '35202, 1234567, 1');
      handle.dispose();
    });

    testWidgets('spells out its digit groups, and only those', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      // A group of digits read as one number would be "thirty-five
      // thousand...": each group is read digit by digit.
      expect(_spelledOut(_number(tester).attributedLabel), ['35202', '1']);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(_spelledOut(_number(tester).attributedLabel), [
        '35202',
        '1234567',
        '1',
      ]);
      handle.dispose();
    });

    testWidgets('says how many digits are hidden in Urdu, with its comma', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        MmCnicText(cnic: _cnic),
        variant: MmVariant.urdu,
      );
      final label = _number(tester).attributedLabel;
      expect(label.string, '35202، ${MmLocalizations.urdu.hiddenDigits(7)}، 1');
      expect(_spelledOut(label), ['35202', '1']);
      handle.dispose();
    });

    testWidgets('can start revealed', (tester) async {
      await pumpThemed(tester, MmCnicText(cnic: _cnic, initiallyMasked: false));
      expect(_pieces(tester), ['35202-', '1234567-', '1']);
      expect(find.byTooltip('Hide CNIC'), findsOneWidget);
    });

    testWidgets('a different CNIC starts masked again', (tester) async {
      Widget build(Cnic cnic) => themed(MmCnicText(cnic: cnic));
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      // The same CNIC keeps its state.
      await tester.pumpWidget(build(Cnic.parse('3520212345671')));
      expect(_pieces(tester), ['35202-', '1234567-', '1']);
      await tester.pumpWidget(build(Cnic.parse('42101-7654321-2')));
      expect(_pieces(tester), ['42101-', '•••••••-', '2']);
    });

    testWidgets('the button works from the keyboard', (tester) async {
      await pumpThemed(tester, MmCnicText(cnic: _cnic));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_pieces(tester), ['35202-', '1234567-', '1']);
    });

    testEveryVariant('the button draws the focus ring outside itself', (
      tester,
      variant,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(tester, MmCnicText(cnic: _cnic), variant: variant);
      expect(_buttonShape(tester), isNot(isA<MmFocusRingBorder>()));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ring = _buttonShape(tester)! as MmFocusRingBorder;
      expect(ring.color, colorsOf(variant).focus);
      expect(ring.width, MmSize.focusRing);
    });

    testWidgets('takes a style and keeps the Latin face in Urdu', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmCnicText(cnic: _cnic, style: const TextStyle(fontSize: 22)),
        variant: MmVariant.urdu,
      );
      final first = tester.widget<Text>(find.text('35202-'));
      expect(first.style!.fontSize, 22);
      expect(first.style!.fontFamily, contains(MmFontFamily.latin));
      expect(first.textDirection, TextDirection.ltr);
      // The groups read left to right in the Urdu UI too.
      expect(
        tester.getRect(find.text('35202-')).left,
        lessThan(tester.getRect(find.text('1')).left),
      );
      // The button sits at the end: to the left in right to left.
      expect(
        tester.getRect(find.byType(IconButton)).center.dx,
        lessThan(tester.getRect(find.text('35202-')).left),
      );
    });

    testWidgets('fits 200% text on a 320 dp wide screen', (tester) async {
      final cnic = MmCnicText(cnic: _cnic, initiallyMasked: false);
      await expectFitsNarrowLargeText(tester, cnic);
      // The number keeps one line; the button moves below it instead.
      await pumpLargeNarrow(tester, cnic);
      final top = tester.getRect(find.text('35202-')).top;
      for (final piece in ['1234567-', '1']) {
        expect(tester.getRect(find.text(piece)).top, top);
      }
      expect(
        tester.getRect(find.byType(IconButton)).top,
        greaterThanOrEqualTo(tester.getRect(find.text('1')).bottom),
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
      final pieces = ['35202-', '1234567-', '1'];
      // Each group stays on one line of its own height...
      final lineHeight = tester.getSize(find.text('1')).height;
      for (final piece in pieces) {
        expect(tester.getSize(find.text(piece)).height, lineHeight);
      }
      // ...and the number breaks onto more lines between them.
      final tops = {
        for (final piece in pieces) tester.getRect(find.text(piece)).top,
      };
      expect(tops.length, greaterThan(1));
    });
  });
}
