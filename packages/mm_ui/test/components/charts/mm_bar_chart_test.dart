import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/components/charts/mm_bar_chart.dart';
import 'package:mm_ui/src/components/charts/mm_bar_layout.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';

import '../../support/testing.dart';
import 'samples.dart';

const _summary = 'Rent collected against rent due, June to November.';

const _months = ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'];

/// The rent chart: collected (solid) against due (outlined), by month.
Widget _rent({
  String? title = 'Rent, last 6 months',
  String? groupLabel = 'Month',
  List<String> months = _months,
  int count = 6,
  FocusNode? focusNode,
  bool autofocus = false,
  double width = 328,
}) => SizedBox(
  width: width,
  child: MmBarChart(
    title: title,
    semanticSummary: _summary,
    groupLabel: groupLabel,
    focusNode: focusNode,
    autofocus: autofocus,
    series: const [
      MmBarSeries(label: 'Collected'),
      MmBarSeries(label: 'Due', fill: MmBarFill.outlined),
    ],
    groups: [
      for (var i = 0; i < count; i++)
        MmBarGroup(label: months[i], values: [collected[i], due]),
    ],
  ),
);

/// Net income: one series with a loss in August.
Widget _net({String? title = 'Net income', double width = 328}) => SizedBox(
  width: width,
  child: MmBarChart(
    title: title,
    semanticSummary: 'Net income, June to November.',
    series: const [MmBarSeries(label: 'Net income')],
    groups: [
      for (final (index, month) in _months.indexed)
        MmBarGroup(label: month, values: [netIncome[index]]),
    ],
  ),
);

Finder get _plot => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is MmBarChartPainter,
);

MmBarChartPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_plot).painter! as MmBarChartPainter;

MmBarLayout _layout(WidgetTester tester) => _painter(tester).layout;

/// The global centre of group [index]'s band.
Offset _groupCentre(WidgetTester tester, int index) => tester
    .getTopLeft(_plot)
    .translate(
      _layout(tester).bands[index].center.dx,
      _layout(tester).bands[index].center.dy,
    );

/// The readout's group heading, or null when no readout is shown.
String? _readout(WidgetTester tester) =>
    _painter(tester).active == null ? null : _months[_painter(tester).active!];

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Rects of every axis label shown in the chart.
List<Rect> _axisLabelRects(WidgetTester tester) {
  final layout = _layout(tester);
  final origin = tester.getTopLeft(_plot);
  return [
    for (final tick in layout.ticks) tick.rect.shift(origin),
    for (final label in layout.labels) label.rect.shift(origin),
  ];
}

