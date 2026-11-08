import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The places [MmReflow] lays its children out in.
enum MmReflowSlot {
  /// The text whose natural width decides the layout: a title or a label.
  start,

  /// An optional line under [start], such as a subtitle.
  below,

  /// The optional widget at the end edge: a value, a trailing amount, an
  /// action, a seal.
  end,
}

/// How [MmReflow] lines its end widget up with the text when the two sit
/// side by side.
enum MmReflowAlignment {
  /// Both are centred vertically (a list tile's trailing widget).
  center,

  /// The end widget sits on the first baseline of the start text (a value
  /// beside its label); centred when either has no baseline.
  baseline,

  /// Both hang from the top (a receipt's issuer beside its seal).
  top,
}

/// Lays out a [start] text, with an optional [below] line under it, and an
/// [end] widget side by side when [start] and [end] fit on one line at their
/// natural widths, and [below] can wrap beside [end] without breaking a word
/// (its narrowest width fits). When they do not (a narrow screen, large
/// text, a long email address under a name) [end] moves under the text so
/// neither is squeezed: at the start edge, or at the end edge when
/// [stackedAtEnd].
///
/// An [end] widget with inner space of its own at its edges (a text button's
/// padding) can hang past the edge it sits on by [endOverhang], so its
/// content lines up with the text instead of sitting that far inside it.
///
/// This is how a label and its value, a title and its trailing widget, and
/// a heading and its action reflow at 200% text. It mirrors in right-to-left
/// layouts, and reads, paints and hit-tests its children in reading order.
///
/// Internal to mm_ui: any component family may use it.
class MmReflow
    extends SlottedMultiChildRenderObjectWidget<MmReflowSlot, RenderBox> {
  /// Lays out [start], [below] and [end].
  const new({
    required this.start,
    this.below,
    this.end,
    this.alignment = MmReflowAlignment.center,
    this.stackedAtEnd = false,
    this.endOverhang = 0,
    super.key,
  }) : assert(endOverhang >= 0, 'endOverhang must not be negative');

  /// The space between the text and [end] when they sit side by side.
  static const double spacing = MmSpace.s4;

  /// The space between the text and [end] when [end] moves under it.
  static const double runSpacing = MmSpace.s1;

  /// The text whose natural width decides whether [end] fits beside it.
  final Widget start;

  /// An optional line under [start] that wraps within the text's width.
  final Widget? below;

  /// The widget at the end edge, or under the text when it does not fit.
  final Widget? end;

  /// How [end] lines up with the text when they sit side by side.
  final MmReflowAlignment alignment;

  /// Whether [end] keeps to the end edge when it moves under the text (a
  /// seal); otherwise it moves to the start edge (a value under its label).
  final bool stackedAtEnd;

  /// How far [end] hangs past the edge it sits on: past the end edge beside
  /// the text (or stacked at the end), past the start edge when it moves
  /// under the text. Pass the horizontal padding of a text button, so its
  /// label lines up with the text above or beside it. It never hangs so far
  /// that less than [MmSize.minTarget] of it stays inside, so a full touch
  /// target always does. The part that hangs out takes taps too where the
  /// widgets around the reflow reach that far (a page's padding around it
  /// does; a column between them, narrower than the padding, does not).
  final double endOverhang;

  @override
  Iterable<MmReflowSlot> get slots => MmReflowSlot.values;

  @override
  Widget? childForSlot(MmReflowSlot slot) => switch (slot) {
    MmReflowSlot.start => start,
    MmReflowSlot.below => below,
    MmReflowSlot.end => end,
  };

  @override
  RenderMmReflow createRenderObject(BuildContext context) => RenderMmReflow(
    alignment: alignment,
    stackedAtEnd: stackedAtEnd,
    endOverhang: endOverhang,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderMmReflow renderObject) {
    renderObject
      ..alignment = alignment
      ..stackedAtEnd = stackedAtEnd
      ..endOverhang = endOverhang
      ..textDirection = Directionality.of(context);
  }
}

/// Where [RenderMmReflow] places its children for some constraints.
typedef _Arrangement = ({
  Size size,
  Offset start,
  Offset below,
  Offset end,
  BoxConstraints textConstraints,
});

