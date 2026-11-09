import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const ValueKey<String> _primaryKey = ValueKey('primary');
const ValueKey<String> _secondaryKey = ValueKey('secondary');

MmActionBar _bar({
  String primary = 'Save',
  String? secondary = 'Cancel',
  VoidCallback? onPrimary = tapped,
  VoidCallback? onSecondary = tapped,
}) => MmActionBar(
  primary: FilledButton(
    key: _primaryKey,
    onPressed: onPrimary,
    child: Text(primary),
  ),
  secondary: secondary == null
      ? null
      : OutlinedButton(
          key: _secondaryKey,
          onPressed: onSecondary,
          child: Text(secondary),
        ),
);

Rect _primary(WidgetTester tester) => tester.getRect(find.byKey(_primaryKey));
Rect _secondary(WidgetTester tester) =>
    tester.getRect(find.byKey(_secondaryKey));
Rect _barRect(WidgetTester tester) => tester.getRect(find.byType(MmActionBar));

/// The render box that lays the buttons out.
RenderBox _buttons(WidgetTester tester) => tester.renderObject<RenderBox>(
  find.descendant(
    of: find.byType(MmActionBar),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MmActionBarButtons',
    ),
  ),
);

/// Shows the keyboard, [height] dp tall, for the rest of the test.
void _showKeyboard(WidgetTester tester, {double height = 300}) {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  addTearDown(tester.view.resetViewInsets);
}

