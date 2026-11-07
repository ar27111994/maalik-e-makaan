import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/components/actions/mm_action_icon.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/foundation/mm_text_metrics.dart';
import 'package:mm_ui/src/icons/mm_icons.g.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One option of an [MmSegmentedControl].
@immutable
class MmSegment<T> {
  /// Creates an option for [value], shown as [label] and optionally [icon].
  const new({required this.value, required this.label, this.icon});

  /// The value the control reports when this option is chosen.
  final T value;

  /// The option's name ("Monthly"), from the app's localisations.
  final String label;

  /// An icon shown before the label. A check mark replaces it while the
  /// option is selected.
  final IconData? icon;

  @override
  bool operator ==(Object other) =>
      other is MmSegment<T> &&
      other.value == value &&
      other.label == label &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(value, label, icon);
}

/// A row of two to five mutually exclusive options, one always selected:
/// the period of a report, a payment method, a list's filter.
///
/// The selected option is filled and carries a check mark, so the choice
/// does not rest on colour alone. Every segment is at least 48 dp tall and
/// grows with its label. Labels wrap inside their segments when space runs
/// short; when the options cannot sit side by side without breaking a word
/// (long words at large text sizes on a narrow phone), they stack, one per
/// line and as wide as the control may be, so every option stays in view.
/// The segment with keyboard focus is ringed in the focus colour.
///
/// The control is as wide as its labels need, or as wide as its parent
/// with [expand]. Give it a [semanticLabel] that names the choice ("Report
/// period") when nothing next to it does.
///
/// Use it to switch between views of the same content or to pick one value
/// of a short list. For more than five options, or options that need
/// explaining, use a radio group or a select field; to trigger actions, use
/// buttons.
///
/// ```dart
/// MmSegmentedControl<ReportPeriod>(
///   segments: [
///     MmSegment(value: ReportPeriod.month, label: l10n.monthly),
///     MmSegment(value: ReportPeriod.quarter, label: l10n.quarterly),
///     MmSegment(value: ReportPeriod.year, label: l10n.yearly),
///   ],
///   selected: period,
///   semanticLabel: l10n.reportPeriod,
///   onChanged: (value) => setState(() => period = value),
/// )
/// ```
class MmSegmentedControl<T> extends StatefulWidget {
  /// Creates a control choosing one of [segments], with [selected] chosen.
  const new({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.semanticLabel,
    super.key,
  });

  /// The options, in reading order.
  final List<MmSegment<T>> segments;

  /// The value of the selected option. When it matches no option, none is
  /// shown selected.
  final T selected;

  /// Called with the value of the option the user chooses (never with the
  /// value already selected). When null the control is disabled.
  final ValueChanged<T>? onChanged;

  /// Whether the control fills the width of its parent, which must be
  /// bounded, sharing it equally between the segments. Otherwise it is as
  /// wide as its labels need. Stacked segments always fill it.
  final bool expand;

  /// What the choice is about ("Report period"), announced by screen
  /// readers before the options. Leave it null when a visible heading or
  /// label next to the control already says so.
  final String? semanticLabel;

  @override
  State<MmSegmentedControl<T>> createState() => _MmSegmentedControlState<T>();
}