/// The render object of [MmReflow].
class RenderMmReflow extends RenderBox
    with SlottedContainerRenderObjectMixin<MmReflowSlot, RenderBox> {
  /// Creates the render object with [alignment] in [textDirection].
  new({
    required this._alignment,
    required this._textDirection,
    this._stackedAtEnd = false,
    this._endOverhang = 0,
  });

  /// How the end child lines up with the text when they sit side by side.
  MmReflowAlignment get alignment => _alignment;
  MmReflowAlignment _alignment;
  set alignment(MmReflowAlignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  /// Whether the end child keeps to the end edge when it moves under the
  /// text.
  bool get stackedAtEnd => _stackedAtEnd;
  bool _stackedAtEnd;
  set stackedAtEnd(bool value) {
    if (value == _stackedAtEnd) return;
    _stackedAtEnd = value;
    markNeedsLayout();
  }

  /// How far the end child may hang past the edge it sits on.
  double get endOverhang => _endOverhang;
  double _endOverhang;
  set endOverhang(double value) {
    if (value == _endOverhang) return;
    _endOverhang = value;
    markNeedsLayout();
  }

  /// How far an end child [width] wide hangs out: [endOverhang], but never
  /// so far that less than a touch target of it stays inside.
  double _overhangOf(double width) =>
      math.max(0, math.min(endOverhang, width - MmSize.minTarget));

  /// The direction that decides which edge is the start.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _start => childForSlot(MmReflowSlot.start)!;
  RenderBox? get _below => childForSlot(MmReflowSlot.below);
  RenderBox? get _end => childForSlot(MmReflowSlot.end);

  /// The children in reading order, which is also the order they are
  /// painted, hit-tested and read out in.
  @override
  Iterable<RenderBox> get children => [
    for (final slot in MmReflowSlot.values) ?childForSlot(slot),
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
    final below = _below;
    final end = _end;
    final width = constraints.maxWidth;
    final startNatural = start.getMaxIntrinsicWidth(double.infinity);
    // The line below wraps beside the end widget, but no narrower than its
    // longest word (an email address, an amount that never breaks).
    final belowNarrowest = below?.getMinIntrinsicWidth(double.infinity) ?? 0;
    final endNatural = end?.getMaxIntrinsicWidth(double.infinity);
    final sideBySide =
        endNatural != null &&
        math.max(startNatural, belowNarrowest) +
                MmReflow.spacing +
                endNatural -
                _overhangOf(endNatural) <=
            width;

    // The end widget first: beside the text it may use whatever the text
    // does not need; under the text it has the whole width. Either way it
    // may also take the space it hangs out into.
    final endConstraints = BoxConstraints(
      maxWidth:
          (sideBySide ? width - MmReflow.spacing - startNatural : width) +
          endOverhang,
    );
    final endSize = end == null ? Size.zero : layoutChild(end, endConstraints);
    final overhang = _overhangOf(endSize.width);
    final inside = endSize.width - overhang;
    final textConstraints = BoxConstraints(
      maxWidth: sideBySide ? width - MmReflow.spacing - inside : width,
    );
    final startSize = layoutChild(start, textConstraints);
    final belowSize = below == null
        ? Size.zero
        : layoutChild(below, textConstraints);
    final textHeight = startSize.height + belowSize.height;
    final boxWidth = constraints.constrainWidth(
      width.isFinite
          ? width
          : math.max(startSize.width, belowSize.width) +
                (end == null ? 0 : MmReflow.spacing + inside),
    );

    var textTop = 0.0;
    var endTop = 0.0;
    final double height;
    if (end == null) {
      height = textHeight;
    } else if (!sideBySide) {
      endTop = textHeight + MmReflow.runSpacing;
      height = endTop + endSize.height;
    } else {
      final startBaseline = alignment == MmReflowAlignment.baseline
          ? baselineOf(start, textConstraints, TextBaseline.alphabetic)
          : null;
      final endBaseline = startBaseline == null
          ? null
          : baselineOf(end, endConstraints, TextBaseline.alphabetic);
      if (startBaseline != null && endBaseline != null) {
        final line = math.max(startBaseline, endBaseline);
        textTop = line - startBaseline;
        endTop = line - endBaseline;
      } else if (alignment != MmReflowAlignment.top) {
        final tallest = math.max(textHeight, endSize.height);
        textTop = (tallest - textHeight) / 2;
        endTop = (tallest - endSize.height) / 2;
      }
      height = math.max(textTop + textHeight, endTop + endSize.height);
    }

    final rtl = textDirection == TextDirection.rtl;
    final endAtEnd = sideBySide || stackedAtEnd;
    double atStart(double childWidth) => rtl ? boxWidth - childWidth : 0;
    return (
      size: constraints.constrain(Size(boxWidth, height)),
      start: Offset(atStart(startSize.width), textTop),
      below: Offset(atStart(belowSize.width), textTop + startSize.height),
      end: Offset(endAtEnd == rtl ? -overhang : boxWidth - inside, endTop),
      textConstraints: textConstraints,
    );
  }

  @override
  void performLayout() {
    final arrangement = _arrange(constraints, dry: false);
    size = arrangement.size;
    _place(_start, arrangement.start);
    _place(_below, arrangement.below);
    _place(_end, arrangement.end);
  }

  static void _place(RenderBox? child, Offset offset) {
    if (child == null) return;
    (child.parentData! as BoxParentData).offset = offset;
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
      arrangement.textConstraints,
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
  double computeMinIntrinsicWidth(double height) => children.fold(
    0,
    (widest, child) =>
        math.max(widest, child.getMinIntrinsicWidth(double.infinity)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final text = math.max(
      _start.getMaxIntrinsicWidth(double.infinity),
      _below?.getMaxIntrinsicWidth(double.infinity) ?? 0,
    );
    final end = _end;
    if (end == null) return text;
    final endWidth = end.getMaxIntrinsicWidth(double.infinity);
    return text + MmReflow.spacing + endWidth - _overhangOf(endWidth);
  }

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

  /// Takes taps on the part of the end child that hangs past the box, as
  /// well as inside it.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final reach = Rect.fromLTRB(
      -endOverhang,
      0,
      size.width + endOverhang,
      size.height,
    );
    if (!reach.contains(position)) return false;
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
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
