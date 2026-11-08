import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/foundation/mm_tone.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The face of a status chip: an icon and words on a tone's container, with
/// the `xs` radius of chips and badges, so a status never relies on colour
/// alone.
///
/// The words wrap under the icon instead of overflowing, and the chip stays
/// as wide as its longest line. It adds no semantics node of its own:
/// assistive technology reads [label] as part of the nearest container, so
/// a component wraps the chip in its own node or excludes it.
///
/// Internal to mm_ui: any component family may use it.
class MmToneChip extends StatelessWidget {
  /// Shows [icon] and [label] on [tone]'s container.
  const new({
    required this.tone,
    required this.icon,
    required this.label,
    this.textAlign = TextAlign.start,
    super.key,
  });

  /// The colours of the chip.
  final MmTone tone;

  /// The icon before the words.
  final IconData icon;

  /// The words, which carry the meaning.
  final String label;

  /// How wrapped lines of [label] are aligned.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final on = tone.onContainerIn(colors);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.containerIn(colors),
        borderRadius: const BorderRadius.all(Radius.circular(MmRadius.xs)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MmSpace.s2,
          vertical: MmSpace.sHalf,
        ),
        child: MmIconLabel(
          icon: icon,
          label: label,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: on),
          iconColor: on,
          textAlign: textAlign,
          // Wrapped words keep the chip as wide as its longest line, without
          // empty fill after it.
          textWidthBasis: TextWidthBasis.longestLine,
          // An amount too wide for a narrow badge wraps between its
          // figures and its currency word, never inside the figures.
          fitWords: true,
        ),
      ),
    );
  }
}
