import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The Money section: what the portfolio is owed, overdue and holds as
/// credit, then who owes what, the most overdue first (INS-02), each
/// leading to its tenancy's ledger; and the way to the cash in hand.
class MoneyScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    return MmPage(
      title: l10n.navMoney,
      actions: [
        IconButton(
          tooltip: l10n.cashBookTitle,
          icon: const Icon(MmIcons.cash),
          onPressed: () => context.go(Routes.cash),
        ),
      ],
      body: portfolio == null
          ? const SizedBox.shrink()
          : _Receivables(portfolio: portfolio),
    );
  }
}

class _Receivables extends ConsumerWidget {
  const new({required this.portfolio});

  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = receivablesProvider(portfolio);
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingReceivables,
      failedTitle: l10n.receivablesLoadFailedTitle,
      builder: (receivables) {
        if (receivables.isEmpty) {
          return MmEmptyState(
            icon: MmIcons.ledger,
            title: l10n.receivablesEmptyTitle,
            message: l10n.receivablesEmptyBody,
          );
        }
        Money total(Money Function(LeaseBalance b) of) =>
            Money.sum([for (final r in receivables) of(r.balance)]);
        final owing = byDaysOverdue([
          for (final r in receivables)
            if (r.balance.outstanding.isPositive) r,
        ]);
        final settled = [
          for (final r in receivables)
            if (!r.balance.outstanding.isPositive) r,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmResponsiveGrid(
              minItemWidth: 150,
              children: [
                MmStatTile(
                  label: l10n.totalOwedLabel,
                  value: MmAmount(amount: total((b) => b.outstanding)),
                ),
                MmStatTile(
                  label: l10n.totalOverdueLabel,
                  value: MmAmount(amount: total((b) => b.overdue)),
                ),
                MmStatTile(
                  label: l10n.totalCreditLabel,
                  value: MmAmount(amount: total((b) => b.credit)),
                ),
              ],
            ),
            const SizedBox(height: MmSpace.s6),
            MmSectionHeader(
              title: l10n.whoOwesSection,
              subtitle: l10n.whoOwesHelp,
            ),
            const SizedBox(height: MmSpace.s2),
            if (owing.isEmpty)
              Text(
                l10n.nobodyOwes,
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else
              ListCard(children: [for (final r in owing) ReceivableTile(r)]),
            if (settled.isNotEmpty) ...[
              const SizedBox(height: MmSpace.s6),
              MmSectionHeader(title: l10n.settledSection),
              const SizedBox(height: MmSpace.s2),
              ListCard(children: [for (final r in settled) ReceivableTile(r)]),
            ],
          ],
        );
      },
    );
  }
}

/// [owing] in the order of INS-02: the longest overdue first, then the most
/// overdue, then the most owed, then by name. The server lists the most
/// overdue amount first.
List<Receivable> byDaysOverdue(List<Receivable> owing) =>
    [...owing]..sort((a, b) {
      final days = (b.balance.daysOverdue ?? -1).compareTo(
        a.balance.daysOverdue ?? -1,
      );
      if (days != 0) return days;
      final overdue = b.balance.overdue.compareTo(a.balance.overdue);
      if (overdue != 0) return overdue;
      final owed = b.balance.outstanding.compareTo(a.balance.outstanding);
      if (owed != 0) return owed;
      final name = a.tenantName.compareTo(b.tenantName);
      return name != 0 ? name : a.leaseId.compareTo(b.leaseId);
    });

/// One tenancy in the who-owes-what list: the tenant, the unit, when they
/// last paid, and what they owe (since when) or hold as credit.
class ReceivableTile extends StatelessWidget {
  const new(this.receivable, {super.key});

  final Receivable receivable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final balance = receivable.balance;
    final paidOn = balance.lastPaidOn;
    return MmListTile(
      leading: MmAvatar(name: receivable.tenantName),
      title: receivable.tenantName,
      subtitle: appText(
        detailLine([
          l10n.unitAtProperty(
            inSentence(receivable.unitLabel, direction),
            inSentence(receivable.propertyName, direction),
          ),
          if (paidOn != null) l10n.lastPaidOn(dateInLine(context, paidOn)),
          if (!receivable.active) l10n.leaseEnded,
        ]),
        direction,
      ),
      subtitleMaxLines: 6,
      trailing: BelowText(child: balanceBadge(context, balance)),
      onTap: () => context.go(Routes.ledger(receivable.leaseId)),
    );
  }
}

/// A badge saying what a tenancy owes, since how long, or holds. When
/// some of it is overdue, the badge names what is overdue and the age of
/// the oldest due, not the whole amount owed: part of that may not be due
/// yet.
MmStatusBadge balanceBadge(BuildContext context, LeaseBalance balance) {
  final l10n = AppLocalizations.of(context);
  final money = MmFormats.moneyOf(context);
  final days = balance.daysOverdue;
  if (balance.overdue.isPositive && days != null) {
    return MmStatusBadge(
      status: MmStatus.overdue,
      label: l10n.overdueOldest(money.format(balance.overdue), days),
    );
  }
  if (balance.outstanding.isPositive) {
    return MmStatusBadge(
      status: MmStatus.dueSoon,
      label: l10n.owesAmount(money.format(balance.outstanding)),
    );
  }
  if (balance.credit.isPositive) {
    return MmStatusBadge(
      status: MmStatus.credit,
      label: l10n.creditAmount(money.format(balance.credit)),
    );
  }
  return MmStatusBadge(status: MmStatus.paid, label: l10n.allPaid);
}
