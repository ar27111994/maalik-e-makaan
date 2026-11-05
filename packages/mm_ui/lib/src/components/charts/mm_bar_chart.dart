import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/charts/mm_bar_layout.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';
import 'package:mm_ui/src/components/charts/mm_data_table.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// How the bars of an [MmBarSeries] are drawn. The two fills differ by
/// more than colour, so a chart's two series stay apart for colour-blind
/// readers and in greyscale.
enum MmBarFill {
  /// Solid cobalt: the main series ("Collected").
  solid,

  /// A pale cobalt fill inside a 2 dp cobalt outline: the series the main
  /// one is measured against ("Due").
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
  const new({required this.label, this.fill = MmBarFill.solid});

  /// What the series measures ("Collected", "Due"), from the app's
  /// localisations: the legend's word, the readout's label and the table's
  /// column header.
  final String label;

  /// How its bars are drawn.
  final MmBarFill fill;

  @override
  bool operator ==(Object other) =>
      other is MmBarSeries && other.label == label && other.fill == fill;

  @override
  int get hashCode => Object.hash(label, fill);

  @override
  String toString() => 'MmBarSeries("$label", ${fill.name})';
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

/// Rupee amounts compared across a few groups (months, units): one or two
/// series of bars from a zero line, against a y-axis of round rupee steps
/// in the compact money format ("Rs 50,000", "Rs 1.5 lakh"), with a legend
/// of the series and a [title].
///
/// Groups run from the start edge, so time reads in the language's
/// direction: in Urdu the first group is on the right. Negative amounts go
/// below the zero line. The first series is solid cobalt and the second is
/// outlined ([MmBarFill]), so the series differ by more than colour. On a
/// narrow screen or with large text the axes keep their labels apart by
/// labelling fewer steps and fewer groups.
///
/// Tapping a group, hovering over it or moving keyboard focus onto the
/// chart shows a readout of the group's exact amounts in the full money
/// format, beside the group so it never hides the group's own bars; the
/// arrow keys move between groups (in the reading direction), Home and End
/// jump to the first and last, Escape hides the readout and tapping the
/// shown group again hides it too.
///
/// Screen readers hear [semanticSummary] for the chart, which should say
/// what it shows and its main finding in words, and then the shown group's
/// amounts as plain numbers. A text button beside the title, or under it
/// when they do not fit (`MmLocalizations.showAsTable`), swaps the chart
/// for an [MmDataTable] of the same amounts, and back.
///
/// Use it to compare amounts across up to about a year of months or a
/// handful of units. Don't use it for one whole split into parts (use
/// `MmProportionBar`), for the shape of a trend beside a figure (use
/// `MmSparkline`) or for a single figure (use a stat tile).
///
/// ```dart
/// MmBarChart(
///   title: l10n.rentLastSixMonths,
///   semanticSummary: l10n.rentSummary(collectedTotal, dueTotal),
///   groupLabel: l10n.month,
///   series: [
///     MmBarSeries(label: l10n.collected),
///     MmBarSeries(label: l10n.due, fill: MmBarFill.outlined),
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
  /// localisations. A chart of one series with a title needs no legend: the
  /// title names what the bars show.
  final String? title;

  /// The header of the table view's first column, which lists the groups
  /// ("Month"), from the app's localisations. When null that header is
  /// left blank.
  final String? groupLabel;

  /// The chart's focus node, to move keyboard focus to it. When null the
  /// chart makes its own.
  final FocusNode? focusNode;

  /// Whether the chart takes keyboard focus when first shown, showing the
  /// first group's readout.
  final bool autofocus;

  /// The height of the plotting area, between the axis labels.
  static const double plotHeight = 176;

  /// The width laid out when the chart is given unbounded width (in a
  /// horizontal scroll view).
  static const double unboundedWidth = 320;

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

