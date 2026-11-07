import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Measures [text] as it will be drawn, wrapping at [maxWidth].
///
/// Internal to the charts family.
typedef MmTextMeasure = Size Function(String text, {double maxWidth});

/// The values of a y-axis between [low] and [high] rupees (which bracket
/// zero): whole multiples of the smallest "nice" step (1, 2, 2.5 or 5 times
/// a power of ten, in whole rupees) that needs at most [maxCount] ticks.
/// The ticks always include zero. Fewer than three ticks cannot bracket
/// values on both sides of zero, so [maxCount] is raised to three then.
///
/// Internal to the charts family.
List<int> mmNiceTicks(double low, double high, int maxCount) {
  if (low == 0 && high == 0) return const [0];
  final limit = math.max(maxCount, low < 0 && high > 0 ? 3 : 2);
  for (var magnitude = 1; ; magnitude *= 10) {
    for (final step in [
      magnitude,
      2 * magnitude,
      if (magnitude >= 10) magnitude * 5 ~/ 2,
      5 * magnitude,
    ]) {
      final first = (low / step).floor();
      final last = (high / step).ceil();
      if (last - first + 1 <= limit) {
        return [for (var i = first; i <= last; i++) i * step];
      }
    }
  }
}

/// A y-axis tick of an [MmBarLayout]: its `value` in rupees, the `y` of
/// its gridline, its `label` and the `rect` the label sits in.
///
/// Internal to the charts family.
typedef MmBarTick = ({int value, double y, String label, Rect rect});

/// An x-axis label of an [MmBarLayout]: the group at `index`, its `text`
/// and the `rect` it sits in.
///
/// Internal to the charts family.
typedef MmBarLabel = ({int index, String text, Rect rect});

/// The geometry of a bar chart at one width: where the plot, the ticks, the
/// groups, their bars and their labels go, mirrored for right-to-left text.
///
/// Axis labels never overlap: when the tick labels are too tall for every
/// tick (large text) the axis takes fewer, wider steps, and when the group
/// labels are too wide for every group only every second, third, … group
/// is labelled, starting with the first.
///
/// A group's bars share its band's centre. With two series, the [outer]
/// series' bar (the outlined one) is the wide bar and the other series'
/// bar stands inside it, [innerInset] in from each side, so the two differ
/// by position and width as well as by fill, at any width: side by side,
/// a year of months on a phone would leave each bar too narrow to show an
/// outline.
///
/// Internal to the charts family.
final class MmBarLayout {
  const new _({
    required this.size,
    required this.plot,
    required this.baseline,
    required this.ticks,
    required this.bands,
    required this.bars,
    required this.labels,
    required this.outer,
    required this.textDirection,
  });

  /// Lays out [values] (one list of rupee amounts per group, one amount per
  /// series) in [width], with a plot [plotHeight] tall. With two series,
  /// [outer] is the one drawn as the wide bar. [tickLabel] names a tick,
  /// [measureTick] and [measureLabel] measure tick and group labels as they
  /// will be drawn.
  factory compute({
    required double width,
    required double plotHeight,
    required int seriesCount,
    required List<List<double>> values,
    required List<String> groupLabels,
    required String Function(int rupees) tickLabel,
    required MmTextMeasure measureTick,
    required MmTextMeasure measureLabel,
    required TextDirection textDirection,
    int? outer,
  }) {
    assert(
      seriesCount == 1 || (outer != null && outer >= 0 && outer < seriesCount),
      'A layout of two series needs the series drawn as the wide bar.',
    );
    final rtl = textDirection == TextDirection.rtl;
    final all = [for (final group in values) ...group];
    final low = all.fold<double>(0, math.min);
    final high = all.fold<double>(0, math.max);

    // The y-axis: as many nice steps as the labels' height allows.
    var ticks = const <int>[];
    var tickSizes = const <Size>[];
    for (var limit = maxTicks; limit >= 2; limit--) {
      ticks = mmNiceTicks(low, high, limit);
      tickSizes = [for (final tick in ticks) measureTick(tickLabel(tick))];
      final tallest = tickSizes.map((size) => size.height).reduce(math.max);
      if (ticks.length < 2 ||
          plotHeight / (ticks.length - 1) >= tallest + MmSpace.s1) {
        break;
      }
    }
    final tickWidth = tickSizes.map((size) => size.width).reduce(math.max);
    final tickHeight = tickSizes.map((size) => size.height).reduce(math.max);
    final gutter = math.min(width, tickWidth + MmSpace.s2);
    final plotWidth = width - gutter;
    final plot = Rect.fromLTWH(
      rtl ? 0 : gutter,
      tickHeight / 2,
      plotWidth,
      plotHeight,
    );
    final top = ticks.last.toDouble();
    final span = top - ticks.first;
    // With nothing but zero to show, the zero line is the plot's floor.
    double yOf(double rupees) => span == 0
        ? plot.bottom
        : plot.top + (top - rupees) / span * plot.height;

    final tickRects = [
      for (final (index, tick) in ticks.indexed)
        (
          value: tick,
          y: yOf(tick.toDouble()),
          label: tickLabel(tick),
          rect: Rect.fromLTWH(
            rtl ? plot.right + MmSpace.s2 : 0,
            yOf(tick.toDouble()) - tickSizes[index].height / 2,
            tickWidth,
            tickSizes[index].height,
          ),
        ),
    ];

    // The groups: equal bands from the start edge, bars centred in each.
    final count = values.length;
    final band = count == 0 ? plotWidth : plotWidth / count;
    final bands = [
      for (var i = 0; i < count; i++)
        Rect.fromLTWH(
          rtl ? plot.right - (i + 1) * band : plot.left + i * band,
          plot.top,
          band,
          plot.height,
        ),
    ];
    // Bars fill most of the band, within their least and greatest widths,
    // and always leave a sliver of air between neighbouring groups.
    final least = math.max<double>(
      1,
      math.min(minBarWidth, band - MmSpace.sHalf),
    );
    final barWidth = (band * bandFill).clamp(least, maxBarWidth);
    final innerWidth = math.max<double>(1, barWidth - 2 * innerInset);
    final zero = yOf(0);
    final bars = [
      for (final (index, group) in values.indexed)
        [
          for (final (series, rupees) in group.indexed)
            _bar(
              bands[index],
              width: seriesCount == 1 || series == outer
                  ? barWidth
                  : innerWidth,
              from: zero,
              to: yOf(rupees),
            ),
        ],
    ];

    // The group labels: every k-th group, for the smallest k whose labels
    // keep clear of each other.
    final labelTop = plot.bottom + MmSpace.s2;
    final labelSizes = [
      for (final label in groupLabels) measureLabel(label, maxWidth: plotWidth),
    ];
    var labels = const <MmBarLabel>[];
    for (var every = 1; every <= count; every++) {
      labels = [
        for (var i = 0; i < count; i += every)
          (
            index: i,
            text: groupLabels[i],
            rect: _labelRect(bands[i], labelSizes[i], plot, labelTop),
          ),
      ];
      if (_clear(labels)) break;
    }
    final labelHeight = labels.fold<double>(
      0,
      (tallest, label) => math.max(tallest, label.rect.height),
    );
    final height = math.max(
      plot.bottom + tickHeight / 2,
      labels.isEmpty ? 0.0 : labelTop + labelHeight,
    );
    return MmBarLayout._(
      size: Size(width, height),
      plot: plot,
      baseline: zero,
      ticks: tickRects,
      bands: bands,
      bars: bars,
      labels: labels,
      outer: seriesCount == 1 ? null : outer,
      textDirection: textDirection,
    );
  }

