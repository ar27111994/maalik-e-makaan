import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_skeleton_pulse.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A placeholder shape that stands in for content while it loads: a box
/// for a figure or an image, lines for text, a circle for an avatar.
///
/// Skeletons are inset wells (`surfaceSunken`, outlined with a hairline
/// rule in the high-contrast modes) that pulse slowly; the pulse stops when
/// the platform asks for reduced motion. They are hidden from assistive
/// technology: whatever holds them says that content is loading once (as
/// `MmSkeletonList` does). Place them on a surface (a card or a sheet),
/// where the sunken tone shows.
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
    final mm = context.mm;
    // A hairline rule in the high-contrast modes, where the sunken tone
    // alone barely differs from the surface.
    final side = mm.highContrast
        ? BorderSide(color: mm.colors.rule)
        : BorderSide.none;
    final ShapeBorder shape = round
        ? CircleBorder(side: side)
        : RoundedRectangleBorder(
            side: side,
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          );
    return FadeTransition(
      opacity: MmSkeletonPulse.of(context),
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: mm.colors.surfaceSunken,
            shape: shape,
          ),
        ),
      ),
    );
  }
}