  /// Moves the readout one group to the right (or left), which is the next
  /// group in left-to-right text and the previous one in right-to-left.
  void _move(int rightward) {
    final step = Directionality.of(context) == TextDirection.rtl
        ? -rightward
        : rightward;
    final from = _active ?? (step > 0 ? -1 : widget.groups.length);
    _show((from + step).clamp(0, widget.groups.length - 1));
  }

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
      } else if (_active == null && widget.groups.isNotEmpty) {
        _active = 0;
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
    final title = widget.title;
    final showsLegend = widget.series.length > 1 || title == null;
    final chart = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, title),
        if (showsLegend)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: MmSpace.s1),
            child: _legend(context),
          ),
        const SizedBox(height: MmSpace.s3),
        if (_showsTable) _table(context) else _chart(context),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedWidth
          ? chart
          : SizedBox(width: MmBarChart.unboundedWidth, child: chart),
    );
  }

  Widget _header(BuildContext context, String? title) {
    final l10n = MmLocalizations.of(context);
    final toggle = TextButton.icon(
      onPressed: _toggleTable,
      icon: Icon(_showsTable ? MmIcons.reports : MmIcons.spreadsheet),
      label: Text(_showsTable ? l10n.showAsChart : l10n.showAsTable),
    );
    if (title == null) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: toggle);
    }
    return MmReflow(
      start: Semantics(
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
      end: toggle,
    );
  }

  Widget _legend(BuildContext context) {
    final mm = context.mm;
    final style = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: mm.colors.ink);
    return Wrap(
      spacing: MmSpace.s4,
      runSpacing: MmSpace.s1,
      children: [
        for (final series in widget.series)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: MmSpace.s2,
            children: [
              MmChartSwatch(_markOf(series.fill, mm.colors)),
              Flexible(
                child: Text(
                  series.label,
                  style: mm.styleFor(series.label, style),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final format = MmFormats.moneyOf(context);
    return MmDataTable(
      columns: [
        MmDataColumn(label: widget.groupLabel ?? ''),
        for (final series in widget.series)
          MmDataColumn(label: series.label, numeric: true),
      ],
      rows: [
        for (final group in widget.groups)
          [group.label, for (final value in group.values) format.format(value)],
      ],
    );
  }

  Widget _chart(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final format = MmFormats.moneyOf(context);
    final compact = format.copyWith(notation: MoneyNotation.compact);
    final tickStyle = mm.figures(
      mm.script == MmScript.urdu
          ? MmTypeScale.latinBodySmall
          : MmTypeScale.latinCaption,
      colors.inkMuted,
    );
    final labelBase = Theme.of(context).textTheme.bodySmall!
        .copyWith(color: colors.inkMuted);
    TextStyle labelStyle(String label) => mm.styleFor(label, labelBase);
    String tickLabel(int rupees) => compact.format(Money.fromRupees(rupees));
    Size measure(
      String text,
      TextStyle style, {
      double maxWidth = double.infinity,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: mmDirectionOf(text),
        textScaler: scaler,
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = MmBarLayout.compute(
          width: constraints.maxWidth,
          plotHeight: MmBarChart.plotHeight,
          seriesCount: widget.series.length,
          values: [
            for (final group in widget.groups)
              [
                for (final value in group.values)
                  value.paisa / Money.paisaPerRupee,
              ],
          ],
          groupLabels: [for (final group in widget.groups) group.label],
          tickLabel: tickLabel,
          measureTick: (text, {maxWidth = double.infinity}) =>
              measure(text, tickStyle, maxWidth: maxWidth),
          measureLabel: (text, {maxWidth = double.infinity}) =>
              measure(text, labelStyle(text), maxWidth: maxWidth),
          textDirection: direction,
        );
        final active = _active;
        return Semantics(
          container: true,
          label: widget.semanticSummary,
          value: active == null ? null : _spokenReadout(context, active),
          child: FocusableActionDetector(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            shortcuts: _shortcuts,
            actions: _actions,
            onFocusChange: _handleFocus,
            onShowFocusHighlight: _handleFocusHighlight,
            child: MouseRegion(
              onHover: (event) =>
                  _handleHover(layout.groupAt(event.localPosition)),
              onExit: (_) => _handleExit(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapUp: (details) =>
                    _handleTap(layout.groupAt(details.localPosition)),
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: _focusShown
                        ? BoxDecoration(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(MmRadius.xs),
                            ),
                            border: Border.all(
                              color: colors.focus,
                              width: MmSize.focusRing,
                            ),
                          )
                        : const BoxDecoration(),
                    child: SizedBox.fromSize(
                      size: layout.size,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: MmBarChartPainter(
                                layout: layout,
                                marks: [
                                  for (final series in widget.series)
                                    _markOf(series.fill, colors),
                                ],
                                active: active,
                                gridColor: colors.rule,
                                baselineColor: colors.outline,
                                highlightColor: colors.primaryContainer
                                    .withValues(alpha: 0.5),
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
                                style: labelStyle(label.text),
                                textAlign: TextAlign.center,
                                textDirection: mmDirectionOf(label.text),
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          if (active != null)
                            Positioned.fill(
                              child: MmReadoutPlacement(
                                band: layout.bands[active],
                                plot: layout.plot,
                                child: _Readout(
                                  group: widget.groups[active],
                                  series: widget.series,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

/// Moves the readout to the neighbouring group on the right ([rightward]
/// is 1) or the left (-1).
class _MoveIntent extends Intent {
  const new(this.rightward);

  final int rightward;
}

/// Moves the readout to the first or the [last] group.
class _EdgeIntent extends Intent {
  const new({required this.last});

  final bool last;
}

/// An action that is enabled while [enabled] says so, so a key the chart
/// cannot use (Escape with no readout shown) goes on to the page.
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

/// The readout of one group: its label, then each series' amount (in the
/// full money format, leading) and name, keyed by the series' swatch.
class _Readout extends StatelessWidget {
  const new({required this.group, required this.series});

  final MmBarGroup group;
  final List<MmBarSeries> series;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final format = MmFormats.moneyOf(context);
    final amount = mm
        .figures(MmTypeScale.latinBodySmall, colors.ink)
        .copyWith(fontWeight: FontWeight.w600);
    final name = text.bodySmall!.copyWith(color: colors.inkMuted);
    final lineHeight = MediaQuery.textScalerOf(context)
        .scale(amount.fontSize! * amount.height!);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.xs)),
        border: Border.all(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s3,
          vertical: MmSpace.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: MmSpace.s1,
          children: [
            Text(
              group.label,
              style: mm.styleFor(
                group.label,
                text.labelLarge!.copyWith(color: colors.ink),
              ),
              textDirection: mmDirectionOf(group.label),
            ),
            for (final (index, value) in group.values.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: MmSpace.s2,
                children: [
                  SizedBox(
                    height: lineHeight,
                    child: Center(
                      child: MmChartSwatch(_markOf(series[index].fill, colors)),
                    ),
                  ),
                  Flexible(
                    child: Wrap(
                      spacing: MmSpace.s2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // An amount stays whole: it never wraps, and the
                        // readout is never laid out narrower than it.
                        IntrinsicWidth(
                          child: Text(
                            format.format(value),
                            style: amount,
                            softWrap: false,
                          ),
                        ),
                        Text(
                          series[index].label,
                          style: mm.styleFor(series[index].label, name),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Where a readout goes across the chart: its `left` edge and the `width`
/// it is laid out in.
///
/// Internal to the charts family.
typedef MmReadoutSpot = ({double left, double width});

/// Places a readout beside the [band] of its group, level with the top of
/// the [plot], so it covers neither the group's own bars nor, when it can
/// help it, the axis labels.
///
/// It tries, in order: after the band in the reading direction, then
/// before it, first over the plot and then over the whole chart, first at
/// its natural width and then with its series names wrapped under their
/// amounts (never narrower than its longest word or amount). When none of
/// those fit, it is centred over the band.
///
/// Exposed for the charts family's tests; not exported from the library.
class MmReadoutPlacement extends SingleChildRenderObjectWidget {
  /// Places [child] beside [band] over [plot].
  const new({
    required this.band,
    required this.plot,
    required super.child,
    super.key,
  });

  /// The band of the group the readout describes.
  final Rect band;

  /// The plotting area of the chart.
  final Rect plot;

  /// The space between a readout and the band it describes.
  static const double gap = MmSpace.s2;

  /// Where a readout goes in a chart [chartWidth] wide, given its
  /// [natural] width (every row on one line) and its [least] width (names
  /// wrapped under their amounts), for [textDirection].
  static MmReadoutSpot place({
    required Rect band,
    required Rect plot,
    required double chartWidth,
    required double natural,
    required double least,
    required TextDirection textDirection,
  }) {
    final rtl = textDirection == TextDirection.rtl;
    // The room after and before the band, over the plot and over the chart.
    final areas = [(plot.left, plot.right), (0.0, chartWidth)];
    for (final (low, high) in areas) {
      final right = high - (band.right + gap);
      final left = band.left - gap - low;
      final sides = rtl ? [left, right] : [right, left];
      for (final width in [natural, least]) {
        for (final (index, room) in sides.indexed) {
          if (room < width) continue;
          final towardRight = (index == 0) != rtl;
          return (
            left: towardRight ? band.right + gap : band.left - gap - width,
            width: width,
          );
        }
      }
    }
    final width = math.min(natural, chartWidth);
    final left = math.min(
      math.max(band.center.dx - width / 2, 0),
      chartWidth - width,
    );
    return (left: left.toDouble(), width: width);
  }

  @override
  RenderMmReadoutPlacement createRenderObject(BuildContext context) =>
      RenderMmReadoutPlacement(
        band: band,
        plot: plot,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMmReadoutPlacement renderObject,
  ) {
    renderObject
      ..band = band
      ..plot = plot
      ..textDirection = Directionality.of(context);
  }
}

/// The render object of [MmReadoutPlacement]: as big as its constraints
/// allow, with its child placed by [MmReadoutPlacement.place].
///
/// Exposed for the charts family's tests; not exported from the library.
class RenderMmReadoutPlacement extends RenderShiftedBox {
  /// Places its child beside [band] over [plot], for [textDirection].
  new({required this._band, required this._plot, required this._textDirection})
    : super(null);

  /// The band of the group the readout describes.
  Rect get band => _band;
  Rect _band;
  set band(Rect value) {
    if (value == _band) return;
    _band = value;
    markNeedsLayout();
  }

  /// The plotting area of the chart.
  Rect get plot => _plot;
  Rect _plot;
  set plot(Rect value) {
    if (value == _plot) return;
    _plot = value;
    markNeedsLayout();
  }

  /// The reading direction.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child!;
    final spot = MmReadoutPlacement.place(
      band: band,
      plot: plot,
      chartWidth: size.width,
      natural: child.getMaxIntrinsicWidth(double.infinity),
      least: child.getMinIntrinsicWidth(double.infinity),
      textDirection: textDirection,
    );
    child.layout(
      BoxConstraints(maxWidth: spot.width, maxHeight: size.height),
      parentUsesSize: true,
    );
    (child.parentData! as BoxParentData).offset = Offset(
      spot.left,
      math.min(plot.top, math.max(0, size.height - child.size.height)),
    );
  }
}

/// Paints an [MmBarChart]'s plot: gridlines, the active group's band, the
/// bars and the zero line. The axis labels and the readout are widgets on
/// top.
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

  /// The colour of the zero line.
  final Color baselineColor;

  /// The colour of the active group's band.
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
    for (final group in layout.bars) {
      for (final (series, bar) in group.indexed) {
        marks[series].paint(canvas, _shape(bar));
      }
    }
    final zero = _crisp(layout.baseline);
    canvas.drawLine(
      Offset(plot.left, zero),
      Offset(plot.right, zero),
      hairline..color = baselineColor,
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
