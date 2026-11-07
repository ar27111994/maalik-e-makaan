import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/layout/mm_focus_ring.dart';
import 'package:mm_ui/src/components/layout/mm_text_metrics.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/foundation/mm_window.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// One place the app's main navigation leads to: its icon, its label and an
/// optional count of things waiting there.
///
/// ```dart
/// const MmDestination(
///   icon: MmIcons.receipt,
///   label: 'Dues',
///   badgeCount: 3,
/// )
/// ```
@immutable
final class MmDestination {
  /// Creates a destination labelled [label] with [icon].
  const new({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount,
  }) : assert(
         badgeCount == null || badgeCount >= 0,
         'badgeCount must not be negative',
       );

  /// The icon shown while the destination is not selected, and while it is
  /// selected when [selectedIcon] is null.
  final IconData icon;

  /// The icon shown while the destination is selected (a filled variant of
  /// [icon]), or null to keep [icon].
  final IconData? selectedIcon;

  /// The destination's name ("Properties", "Tenants"), shown under or beside
  /// the icon and read by screen readers.
  final String label;

  /// How many things wait at the destination (overdue dues, unread
  /// requests), shown as a badge on the icon and read after the label. Null
  /// or zero shows no badge; counts over 999 show "999+" but are read in
  /// full.
  final int? badgeCount;

  @override
  bool operator ==(Object other) =>
      other is MmDestination &&
      other.icon == icon &&
      other.selectedIcon == selectedIcon &&
      other.label == label &&
      other.badgeCount == badgeCount;

  @override
  int get hashCode => Object.hash(icon, selectedIcon, label, badgeCount);
}

/// The app's top-level frame: its main destinations and the screen of the
/// selected one, laid out for the window it is shown in.
///
/// By `MmWindowSize`:
///
/// * **compact** (phones): [body] above a bottom [NavigationBar], so the
///   destinations sit within thumb reach. The bar grows taller with large
///   text and with Nastaliq labels, so no label is clipped.
/// * **medium** and **expanded**: a [NavigationRail] at the start edge with
///   every label shown under its icon, a hairline rule, then [body].
/// * **large** (desktop web): the rail extended, labels beside the icons.
///
/// Everything mirrors in right-to-left layouts (the rail sits on the right in
/// Urdu). [body] keeps its state when the window changes size class, for
/// example when a tablet rotates. Keyboard users reach the destinations
/// with Tab and select one with Enter or Space; the focused destination is
/// ringed in the focus colour. Screen readers hear each as a tab
/// ("Tenants, tab 2 of 4") with its badge count.
///
/// [body] gets a `ScaffoldMessenger` of its own, so a snack bar shown from
/// inside it (`ScaffoldMessenger.of(context)`, `showMmSnackbar`) appears on
/// the screen's own `Scaffold`, above the screen's bottom bar rather than
/// over it. The screen must therefore be (or hold) a `Scaffold`: an
/// `MmPage` is one. A screen that shows snack bars and has a floating
/// action button should pass the button to its `MmPage`, where the two
/// make room for each other, rather than to [floatingActionButton].
///
/// Use it once, at the root of the signed-in app; screens inside it are
/// `MmPage`s. Don't use it for a single screen's sections (use `MmTabs`) or
/// for fewer than two destinations.
///
/// ```dart
/// MmAdaptiveScaffold(
///   destinations: const [
///     MmDestination(icon: MmIcons.property, label: 'Properties'),
///     MmDestination(icon: MmIcons.tenants, label: 'Tenants'),
///     MmDestination(icon: MmIcons.receipt, label: 'Dues', badgeCount: 3),
///   ],
///   selectedIndex: tab,
///   onDestinationSelected: (index) => setState(() => tab = index),
///   body: screens[tab],
/// )
/// ```
class MmAdaptiveScaffold extends StatefulWidget {
  /// Creates the frame around [body] with [destinations].
  const new({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.floatingActionButton,
    super.key,
  });

  /// The app's main destinations, in order. At least two.
  final List<MmDestination> destinations;

  /// The index in [destinations] of the destination [body] shows.
  final int selectedIndex;

