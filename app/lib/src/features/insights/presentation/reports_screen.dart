import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/application/payment_scores.dart';
import 'package:maalik_e_makaan/src/features/insights/data/reports.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_labels.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/statement_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The reports (INS-03, INS-05, RPT-*): the cash flow of the last 12
/// months, each property's income, expenses, occupancy and yields, the
/// tenants' payment scores, and the statements and exports.
class ReportsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final span = portfolio == null
        ? null
        : twelveMonthsTo(portfolio.id, MonthPeriod.of(today(context)));
    return MmPage(
      title: l10n.reportsTitle,
      body: portfolio == null || span == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Cashflow(span: span),
                const SizedBox(height: MmSpace.s8),
                _Performance(span: span),
                const SizedBox(height: MmSpace.s8),
                _Scores(portfolio: portfolio),
                const SizedBox(height: MmSpace.s8),
                _Statements(portfolio: portfolio),
              ],
            ),
    );
  }
}

/// Money in and out each month (INS-05), as bars and in total.
class _Cashflow extends ConsumerWidget {
  const new({required this.span});

  final ReportSpan span;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = cashflowProvider(span);
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingCashflow,
      failedTitle: l10n.cashflowLoadFailedTitle,
      skeleton: const MmSkeleton.text(lines: 6),
      builder: (months) {
        final moneyIn = Money.sum([for (final m in months) m.received]);
        final moneyOut = Money.sum([
          for (final m in months) m.expenses + m.depositRefunds,
        ]);
        if (!moneyIn.isPositive && !moneyOut.isPositive) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmSectionHeader(title: l10n.cashflowSection),
              const SizedBox(height: MmSpace.s2),
              Text(
                l10n.cashflowEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmCard(
              child: MmBarChart(
                title: l10n.cashflowSection,
                groupLabel: l10n.monthColumn,
                semanticSummary: l10n.cashflowSummary(
                  monthLabel(context, months.first.month),
                  monthLabel(context, months.last.month),
                  spokenFigure(context, moneyIn),
                  spokenFigure(context, moneyOut),
                ),
                // Two independent measures, side by side: money in at the
                // start edge, solid, and money out beside it, outlined.
                arrangement: MmBarArrangement.sideBySide,
                series: [
                  MmBarSeries(label: l10n.moneyInSeries),
                  MmBarSeries(label: l10n.moneyOutSeries),
                ],
                groups: [
                  for (final month in months)
                    MmBarGroup(
                      label: shortMonthLabel(context, month.month),
                      values: [
                        month.received,
                        month.expenses + month.depositRefunds,
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: MmSpace.s3),
            MmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MmDetailRow.amount(label: l10n.totalInLabel, amount: moneyIn),
                  MmDetailRow.amount(
                    label: l10n.totalOutLabel,
                    amount: moneyOut,
                  ),
                  MmDetailRow.amount(
                    label: l10n.netLabel,
                    amount: moneyIn - moneyOut,
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Each property's income, expenses, occupancy and yields (INS-05).
class _Performance extends ConsumerWidget {
  const new({required this.span});

  final ReportSpan span;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = performanceProvider(span);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.performanceSection),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingPerformance,
          failedTitle: l10n.performanceLoadFailedTitle,
          builder: (properties) {
            if (properties.isEmpty) {
              return Text(
                l10n.performanceEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              );
            }
            final best = properties.reduce(
              (a, b) => b.netOperatingIncome > a.netOperatingIncome ? b : a,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (properties.length > 1) ...[
                  MmCard(
                    child: MmBarChart(
                      title: l10n.noiChartTitle,
                      groupLabel: l10n.propertyLabel,
                      groupKind: MmBarGroupKind.names,
                      semanticSummary: l10n.noiChartSummary(
                        best.propertyName,
                        spokenFigure(context, best.netOperatingIncome),
                      ),
                      series: [MmBarSeries(label: l10n.noiLabel)],
                      groups: [
                        for (final property in properties)
                          MmBarGroup(
                            label: property.propertyName,
                            values: [property.netOperatingIncome],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MmSpace.s3),
                ],
                for (final (index, property) in properties.indexed) ...[
                  if (index > 0) const SizedBox(height: MmSpace.s3),
                  PerformanceCard(property: property),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One property's figures over the report's span.
class PerformanceCard extends StatelessWidget {
  const new({required this.property, super.key});

  final PropertyPerformance property;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final colors = context.mm.colors;
    final gross = property.grossYield;
    final net = property.netYield;
    return MmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              property.propertyName,
              style: context.mm.styleFor(
                property.propertyName,
                text.titleMedium!,
              ),
            ),
          ),
          const SizedBox(height: MmSpace.s2),
          MmDetailRow(
            label: l10n.unitsLetLabel,
            value: l10n.unitsLetValue(
              '${property.occupiedUnits}',
              '${property.units}',
            ),
            userData: false,
          ),
          MmDetailRow.amount(
            label: l10n.rentIncomeLabel,
            amount: property.rentIncome,
          ),
          MmDetailRow.amount(
            label: l10n.otherIncomeLabel,
            amount: property.otherIncome,
          ),
          MmDetailRow.amount(
            label: l10n.propertyExpensesLabel,
            amount: property.expenses,
          ),
          MmDetailRow.amount(
            label: l10n.noiLabel,
            amount: property.netOperatingIncome,
            emphasized: true,
          ),
          if (gross != null && net != null) ...[
            MmDetailRow(
              label: l10n.grossYieldLabel,
              value: l10n.yieldValue(percentText(l10n, gross, decimals: 1)),
              userData: false,
            ),
            MmDetailRow(
              label: l10n.netYieldLabel,
              value: l10n.yieldValue(percentText(l10n, net, decimals: 1)),
              userData: false,
            ),
          ] else ...[
            const SizedBox(height: MmSpace.s2),
            Text(
              l10n.noYieldHelp,
              style: text.bodyMedium!.copyWith(color: colors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The current tenants' payment scores (INS-03), the lowest first.
class _Scores extends ConsumerWidget {
  const new({required this.portfolio});

  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = paymentFactsProvider(portfolio.id);
    // The tenants' names come from the who-owes-what list (every active
    // tenancy, and any that still owes or holds credit): until it is read,
    // or when it cannot be, the scores cannot be named.
    final receivablesOf = receivablesProvider(portfolio);
    final receivables = ref.watch(receivablesOf);
    final today = ref.watch(todayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.scoresSection, subtitle: l10n.scoresHelp),
        const SizedBox(height: MmSpace.s2),
        SnapshotView(
          state: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          loadingLabel: l10n.loadingScores,
          failedTitle: l10n.scoresLoadFailedTitle,
          builder: (facts) {
            final tenants = receivables.value?.value;
            if (tenants == null) {
              if (receivables.error case final error?) {
                return MmErrorState(
                  title: l10n.scoresLoadFailedTitle,
                  message: failureMessage(l10n, AppFailure.from(error)),
                  onRetry: () => ref.invalidate(receivablesOf),
                );
              }
              return Semantics(
                container: true,
                label: l10n.loadingScores,
                child: const MmSkeletonList(itemCount: 4),
              );
            }
            final names = {for (final r in tenants) r.tenantId: r.tenantName};
            final scores =
                [
                  for (final MapEntry(key: tenantId, value: score)
                      in paymentScores(facts, today).entries)
                    if (names[tenantId] case final name?)
                      (tenantId, name, score),
                ]..sort((a, b) {
                  final score = a.$3.score.compareTo(b.$3.score);
                  return score != 0 ? score : a.$2.compareTo(b.$2);
                });
            if (scores.isEmpty) {
              return Text(
                l10n.scoresEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              );
            }
            return ListCard(
              children: [
                for (final (tenantId, name, score) in scores)
                  MmListTile(
                    leading: MmAvatar(name: name),
                    title: name,
                    subtitle: detailLine(scoreLines(context, score)),
                    subtitleMaxLines: 6,
                    trailing: BelowText(child: scoreBadge(context, score)),
                    onTap: () => context.go(Routes.tenant(tenantId)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A payment score as a badge: its band's colour and icon, with the
/// score.
MmStatusBadge scoreBadge(BuildContext context, PaymentScore score) {
  final l10n = AppLocalizations.of(context);
  return MmStatusBadge(
    status: switch (MmScoreBand.of(score.score)) {
      MmScoreBand.good => MmStatus.paid,
      MmScoreBand.fair => MmStatus.dueSoon,
      MmScoreBand.poor => MmStatus.overdue,
    },
    label: l10n.scoreValue('${score.score}'),
  );
}

/// What a payment score is made of, in words: its band, the dues paid on
/// time, the average days late and what is overdue.
List<String> scoreLines(BuildContext context, PaymentScore score) {
  final l10n = AppLocalizations.of(context);
  return [
    scoreBandLabel(l10n, MmScoreBand.of(score.score)),
    l10n.scoreOnTime('${score.onTime}', '${score.duesCounted}'),
    averageLateText(l10n, score),
    if (score.arrears.isPositive)
      l10n.scoreArrears(tenthsText(score.arrearsMonths))
    else
      l10n.scoreNoArrears,
  ];
}

/// The tax-year statement, the owner statement and the exports.
class _Statements extends StatelessWidget {
  const new({required this.portfolio});

  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.statementsSection),
        const SizedBox(height: MmSpace.s2),
        ListCard(
          children: [
            MmListTile(
              leading: const Icon(MmIcons.receiptText),
              title: l10n.taxYearTitle,
              subtitle: l10n.taxYearSummary,
              subtitleMaxLines: null,
              userData: false,
              chevron: true,
              onTap: () => context.go(Routes.taxYear),
            ),
            MmListTile(
              leading: const Icon(MmIcons.document),
              title: l10n.ownerStatementTitle,
              subtitle: l10n.ownerStatementSummary,
              subtitleMaxLines: null,
              userData: false,
              chevron: true,
              onTap: () => showOwnerStatement(context, portfolio),
            ),
            MmListTile(
              leading: const Icon(MmIcons.spreadsheet),
              title: l10n.exportTitle,
              subtitle: l10n.exportSummary,
              subtitleMaxLines: null,
              userData: false,
              chevron: true,
              onTap: () => showExport(context, portfolio),
            ),
          ],
        ),
      ],
    );
  }
}
