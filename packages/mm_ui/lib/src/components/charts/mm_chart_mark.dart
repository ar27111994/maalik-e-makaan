import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The direction of a mark's hatching.
///
/// Internal to the charts family.
enum MmHatch {
  /// Lines rising from the bottom-left corner to the top-right (45°).
  rising,

  /// Lines falling from the top-left corner to the bottom-right (135°).
  falling,

  /// Both: lines rising and falling, crossing in a lattice, which leaves
  /// less of the fill showing than lines one way.
  crossed,
}

/// How a chart mark (a bar, a segment, a legend swatch) is drawn: a [fill],
/// an optional [stroke] drawn inside its edge, and optional [hatch] lines
/// in [hatchColor] over the fill.
///
/// Status colours cannot tell every pair of marks apart for every reader
/// (red and amber look alike to a deuteranope), so marks that may sit side
/// by side differ by more than colour: solid, outlined or hatched one way
/// or the other. A legend swatch is drawn with the same mark as what it
/// names.
///
/// Internal to the charts family.
@immutable
final class MmChartMark {
  /// A mark filled with [fill], outlined with [stroke] and hatched in
  /// [hatch] direction with [hatchColor].
  const new({required this.fill, this.stroke, this.hatch, this.hatchColor})
    : assert(
        (hatch == null) == (hatchColor == null),
        'A hatch needs both a direction and a colour.',
      );

  /// The colour inside the mark.
  final Color fill;

  /// The colour of the [MmSize.stroke] wide line drawn just inside
  /// the mark's edge, or null for none.
  final Color? stroke;

  /// The direction of the hatching, or null for none.
  final MmHatch? hatch;

  /// The colour of the hatching lines: the surface, so the hatch reads as
  /// paper showing through the ink.
  final Color? hatchColor;

  /// The distance between hatching lines along the mark's width: a chart
  /// geometry with no token, close enough for two lines to cross a 12 dp
  /// legend swatch.
  static const double hatchStep = 6;

  /// The width of a hatching line: a chart geometry with no token, between
  /// the hairline (too faint to read as texture) and the 2 dp stroke (which
  /// would leave little of the fill's colour between the lines).
  static const double hatchWidth = 1.5;

  /// Paints this mark in [shape] on [canvas].
  void paint(Canvas canvas, RRect shape) {
    if (shape.width <= 0 || shape.height <= 0) return;
    canvas.drawRRect(shape, Paint()..color = fill);
    final hatch = this.hatch;
    final hatchColor = this.hatchColor;
    if (hatch != null && hatchColor != null) {
      _paintHatch(canvas, shape, hatch, hatchColor);
    }
    final stroke = this.stroke;
    if (stroke != null) {
      const inset = MmSize.stroke / 2;
      canvas.drawRRect(
        shape.deflate(inset),
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = MmSize.stroke,
      );
    }
  }

  static void _paintHatch(
    Canvas canvas,
    RRect shape,
    MmHatch hatch,
    Color color,
  ) {
    final rect = shape.outerRect;
    final paint = Paint()
      ..color = color
      ..strokeWidth = hatchWidth;
    canvas
      ..save()
      ..clipRRect(shape);
    final rise = rect.height;
    final rising = hatch != MmHatch.falling;
    final falling = hatch != MmHatch.rising;
    for (var x = rect.left - rise; x < rect.right; x += hatchStep) {
      if (rising) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rise, rect.top),
          paint,
        );
      }
      if (falling) {
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x + rise, rect.bottom),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool operator ==(Object other) =>
      other is MmChartMark &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.hatch == hatch &&
      other.hatchColor == hatchColor;

  @override
  int get hashCode => Object.hash(fill, stroke, hatch, hatchColor);

  @override
  String toString() =>
      'MmChartMark(fill: $fill, stroke: $stroke, hatch: ${hatch?.name})';
}

/// Paints one [MmChartMark] filling its canvas, with corners of [radius]:
/// a proportion bar's segment or a legend swatch.
///
/// Internal to the charts family.
class MmChartMarkPainter extends CustomPainter {
  /// Paints [mark] with corners of [radius].
  const new(this.mark, {required this.radius});

  /// The mark painted.
  final MmChartMark mark;

  /// The corner radius of the mark.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) => mark.paint(
    canvas,
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
  );

  @override
  bool shouldRepaint(MmChartMarkPainter oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.radius != radius;
}