void main() {
  group('MmBarSeries and MmBarGroup', () {
    test('compare by value and describe themselves', () {
      const due = MmBarSeries(label: 'Due', fill: MmBarFill.outlined);
      expect(due, const MmBarSeries(label: 'Due', fill: MmBarFill.outlined));
      expect(
        due.hashCode,
        const MmBarSeries(label: 'Due', fill: MmBarFill.outlined).hashCode,
      );
      expect(due, isNot(const MmBarSeries(label: 'Due')));
      expect(
        due,
        isNot(const MmBarSeries(label: 'Paid', fill: MmBarFill.outlined)),
      );
      expect(const MmBarSeries(label: 'Due').fill, MmBarFill.solid);
      expect(due.toString(), 'MmBarSeries("Due", outlined)');

      const june = MmBarGroup(label: 'Jun', values: [Money.fromRupees(5)]);
      expect(
        june,
        const MmBarGroup(label: 'Jun', values: [Money.fromRupees(5)]),
      );
      expect(
        june.hashCode,
        const MmBarGroup(label: 'Jun', values: [Money.fromRupees(5)]).hashCode,
      );
      expect(
        june,
        isNot(const MmBarGroup(label: 'Jul', values: [Money.fromRupees(5)])),
      );
      expect(
        june,
        isNot(const MmBarGroup(label: 'Jun', values: [Money.fromRupees(6)])),
      );
      expect(june.toString(), startsWith('MmBarGroup("Jun", ['));
    });
  });

  group('MmBarChart', () {
    testEveryVariant('draws the first series solid and the second outlined', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, _rent(), variant: variant);
      final colors = colorsOf(variant);
      final painter = _painter(tester);
      expect(painter.marks, [
        MmChartMark(fill: colors.primary),
        MmChartMark(fill: colors.primaryContainer, stroke: colors.primary),
      ]);
      expect(painter.gridColor, colors.rule);
      expect(painter.baselineColor, colors.outline);
      // The legend keys match the bars.
      expect([
        for (final swatch in tester.widgetList<MmChartSwatch>(
          find.byType(MmChartSwatch),
        ))
          swatch.mark,
      ], painter.marks);
      // The outline and the fill both stand out from the surface.
      expect(
        mmContrastRatio(colors.primary, colors.surface),
        greaterThanOrEqualTo(3),
      );
      expect(styleOf(tester, 'Collected').color, colors.ink);
      expect(styleOf(tester, 'Jun').color, colors.inkMuted);
    });

    testEveryVariant('labels the y-axis in compact rupees, tabular figures', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, lakhGrouping(_rent()), variant: variant);
      final colors = colorsOf(variant);
      final ticks = [for (final tick in _layout(tester).ticks) tick.label];
      if (variant.locale.languageCode == 'ur') {
        expect(ticks.first, '0 روپے');
        expect(ticks.last, '1.25 لاکھ روپے');
      } else if (variant == MmVariant.largeText) {
        expect(ticks, ['Rs 0', 'Rs 50,000', 'Rs 1 lakh', 'Rs 1.5 lakh']);
      } else {
        expect(ticks, [
          'Rs 0',
          'Rs 25,000',
          'Rs 50,000',
          'Rs 75,000',
          'Rs 1 lakh',
          'Rs 1.25 lakh',
        ]);
      }
      final tick = styleOf(tester, ticks.last);
      expect(tick.color, colors.inkMuted);
      expect(tick.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(tick.fontFamily, contains(MmFontFamily.latin));
    });

    testWidgets('paints gridlines, rounded bar ends and the zero line', (
      tester,
    ) async {
      await pumpThemed(tester, _net());
      final colors = colorsOf(MmVariant.light);
      final layout = _layout(tester);
      final june = layout.bars[0].single;
      final august = layout.bars[2].single;
      const radius = Radius.circular(MmRadius.xs);
      expect(
        _plot,
        paints
          ..line(color: colors.rule, strokeWidth: MmSize.hairline)
          ..rrect(
            rrect: RRect.fromRectAndCorners(
              june,
              topLeft: radius,
              topRight: radius,
            ),
            color: colors.primary,
          )
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndCorners(
              august,
              bottomLeft: radius,
              bottomRight: radius,
            ),
            color: colors.primary,
          ),
      );
      // The zero line is drawn last, over the bars' square ends.
      expect(
        _plot,
        paints
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..line(color: colors.outline, strokeWidth: MmSize.hairline),
      );
      // August's loss is below the zero line.
      expect(august.top, closeTo(layout.baseline, 1e-9));
      expect(august.bottom, greaterThan(layout.baseline));
    });

    testWidgets("keeps a short bar's corners no larger than the bar", (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 328,
          child: MmBarChart(
            semanticSummary: 'Tiny',
            series: [MmBarSeries(label: 'Collected')],
            groups: [
              MmBarGroup(label: 'Jun', values: [Money.fromRupees(100000)]),
              MmBarGroup(label: 'Jul', values: [Money.fromRupees(100)]),
            ],
          ),
        ),
      );
      final bar = _layout(tester).bars[1].single;
      expect(bar.height, lessThan(MmRadius.xs));
      final radius = Radius.circular(bar.height);
      expect(
        _plot,
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndCorners(
              bar,
              topLeft: radius,
              topRight: radius,
            ),
          ),
      );
    });

    testWidgets('runs the groups from the start edge', (tester) async {
      await pumpThemed(tester, _rent());
      final plot = tester.getRect(_plot);
      final june = tester.getRect(find.text('Jun'));
      final november = tester.getRect(find.text('Nov'));
      expect(june.center.dx, lessThan(november.center.dx));
      // The y-axis labels sit at the start edge.
      expect(tester.getRect(find.text('Rs 0')).left, plot.left);
    });

    testWidgets('runs the groups from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        _rent(
          months: const ['جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر'],
        ),
        variant: MmVariant.urdu,
      );
      final layout = _layout(tester);
      expect(
        layout.bands.first.center.dx,
        greaterThan(layout.bands.last.center.dx),
      );
      final plot = tester.getRect(_plot);
      expect(
        tester.getRect(find.text('0 روپے')).right,
        lessThanOrEqualTo(plot.right),
      );
      expect(layout.ticks.first.rect.left, greaterThan(layout.plot.right));
      // Collected is the bar nearest the start edge: on the right.
      final june = layout.bars.first;
      expect(june[0].left, greaterThan(june[1].left));
    });

    testWidgets('shows a legend for two series, keyed by their marks', (
      tester,
    ) async {
      await pumpThemed(tester, _rent());
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.byType(MmChartSwatch), findsNWidgets(2));
      final title = tester.getRect(find.text('Rent, last 6 months'));
      final legend = tester.getRect(find.text('Collected'));
      expect(legend.top, greaterThan(title.bottom));
      expect(legend.bottom, lessThan(tester.getRect(_plot).top));
    });

    testWidgets('names a titled single series by its title, with no legend', (
      tester,
    ) async {
      await pumpThemed(tester, _net());
      expect(find.byType(MmChartSwatch), findsNothing);
      expect(find.text('Net income'), findsOneWidget);
    });

    testWidgets('keeps the legend of a single series with no title', (
      tester,
    ) async {
      await pumpThemed(tester, _net(title: null));
      expect(find.byType(MmChartSwatch), findsOneWidget);
      expect(find.text('Net income'), findsOneWidget);
      // The table toggle keeps to the end edge.
      final chart = tester.getRect(find.byType(MmBarChart));
      expect(tester.getRect(find.byType(TextButton)).right, chart.right);
    });

    testWidgets('puts the table toggle beside the title, or under it', (
      tester,
    ) async {
      await pumpThemed(tester, _net());
      final title = tester.getRect(find.text('Net income'));
      final toggle = tester.getRect(find.byType(TextButton));
      expect(toggle.center.dy, closeTo(title.center.dy, 1));
      expect(toggle.right, tester.getRect(find.byType(MmBarChart)).right);
      await pumpThemed(tester, _rent(width: 296));
      final longTitle = tester.getRect(find.text('Rent, last 6 months'));
      expect(
        tester.getRect(find.byType(TextButton)).top,
        greaterThanOrEqualTo(longTitle.bottom),
      );
    });

    testWidgets('fits a 360 dp phone with every group labelled', (
      tester,
    ) async {
      await pumpThemed(tester, _rent());
      expect(tester.takeException(), isNull);
      expect(_layout(tester).labels, hasLength(6));
      expect(_layout(tester).ticks, hasLength(6));
      for (final month in _months) {
        expect(find.text(month), findsOneWidget);
      }
    });

    testWidgets('lays out 320 dp when given no width', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 328,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: MmBarChart(
              semanticSummary: _summary,
              series: const [MmBarSeries(label: 'Collected')],
              groups: [
                for (final (index, month) in _months.indexed)
                  MmBarGroup(label: month, values: [collected[index]]),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MmBarChart)).width, 320);
      expect(_layout(tester).size.width, MmBarChart.unboundedWidth);
    });

    group('readout', () {
      testWidgets('tapping a group shows its exact amounts', (tester) async {
        await pumpThemed(tester, lakhGrouping(_rent()));
        expect(find.text('Rs 1,10,000'), findsNothing);
        await tester.tapAt(_groupCentre(tester, 0));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jun');
        expect(find.text('Rs 1,10,000'), findsOneWidget);
        expect(find.text('Rs 1,25,000'), findsOneWidget);
        // The readout keys each amount with its series.
        expect(find.byType(MmChartSwatch), findsNWidgets(4));
        expect(find.text('Collected'), findsNWidgets(2));
        // Its band is highlighted.
        expect(
          _painter(tester).highlightColor,
          colorsOf(MmVariant.light).primaryContainer.withValues(alpha: 0.5),
        );
        expect(
          _plot,
          paints..rrect(
            rrect: RRect.fromRectAndRadius(
              _layout(tester).bands[0],
              const Radius.circular(MmRadius.xs),
            ),
          ),
        );
      });

      testWidgets('sets the amounts in ink and the names in muted ink', (
        tester,
      ) async {
        await pumpThemed(tester, lakhGrouping(_rent()));
        await tester.tapAt(_groupCentre(tester, 3));
        await tester.pumpAndSettle();
        final colors = colorsOf(MmVariant.light);
        final amount = styleOf(tester, 'Rs 95,000');
        expect(amount.color, colors.ink);
        expect(amount.fontWeight, FontWeight.w600);
        expect(amount.fontFeatures, [const FontFeature.tabularFigures()]);
        final heading = tester.renderObject<RenderParagraph>(
          find.text('Sep').last,
        );
        expect(heading.text.style!.color, colors.ink);
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('Rs 95,000'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, colors.surface);
        expect(decoration.border, Border.all(color: colors.outline));
      });

      testWidgets('tapping the shown group again hides it', (tester) async {
        await pumpThemed(tester, _rent());
        await tester.tapAt(_groupCentre(tester, 2));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Aug');
        await tester.tapAt(_groupCentre(tester, 4));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Oct');
        await tester.tapAt(_groupCentre(tester, 4));
        await tester.pumpAndSettle();
        expect(_readout(tester), isNull);
        expect(_painter(tester).active, isNull);
      });

      testWidgets('tapping beside the plot hides it', (tester) async {
        await pumpThemed(tester, _rent());
        await tester.tapAt(_groupCentre(tester, 2));
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getTopLeft(_plot) + const Offset(2, 40));
        await tester.pumpAndSettle();
        expect(_readout(tester), isNull);
      });

      testWidgets('hovering shows the group under the pointer', (tester) async {
        await pumpThemed(tester, _rent());
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(_groupCentre(tester, 1));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jul');
        await mouse.moveTo(_groupCentre(tester, 5));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Nov');
        await mouse.moveTo(tester.getTopLeft(_plot) + const Offset(2, 40));
        await tester.pumpAndSettle();
        expect(_readout(tester), isNull);
        await mouse.moveTo(_groupCentre(tester, 0));
        await tester.pumpAndSettle();
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(_readout(tester), isNull);
      });

      for (final width in [328.0, 296.0]) {
        testWidgets('never covers its own bars, $width dp wide', (
          tester,
        ) async {
          await pumpThemed(tester, lakhGrouping(_rent(width: width)));
          final origin = tester.getTopLeft(_plot);
          final chart = tester.getRect(_plot);
          final plot = _layout(tester).plot.shift(origin);
          for (var group = 0; group < 6; group++) {
            await tester.tapAt(_groupCentre(tester, group));
            await tester.pumpAndSettle();
            final readout = tester.getRect(
              find
                  .ancestor(
                    of: find.text(_months[group]).last,
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            );
            final band = _layout(tester).bands[group].shift(origin);
            expect(
              readout.left >= band.right || readout.right <= band.left,
              isTrue,
              reason: '${_months[group]} readout covers its own bars',
            );
            expect(readout.left, greaterThanOrEqualTo(chart.left));
            expect(readout.right, lessThanOrEqualTo(chart.right));
            expect(readout.top, plot.top);
            await tester.tapAt(_groupCentre(tester, group));
            await tester.pumpAndSettle();
          }
        });
      }

      testWidgets('keeps clear of the axis labels when the plot has room', (
        tester,
      ) async {
        await pumpThemed(tester, _rent());
        final origin = tester.getTopLeft(_plot);
        final plot = _layout(tester).plot.shift(origin);
        for (final group in [0, 1, 4, 5]) {
          await tester.tapAt(_groupCentre(tester, group));
          await tester.pumpAndSettle();
          final readout = tester.getRect(
            find
                .ancestor(
                  of: find.text(_months[group]).last,
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(readout.left, greaterThanOrEqualTo(plot.left));
        }
      });

      testWidgets('wraps a series name under its amount, never mid-word', (
        tester,
      ) async {
        await pumpLargeNarrow(tester, lakhGrouping(_rent(width: 288)));
        await tester.tapAt(_groupCentre(tester, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final name = paragraphOf(tester, 'Collected');
        // In the readout (the last "Collected"), the word is on one line.
        final readoutName = tester.renderObject<RenderParagraph>(
          find.text('Collected').last,
        );
        expect(
          readoutName.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 9),
          ),
          hasLength(1),
        );
        expect(name, isNotNull);
      });
    });

    group('keyboard', () {
      testWidgets('takes focus after the toggle, with a ring and a readout', (
        tester,
      ) async {
        useKeyboardHighlights();
        await pumpThemed(tester, _rent());
        await _key(tester, LogicalKeyboardKey.tab);
        expect(focusedAt(tester, 'Show as a table'), isTrue);
        await _key(tester, LogicalKeyboardKey.tab);
        expect(_readout(tester), 'Jun');
        final ring = tester
            .widgetList<DecoratedBox>(
              find.ancestor(of: _plot, matching: find.byType(DecoratedBox)),
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
      });

      testWidgets('moves between groups with the arrow keys, Home and End', (
        tester,
      ) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(tester, _rent(focusNode: focus));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jun');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Jul');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Aug');
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Jul');
        await _key(tester, LogicalKeyboardKey.end);
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.home);
        expect(_readout(tester), 'Jun');
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Jun');
      });

      testWidgets('Escape hides the readout, then lets the key through', (
        tester,
      ) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var escapes = 0;
        await pumpThemed(
          tester,
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () => escapes++,
            },
            child: _rent(focusNode: focus),
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        await _key(tester, LogicalKeyboardKey.escape);
        expect(_readout(tester), isNull);
        expect(escapes, 0);
        await _key(tester, LogicalKeyboardKey.escape);
        expect(escapes, 1);
        // An arrow key brings it back, from the edge it points away from.
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.escape);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Jun');
      });

      testWidgets('moves the other way in Urdu, where time runs leftward', (
        tester,
      ) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(
          tester,
          _rent(focusNode: focus),
          variant: MmVariant.urdu,
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jun');
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Jul');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Jun');
        // The readout opens toward the start of time: left of the band.
        final band = _layout(tester).bands[0].shift(tester.getTopLeft(_plot));
        final readout = tester.getRect(
          find
              .ancestor(
                of: find.text('Jun').last,
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(readout.right, lessThanOrEqualTo(band.left));
      });

      testWidgets('hides the readout when focus leaves', (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(tester, _rent(focusNode: focus));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jun');
        focus.unfocus();
        await tester.pumpAndSettle();
        expect(_readout(tester), isNull);
      });

      testWidgets('keeps a tapped group when focus arrives', (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(tester, _rent(focusNode: focus));
        await tester.tapAt(_groupCentre(tester, 3));
        await tester.pumpAndSettle();
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Sep');
      });

      testWidgets('keeps the readout on hover exit while focused', (
        tester,
      ) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(tester, _rent(focusNode: focus));
        focus.requestFocus();
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: _groupCentre(tester, 2));
        await tester.pumpAndSettle();
        await mouse.moveTo(_groupCentre(tester, 2) + const Offset(1, 0));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Aug');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Aug');
      });

      testWidgets('shows the first group when autofocused', (tester) async {
        await pumpThemed(tester, _rent(autofocus: true));
        expect(_readout(tester), 'Jun');
      });
    });

    group('semantics', () {
      testWidgets('reads the summary, then the shown group in plain figures', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(tester, lakhGrouping(_rent(focusNode: focus)));
        final chart = tester.getSemantics(_plot);
        expect(chart.label, _summary);
        expect(chart.value, isEmpty);
        expect(chart.flagsCollection.isFocused, isNot(Tristate.none));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(_plot).value,
          'Jun\nCollected 110000 rupees\nDue 125000 rupees',
        );
        expect(
          tester.getSemantics(find.text('Rent, last 6 months')),
          matchesSemantics(label: 'Rent, last 6 months', isHeader: true),
        );
        expect(
          tester.getSemantics(find.byType(TextButton)),
          matchesSemantics(
            label: 'Show as a table',
            isButton: true,
            isFocusable: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        // The axis labels and the readout are not read twice.
        expect(find.bySemanticsLabel('Rs 0'), findsNothing);
        expect(find.bySemanticsLabel('Jun'), findsNothing);
        handle.dispose();
      });

      testWidgets('reads the Urdu readout with the Urdu currency word', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpThemed(
          tester,
          _rent(autofocus: true, title: 'کرایہ'),
          variant: MmVariant.urdu,
        );
        expect(
          tester.getSemantics(_plot).value,
          'Jun\nCollected 110000 روپے\nDue 125000 روپے',
        );
        handle.dispose();
      });
    });

    group('table view', () {
      testWidgets('swaps the chart for a table of the same amounts', (
        tester,
      ) async {
        await pumpThemed(tester, lakhGrouping(_rent()));
        await tester.tap(find.text('Show as a table'));
        await tester.pumpAndSettle();
        expect(_plot, findsNothing);
        final table = tester.widget<MmDataTable>(find.byType(MmDataTable));
        expect(table.columns, const [
          MmDataColumn(label: 'Month'),
          MmDataColumn(label: 'Collected', numeric: true),
          MmDataColumn(label: 'Due', numeric: true),
        ]);
        expect(table.rows.first, ['Jun', 'Rs 1,10,000', 'Rs 1,25,000']);
        expect(table.rows.last, ['Nov', 'Rs 45,000', 'Rs 1,25,000']);
        expect(table.rows, hasLength(6));
        // The legend stays; the toggle now offers the chart back.
        expect(find.byType(MmChartSwatch), findsNWidgets(2));
        expect(find.text('Show as a chart'), findsOneWidget);
        await tester.tap(find.text('Show as a chart'));
        await tester.pumpAndSettle();
        expect(find.byType(MmDataTable), findsNothing);
        expect(_plot, findsOneWidget);
        expect(find.text('Show as a table'), findsOneWidget);
      });

      testWidgets('leaves the group header blank without a group label', (
        tester,
      ) async {
        await pumpThemed(tester, _rent(groupLabel: null));
        await tester.tap(find.text('Show as a table'));
        await tester.pumpAndSettle();
        final table = tester.widget<MmDataTable>(find.byType(MmDataTable));
        expect(table.columns.first, const MmDataColumn(label: ''));
      });

      testWidgets('hides the readout when it swaps', (tester) async {
        await pumpThemed(tester, _rent());
        await tester.tapAt(_groupCentre(tester, 1));
        await tester.pumpAndSettle();
        expect(_painter(tester).active, 1);
        await tester.tap(find.text('Show as a table'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Show as a chart'));
        await tester.pumpAndSettle();
        expect(_painter(tester).active, isNull);
      });

      testWidgets('uses the Urdu toggle words', (tester) async {
        await pumpThemed(tester, _rent(), variant: MmVariant.urdu);
        expect(find.text('جدول کی شکل میں دکھائیں'), findsOneWidget);
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        expect(find.text('چارٹ کی شکل میں دکھائیں'), findsOneWidget);
      });
    });

    testWidgets('keeps the readout on a group that still exists', (
      tester,
    ) async {
      await pumpThemed(tester, _rent());
      await tester.tapAt(_groupCentre(tester, 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(themed(_rent(count: 3)));
      await tester.pumpAndSettle();
      expect(_painter(tester).active, 2);
      await tester.pumpWidget(themed(_rent(count: 4)));
      await tester.pumpAndSettle();
      expect(_painter(tester).active, 2);
      await tester.pumpWidget(themed(_rent(count: 0)));
      await tester.pumpAndSettle();
      expect(_painter(tester).active, isNull);
    });

    testWidgets('shows an empty chart without groups', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(tester, _rent(count: 0, focusNode: focus));
      expect(tester.takeException(), isNull);
      expect(_layout(tester).ticks.single.label, 'Rs 0');
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(_painter(tester).active, isNull);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_painter(tester).active, isNull);
    });

    testWidgets('repaints only when what it draws changes', (tester) async {
      await pumpThemed(tester, _rent());
      final painter = _painter(tester);
      MmBarChartPainter copy({
        int? active,
        Color? grid,
        Color? baseline,
        Color? highlight,
        List<MmChartMark>? marks,
      }) => MmBarChartPainter(
        layout: painter.layout,
        marks: marks ?? painter.marks,
        active: active,
        gridColor: grid ?? painter.gridColor,
        baselineColor: baseline ?? painter.baselineColor,
        highlightColor: highlight ?? painter.highlightColor,
      );
      expect(painter.shouldRepaint(copy()), isFalse);
      expect(painter.shouldRepaint(copy(active: 1)), isTrue);
      expect(
        painter.shouldRepaint(copy(grid: const Color(0xFF000000))),
        isTrue,
      );
      expect(
        painter.shouldRepaint(copy(baseline: const Color(0xFF000000))),
        isTrue,
      );
      expect(
        painter.shouldRepaint(copy(highlight: const Color(0xFF000000))),
        isTrue,
      );
      expect(painter.shouldRepaint(copy(marks: const [])), isTrue);
    });

    testWidgets('at 200% on a 320 dp phone, keeps the axis labels apart', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(tester, lakhGrouping(_rent()));
      await pumpLargeNarrow(tester, lakhGrouping(_rent(width: 288)));
      final rects = _axisLabelRects(tester);
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: 'axis labels $i and $j overlap',
          );
        }
      }
      expect(_layout(tester).labels.length, lessThan(6));
      expect(_layout(tester).ticks.length, lessThan(6));
    });

    testWidgets('in Urdu at 200%, keeps the axis labels apart', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themedApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(MmSpace.s4),
              child: lakhGrouping(
                _rent(
                  width: 288,
                  months: const [
                    'جون',
                    'جولائی',
                    'اگست',
                    'ستمبر',
                    'اکتوبر',
                    'نومبر',
                  ],
                ),
              ),
            ),
          ),
          variant: MmVariant.largeText,
          locale: const Locale('ur'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rects = _axisLabelRects(tester);
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
    });

    testWidgets('meets the accessibility guidelines with a readout shown', (
      tester,
    ) async {
      await pumpThemed(tester, _rent(autofocus: true));
      await expectAccessible(tester);
    });
  });
}
