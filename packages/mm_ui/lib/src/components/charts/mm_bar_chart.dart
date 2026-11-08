import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/charts/mm_bar_layout.dart';
import 'package:mm_ui/src/components/charts/mm_chart_focus_ring.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';
import 'package:mm_ui/src/components/charts/mm_data_table.dart';
import 'package:mm_ui/src/foundation/mm_button_styles.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How the two series of an [MmBarChart] stand in each group.
enum MmBarArrangement {
  /// The outlined series' bar is the wide one and the solid series' bar
  /// stands inside it: one measure against the one it is measured by
  /// ("Collected" inside "Due"). It reads at any width, even a year of
  /// months on a phone.
  nested,

  /// The two bars stand side by side, as wide as each other, the first
  /// series at the start edge (on the right in Urdu): two independent
  /// measures, neither a part of the other ("Money in" beside "Money
  /// out"). They still differ by fill as well as colour, and by place.
  sideBySide,
}

/// How the bars of an [MmBarSeries] are drawn. The two fills differ by
/// more than colour, so a chart's two series stay apart for colour-blind
/// readers and in greyscale.
enum MmBarFill {
  /// Solid cobalt: the main series ("Collected"). Nested with an outlined
  /// series, its bars stand inside the outlined ones.
  solid,

  /// A pale cobalt fill inside a 2 dp cobalt outline: the series the main
  /// one is measured against ("Due"). Nested with a solid series, its bars
  /// are the wide ones, with the solid bars standing inside them.
  outlined,
}

/// The mark of [fill] in [colors].
MmChartMark _markOf(MmBarFill fill, MmColorTokens colors) => switch (fill) {
  MmBarFill.solid => MmChartMark(fill: colors.primary),
  MmBarFill.outlined => MmChartMark(
    fill: colors.primaryContainer,
    stroke: colors.primary,
  ),
};

/// One measure plotted in an [MmBarChart]: its name in the legend and how
/// its bars are drawn.
@immutable
final class MmBarSeries {
  /// A series called [label], drawn with [fill].
  const new({required this.label, this.fill});

  /// What the series measures ("Collected", "Due"), from the app's
  /// localisations: the legend's word, the readout's label and the table's
  /// column header.
  final String label;

  /// How its bars are drawn. When null it follows the series' place: the
  /// first series is solid and the second outlined. A chart's two series
  /// always differ.
  final MmBarFill? fill;

  @override
  bool operator ==(Object other) =>
      other is MmBarSeries && other.label == label && other.fill == fill;

  @override
  int get hashCode => Object.hash(label, fill);

  @override
  String toString() =>
      'MmBarSeries("$label"${fill == null ? '' : ', ${fill!.name}'})';
}

/// What the groups of an [MmBarChart] are, which decides how their labels
/// give way when they do not all fit under the bars.
enum MmBarGroupKind {
  /// Periods in order (months, years): when the labels do not fit, only
  /// every second, third, … group is labelled, as the reader counts the
  /// rest along the axis.
  periods,

  /// Things with names (units, properties, tenants): every group is
  /// labelled, each label wrapping between its words within its group's
  /// width, since a bar without its name cannot be told from the others.
  /// When even a single word does not fit (large text on a narrow phone),
  /// the chart shows its table instead, with every name in full, and offers
  /// no chart view there.
  names,
}

/// One group of bars in an [MmBarChart]: a period or a thing ([label]) and
/// its amount in each series ([values]).
@immutable
final class MmBarGroup {
  /// A group called [label] with one of [values] per series, in the order
  /// of the chart's series.
  const new({required this.label, required this.values});

  /// What the group is ("Oct", "Flat 2B"), from the app's data or
  /// localisations: the axis label, the readout's heading and the table's
  /// first cell.
  final String label;

  /// The group's amount in each series, in series order. Negative amounts
  /// (a month's net loss) are drawn below the zero line.
  final List<Money> values;

