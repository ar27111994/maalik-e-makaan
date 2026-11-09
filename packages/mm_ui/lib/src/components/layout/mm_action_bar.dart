import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/foundation/mm_window.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// The bar at the bottom of a screen that holds its main action ("Record
/// payment") and optionally one alternative ("Save draft"), within thumb
/// reach.
///
/// It is a strip of surface paper under a hairline rule, padded 16 dp, that
/// keeps clear of the device's safe area. On a phone (`MmWindowSize.compact`)
/// the buttons fill the width: side by side in equal halves when both
/// labels fit, otherwise stacked full width with [primary] at the bottom
/// (large text, narrow phones). On wider windows they keep their natural
/// widths at the end edge of the 720 dp reading column. [secondary] always
/// comes first in reading and focus order, so [primary] sits at the end in
/// a row and at the bottom in a stack, mirrored in Urdu.
///
/// Pass it as `MmPage.bottomBar` (or a `Scaffold`'s `bottomNavigationBar`)
/// and it rises above the on-screen keyboard while a field is being typed
/// in. As a `Scaffold`'s `bottomSheet` the scaffold lifts it already, unless
/// the scaffold does not resize for the keyboard, in which case the bar
/// does. Pass the bar itself to those slots, not wrapped in another widget:
/// that is how it knows where it is. Anywhere else (a scaffold's body, a
/// modal sheet) the parent makes room for the keyboard.
///
/// Give it a `FilledButton` as [primary] and an `OutlinedButton` or
/// `TextButton` as [secondary]; a null `onPressed` shows a button disabled.
/// Don't put more than two actions in it (move the rest into the app bar's
/// menu), and don't use it for navigation (use `MmAdaptiveScaffold`).
///
/// ```dart
/// MmActionBar(
///   secondary: OutlinedButton(
///     onPressed: saveDraft,
///     child: const Text('Save draft'),
///   ),
///   primary: FilledButton(
///     onPressed: canSave ? recordPayment : null,
///     child: const Text('Record payment'),
///   ),
/// )
/// ```
class MmActionBar extends StatelessWidget {
  /// Creates a bar holding [primary] and, optionally, [secondary].
  const new({required this.primary, this.secondary, super.key});

  /// The space between the two buttons, in a row or a stack.
  static const double spacing = MmSpace.s3;

  /// The screen's main action, usually a `FilledButton`.
  final Widget primary;

  /// An alternative to [primary], usually an `OutlinedButton`, or null.
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    final safeArea = MediaQuery.paddingOf(context);
    final secondary = this.secondary;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        // The default width of a side is the hairline.
        border: Border(top: BorderSide(color: colors.rule)),
      ),
      // Safe-area insets are physical (the device's own left and right).
      // design-lint: allow-next-line physical safe-area insets
      padding: EdgeInsets.fromLTRB(
        safeArea.left + MmSpace.s4,
        MmSpace.s4,
        safeArea.right + MmSpace.s4,
        math.max(safeArea.bottom, _keyboardInset(context)) + MmSpace.s4,
      ),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MmSize.contentMax),
          child: _MmActionBarButtons(
            fill: MmWindowSize.of(context) == MmWindowSize.compact,
            textDirection: Directionality.of(context),
            children: [?secondary, primary],
          ),
        ),
      ),
    );
  }

  /// How far the bar must lift itself to stay above the on-screen keyboard.
  ///
  /// A `Scaffold` never lifts its bottom navigation bar, and lifts its
  /// bottom sheet only when it resizes for the keyboard. Anywhere else (a
  /// scaffold's body, a modal sheet) the parent has made room already.
  double _keyboardInset(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context)?.widget;
    if (scaffold == null) return 0;
    final lifted = scaffold.resizeToAvoidBottomInset ?? true;
    if (identical(scaffold.bottomNavigationBar, this) ||
        (identical(scaffold.bottomSheet, this) && !lifted)) {
      return MediaQuery.viewInsetsOf(context).bottom;
    }
    return 0;
  }
}

/// Lays out the bar's buttons in a row when they fit, else in a stack.
class _MmActionBarButtons extends MultiChildRenderObjectWidget {
  const new({
    required this.fill,
    required this.textDirection,
    required super.children,
  });

  /// Whether the buttons share the whole width (phones) rather than keep
  /// their natural widths at the end edge.
  final bool fill;

  final TextDirection textDirection;