class _MmSegmentedControlState<T> extends State<MmSegmentedControl<T>>
    with MmFocusHighlight<MmSegmentedControl<T>> {
  /// One key per segment label. A label sits inside its segment's button,
  /// so the focus node nearest above it is the segment's.
  late List<GlobalKey> _labelKeys;

  /// The segments handed to [SegmentedButton], kept while [widget]'s
  /// segments stay equal so it keeps each segment's hover and focus state.
  late List<ButtonSegment<T>> _segments;

  /// The index of the segment with the primary focus, if any.
  int? _focused;

  @override
  void initState() {
    super.initState();
    _buildSegments();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(MmSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.segments, widget.segments)) _buildSegments();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _buildSegments() {
    _labelKeys = [for (final _ in widget.segments) GlobalKey()];
    _segments = [
      for (final (index, segment) in widget.segments.indexed)
        ButtonSegment<T>(
          value: segment.value,
          // The label draws the segment's icon itself (see _SegmentLabel),
          // so Material keeps the control's padding for every segment.
          label: _SegmentLabel<T>(segment, key: _labelKeys[index]),
        ),
    ];
  }

  /// Notes which segment has the primary focus, to ring it.
  void _handleFocusChange() {
    final index = _labelKeys.indexWhere((key) {
      final label = key.currentContext;
      return label != null &&
          Focus.of(label, createDependency: false).hasPrimaryFocus;
    });
    final focused = index < 0 ? null : index;
    if (focused != _focused) setState(() => _focused = focused);
  }

  /// The narrowest the segments can sit side by side without breaking a
  /// word: Material gives every segment the width of the widest, and each
  /// needs its label's longest word beside an icon (any segment may show
  /// the check mark) inside [padding] (the sides of a segment), and no less
  /// than a text button's minimum width. It does not depend on which
  /// segment is selected, so choosing one never restacks the control.
  double _narrowestRow(
    BuildContext context,
    ButtonStyle style,
    double padding,
  ) {
    final textScaler = MediaQuery.textScalerOf(context);
    final base = style.textStyle!.resolve(const {})!;
    // Text sets its words in bold when the platform asks for bold text.
    final textStyle = MediaQuery.boldTextOf(context)
        ? base.merge(const TextStyle(fontWeight: FontWeight.bold))
        : base;
    final icon = MmActionIcon.grown(
      style.iconSize!.resolve(const {})!,
      textScaler: textScaler,
      fontSize: textStyle.fontSize!,
    );
    var widest =
        const TextButton(
          onPressed: null,
          child: SizedBox.shrink(),
        ).defaultStyleOf(context).minimumSize?.resolve(const {})?.width ??
        0;
    for (final segment in widget.segments) {
      final label = MmTextMetrics.of(
        context,
        segment.label,
        textStyle,
        textScaler: textScaler,
      );
      widest = math.max(
        widest,
        padding + icon + _SegmentLabel.iconGap + label.minIntrinsicWidth,
      );
    }
    return widest * widget.segments.length;
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final direction = Directionality.of(context);
    final focus = context.mm.colors.focus;
    // MmTheme styles the segments: the label style and icon size, paper,
    // the selected one cobalt-tonal, the field outline, and muted ink while
    // disabled.
    final style = SegmentedButtonTheme.of(context).style!;
    final themeSide = style.side!;
    // The theme's vertical padding, which makes segments 48 dp tall, and
    // narrower sides than the theme's, so that a check mark fits beside the
    // longest of three everyday labels ("Quarterly") side by side on a
    // 360 dp phone.
    final padding = EdgeInsetsDirectional.symmetric(
      horizontal: MmSpace.s2,
      vertical: style.padding!.resolve(const {})!.vertical / 2,
    );
    final control = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stacked =
            _narrowestRow(context, style, padding.horizontal) > width;
        final count = widget.segments.length;
        final focused = _focused;
        // The theme rings the whole control while one of its segments has
        // focus, which says nothing about which one; this control keeps the
        // resting outline and rings the focused segment instead.
        final Widget button = CustomPaint(
          foregroundPainter:
              showsFocusHighlights && focused != null && focused < count
              ? _SegmentFocusPainter(
                  slot: !stacked && direction == TextDirection.rtl
                      ? count - 1 - focused
                      : focused,
                  count: count,
                  axis: stacked ? Axis.vertical : Axis.horizontal,
                  color: focus,
                )
              : null,
          child: SegmentedButton<T>(
            segments: _segments,
            selected: {widget.selected},
            // The labels draw the check mark (see _SegmentLabel).
            showSelectedIcon: false,
            direction: stacked ? Axis.vertical : Axis.horizontal,
            style: ButtonStyle(
              padding: WidgetStatePropertyAll(padding),
              side: WidgetStateProperty.resolveWith(
                (states) => themeSide.resolve(
                  states.difference(const {WidgetState.focused}),
                ),
              ),
            ),
            onSelectionChanged: onChanged == null
                ? null
                : (selection) => onChanged(selection.single),
          ),
        );
        return _SegmentScope<T>(
          selected: widget.selected,
          labelWidth: stacked ? width - padding.horizontal : null,
          direction: direction,
          // Material stacks segments bottom up in right-to-left layouts;
          // laid out left to right, the first is on top in both languages.
          // The labels keep the control's own direction.
          child: switch ((stacked, widget.expand)) {
            (true, _) => Directionality(
              textDirection: TextDirection.ltr,
              child: button,
            ),
            // Material shares a tight width equally between the segments.
            // (Its expandedInsets would do the same, but its render object
            // keeps the first value it was given.)
            (false, true) => SizedBox(width: width, child: button),
            (false, false) => button,
          },
        );
      },
    );
    final label = widget.semanticLabel;
    if (label == null) return control;
    return Semantics(container: true, label: label, child: control);
  }
}

/// What a segment's label needs from its control: the selection (for the
/// check mark), the width of stacked labels and the control's direction.
class _SegmentScope<T> extends InheritedWidget {
  const new({
    required this.selected,
    required this.labelWidth,
    required this.direction,
    required super.child,
  });