  @override
  bool operator ==(Object other) =>
      other is MmBarGroup &&
      other.label == label &&
      listEquals(other.values, values);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(values));

  @override
  String toString() => 'MmBarGroup("$label", $values)';
}

/// The y-axis of an [MmBarChart] in one unit: plain figures in rupees, in
/// lakhs or in crores, chosen from the largest amount, with the currency
/// and the unit said once in a [caption] above the axis ("Rs lakh"), so
/// every step reads in the same unit and the axis keeps a narrow gutter.
///
/// Exposed for the charts family's tests; not exported from the library.
@immutable
final class MmAxisScale {
  const new _(this.format, this.unit);

  /// The scale for amounts up to [largest] rupees either side of zero, in
  /// [format]'s grouping, currency and language.
  factory of(MoneyFormat format, double largest) => MmAxisScale._(
    format,
    largest >= crore
        ? crore
        : largest >= lakh
        ? lakh
        : 1,
  );

  /// A lakh, in rupees.
  static const int lakh = 100000;

  /// A crore, in rupees.
  static const int crore = 10000000;

  /// The app's money format.
  final MoneyFormat format;

  /// The rupees one step of the figures stands for: 1, [lakh] or [crore].
  final int unit;

  /// The currency and unit of the figures ("Rs", "Rs lakh", "لاکھ روپے"),
  /// or nothing when the format writes no currency and the unit is a rupee.
  String get caption => mmUnitWords(format, Money.fromRupees(unit));

  /// The figure of a tick at [rupees], in [unit]: "25,000" in rupees,
  /// "1.25" or "0.5" in lakhs (at most two decimals, trailing zeros left
  /// out).
  String label(int rupees) {
    final plain = format.copyWith(
      notation: MoneyNotation.standard,
      currency: CurrencyDisplay.none,
      paisa: PaisaDisplay.auto,
    );
    if (unit == 1) return plain.format(Money.fromRupees(rupees));
    // Hundredths of the unit, written as paisa so the format gives two
    // decimals in its own digits.
    final hundredths = (rupees * 100 / unit).round();
    final text = plain.format(Money.fromPaisa(hundredths));
    return text.contains('.') ? text.replaceFirst(_trailingZeros, '') : text;
  }

  static final RegExp _trailingZeros = RegExp(r'\.?[0۰]+$');

  @override
  bool operator ==(Object other) =>
      other is MmAxisScale && other.format == format && other.unit == unit;

  @override
  int get hashCode => Object.hash(format, unit);
}