void main() {
  group('MmActionBar', () {
    testEveryVariant('is surface paper under a hairline rule, padded 16 dp', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      await pumpThemed(tester, _bar(secondary: null), variant: variant);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(MmActionBar),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, colors.surface);
      expect(decoration.border, Border(top: BorderSide(color: colors.rule)));
      expect(decoration.border!.top.width, MmSize.hairline);
      final bar = _barRect(tester);
      final button = _primary(tester);
      expect(button.top - bar.top, MmSpace.s4 + MmSize.hairline);
      expect(bar.bottom - button.bottom, MmSpace.s4);
      expect(button.left - bar.left, MmSpace.s4);
      expect(bar.right - button.right, MmSpace.s4);
    });

    testWidgets('on a phone, a lone primary fills the width', (tester) async {
      await pumpThemed(tester, _bar(secondary: null));
      expect(_primary(tester).width, 328 - 2 * MmSpace.s4);
    });

    testWidgets(
      'on a phone, two that fit share the width, primary at the end',
      (tester) async {
        await pumpThemed(tester, _bar());
        const half = (328 - 2 * MmSpace.s4 - MmActionBar.spacing) / 2;
        final primary = _primary(tester);
        final secondary = _secondary(tester);
        expect(primary.width, half);
        expect(secondary.width, half);
        expect(primary.top, secondary.top);
        expect(primary.left, secondary.right + MmActionBar.spacing);

        await pumpThemed(tester, _bar(), variant: MmVariant.urdu);
        expect(_primary(tester).right, _secondary(tester).left - 12);
        expect(_primary(tester).width, half);
      },
    );

    testWidgets(
      'on a phone, two that do not fit stack, primary at the bottom',
      (tester) async {
        await pumpThemed(
          tester,
          _bar(secondary: 'Share on WhatsApp', primary: 'Record payment'),
        );
        final primary = _primary(tester);
        final secondary = _secondary(tester);
        expect(primary.width, 328 - 2 * MmSpace.s4);
        expect(secondary.width, 328 - 2 * MmSpace.s4);
        expect(primary.top, secondary.bottom + MmActionBar.spacing);
        expect(primary.left, secondary.left);
      },
    );

    testWidgets('buttons side by side share one height', (tester) async {
      await pumpThemed(
        tester,
        const MmActionBar(
          secondary: SizedBox(key: _secondaryKey, width: 40, height: 64),
          primary: FilledButton(
            key: _primaryKey,
            onPressed: tapped,
            child: Text('Save'),
          ),
        ),
      );
      expect(_secondary(tester).height, 64);
      expect(_primary(tester).height, 64);
    });

    testWidgets('on wider windows, natural widths at the end edge', (
      tester,
    ) async {
      const size = Size(800, 740);
      await pumpThemed(tester, _bar(), size: size);
      final bar = _barRect(tester);
      final column = (bar.width - 2 * MmSpace.s4).clamp(0, MmSize.contentMax);
      final end = bar.center.dx + column / 2;
      final primary = _primary(tester);
      final secondary = _secondary(tester);
      expect(primary.right, end);
      expect(secondary.right, primary.left - MmActionBar.spacing);
      expect(primary.width, lessThan(column / 2));
      expect(primary.top, secondary.top);

      await pumpThemed(tester, _bar(), size: size, variant: MmVariant.urdu);
      expect(_primary(tester).left, bar.center.dx - column / 2);
      expect(
        _secondary(tester).left,
        _primary(tester).right + MmActionBar.spacing,
      );
    });

    testWidgets('on desktop, the buttons end with the reading column', (
      tester,
    ) async {
      await pumpThemed(tester, _bar(), size: const Size(1400, 740));
      final bar = _barRect(tester);
      expect(_primary(tester).right, bar.center.dx + MmSize.contentMax / 2);
    });

    testWidgets('on wider windows, labels too long for a row stack', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _bar(
          secondary: 'Share the receipt on WhatsApp',
          primary: 'Record the payment now',
        ),
        size: const Size(640, 740),
        variant: MmVariant.largeText,
      );
      final primary = _primary(tester);
      final secondary = _secondary(tester);
      expect(primary.top, secondary.bottom + MmActionBar.spacing);
      expect(primary.width, secondary.width);
      expect(primary.width, 640 - 2 * MmSpace.s4 - 2 * MmSpace.s4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps clear of the safe area as a bottom bar', (tester) async {
      tester.view.padding = const FakeViewPadding(
        left: 20,
        right: 10,
        bottom: 34,
      );
      addTearDown(tester.view.resetPadding);
      await pumpScreen(tester, Scaffold(bottomNavigationBar: _bar()));
      expect(_barRect(tester).bottom, 740);
      expect(_primary(tester).bottom, 740 - 34 - MmSpace.s4);
      expect(_secondary(tester).left, 20 + MmSpace.s4);
      expect(_primary(tester).right, 360 - 10 - MmSpace.s4);
    });

    testWidgets('rises above the keyboard as a bottom bar', (tester) async {
      _showKeyboard(tester);
      await pumpScreen(
        tester,
        Scaffold(body: const TextField(), bottomNavigationBar: _bar()),
      );
      expect(_primary(tester).bottom, 740 - 300 - MmSpace.s4);
      expect(_barRect(tester).bottom, 740);
    });

    testWidgets('rises above the keyboard in a page', (tester) async {
      _showKeyboard(tester);
      await pumpScreen(
        tester,
        MmPage(
          title: 'Record payment',
          body: const TextField(),
          bottomBar: _bar(),
        ),
      );
      expect(_primary(tester).bottom, 740 - 300 - MmSpace.s4);
    });

    testWidgets('as a bottom sheet, the scaffold lifts it', (tester) async {
      _showKeyboard(tester);
      await pumpScreen(tester, Scaffold(bottomSheet: _bar()));
      expect(_barRect(tester).bottom, 740 - 300);
      expect(_primary(tester).bottom, 740 - 300 - MmSpace.s4);
    });

    testWidgets('as a bottom sheet of a scaffold that does not resize', (
      tester,
    ) async {
      _showKeyboard(tester);
      await pumpScreen(
        tester,
        Scaffold(resizeToAvoidBottomInset: false, bottomSheet: _bar()),
      );
      expect(_barRect(tester).bottom, 740);
      expect(_primary(tester).bottom, 740 - 300 - MmSpace.s4);
    });

    testWidgets('elsewhere, leaves the keyboard to its parent', (tester) async {
      _showKeyboard(tester);
      // In a scaffold's body, which the scaffold already resized.
      await pumpScreen(
        tester,
        Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: _bar()),
        ),
      );
      expect(_primary(tester).bottom, 740 - 300 - MmSpace.s4);
      // Outside any scaffold.
      await pumpScreen(
        tester,
        Material(
          child: Align(alignment: Alignment.bottomCenter, child: _bar()),
        ),
      );
      expect(_primary(tester).bottom, 740 - MmSpace.s4);
    });

    testWidgets('Tab reaches the secondary, then the primary', (tester) async {
      var saves = 0;
      var cancels = 0;
      await pumpThemed(
        tester,
        _bar(onPrimary: () => saves++, onSecondary: () => cancels++),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.text('Cancel')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.text('Save')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((cancels, saves), (1, 1));
    });

    testWidgets('reads the buttons in order; a disabled one says so', (
      tester,
    ) async {
      await pumpThemed(tester, _bar(onPrimary: null));
      expect(
        tester.getSemantics(find.byKey(_secondaryKey)),
        isSemantics(label: 'Cancel', isButton: true, isEnabled: true),
      );
      expect(
        tester.getSemantics(find.byKey(_primaryKey)),
        isSemantics(
          label: 'Save',
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
    });

    testWidgets('lays out again when the window or direction changes', (
      tester,
    ) async {
      await pumpThemed(tester, _bar());
      const half = (328 - 2 * MmSpace.s4 - MmActionBar.spacing) / 2;
      expect(_primary(tester).width, half);
      // The same settings again change nothing.
      await pumpThemed(tester, _bar());
      expect(_primary(tester).width, half);
      await pumpThemed(tester, _bar(), size: const Size(800, 740));
      expect(_primary(tester).width, lessThan(half));
      await pumpThemed(
        tester,
        _bar(),
        size: const Size(800, 740),
        variant: MmVariant.urdu,
      );
      expect(
        _primary(tester).center.dx,
        lessThan(_secondary(tester).center.dx),
      );
    });

    testWidgets('reports its intrinsic and dry sizes', (tester) async {
      await pumpThemed(
        tester,
        _bar(secondary: 'Share on WhatsApp', primary: 'Record payment'),
      );
      final buttons = _buttons(tester);
      final secondary = tester.renderObject<RenderBox>(
        find.byKey(_secondaryKey),
      );
      final primary = tester.renderObject<RenderBox>(find.byKey(_primaryKey));
      final secondaryWidth = secondary.getMaxIntrinsicWidth(double.infinity);
      final primaryWidth = primary.getMaxIntrinsicWidth(double.infinity);
      expect(
        buttons.getMaxIntrinsicWidth(double.infinity),
        secondaryWidth + MmActionBar.spacing + primaryWidth,
      );
      expect(
        buttons.getMinIntrinsicWidth(double.infinity),
        [
          secondary.getMinIntrinsicWidth(double.infinity),
          primary.getMinIntrinsicWidth(double.infinity),
        ].reduce((a, b) => a > b ? a : b),
      );
      // Narrow: stacked. Unbounded: one row.
      const height = MmSize.buttonHeight;
      expect(buttons.size.height, 2 * height + MmActionBar.spacing);
      expect(
        buttons.getMinIntrinsicHeight(296),
        2 * height + MmActionBar.spacing,
      );
      expect(buttons.getMaxIntrinsicHeight(double.infinity), height);
      expect(
        buttons.getDryLayout(const BoxConstraints(maxWidth: 296)),
        buttons.size,
      );
      expect(
        buttons.getDryLayout(const BoxConstraints()).width,
        secondaryWidth + MmActionBar.spacing + primaryWidth,
      );
    });

    testWidgets('200% text on a 320 dp phone fits', (tester) async {
      await pumpLargeNarrow(
        tester,
        _bar(secondary: 'Share on WhatsApp', primary: 'Record payment'),
      );
      expect(tester.takeException(), isNull);
      expect(_primary(tester).top, greaterThan(_secondary(tester).bottom));
    });

    testWidgets('200% text on a 320 dp phone fits in English and Urdu', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        _bar(secondary: 'واٹس ایپ پر بھیجیں', primary: 'ادائیگی درج کریں'),
      );
    });
  });
}
