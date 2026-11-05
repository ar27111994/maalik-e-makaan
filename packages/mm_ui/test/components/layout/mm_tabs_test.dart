import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _labels = ['Dues', 'Payments', 'Notes'];
const _many = ['Overview', 'Payments', 'Documents', 'Utilities', 'History'];

/// [labels] under a default controller, in a phone-wide column.
Widget _tabs({
  List<String> labels = _labels,
  ValueChanged<int>? onTap,
  int initialIndex = 0,
  double width = 328,
}) => SizedBox(
  width: width,
  child: DefaultTabController(
    length: labels.length,
    initialIndex: initialIndex,
    child: MmTabs(labels: labels, onTap: onTap),
  ),
);

TabBar _bar(WidgetTester tester) => tester.widget<TabBar>(find.byType(TabBar));

TabController _controllerOf(WidgetTester tester) =>
    DefaultTabController.of(tester.element(find.byType(MmTabs)));

void main() {
  group('MmTabs', () {
    testEveryVariant('cobalt marks the selected tab over a hairline rule', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      await pumpThemed(tester, _tabs(), variant: variant);
      // The theme styles the bar; the tabs add no colours of their own.
      final bar = _bar(tester);
      expect(bar.labelColor, isNull);
      expect(bar.indicator, isNull);
      final theme = TabBarTheme.of(tester.element(find.byType(MmTabs)));
      final indicator = theme.indicator! as UnderlineTabIndicator;
      expect(indicator.borderSide.color, colors.primary);
      expect(indicator.borderSide.width, MmSize.tabIndicator);
      expect(theme.indicatorSize, TabBarIndicatorSize.label);
      expect(theme.dividerColor, colors.rule);
      expect(theme.dividerHeight, MmSize.hairline);
      // As painted: the selected label cobalt, the others muted, all in the
      // label style they are measured in.
      final label = Theme.of(tester.element(find.byType(MmTabs)))
          .textTheme
          .labelLarge!;
      expect(bar.labelStyle, label);
      expect(bar.unselectedLabelStyle, label);
      final selected = styleOf(tester, _labels.first);
      expect(selected.color, colors.primary);
      expect(selected.fontSize, label.fontSize);
      expect(selected.fontWeight, label.fontWeight);
      expect(styleOf(tester, _labels.last).color, colors.inkMuted);
    });

    testWidgets('labels that fit share the width equally', (tester) async {
      await pumpThemed(tester, _tabs());
      final bar = _bar(tester);
      expect(bar.isScrollable, isFalse);
      expect(bar.tabAlignment, TabAlignment.fill);
      final widths = [
        for (final label in _labels)
          tester
              .getRect(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                ),
              )
              .width,
      ];
      expect(widths, everyElement(closeTo(328 / 3, 0.01)));
    });

    testWidgets('labels that do not fit scroll instead', (tester) async {
      final taps = <int>[];
      await pumpThemed(tester, _tabs(labels: _many, onTap: taps.add));
      final bar = _bar(tester);
      expect(bar.isScrollable, isTrue);
      expect(bar.tabAlignment, TabAlignment.start);
      // The first tab starts at the start edge.
      expect(
        tester.getRect(find.text('Overview')).left,
        tester.getRect(find.byType(MmTabs)).left + kTabLabelPadding.left,
      );
      await tester.drag(find.byType(TabBar), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(taps, [4]);
      expect(_controllerOf(tester).index, 4);
    });

    testWidgets('scroll from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        _tabs(labels: _many),
        variant: MmVariant.urdu,
        size: const Size(280, 740),
      );
      expect(_bar(tester).isScrollable, isTrue);
      expect(
        tester.getRect(find.text('Overview')).right,
        tester.getRect(find.byType(MmTabs)).right - kTabLabelPadding.right,
      );
    });

    testWidgets('three tabs scroll at 200% text on a 320 dp phone', (
      tester,
    ) async {
      await pumpLargeNarrow(tester, _tabs(width: 288));
      expect(_bar(tester).isScrollable, isTrue);
      expect(tester.takeException(), isNull);
      // Every label is whole: none is squeezed or faded.
      for (final label in _labels) {
        final text = tester.getRect(find.text(label));
        final tab = tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(Tab)),
        );
        expect(text.width, tab.width);
      }
    });

    testEveryVariant('tabs are at least 48 dp and grow with the text', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _tabs(), variant: variant);
      final tab = tester.getRect(find.byType(Tab).first);
      final text = tester.getRect(
        find.descendant(
          of: find.byType(Tab).first,
          matching: find.byType(Text),
        ),
      );
      expect(tab.height, greaterThanOrEqualTo(MmSize.minTarget));
      expect(tab.height, greaterThanOrEqualTo(text.height + 2 * MmSpace.s2));
    });

    testWidgets('selects with a tap through the default controller', (
      tester,
    ) async {
      final taps = <int>[];
      await pumpThemed(tester, _tabs(onTap: taps.add));
      await tester.tap(find.text('Payments'));
      await tester.pumpAndSettle();
      expect(_controllerOf(tester).index, 1);
      expect(taps, [1]);
    });

    testWidgets('follows the controller it is given', (tester) async {
      final controller = TabController(length: 3, vsync: const TestVSync());
      addTearDown(controller.dispose);
      await pumpThemed(
        tester,
        SizedBox(
          width: 328,
          child: MmTabs(labels: _labels, controller: controller),
        ),
      );
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
      controller.index = 0;
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Dues')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('reads each tab with its place and selection', (tester) async {
      await pumpThemed(tester, _tabs(initialIndex: 1));
      expect(
        tester.getSemantics(find.text('Payments')),
        isSemantics(
          label: 'Payments\nTab 2 of 3',
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Notes')),
        isSemantics(label: 'Notes\nTab 3 of 3', isSelected: false),
      );
    });

    testWidgets('Tab reaches the tabs, Enter and Space select', (tester) async {
      final taps = <int>[];
      await pumpThemed(tester, _tabs(onTap: taps.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Payments')),
        isSemantics(isFocused: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_controllerOf(tester).index, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(_controllerOf(tester).index, 2);
      expect(taps, [1, 2]);
    });

    testWidgets('needs at least one label', (tester) async {
      await pumpThemed(
        tester,
        const DefaultTabController(length: 0, child: MmTabs(labels: [])),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });
}
