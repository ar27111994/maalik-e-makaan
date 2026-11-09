import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The keyboard focus ring of a filled control: a ring in the focus colour,
/// drawn outside the control with a gap between them, so it shows on any
/// fill (cobalt, overdue red, a disabled grey) and in every colour mode.
///
/// A ring on the control's own edge, as outlined buttons and fields draw it,
/// would vanish on a filled control whose fill is the focus colour (cobalt in
/// light and dark mode). Here the control keeps its fill and edge, a
/// [MmSize.focusGap] strip of whatever it sits on separates them, and the
/// ring follows the control's outline [MmSize.focusRing] wide. Against the
/// page, cards and sunken wells the focus colour reaches 3:1 (4.5:1 in the
/// high-contrast modes); the token build checks it. The ring surrounds the
/// whole control, so it is larger than a 2 dp perimeter of it (WCAG 2.4.13).
///
/// The theme draws it for filled, elevated and icon buttons and the floating
/// action button. A component that styles a filled control itself uses
/// [whenFocused] for the same ring:
///
/// ```dart
/// FilledButton(
///   style: ButtonStyle(
///     shape: MmFocusRingBorder.whenFocused(
///       const StadiumBorder(),
///       color: context.mm.colors.focus,
///     ),
///   ),
///   onPressed: onPressed,
///   child: Text(label),
/// )
/// ```
///
/// Only the ring is painted outside [shape]: fill, ink, clip, layout and hit
/// testing keep [shape]'s outline. Leave [MmSize.focusGap] plus
/// [MmSize.focusRing] (4 dp) around a filled control, so a neighbour or a
/// clipping parent does not cover the ring (WCAG 2.4.11).
@immutable
final class MmFocusRingBorder extends OutlinedBorder {
  /// A focus ring of [color] around [shape].
  const new(
    this.shape, {
    required this.color,
    this.width = MmSize.focusRing,
    this.gap = MmSize.focusGap,
  });

  /// [shape] while the control is not focused, and [shape] inside a focus
  /// ring of [color] while it is: for `ButtonStyle.shape`, or the `shape` of
  /// a floating action button.
  static WidgetStateOutlinedBorder whenFocused(
    OutlinedBorder shape, {
    required Color color,
  }) => WidgetStateOutlinedBorder.resolveWith(
    (states) => states.contains(WidgetState.focused)
        ? MmFocusRingBorder(shape, color: color)
        : shape,
  );

  /// The control's own outline, with its border [side].
  final OutlinedBorder shape;

  /// The colour of the ring.
  final Color color;

  /// The width of the ring.
  final double width;

  /// The space between the control's edge and the ring.
  final double gap;

  /// The control's own border, which the ring does not change.
  @override
  BorderSide get side => shape.side;

  @override
  EdgeInsetsGeometry get dimensions => shape.dimensions;

  @override
  OutlinedBorder copyWith({BorderSide? side}) => MmFocusRingBorder(
    shape.copyWith(side: side),
    color: color,
    width: width,
    gap: gap,
  );

  @override
  ShapeBorder scale(double t) {
    final scaled = shape.scale(t);
    if (scaled is! OutlinedBorder) return scaled;
    return MmFocusRingBorder(
      scaled,
      color: color,
      width: width * t,
      gap: gap * t,
    );
  }

  /// Focus arriving: the ring fades in around the shape.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is MmFocusRingBorder) {
      return MmFocusRingBorder(
        OutlinedBorder.lerp(a.shape, shape, t)!,
        color: Color.lerp(a.color, color, t)!,
        width: lerpDouble(a.width, width, t)!,
        gap: lerpDouble(a.gap, gap, t)!,
      );
    }
    if (a is OutlinedBorder) {
      return MmFocusRingBorder(
        OutlinedBorder.lerp(a, shape, t)!,
        color: color.withValues(alpha: color.a * t),
        width: width,
        gap: gap,
      );
    }
    return super.lerpFrom(a, t);
  }

  /// Focus leaving: the ring fades out around the shape.
  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is MmFocusRingBorder) return b.lerpFrom(this, t);
    if (b is OutlinedBorder) {
      return MmFocusRingBorder(
        OutlinedBorder.lerp(shape, b, t)!,
        color: color.withValues(alpha: color.a * (1 - t)),
        width: width,
        gap: gap,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      shape.getOuterPath(rect, textDirection: textDirection);

  @override
  bool get preferPaintInterior => shape.preferPaintInterior;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) => shape.paintInterior(canvas, rect, paint, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    shape.paint(canvas, rect, textDirection: textDirection);
    // The ring's centre line, outside the edge by the gap and half the
    // ring. Its corners stay concentric with the control's: a rounded
    // rectangle's radii grow by the same distance (stadiums and circles
    // follow from their bounds).
    final offset = gap + width / 2;
    final outline = switch (shape) {
      RoundedRectangleBorder(:final borderRadius) =>
        Path()..addRRect(
          borderRadius.resolve(textDirection).toRRect(rect).inflate(offset),
        ),
      _ => shape.getOuterPath(
        rect.inflate(offset),
        textDirection: textDirection,
      ),
    };
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MmFocusRingBorder &&
      other.shape == shape &&
      other.color == color &&
      other.width == width &&
      other.gap == gap;

  @override
  int get hashCode => Object.hash(shape, color, width, gap);

  @override
  String toString() =>
      'MmFocusRingBorder($shape, $color, width: $width, gap: $gap)';
}