  /// Called with a destination's index when it is tapped or activated from
  /// the keyboard. The app switches [body] and [selectedIndex].
  final ValueChanged<int> onDestinationSelected;

  /// The screen of the selected destination: an `MmPage`, or another
  /// widget holding a `Scaffold`.
  final Widget body;

  /// The selected screen's main action, if it has one, floating at the
  /// bottom end of the window. Prefer `MmPage.floatingActionButton` on a
  /// screen that shows snack bars (see the class comment).
  final Widget? floatingActionButton;

  @override
  State<MmAdaptiveScaffold> createState() => _MmAdaptiveScaffoldState();
}

/// The size of Material 3's selection indicator behind a bar destination's
/// icon.
const Size _barIndicator = Size(64, 32);

/// The size of Material 3's selection indicator behind a rail
/// destination's icon.
const Size _railIndicator = Size(56, 32);

/// The most a bar label grows with the text, as [NavigationBar] sets it.
const double _maxBarLabelTextScale = 1.3;

/// The height of [NavigationBar] the theme asks for when its labels fit.
const double _defaultBarHeight = 72;

class _MmAdaptiveScaffoldState extends State<MmAdaptiveScaffold> {
  /// Keeps the body's state when it moves between the layouts.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'MmAdaptiveScaffold.body');

