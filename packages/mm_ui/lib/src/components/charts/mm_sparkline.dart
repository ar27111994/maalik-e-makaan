import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A word-sized line of how a figure moved: a 2 dp cobalt line through
/// [values] in order, with a dot on the latest value. Time runs from the
/// start edge, so in Urdu the line runs from right to left and the dot sits
/// at the left end.
///
/// It is decoration: the line has no axis, so screen readers skip it and
/// the tile around it must state the trend in words (an `MmStatTile`'s
/// trend, "Up 12% since June"). The line spans the lowest to the highest
/// value; a flat series draws a level line through the middle, a single
/// value draws only its dot, and no values draw nothing. Values that are
/// not finite numbers are left out.
///
/// Use it beside a figure to show its recent shape. Don't use it when the
/// reader needs the values (use `MmBarChart`, which has an axis, readouts
/// and a table view).
///
/// ```dart
/// Row(
///   spacing: MmSpace.s3,
///   children: [
///     Text(l10n.upSince('12%', 'June')),
///     MmSparkline(
///       values: [for (final month in months) month.collected.paisa / 100],
///     ),
///   ],
/// )
/// ```
class MmSparkline extends StatelessWidget {
  /// A sparkline of [values], [width] by [height] dp.
  const new({
    required this.values,
    this.width = 64,
    this.height = 24,
    super.key,
  });

  /// The figures, oldest first.
  final List<double> values;

  /// The width of the sparkline.
  final double width;

  /// The height of the sparkline.
  final double height;

  /// The width of the line.
  static const double lineWidth = MmSize.stroke;

  /// The radius of the dot on the latest value: an 8 dp marker, the
  /// smallest that reads as a point rather than a bump in the line.
  static const double dotRadius = MmSpace.s1;

  /// The width of the surface-coloured ring around the dot, which parts it
  /// from the line running into it.
  static const double ringWidth = MmSpace.sHalf;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: MmSparklinePainter(
          values: [
            for (final value in values)
              if (value.isFinite) value,
          ],
          color: colors.primary,
          ringColor: colors.surface,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

/// Paints an [MmSparkline].
///
/// Exposed for the charts family's tests; not exported from the library.
class MmSparklinePainter extends CustomPainter {
  /// Paints a line through [values] in [color], from the start edge of
  /// [textDirection], with a dot ringed in [ringColor] on the last value.
  const new({
    required this.values,
    required this.color,
    required this.ringColor,
    required this.textDirection,
  });

  /// The finite values, oldest first.
  final List<double> values;

  /// The colour of the line and the dot.
  final Color color;

  /// The colour of the ring around the dot: the surface under the line.
  final Color ringColor;

  /// Which edge time runs from.
  final TextDirection textDirection;

  /// The points of [values] in a canvas of [size]: inset by the dot and its
  /// ring so neither is cut off, spread evenly from the start edge, the
  /// highest value at the top. A single value sits at the end edge.
  List<Offset> pointsIn(Size size) {
    if (values.isEmpty) return const [];
    const inset = MmSparkline.dotRadius + MmSparkline.ringWidth;
    const left = inset;
    final right = math.max(left, size.width - inset);
    const top = inset;
    final bottom = math.max(top, size.height - inset);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = high - low;
    final steps = values.length - 1;
    final rtl = textDirection == TextDirection.rtl;
    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          _along(steps == 0 ? 1 : i / steps, left, right, reversed: rtl),
          span == 0
              ? (top + bottom) / 2
              : bottom - (values[i] - low) / span * (bottom - top),
        ),
    ];
  }

  static double _along(
    double t,
    double start,
    double end, {
    required bool reversed,
  }) => reversed ? end - t * (end - start) : start + t * (end - start);

  @override
  void paint(Canvas canvas, Size size) {
    final points = pointsIn(size);
    if (points.isEmpty) return;
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = MmSparkline.lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final last = points.last;
    canvas
      ..drawCircle(
        last,
        MmSparkline.dotRadius + MmSparkline.ringWidth,
        Paint()..color = ringColor,
      )
      ..drawCircle(last, MmSparkline.dotRadius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(MmSparklinePainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.color != color ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.textDirection != textDirection;
}
