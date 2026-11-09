import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_skeleton_pulse.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A placeholder shape that stands in for content while it loads: a box
/// for a figure or an image, lines for text, a circle for an avatar.
///
/// Skeletons are shapes in the tone of a hairline rule (`rule`, decoration
/// that carries no meaning) that pulse slowly; the pulse stops when the
/// platform asks for reduced motion. That tone stands apart from the page
/// and from a card or sheet in every mode: by 1.3:1 to 1.5:1 in the light
/// and dark modes, still 1.1:1 at the faintest of the pulse, and by more
/// than 3:1 in the high-contrast modes, as a shape there needs. They are
/// hidden from assistive technology: whatever holds them says that content
/// is loading once (as `MmSkeletonList` does).
///
/// Use skeletons, not spinners, for lists and cards whose shape is known.
/// For a whole list of rows, use `MmSkeletonList`.
///
/// ```dart
/// MmCard(
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: [
///       MmSkeleton.box(width: 160, height: 40),
///       MmSkeleton.text(lines: 2),
///     ],
///   ),
/// )
/// ```
class MmSkeleton extends StatelessWidget {
  /// A box [height] dp tall and [width] dp wide, with button and field
  /// corners. Without [width] it fills the width of its parent, which must
  /// then be bounded.
  const new box({required double this.height, this.width, super.key})
    : assert(height > 0, 'A skeleton box needs a height.'),
      assert(width == null || width > 0, 'A skeleton box needs a width.'),
      lines = null,
      _round = false;

  /// [lines] lines of body text, as tall as the theme's body lines at the
  /// ambient text size, filling the width of their parent (which must be
  /// bounded). The last of several lines is shorter, as a paragraph's is.
  const new text({int this.lines = 1, super.key})
    : assert(lines > 0, 'Skeleton text needs at least one line.'),
      width = null,
      height = null,
      _round = false;

  /// A circle [diameter] dp across, for an avatar.
  const new circle({required double diameter, super.key})
    : assert(diameter > 0, 'A skeleton circle needs a diameter.'),
      width = diameter,
      height = diameter,
      lines = null,
      _round = true;

  /// The share of the width the last line of several takes.
  static const double lastLineShare = 0.6;

  /// The height of a text line's bar, as a share of the font size.
  static const double barShare = 0.75;

  /// The width of a box or circle; null when it fills its parent's width.
  final double? width;

  /// The height of a box or circle; null for text.
  final double? height;

  /// The number of text lines; null for a box or circle.
  final int? lines;

  final bool _round;

  @override
  Widget build(BuildContext context) {
    final lines = this.lines;
    return ExcludeSemantics(
      child: MmSkeletonPulse(
        child: lines == null
            ? _Bone(width: width, height: height!, round: _round)
            : _Lines(lines: lines),
      ),
    );
  }
}

/// Lines of skeleton text at the theme's body size.
class _Lines extends StatelessWidget {
  const new({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!;
    final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
    final lineHeight = fontSize * (style.height ?? 1);
    // A bar about as tall as a line's letters, centred in each line, so
    // stacked lines leave the gaps a paragraph's lines do.
    final bar = fontSize * MmSkeleton.barShare;
    final gap = (lineHeight - bar) / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var line = 0; line < lines; line++)
          Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: gap),
            child: FractionallySizedBox(
              widthFactor: lines > 1 && line == lines - 1
                  ? MmSkeleton.lastLineShare
                  : 1,
              alignment: AlignmentDirectional.centerStart,
              child: _Bone(height: bar, radius: MmRadius.xs),
            ),
          ),
      ],
    );
  }
}

/// One placeholder shape, faded by the nearest pulse.
class _Bone extends StatelessWidget {
  const new({
    required this.height,
    this.width,
    this.round = false,
    this.radius = MmRadius.sm,
  });

  final double? width;
  final double height;
  final bool round;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ShapeBorder shape = round
        ? const CircleBorder()
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          );
    return FadeTransition(
      opacity: MmSkeletonPulse.of(context),
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: context.mm.colors.rule,
            shape: shape,
          ),
        ),
      ),
    );
  }
}
