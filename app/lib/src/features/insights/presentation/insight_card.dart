import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insight_rules.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_labels.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// An insight (INS-04) as a card: how pressing it is (a badge with an
/// icon and a word, never colour alone), what was found, the figures
/// behind it, and the way to act on it.
///
/// mm_ui has no insight card: this composes a card, a status badge, text
/// and a tertiary button (a gap reported to the design system).
class InsightCard extends StatelessWidget {
  const new(this.insight, {super.key});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    final (:title, :lines, :action) = _wordsOf(context, l10n, insight);
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MmStatusBadge(
                    status: insightStatus(insight.level),
                    label: insightLevelLabel(l10n, insight.level),
                    icon: insightLevelIcon(insight.level),
                  ),
                ),
                const SizedBox(height: MmSpace.s2),
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleMedium),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: MmSpace.s1),
                  Text(
                    line,
                    style: text.bodyMedium!.copyWith(color: colors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: MmSpace.s2),
            // Lined up with the card's words, its ink reaching into the
            // card's padding.
            MmButton(
              label: action.label,
              variant: MmButtonVariant.link,
              onPressed: () => context.go(action.route),
            ),
          ],
        ],
      ),
    );
  }
}

typedef _Action = ({String label, String route});
typedef _Words = ({String title, List<String> lines, _Action? action});

