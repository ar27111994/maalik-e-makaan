import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Lays a choice tile ([child]) out [bleed] wider than its place on both
/// sides, so the tile's content (its own [MmSpace.s4] padding in) lines up
/// with the content edge of the page or card it sits on, while its ink,
/// hover and focus ring reach into the gutter around that content, as a
/// full-width list row's do.
///
/// A switch, checkbox or radio row is a list row: Material pads its
/// content 16 dp from the row's edges, so a row placed inside a page's
/// 16 dp gutter would sit its control 16 dp in from the fields and
/// headings above and below it. Bleeding into the gutter keeps the control
/// on the content edge, and the row's highlight as wide as a row.
///
/// The visible control lines up too, not just its touch target: Material
/// lays a row's checkbox or radio button out in a [controlBox] square with
/// its [glyph] centred, so [leadingPadding] starts the row that much nearer
/// its edge, and the box or ring itself starts on the content edge, as the
/// fields' outlines do. A switch is drawn with no padding of its own, so its
/// track ends on the content edge at the other side. Like the icons beside
/// them, the controls grow with the text, at most 150% ([scaleOf]).
///
/// Only what is painted reaches the gutter: taps there land on whatever is
/// beside the content, as they do beside a text field, because the widgets
/// that hold the content are no wider than it.
///
/// Internal to the choices family.
class MmTileBleed extends SingleChildRenderObjectWidget {
  /// Bleeds [child] by [bleed] on both sides.
  const new({required Widget super.child, this.bleed = MmSpace.s4, super.key})
    : assert(bleed >= 0, 'bleed must not be negative');

  /// How far the child reaches past each side of its place.
  final double bleed;

  /// The square Material lays a list row's checkbox or radio button out in
  /// (its 48 dp target shrink-wrapped): Material's geometry, no token.
  static const double controlBox = 40;

  /// The visible box of a checkbox, and the outer ring of a radio button,
  /// at 100% text: Material's geometry, no token.
  static const double glyph = 18;

  /// How much a row's control grows with the text in [context]: as an
  /// icon does, at most `MmIconLabel.maxIconScale` times.
  static double scaleOf(BuildContext context) =>
      MmIconLabel.scaledSize(context, 1);

  /// The padding at the start of a checkbox or radio row whose control is
  /// drawn [scale] times its size, so the control's visible [glyph] starts
  /// on the content edge, [MmSpace.s4] in from the row's bled edge.
  static double leadingPadding(double scale) =>
      MmSpace.s4 - (controlBox - glyph * scale) / 2;

  @override
  RenderMmTileBleed createRenderObject(BuildContext context) =>
      RenderMmTileBleed(bleed);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMmTileBleed renderObject,
  ) => renderObject.bleed = bleed;
}

/// The render object of [MmTileBleed]; it always has a child.
class RenderMmTileBleed extends RenderShiftedBox {
  /// Bleeds its child by [bleed] on both sides.
  new(this._bleed) : super(null);

  /// How far the child reaches past each side.
  double get bleed => _bleed;
  double _bleed;
  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsLayout();
  }

  /// [constraints] widened by the bleed on both sides.
  BoxConstraints _wider(BoxConstraints constraints) => constraints.copyWith(
    minWidth: constraints.minWidth + 2 * bleed,
    maxWidth: constraints.maxWidth + 2 * bleed,
  );

  /// The size of a child [childSize] big within [constraints].
  Size _sizeFor(BoxConstraints constraints, Size childSize) =>
      constraints.constrain(
        Size(math.max(0, childSize.width - 2 * bleed), childSize.height),
      );

  double _narrower(double width) => math.max(0, width - 2 * bleed);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _narrower(child!.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _narrower(child!.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      child!.getMinIntrinsicHeight(width + 2 * bleed);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child!.getMaxIntrinsicHeight(width + 2 * bleed);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizeFor(constraints, child!.getDryLayout(_wider(constraints)));

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => child!.getDryBaseline(_wider(constraints), baseline);

  @override
  void performLayout() {
    final child = this.child!
      ..layout(_wider(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    (child.parentData! as BoxParentData).offset = Offset(-bleed, 0);
  }
}