/// Rupee amounts compared across a few groups (months, units): one or two
/// series of bars from a zero line, against a y-axis of round steps in one
/// unit ("Rs lakh": 0, 0.5, 1, 1.5), with a [title] and a readout above
/// the plot that keys each series by its mark.
///
/// Groups run from the start edge, so time reads in the language's
/// direction: in Urdu the first group is on the right. Negative amounts go
/// below the zero line. The first series is solid cobalt and the second is
/// outlined ([MmBarFill]); by default ([MmBarArrangement.nested]) the
/// outlined bars are the wide ones and the solid bars stand inside them, so
/// the series differ by position and width as well as fill, even with a
/// year of months on a phone. Two independent measures (money in and money
/// out) stand side by side instead ([MmBarArrangement.sideBySide]), the
/// first series at the start edge of each group. On a
/// narrow screen or with large text the axes keep their labels apart by
/// labelling fewer steps and, for periods, fewer groups; named groups
/// ([groupKind] [MmBarGroupKind.names]: units, properties) keep every label,
/// wrapped between words, or show the table when a word cannot fit.
///
/// The readout above the plot names each series beside its mark and shows
/// one group's exact amounts in the full money format: the latest group's,
/// until the reader picks another by tapping it, hovering over it or with
/// the keyboard, which also highlights the picked group's band. It keeps
/// its place and height whichever group it shows, so the chart never moves
/// under the reader's finger, and it never covers the bars or the axes.
/// Once the chart has keyboard focus the arrow keys move between groups (in
/// the reading direction), Home and End jump to the first and last, Escape
/// clears the pick, and tapping the picked group again clears it too.
///
/// Screen readers hear [semanticSummary] for the chart, which should say
/// what it shows and its main finding in words, and then the picked
/// group's amounts as plain numbers; swiping up or down steps through the
/// groups. A text button beside the title, or under it when they do not
/// fit (`MmLocalizations.showAsTable`), swaps the chart for an
/// [MmDataTable] of the same amounts, with the currency in its headers,
/// and back.
///
/// Use it to compare amounts across up to about a year of months or a
/// handful of units. Don't use it for one whole split into parts (use
/// `MmProportionBar`), for the shape of a trend beside a figure (use
/// `MmSparkline`), for a single figure (use a stat tile), or with nothing
/// to plot yet (show an empty state that says so instead).
///
/// ```dart
/// MmBarChart(
///   title: l10n.rentLastSixMonths,
///   semanticSummary: l10n.rentSummary(collectedTotal, dueTotal),
///   groupLabel: l10n.month,
///   series: [
///     MmBarSeries(label: l10n.collected),
///     MmBarSeries(label: l10n.due),
///   ],
///   groups: [
///     for (final month in months)
///       MmBarGroup(
///         label: month.shortName,
///         values: [month.collected, month.due],
///       ),
///   ],
/// )
/// ```
class MmBarChart extends StatefulWidget {
  /// A chart of [groups] of [series], read out as [semanticSummary].
  const new({
    required this.series,
    required this.groups,
    required this.semanticSummary,
    this.title,
    this.groupLabel,
    this.groupKind = MmBarGroupKind.periods,
    this.arrangement = MmBarArrangement.nested,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The measures plotted: one or two, in legend order.
  final List<MmBarSeries> series;

  /// The groups of bars, in order from the start edge (oldest first).
  final List<MmBarGroup> groups;

  /// The chart in words, as a screen reader should say it ("Rent collected
  /// each month from June to November; November is lowest at Rs 45,000"),
  /// from the app's localisations.
  final String semanticSummary;

  /// The chart's heading ("Rent, last 6 months"), from the app's
  /// localisations. A chart of one series with a title names no series in
  /// its readout: the title names what the bars show.
  final String? title;

  /// The header of the table view's first column, which lists the groups
  /// ("Month"), from the app's localisations. When null that header is
  /// left blank.
  final String? groupLabel;

  /// Whether the groups are periods (months), whose labels may be thinned
  /// out, or named things (units), each of which keeps its label.
  final MmBarGroupKind groupKind;

  /// How two series stand in each group: one inside the other (one measure
  /// against another) or side by side (two independent measures). A chart
  /// of one series has one bar per group either way.
  final MmBarArrangement arrangement;

  /// The chart's focus node, to move keyboard focus to it. When null the
  /// chart makes its own.
  final FocusNode? focusNode;

  /// Whether the chart takes keyboard focus when first shown, picking the
  /// latest group.
  final bool autofocus;

  /// The height of the plotting area, between the axis labels: a chart
  /// geometry with no token, tall enough for six ticks of large text.
  static const double plotHeight = 176;

  /// The width laid out when the chart is given unbounded width (in a
  /// horizontal scroll view): the narrowest phone's width, a chart geometry
  /// with no token.
  static const double unboundedWidth = 320;

  /// The fill of each of [series] in a chart: its own, or by its place.
  static List<MmBarFill> fillsOf(List<MmBarSeries> series) => [
    for (final (index, one) in series.indexed)
      one.fill ?? (index == 0 ? MmBarFill.solid : MmBarFill.outlined),
  ];

  @override
  State<MmBarChart> createState() => _MmBarChartState();
}

class _MmBarChartState extends State<MmBarChart> {
  bool _showsTable = false;
  int? _active;
  bool _focused = false;
  bool _focusShown = false;

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(1),
    SingleActivator(LogicalKeyboardKey.home): _EdgeIntent(last: false),
    SingleActivator(LogicalKeyboardKey.end): _EdgeIntent(last: true),
    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
  };

  late final Map<Type, Action<Intent>> _actions = {
    _MoveIntent: _ChartAction<_MoveIntent>(
      enabled: () => widget.groups.isNotEmpty,
      onInvoke: (intent) => _move(intent.rightward),
    ),
    _EdgeIntent: _ChartAction<_EdgeIntent>(
      enabled: () => widget.groups.isNotEmpty,
      onInvoke: (intent) => _show(intent.last ? widget.groups.length - 1 : 0),
    ),
    DismissIntent: _ChartAction<DismissIntent>(
      enabled: () => _active != null,
      onInvoke: (_) => _show(null),
    ),
  };

  /// The group the readout shows: the picked one, or else the latest.
  int? get _shown =>
      _active ?? (widget.groups.isEmpty ? null : widget.groups.length - 1);

  @override
  void didUpdateWidget(MmBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final active = _active;
    if (active != null && active >= widget.groups.length) {
      _active = widget.groups.isEmpty ? null : widget.groups.length - 1;
    }
  }

  void _show(int? group) {
    if (group != _active) setState(() => _active = group);
  }

  /// Picks the group [by] groups later in time than the picked one; with
  /// none picked, picks the latest, which the readout already shows.
  void _step(int by) {
    final active = _active;
    _show(
      active == null
          ? widget.groups.length - 1
          : (active + by).clamp(0, widget.groups.length - 1),
    );
  }

  /// Moves the pick one group to the right (or left), which is the next
  /// group in left-to-right text and the previous one in right-to-left.
  void _move(int rightward) => _step(
    Directionality.of(context) == TextDirection.rtl ? -rightward : rightward,
  );

  void _handleTap(int? group) =>
      setState(() => _active = group == _active ? null : group);

  void _handleHover(int? group) => _show(group);

  void _handleExit() {
    if (!_focused) _show(null);
  }

  void _handleFocus(bool focused) {
    setState(() {
      _focused = focused;
      if (!focused) {
        _active = null;
      } else {
        _active ??= _shown;
      }
    });
  }

  void _handleFocusHighlight(bool shown) {
    if (shown != _focusShown) setState(() => _focusShown = shown);
  }

  void _toggleTable() => setState(() {
    _showsTable = !_showsTable;
    _active = null;
  });

  @override
  Widget build(BuildContext context) {
    assert(
      widget.series.length == 1 || widget.series.length == 2,
      'An MmBarChart shows one or two series.',
    );
    assert(
      widget.groups.every(
        (group) => group.values.length == widget.series.length,
      ),
      'Every MmBarGroup needs one value per series.',
    );
    assert(
      MmBarChart.fillsOf(widget.series).toSet().length == widget.series.length,
      "An MmBarChart's two series need different fills.",
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Named groups that cannot all be labelled are shown as a table.
        final tableOnly =
            widget.groupKind == MmBarGroupKind.names &&
            !_layoutFor(
              context,
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MmBarChart.unboundedWidth,
            ).labelsEveryGroup;
        final chart = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, toggles: !tableOnly),
            const SizedBox(height: MmSpace.s3),
            if (_showsTable || tableOnly) _table(context) else _chart(context),
          ],
        );
        return constraints.hasBoundedWidth
            ? chart
            : SizedBox(width: MmBarChart.unboundedWidth, child: chart);
      },
    );
  }

  /// The title with the table toggle beside it, or under it when they do
  /// not fit; without the toggle when the chart [toggles] no view. The
  /// toggle's padding hangs past the edge it sits on, so its icon and words
  /// line up with the chart's edge and the title.
  Widget _header(BuildContext context, {required bool toggles}) {
    final l10n = MmLocalizations.of(context);
    final title = widget.title;
    final toggle = TextButton.icon(
      onPressed: _toggleTable,
      style: MmButtonStyles.labelled.copyWith(
        iconSize: WidgetStatePropertyAll(
          MmIconLabel.scaledSize(context, MmSize.iconMd),
        ),
      ),
      icon: Icon(_showsTable ? MmIcons.reports : MmIcons.spreadsheet),
      label: Text(_showsTable ? l10n.showAsChart : l10n.showAsTable),
    );
    return MmReflow(
      endOverhang: _togglePadding,
      start: title == null
          ? const SizedBox.shrink()
          : Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: context.mm.styleFor(
                  title,
                  Theme.of(context).textTheme.titleMedium!,
                ),
              ),
            ),
      end: toggles ? toggle : null,
    );
  }

  /// The horizontal padding of the table toggle (`MmButtonStyles.labelled`).
  static const double _togglePadding = MmSpace.s4;

  Widget _table(BuildContext context) {
    final format = MmFormats.moneyOf(context);
    final unit = mmUnitWords(format, const Money.fromRupees(1));
    final plain = format.copyWith(notation: MoneyNotation.standard);
    return Semantics(
      container: true,
      label: widget.semanticSummary,
      child: MmDataTable(
        columns: [
          MmDataColumn(label: widget.groupLabel ?? ''),
          for (final series in widget.series)
            MmDataColumn(
              label: unit.isEmpty ? series.label : '${series.label} ($unit)',
              numeric: true,
            ),
        ],
        rows: [
          for (final group in widget.groups)
            [
              group.label,
              for (final value in group.values) plain.formatNumber(value),
            ],
        ],
      ),
    );
  }

  /// Each group's amounts in rupees, one per series.
  List<List<double>> get _rupees => [
    for (final group in widget.groups)
      [for (final value in group.values) value.paisa / Money.paisaPerRupee],
  ];

  /// The y-axis's unit for [rupees].
  static MmAxisScale _scaleOf(
    BuildContext context,
    List<List<double>> rupees,
  ) => MmAxisScale.of(
    MmFormats.moneyOf(context),
    rupees.expand((group) => group).fold(0, (top, v) => math.max(top, v.abs())),
  );

  /// The style of the y-axis's tick labels.
  static TextStyle _tickStyle(BuildContext context) {
    final mm = context.mm;
    return mm.figures(
      mm.script == MmScript.urdu
          ? MmTypeScale.latinBodySmall
          : MmTypeScale.latinCaption,
      mm.colors.inkMuted,
    );
  }

  /// The style of a group label or of the axis caption, [text].
  static TextStyle _labelStyle(BuildContext context, String text) =>
      context.mm.styleFor(
        text,
        Theme.of(context).textTheme.bodySmall!
            .copyWith(color: context.mm.colors.inkMuted),
      );

  /// Lays [text] out in [style] as it will be drawn, wrapping at
  /// [maxWidth].
  static TextPainter _painterOf(
    BuildContext context,
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: mmDirectionOf(text),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);

  /// The size of [text] in [style], wrapping at [maxWidth].
  static Size _measure(
    BuildContext context,
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) {
    final painter = _painterOf(context, text, style, maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  /// The chart's geometry at [width].
  MmBarLayout _layoutFor(BuildContext context, double width) {
    final fills = MmBarChart.fillsOf(widget.series);
    final rupees = _rupees;
    final tickStyle = _tickStyle(context);
    final sideBySide = widget.arrangement == MmBarArrangement.sideBySide;
    return MmBarLayout.compute(
      width: width,
      plotHeight: MmBarChart.plotHeight,
      seriesCount: widget.series.length,
      sideBySide: sideBySide,
      outer: fills.length == 2 && !sideBySide
          ? fills.indexOf(MmBarFill.outlined)
          : null,
      values: rupees,
      groupLabels: [for (final group in widget.groups) group.label],
      tickLabel: _scaleOf(context, rupees).label,
      measureTick: (text, {maxWidth = double.infinity}) =>
          _measure(context, text, tickStyle, maxWidth: maxWidth),
      measureLabel: (text, {maxWidth = double.infinity}) => _measure(
        context,
        text,
        _labelStyle(context, text),
        maxWidth: maxWidth,
      ),
      wrapLabels: widget.groupKind == MmBarGroupKind.names,
      measureWidestWord: (text) {
        final painter = _painterOf(context, text, _labelStyle(context, text));
        final widest = painter.minIntrinsicWidth;
        painter.dispose();
        return widest;
      },
      textDirection: Directionality.of(context),
    );
  }

  Widget _chart(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final fills = MmBarChart.fillsOf(widget.series);
    final marks = [for (final fill in fills) _markOf(fill, colors)];
    final caption = _scaleOf(context, _rupees).caption;
    final tickStyle = _tickStyle(context);
    TextStyle labelStyle(String label) => _labelStyle(context, label);

    final shown = _shown;
    final active = _active;
    final showsNames = widget.series.length > 1 || widget.title == null;
    final readouts = IndexedStack(
      index: shown ?? 0,
      children: [
        if (shown == null)
          MmBarReadout(
            series: widget.series,
            marks: marks,
            groups: widget.groups,
            showsNames: showsNames,
          )
        else
          for (final group in widget.groups)
            MmBarReadout(
              series: widget.series,
              marks: marks,
              groups: widget.groups,
              group: group,
              showsNames: showsNames,
            ),
      ],
    );
    final plot = LayoutBuilder(
      builder: (context, constraints) {
        final layout = _layoutFor(context, constraints.maxWidth);
        return MouseRegion(
          onHover: (event) => _handleHover(layout.groupAt(event.localPosition)),
          onExit: (_) => _handleExit(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) =>
                _handleTap(layout.groupAt(details.localPosition)),
            child: SizedBox.fromSize(
              size: layout.size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: MmBarChartPainter(
                        layout: layout,
                        marks: marks,
                        active: active,
                        gridColor: colors.rule,
                        baselineColor: colors.ink,
                        highlightColor: colors.primaryContainer,
                      ),
                    ),
                  ),
                  for (final tick in layout.ticks)
                    Positioned.fromRect(
                      rect: tick.rect,
                      child: Text(
                        tick.label,
                        style: tickStyle,
                        textAlign: TextAlign.end,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  for (final label in layout.labels)
                    Positioned.fromRect(
                      rect: label.rect,
                      child: Text(
                        label.text,
                        // The picked group's label is in ink, the rest in
                        // muted ink.
                        style: labelStyle(label.text).copyWith(
                          color: label.index == active ? colors.ink : null,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: mmDirectionOf(label.text),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    // Swipes step through the groups while there is one further that way;
    // with none picked, they pick the group on show.
    final groups = widget.groups.length;
    final later = active == null ? groups > 0 : active + 1 < groups;
    final earlier = active == null ? groups > 0 : active > 0;
    return Semantics(
      container: true,
      label: widget.semanticSummary,
      value: active == null ? null : _spokenReadout(context, active),
      increasedValue: active == null || !later
          ? null
          : _spokenReadout(context, active + 1),
      decreasedValue: active == null || !earlier
          ? null
          : _spokenReadout(context, active - 1),
      onIncrease: later ? () => _step(1) : null,
      onDecrease: earlier ? () => _step(-1) : null,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        shortcuts: _shortcuts,
        actions: _actions,
        onFocusChange: _handleFocus,
        onShowFocusHighlight: _handleFocusHighlight,
        child: MmChartFocusRing(
          shown: _focusShown,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                readouts,
                const SizedBox(height: MmSpace.s3),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: MmSpace.s1,
                    ),
                    child: Text(
                      caption,
                      style: labelStyle(caption),
                      textDirection: mmDirectionOf(caption),
                      textAlign: TextAlign.start,
                    ),
                  ),
                plot,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The readout of group [index] as a screen reader should say it: the
  /// group, then each series and its amount as a plain number.
  String _spokenReadout(BuildContext context, int index) {
    final format = MmFormats.moneyOf(context);
    final group = widget.groups[index];
    return [
      group.label,
      for (final (series, value) in group.values.indexed)
        [
          widget.series[series].label,
          MmFormats.spokenMoney(context, value, format: format),
        ].join(' '),
    ].join('\n');
  }
}

/// Moves the pick to the neighbouring group on the right ([rightward] is
/// 1) or the left (-1).
class _MoveIntent extends Intent {
  const new(this.rightward);

  final int rightward;
}

/// Moves the pick to the first or the [last] group.
class _EdgeIntent extends Intent {
  const new({required this.last});

  final bool last;
}

/// An action that is enabled while [enabled] says so, so a key the chart
/// cannot use (Escape with no group picked) goes on to the page.
class _ChartAction<T extends Intent> extends Action<T> {
  new({required this.enabled, required this.onInvoke});

  final bool Function() enabled;
  final void Function(T intent) onInvoke;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    onInvoke(intent);
    return null;
  }
}

/// The readout of an [MmBarChart]: the [group]'s label, then a line per
/// series: its amount in the full money format (leading, in ink) and its
/// name (in muted ink), keyed by the series' mark. Without a [group] it is the
/// legend alone: each mark and name.
///
/// Every series' name sits beside its amount when, in every one of the
/// chart's [groups], every amount and name fit on a line, and under it
/// otherwise, so the series line up the same way whichever group is shown.
/// With [showsNames] off (one series, named by the chart's title) it shows
/// only the amount.
///
/// Exposed for the charts family's tests; not exported from the library.
class MmBarReadout extends StatelessWidget {
  /// The readout of [group], one of [groups], in [series], drawn with
  /// [marks].
  const new({
    required this.series,
    required this.marks,
    required this.groups,
    this.group,
    this.showsNames = true,
    super.key,
  });

  /// The chart's series.
  final List<MmBarSeries> series;

  /// Each series' mark, in series order.
  final List<MmChartMark> marks;

  /// Every group of the chart, which the readout's layout fits.
  final List<MmBarGroup> groups;

  /// The group shown, or null for the legend alone.
  final MmBarGroup? group;

  /// Whether each amount is keyed by its series' mark and name.
  final bool showsNames;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final format = MmFormats.moneyOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final group = this.group;
    if (group == null && !showsNames) return const SizedBox.shrink();
    final amountStyle = mm
        .figures(MmTypeScale.latinBodySmall, colors.ink)
        .copyWith(fontWeight: FontWeight.w600);
    final nameBase = text.bodySmall!.copyWith(color: colors.inkMuted);
    TextStyle nameStyle(String name) => mm.styleFor(name, nameBase);
    final lineHeight = scaler.scale(
      amountStyle.fontSize! * amountStyle.height!,
    );
    final swatch = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: MmChartSwatch.maxScale)
        .scale(MmChartMetrics.swatch);
    double widthOf(String words, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: words, style: style),
        textDirection: mmDirectionOf(words),
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The names go under the amounts when any group's amount and name
        // do not fit on one line. Figures are tabular, so a series' widest
        // amount is its longest.
        final stacked =
            group != null &&
            showsNames &&
            [
              for (final (index, one) in series.indexed)
                swatch +
                    MmSpace.s2 +
                    widthOf(
                      groups
                          .map((other) => format.format(other.values[index]))
                          .reduce((a, b) => b.length > a.length ? b : a),
                      amountStyle,
                    ) +
                    MmSpace.s2 +
                    widthOf(one.label, nameStyle(one.label)),
            ].any((width) => width > constraints.maxWidth);
        Widget item(int index) {
          final name = Text(
            series[index].label,
            style: nameStyle(series[index].label),
          );
          final amount = group == null
              ? null
              : Text(
                  format.format(group.values[index]),
                  style: amountStyle,
                  softWrap: false,
                );
          if (!showsNames) return amount!;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: MmSpace.s2,
            children: [
              SizedBox(
                height: lineHeight,
                child: Center(child: MmChartSwatch(marks[index])),
              ),
              Flexible(
                child: amount == null
                    ? name
                    : stacked
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [amount, name],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        spacing: MmSpace.s2,
                        children: [
                          amount,
                          Flexible(child: name),
                        ],
                      ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MmSpace.s1,
          children: [
            if (group != null)
              Text(
                group.label,
                style: mm.styleFor(
                  group.label,
                  text.labelLarge!.copyWith(color: colors.ink),
                ),
                textDirection: mmDirectionOf(group.label),
              ),
            for (var i = 0; i < series.length; i++) item(i),
          ],
        );
      },
    );
  }
}

/// Paints an [MmBarChart]'s plot: gridlines, the picked group's band, the
/// bars and the zero line. The axis labels are widgets on top.
///
/// Exposed for the charts family's tests; not exported from the library.
class MmBarChartPainter extends CustomPainter {
  /// Paints [layout] with one of [marks] per series.
  const new({
    required this.layout,
    required this.marks,
    required this.active,
    required this.gridColor,
    required this.baselineColor,
    required this.highlightColor,
  });

  /// The chart's geometry.
  final MmBarLayout layout;

  /// Each series' mark, in series order.
  final List<MmChartMark> marks;

  /// The group whose band is highlighted, or null.
  final int? active;

  /// The colour of the gridlines.
  final Color gridColor;

  /// The colour of the zero line, which is [MmSize.stroke] wide so it
  /// stands apart from the hairline gridlines by width as well as colour.
  final Color baselineColor;

  /// The colour of the picked group's band.
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = layout.plot;
    final active = this.active;
    if (active != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          layout.bands[active],
          const Radius.circular(MmRadius.xs),
        ),
        Paint()..color = highlightColor,
      );
    }
    final hairline = Paint()..strokeWidth = MmSize.hairline;
    for (final tick in layout.ticks) {
      if (tick.value == 0) continue;
      final y = _crisp(tick.y);
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        hairline..color = gridColor,
      );
    }
    // The wide bars first, so the other series' bars stand on them.
    final outer = layout.outer;
    final order = [
      ?outer,
      for (var series = 0; series < marks.length; series++)
        if (series != outer) series,
    ];
    for (final group in layout.bars) {
      for (final series in order) {
        marks[series].paint(canvas, _shape(group[series]));
      }
    }
    // On whole pixels, so the 2 dp line stays sharp.
    final zero = layout.baseline.roundToDouble();
    canvas.drawLine(
      Offset(plot.left, zero),
      Offset(plot.right, zero),
      Paint()
        ..strokeWidth = MmSize.stroke
        ..color = baselineColor,
    );
  }

  /// [bar] with its data end rounded (the top of a bar above the zero
  /// line, the bottom of one below it) and its end at the zero line square.
  RRect _shape(Rect bar) {
    final radius = Radius.circular(
      [MmRadius.xs, bar.width / 2, bar.height].reduce(math.min),
    );
    return bar.top < layout.baseline
        ? RRect.fromRectAndCorners(bar, topLeft: radius, topRight: radius)
        : RRect.fromRectAndCorners(
            bar,
            bottomLeft: radius,
            bottomRight: radius,
          );
  }

  /// [y] on the middle of a device pixel row, so a hairline stays sharp.
  static double _crisp(double y) => y.floorToDouble() + MmSize.hairline / 2;

  @override
  bool shouldRepaint(MmBarChartPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      !listEquals(oldDelegate.marks, marks) ||
      oldDelegate.active != active ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.baselineColor != baselineColor ||
      oldDelegate.highlightColor != highlightColor;
}
