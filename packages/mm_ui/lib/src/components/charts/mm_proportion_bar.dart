import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/src/components/charts/mm_chart_mark.dart';
import 'package:mm_ui/src/components/charts/mm_chart_style.dart';
import 'package:mm_ui/src/components/charts/mm_chart_swatch.dart';
import 'package:mm_ui/src/foundation/mm_formats.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The look of an [MmProportionSegment]: a colour role and a treatment
/// that does not rely on colour, so neighbouring parts stay apart for
/// colour-blind readers, in greyscale and in high contrast. The segment's
/// label says what it means; the tone never carries it alone.
///
/// The treatments are: hollow ([neutral]); solid ([paid], [overdueSevere],
/// [primary]); hatched with falling lines ([dueSoon], [credit]); hatched
/// with rising lines ([overdue]). The status colours are about equally
/// light, so tones that share a treatment differ by hue alone: one bar never
/// mixes them (debug builds check it). The bars the app draws keep to
/// that: rent by status (paid, due soon, overdue, not yet due), overdue
/// rent by age (due soon, overdue, severe) and money held for tenants
/// (primary, credit).
enum MmSegmentTone {
  /// An outline in the control-border colour around an empty segment: what
  /// is not yet anything ("Not yet due", "Vacant").
  neutral,

  /// Solid paid colour: what is settled ("Paid").
  paid,

  /// The due-soon colour hatched with falling lines: what is due inside
  /// the reminder window, or the youngest overdue bucket ("1 to 30 days").
  dueSoon,

  /// The overdue colour hatched with rising lines: what is past its grace
  /// period ("Overdue", "31 to 60 days").
  overdue,

  /// Solid overdue colour: the oldest overdue bucket of an aging breakdown
  /// ("Over 60 days"). It is the same red as [overdue] in every mode, with
  /// no paper showing through, so it reads as the heaviest part, and
  /// differs from [overdue] by having no hatch.
  overdueSevere,

  /// The credit colour hatched with falling lines: a tenant's advance
  /// ("Advance held").
  credit,

  /// Solid cobalt: a part with no status ("Let", "Collected by bank").
  primary;

  /// What the tone looks like without its colour: tones of one treatment
  /// differ by hue alone.
  _Treatment get _treatment => switch (this) {
    neutral => _Treatment.hollow,
    paid || overdueSevere || primary => _Treatment.solid,
    dueSoon || credit => _Treatment.falling,
    overdue => _Treatment.rising,
  };
}

/// How a [MmSegmentTone] is drawn, apart from its colour.
enum _Treatment { hollow, solid, falling, rising }

/// The mark of [tone] in [colors].
MmChartMark _markOf(MmSegmentTone tone, MmColorTokens colors) => switch (tone) {
  MmSegmentTone.neutral => MmChartMark(
    fill: colors.surface,
    stroke: colors.outline,
  ),
  MmSegmentTone.paid => MmChartMark(fill: colors.paid),
  MmSegmentTone.dueSoon => MmChartMark(
    fill: colors.dueSoon,
    hatch: MmHatch.falling,
    hatchColor: colors.surface,
  ),
  MmSegmentTone.overdue => MmChartMark(
    fill: colors.overdue,
    hatch: MmHatch.rising,
    hatchColor: colors.surface,
  ),
  MmSegmentTone.overdueSevere => MmChartMark(fill: colors.overdue),
  MmSegmentTone.credit => MmChartMark(
    fill: colors.credit,
    hatch: MmHatch.falling,
    hatchColor: colors.surface,
  ),
  MmSegmentTone.primary => MmChartMark(fill: colors.primary),
};

/// One part of an [MmProportionBar]: what it is ([label]), how much
/// ([value]) and how it looks ([tone]).
@immutable
final class MmProportionSegment {
  /// A part of [value] called [label], drawn in [tone].
  const new({required this.label, required this.value, required this.tone});

