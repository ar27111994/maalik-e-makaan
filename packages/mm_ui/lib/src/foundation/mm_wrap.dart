import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [Wrap] of [children] in a row that also says how wide it is truly:
/// its widest intrinsic width counts the [spacing] between its children.
///
/// Flutter's `RenderWrap` leaves the spacing out of its widest intrinsic
/// width, so a layout that asks how wide a wrap would be on one line (as
/// `MmReflow` asks of its end widget, to decide whether it fits beside the
/// text) is told too little: the wrap is then given that much room and
/// breaks onto a second line. In a legend that put one row's share under
/// its amount while every other row kept them on one line. Use it for a
/// wrap that such a layout measures.
///
/// Internal to mm_ui: any component family may use it.
class MmWrap extends StatelessWidget {
  /// Wraps [children] in a row, [spacing] apart.
  const new({
    required this.children,
    this.spacing = 0,
    this.runSpacing = 0,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.textDirection,
    super.key,
  });

  /// The widgets wrapped, in reading order.
  final List<Widget> children;

  /// The space between neighbours on a line.
  final double spacing;

  /// The space between lines.
  final double runSpacing;

  /// How each line sits along the row.
  final WrapAlignment alignment;

  /// How the children of a line line up across it.
  final WrapCrossAlignment crossAxisAlignment;

  /// The direction the children run in; the ambient one when null.
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) => _WithSpacing(
    spacing: children.length < 2 ? 0 : spacing * (children.length - 1),
    child: Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      children: children,
    ),
  );
}

/// Adds the [spacing] its wrap leaves out to the wrap's widest intrinsic
/// width.
class _WithSpacing extends SingleChildRenderObjectWidget {
  const new({required this.spacing, required super.child});

  final double spacing;

  @override
  _RenderWithSpacing createRenderObject(BuildContext context) =>
      _RenderWithSpacing(spacing);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWithSpacing renderObject,
  ) => renderObject.spacing = spacing;
}

class _RenderWithSpacing extends RenderProxyBox {
  new(this._spacing);

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  @override
  double computeMaxIntrinsicWidth(double height) =>
      super.computeMaxIntrinsicWidth(height) + spacing;
}
