import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/records/mm_record_line.dart';
import 'package:mm_ui/src/components/records/mm_record_style.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The colours of an [MmMeter]: a fill on the matching container. The tone
/// adds emphasis to a quantity whose meaning the label says in words; it
/// never carries a status alone.
enum MmMeterTone {
  /// Cobalt on its container: progress with no status, such as units let
  /// or a form filled in.
  primary,

  /// The paid colours: progress toward something settled, such as rent
  /// collected this month.
  paid,

  /// The due-soon colours: a quantity nearing its limit, such as a lease
  /// nearing its end.
  dueSoon,

  /// The overdue colours: what is past due, such as the share of rent
  /// overdue.
  overdue;

  /// The colour of the filled part in [colors].
  Color fillIn(MmColorTokens colors) => switch (this) {
    MmMeterTone.primary => colors.primary,
    MmMeterTone.paid => colors.paid,
    MmMeterTone.dueSoon => colors.dueSoon,
    MmMeterTone.overdue => colors.overdue,
  };

  /// The colour of the track behind the fill in [colors].
  Color trackIn(MmColorTokens colors) => switch (this) {
    MmMeterTone.primary => colors.primaryContainer,
    MmMeterTone.paid => colors.paidContainer,
    MmMeterTone.dueSoon => colors.dueSoonContainer,
    MmMeterTone.overdue => colors.overdueContainer,
  };
}

/// A labelled linear meter: how much of a whole is done, with the
/// [label] at the start and the [valueLabel] at the end above a bar that
/// fills from the start edge (so it fills from the right in Urdu).
///
/// The [valueLabel] says the amount in words or figures ("Rs 90,000 of Rs
/// 1,25,000", "8 of 10 units"), so the bar is never the only way to read
/// it. When label and value do not fit on one line (a narrow screen, large
/// text) the value moves under the label. Screen readers hear one node:
/// the label, then the value. Changes of [value] animate, unless the
/// platform asks for reduced motion.
///
/// Use it for a share of a known whole: rent collected this month, units
/// let, a lease's months elapsed. Don't use it for work in progress with
/// no known end (use a progress indicator) or to compare several
/// quantities (use a chart).
///
/// ```dart
/// MmMeter(
///   value: collected.paisa / due.paisa,
///   label: l10n.rentCollected,
///   valueLabel: l10n.amountOf(format.format(collected), format.format(due)),
///   tone: MmMeterTone.paid,
/// )
/// ```
class MmMeter extends StatelessWidget {
  /// Creates a meter showing [value] of the whole.
  const new({
    required this.value,
    required this.label,
    required this.valueLabel,
    this.tone = MmMeterTone.primary,
    super.key,
  });

  /// How much of the whole is done, from 0 (empty) to 1 (full). Values
  /// outside that range are clamped; a value that is not a number shows an
  /// empty bar.
  final double value;

  /// What is measured ("Rent collected"), from the app's localisations.
  final String label;

  /// The value in words or figures ("Rs 90,000 of Rs 1,25,000"), shown at
  /// the end and read out after [label]. It wraps when it does not fit: join
  /// the parts of each amount with a no-break space (`Rs\u00A090,000`) so a
  /// currency never ends a line apart from its number.
  final String valueLabel;

  /// The colours of the fill and its track.
  final MmMeterTone tone;

  /// The thickness of the bar.
  static const double barHeight = MmSpace.s2;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final colors = mm.colors;
    final text = Theme.of(context).textTheme;
    final fraction = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final fill = tone.fillIn(colors);
    const radius = BorderRadius.all(Radius.circular(MmRadius.xs));
    return Semantics(
      container: true,
      label: label,
      value: valueLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmRecordLine(
            start: Text(
              label,
              style: mm.dataStyleFor(
                label,
                text.labelLarge!.copyWith(color: colors.ink),
              ),
            ),
            end: Text(
              valueLabel,
              style: mm.dataStyleFor(
                valueLabel,
                text.bodyMedium!.copyWith(
                  color: colors.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: MmSpace.s2),
          SizedBox(
            height: barHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tone.trackIn(colors),
                borderRadius: radius,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: MmMotion.of(context, MmDuration.standard),
                curve: MmEasing.standard,
                builder: (context, shown, _) => FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: shown,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
