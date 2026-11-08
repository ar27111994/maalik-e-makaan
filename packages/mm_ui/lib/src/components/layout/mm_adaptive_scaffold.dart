import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/layout/mm_focus_ring.dart';
import 'package:mm_ui/src/foundation/mm_focus_highlight.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/foundation/mm_text_metrics.dart';
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
///   text and with Nastaliq labels, so no label is clipped. A label wraps
///   only between its words, never inside one: when a word would not fit
///   its destination at the reader's text size (five destinations at 200%
///   text), the labels are set only as much smaller as that word needs, but
///   never below their standard size; if a word does not fit even then, the
///   bar shows icons alone, and each label is the destination's tooltip and
///   is still read by screen readers.
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
/// A phone's bar holds two to [maxBarDestinations] (five) destinations, as
/// Material's navigation bar does. Five share a 320 dp phone 64 dp each,
/// as wide as the selection indicator behind an icon; six would get 53 dp,
/// too narrow for the indicator, let alone a label. An app with more places
/// gives the bar its four most used and a fifth, "More", whose screen lists
/// the rest (the gallery app does this); the rail of a wider window can
/// list them all. Debug builds check the limit on phones.
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

  /// The app's main destinations, in order. At least two, and on a phone
  /// at most [maxBarDestinations].
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

  /// The most destinations a phone's bottom bar holds: Material's
  /// navigation bar takes three to five.
  static const int maxBarDestinations = 5;

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
      assert(
        widget.destinations.length <= MmAdaptiveScaffold.maxBarDestinations,
        'MmAdaptiveScaffold has ${widget.destinations.length} destinations, '
        "but a phone's bottom bar holds at most "
        '${MmAdaptiveScaffold.maxBarDestinations}: their labels would not '
        'fit. On phones, pass the four most used and a "More" destination '
        'whose screen lists the rest.',
      );
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
                      label: MmScriptText(
                        destination.label,
                        style: const TextStyle(),
                      ),
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
    final slot = width / widget.destinations.length;
    final reader = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: _maxBarLabelTextScale)
        .scale(1);
    // The largest scale, up to the reader's, at which the longest word of
    // every label fits its destination: labels wrap between words only.
    var fit = reader;
    for (final destination in widget.destinations) {
      final word = MmTextMetrics.of(
        context,
        destination.label,
        context.mm.styleFor(destination.label, style ?? const TextStyle()),
        textScaler: TextScaler.noScaling,
      ).minIntrinsicWidth;
      // A pixel to spare: glyph widths do not scale exactly linearly.
      if (word > 0) fit = math.min(fit, (slot - 1) / word);
    }
    // Never smaller than the standard size: below it a label is too small
    // to read, and the icons alone say more.
    final hidden = fit < math.min(1, reader);
    // The badges grow as the labels do; with the labels hidden, as far as
    // the bar lets labels grow.
    final scaler = TextScaler.linear(hidden ? reader : fit);
    final bar = hidden
        ? NavigationBar(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            animationDuration: MmMotion.of(context, MmDuration.standard),
            destinations: _barDestinations(),
          )
        : _labelledBar(context, width, style, scaler);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: bar,
    );
  }

  /// The bar's destinations. A label in Latin script ("WhatsApp") keeps
  /// the Latin face in the Urdu UI: a destination's label is a plain
  /// string, so its style says so.
  List<Widget> _barDestinations() {
    final barTheme = NavigationBarTheme.of(context);
    final base = Theme.of(context).textTheme.labelMedium;
    return [
      for (final destination in widget.destinations)
        NavigationBarTheme(
          data: barTheme.copyWith(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => context.mm.styleFor(
                destination.label,
                barTheme.labelTextStyle?.resolve(states) ?? base!,
              ),
            ),
          ),
          child: NavigationDestination(
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
        ),
    ];
  }

  /// The bar [width] wide with its labels shown, in [style] at [scaler].
  Widget _labelledBar(
    BuildContext context,
    double width,
    TextStyle? style,
    TextScaler scaler,
  ) {
    final barTheme = NavigationBarTheme.of(context);
    var line = 0.0;
    var above = 0.0;
    var below = 0.0;
    for (final destination in widget.destinations) {
      final metrics = MmTextMetrics.of(
        context,
        destination.label,
        context.mm.styleFor(destination.label, style ?? const TextStyle()),
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
      destinations: _barDestinations(),
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                icon,
                Positioned.fill(
                  child: CustomSingleChildLayout(
                    delegate: _EndCornerBadge(Directionality.of(context)),
                    child: Badge.count(count: count),
                  ),
                ),
              ],
            ),
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

/// Places a destination's count badge past the top end corner of its icon,
/// in either direction.
///
/// Material's `Badge` overlaps its child: its start edge stands 12 dp into a
/// 24 dp icon, over the glyph of a narrow icon (the dots of "More"), and in
/// right-to-left text it hangs from the icon's left edge into the icon
/// rather than past it. Here the badge's start edge sits on the end edge of
/// the icon's glyph, which Lucide draws [MmSpace.sHalf] in from the icon's
/// square, so the count never covers any part of the icon. Its middle is
/// a sixth of the way down the icon (4 dp on a 24 dp icon), where Material
/// puts it.
class _EndCornerBadge extends SingleChildLayoutDelegate {
  const new(this.textDirection);

  final TextDirection textDirection;

  /// How far the badge's start edge stands inside the icon's square: the
  /// air Lucide leaves around its glyphs.
  static const double _overlap = MmSpace.sHalf;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final start = size.width - _overlap;
    return Offset(
      textDirection == TextDirection.rtl
          ? size.width - start - childSize.width
          : start,
      size.height / 6 - childSize.height / 2,
    );
  }

  @override
  bool shouldRelayout(_EndCornerBadge oldDelegate) =>
      oldDelegate.textDirection != textDirection;
}
