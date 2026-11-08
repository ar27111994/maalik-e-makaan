import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// A tenancy's money on its own screen: what it owes or holds, and the way
/// to its ledger, where payments are recorded.
class LeaseMoneySection extends ConsumerWidget {
  const new({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = tenancyLedgerProvider(leaseId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.moneySection),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingLedger,
          failedTitle: l10n.ledgerLoadFailedTitle,
          skeleton: const MmSkeletonList(itemCount: 1),
          builder: (ledger) => ListCard(
            children: [
              MmListTile(
                leading: const Icon(MmIcons.ledger),
                title: l10n.openLedgerAction,
                subtitle: l10n.owedNowValue(
                  MmFormats.moneyOf(context).format(ledger.balance.outstanding),
                ),
                trailing: BelowText(
                  child: balanceBadge(context, ledger.balance),
                ),
                onTap: () => context.go(Routes.ledger(leaseId)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
