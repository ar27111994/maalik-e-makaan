import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/records/mm_record_icon_label.dart';
import 'package:mm_ui/src/components/records/mm_record_style.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The band a payment score falls in, which picks the gauge's colour and
/// icon. The app picks the band's word for [MmScoreGauge.bandLabel] with
/// [MmScoreBand.of], so the word and the colour always agree.
enum MmScoreBand {
  /// 75 and above: pays on time. The paid colours.
  good,

  /// 50 to 74: sometimes late. The due-soon colours.
  fair,

  /// Below 50: often late. The overdue colours.
  poor;

  /// The band of [score] (on a scale of 0 to 100).
  static MmScoreBand of(int score) {
    if (score >= 75) return good;
    if (score >= 50) return fair;
    return poor;
  }

  /// The colour of the gauge's value arc in [colors].
  Color colorIn(MmColorTokens colors) => switch (this) {
    MmScoreBand.good => colors.paid,
    MmScoreBand.fair => colors.dueSoon,
    MmScoreBand.poor => colors.overdue,
  };

  /// The fill of the band's chip in [colors].
  Color containerIn(MmColorTokens colors) => switch (this) {
    MmScoreBand.good => colors.paidContainer,
    MmScoreBand.fair => colors.dueSoonContainer,
    MmScoreBand.poor => colors.overdueContainer,
  };

  /// The colour of the band's word and icon on [containerIn] in [colors].
  Color onContainerIn(MmColorTokens colors) => switch (this) {
    MmScoreBand.good => colors.onPaidContainer,
    MmScoreBand.fair => colors.onDueSoonContainer,
    MmScoreBand.poor => colors.onOverdueContainer,
  };

  /// The icon shown before the band's word.
  IconData get icon => switch (this) {
    MmScoreBand.good => MmIcons.success,
    MmScoreBand.fair => MmIcons.warning,
    MmScoreBand.poor => MmIcons.error,
  };
}

/// A tenant's payment score out of 100 on a semicircular gauge: the arc
/// fills from the start side (from the right in Urdu) in the colour of the
/// score's band, the number sits in the middle in the Latin amount face,
/// and the band's word with an icon sits under it, so the band never
/// relies on colour alone. An optional [caption] explains the score.
///
/// The gauge grows with the text size so its number keeps fitting inside
/// the arc, and scales down when its space is narrower. Screen readers
/// hear exactly [semanticLabel] for the gauge, which the app words in full
/// ("Payment score 82 out of 100, good"), then the caption.
///
/// Use it for a single score on a tenant's profile. Don't use it for a
/// share of a whole (use `MmMeter`) or to compare scores (use a chart).
///
/// ```dart
/// MmScoreGauge(
///   score: tenant.score,
///   bandLabel: l10n.scoreBand(MmScoreBand.of(tenant.score)),
///   semanticLabel: l10n.paymentScoreSpoken(tenant.score),
///   caption: l10n.scoreBasis(12),
/// )
/// ```
class MmScoreGauge extends StatelessWidget {
  /// Creates a gauge showing [score].
  const new({
    required this.score,
    required this.bandLabel,
    required this.semanticLabel,
    this.caption,
    this.size = 120,
    super.key,
  }) : assert(size > 0, 'A gauge needs a positive size.');

  /// The score from 0 to 100; values outside that range are clamped.
  final int score;

  /// The band's word ("Good", "Fair", "Poor"), from the app's
  /// localisations; pick it with [MmScoreBand.of].
  final String bandLabel;

  /// What a screen reader says for the gauge, in full ("Payment score 82
  /// out of 100, good").
  final String semanticLabel;

  /// An optional line under the gauge explaining the score ("Based on 12
  /// months of payments").
  final String? caption;

  /// The width of the gauge at 100% text size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final shown = score.clamp(0, 100);
    final band = MmScoreBand.of(shown);
    final numberStyle = mm.amountLarge;
    final fontSize = numberStyle.fontSize!;
    final textScale =
        MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
    final width = size * textScale;
    final stroke = width / 10;
    final innerRadius = width / 2 - stroke;
    final caption = this.caption;
    final onBand = band.onContainerIn(colors);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width,
                  height: width / 2 + stroke / 2,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      fraction: shown / 100,
                      stroke: stroke,
                      track: colors.rule,
                      value: band.colorIn(colors),
                      textDirection: Directionality.of(context),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: innerRadius * 2,
                        height: innerRadius,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            '$shown',
                            style: numberStyle,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MmSpace.s2),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: band.containerIn(colors),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(MmRadius.xs),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: MmSpace.s2,
                    vertical: MmSpace.sHalf,
                  ),
                  child: MmRecordIconLabel(
                    icon: band.icon,
                    label: bandLabel,
                    style: text.labelLarge!.copyWith(color: onBand),
                    iconColor: onBand,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: MmSpace.s2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: mmSmallPrint(text.bodySmall!, colors),
          ),
        ],
      ],
    );
  }
}

/// Paints the gauge: a thin semicircular track and, over it, the thicker
/// value arc filling from the start side.
class _GaugePainter extends CustomPainter {
  const new({
    required this.fraction,
    required this.stroke,
    required this.track,
    required this.value,
    required this.textDirection,
  });

  /// How much of the arc is filled, from 0 to 1.
  final double fraction;
  final double stroke;
  final Color track;
  final Color value;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final arc = Rect.fromCircle(
      center: Offset(radius, radius),
      radius: radius - stroke / 2,
    );
    // The track is half as thick as the value arc, so filled and unfilled
    // differ in shape as well as colour.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke / 2
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(arc, math.pi, math.pi, false, paint);
    if (fraction <= 0) return;
    // Angles run clockwise from the positive x axis: the arc's left end is
    // at pi and its right end at 0, so a positive sweep from pi fills from
    // the left and a negative sweep from 0 fills from the right.
    final sweep = math.pi * fraction;
    final ltr = textDirection == TextDirection.ltr;
    canvas.drawArc(
      arc,
      ltr ? math.pi : 0,
      ltr ? sweep : -sweep,
      false,
      paint
        ..strokeWidth = stroke
        ..color = value,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      stroke != oldDelegate.stroke ||
      track != oldDelegate.track ||
      value != oldDelegate.value ||
      textDirection != oldDelegate.textDirection;
}
