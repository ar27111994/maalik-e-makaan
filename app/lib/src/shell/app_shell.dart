import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:mm_ui/mm_ui.dart';

/// The signed-in frame: the five sections in a bottom bar on phones and a
/// navigation rail from medium windows up (start side, so it moves to the
/// right in Urdu). Each section keeps its own navigation stack.
class AppShell extends StatelessWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (MmIcons.home, l10n.navHome),
      (MmIcons.tenants, l10n.navTenants),
      (MmIcons.ledger, l10n.navMoney),
      (MmIcons.property, l10n.navProperties),
      (MmIcons.more, l10n.navMore),
    ];
    final size = MmWindowSize.of(context);
    if (size == MmWindowSize.compact) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final (icon, label) in destinations)
              NavigationDestination(icon: Icon(icon), label: label),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _select,
            extended: size == MmWindowSize.large,
            labelType: size == MmWindowSize.large
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final (icon, label) in destinations)
                NavigationRailDestination(icon: Icon(icon), label: Text(label)),
            ],
          ),
          const VerticalDivider(width: MmSize.hairline),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
