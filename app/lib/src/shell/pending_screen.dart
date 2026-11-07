import 'package:flutter/material.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:mm_ui/mm_ui.dart';

/// A section whose screens arrive in a later phase: it says so plainly
/// instead of showing an empty page.
class PendingScreen extends StatelessWidget {
  const new({required this.section, super.key});

  final String Function(AppLocalizations l10n) section;

  static Widget dashboard(BuildContext context) =>
      PendingScreen(section: (l10n) => l10n.navDashboard);
  static Widget properties(BuildContext context) =>
      PendingScreen(section: (l10n) => l10n.navProperties);
  static Widget tenants(BuildContext context) =>
      PendingScreen(section: (l10n) => l10n.navTenants);
  static Widget money(BuildContext context) =>
      PendingScreen(section: (l10n) => l10n.navMoney);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = section(l10n);
    return MmPage(
      title: name,
      body: MmEmptyState(
        icon: MmIcons.maintenance,
        title: l10n.comingSoonTitle(name),
        message: l10n.comingSoonBody,
      ),
    );
  }
}
