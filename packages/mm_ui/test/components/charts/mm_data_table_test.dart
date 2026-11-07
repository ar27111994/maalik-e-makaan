import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/charts/mm_chart_focus_ring.dart';

import '../../support/testing.dart';

const _columns = [
  MmDataColumn(label: 'Tenant'),
  MmDataColumn(label: 'Rent (Rs)', numeric: true),
];

const _rows = [
  ['Ali Raza', '45,000'],
  ['Ayesha Khan', '1,25,000'],
];

/// A table [width] wide on the page.
Widget _table({
  List<MmDataColumn> columns = _columns,
  List<List<String>> rows = _rows,
  String? caption,
  double width = 328,
}) => SizedBox(
  width: width,
  child: MmDataTable(columns: columns, rows: rows, caption: caption),
);

/// A table of contacts too wide for a phone, which scrolls sideways.
Widget _wideTable({double width = 296}) => _table(
  width: width,
  columns: const [
    MmDataColumn(label: 'Tenant'),
    MmDataColumn(label: 'Phone'),
    MmDataColumn(label: 'CNIC'),
    MmDataColumn(label: 'Since', numeric: true),
  ],
  rows: const [
    ['Ali Raza', '0300 1234567', '35202-1234567-1', '2021'],
    ['Ayesha Khan', '0321 7654321', '35201-7654321-2', '2023'],
  ],
);

