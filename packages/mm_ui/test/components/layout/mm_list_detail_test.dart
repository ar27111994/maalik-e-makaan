import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';
import 'support.dart';

const ValueKey<String> _listKey = ValueKey('list');
const ValueKey<String> _detailKey = ValueKey('detail');
const ValueKey<String> _emptyKey = ValueKey('empty');

const _phone = Size(360, 740);
const _wide = Size(1000, 740);

/// Tenants, as two buttons stacked at the top of the pane.
Widget _list() => const Column(
  key: _listKey,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextButton(onPressed: tapped, child: Text('Ali Raza')),
    TextButton(onPressed: tapped, child: Text('Ayesha Khan')),
  ],
);

/// Ayesha Khan's details: an action at the top of the pane.
Widget _detail() => const Align(
  key: _detailKey,
  alignment: AlignmentDirectional.topStart,
  child: TextButton(onPressed: tapped, child: Text('Record payment')),
);

const _empty = Center(key: _emptyKey, child: Text('Choose a tenant'));

Widget _layout({Widget? detail, Widget? list}) => Scaffold(
  body: MmListDetail(
    list: list ?? _list(),
    detail: detail,
    emptyDetail: _empty,
  ),
);

void main() {
  group('MmListDetail', () {
    testWidgets('on a phone, shows the list when nothing is selected', (
      tester,
    ) async {
      await pumpScreen(tester, _layout());
      expect(find.byKey(_listKey), findsOneWidget);
      expect(find.byKey(_emptyKey), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(tester.getRect(find.byType(MmListDetail)).size, _phone);
    });

    testWidgets('on a phone, the detail covers the list', (tester) async {
      await pumpScreen(tester, _layout(detail: _detail()));
      expect(find.byKey(_detailKey), findsOneWidget);
      expect(tester.getRect(find.byKey(_detailKey)).size, _phone);
      // The list stays, hidden from sight, touch, screen readers and focus.
      expect(find.byKey(_listKey), findsNothing);
      expect(find.byKey(_listKey, skipOffstage: false), findsOneWidget);
      expect(find.bySemanticsLabel('Ali Raza'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.text('Record payment')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, find.text('Record payment')), isTrue);
    });

    testWidgets('on a phone, the list keeps its state under the detail', (
      tester,
    ) async {
      Widget layout({required bool selected}) => _layout(
        list: const TextField(key: _listKey),
        detail: selected ? _detail() : null,
      );
      await pumpScreen(tester, layout(selected: false));
      await tester.enterText(find.byKey(_listKey), 'Gulberg');
      await pumpScreen(tester, layout(selected: true));
      await pumpScreen(tester, layout(selected: false));
      expect(find.text('Gulberg'), findsOneWidget);
    });

    testWidgets('from expanded up, the list and the detail sit side by side', (
      tester,
    ) async {
      await pumpScreen(tester, _layout(detail: _detail()), size: _wide);
      final list = tester.getRect(find.byKey(_listKey));
      expect(list.left, 0);
      expect(list.width, MmListDetail.listWidth);
      expect(list.height, _wide.height);
      final rule = tester.getRect(find.byType(VerticalDivider));
      expect(rule.left, MmListDetail.listWidth);
      expect(rule.width, MmSize.hairline);
      final detail = tester.getRect(find.byKey(_detailKey));
      expect(detail.left, rule.right);
      expect(detail.right, _wide.width);
      expect(find.byKey(_emptyKey), findsNothing);
    });

    testWidgets('from expanded up, the empty detail stands in', (tester) async {
      await pumpScreen(tester, _layout(), size: _wide);
      expect(find.byKey(_listKey), findsOneWidget);
      final empty = tester.getRect(find.byKey(_emptyKey));
      expect(empty.left, MmListDetail.listWidth + MmSize.hairline);
      expect(empty.right, _wide.width);
    });

    testWidgets('still one at a time just below expanded', (tester) async {
      await pumpScreen(
        tester,
        _layout(detail: _detail()),
        size: const Size(MmBreakpoint.expanded - 1, 740),
      );
      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byKey(_listKey), findsNothing);
    });

    testWidgets('mirrors in Urdu: the list on the right', (tester) async {
      await pumpScreen(
        tester,
        _layout(detail: _detail()),
        size: _wide,
        variant: MmVariant.urdu,
      );
      final list = tester.getRect(find.byKey(_listKey));
      expect(list.right, _wide.width);
      final rule = tester.getRect(find.byType(VerticalDivider));
      expect(rule.right, list.left);
      expect(tester.getRect(find.byKey(_detailKey)).left, 0);
    });

    testWidgets('keyboard focus finishes the list before the detail', (
      tester,
    ) async {
      await pumpScreen(tester, _layout(detail: _detail()), size: _wide);
      final order = <String>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        for (final label in ['Ali Raza', 'Ayesha Khan', 'Record payment']) {
          if (hasFocus(tester, find.text(label))) order.add(label);
        }
      }
      expect(order, ['Ali Raza', 'Ayesha Khan', 'Record payment']);
    });

    testWidgets('both panes keep their state across size classes', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        _layout(
          list: const TextField(key: _listKey),
          detail: const TextField(key: _detailKey),
        ),
        size: _wide,
      );
      await tester.enterText(find.byKey(_listKey), 'Gulberg');
      await tester.enterText(find.byKey(_detailKey), '45,000');
      await resizeScreen(tester, _phone);
      expect(find.text('45,000'), findsOneWidget);
      expect(find.text('Gulberg', skipOffstage: false), findsOneWidget);
      await resizeScreen(tester, _wide);
      expect(find.text('Gulberg'), findsOneWidget);
      expect(find.text('45,000'), findsOneWidget);
    });

    testEveryVariant('the panes are parted by a hairline rule', (
      tester,
      variant,
    ) async {
      await pumpScreen(tester, _layout(), size: _wide, variant: variant);
      final rule = tester.widget<VerticalDivider>(find.byType(VerticalDivider));
      expect(rule.width, MmSize.hairline);
      expect(rule.thickness, MmSize.hairline);
      expect(
        DividerTheme.of(tester.element(find.byType(VerticalDivider))).color,
        colorsOf(variant).rule,
      );
    });

    testWidgets('200% text on a 320 dp phone fits', (tester) async {
      await pumpScreen(
        tester,
        _layout(detail: _detail()),
        size: const Size(320, 640),
        variant: MmVariant.largeText,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Record payment'), findsOneWidget);
    });
  });
}