  @override
  _RenderMmActionBarButtons createRenderObject(BuildContext context) =>
      _RenderMmActionBarButtons(fill: fill, textDirection: textDirection);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMmActionBarButtons renderObject,
  ) {
    renderObject
      ..fill = fill
      ..textDirection = textDirection;
  }
}

class _ButtonParentData extends ContainerBoxParentData<RenderBox>;

/// Where the buttons go within some constraints.
typedef _Arrangement = ({
  Size size,
  bool inRow,
  List<double> widths,
  double rowHeight,
});

class _RenderMmActionBarButtons extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ButtonParentData> {
  new({required this._fill, required this._textDirection});

  bool get fill => _fill;
  bool _fill;
  set fill(bool value) {
    if (value == _fill) return;
    _fill = value;
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
    if (child.parentData is! _ButtonParentData) {
      child.parentData = _ButtonParentData();
    }
  }

  List<RenderBox> get _buttons {
    final buttons = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      buttons.add(child);
      child = childAfter(child);
    }
    return buttons;
  }

  /// Decides between a row and a stack and sizes the buttons for it,
  /// measuring them for real or only for size ([dry]).
  _Arrangement _arrange(BoxConstraints constraints, {required bool dry}) {
    final layoutChild = dry
        ? ChildLayoutHelper.dryLayoutChild
        : ChildLayoutHelper.layoutChild;
    final buttons = _buttons;
    final available = constraints.maxWidth;
    final gaps = MmActionBar.spacing * math.max(0, buttons.length - 1);
    final natural = [
      for (final button in buttons)
        button.getMaxIntrinsicWidth(double.infinity),
    ];
    final naturalRow = natural.fold(gaps, (sum, width) => sum + width);

    final bool inRow;
    final List<double> widths;
    if (!available.isFinite) {
      inRow = true;
      widths = natural;
    } else if (fill) {
      final share = (available - gaps) / math.max(1, buttons.length);
      inRow = natural.every((width) => width <= share);
      widths = [
        for (final _ in buttons)
          if (inRow) share else available,
      ];
    } else {
      inRow = naturalRow <= available;
      widths = inRow ? natural : [for (final _ in buttons) available];
    }

    final heights = [
      for (final (index, button) in buttons.indexed)
        layoutChild(
          button,
          BoxConstraints.tightFor(width: widths[index]),
        ).height,
    ];
    final double width;
    final double height;
    var rowHeight = 0.0;
    if (inRow) {
      rowHeight = heights.reduce(math.max);
      width = available.isFinite ? available : naturalRow;
      height = rowHeight;
    } else {
      width = available;
      height = heights.fold(gaps, (sum, height) => sum + height);
    }
    return (
      size: constraints.constrain(Size(width, height)),
      inRow: inRow,
      widths: widths,
      rowHeight: rowHeight,
    );
  }

  @override
  void performLayout() {
    final arrangement = _arrange(constraints, dry: false);
    size = arrangement.size;
    final buttons = _buttons;
    if (!arrangement.inRow) {
      var top = 0.0;
      for (final button in buttons) {
        (button.parentData! as _ButtonParentData).offset = Offset(0, top);
        top += button.size.height + MmActionBar.spacing;
      }
      return;
    }
    // In a row the buttons share one height and end at the end edge, the
    // first (secondary) at the start.
    final widths = arrangement.widths;
    final rowWidth = widths.fold(
      MmActionBar.spacing * (buttons.length - 1),
      (sum, width) => sum + width,
    );
    final rtl = textDirection == TextDirection.rtl;
    var start = rtl ? 0.0 : size.width - rowWidth;
    for (final (index, button) in buttons.indexed) {
      if (button.size.height < arrangement.rowHeight) {
        button.layout(
          BoxConstraints.tightFor(
            width: widths[index],
            height: arrangement.rowHeight,
          ),
          parentUsesSize: true,
        );
      }
      final left = rtl ? rowWidth - start - widths[index] : start;
      (button.parentData! as _ButtonParentData).offset = Offset(left, 0);
      start += widths[index] + MmActionBar.spacing;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, dry: true).size;

  @override
  double computeMinIntrinsicWidth(double height) => _buttons.fold<double>(
    0,
    (widest, button) =>
        math.max(widest, button.getMinIntrinsicWidth(double.infinity)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => _buttons.fold(
    MmActionBar.spacing * math.max(0, childCount - 1),
    (sum, button) => sum + button.getMaxIntrinsicWidth(double.infinity),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