ScrollPosition _scrollOf(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(MmDataTable),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  group('MmDataColumn', () {
    test('compares by label and kind and describes itself', () {
      const rent = MmDataColumn(label: 'Rent', numeric: true);
      expect(rent, const MmDataColumn(label: 'Rent', numeric: true));
      expect(
        rent.hashCode,
        const MmDataColumn(label: 'Rent', numeric: true).hashCode,
      );
      expect(rent, isNot(const MmDataColumn(label: 'Rent')));
      expect(rent, isNot(const MmDataColumn(label: 'Owes', numeric: true)));
      expect(rent.numeric, isTrue);
      expect(const MmDataColumn(label: 'Tenant').numeric, isFalse);
      expect(rent.toString(), 'MmDataColumn("Rent", numeric)');
      expect(
        const MmDataColumn(label: 'Tenant').toString(),
        'MmDataColumn("Tenant")',
      );
    });
  });

  group('MmDataTable', () {
    testEveryVariant('sets headers in muted ink and cells in ink', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _table(caption: 'Rent roll'), variant: variant);
      final colors = colorsOf(variant);
      final text = variant.theme.textTheme;
      final header = styleOf(tester, 'Tenant');
      expect(header.color, colors.inkMuted);
      expect(header.fontWeight, text.labelLarge!.fontWeight);
      expect(styleOf(tester, 'Ali Raza').color, colors.ink);
      final caption = styleOf(tester, 'Rent roll');
      expect(caption.fontSize, text.titleMedium!.fontSize);
    });

    testEveryVariant('sets figures in the Latin face with tabular figures', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _table(), variant: variant);
      final figures = styleOf(tester, '45,000');
      expect(figures.fontFamily, contains(MmFontFamily.latin));
      expect(figures.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(figures.color, colorsOf(variant).ink);
    });

    testWidgets('aligns figures to the end edge and words to the start', (
      tester,
    ) async {
      await pumpThemed(tester, _table());
      final table = tester.getRect(find.byType(MmDataTable));
      expect(tester.getRect(find.text('Ali Raza')).left, table.left);
      expect(tester.getRect(find.text('Tenant')).left, table.left);
      expect(tester.getRect(find.text('45,000')).right, table.right);
      expect(tester.getRect(find.text('1,25,000')).right, table.right);
      expect(tester.getRect(find.text('Rent (Rs)')).right, table.right);
    });

    testWidgets('runs its columns from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        _table(
          columns: const [
            MmDataColumn(label: 'کرایہ دار'),
            MmDataColumn(label: 'کرایہ (روپے)', numeric: true),
          ],
          rows: const [
            ['علی رضا', '45,000'],
            ['عائشہ خان', '1,25,000'],
          ],
        ),
        variant: MmVariant.urdu,
      );
      final table = tester.getRect(find.byType(MmDataTable));
      expect(tester.getRect(find.text('علی رضا')).right, table.right);
      expect(tester.getRect(find.text('کرایہ دار')).right, table.right);
      // The figures keep to the end edge (the left) and line up on their
      // last digit, on the right, as in English; their header too.
      final short = tester.getRect(find.text('45,000'));
      final long = tester.getRect(find.text('1,25,000'));
      final header = tester.getRect(find.text('کرایہ (روپے)'));
      expect(header.left, table.left);
      expect(short.right, long.right);
      expect(header.right, long.right);
      expect(short.left, greaterThan(long.left));
    });

    testWidgets('keeps each cell in its own direction', (tester) async {
      await pumpThemed(
        tester,
        _table(
          columns: const [
            MmDataColumn(label: 'کرایہ دار'),
            MmDataColumn(label: 'فون'),
          ],
          rows: const [
            ['Ali Raza', '0300 1234567'],
            ['فاطمہ نور', '0321 7654321'],
          ],
        ),
        variant: MmVariant.urdu,
      );
      expect(
        paragraphOf(tester, '0300 1234567').textDirection,
        TextDirection.ltr,
      );
      expect(paragraphOf(tester, 'Ali Raza').textDirection, TextDirection.ltr);
      expect(paragraphOf(tester, 'فاطمہ نور').textDirection, TextDirection.rtl);
      // The phone number reads in its own order: 0300 on the left.
      final number = paragraphOf(tester, '0300 1234567');
      final first = number
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          )
          .single;
      final last = number
          .getBoxesForSelection(
            const TextSelection(baseOffset: 5, extentOffset: 12),
          )
          .single;
      expect(first.left, lessThan(last.left));
      // A name typed in English is set in the Latin face in the Urdu UI.
      expect(
        styleOf(tester, 'Ali Raza').fontFamily,
        contains(MmFontFamily.latin),
      );
    });

    testWidgets('divides rows with hairline rules and no stripes', (
      tester,
    ) async {
      await pumpThemed(tester, _table());
      final table = tester.widget<Table>(find.byType(Table));
      final rule = BorderSide(color: colorsOf(MmVariant.light).rule);
      expect(table.border, TableBorder(horizontalInside: rule, bottom: rule));
      expect(rule.width, MmSize.hairline);
      expect(table.children.every((row) => row.decoration == null), isTrue);
    });

    testWidgets('leaves out the caption when there is none', (tester) async {
      await pumpThemed(tester, _table());
      expect(find.byType(Text), findsNWidgets(6));
      await pumpThemed(tester, _table(caption: 'Rent roll'));
      expect(find.text('Rent roll'), findsOneWidget);
    });

    testWidgets('reads as a table: column headers, then a node per cell', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, _table(caption: 'Rent roll'));
      expect(
        tester.getSemantics(find.text('Rent roll')),
        matchesSemantics(label: 'Rent roll', isHeader: true),
      );
      final header = tester.getSemantics(find.text('Rent (Rs)'));
      expect(header.label, 'Rent (Rs)');
      expect(header.role, SemanticsRole.columnHeader);
      expect(header.flagsCollection.isHeader, isTrue);
      final cell = tester.getSemantics(find.text('Ali Raza'));
      expect(cell.role, SemanticsRole.cell);
      // Grouped figures are read as one number.
      expect(tester.getSemantics(find.text('1,25,000')).label, '125000');
      final table = tester.getSemantics(find.byType(Table));
      expect(table.role, SemanticsRole.table);
      expect(labelsIn(table), [
        'Tenant',
        'Rent (Rs)',
        'Ali Raza',
        '45000',
        'Ayesha Khan',
        '125000',
      ]);
      handle.dispose();
    });

    testWidgets('lets the first column take the width to spare', (
      tester,
    ) async {
      await pumpThemed(tester, _table());
      final table = tester.getRect(find.byType(MmDataTable));
      final rent = tester.getRect(find.text('1,25,000'));
      // The figure column is only as wide as its widest cell and its gap.
      expect(rent.left, greaterThan(table.center.dx));
      expect(_scrollOf(tester).maxScrollExtent, 0);
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isFalse,
      );
    });

    testWidgets('scrolls sideways with a scrollbar when too wide', (
      tester,
    ) async {
      await pumpThemed(tester, _wideTable());
      final position = _scrollOf(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.text('Ali Raza'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
    });

    testEveryVariant('draws the scrollbar in the control-border colour', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _wideTable(), variant: variant);
      final colors = colorsOf(variant);
      final theme = ScrollbarTheme.of(
        tester.element(find.byType(SingleChildScrollView)),
      );
      for (final states in [
        <WidgetState>{},
        {WidgetState.hovered},
        {WidgetState.dragged},
      ]) {
        expect(theme.thumbColor!.resolve(states), colors.outline);
      }
      // The only sign the table scrolls stands out from the card (3:1).
      expect(
        mmContrastRatio(colors.outline, colors.surface),
        greaterThanOrEqualTo(3),
      );
    });

    testWidgets('stops showing the scrollbar when it fits again', (
      tester,
    ) async {
      await pumpThemed(tester, _wideTable());
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isTrue,
      );
      tester.view.physicalSize = const Size(800, 740);
      await tester.pumpWidget(themed(_wideTable(width: 700)));
      await tester.pumpAndSettle();
      expect(_scrollOf(tester).maxScrollExtent, 0);
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).thumbVisibility,
        isFalse,
      );
    });

    testWidgets('scrolls with the arrow keys once focused, with a ring', (
      tester,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(tester, _wideTable());
      final position = _scrollOf(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      // Taking focus leaves the table at its start.
      expect(position.pixels, 0);
      final ring = find.descendant(
        of: find.byType(MmDataTable),
        matching: find.byType(MmChartFocusRing),
      );
      expect(tester.widget<MmChartFocusRing>(ring).shown, isTrue);
      // The ring goes round the scrolling area, outside it, so it covers
      // neither the first column's text nor the scrollbar.
      expect(tester.getRect(ring), tester.getRect(find.byType(Scrollbar)));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      final scrolled = position.pixels;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(position.pixels, lessThan(scrolled));
      // Focus leaves: the ring goes.
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<MmChartFocusRing>(ring).shown, isFalse);
    });

    testWidgets('takes no focus when it fits', (tester) async {
      await pumpThemed(tester, _table());
      expect(
        tester
            .widget<FocusableActionDetector>(
              find.byType(FocusableActionDetector),
            )
            .enabled,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.byType(Table))).hasFocus, isFalse);
    });

    testWidgets('scrolls from the right in Urdu', (tester) async {
      await pumpThemed(tester, _wideTable(), variant: MmVariant.urdu);
      final table = tester.getRect(find.byType(MmDataTable));
      // The first column is on the right, in view.
      expect(tester.getRect(find.text('Ali Raza')).right, table.right);
      expect(tester.getRect(find.text('2021')).right, lessThan(table.left));
    });

    testWidgets('in Urdu, the left arrow reveals the columns on the left', (
      tester,
    ) async {
      await pumpThemed(tester, _wideTable(), variant: MmVariant.urdu);
      final position = _scrollOf(tester);
      final since = tester.getRect(find.text('2021')).left;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.getRect(find.text('2021')).left, greaterThan(since));
      // The right arrow goes back, and stops at the start.
      for (var press = 0; press < 20; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
    });

    testWidgets('at 200% on a 320 dp phone, scrolls instead of overflowing', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(
        tester,
        const MmDataTable(
          caption: 'Rent roll, November',
          columns: [
            MmDataColumn(label: 'Tenant'),
            MmDataColumn(label: 'Unit'),
            MmDataColumn(label: 'Rent (Rs)', numeric: true),
            MmDataColumn(label: 'Owes (Rs)', numeric: true),
          ],
          rows: [
            ['Ayesha Khan', 'Shop 4', '1,25,000', '30,000'],
          ],
        ),
      );
    });

    testWidgets('meets the accessibility guidelines', (tester) async {
      await pumpThemed(tester, _wideTable());
      await expectAccessible(tester);
    });
  });
}
