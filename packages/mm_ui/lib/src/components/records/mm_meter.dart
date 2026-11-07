import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_reflow.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/foundation/mm_tone.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The colours of an [MmMeter]: a fill on the matching container. The tone
/// adds emphasis to a quantity whose meaning the label says in words; it
/// never carries a status alone.
enum MmMeterTone {
  /// Cobalt on its container: progress with no status, such as units let
  /// or a form filled in.
  primary(MmTone.primary),

  /// The paid colours: progress toward something settled, such as rent
  /// collected this month.
  paid(MmTone.paid),

  /// The due-soon colours: a quantity nearing its limit, such as a lease
  /// nearing its end.
  dueSoon(MmTone.dueSoon),

  /// The overdue colours: what is past due, such as the share of rent
  /// overdue.
  overdue(MmTone.overdue);

  new(this._tone);

  /// The design system's colour family this tone takes its roles from.
  final MmTone _tone;

  /// The colour of the filled part in [colors].
  Color fillIn(MmColorTokens colors) => _tone.colorIn(colors);

  /// The colour of the track behind the fill in [colors].
  Color trackIn(MmColorTokens colors) => _tone.containerIn(colors);
}

/// A labelled linear meter: how much of a whole is done, with the
/// [label] at the start and the [valueLabel] at the end above a bar that
/// fills from the start edge (so it fills from the right in Urdu).
///
/// The [valueLabel] says the amount in words or figures ("Rs 90,000 of Rs
/// 1,25,000", "8 of 10 units"), so the bar is never the only way to read
/// it. When label and value do not fit on one line (a narrow screen, large
/// text) the value moves under the label. Screen readers hear one node:
/// the label, then the value, as [semanticValue] when it is given. Changes
/// of [value] animate, unless the platform asks for reduced motion.
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
///   semanticValue: l10n.amountOf(
///     MmFormats.spokenMoney(context, collected),
///     MmFormats.spokenMoney(context, due),
///   ),
///   tone: MmMeterTone.paid,
/// )
/// ```
class MmMeter extends StatelessWidget {
  /// Creates a meter showing [value] of the whole.
  const new({
    required this.value,
    required this.label,
    required this.valueLabel,
    this.semanticValue,
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

  /// How a screen reader says [valueLabel] when that differs from how it
  /// looks. Grouped figures such as 1,25,000 are read out unreliably, so
  /// give amounts as plain numbers ("90000 rupees of 125000 rupees", from
  /// `MmFormats.spokenMoney`). When null, [valueLabel] is read.
  final String? semanticValue;

  /// The colours of the fill and its track.
  final MmMeterTone tone;

  /// The thickness of the bar.
  static const double barHeight = MmSpace.s2;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final text = Theme.of(context).textTheme;
    final fraction = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final fill = tone.fillIn(colors);
    const radius = BorderRadius.all(Radius.circular(MmRadius.xs));
    return Semantics(
      container: true,
      label: label,
      value: semanticValue ?? valueLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmReflow(
            alignment: MmReflowAlignment.baseline,
            start: MmScriptText(
              label,
              style: text.labelLarge!.copyWith(color: colors.ink),
            ),
            end: MmScriptText(
              valueLabel,
              style: MmSemantics.withTabularFigures(
                text.bodyMedium!.copyWith(color: colors.inkMuted),
              ),
            ),
          ),
          const SizedBox(height: MmSpace.s2),
          SizedBox(
            height: barHeight,
            child: DecoratedBox(
              // The track's hairline in the outline colour shows the whole
              // the fill is a share of: the tonal track alone is barely
              // lighter or darker than the paper. The fill covers it.
              decoration: BoxDecoration(
                color: tone.trackIn(colors),
                border: Border.all(color: colors.outline),
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
