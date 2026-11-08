import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:mm_ui/mm_ui.dart';

/// The fifth section: the portfolio being worked in (and switching it), its
/// operations (expenses, utilities and maintenance), its reports and
/// search, and the way to notifications, the team, the portfolio's details
/// and Settings.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final current = ref.watch(currentPortfolioProvider).value;
    final unread = ref.watch(unreadCountProvider).value;
    return MmPage(
      title: l10n.navMore,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (userId != null)
            RefreshNotice(
              state: ref.watch(portfoliosProvider(userId)),
              onRetry: () => ref.invalidate(portfoliosProvider(userId)),
            ),
          if (current != null) ...[
            MmSectionHeader(title: l10n.portfolioSection),
            const SizedBox(height: MmSpace.s2),
            MmNameplate(
              name: current.name,
              subtitle: l10n.yourRole(roleLabel(l10n, current.role)),
            ),
            const SizedBox(height: MmSpace.s3),
            MmButton(
              label: l10n.switchPortfolioAction,
              icon: MmIcons.expand,
              variant: MmButtonVariant.secondary,
              onPressed: () => showPortfolioSwitcher(context),
            ),
            const SizedBox(height: MmSpace.s8),
            MmSectionHeader(title: l10n.operationsSection),
            const SizedBox(height: MmSpace.s2),
            MmCard(
              padding: EdgeInsetsDirectional.zero,
              child: Column(
                children: [
                  _Entry(
                    icon: MmIcons.receiptText,
                    title: l10n.expensesTitle,
                    subtitle: l10n.expensesSummary,
                    route: Routes.expenses,
                  ),
                  const Divider(height: MmSize.hairline),
                  _Entry(
                    icon: MmIcons.utility,
                    title: l10n.utilitiesTitle,
                    subtitle: l10n.utilitiesSummary,
                    route: Routes.utilities,
                  ),
                  const Divider(height: MmSize.hairline),
                  _Entry(
                    icon: MmIcons.maintenance,
                    title: l10n.maintenanceTitle,
                    subtitle: l10n.maintenanceSummary,
                    route: Routes.maintenance,
                  ),
                ],
              ),
            ),
            const SizedBox(height: MmSpace.s8),
            MmSectionHeader(title: l10n.reportsTitle),
            const SizedBox(height: MmSpace.s2),
            MmCard(
              padding: EdgeInsetsDirectional.zero,
              child: Column(
                children: [
                  _Entry(
                    icon: MmIcons.reports,
                    title: l10n.reportsEntryTitle,
                    subtitle: l10n.reportsEntrySummary,
                    route: Routes.reports,
                  ),
                  const Divider(height: MmSize.hairline),
                  _Entry(
                    icon: MmIcons.search,
                    title: l10n.searchTitle,
                    subtitle: l10n.searchIntro,
                    route: Routes.search,
                  ),
                ],
              ),
            ),
            const SizedBox(height: MmSpace.s8),
          ],
          MmCard(
            padding: EdgeInsetsDirectional.zero,
            child: Column(
              children: [
                if (current != null) ...[
                  _Entry(
                    icon: MmIcons.notifications,
                    title: l10n.notificationsTitle,
                    subtitle: switch (unread) {
                      final count? when count > 0 => l10n.unreadCount(count),
                      _ => l10n.notificationsSummary,
                    },
                    route: Routes.notifications,
                  ),
                  const Divider(height: MmSize.hairline),
                  _Entry(
                    icon: MmIcons.tenants,
                    title: l10n.teamTitle,
                    subtitle: l10n.teamSummary,
                    route: Routes.team,
                  ),
                  const Divider(height: MmSize.hairline),
                  _Entry(
                    icon: MmIcons.property,
                    title: l10n.portfolioDetailsTitle,
                    subtitle: l10n.portfolioDetailsSummary,
                    route: Routes.portfolioDetails,
                  ),
                  const Divider(height: MmSize.hairline),
                ],
                _Entry(
                  icon: MmIcons.settings,
                  title: l10n.settingsTitle,
                  subtitle: l10n.settingsSummary,
                  route: Routes.settings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One way onward from More.
class _Entry extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => MmListTile(
    leading: Icon(icon),
    title: title,
    subtitle: subtitle,
    // Never cut short, even at 200% text.
    subtitleMaxLines: null,
    // The app's own words, in the UI's direction.
    userData: false,
    chevron: true,
    onTap: () => context.go(route),
  );
}
