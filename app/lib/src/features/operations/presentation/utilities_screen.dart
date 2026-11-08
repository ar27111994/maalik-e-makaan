import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Utilities (UTIL-01..03): the bills still to pay, the earliest due
/// first, with a warning for those on connections in the landlord's name
/// (arrears follow the premises); then the connections in use (or
/// archived), each leading to its bills and readings. Owners and managers
/// add connections.
class UtilitiesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends ConsumerState<UtilitiesScreen> {
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    return MmPage(
      title: l10n.utilitiesTitle,
      body: portfolio == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UnpaidBills(portfolio: portfolio),
                const SizedBox(height: MmSpace.s8),
                MmSectionHeader(
                  title: l10n.connectionsSection,
                  subtitle: l10n.connectionsHelp,
                ),
                const SizedBox(height: MmSpace.s2),
                MmFilterChips<bool>(
                  multiSelect: false,
                  options: [
                    MmFilterOption(value: false, label: l10n.filterInUse),
                    MmFilterOption(value: true, label: l10n.filterArchived),
                  ],
                  selected: {_archived},
                  onChanged: (selected) {
                    if (selected.isNotEmpty) {
                      setState(() => _archived = selected.single);
                    }
                  },
                ),
                const SizedBox(height: MmSpace.s4),
                _AccountList(
                  list: (portfolioId: portfolio.id, archived: _archived),
                ),
              ],
            ),
      bottomBar: portfolio != null && portfolio.role.runsProperties
          ? MmActionBar(
              primary: MmButton(
                label: l10n.addConnectionAction,
                icon: MmIcons.add,
                onPressed: () => context.go(Routes.newUtility),
              ),
            )
          : null,
    );
  }
}

class _UnpaidBills extends ConsumerWidget {
  const new({required this.portfolio});

  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = unpaidBillsProvider(portfolio.id);
    final today = dates.today(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.unpaidBillsSection,
          subtitle: l10n.unpaidBillsHelp,
        ),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingUtilities,
          failedTitle: l10n.utilitiesLoadFailedTitle,
          skeleton: const MmSkeletonList(itemCount: 2),
          builder: (bills) {
            if (bills.isEmpty) {
              return Text(
                l10n.noUnpaidBills,
                style: Theme.of(context).textTheme.bodyLarge,
              );
            }
            final atRisk = [
              for (final bill in bills)
                if (bill.connection.inLandlordName &&
                    (bill.dueDate?.isBefore(today) ?? false))
                  bill,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (atRisk.isNotEmpty) ...[
                  MmBanner(
                    tone: MmBannerTone.warning,
                    message: l10n.landlordNameOverdue(atRisk.length),
                  ),
                  const SizedBox(height: MmSpace.s3),
                ],
                ListCard(
                  children: [
                    for (final bill in bills) BillTile(bill: bill, named: true),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AccountList extends ConsumerWidget {
  const new({required this.list});

  final UtilityAccountList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = utilityAccountsProvider(list);
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingUtilities,
      failedTitle: l10n.utilitiesLoadFailedTitle,
      builder: (page) {
        if (page.items.isEmpty) {
          return list.archived
              ? MmEmptyState(
                  icon: MmIcons.archive,
                  title: l10n.archivedConnectionsEmpty,
                  message: l10n.archivedConnectionsEmptyBody,
                )
              : MmEmptyState(
                  icon: MmIcons.utility,
                  title: l10n.connectionsEmptyTitle,
                  message: l10n.connectionsEmptyBody,
                );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListCard(
              children: [
                for (final account in page.items)
                  UtilityAccountTile(account: account),
              ],
            ),
            if (page.hasMore)
              LoadMoreButton(
                onLoad: () => ref.read(provider.notifier).loadMore(),
              ),
          ],
        );
      },
    );
  }
}

/// A connection in a list: what and who supplies it, where, its number,
/// and whose name it is in.
class UtilityAccountTile extends StatelessWidget {
  const new({required this.account, super.key});

  final UtilityAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    return MmListTile(
      leading: Icon(utilityIcon(account.type)),
      title: connectionName(
        context,
        type: account.type,
        provider: account.provider,
        providerOther: account.providerOther,
      ),
      subtitle: appText(
        detailLine([
          placeLabel(context, account.propertyName, account.unitLabel),
          if (account.referenceNumber case final reference?)
            l10n.connectionReference(
              MmSemantics.isolated(reference, direction),
            ),
          if (account.inLandlordName) l10n.inYourName,
        ]),
        direction,
      ),
      subtitleMaxLines: null,
      chevron: true,
      onTap: () => context.go(Routes.utility(account.id)),
    );
  }
}

/// A bill in a list: its month (and, when [named], its connection), its
/// amount and units, and where it stands, with, on a connection on the
/// protected tariff, a badge when its units are near or over the limit:
/// losing the tariff is the costliest thing a bill can show.
class BillTile extends StatelessWidget {
  const new({required this.bill, this.named = false, super.key});

  final UtilityBill bill;

  /// Whether the tile names the connection: in a list of every
  /// connection's bills.
  final bool named;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final direction = Directionality.of(context);
    final connection = bill.connection;
    final month = monthLabel(context, bill.billingMonth);
    final units = bill.unitsConsumed;
    final protected = protectedBadge(context, bill.protectedUse);
    return MmListTile(
      leading: Icon(utilityIcon(connection.type)),
      title: named
          ? l10n.billOfMonth(
              inSentence(connectionNameOf(context, connection), direction),
              month,
            )
          : month,
      subtitle: appText(
        detailLine([
          money.format(bill.amount),
          if (named)
            placeLabel(context, connection.propertyName, connection.unitLabel),
          if (units != null) l10n.unitsUsed('$units'),
          if (named && connection.inLandlordName) l10n.inYourName,
          if (bill.liveCharge != null) l10n.chargedToTenant,
        ]),
        direction,
      ),
      subtitleMaxLines: null,
      trailing: BelowText(
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: MmSpace.s2,
          runSpacing: MmSpace.s2,
          children: [billBadge(context, bill), ?protected],
        ),
      ),
      onTap: () => context.go(Routes.utilityBill(bill.id)),
    );
  }
}
