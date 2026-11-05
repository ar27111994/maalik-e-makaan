import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The places [MmRecordLine] lays its children out in.
enum MmRecordLineSlot {
  /// The child at the start edge: a label or a title.
  start,

  /// The child at the end edge: a value or a seal.
  end,
}

/// How [MmRecordLine] lines its children up when they sit side by side.
enum MmRecordLineAlignment {
  /// On their first baselines, as a label and its value on a raseed; at the
  /// top when either child has no baseline.
  baseline,

  /// At the top, as a receipt's issuer beside its seal.
  top,
}

/// A [start] child and an [end] child on one line, at the start and end
/// edges, when both fit at their natural widths. When they do not (a narrow
/// screen, large text) [end] moves under [start] so neither is squeezed,
/// and both wrap within the full width.
///
/// Internal to the records family: receipt rows, the receipt header and
/// meter labels reflow this way. It mirrors in right-to-left layouts.
class MmRecordLine
    extends SlottedMultiChildRenderObjectWidget<MmRecordLineSlot, RenderBox> {
  /// Lays out [start] and [end].
  const new({
    required this.start,
    required this.end,
    this.alignment = MmRecordLineAlignment.baseline,
    this.stackedAtEnd = false,
    super.key,
  });

  /// The space between the children when they sit side by side.
  static const double spacing = MmSpace.s4;

  /// The space between the children when [end] moves under [start].
  static const double runSpacing = MmSpace.s1;

  /// The child at the start edge.
  final Widget start;

  /// The child at the end edge, or under [start] when they do not fit.
  final Widget end;

  /// How the children line up when they sit side by side.
  final MmRecordLineAlignment alignment;

  /// Whether [end] keeps to the end edge when it moves under [start]
  /// (a seal); otherwise it moves to the start edge (a value under its
  /// label).
  final bool stackedAtEnd;

  @override
  Iterable<MmRecordLineSlot> get slots => MmRecordLineSlot.values;

  @override
  Widget childForSlot(MmRecordLineSlot slot) => switch (slot) {
    MmRecordLineSlot.start => start,
    MmRecordLineSlot.end => end,
  };

  @override
  RenderMmRecordLine createRenderObject(BuildContext context) =>
      RenderMmRecordLine(
        alignment: alignment,
        stackedAtEnd: stackedAtEnd,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMmRecordLine renderObject,
  ) {
    renderObject
      ..alignment = alignment
      ..stackedAtEnd = stackedAtEnd
      ..textDirection = Directionality.of(context);
  }
}

/// Where [RenderMmRecordLine] places its children for some constraints.
typedef _Arrangement = ({
  Size size,
  Offset start,
  Offset end,
  BoxConstraints startConstraints,
});

/// The render object of [MmRecordLine].
class RenderMmRecordLine extends RenderBox
    with SlottedContainerRenderObjectMixin<MmRecordLineSlot, RenderBox> {
  /// Creates the render object with [alignment] in [textDirection].
  new({
    required this._alignment,
    required this._stackedAtEnd,
    required this._textDirection,
  });

  /// How the children line up when they sit side by side.
  MmRecordLineAlignment get alignment => _alignment;
  MmRecordLineAlignment _alignment;
  set alignment(MmRecordLineAlignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  /// Whether the end child keeps to the end edge when it moves under the
  /// start child.
  bool get stackedAtEnd => _stackedAtEnd;
  bool _stackedAtEnd;
  set stackedAtEnd(bool value) {
    if (value == _stackedAtEnd) return;
    _stackedAtEnd = value;
    markNeedsLayout();
  }

  /// The direction that decides which edge is the start.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _start => childForSlot(MmRecordLineSlot.start)!;
  RenderBox get _end => childForSlot(MmRecordLineSlot.end)!;

  /// The children in reading order, which is also the order they are
  /// painted, hit-tested and read out in.
  @override
  Iterable<RenderBox> get children => [
    for (final slot in MmRecordLineSlot.values) ?childForSlot(slot),
  ];

  /// Works out where the children go within [constraints], laying them out
  /// for real or only measuring them ([dry]).
  _Arrangement _arrange(BoxConstraints constraints, {required bool dry}) {
    final layoutChild = dry
        ? ChildLayoutHelper.dryLayoutChild
        : ChildLayoutHelper.layoutChild;
    final baselineOf = dry
        ? ChildLayoutHelper.getDryBaseline
        : ChildLayoutHelper.getBaseline;
    final start = _start;
    final end = _end;
    final width = constraints.maxWidth;
    final startNatural = start.getMaxIntrinsicWidth(double.infinity);
    final endNatural = end.getMaxIntrinsicWidth(double.infinity);
    final sideBySide =
        startNatural + MmRecordLine.spacing + endNatural <= width;

    // The end child first: beside the start child it may use whatever the
    // start child does not need; under it, the whole width.
    final endConstraints = BoxConstraints(
      maxWidth: sideBySide
          ? width - MmRecordLine.spacing - startNatural
          : width,
    );
    final endSize = layoutChild(end, endConstraints);
    final startConstraints = BoxConstraints(
      maxWidth: sideBySide
          ? width - MmRecordLine.spacing - endSize.width
          : width,
    );
    final startSize = layoutChild(start, startConstraints);
    final boxWidth = constraints.constrainWidth(
      width.isFinite
          ? width
          : startSize.width + MmRecordLine.spacing + endSize.width,
    );

    var startTop = 0.0;
    var endTop = 0.0;
    if (!sideBySide) {
      endTop = startSize.height + MmRecordLine.runSpacing;
    } else if (alignment == MmRecordLineAlignment.baseline) {
      final startBaseline = baselineOf(
        start,
        startConstraints,
        TextBaseline.alphabetic,
      );
      final endBaseline = baselineOf(
        end,
        endConstraints,
        TextBaseline.alphabetic,
      );
      if (startBaseline != null && endBaseline != null) {
        final line = math.max(startBaseline, endBaseline);
        startTop = line - startBaseline;
        endTop = line - endBaseline;
      }
    }
    final height = math.max(
      startTop + startSize.height,
      endTop + endSize.height,
    );

    final rtl = textDirection == TextDirection.rtl;
    final endAtEnd = sideBySide || stackedAtEnd;
    return (
      size: constraints.constrain(Size(boxWidth, height)),
      start: Offset(rtl ? boxWidth - startSize.width : 0, startTop),
      end: Offset(endAtEnd == rtl ? 0 : boxWidth - endSize.width, endTop),
      startConstraints: startConstraints,
    );
  }

  @override
  void performLayout() {
    final arrangement = _arrange(constraints, dry: false);
    size = arrangement.size;
    (_start.parentData! as BoxParentData).offset = arrangement.start;
    (_end.parentData! as BoxParentData).offset = arrangement.end;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, dry: true).size;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final arrangement = _arrange(constraints, dry: true);
    final startBaseline = _start.getDryBaseline(
      arrangement.startConstraints,
      baseline,
    );
    return (BaselineOffset(startBaseline) + arrangement.start.dy).offset;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final start = _start;
    final offset = (start.parentData! as BoxParentData).offset;
    return (BaselineOffset(start.getDistanceToActualBaseline(baseline)) +
            offset.dy)
        .offset;
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _start.getMinIntrinsicWidth(double.infinity),
    _end.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _start.getMaxIntrinsicWidth(double.infinity) +
      MmRecordLine.spacing +
      _end.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      context.paintChild(child, offset + parentData.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final parentData = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: parentData.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
