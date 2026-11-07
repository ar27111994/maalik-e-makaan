import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/shell/refresh_notice.dart';
import 'package:mm_ui/mm_ui.dart';

/// The fifth section: the portfolio being worked in (and switching it), and
/// the way to Settings.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final current = ref.watch(currentPortfolioProvider).value;
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
          ],
          MmCard(
            padding: EdgeInsetsDirectional.zero,
            child: MmListTile(
              leading: const Icon(MmIcons.settings),
              title: l10n.settingsTitle,
              subtitle: l10n.settingsSummary,
              // Never cut short, even at 200% text.
              subtitleMaxLines: 4,
              trailing: const Icon(MmIcons.chevronEnd),
              onTap: () => context.go(Routes.settings),
            ),
          ),
        ],
      ),
    );
  }
}
