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

/// The look of an [MmProportionSegment]: a colour role, and for the roles
/// that could be mistaken for a neighbour by colour alone, an outline or a
/// hatch, so every pair of tones stays apart for colour-blind readers, in
/// greyscale and in high contrast. The segment's label says what it means;
/// the tone never carries it alone.
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

  /// Solid in the far end of the overdue ramp from the surface (the
  /// on-overdue-container role): the oldest overdue bucket of an aging
  /// breakdown ("Over 60 days"). It is deep maroon on light paper and the
  /// palest overdue tint on dark, so it is the strongest mark in every
  /// mode, at least 3:1 against the surface. It differs from [overdue] in
  /// lightness and by having no hatch, and from [paid] in lightness, which
  /// colour-blind readers still see.
  overdueSevere,

  /// The credit colour hatched with falling lines: a tenant's advance
  /// ("Advance held").
  credit,

  /// Solid cobalt: a part with no status ("Let", "Collected by bank").
  primary,
}

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
  MmSegmentTone.overdueSevere => MmChartMark(fill: colors.onOverdueContainer),
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

  /// How much the part is. A part of a whole is never negative: a negative
  /// value counts as zero in the bar and its share.
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
/// Parts are separated by a 2 dp gap, and tones that colour alone could
/// confuse also differ by outline or hatching ([MmSegmentTone]), so the
/// parts and their legend keys stay apart without colour. A part of zero
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
    final colors = context.mm.colors;
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
                      border: Border.all(color: colors.rule),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MmSpace.s2,
            children: [
              for (final (index, segment) in segments.indexed)
                _LegendRow(
                  segment: segment,
                  share: _shareLabel(shares[index], weights[index], total),
                ),
            ],
          ),
      ],
    );
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
  const new({required this.segment, required this.share});

  final MmProportionSegment segment;
  final String share;

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
    final figures = mm.figures(MmTypeScale.latinBodySmall, colors.ink);
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
                    child: Text(
                      format.format(segment.value),
                      style: figures.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    share,
                    style: figures.copyWith(color: colors.inkMuted),
                    // "<1%" keeps its sign before the figure in Urdu.
                    textDirection: TextDirection.ltr,
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
