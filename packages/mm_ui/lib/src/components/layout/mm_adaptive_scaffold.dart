import 'package:flutter/material.dart';
import 'package:mm_ui/src/foundation/mm_window.dart';
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
///   destinations sit within thumb reach.
/// * **medium** and **expanded**: a [NavigationRail] at the start edge with
///   every label shown under its icon, a hairline rule, then [body].
/// * **large** (desktop web): the rail extended, labels beside the icons.
///
/// Everything mirrors in right-to-left layouts (the rail sits on the right in
/// Urdu). [body] keeps its state when the window changes size class, for
/// example when a tablet rotates. Keyboard users reach the destinations
/// with Tab and select one with Enter or Space; screen readers hear each as
/// a tab ("Tenants, tab 2 of 4") with its badge count.
///
/// Use it once, at the root of the signed-in app; screens inside it are
/// usually `MmPage`s. Don't use it for a single screen's sections (use
/// `MmTabs`) or for fewer than two destinations.
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

  /// The screen of the selected destination.
  final Widget body;

  /// The selected screen's main action, if it has one, floating at the
  /// bottom end of the window.
  final Widget? floatingActionButton;

  @override
  State<MmAdaptiveScaffold> createState() => _MmAdaptiveScaffoldState();
}

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
      child: KeyedSubtree(key: _bodyKey, child: widget.body),
    );
    if (size == MmWindowSize.compact) {
      return Scaffold(
        body: body,
        // A hairline rule parts the bar from the page, as it parts the rail.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: MmSize.hairline, thickness: MmSize.hairline),
            NavigationBar(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              destinations: [
                for (final destination in widget.destinations)
                  NavigationDestination(
                    icon: _DestinationIcon(destination, selected: false),
                    selectedIcon: _DestinationIcon(destination, selected: true),
                    label: destination.label,
                  ),
              ],
            ),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    final extended = size == MmWindowSize.large;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Beside the icons, labels read at the size of buttons' labels rather
    // than the captions under the icons of the narrow rail.
    final colors = context.mm.colors;
    final label = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusTraversalGroup(
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
                    icon: _DestinationIcon(destination, selected: false),
                    selectedIcon: _DestinationIcon(destination, selected: true),
                    label: Text(destination.label),
                  ),
              ],
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
}

/// The most a badge's count grows with the text: as much as the labels of
/// a [NavigationBar] do.
const double _maxBadgeTextScale = 1.3;

/// A destination's icon, with its badge when it has a count.
class _DestinationIcon extends StatelessWidget {
  const new(this.destination, {required this.selected});

  final MmDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected
          ? destination.selectedIcon ?? destination.icon
          : destination.icon,
    );
    final count = destination.badgeCount ?? 0;
    if (count == 0) return icon;
    // The badge may say "999+"; screen readers get the full count, read
    // after the destination's label. The theme sets counts in the Latin
    // face in both languages, like amounts; they grow with the text only as
    // far as the bar's labels do, so the badge never hides its icon.
    return Semantics(
      value: '$count',
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxBadgeTextScale,
          child: Badge.count(count: count, child: icon),
        ),
      ),
    );
  }
}
