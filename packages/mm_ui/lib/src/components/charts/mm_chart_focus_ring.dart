import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The keyboard focus ring of a chart or a table: a [MmSize.focusRing]
/// ring in the focus colour drawn around [child], outside it past a
/// [MmSize.focusGap] gap, so it never runs over the axis labels, the
/// table's text or its scrollbar at the child's edges.
///
/// It takes no room of its own: leave [reach] around the child (a card's
/// padding does) so a neighbour or a clipping parent does not cover it.
///
/// Internal to the charts family.
class MmChartFocusRing extends StatelessWidget {
  /// Draws the ring around [child] while [shown].
  const new({required this.shown, required this.child, super.key});

  /// Whether the ring is drawn: the child has keyboard focus.
  final bool shown;

  /// What the ring surrounds.
  final Widget child;

  /// How far the ring reaches past the child's edge.
  static const double reach = MmSize.focusGap + MmSize.focusRing;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: shown
        ? MmChartFocusRingPainter(color: context.mm.colors.focus)
        : null,
    child: child,
  );
}

/// Paints an [MmChartFocusRing] around the box it is given.
///
/// Exposed for the charts family's tests; not exported from the library.
class MmChartFocusRingPainter extends CustomPainter {
  /// A ring of [color].
  const new({required this.color});

  /// The focus colour.
  final Color color;

  /// The ring's centre line around a box of [size]: past the gap and half
  /// the ring, its corners the `xs` radius grown by the same distance.
  static RRect ringFor(Size size) {
    const offset = MmSize.focusGap + MmSize.focusRing / 2;
    return RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(offset),
      const Radius.circular(MmRadius.xs + offset),
    );
  }

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    ringFor(size),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = MmSize.focusRing
      ..color = color,
  );

  @override
  bool shouldRepaint(MmChartFocusRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
