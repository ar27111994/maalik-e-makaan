import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/lost_photo_recovery.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:mm_ui/mm_ui.dart';

/// The signed-in frame: the five sections in a bottom bar on phones, a
/// navigation rail from medium windows up (on the start side, so on the
/// right in Urdu), extended on large ones. Each section keeps its own
/// navigation stack.
///
/// Every section works in the current portfolio, so until it is known the
/// frame shows that it is loading, or why it could not load, with a retry.
///
/// When the app comes back to the foreground, the unread count on More is
/// read again: notifications may have arrived while it was away. A camera
/// photo Android kept after closing the app is brought back to its record
/// ([LostPhotoRecovery]).
class AppShell extends ConsumerStatefulWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  StatefulNavigationShell get shell => widget.shell;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(unreadCountProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider);
    final unread = ref.watch(unreadCountProvider).value;
    // A camera photo Android kept after closing the app comes back here.
    return LostPhotoRecovery(
      child: MmAdaptiveScaffold(
        destinations: [
          MmDestination(icon: MmIcons.home, label: l10n.navDashboard),
          MmDestination(icon: MmIcons.property, label: l10n.navProperties),
          MmDestination(icon: MmIcons.tenants, label: l10n.navTenants),
          MmDestination(icon: MmIcons.ledger, label: l10n.navMoney),
          MmDestination(
            icon: MmIcons.more,
            label: l10n.navMore,
            // Unread notifications wait under More.
            badgeCount: unread,
          ),
        ],
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _select,
        body: portfolio.hasValue
            ? shell
            : _PortfolioPending(error: portfolio.error),
      ),
    );
  }
}

/// Shown in place of a section while the portfolios load, or when they
/// failed to load and nothing was saved on the device.
class _PortfolioPending extends ConsumerWidget {
  const new({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = this.error;
    return MmPage(
      title: l10n.appName,
      body: error == null
          ? Semantics(
              label: l10n.loadingPortfolios,
              child: const MmSkeleton.text(lines: 4),
            )
          : MmErrorState(
              title: l10n.portfoliosLoadFailedTitle,
              message: failureMessage(l10n, AppFailure.from(error)),
              onRetry: () {
                final userId = ref.read(currentUserIdProvider);
                if (userId != null) ref.invalidate(portfoliosProvider(userId));
              },
            ),
    );
  }
}
