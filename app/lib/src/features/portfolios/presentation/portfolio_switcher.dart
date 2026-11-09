import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// The word for [role] in the app's language.
String roleLabel(AppLocalizations l10n, MemberRole role) => switch (role) {
  MemberRole.owner => l10n.roleOwner,
  MemberRole.manager => l10n.roleManager,
  MemberRole.accountant => l10n.roleAccountant,
  MemberRole.viewer => l10n.roleViewer,
};

/// Opens the portfolio switcher: every portfolio the user belongs to, the
/// current one marked, and a way to create another.
Future<void> showPortfolioSwitcher(BuildContext context) => showMmSheet<void>(
  context,
  title: AppLocalizations.of(context).switchPortfolioTitle,
  builder: (context) => const PortfolioSwitcher(),
);

/// The content of the portfolio switcher sheet.
class PortfolioSwitcher extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final current = ref.watch(currentPortfolioProvider).value;
    final memberships = userId == null
        ? const <PortfolioMembership>[]
        : ref.watch(portfoliosProvider(userId)).value?.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (memberships.isNotEmpty)
          MmCard(
            padding: EdgeInsetsDirectional.zero,
            child: Column(
              children: [
                for (final (index, membership) in memberships.indexed) ...[
                  if (index > 0) const Divider(height: MmSize.hairline),
                  MmListTile(
                    title: membership.name,
                    subtitle: roleLabel(l10n, membership.role),
                    selected: membership.id == current?.id,
                    trailing: membership.id == current?.id
                        ? Semantics(
                            label: l10n.currentPortfolioLabel,
                            child: Icon(
                              MmIcons.check,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      if (userId != null) {
                        await ref
                            .read(selectedPortfolioProvider(userId).notifier)
                            .select(membership.id);
                      }
                      navigator.pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.newPortfolioAction,
          icon: MmIcons.add,
          variant: MmButtonVariant.secondary,
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.go(Routes.createPortfolio);
          },
        ),
      ],
    );
  }
}
