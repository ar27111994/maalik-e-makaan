import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
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
/// does not rest on colour alone. Labels wrap inside their segments when
/// space runs short; when even wrapped labels cannot fit (long words at
/// large text sizes on a narrow phone), the control scrolls sideways and
/// keeps the selected option in view.
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
///   onChanged: (value) => setState(() => period = value),
/// )
/// ```
class MmSegmentedControl<T> extends StatefulWidget {
  /// Creates a control choosing one of [segments], with [selected] chosen.
  const new({
    required this.segments,
    required this.selected,
    required this.onChanged,
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

  @override
  State<MmSegmentedControl<T>> createState() => _MmSegmentedControlState<T>();
}

class _MmSegmentedControlState<T> extends State<MmSegmentedControl<T>> {
  final _scroll = ScrollController();

  /// The key of the [SegmentedButton], to measure its segments.
  final GlobalKey _buttonKey = GlobalKey();

  /// One key per segment label, to find the selected one on screen.
  late List<GlobalKey> _labelKeys;

  /// The segments handed to [SegmentedButton], kept while [widget]'s
  /// segments stay equal so it keeps each segment's hover and focus state.
  late List<ButtonSegment<T>> _segments;

  @override
  void initState() {
    super.initState();
    _buildSegments();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(MmSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final segmentsChanged = !listEquals(oldWidget.segments, widget.segments);
    if (segmentsChanged) _buildSegments();
    if (segmentsChanged || oldWidget.selected != widget.selected) {
      _revealSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _buildSegments() {
    _labelKeys = [for (final _ in widget.segments) GlobalKey()];
    _segments = [
      for (final (index, segment) in widget.segments.indexed)
        ButtonSegment<T>(
          value: segment.value,
          icon: segment.icon == null ? null : Icon(segment.icon),
          label: _SegmentLabel(segment.label, key: _labelKeys[index]),
        ),
    ];
  }

  /// After the next layout, scrolls the least distance that shows the whole
  /// selected segment: nothing moves while it is in view.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.segments.indexWhere(
        (segment) => segment.value == widget.selected,
      );
      final label = index < 0
          ? null
          : _labelKeys[index].currentContext?.findRenderObject();
      // No segment is selected, or the control has left the screen.
      if (label is! RenderBox) return;
      final control =
          _buttonKey.currentContext!.findRenderObject()! as RenderBox;
      // The segments share the control's width equally; the selected one is
      // the slot its label sits in (the whole segment, which can be wider
      // than its label).
      final width = control.size.width / widget.segments.length;
      final centre = label
          .localToGlobal(label.size.center(Offset.zero), ancestor: control)
          .dx;
      final segment = Rect.fromLTWH(
        (centre / width).floor() * width,
        0,
        width,
        control.size.height,
      );
      final viewport = RenderAbstractViewport.of(control);
      final atStart = viewport
          .getOffsetToReveal(control, 0, rect: segment)
          .offset;
      final atEnd = viewport
          .getOffsetToReveal(control, 1, rect: segment)
          .offset;
      final position = _scroll.position;
      unawaited(
        position.moveTo(
          math.min(math.max(position.pixels, atEnd), atStart),
          duration: animate
              ? MmMotion.of(context, MmDuration.standard)
              : Duration.zero,
          curve: MmEasing.standard,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    // The theme styles the segments: paper, the selected one cobalt-tonal
    // with a check mark, the field outline with a focus ring, muted ink
    // while disabled, and 48 dp tall.
    final button = SegmentedButton<T>(
      key: _buttonKey,
      segments: _segments,
      selected: {widget.selected},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged(selection.single),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        child: _WrapBeforeScrolling(
          viewportWidth: constraints.maxWidth,
          child: button,
        ),
      ),
    );
  }
}

/// A segment's label: centred, and wrapping when space runs short.
class _SegmentLabel extends StatelessWidget {
  const new(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Align(widthFactor: 1, child: Text(label, textAlign: TextAlign.center));
}

/// Lays its child out no wider than the viewport, so segment labels wrap
/// first; only when the child cannot fit even with every label wrapped
/// does it take its narrowest width, which the scroll view around it then
/// scrolls.
class _WrapBeforeScrolling extends SingleChildRenderObjectWidget {
  const new({required this.viewportWidth, required super.child});

  /// The width of the scroll view's viewport.
  final double viewportWidth;

  @override
  _RenderWrapBeforeScrolling createRenderObject(BuildContext context) =>
      _RenderWrapBeforeScrolling(viewportWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderWrapBeforeScrolling renderObject,
  ) => renderObject.viewportWidth = viewportWidth;
}

class _RenderWrapBeforeScrolling extends RenderProxyBox {
  new(this._viewportWidth);

  /// The width of the scroll view's viewport.
  double get viewportWidth => _viewportWidth;
  double _viewportWidth;

  set viewportWidth(double value) {
    if (value == _viewportWidth) return;
    _viewportWidth = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final narrowest = child!.getMinIntrinsicWidth(double.infinity);
    return constraints.copyWith(
      minWidth: 0,
      maxWidth: math.min(
        constraints.maxWidth,
        math.max(viewportWidth, narrowest),
      ),
    );
  }

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