  /// The control's selected value.
  final T selected;

  /// The width every label takes while the segments are stacked; null
  /// while they sit side by side.
  final double? labelWidth;

  /// The control's text direction, which its labels keep.
  final TextDirection direction;

  static _SegmentScope<T> of<T>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SegmentScope<T>>()!;

  @override
  bool updateShouldNotify(_SegmentScope<T> oldWidget) =>
      selected != oldWidget.selected ||
      labelWidth != oldWidget.labelWidth ||
      direction != oldWidget.direction;
}

/// A segment's label: its icon, or the check mark while it is selected,
/// before its centred words, which wrap when space runs short.
///
/// Material replaces the padding of any segment it gives an icon (40 dp
/// tall at most, however large the text), so the label draws the icon
/// itself and every segment keeps the control's padding: 48 dp tall, and
/// taller with the text.
class _SegmentLabel<T> extends StatelessWidget {
  const new(this.segment, {super.key});

  final MmSegment<T> segment;

  /// The space between the icon and the words.
  static const double iconGap = MmSpace.s2;

  @override
  Widget build(BuildContext context) {
    final scope = _SegmentScope.of<T>(context);
    final icon = scope.selected == segment.value ? MmIcons.check : segment.icon;
    // As wide as its longest line, so a wrapped label stays by its icon.
    Widget label = Text(
      segment.label,
      textAlign: TextAlign.center,
      textWidthBasis: TextWidthBasis.longestLine,
    );
    if (icon != null) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: iconGap,
        children: [
          MmActionIcon(icon),
          Flexible(child: label),
        ],
      );
    }
    final width = scope.labelWidth;
    if (width == null) return label;
    return Directionality(
      textDirection: scope.direction,
      child: _FixedWidth(
        width: width,
        child: Center(heightFactor: 1, child: label),
      ),
    );
  }
}

/// A stacked segment's label, as wide as the control's content.
///
/// Material sizes stacked segments by their labels' unwrapped width and
/// one-line height. This label reports its fixed width instead, and its
/// height at that width, so stacked labels wrap inside the control and
/// every segment is as tall as the tallest wrapped label.
class _FixedWidth extends SingleChildRenderObjectWidget {
  const new({required this.width, required super.child});

  final double width;

  @override
  _RenderFixedWidth createRenderObject(BuildContext context) =>
      _RenderFixedWidth(width);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFixedWidth renderObject,
  ) => renderObject.width = width;
}

class _RenderFixedWidth extends RenderProxyBox {
  new(this._width);

  double get width => _width;
  double _width;

  set width(double value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => width;

  @override
  double computeMaxIntrinsicWidth(double height) => width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(this.width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(this.width);

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: width).enforce(constraints);

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    child!.getDryLayout(_childConstraints(constraints)),
  );

  @override
  void performLayout() {
    child!.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(child!.size);
  }
}

/// The keyboard focus ring of one segment: [MmSize.focusRing] wide in the
/// focus colour, over the control's outline and the dividers around the
/// segment, so the ring frames exactly the segment that Enter would choose.
class _SegmentFocusPainter extends CustomPainter {
  const new({
    required this.slot,
    required this.count,
    required this.axis,
    required this.color,
  });

  /// The focused segment's place along [axis], from the left or the top.
  final int slot;

  /// How many segments share the control.
  final int count;

  /// The direction the segments run in.
  final Axis axis;

  /// The colour of the ring.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const ring = MmSize.focusRing;
    const half = ring / 2;
    final across = axis == Axis.horizontal;
    final first = slot == 0;
    final last = slot == count - 1;
    final length = (across ? size.width : size.height) / count;
    // Along the control the ring is centred on the dividers between
    // segments, and inside the control's own edge, where its outline lies.
    final start = slot * length + (first ? half : 0);
    final end = (slot + 1) * length - (last ? half : 0);
    final rect = across
        ? Rect.fromLTRB(start, half, end, size.height - half)
        : Rect.fromLTRB(half, start, size.width - half, end);
    // Rounded only at the control's corners (the theme's segmented shape),
    // concentric with them.
    const corner = Radius.circular(MmRadius.sm - half);
    final startCorner = first ? corner : Radius.zero;
    final endCorner = last ? corner : Radius.zero;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: startCorner,
        topRight: across ? endCorner : startCorner,
        bottomLeft: across ? startCorner : endCorner,
        bottomRight: endCorner,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SegmentFocusPainter oldDelegate) =>
      slot != oldDelegate.slot ||
      count != oldDelegate.count ||
      axis != oldDelegate.axis ||
      color != oldDelegate.color;
}