  /// What the part is ("Paid", "Overdue"), from the app's localisations.
  final String label;

  /// How much the part is: never negative, since a part of a whole cannot
  /// be (debug builds check it; release builds count a negative part as
  /// zero, in the bar and in its share).
  final Money value;

  /// How the part is drawn.
  final MmSegmentTone tone;

  @override
  bool operator ==(Object other) =>
      other is MmProportionSegment &&
      other.label == label &&
      other.value == value &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(label, value, tone);

  @override
  String toString() => 'MmProportionSegment("$label", $value, ${tone.name})';
}

/// One whole split into parts: a single horizontal bar of [segments] from
/// the start edge (from the right in Urdu), each part as long as its share,
/// with a legend under it that lists every part's label, amount and share.
///
/// Parts are separated by a 2 dp gap, and the tones of one bar differ by
/// outline, fill or hatching as well as colour ([MmSegmentTone]), so the
/// parts and their legend keys stay apart without colour. In the legend the
/// amounts and shares sit in columns as wide as the widest of them, lined
/// up on their last digit (on the right in both languages, where a figure
/// ends), so the figures of every row line up. A part of zero
/// draws nothing in the bar but keeps its legend row; a part too small to
/// see is drawn [minPartWidth] wide, so nothing that exists looks like
/// nothing. When the whole is
/// zero the bar is an empty track, with [emptyLabel] under it in place of
/// the legend.
///
/// Screen readers hear [semanticSummary] for the bar, then one node per
/// legend row: the label, the amount as a plain number and the share
/// ("Paid, 90000 rupees, 72%").
///
/// Use it for where one total went: this month's rent by status, overdue
/// rent by age. Don't use it to compare totals over time (use
/// `MmBarChart`) or for progress toward one target (use `MmMeter`).
///
/// ```dart
/// MmProportionBar(
///   semanticSummary: l10n.rentSummary('72%', '16%', '12%'),
///   emptyLabel: l10n.noRentDueYet,
///   segments: [
///     MmProportionSegment(
///       label: l10n.paid,
///       value: month.paid,
///       tone: MmSegmentTone.paid,
///     ),
///     MmProportionSegment(
///       label: l10n.overdue,
///       value: month.overdue,
///       tone: MmSegmentTone.overdue,
///     ),
///   ],
/// )
/// ```
class MmProportionBar extends StatelessWidget {
  /// A bar of [segments], read out as [semanticSummary].
  const new({
    required this.segments,
    required this.semanticSummary,
    this.emptyLabel,
    super.key,
  });

  /// The parts, in order from the start edge.
  final List<MmProportionSegment> segments;

  /// The whole bar in words, as a screen reader should say it ("72% paid,
  /// 16% due soon, 12% overdue"), from the app's localisations.
  final String semanticSummary;

  /// What to say when the whole is zero ("No rent due yet this month"),
  /// shown under the empty track in place of the legend. When null the
  /// legend lists every part at 0%.
  final String? emptyLabel;

  /// The thickness of the bar.
  static const double barHeight = MmSpace.s4;

  /// The whole-number percentage of each of [amounts] (negatives counted as
  /// zero) in their total, by the largest-remainder method so the shares
  /// add up to exactly 100. All shares are 0 when the total is zero.
  static List<int> percentagesOf(List<Money> amounts) {
    final weights = [for (final amount in amounts) math.max(0, amount.paisa)];
    if (weights.every((weight) => weight == 0)) {
      return List.filled(amounts.length, 0);
    }
    return [
      for (final share in const Money.fromPaisa(100).allocate(weights))
        share.paisa,
    ];
  }

  /// The smallest width a part that is more than nothing is drawn at, so
  /// a sliver such as "<1%" still shows in the bar.
  static const double minPartWidth = MmSpace.s1;

