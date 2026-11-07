import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Paints a keyboard focus ring, [MmSize.focusRing] wide, whose outer edge
/// is a rounded box centred on the widget it is painted over.
///
/// The box is [size], or, where [size] is null, the widget's own width
/// grown by [widthOutset] on each side and [height] tall. Stock navigation
/// bars, rails and tab bars draw focus only as a faint tint; the layout
/// family's destinations and tabs paint this ring over their content
/// instead, as `DESIGN.md` asks of every focusable control.
///
/// Internal to the layout family.
class MmFocusRingPainter extends CustomPainter {
  /// Rings a box of [size] (or of the widget's width plus [widthOutset] on
  /// each side by [height]) with corners of [radius], in [color].
  const new({
    required this.color,
    required this.radius,
    this.size,
    this.height,
    this.widthOutset = 0,
  }) : assert(size != null || height != null, 'Give the ring a height');

  /// The ring's colour.
  final Color color;

  /// The corner radius of the ring's outer edge.
  final double radius;

  /// The size of the ring's outer edge, or null to size it from the widget.
  final Size? size;

  /// The height of the ring's outer edge when [size] is null.
  final double? height;

  /// How far the ring reaches past each side of the widget when [size] is
  /// null.
  final double widthOutset;

  /// The ring's outer edge around a widget of [widget] size.
  Rect outerEdge(Size widget) {
    final box =
        size ?? Size(widget.width + 2 * widthOutset, height ?? widget.height);
    return Rect.fromCenter(
      center: widget.center(Offset.zero),
      width: box.width,
      height: box.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The stroke is centred on its path: half a stroke inside the edge.
    final path = outerEdge(size).deflate(MmSize.focusRing / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        path,
        Radius.circular(radius - MmSize.focusRing / 2),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = MmSize.focusRing
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(MmFocusRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.size != size ||
      oldDelegate.height != height ||
      oldDelegate.widthOutset != widthOutset;
}
