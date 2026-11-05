import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/testing.dart';

const _columns = [
  MmDataColumn(label: 'Tenant'),
  MmDataColumn(label: 'Rent', numeric: true),
];

const _rows = [
  ['Ali Raza', 'Rs 45,000'],
  ['Ayesha Khan', 'Rs 1,25,000'],
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
      final figures = styleOf(tester, 'Rs 45,000');
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
      expect(tester.getRect(find.text('Rs 45,000')).right, table.right);
      expect(tester.getRect(find.text('Rs 1,25,000')).right, table.right);
      expect(tester.getRect(find.text('Rent')).right, table.right);
    });

    testWidgets('runs its columns from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        _table(
          columns: const [
            MmDataColumn(label: 'کرایہ دار'),
            MmDataColumn(label: 'کرایہ', numeric: true),
          ],
          rows: const [
            ['علی رضا', '45,000 روپے'],
          ],
        ),
        variant: MmVariant.urdu,
      );
      final table = tester.getRect(find.byType(MmDataTable));
      expect(tester.getRect(find.text('علی رضا')).right, table.right);
      expect(tester.getRect(find.text('کرایہ دار')).right, table.right);
      expect(tester.getRect(find.text('45,000 روپے')).left, table.left);
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
      final header = tester.getSemantics(find.text('Rent'));
      expect(header.label, 'Rent');
      expect(header.role, SemanticsRole.columnHeader);
      expect(header.flagsCollection.isHeader, isTrue);
      final cell = tester.getSemantics(find.text('Ali Raza'));
      expect(cell.role, SemanticsRole.cell);
      // Grouped figures are read as one number.
      expect(tester.getSemantics(find.text('Rs 1,25,000')).label, 'Rs 125000');
      final table = tester.getSemantics(find.byType(Table));
      expect(table.role, SemanticsRole.table);
      expect(labelsIn(table), [
        'Tenant',
        'Rent',
        'Ali Raza',
        'Rs 45000',
        'Ayesha Khan',
        'Rs 125000',
      ]);
      handle.dispose();
    });

    testWidgets('lets the first column take the width to spare', (
      tester,
    ) async {
      await pumpThemed(tester, _table());
      final table = tester.getRect(find.byType(MmDataTable));
      final rent = tester.getRect(find.text('Rs 1,25,000'));
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
      final ring = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(MmDataTable),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.border != null)
          .single;
      expect(
        ring.border,
        Border.all(
          color: colorsOf(MmVariant.light).focus,
          width: MmSize.focusRing,
        ),
      );
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
      expect(
        tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(MmDataTable),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .where((decoration) => decoration.border != null),
        isEmpty,
      );
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
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.getRect(find.text('2021')).left, greaterThan(since));
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
            MmDataColumn(label: 'Rent', numeric: true),
            MmDataColumn(label: 'Owes', numeric: true),
          ],
          rows: [
            ['Ayesha Khan', 'Shop 4', 'Rs 1,25,000', 'Rs 30,000'],
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