_Words _wordsOf(BuildContext context, AppLocalizations l10n, Insight insight) {
  final direction = Directionality.of(context);
  String money(Money amount) => moneyText(context, amount);
  final whoOwes = (label: l10n.seeWhoOwesAction, route: Routes.money);
  // An insight about one tenancy opens it, named; one about several leads
  // to the tenants (the app lists tenancies under their tenants), and each
  // is a row of "Due and coming up" when it is dated.
  _Action tenancies(List<({String leaseId, String tenantName})> about) =>
      about.length == 1
      ? (
          label: l10n.openNamedTenancyAction(
            inSentence(about.single.tenantName, direction),
          ),
          route: Routes.lease(about.single.leaseId),
        )
      : (label: l10n.seeTenantsAction, route: Routes.tenants);
  return switch (insight) {
    CollectionInsight(:final rate, :final unpaid) => (
      title: l10n.insightCollectionTitle(percentText(l10n, rate)),
      lines: [
        if (unpaid.isPositive)
          l10n.insightCollectionBody(money(unpaid))
        else
          l10n.insightCollectionDone,
      ],
      action: unpaid.isPositive ? whoOwes : null,
    ),
    LongArrearsInsight(:final amount) => (
      title: l10n.insightLongArrearsTitle(money(amount)),
      lines: [l10n.insightLongArrearsBody],
      action: whoOwes,
    ),
    final IncrementInsight increments => (
      title: l10n.insightIncrementTitle,
      lines: [
        if (increments.missed.isNotEmpty)
          l10n.insightIncrementMissed(
            increments.missed.length,
            money(increments.missedMonthly),
          ),
        if (increments.upcoming.isNotEmpty)
          l10n.insightIncrementUpcoming(increments.upcoming.length),
      ],
      action: tenancies(
        _tenanciesOf([
          for (final i in [...increments.missed, ...increments.upcoming])
            (leaseId: i.leaseId, tenantName: i.tenantName),
        ]),
      ),
    ),
    ExpiringInsight(:final leases) => (
      title: l10n.insightExpiringTitle(leases.length),
      lines: [
        l10n.insightExpiringBody(
          inSentence(leases.first.tenantName, direction),
          leases.first.daysLeft,
        ),
      ],
      action: tenancies(
        _tenanciesOf([
          for (final l in leases)
            (leaseId: l.leaseId, tenantName: l.tenantName),
        ]),
      ),
    ),
    PoliceInsight(
      :final unregistered,
      :final submitted,
      :final pastLegalDeadline,
    ) =>
      (
        title: unregistered.isNotEmpty
            ? l10n.insightPoliceTitle(unregistered.length)
            : l10n.insightPoliceSubmittedTitle(submitted.length),
        lines: [
          if (unregistered.isNotEmpty) ...[
            if (pastLegalDeadline > 0)
              l10n.insightPoliceLate(pastLegalDeadline),
            l10n.insightPoliceBody,
            if (submitted.isNotEmpty)
              l10n.insightPoliceSubmittedLine(submitted.length),
          ] else
            l10n.insightPoliceSubmittedBody,
        ],
        // Those still to register first, the earliest deadline first.
        action: tenancies(
          _tenanciesOf([
            for (final p in [
              ...[...unregistered]
                ..sort((a, b) => a.deadline.compareTo(b.deadline)),
              ...submitted,
            ])
              (leaseId: p.leaseId, tenantName: p.tenantName),
          ]),
        ),
      ),
    VacancyInsight(:final vacant, :final monthlyLoss, :final longestDays) => (
      title: l10n.insightVacancyTitle(vacant),
      lines: [l10n.insightVacancyBody(vacant, money(monthlyLoss), longestDays)],
      action: null,
    ),
    final DepositCoverInsight deposits => (
      title: l10n.insightDepositTitle(percentText(l10n, deposits.cover)),
      lines: [
        l10n.insightDepositBody(money(deposits.overdue), money(deposits.held)),
      ],
      action: whoOwes,
    ),
    final UtilityRiskInsight utilities => (
      title: l10n.insightUtilityTitle,
      lines: [
        if (utilities.arrears.unpaidInLandlordNameCount > 0)
          l10n.insightUtilityLandlord(
            utilities.arrears.unpaidInLandlordNameCount,
            money(utilities.arrears.unpaidInLandlordName),
          ),
        if (utilities.arrears.overdueCount > 0)
          l10n.insightUtilityOverdue(utilities.arrears.overdueCount),
        if (utilities.overTariff > 0)
          l10n.insightUtilityOverTariff(utilities.overTariff),
        if (utilities.nearTariff > 0)
          l10n.insightUtilityNearTariff(utilities.nearTariff),
      ],
      action: (label: l10n.seeUtilitiesAction, route: Routes.utilities),
    ),
    ExpenseSpikeInsight(:final thisMonth, :final average) => (
      title: l10n.insightExpenseTitle,
      lines: [l10n.insightExpenseBody(money(thisMonth), money(average))],
      action: (label: l10n.seeExpensesAction, route: Routes.expenses),
    ),
    final UnderpricedInsight underpriced => (
      title: l10n.insightUnderpricedTitle(underpriced.units.length),
      lines: [
        l10n.insightUnderpricedBody(
          money(underpriced.monthlyGap),
          l10n.unitAtProperty(
            inSentence(underpriced.units.first.unitLabel, direction),
            inSentence(underpriced.units.first.propertyName, direction),
          ),
        ),
      ],
      action: tenancies([
        for (final u in underpriced.units)
          (leaseId: u.leaseId, tenantName: u.tenantName),
      ]),
    ),
    final CashInsight cash => (
      title: cash.holders.isEmpty
          ? l10n.insightCashShareTitle
          : l10n.insightCashTitle(money(cash.held)),
      lines: [
        if (cash.holders.isNotEmpty)
          l10n.insightCashHolder(
            inSentence(holderName(l10n, cash.holders.first), direction),
            money(cash.holders.first.inHand),
          ),
        if (cash.cashShare case final share?)
          l10n.insightCashShare(percentText(l10n, share)),
        l10n.insightCashAdvice,
      ],
      action: (label: l10n.seeCashAction, route: Routes.cash),
    ),
  };
}

/// [tenancies] once each, in their order: one tenancy can be in a list
/// twice (a missed increase and the next one).
List<({String leaseId, String tenantName})> _tenanciesOf(
  List<({String leaseId, String tenantName})> tenancies,
) {
  final seen = <String>{};
  return [
    for (final t in tenancies)
      if (seen.add(t.leaseId)) t,
  ];
}
