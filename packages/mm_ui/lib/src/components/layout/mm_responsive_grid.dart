import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A grid of equal-width columns, as many as fit the width at
/// [minItemWidth] each (at least one), for cards and stat tiles.
///
/// Each row is as tall as its tallest child, and every child in the row is
/// stretched to that height, so cards in a row line up top and bottom
/// however much text each holds. Children fill the rows in order from the
/// start edge (from the right in Urdu); a short last row keeps the same
/// column widths. Screen readers and keyboard focus go through the children
/// in that order, finishing one child before the next.
///
/// For tiles that are mostly text, scale [minItemWidth] with the text
/// (`MediaQuery.textScalerOf(context).scale(160)`), so large text gets fewer,
/// wider columns rather than words broken across lines.
///
/// The grid does not scroll: put it in a scrolling page (an `MmPage`). With
/// no width limit (inside a horizontal scroll view) every child sits in one
/// row at [minItemWidth]. Don't use it for long or lazily built lists (use a
/// `ListView`), or for items that must keep a fixed aspect ratio (use a
/// `GridView`).
///
/// ```dart
/// MmResponsiveGrid(
///   minItemWidth: 160,
///   children: [
///     for (final property in properties) PropertyCard(property),
///   ],
/// )
/// ```
class MmResponsiveGrid extends StatelessWidget {
  /// Lays out [children] in as many columns as fit.
  const new({
    required this.children,
    this.minItemWidth = 280,
    this.spacing = MmSpace.s3,
    super.key,
  }) : assert(minItemWidth > 0, 'minItemWidth must be positive'),
       assert(spacing >= 0, 'spacing must not be negative');

  /// The grid's items, in reading order.
  final List<Widget> children;

  /// The narrowest a column may be. The grid uses as many columns as fit at
  /// this width and shares what is left over equally; a grid narrower than
  /// this has one column as wide as itself.
  final double minItemWidth;

  /// The space between columns and between rows.
  final double spacing;

  @override
  Widget build(BuildContext context) => _MmGrid(
    minItemWidth: minItemWidth,
    spacing: spacing,
    textDirection: Directionality.of(context),
    children: [
      for (final child in children)
        // Keyboard focus finishes one item before moving to the next.
        FocusTraversalGroup(
          key: switch (child.key) {
            final Key key => ValueKey<Key>(key),
            null => null,
          },
          child: child,
        ),
    ],
  );
}

class _MmGrid extends MultiChildRenderObjectWidget {
  const new({
    required this.minItemWidth,
    required this.spacing,
    required this.textDirection,
    required super.children,
  });

  final double minItemWidth;
  final double spacing;
  final TextDirection textDirection;

  @override
  _RenderMmGrid createRenderObject(BuildContext context) => _RenderMmGrid(
    minItemWidth: minItemWidth,
    spacing: spacing,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderMmGrid renderObject) {
    renderObject
      ..minItemWidth = minItemWidth
      ..spacing = spacing
      ..textDirection = textDirection;
  }
}

class _MmGridParentData extends ContainerBoxParentData<RenderBox>;

/// The columns of a grid at some width.
typedef _Columns = ({int count, double width});

class _RenderMmGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MmGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MmGridParentData> {
  new({
    required this._minItemWidth,
    required this._spacing,
    required this._textDirection,
  });

  double get minItemWidth => _minItemWidth;
  double _minItemWidth;
  set minItemWidth(double value) {
    if (value == _minItemWidth) return;
    _minItemWidth = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MmGridParentData) {
      child.parentData = _MmGridParentData();
    }
  }

  /// The columns that fit [width]: as many as fit at [minItemWidth], at
  /// least one, sharing the width equally. Without a width limit every
  /// child gets a column at [minItemWidth].
  _Columns _columnsFor(double width) {
    if (!width.isFinite) {
      return (count: math.max(1, childCount), width: minItemWidth);
    }
    final count = math.max(
      1,
      ((width + spacing) / (minItemWidth + spacing)).floor(),
    );
    return (
      count: count,
      width: math.max(0, (width - spacing * (count - 1)) / count),
    );
  }

  /// The grid's width for [columns] within [constraints].
  double _widthFor(BoxConstraints constraints, _Columns columns) =>
      constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : columns.count * columns.width + spacing * (columns.count - 1);

  /// The rows of children, [count] at a time.
  List<List<RenderBox>> _rows(int count) {
    final rows = <List<RenderBox>>[];
    var child = firstChild;
    while (child != null) {
      if (rows.isEmpty || rows.last.length == count) rows.add([]);
      rows.last.add(child);
      child = childAfter(child);
    }
    return rows;
  }

  /// The grid's height when each row is as tall as its tallest child, the
  /// children measured by [heightOf] at the column width.
  double _heightFor(
    _Columns columns,
    double Function(RenderBox child, double width) heightOf,
  ) {
    final rows = _rows(columns.count);
    var height = 0.0;
    for (final row in rows) {
      height += row.fold(
        0.0,
        (tallest, child) => math.max(tallest, heightOf(child, columns.width)),
      );
    }
    return height + spacing * math.max(0, rows.length - 1);
  }

  @override
  void performLayout() {
    final columns = _columnsFor(constraints.maxWidth);
    final width = _widthFor(constraints, columns);
    final rtl = textDirection == TextDirection.rtl;
    final natural = BoxConstraints.tightFor(width: columns.width);
    var top = 0.0;
    final rows = _rows(columns.count);
    for (final row in rows) {
      var rowHeight = 0.0;
      for (final child in row) {
        child.layout(natural, parentUsesSize: true);
        rowHeight = math.max(rowHeight, child.size.height);
      }
      for (final (column, child) in row.indexed) {
        // Stretch the shorter children to the row's height.
        if (child.size.height < rowHeight) {
          child.layout(
            BoxConstraints.tightFor(width: columns.width, height: rowHeight),
            parentUsesSize: true,
          );
        }
        final start = column * (columns.width + spacing);
        (child.parentData! as _MmGridParentData).offset = Offset(
          rtl ? width - start - columns.width : start,
          top,
        );
      }
      top += rowHeight + spacing;
    }
    final height = rows.isEmpty ? 0.0 : top - spacing;
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final columns = _columnsFor(constraints.maxWidth);
    final height = _heightFor(
      columns,
      (child, width) =>
          child.getDryLayout(BoxConstraints.tightFor(width: width)).height,
    );
    return constraints.constrain(Size(_widthFor(constraints, columns), height));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var widest = 0.0;
    var child = firstChild;
    while (child != null) {
      widest = math.max(widest, child.getMinIntrinsicWidth(double.infinity));
      child = childAfter(child);
    }
    return widest;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (childCount == 0) return 0;
    var column = minItemWidth;
    var child = firstChild;
    while (child != null) {
      column = math.max(column, child.getMaxIntrinsicWidth(double.infinity));
      child = childAfter(child);
    }
    return childCount * column + spacing * (childCount - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(
    _columnsFor(width),
    (child, width) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(
    _columnsFor(width),
    (child, width) => child.getMaxIntrinsicHeight(width),
  );

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