  /// The most ticks the y-axis takes.
  static const int maxTicks = 6;

  /// The share of a group's band its bars may fill; the rest is air between
  /// groups.
  static const double bandFill = 0.7;

  /// The widest a bar gets, however much room there is.
  static const double maxBarWidth = MmSpace.s6;

  /// The narrowest a bar gets while its band has room for it and some air:
  /// wide enough for an outline on each side, a gap inside each and a
  /// 4 dp bar of the other series between them.
  static const double minBarWidth = MmSpace.s3;

  /// How far the inner bar of a two-series group stands in from each side
  /// of the outer one: the outer bar's outline and a gap of its pale fill,
  /// so the two never touch.
  static const double innerInset = MmSize.stroke + MmChartMetrics.gap;

  /// The size of the whole chart: plot, axis labels and gutter.
  final Size size;

  /// The plotting area, between the axis labels.
  final Rect plot;

  /// The y of the zero line.
  final double baseline;

  /// The y-axis ticks, lowest first.
  final List<MmBarTick> ticks;

  /// Each group's band across the plot, in group order (from the right in
  /// right-to-left text).
  final List<Rect> bands;

  /// Each group's bars, one per series in series order. A bar of zero is
  /// a rectangle of no height on the zero line.
  final List<List<Rect>> bars;

  /// The group labels shown, in group order.
  final List<MmBarLabel> labels;

  /// In a two-series chart, the series whose bars are the wide ones, which
  /// are painted first so the other series' bars stand on them; null with
  /// one series.
  final int? outer;

  /// The direction the groups run in.
  final TextDirection textDirection;

  /// The index of the group whose band is under [position], or null when
  /// it is outside the plot's width.
  int? groupAt(Offset position) {
    for (final (index, band) in bands.indexed) {
      if (position.dx >= band.left && position.dx < band.right) return index;
    }
    return null;
  }

  /// A bar [width] wide centred in [band], from the zero line at [from] to
  /// its value at [to].
  static Rect _bar(
    Rect band, {
    required double width,
    required double from,
    required double to,
  }) {
    final left = band.center.dx - width / 2;
    return Rect.fromLTRB(
      left,
      math.min(from, to),
      left + width,
      math.max(from, to),
    );
  }

  static Rect _labelRect(Rect band, Size size, Rect plot, double top) {
    final last = math.max(plot.left, plot.right - size.width);
    final left = (band.center.dx - size.width / 2).clamp(plot.left, last);
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  /// Whether neighbouring [labels] keep at least a small gap between them.
  static bool _clear(List<MmBarLabel> labels) {
    for (var i = 1; i < labels.length; i++) {
      final a = labels[i - 1].rect;
      final b = labels[i].rect;
      if (a.left < b.right + MmSpace.s2 && b.left < a.right + MmSpace.s2) {
        return false;
      }
    }
    return true;
  }
}
