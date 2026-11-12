import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

/// A cell at least [height] tall that grows to what it is given.
Widget _cell(int index, {double height = 40}) => ConstrainedBox(
  key: ValueKey(index),
  constraints: BoxConstraints(minHeight: height),
  child: const SizedBox.shrink(),
);

Rect _cellRect(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey(index)));

/// The grid's render box.
RenderBox _grid(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byType(MmResponsiveGrid));

Future<void> _pumpGrid(
  WidgetTester tester,
  MmResponsiveGrid grid, {
  double width = 328,
  MmVariant variant = MmVariant.light,
}) => pumpThemed(
  tester,
  SizedBox(width: width, child: grid),
  variant: variant,
  size: Size(width + 2 * MmSpace.s4, 740),
);

void main() {
  group('MmResponsiveGrid', () {
    testWidgets('fits as many equal columns as it can', (tester) async {
      for (final (width, minItemWidth, columns) in [
        (328.0, 140.0, 2),
        (328.0, 280.0, 1),
        (900.0, 280.0, 3),
        (888.0, 288.0, 3),
        (200.0, 280.0, 1),
      ]) {
        await _pumpGrid(
          tester,
          MmResponsiveGrid(
            minItemWidth: minItemWidth,
            children: [for (var i = 0; i < 6; i++) _cell(i)],
          ),
          width: width,
        );
        final cellWidth = (width - MmSpace.s3 * (columns - 1)) / columns;
        final origin = tester.getTopLeft(find.byType(MmResponsiveGrid));
        for (var i = 0; i < 6; i++) {
          final cell = _cellRect(tester, i);
          expect(cell.width, closeTo(cellWidth, 0.01), reason: '$width/$i');
          final column = i % columns;
          expect(
            cell.left - origin.dx,
            closeTo(column * (cellWidth + MmSpace.s3), 0.01),
          );
        }
      }
    });

    testWidgets('a narrow grid still has one column, as wide as itself', (
      tester,
    ) async {
      await _pumpGrid(
        tester,
        MmResponsiveGrid(children: [_cell(0), _cell(1)]),
        width: 200,
      );
      expect(_cellRect(tester, 0).width, 200);
      expect(
        _cellRect(tester, 1).top,
        _cellRect(tester, 0).bottom + MmSpace.s3,
      );
    });

    testWidgets('rows are as tall as their tallest child, which all fill', (
      tester,
    ) async {
      await _pumpGrid(
        tester,
        MmResponsiveGrid(
          minItemWidth: 100,
          children: [
            _cell(0),
            _cell(1, height: 90),
            _cell(2, height: 60),
            _cell(3, height: 30),
          ],
        ),
      );
      // Three columns: 0 1 2 / 3.
      for (var i = 0; i < 3; i++) {
        expect(_cellRect(tester, i).height, 90);
      }
      expect(_cellRect(tester, 3).top, _cellRect(tester, 0).top + 90 + 12);
      expect(_cellRect(tester, 3).height, 30);
      expect(
        tester.getSize(find.byType(MmResponsiveGrid)).height,
        90 + 12 + 30,
      );
    });

    testWidgets('takes its spacing between columns and rows', (tester) async {
      await _pumpGrid(
        tester,
        MmResponsiveGrid(
          minItemWidth: 150,
          spacing: MmSpace.s6,
          children: [for (var i = 0; i < 4; i++) _cell(i)],
        ),
      );
      final first = _cellRect(tester, 0);
      expect(_cellRect(tester, 1).left, first.right + MmSpace.s6);
      expect(_cellRect(tester, 2).top, first.bottom + MmSpace.s6);
      expect(first.width, (328 - MmSpace.s6) / 2);
    });

    testWidgets('fills rows from the right in Urdu', (tester) async {
      await _pumpGrid(
        tester,
        MmResponsiveGrid(
          minItemWidth: 100,
          children: [for (var i = 0; i < 4; i++) _cell(i)],
        ),
        variant: MmVariant.urdu,
      );
      final grid = tester.getRect(find.byType(MmResponsiveGrid));
      expect(_cellRect(tester, 0).right, grid.right);
      expect(_cellRect(tester, 2).left, closeTo(grid.left, 0.01));
      expect(_cellRect(tester, 3).right, grid.right);
    });

    testWidgets('has no height without children', (tester) async {
      await _pumpGrid(tester, const MmResponsiveGrid(children: []));
      expect(tester.getSize(find.byType(MmResponsiveGrid)), const Size(328, 0));
      expect(_grid(tester).getMaxIntrinsicWidth(double.infinity), 0);
      expect(_grid(tester).getMinIntrinsicHeight(328), 0);
    });

    testWidgets('without a width limit, puts every child in one row', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: MmResponsiveGrid(
            minItemWidth: 120,
            children: [for (var i = 0; i < 3; i++) _cell(i)],
          ),
        ),
      );
      expect(tester.getSize(find.byType(MmResponsiveGrid)).width, 3 * 120 + 24);
      for (var i = 0; i < 3; i++) {
        expect(_cellRect(tester, i).width, 120);
        expect(_cellRect(tester, i).top, _cellRect(tester, 0).top);
      }
    });

    testWidgets('reports its intrinsic and dry sizes', (tester) async {
      await _pumpGrid(
        tester,
        MmResponsiveGrid(
          minItemWidth: 100,
          children: [
            const SizedBox(width: 60, height: 40),
            const SizedBox(width: 130, height: 90),
            _cell(2, height: 50),
          ],
        ),
      );
      final grid = _grid(tester);
      // One column at least as wide as the widest child.
      expect(grid.getMinIntrinsicWidth(double.infinity), 130);
      // Everything in one row, columns as wide as the widest child.
      expect(grid.getMaxIntrinsicWidth(double.infinity), 3 * 130 + 2 * 12);
      // At 328 dp: three columns, one row as tall as the tallest.
      expect(grid.getMinIntrinsicHeight(328), 90);
      expect(grid.getMaxIntrinsicHeight(328), 90);
      // At 200 dp: one column, three rows.
      expect(grid.getMaxIntrinsicHeight(200), 40 + 90 + 50 + 2 * 12);
      expect(
        grid.getDryLayout(const BoxConstraints(maxWidth: 212)),
        const Size(212, 90 + 12 + 50),
      );
      expect(
        grid.getDryLayout(const BoxConstraints()),
        const Size(3 * 100 + 24, 90),
      );
      expect(grid.size, const Size(328, 90));
    });

    testWidgets('its baseline is its first child', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 328,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Due'),
              Expanded(
                child: MmResponsiveGrid(
                  minItemWidth: 100,
                  children: [Text('Rs 45,000'), Text('Rs 80,000')],
                ),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getBottomLeft(find.text('Due')).dy,
        tester.getBottomLeft(find.text('Rs 45,000')).dy,
      );
    });

    testWidgets('lays out again when its settings change', (tester) async {
      late StateSetter update;
      var minItemWidth = 100.0;
      var spacing = MmSpace.s3;
      var direction = TextDirection.ltr;
      await pumpThemed(
        tester,
        SizedBox(
          width: 328,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Directionality(
                textDirection: direction,
                child: MmResponsiveGrid(
                  minItemWidth: minItemWidth,
                  spacing: spacing,
                  children: [for (var i = 0; i < 3; i++) _cell(i)],
                ),
              );
            },
          ),
        ),
      );
      final left = tester.getTopLeft(find.byType(MmResponsiveGrid)).dx;
      expect(_cellRect(tester, 1).top, _cellRect(tester, 0).top);

      // The same settings again change nothing.
      update(() {});
      await tester.pump();
      expect(_cellRect(tester, 1).top, _cellRect(tester, 0).top);

      update(() => minItemWidth = 200);
      await tester.pump();
      expect(_cellRect(tester, 1).top, greaterThan(_cellRect(tester, 0).top));

      update(() => spacing = MmSpace.s6);
      await tester.pump();
      expect(
        _cellRect(tester, 1).top,
        _cellRect(tester, 0).bottom + MmSpace.s6,
      );

      update(() {
        minItemWidth = 100;
        direction = TextDirection.rtl;
      });
      await tester.pump();
      expect(_cellRect(tester, 0).right, left + 328);
    });

    testWidgets('children can be tapped', (tester) async {
      final taps = <int>[];
      await _pumpGrid(
        tester,
        MmResponsiveGrid(
          minItemWidth: 100,
          children: [
            for (var i = 0; i < 4; i++)
              TextButton(onPressed: () => taps.add(i), child: Text('Unit $i')),
          ],
        ),
      );
      await tester.tap(find.text('Unit 3'));
      await tester.tap(find.text('Unit 1'));
      expect(taps, [3, 1]);
    });

    testWidgets('keyboard focus finishes one child before the next', (
      tester,
    ) async {
      Widget card(String name) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: tapped, child: Text('$name rent')),
          TextButton(onPressed: tapped, child: Text('$name bills')),
        ],
      );
      await _pumpGrid(
        tester,
        MmResponsiveGrid(
          minItemWidth: 140,
          children: [card('Ali'), card('Bilal')],
        ),
      );
      final order = <String>[];
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        for (final label in [
          'Ali rent',
          'Ali bills',
          'Bilal rent',
          'Bilal bills',
        ]) {
          if (hasFocus(tester, find.text(label))) order.add(label);
        }
      }
      expect(order, ['Ali rent', 'Ali bills', 'Bilal rent', 'Bilal bills']);
    });

    testWidgets('keyed children keep their state when reordered', (
      tester,
    ) async {
      Widget field(String key) =>
          SizedBox(key: ValueKey(key), child: const TextField());
      await _pumpGrid(
        tester,
        MmResponsiveGrid(children: [field('ali'), field('bilal')]),
      );
      await tester.enterText(find.byType(TextField).first, 'Flat 3');
      await _pumpGrid(
        tester,
        MmResponsiveGrid(children: [field('bilal'), field('ali')]),
      );
      final ali = find.descendant(
        of: find.byKey(const ValueKey('ali')),
        matching: find.text('Flat 3'),
      );
      expect(ali, findsOneWidget);
      expect(
        tester.getTopLeft(ali).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('bilal'))).dy),
      );
    });

    testWidgets('200% text on a 320 dp phone fits', (tester) async {
      await pumpLargeNarrow(
        tester,
        const MmResponsiveGrid(
          minItemWidth: 120,
          children: [
            Text('Rent due this month'),
            Text('Vacant units in Gulberg'),
            Text('Overdue'),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text on a 320 dp phone fits in English and Urdu', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmResponsiveGrid(
          minItemWidth: 120,
          children: [
            Text('اس مہینے کا کرایہ'),
            Text('گلبرگ میں خالی یونٹ'),
            Text('لیٹ'),
          ],
        ),
      );
    });

    test('needs a positive item width and no negative spacing', () {
      double zero() => 0;
      expect(
        () => MmResponsiveGrid(minItemWidth: zero(), children: const []),
        throwsAssertionError,
      );
      expect(
        () => MmResponsiveGrid(spacing: zero() - 1, children: const []),
        throwsAssertionError,
      );
    });
  });
}
