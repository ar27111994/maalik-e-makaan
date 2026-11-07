import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/layout/mm_focus_ring.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/foundation/mm_text_metrics.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Tabs that switch between the views of one screen ("Dues", "Payments",
/// "Documents" of a tenant).
///
/// The selected tab's label and the line under it are cobalt; the others
/// are muted ink, over a hairline rule. While every label fits, the tabs
/// share the width equally; when one does not (large text, long Urdu
/// words, many tabs, or no width limit at all) the bar scrolls sideways
/// instead, so no label is cut. The tabs grow taller with the text and are
/// at least 48 dp. Keyboard users reach them with Tab and choose one with
/// Enter or Space; the focused tab is ringed in the focus colour. Screen
/// readers hear "Payments, tab 2 of 3".
///
/// It works with the [DefaultTabController] above it, or with [controller],
/// and its [TabBarView] below it, at the top of an `MmPage`'s body with
/// `scrollable: false`. It is not an `AppBar.bottom`: its height follows
/// the text size, which a `PreferredSizeWidget` cannot know before it is
/// built. With reduced motion, give the controller
/// `animationDuration: MmMotion.of(context, MmDuration.standard)` so the
/// tabs switch without sliding. Don't use it for the app's main
/// destinations (use `MmAdaptiveScaffold`) or to filter a list (use
/// `MmFilterChips`).
///
/// ```dart
/// DefaultTabController(
///   length: 3,
///   child: Column(
///     children: [
///       const MmTabs(labels: ['Dues', 'Payments', 'Documents']),
///       Expanded(child: TabBarView(children: [dues, payments, documents])),
///     ],
///   ),
/// )
/// ```
class MmTabs extends StatelessWidget {
  /// Creates tabs labelled [labels].
  const new({required this.labels, this.controller, this.onTap, super.key});

  /// The tabs' labels, in order. As many as [controller] (or the
  /// [DefaultTabController]) has tabs.
  final List<String> labels;

  /// The controller of the selected tab, or null to use the
  /// [DefaultTabController] above.
  final TabController? controller;

  /// Called with a tab's index when it is tapped or activated from the
  /// keyboard, after the controller moves to it.
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    assert(labels.isNotEmpty, 'MmTabs needs at least one label');
    // The theme colours the bar: cobalt label and underline over a hairline
    // rule. The tabs are sized here, which a theme cannot do, so the labels
    // are set in the very style they are measured in.
    final style = Theme.of(context).textTheme.labelLarge;
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = 0.0;
        var height = 0.0;
        for (final text in labels) {
          final label = MmTextMetrics.of(context, text, style, maxLines: 1);
          width = math.max(width, label.size.width);
          height = math.max(height, label.size.height);
        }
        final scrollable =
            !constraints.hasBoundedWidth ||
            width + kTabLabelPadding.horizontal >
                constraints.maxWidth / labels.length;
        final tabHeight = math.max(MmSize.minTarget, height + 2 * MmSpace.s2);
        return TabBar(
          controller: controller,
          onTap: onTap,
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
          tabs: [
            for (final text in labels)
              Tab(
                height: tabHeight,
                child: _TabLabel(text, tabHeight: tabHeight),
              ),
          ],
          labelStyle: style,
          unselectedLabelStyle: style,
        );
      },
    );
  }
}

/// A tab's label, ringed while its tab has keyboard focus.
///
/// It sits inside the tab's ink well, so the nearest [Focus] is the tab's
/// own. The ring reaches [MmSpace.s3] past the label on each side (inside
/// the tab's own 16 dp padding) and stops [MmSpace.s1] short of the tab's
/// top and bottom, clear of the selected tab's underline.
class _TabLabel extends StatefulWidget {
  const new(this.text, {required this.tabHeight});

  final String text;

  /// The height of the tab the label is centred in.
  final double tabHeight;

  @override
  State<_TabLabel> createState() => _TabLabelState();
}

class _TabLabelState extends State<_TabLabel> with MmFocusHighlight<_TabLabel> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final node = Focus.maybeOf(context);
    final focused = showsFocusHighlights && (node?.hasPrimaryFocus ?? false);
    if (focused && !_focused) {
      // Keyboard focus only keeps a tab's trailing edge in view; a ring
      // half scrolled out of a scrolling bar would be no ring at all.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(node!));
    }
    _focused = focused;
    return CustomPaint(
      foregroundPainter: focused
          ? MmFocusRingPainter(
              color: context.mm.colors.focus,
              radius: MmRadius.sm,
              height: widget.tabHeight - 2 * MmSpace.s1,
              widthOutset: MmSpace.s3,
            )
          : null,
      // As a tab sets its own text: on one line, faded rather than wrapped
      // if the bar were ever too narrow.
      child: Text(widget.text, softWrap: false, overflow: TextOverflow.fade),
    );
  }

  /// Scrolls the whole of the tab whose focus is [node] (its ink well,
  /// ring included) into the bar's view, when the bar scrolls.
  void _reveal(FocusNode node) {
    final tab = node.context;
    if (!mounted || tab == null || Scrollable.maybeOf(tab) == null) return;
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    ]) {
      Scrollable.ensureVisible(tab, alignmentPolicy: policy);
    }
  }
}
