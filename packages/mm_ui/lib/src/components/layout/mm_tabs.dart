import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Tabs that switch between the views of one screen ("Dues", "Payments",
/// "Documents" of a tenant).
///
/// The selected tab's label and the line under it are cobalt; the others
/// are muted ink, over a hairline rule. While every label fits, the tabs
/// share the width equally; when one does not (large text, long Urdu
/// words, many tabs) the bar scrolls sideways instead, so no label is cut.
/// The tabs grow taller with the text and are at least 48 dp. Keyboard
/// users reach them with Tab and choose one with Enter or Space; screen
/// readers hear "Payments, tab 2 of 3".
///
/// It works with the [DefaultTabController] above it, or with [controller],
/// and its [TabBarView] below it, inside an `MmPage` with
/// `scrollable: false`. Don't use it for the app's main destinations (use
/// `MmAdaptiveScaffold`) or to filter a list (use `MmFilterChips`).
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

  /// The thickness of the line under the selected tab.
  static const double indicatorWeight = 3;

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
    final colors = context.mm.colors;
    final style = Theme.of(context).textTheme.labelLarge;
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = _measure(context, style);
        final scrollable =
            label.width + kTabLabelPadding.horizontal >
            constraints.maxWidth / labels.length;
        return TabBar(
          controller: controller,
          onTap: onTap,
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
          tabs: [
            for (final text in labels)
              Tab(
                height: math.max(
                  MmSize.minTarget,
                  label.height + 2 * MmSpace.s2,
                ),
                text: text,
              ),
          ],
          labelStyle: style,
          unselectedLabelStyle: style,
          labelColor: colors.primary,
          unselectedLabelColor: colors.inkMuted,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: colors.primary,
              width: indicatorWeight,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(indicatorWeight),
            ),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: colors.rule,
          dividerHeight: MmSize.hairline,
        );
      },
    );
  }

  /// The size of the widest and of the tallest label, as the tabs will set
  /// them.
  Size _measure(BuildContext context, TextStyle? style) {
    var width = 0.0;
    var height = 0.0;
    for (final text in labels) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
      painter.dispose();
    }
    return Size(width, height);
  }
}