  @override
  Widget build(BuildContext context) {
    assert(
      segments.every((segment) => !segment.value.isNegative),
      'An MmProportionSegment is a part of a whole: it is never negative.',
    );
    assert(() {
      final treatments = <_Treatment, MmSegmentTone>{};
      for (final segment in segments) {
        final other = treatments.putIfAbsent(
          segment.tone._treatment,
          () => segment.tone,
        );
        if (other != segment.tone) {
          throw FlutterError(
            'An MmProportionBar mixes ${other.name} and ${segment.tone.name}, '
            'which differ by colour alone.',
          );
        }
      }
      return true;
    }(), 'The tones of an MmProportionBar differ by more than colour.');
    final mm = context.mm;
    final colors = mm.colors;
    final emptyLabel = this.emptyLabel;
    final weights = [
      for (final segment in segments) math.max(0, segment.value.paisa),
    ];
    final total = weights.fold(0, (sum, weight) => sum + weight);
    final empty = total == 0;
    final shares = percentagesOf([for (final s in segments) s.value]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: semanticSummary,
          child: SizedBox(
            height: barHeight,
            child: empty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(MmRadius.xs),
                      ),
                      // The control-border colour, so the empty track
                      // stands out from the surface (3:1).
                      border: Border.all(color: colors.outline),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: MmProportionBarPainter(
                      parts: [
                        for (final (index, segment) in segments.indexed)
                          if (weights[index] > 0)
                            (
                              mark: _markOf(segment.tone, colors),
                              weight: weights[index],
                            ),
                      ],
                      textDirection: Directionality.of(context),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: MmSpace.s3),
        if (empty && emptyLabel != null)
          Text(
            emptyLabel,
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(color: colors.inkMuted),
          )
        else
          Builder(
            builder: (context) {
              final format = MmFormats.moneyOf(context);
              final figures = mm.figures(
                MmTypeScale.latinBodySmall,
                colors.ink,
              );
              final amountStyle = figures.copyWith(fontWeight: FontWeight.w600);
              final shareStyle = figures.copyWith(color: colors.inkMuted);
              final labels = [
                for (final (index, _) in segments.indexed)
                  _shareLabel(shares[index], weights[index], total),
              ];
              final scaler = MediaQuery.textScalerOf(context);
              double widest(Iterable<String> texts, TextStyle style) => texts
                  .map((text) => _widthOf(text, style, scaler))
                  .fold(0, math.max);
              final amountWidth = widest([
                for (final segment in segments) format.format(segment.value),
              ], amountStyle);
              final shareWidth = widest(labels, shareStyle);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MmSpace.s2,
                children: [
                  for (final (index, segment) in segments.indexed)
                    _LegendRow(
                      segment: segment,
                      share: labels[index],
                      amountStyle: amountStyle,
                      shareStyle: shareStyle,
                      amountWidth: amountWidth,
                      shareWidth: shareWidth,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  /// The width of [text] in [style] at [scaler], rounded up to a whole
  /// pixel so it never wraps.
  static double _widthOf(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  /// [percent] as shown for a part of [weight] paisa in [total]: a part
  /// that is more than nothing never shows 0%, and a part that is less than
  /// everything never shows 100%.
  static String _shareLabel(int percent, int weight, int total) {
    if (percent == 0 && weight > 0) return '<1%';
    if (percent == 100 && weight < total) return '>99%';
    return '$percent%';
  }
}

/// One drawn part of an [MmProportionBar]: its [MmChartMark] and its
/// `weight` in paisa (more than zero).
///
/// Internal to the charts family.
typedef MmProportionPart = ({MmChartMark mark, int weight});

/// Paints the bar of an [MmProportionBar]: each of [parts] as long as its
/// share of the width, from the start edge of [textDirection], separated
/// by [MmChartMetrics.gap] and with corners of [MmRadius.xs].
///
/// Exposed for the charts family's tests; not exported from the library.
class MmProportionBarPainter extends CustomPainter {
  /// Paints [parts] from the start edge of [textDirection].
  const new({required this.parts, required this.textDirection});

  /// The parts drawn, from the start edge; none weighs zero.
  final List<MmProportionPart> parts;

  /// Which edge the first part starts at.
  final TextDirection textDirection;

  /// The widths of parts of [weights] in a bar [width] wide, after the
  /// gaps between them: each in proportion to its weight, except that a
  /// part narrower than [MmProportionBar.minPartWidth] is widened to it at
  /// the expense of the others (when every part can have it).
  static List<double> widthsFor(List<int> weights, double width) {
    final room = math.max(0, width - MmChartMetrics.gap * (weights.length - 1));
    final total = weights.fold(0, (sum, weight) => sum + weight);
    final exact = [for (final weight in weights) room * weight / total];
    const least = MmProportionBar.minPartWidth;
    final slivers = exact.where((width) => width < least).length;
    if (slivers == 0 || least * weights.length > room) return exact;
    final rest = [
      for (final (index, weight) in weights.indexed)
        if (exact[index] >= least) weight,
    ].fold(0, (sum, weight) => sum + weight);
    final spread = room - least * slivers;
    return [
      for (final (index, weight) in weights.indexed)
        if (exact[index] < least) least else spread * weight / rest,
    ];
  }

  /// The rectangle of each part in a bar of [size], in [parts] order: the
  /// first at the start edge, each next one after a gap.
  List<Rect> rectsIn(Size size) {
    final widths = widthsFor([
      for (final part in parts) part.weight,
    ], size.width);
    final rtl = textDirection == TextDirection.rtl;
    final rects = <Rect>[];
    var start = 0.0;
    for (final width in widths) {
      final left = rtl ? size.width - start - width : start;
      rects.add(Rect.fromLTWH(left, 0, width, size.height));
      start += width + MmChartMetrics.gap;
    }
    return rects;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (index, rect) in rectsIn(size).indexed) {
      final radius = math.min(MmRadius.xs, rect.width / 2);
      parts[index].mark.paint(
        canvas,
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      );
    }
  }

  @override
  bool shouldRepaint(MmProportionBarPainter oldDelegate) =>
      oldDelegate.textDirection != textDirection ||
      !listEquals(oldDelegate.parts, parts);
}

class _LegendRow extends StatelessWidget {
  const new({
    required this.segment,
    required this.share,
    required this.amountStyle,
    required this.shareStyle,
    required this.amountWidth,
    required this.shareWidth,
  });

  final MmProportionSegment segment;
  final String share;
  final TextStyle amountStyle;
  final TextStyle shareStyle;

  /// The width of the legend's widest amount, which every amount takes.
  final double amountWidth;

  /// The width of the legend's widest share, which every share takes.
  final double shareWidth;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final format = MmFormats.moneyOf(context);
    final labelStyle = mm.styleFor(segment.label, text.bodyMedium!);
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight =
        scaler.scale(labelStyle.fontSize!) * (labelStyle.height ?? 1);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MmSpace.s2,
        children: [
          SizedBox(
            height: lineHeight,
            child: Center(child: MmChartSwatch(_markOf(segment.tone, colors))),
          ),
          Expanded(
            child: MmReflow(
              alignment: MmReflowAlignment.baseline,
              start: Text(segment.label, style: labelStyle),
              end: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: MmSpace.s2,
                children: [
                  Semantics(
                    label: MmFormats.spokenMoney(
                      context,
                      segment.value,
                      format: format,
                    ),
                    excludeSemantics: true,
                    child: SizedBox(
                      width: amountWidth,
                      child: Text(
                        format.format(segment.value),
                        style: amountStyle,
                        softWrap: false,
                        // Figures end on the right in both languages: in
                        // Urdu the currency word follows on their left.
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: shareWidth,
                    child: Text(
                      share,
                      style: shareStyle,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      // "<1%" keeps its sign before the figure in Urdu.
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