  @override
  Widget build(BuildContext context) {
    assert(
      widget.destinations.length >= 2,
      'MmAdaptiveScaffold needs at least two destinations',
    );
    assert(
      widget.selectedIndex >= 0 &&
          widget.selectedIndex < widget.destinations.length,
      'selectedIndex must point at one of the destinations',
    );
    final size = MmWindowSize.of(context);
    final body = FocusTraversalGroup(
      child: KeyedSubtree(
        key: _bodyKey,
        // Snack bars from the screen show on the screen's own scaffold,
        // above its bottom bar, not on this frame's scaffold over it.
        child: ScaffoldMessenger(child: widget.body),
      ),
    );
    // The destinations draw focus as a ring (see _DestinationIcon), not as
    // a tinted pill that looks like a second selection.
    final theme = Theme.of(context).copyWith(focusColor: Colors.transparent);
    if (size == MmWindowSize.compact) {
      return Scaffold(
        body: body,
        // A hairline rule parts the bar from the page, as it parts the rail.
        bottomNavigationBar: Theme(
          data: theme,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(
                height: MmSize.hairline,
                thickness: MmSize.hairline,
              ),
              LayoutBuilder(
                builder: (context, constraints) =>
                    _navigationBar(context, constraints.maxWidth),
              ),
            ],
          ),
        ),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    final extended = size == MmWindowSize.large;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Beside the icons, labels read at the size of buttons' labels rather
    // than the captions under the icons of the narrow rail.
    final colors = context.mm.colors;
    final label = theme.textTheme.labelLarge;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusTraversalGroup(
            child: Theme(
              data: theme,
              child: NavigationRail(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onDestinationSelected,
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedLabelTextStyle: extended
                    ? label?.copyWith(color: colors.ink)
                    : null,
                unselectedLabelTextStyle: extended
                    ? label?.copyWith(color: colors.inkMuted)
                    : null,
                // Large text or a short window must not push destinations
                // out of reach.
                scrollable: true,
                destinations: [
                  for (final destination in widget.destinations)
                    NavigationRailDestination(
                      icon: _DestinationIcon(
                        destination,
                        selected: false,
                        indicator: _railIndicator,
                      ),
                      selectedIcon: _DestinationIcon(
                        destination,
                        selected: true,
                        indicator: _railIndicator,
                      ),
                      label: Text(destination.label),
                      // Material's extended destinations are 44 dp tall:
                      // this makes them 48 dp targets at least, and parts
                      // the lines of labels that grow past the icon.
                      padding: extended
                          ? const EdgeInsets.symmetric(vertical: MmSpace.s1)
                          : null,
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(
            width: MmSize.hairline,
            thickness: MmSize.hairline,
          ),
          Expanded(
            // The rail already keeps clear of the display cut-out on its
            // side; the body must not pad for it again.
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: !rtl,
              removeRight: rtl,
              child: body,
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// The bottom bar of a phone, [width] wide.
  ///
  /// Material's bar is a fixed height that fits one Latin line of label;
  /// Nastaliq labels and large text need more, so the bar grows to hold
  /// the tallest label (as wrapped in its destination's width) with its
  /// glyphs' overhang and [MmSpace.s1] to spare above and below.
  Widget _navigationBar(BuildContext context, double width) {
    final barTheme = NavigationBarTheme.of(context);
    final style =
        barTheme.labelTextStyle?.resolve({WidgetState.selected}) ??
        Theme.of(context).textTheme.labelMedium;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: _maxBarLabelTextScale);
    var line = 0.0;
    var above = 0.0;
    var below = 0.0;
    for (final destination in widget.destinations) {
      final metrics = MmTextMetrics.of(
        context,
        destination.label,
        style,
        textScaler: scaler,
        maxWidth: width / widget.destinations.length,
      );
      line = math.max(line, metrics.size.height);
      above = math.max(above, metrics.overhangAbove);
      below = math.max(below, metrics.overhangBelow);
    }
    // The label keeps Material's 4 dp from the indicator, plus whatever its
    // glyphs rise above their line. Whole pixels keep the icons sharp.
    final labelGap = MmSpace.s1 + above.ceilToDouble();
    final content = _barIndicator.height + labelGap + line.ceilToDouble();
    var height = math.max(
      barTheme.height ?? _defaultBarHeight,
      content + 2 * (below.ceilToDouble() + MmSpace.s1),
    );
    // The bar centres the icon and label: an odd spare pixel would put
    // them on a half pixel.
    if ((height - content).round().isOdd) height += 1;
    return NavigationBar(
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onDestinationSelected,
      height: height,
      labelPadding: EdgeInsets.only(top: labelGap),
      animationDuration: MmMotion.of(context, MmDuration.standard),
      destinations: [
        for (final destination in widget.destinations)
          NavigationDestination(
            icon: _DestinationIcon(
              destination,
              selected: false,
              indicator: _barIndicator,
            ),
            selectedIcon: _DestinationIcon(
              destination,
              selected: true,
              indicator: _barIndicator,
            ),
            label: destination.label,
          ),
      ],
    );
  }
}

/// The most a badge's count grows with the text: as much as the labels of
/// a [NavigationBar] do.
const double _maxBadgeTextScale = _maxBarLabelTextScale;

/// A destination's icon, with its badge when it has a count, ringed while
/// its destination has keyboard focus.
///
/// It sits inside the destination's ink well, so the nearest [Focus] is
/// the destination's own. The ring follows the edge of the selection
/// indicator ([indicator], centred on the icon), so it outlines the same
/// pill selection fills: on the edge, as for outlined controls, because the
/// indicator's fill is a light tint the focus colour stands out against.
class _DestinationIcon extends StatefulWidget {
  const new(
    this.destination, {
    required this.selected,
    required this.indicator,
  });

  final MmDestination destination;
  final bool selected;

  /// The size of the selection indicator around the icon.
  final Size indicator;

  @override
  State<_DestinationIcon> createState() => _DestinationIconState();
}

class _DestinationIconState extends State<_DestinationIcon>
    with MmFocusHighlight<_DestinationIcon> {
  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final focused =
        showsFocusHighlights &&
        (Focus.maybeOf(context)?.hasPrimaryFocus ?? false);
    Widget icon = Icon(
      widget.selected
          ? destination.selectedIcon ?? destination.icon
          : destination.icon,
    );
    final count = destination.badgeCount ?? 0;
    if (count != 0) {
      // The badge may say "999+"; screen readers get the full count, read
      // after the destination's label. The theme sets counts in the Latin
      // face in both languages, like amounts; they grow with the text only
      // as far as the bar's labels do, so the badge never hides its icon.
      icon = Semantics(
        value: '$count',
        child: ExcludeSemantics(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: _maxBadgeTextScale,
            child: Badge.count(count: count, child: icon),
          ),
        ),
      );
    }
    return CustomPaint(
      foregroundPainter: focused
          ? MmFocusRingPainter(
              color: context.mm.colors.focus,
              size: widget.indicator,
              radius: widget.indicator.shortestSide / 2,
            )
          : null,
      child: icon,
    );
  }
}
