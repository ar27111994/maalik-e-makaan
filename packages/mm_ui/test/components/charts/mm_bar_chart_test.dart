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
import 'package:mm_ui/src/components/charts/mm_chart_focus_ring.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

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
      MmBarSeries(label: 'Due'),
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

/// The picked group, or null when none is.
String? _readout(WidgetTester tester) =>
    _painter(tester).active == null ? null : _months[_painter(tester).active!];

/// The readout on show.
Finder get _shownReadout => find.byType(MmBarReadout);

/// The label of the group the readout shows.
String? _shownGroup(WidgetTester tester) =>
    tester.widget<MmBarReadout>(_shownReadout).group?.label;

/// The box the readouts take, whichever one is shown.
Rect _readoutBox(WidgetTester tester) =>
    tester.getRect(find.byType(IndexedStack));

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

const _urduMonths = ['جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر'];

/// Pumps [child] on a phone [width] wide in a scrolling page, in [locale]
/// at [variant]'s mode and text size.
Future<void> _pumpPage(
  WidgetTester tester,
  Widget child, {
  required MmVariant variant,
  Locale? locale,
  double width = 360,
}) async {
  tester.view
    ..physicalSize = Size(width, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    themedApp(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(MmSpace.s4),
          child: child,
        ),
      ),
      variant: variant,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Twelve months of rent at 320 dp, collected rising towards what is due.
Widget _year({List<String> months = _months}) => MmBarChart(
  title: 'Rent, last 12 months',
  semanticSummary: _summary,
  series: const [
    MmBarSeries(label: 'Collected'),
    MmBarSeries(label: 'Due'),
  ],
  groups: [
    for (var month = 0; month < 12; month++)
      MmBarGroup(
        label: months[month % 6],
        values: [
          Money.fromRupees(25000 + month * 10000),
          const Money.fromRupees(125000),
        ],
      ),
  ],
);

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
      expect(const MmBarSeries(label: 'Due').fill, isNull);
      expect(due.toString(), 'MmBarSeries("Due", outlined)');
      expect(const MmBarSeries(label: 'Due').toString(), 'MmBarSeries("Due")');

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

    test('take their fills by place unless told', () {
      expect(
        MmBarChart.fillsOf(const [
          MmBarSeries(label: 'Collected'),
          MmBarSeries(label: 'Due'),
        ]),
        [MmBarFill.solid, MmBarFill.outlined],
      );
      expect(
        MmBarChart.fillsOf(const [
          MmBarSeries(label: 'Due', fill: MmBarFill.outlined),
          MmBarSeries(label: 'Collected', fill: MmBarFill.solid),
        ]),
        [MmBarFill.outlined, MmBarFill.solid],
      );
      expect(
        MmBarChart.fillsOf(const [
          MmBarSeries(label: 'Due', fill: MmBarFill.outlined),
        ]),
        [MmBarFill.outlined],
      );
    });
  });

  group('MmAxisScale', () {
    const english = MoneyFormat(grouping: DigitGrouping.southAsian);
    const urdu = MoneyFormat(language: MoneyLanguage.urdu);

    test('picks one unit from the largest amount and says it once', () {
      expect(MmAxisScale.of(english, 95000).unit, 1);
      expect(MmAxisScale.of(english, 95000).caption, 'Rs');
      expect(MmAxisScale.of(english, 125000).unit, MmAxisScale.lakh);
      expect(MmAxisScale.of(english, 125000).caption, 'Rs lakh');
      expect(MmAxisScale.of(english, 15000000).unit, MmAxisScale.crore);
      expect(MmAxisScale.of(english, 15000000).caption, 'Rs crore');
      expect(MmAxisScale.of(urdu, 95000).caption, 'روپے');
      expect(MmAxisScale.of(urdu, 125000).caption, 'لاکھ روپے');
      expect(MmAxisScale.of(urdu, 15000000).caption, 'کروڑ روپے');
      const bare = MoneyFormat(currency: CurrencyDisplay.none);
      expect(MmAxisScale.of(bare, 95000).caption, isEmpty);
      expect(MmAxisScale.of(bare, 125000).caption, 'lakh');
    });

    test('writes each tick as a plain figure in that unit', () {
      final rupees = MmAxisScale.of(english, 95000);
      expect(rupees.label(0), '0');
      expect(rupees.label(25000), '25,000');
      expect(rupees.label(100000), '1,00,000');
      final lakhs = MmAxisScale.of(english, 125000);
      expect(
        [
          for (final tick in [0, 25000, 50000, 100000, 125000])
            lakhs.label(tick),
        ],
        ['0', '0.25', '0.5', '1', '1.25'],
      );
      expect(lakhs.label(-50000), '${MoneyFormat.leftToRightMark}-0.5');
      expect(MmAxisScale.of(english, 25000000).label(15000000), '1.5');
      expect(MmAxisScale.of(english, 15000000000).label(15000000000), '1,500');
      // Urdu digits, when the app writes them.
      const native = MoneyFormat(
        language: MoneyLanguage.urdu,
        nativeDigits: true,
      );
      expect(MmAxisScale.of(native, 125000).label(50000), '۰.۵');
      expect(MmAxisScale.of(native, 125000).label(100000), '۱');
    });

    test('compares by format and unit', () {
      expect(MmAxisScale.of(english, 125000), MmAxisScale.of(english, 150000));
      expect(
        MmAxisScale.of(english, 125000).hashCode,
        MmAxisScale.of(english, 150000).hashCode,
      );
      expect(MmAxisScale.of(english, 125000), isNot(MmAxisScale.of(urdu, 1)));
      expect(
        MmAxisScale.of(english, 125000),
        isNot(MmAxisScale.of(english, 1)),
      );
    });
  });

  group('MmBarChart', () {
    testEveryVariant('draws the first series solid, inside the outlined one', (
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
      expect(painter.layout.outer, 1);
      expect(painter.gridColor, colors.rule);
      expect(painter.baselineColor, colors.ink);
      expect(painter.highlightColor, colors.primaryContainer);
      // The readout keys each series with the mark of its bars.
      expect([
        for (final swatch in tester.widgetList<MmChartSwatch>(
          find.byType(MmChartSwatch),
        ))
          swatch.mark,
      ], painter.marks);
      // The solid bars and the outlines stand out from the surface, and the
      // solid bars from the pale fill of the outlined ones they stand in.
      expect(
        mmContrastRatio(colors.primary, colors.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        mmContrastRatio(colors.primary, colors.primaryContainer),
        greaterThanOrEqualTo(3),
      );
      expect(styleOf(tester, 'Collected').color, colors.inkMuted);
      expect(styleOf(tester, 'Jun').color, colors.inkMuted);
    });

    testWidgets('stands the bars of either fill order inside the outline', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 328,
          child: MmBarChart(
            semanticSummary: _summary,
            series: const [
              MmBarSeries(label: 'Due', fill: MmBarFill.outlined),
              MmBarSeries(label: 'Collected', fill: MmBarFill.solid),
            ],
            groups: [
              for (final (index, month) in _months.indexed)
                MmBarGroup(label: month, values: [due, collected[index]]),
            ],
          ),
        ),
      );
      final layout = _layout(tester);
      expect(layout.outer, 0);
      expect(
        layout.bars.first[0].width,
        greaterThan(layout.bars.first[1].width),
      );
      // The wide bars are painted first, so the narrow ones stand on them.
      final colors = colorsOf(MmVariant.light);
      expect(
        _plot,
        paints
          ..rrect(color: colors.primaryContainer)
          ..rrect(color: colors.primary)
          ..rrect(color: colors.primary),
      );
    });

    testWidgets('asks for two series that differ', (tester) async {
      await pumpThemed(
        tester,
        const MmBarChart(
          semanticSummary: _summary,
          series: [
            MmBarSeries(label: 'Collected', fill: MmBarFill.solid),
            MmBarSeries(label: 'Due', fill: MmBarFill.solid),
          ],
          groups: [],
        ),
      );
      expect(
        tester.takeException(),
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          contains('different fills'),
        ),
      );
    });

    testEveryVariant('labels the y-axis in one unit, said once above it', (
      tester,
      variant,
    ) async {
      await pumpThemed(tester, lakhGrouping(_rent()), variant: variant);
      final colors = colorsOf(variant);
      final ticks = [for (final tick in _layout(tester).ticks) tick.label];
      expect(
        ticks,
        variant == MmVariant.largeText
            ? ['0', '0.5', '1', '1.5']
            : ['0', '0.25', '0.5', '0.75', '1', '1.25'],
      );
      final caption = variant.locale.languageCode == 'ur'
          ? 'لاکھ روپے'
          : 'Rs lakh';
      final captionBox = tester.getRect(find.text(caption));
      final plot = tester.getRect(_plot);
      expect(captionBox.bottom, lessThanOrEqualTo(plot.top));
      // It sits at the start edge, over the axis.
      if (variant.locale.languageCode == 'ur') {
        expect(captionBox.right, closeTo(plot.right, 1));
      } else {
        expect(captionBox.left, plot.left);
      }
      expect(styleOf(tester, caption).color, colors.inkMuted);
      final tick = styleOf(tester, '1.25' == ticks.last ? '1.25' : '1.5');
      expect(tick.color, colors.inkMuted);
      expect(tick.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(tick.fontFamily, contains(MmFontFamily.latin));
    });

    testWidgets('labels an axis under a lakh in rupees', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 328,
          child: MmBarChart(
            semanticSummary: _summary,
            series: const [MmBarSeries(label: 'Bills')],
            groups: [
              for (final (index, month) in _months.indexed)
                MmBarGroup(
                  label: month,
                  values: [Money.fromRupees(9000 + index * 7000)],
                ),
            ],
          ),
        ),
      );
      expect(
        [for (final tick in _layout(tester).ticks) tick.label],
        ['0', '10,000', '20,000', '30,000', '40,000', '50,000'],
      );
      expect(find.text('Rs'), findsOneWidget);
    });

    testWidgets('leaves out the caption when the format writes no currency', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        MmFormats(
          money: const MoneyFormat(currency: CurrencyDisplay.none),
          child: _net(),
        ),
      );
      expect(find.text('lakh'), findsOneWidget);
      await pumpThemed(
        tester,
        const MmFormats(
          money: MoneyFormat(currency: CurrencyDisplay.none),
          child: SizedBox(
            width: 328,
            child: MmBarChart(
              semanticSummary: _summary,
              series: [MmBarSeries(label: 'Bills')],
              groups: [
                MmBarGroup(label: 'Jun', values: [Money.fromRupees(9000)]),
              ],
            ),
          ),
        ),
      );
      final column = tester.widget<Column>(
        find
            .descendant(
              of: find.byType(MmChartFocusRing),
              matching: find.byType(Column),
            )
            .first,
      );
      // The readouts, the space under them and the plot: no caption.
      expect(column.children, hasLength(3));
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
      // The zero line is drawn last, over the bars' square ends, in ink and
      // twice as thick as the gridlines.
      expect(
        _plot,
        paints
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..line(color: colors.ink, strokeWidth: MmSize.stroke),
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
      final november = tester.getRect(find.text('Nov').last);
      expect(june.center.dx, lessThan(november.center.dx));
      // The y-axis labels sit at the start edge.
      expect(tester.getRect(find.text('0')).left, plot.left);
    });

    testWidgets('runs the groups from the right in Urdu', (tester) async {
      await pumpThemed(
        tester,
        _rent(months: _urduMonths),
        variant: MmVariant.urdu,
      );
      final layout = _layout(tester);
      expect(
        layout.bands.first.center.dx,
        greaterThan(layout.bands.last.center.dx),
      );
      final plot = tester.getRect(_plot);
      expect(
        tester.getRect(find.text('0')).right,
        lessThanOrEqualTo(plot.right),
      );
      expect(layout.ticks.first.rect.left, greaterThan(layout.plot.right));
      // A group's bars share its band's centre in Urdu too.
      final june = layout.bars.first;
      expect(june[0].center.dx, closeTo(june[1].center.dx, 1e-9));
      expect(june[0].center.dx, closeTo(layout.bands.first.center.dx, 1e-9));
    });

    testWidgets('keys the two series above the plot, by their marks', (
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

    testWidgets('names a titled single series by its title, with no key', (
      tester,
    ) async {
      await pumpThemed(tester, _net());
      expect(find.byType(MmChartSwatch), findsNothing);
      expect(find.text('Net income'), findsOneWidget);
      // The readout still shows the latest month's amount.
      expect(find.text('Rs 60,000'), findsOneWidget);
    });

    testWidgets('keeps the key of a single series with no title', (
      tester,
    ) async {
      await pumpThemed(tester, _net(title: null));
      expect(find.byType(MmChartSwatch), findsOneWidget);
      expect(find.text('Net income'), findsOneWidget);
      // The table toggle keeps to the end edge, its words on the edge.
      final chart = tester.getRect(find.byType(MmBarChart));
      expect(
        tester.getRect(find.byType(TextButton)).right,
        chart.right + MmSpace.s4,
      );
    });

    testWidgets('puts the table toggle beside the title, or under it', (
      tester,
    ) async {
      await pumpThemed(tester, _net());
      final title = tester.getRect(find.text('Net income'));
      final toggle = tester.getRect(find.byType(TextButton));
      expect(toggle.center.dy, closeTo(title.center.dy, 1));
      final chart = tester.getRect(find.byType(MmBarChart));
      // Its padding hangs past the edge, so its words end on the edge.
      expect(toggle.right, chart.right + MmSpace.s4);
      expect(tester.getRect(find.text('Show as a table')).right, chart.right);
      await pumpThemed(tester, _rent(width: 296));
      final longTitle = tester.getRect(find.text('Rent, last 6 months'));
      expect(
        tester.getRect(find.byType(TextButton)).top,
        greaterThanOrEqualTo(longTitle.bottom),
      );
      // Under the title, its icon starts on the title's edge.
      expect(
        tester.getRect(find.byType(Icon)).left,
        tester.getRect(find.byType(MmBarChart)).left,
      );
    });

    testWidgets('grows the toggle icon with the text, like a button', (
      tester,
    ) async {
      await pumpLargeNarrow(tester, _rent(width: 288));
      expect(
        tester.getSize(find.byType(Icon)).width,
        MmIconLabel.scaledSize(
          tester.element(find.byType(Icon)),
          MmSize.iconMd,
        ),
      );
      expect(tester.getSize(find.byType(Icon)).width, greaterThan(20));
    });

    testWidgets('fits a 360 dp phone with every group labelled', (
      tester,
    ) async {
      await pumpThemed(tester, _rent());
      expect(tester.takeException(), isNull);
      expect(_layout(tester).labels, hasLength(6));
      expect(_layout(tester).ticks, hasLength(6));
      for (final month in _months) {
        expect(find.text(month), findsWidgets);
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
      testWidgets('shows the latest group until one is picked', (tester) async {
        await pumpThemed(tester, lakhGrouping(_rent()));
        expect(_readout(tester), isNull);
        expect(_shownGroup(tester), 'Nov');
        expect(find.text('Rs 45,000'), findsOneWidget);
        // No band is highlighted.
        expect(_painter(tester).active, isNull);
      });

      testWidgets('tapping a group picks it and shows its exact amounts', (
        tester,
      ) async {
        await pumpThemed(tester, lakhGrouping(_rent()));
        await tester.tapAt(_groupCentre(tester, 0));
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jun');
        expect(_shownGroup(tester), 'Jun');
        expect(find.text('Rs 1,10,000'), findsOneWidget);
        expect(find.text('Rs 1,25,000'), findsOneWidget);
        // The readout keys each amount with its series.
        expect(find.byType(MmChartSwatch), findsNWidgets(2));
        expect(find.text('Collected'), findsOneWidget);
        // Its band is highlighted and its label set in ink.
        final colors = colorsOf(MmVariant.light);
        expect(
          _plot,
          paints..rrect(
            rrect: RRect.fromRectAndRadius(
              _layout(tester).bands[0],
              const Radius.circular(MmRadius.xs),
            ),
            color: colors.primaryContainer,
          ),
        );
        Color? colorOf(Finder text) =>
            tester.renderObject<RenderParagraph>(text).text.style!.color;
        // The readout's heading, then the axis label.
        expect(colorOf(find.text('Jun').first), colors.ink);
        expect(colorOf(find.text('Jun').last), colors.ink);
        expect(colorOf(find.text('Jul')), colors.inkMuted);
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
          find.text('Sep').first,
        );
        expect(heading.text.style!.color, colors.ink);
        expect(styleOf(tester, 'Due').color, colors.inkMuted);
      });

      testWidgets('tapping the picked group again clears the pick', (
        tester,
      ) async {
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
        expect(_shownGroup(tester), 'Nov');
      });

      testWidgets('tapping beside the plot clears the pick', (tester) async {
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
        expect(_shownGroup(tester), 'Jul');
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

      testEveryVariant(
        'never covers the plot or the axes, whatever is picked',
        (tester, variant) async {
          await pumpThemed(
            tester,
            lakhGrouping(
              _rent(
                months: variant.locale.languageCode == 'ur'
                    ? _urduMonths
                    : _months,
              ),
            ),
            variant: variant,
            size: const Size(360, 1000),
          );
          final plotTop = tester.getRect(_plot).top;
          final box = _readoutBox(tester);
          for (var group = 0; group < 6; group++) {
            await tester.tapAt(_groupCentre(tester, group));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final readout = tester.getRect(_shownReadout);
            expect(readout.bottom, lessThanOrEqualTo(plotTop));
            for (final label in _axisLabelRects(tester)) {
              expect(readout.overlaps(label), isFalse);
            }
            // It keeps its place and height, so nothing under it moves.
            expect(_readoutBox(tester), box);
            expect(tester.getRect(_plot).top, plotTop);
          }
        },
      );

      for (final locale in const [Locale('en'), Locale('ur')]) {
        testWidgets('at 200% on a 320 dp phone, shows every group whole '
            '(${locale.languageCode})', (tester) async {
          final urdu = locale.languageCode == 'ur';
          await _pumpPage(
            tester,
            lakhGrouping(
              rentChart(
                (english, inUrdu) => urdu ? inUrdu : english,
                autofocus: true,
              ),
            ),
            variant: MmVariant.largeText,
            locale: locale,
            width: 320,
          );
          expect(tester.takeException(), isNull);
          final plotTop = tester.getRect(_plot).top;
          for (var group = 0; group < 6; group++) {
            await tester.tapAt(_groupCentre(tester, group));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'group $group');
            final readout = tester.getRect(_shownReadout);
            expect(readout.bottom, lessThanOrEqualTo(plotTop));
            expect(readout.right, lessThanOrEqualTo(320));
            expect(readout.left, greaterThanOrEqualTo(0));
            await tester.tapAt(_groupCentre(tester, group));
            await tester.pumpAndSettle();
          }
        });
      }

      testWidgets('puts every name beside its amount, or every one under it', (
        tester,
      ) async {
        double nameTop(String name) => tester
            .getRect(
              find.descendant(of: _shownReadout, matching: find.text(name)),
            )
            .top;
        double amountTop(String amount) => tester
            .getRect(
              find.descendant(of: _shownReadout, matching: find.text(amount)),
            )
            .top;
        await pumpThemed(tester, lakhGrouping(_rent()));
        expect(nameTop('Collected'), lessThan(amountTop('Rs 45,000') + 8));
        expect(nameTop('Due'), lessThan(amountTop('Rs 1,25,000') + 8));
        await pumpLargeNarrow(tester, lakhGrouping(_rent(width: 288)));
        expect(tester.takeException(), isNull);
        // "Due" would fit beside its amount, but "Collected" would not.
        expect(nameTop('Collected'), greaterThan(amountTop('Rs 45,000')));
        expect(nameTop('Due'), greaterThan(amountTop('Rs 1,25,000')));
        // So do September's, though "Rs 95,000 Collected" would fit: every
        // group's readout is laid out the same way, and as tall.
        final height = _readoutBox(tester).height;
        await tester.tapAt(_groupCentre(tester, 3));
        await tester.pumpAndSettle();
        expect(nameTop('Collected'), greaterThan(amountTop('Rs 95,000')));
        expect(_readoutBox(tester).height, height);
        // A name is never broken mid-word.
        final name = tester.renderObject<RenderParagraph>(
          find.text('Collected'),
        );
        expect(
          name.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 9),
          ),
          hasLength(1),
        );
      });
    });

    group('keyboard', () {
      testWidgets('takes focus after the toggle, with a ring outside it', (
        tester,
      ) async {
        useKeyboardHighlights();
        await pumpThemed(tester, _rent());
        await _key(tester, LogicalKeyboardKey.tab);
        expect(focusedAt(tester, 'Show as a table'), isTrue);
        await _key(tester, LogicalKeyboardKey.tab);
        // Focus picks the group the readout already shows.
        expect(_readout(tester), 'Nov');
        final ring = find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.foregroundPainter is MmChartFocusRingPainter,
        );
        expect(ring, findsOneWidget);
        final box = tester.getSize(ring);
        final painter =
            tester.widget<CustomPaint>(ring).foregroundPainter!
                as MmChartFocusRingPainter;
        // Outside the readout, the axes and the plot, past a gap.
        expect(
          (Canvas canvas) => painter.paint(canvas, box),
          paints..rrect(
            rrect: MmChartFocusRingPainter.ringFor(box),
            color: colorsOf(MmVariant.light).focus,
            strokeWidth: MmSize.focusRing,
            style: PaintingStyle.stroke,
          ),
        );
        // The ring's outer edge is the gap and the ring past the box.
        expect(
          MmChartFocusRingPainter.ringFor(box).outerRect
              .inflate(MmSize.focusRing / 2),
          (Offset.zero & box).inflate(MmChartFocusRing.reach),
        );
        expect(tester.getRect(ring).top, lessThan(_readoutBox(tester).top + 1));
        expect(
          const MmChartFocusRingPainter(color: Color(0xFF000000)).shouldRepaint(
            const MmChartFocusRingPainter(color: Color(0xFF000000)),
          ),
          isFalse,
        );
        expect(
          const MmChartFocusRingPainter(color: Color(0xFF000000)).shouldRepaint(
            const MmChartFocusRingPainter(color: Color(0xFFFFFFFF)),
          ),
          isTrue,
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
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.home);
        expect(_readout(tester), 'Jun');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Jul');
        expect(_shownGroup(tester), 'Jul');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Aug');
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Jul');
        await _key(tester, LogicalKeyboardKey.end);
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.home);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Jun');
      });

      testWidgets('Escape clears the pick, then lets the key through', (
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
        await _key(tester, LogicalKeyboardKey.home);
        await _key(tester, LogicalKeyboardKey.escape);
        expect(_readout(tester), isNull);
        expect(_shownGroup(tester), 'Nov');
        expect(escapes, 0);
        await _key(tester, LogicalKeyboardKey.escape);
        expect(escapes, 1);
        // An arrow key picks the group on show, the latest, first.
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Nov');
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Oct');
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
        await _key(tester, LogicalKeyboardKey.home);
        expect(_readout(tester), 'Jun');
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_readout(tester), 'Jul');
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_readout(tester), 'Jun');
      });

      testWidgets('clears the pick when focus leaves', (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpThemed(tester, _rent(focusNode: focus));
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Nov');
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

      testWidgets('keeps the pick on hover exit while focused', (tester) async {
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

      testWidgets('picks the latest group when autofocused', (tester) async {
        await pumpThemed(tester, _rent(autofocus: true));
        expect(_readout(tester), 'Nov');
      });
    });

    group('semantics', () {
      testWidgets('reads the summary, then the picked group in plain figures', (
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
          'Nov\nCollected 45000 rupees\nDue 125000 rupees',
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
        expect(find.bySemanticsLabel('0'), findsNothing);
        expect(find.bySemanticsLabel('Jun'), findsNothing);
        expect(find.bySemanticsLabel('Rs lakh'), findsNothing);
        handle.dispose();
      });

      testWidgets('steps through the groups with swipes up and down', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpThemed(tester, lakhGrouping(_rent()));
        final chart = find.semantics.byLabel(_summary);
        expect(
          tester
              .getSemantics(_plot)
              .getSemanticsData()
              .hasAction(SemanticsAction.increase),
          isTrue,
        );
        // With no pick, either swipe picks the group on show.
        tester.semantics.decrease(chart);
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Nov');
        tester.semantics.decrease(chart);
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Oct');
        final node = tester.getSemantics(_plot);
        expect(
          node.increasedValue,
          'Nov\nCollected 45000 rupees\nDue 125000 rupees',
        );
        expect(
          node.decreasedValue,
          'Sep\nCollected 95000 rupees\nDue 125000 rupees',
        );
        tester.semantics.increase(chart);
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Nov');
        // At the latest group there is nothing later to step to.
        expect(tester.getSemantics(_plot).increasedValue, isEmpty);
        expect(
          tester
              .getSemantics(_plot)
              .getSemanticsData()
              .hasAction(SemanticsAction.increase),
          isFalse,
        );
        await _key(tester, LogicalKeyboardKey.escape);
        await tester.tapAt(_groupCentre(tester, 0));
        await tester.pumpAndSettle();
        expect(tester.getSemantics(_plot).decreasedValue, isEmpty);
        tester.semantics.increase(chart);
        await tester.pumpAndSettle();
        expect(_readout(tester), 'Jul');
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
          'Nov\nCollected 45000 روپے\nDue 125000 روپے',
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
        // The currency is said once, in the headers, so the figures line up.
        expect(table.columns, const [
          MmDataColumn(label: 'Month'),
          MmDataColumn(label: 'Collected (Rs)', numeric: true),
          MmDataColumn(label: 'Due (Rs)', numeric: true),
        ]);
        expect(table.rows.first, ['Jun', '1,10,000', '1,25,000']);
        expect(table.rows.last, ['Nov', '45,000', '1,25,000']);
        expect(table.rows, hasLength(6));
        // The key goes with the chart; the toggle now offers it back.
        expect(find.byType(MmChartSwatch), findsNothing);
        expect(find.text('Show as a chart'), findsOneWidget);
        await tester.tap(find.text('Show as a chart'));
        await tester.pumpAndSettle();
        expect(find.byType(MmDataTable), findsNothing);
        expect(_plot, findsOneWidget);
        expect(find.text('Show as a table'), findsOneWidget);
      });

      testWidgets('reads the summary for the table too', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpThemed(tester, _rent());
        await tester.tap(find.text('Show as a table'));
        await tester.pumpAndSettle();
        expect(tester.getSemantics(find.byType(MmDataTable)).label, _summary);
        handle.dispose();
      });

      testWidgets('writes the Urdu currency word in the headers', (
        tester,
      ) async {
        await pumpThemed(tester, _rent(), variant: MmVariant.urdu);
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        final table = tester.widget<MmDataTable>(find.byType(MmDataTable));
        expect(table.columns[1].label, 'Collected (روپے)');
        expect(table.rows.first, ['Jun', '110,000', '125,000']);
      });

      testWidgets('keeps the headers bare when the format has no currency', (
        tester,
      ) async {
        await pumpThemed(
          tester,
          MmFormats(
            money: const MoneyFormat(currency: CurrencyDisplay.none),
            child: _rent(),
          ),
        );
        await tester.tap(find.text('Show as a table'));
        await tester.pumpAndSettle();
        final table = tester.widget<MmDataTable>(find.byType(MmDataTable));
        expect(table.columns[1].label, 'Collected');
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

      testWidgets('clears the pick when it swaps', (tester) async {
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

    testWidgets('keeps the pick on a group that still exists', (tester) async {
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

    testWidgets('shows only the key and a zero line without groups', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpThemed(tester, _rent(count: 0, focusNode: focus));
      expect(tester.takeException(), isNull);
      expect(_layout(tester).ticks.single.label, '0');
      expect(_shownGroup(tester), isNull);
      expect(find.byType(MmChartSwatch), findsNWidgets(2));
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(_painter(tester).active, isNull);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_painter(tester).active, isNull);
      // A titled single series has nothing to key.
      await pumpThemed(
        tester,
        const SizedBox(
          width: 328,
          child: MmBarChart(
            title: 'Net income',
            semanticSummary: _summary,
            series: [MmBarSeries(label: 'Net income')],
            groups: [],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MmChartSwatch), findsNothing);
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

    for (final variant in const [MmVariant.light, MmVariant.largeText]) {
      for (final locale in const [Locale('en'), Locale('ur')]) {
        testWidgets('keeps a year of months apart on a 320 dp phone '
            '(${variant.name}, ${locale.languageCode})', (tester) async {
          await _pumpPage(
            tester,
            chartCard(
              tester.binding.rootElement!,
              _year(
                months: locale.languageCode == 'ur' ? _urduMonths : _months,
              ),
            ),
            variant: variant,
            locale: locale,
            width: 320,
          );
          expect(tester.takeException(), isNull);
          final layout = _layout(tester);
          for (final [inner, outer] in layout.bars) {
            // An outline, a gap of pale fill and a solid bar inside it.
            expect(outer.width, greaterThanOrEqualTo(MmBarLayout.minBarWidth));
            expect(inner.width, greaterThanOrEqualTo(MmSpace.s1));
            expect(
              inner.left - outer.left,
              closeTo(MmBarLayout.innerInset, 1e-9),
            );
          }
          final rects = _axisLabelRects(tester);
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(rects[i].overlaps(rects[j]), isFalse);
            }
          }
        });
      }
    }

    testWidgets('at 200% on a 320 dp phone, keeps the axis labels apart', (
      tester,
    ) async {
      await expectFitsNarrowLargeText(tester, lakhGrouping(_rent()));
      await pumpLargeNarrow(
        tester,
        lakhGrouping(_rent(width: 288)),
        height: 1000,
      );
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
        ..physicalSize = const Size(320, 1100)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        themedApp(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(MmSpace.s4),
              child: lakhGrouping(_rent(width: 288, months: _urduMonths)),
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

    testWidgets('meets the accessibility guidelines with a group picked', (
      tester,
    ) async {
      useKeyboardHighlights();
      await pumpThemed(tester, _rent(autofocus: true));
      await _key(tester, LogicalKeyboardKey.home);
      await expectAccessible(tester);
    });
  });
}
