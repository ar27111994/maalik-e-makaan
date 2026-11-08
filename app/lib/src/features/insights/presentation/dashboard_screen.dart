import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insight_rules.dart';
import 'package:maalik_e_makaan/src/features/insights/application/insights.dart';
import 'package:maalik_e_makaan/src/features/insights/data/dashboard.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_card.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/insight_labels.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/reminders/presentation/reminder_sheet.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The Dashboard section (INS-01, INS-04): this month's collection, what
/// needs attention (the insight cards), what tenants owe by age and who
/// owes most (with one-tap remind and record-payment, INS-02), what falls
/// due soon, the vacant units, and the deposits, tax and expenses. It
/// reads the portfolio in one round trip (`get_dashboard`); the cash and
/// rent-roll cards follow from a second read.
class DashboardScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    return MmPage(
      title: l10n.navDashboard,
      actions: [
        IconButton(
          tooltip: l10n.searchAction,
          icon: const Icon(MmIcons.search),
          onPressed: () => context.go(Routes.search),
        ),
        IconButton(
          tooltip: l10n.reportsTitle,
          icon: const Icon(MmIcons.reports),
          onPressed: () => context.go(Routes.reports),
        ),
      ],
      body: portfolio == null
          ? const SizedBox.shrink()
          : _Dashboard(portfolio: portfolio),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const new({required this.portfolio});

  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = dashboardProvider(portfolio);
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingDashboard,
      failedTitle: l10n.dashboardLoadFailedTitle,
      builder: (dashboard) => dashboard.occupancy.units == 0
          ? _NothingToLet(dashboard: dashboard, portfolio: portfolio)
          // Who owes what first (DESIGN.md), then what needs attention,
          // then what falls due.
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Month(dashboard: dashboard),
                const SizedBox(height: MmSpace.s8),
                _Owed(dashboard: dashboard, role: portfolio.role),
                const SizedBox(height: MmSpace.s8),
                _Insights(dashboard: dashboard, portfolioId: portfolio.id),
                const SizedBox(height: MmSpace.s8),
                _Upcoming(dashboard: dashboard),
                if (dashboard.vacantUnits.isNotEmpty) ...[
                  const SizedBox(height: MmSpace.s8),
                  _Vacant(units: dashboard.vacantUnits),
                ],
                const SizedBox(height: MmSpace.s8),
                _HeldAndSpent(dashboard: dashboard),
              ],
            ),
    );
  }
}

/// A portfolio with no unit yet: nothing falls due, so in place of a page
/// of zeros, the next step (for those who may take it), and any insight
/// that still applies (expenses already recorded).
class _NothingToLet extends StatelessWidget {
  const new({required this.dashboard, required this.portfolio});

  final Dashboard dashboard;
  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final noProperties = dashboard.counts.properties == 0;
    final mayAdd = portfolio.role.runsProperties;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmEmptyState(
          icon: MmIcons.property,
          title: noProperties
              ? l10n.dashboardNoPropertiesTitle
              : l10n.dashboardNoUnitsTitle,
          message: switch ((noProperties, mayAdd)) {
            (true, true) => l10n.dashboardNoPropertiesBody,
            (true, false) => l10n.dashboardNoPropertiesViewer,
            (false, true) => l10n.dashboardNoUnitsBody,
            (false, false) => l10n.dashboardNoUnitsViewer,
          },
          actionLabel: !mayAdd
              ? null
              : noProperties
              ? l10n.addPropertyAction
              : l10n.seePropertiesAction,
          onAction: !mayAdd
              ? null
              : () => context.go(
                  noProperties ? Routes.newProperty : Routes.properties,
                ),
        ),
        _Insights(
          dashboard: dashboard,
          portfolioId: portfolio.id,
          hiddenWhenEmpty: true,
        ),
      ],
    );
  }
}

/// This month: collected against due, overdue against owed, units let.
class _Month extends StatelessWidget {
  const new({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final month = dashboard.month;
    final occupancy = dashboard.occupancy;
    final lettable = occupancy.units - occupancy.unavailable;
    final rate = month.collectionRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.thisMonthSection(monthLabel(context, month.period)),
        ),
        const SizedBox(height: MmSpace.s2),
        MmResponsiveGrid(
          minItemWidth: MediaQuery.textScalerOf(context).scale(200),
          children: [
            MmStatTile(
              label: l10n.collectedThisMonthLabel,
              value: MmAmount(amount: month.paid, size: MmAmountSize.large),
              caption: Text(
                rate == null
                    ? l10n.nothingDueThisMonth
                    : l10n.collectedOfDue(
                        moneyText(context, month.expected),
                        percentText(l10n, rate),
                      ),
              ),
            ),
            MmStatTile(
              label: l10n.totalOverdueLabel,
              value: MmAmount(amount: dashboard.outstanding.overdue),
              caption: Text(
                l10n.owedInAll(moneyText(context, dashboard.outstanding.total)),
              ),
            ),
            MmStatTile(
              label: l10n.unitsLetLabel,
              value: Text(
                lettable > 0
                    ? l10n.unitsLetValue('${occupancy.occupied}', '$lettable')
                    : l10n.noUnitsToLet,
                style: MmSemantics.withTabularFigures(text.titleLarge!),
              ),
              caption: occupancy.rate == null
                  ? null
                  : Text(
                      l10n.occupancyCaption(
                        percentText(l10n, occupancy.rate!),
                        occupancy.vacant,
                      ),
                    ),
            ),
          ],
        ),
        // Nothing due yet: the figure above says so, with nothing to split.
        if (month.expected.isPositive) ...[
          const SizedBox(height: MmSpace.s4),
          MmCard(
            child: MmProportionBar(
              semanticSummary: l10n.monthBarSummary(
                spokenFigure(context, month.expected),
                spokenFigure(context, month.paid),
              ),
              segments: [
                MmProportionSegment(
                  label: l10n.chargePaid,
                  value: month.paid,
                  tone: MmSegmentTone.paid,
                ),
                MmProportionSegment(
                  label: l10n.stillToCollect,
                  value: month.unpaid,
                  tone: MmSegmentTone.neutral,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The insight cards, the most pressing first: the first [shown], and
/// the rest a tap away, so the money owed stays near the top.
class _Insights extends ConsumerStatefulWidget {
  const new({
    required this.dashboard,
    required this.portfolioId,
    this.hiddenWhenEmpty = false,
  });

  final Dashboard dashboard;
  final String portfolioId;

  /// Whether the section is left out when there is nothing to say.
  final bool hiddenWhenEmpty;

  /// How many cards show before "Show all".
  static const shown = 3;

  @override
  ConsumerState<_Insights> createState() => _InsightsState();
}

class _InsightsState extends ConsumerState<_Insights> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The cards that need more than the dashboard join once it is read;
    // until then (or when it cannot be read) the others stand alone.
    final extras = ref
        .watch(insightExtrasProvider(widget.portfolioId))
        .value
        ?.value;
    final insights = insightsFor(
      widget.dashboard,
      positions: extras?.positions,
      rentRoll: extras?.rentRoll,
    );
    if (insights.isEmpty && widget.hiddenWhenEmpty) {
      return const SizedBox.shrink();
    }
    final capped = insights.length > _Insights.shown;
    final visible = capped && !_all ? insights.take(_Insights.shown) : insights;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hiddenWhenEmpty) const SizedBox(height: MmSpace.s8),
        MmSectionHeader(title: l10n.insightsSection),
        const SizedBox(height: MmSpace.s2),
        if (insights.isEmpty)
          Text(l10n.noInsights, style: Theme.of(context).textTheme.bodyLarge)
        else
          for (final (index, insight) in visible.indexed) ...[
            if (index > 0) const SizedBox(height: MmSpace.s3),
            InsightCard(insight),
          ],
        if (capped) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: _all
                ? l10n.insightsShowFewer
                : l10n.insightsShowAll(insights.length),
            icon: _all ? MmIcons.collapse : MmIcons.expand,
            variant: MmButtonVariant.secondary,
            onPressed: () => setState(() => _all = !_all),
          ),
        ],
      ],
    );
  }
}

/// What is owed by age, and the tenancies owing most.
class _Owed extends StatelessWidget {
  const new({required this.dashboard, required this.role});

  final Dashboard dashboard;
  final MemberRole role;

  /// How many of the tenancies owing most the dashboard lists.
  static const shown = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owed = dashboard.outstanding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.owedSection,
          subtitle: owed.total.isPositive
              ? l10n.owedSectionHelp(moneyText(context, owed.total))
              : null,
          actionLabel: l10n.seeAllAction,
          onAction: () => context.go(Routes.money),
        ),
        const SizedBox(height: MmSpace.s2),
        if (!owed.total.isPositive)
          Text(l10n.nobodyOwes, style: Theme.of(context).textTheme.bodyLarge)
        else ...[
          MmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The four buckets INS-01 asks for, after what is not yet
                // due, each in its own overdue tone.
                MmProportionBar(
                  semanticSummary: l10n.ageingSummary(
                    spokenFigure(context, owed.total),
                    spokenFigure(context, owed.notDue),
                    spokenFigure(context, owed.days1to30),
                    spokenFigure(context, owed.days31to60),
                    spokenFigure(context, owed.days61to90),
                    spokenFigure(context, owed.over90),
                  ),
                  segments: [
                    MmProportionSegment(
                      label: l10n.ageNotDue,
                      value: owed.notDue,
                      tone: MmSegmentTone.neutral,
                    ),
                    MmProportionSegment(
                      label: l10n.age1to30,
                      value: owed.days1to30,
                      tone: MmSegmentTone.dueSoon,
                    ),
                    MmProportionSegment(
                      label: l10n.age31to60,
                      value: owed.days31to60,
                      tone: MmSegmentTone.overdue,
                    ),
                    MmProportionSegment(
                      label: l10n.age61to90,
                      value: owed.days61to90,
                      tone: MmSegmentTone.overdueOlder,
                    ),
                    MmProportionSegment(
                      label: l10n.ageOver90,
                      value: owed.over90,
                      tone: MmSegmentTone.overdueSevere,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (dashboard.topArrears.isNotEmpty) ...[
            const SizedBox(height: MmSpace.s6),
            MmSectionHeader(title: l10n.owingMostSection),
            const SizedBox(height: MmSpace.s2),
            for (final (index, arrear)
                in dashboard.topArrears.take(shown).indexed) ...[
              if (index > 0) const SizedBox(height: MmSpace.s3),
              ArrearCard(arrear: arrear, role: role),
            ],
          ],
        ],
      ],
    );
  }
}

/// A tenancy owing rent, with one tap to remind the tenant on WhatsApp or
/// record what they paid (INS-02). The tenancy's ledger opens from its
/// row.
class ArrearCard extends StatelessWidget {
  const new({required this.arrear, required this.role, super.key});

  final Arrear arrear;
  final MemberRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final money = MmFormats.moneyOf(context);
    final paidOn = arrear.lastPaidOn;
    final reminded = arrear.lastRemindedAt;
    return MmCard(
      padding: EdgeInsetsDirectional.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmListTile(
            leading: MmAvatar(name: arrear.tenantName),
            title: arrear.tenantName,
            subtitle: appText(
              detailLine([
                l10n.unitAtProperty(
                  inSentence(arrear.unitLabel, direction),
                  inSentence(arrear.propertyName, direction),
                ),
                if (paidOn != null)
                  l10n.lastPaidOn(dateInLine(context, paidOn)),
                if (reminded != null)
                  l10n.lastRemindedOn(momentLabel(context, reminded)),
              ]),
              direction,
            ),
            subtitleMaxLines: 6,
            trailing: BelowText(
              child: MmStatusBadge(
                status: MmStatus.overdue,
                label: l10n.overdueOldest(
                  money.format(arrear.overdue),
                  arrear.daysOverdue,
                ),
              ),
            ),
            onTap: () => context.go(Routes.ledger(arrear.leaseId)),
          ),
          if (role.recordsMoney)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MmSpace.s4,
                0,
                MmSpace.s4,
                MmSpace.s3,
              ),
              child: Wrap(
                spacing: MmSpace.s2,
                runSpacing: MmSpace.s2,
                children: [
                  MmButton(
                    label: l10n.remindShortAction,
                    icon: MmIcons.reminder,
                    variant: MmButtonVariant.secondary,
                    onPressed: () =>
                        showReminderComposer(context, leaseId: arrear.leaseId),
                  ),
                  MmButton(
                    label: l10n.recordPaymentAction,
                    icon: MmIcons.payment,
                    variant: MmButtonVariant.secondary,
                    onPressed: () =>
                        context.go(Routes.recordPayment(arrear.leaseId)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What is due or was missed, and what falls due soon: tenancies ending,
/// rent increases, police registration and CNICs, by date. Each row opens
/// the tenancy or tenant it is about.
class _Upcoming extends StatelessWidget {
  const new({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = upcomingOf(context, dashboard);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.upcomingSection),
        const SizedBox(height: MmSpace.s2),
        if (items.isEmpty)
          Text(l10n.upcomingEmpty, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [for (final item in items) UpcomingTile(item: item)],
          ),
      ],
    );
  }
}

/// How pressing a dated item is: its icon's colour, always with words
/// that say the same.
enum UpcomingTone {
  /// Past its date: missed, expired or late.
  late,

  /// Soon.
  soon,

  /// Further off, or waiting on someone else.
  later,
}

/// One dated item of the dashboard: what it is about, in words, and where
/// it leads.
@immutable
final class UpcomingItem {
  const new({
    required this.date,
    required this.icon,
    required this.tone,
    required this.title,
    required this.detail,
    required this.route,
  });

  final CalendarDate date;
  final IconData icon;
  final UpcomingTone tone;

  /// What falls due ("Register Indus Tech with the police").
  final String title;

  /// Its unit and state ("Shop 3: the deadline set by law has passed").
  final String detail;
  final String route;
}

/// A dated item as a row: its icon (coloured as pressing it is), what
/// falls due, then its date and detail; it opens what it is about.
class UpcomingTile extends StatelessWidget {
  const new({required this.item, super.key});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.mm.colors;
    return MmListTile(
      leading: Icon(
        item.icon,
        color: switch (item.tone) {
          UpcomingTone.late => colors.overdue,
          UpcomingTone.soon => colors.dueSoon,
          UpcomingTone.later => null,
        },
      ),
      title: item.title,
      subtitle: detailLine([dateInLine(context, item.date), item.detail]),
      subtitleMaxLines: 6,
      // The app's sentences, the landlord's names isolated inside.
      userData: false,
      chevron: true,
      onTap: () => context.go(item.route),
    );
  }
}

/// The dashboard's dated items, the earliest first.
List<UpcomingItem> upcomingOf(BuildContext context, Dashboard dashboard) {
  final l10n = AppLocalizations.of(context);
  final direction = Directionality.of(context);
  String name(String text) => inSentence(text, direction);
  final dated = <UpcomingItem>[
    for (final lease in dashboard.expiring)
      UpcomingItem(
        date: lease.endDate,
        icon: MmIcons.lease,
        tone: lease.daysLeft <= InsightThresholds.expiringSoonDays
            ? UpcomingTone.soon
            : UpcomingTone.later,
        title: l10n.timelineLeaseEnds(name(lease.tenantName)),
        detail: name(lease.unitLabel),
        route: Routes.lease(lease.leaseId),
      ),
    for (final increment in [
      ...dashboard.incrementsMissed,
      ...dashboard.incrementsUpcoming,
    ])
      UpcomingItem(
        date: increment.anniversary,
        icon: MmIcons.trendUp,
        tone: increment.status == IncrementStatus.missed
            ? UpcomingTone.late
            : UpcomingTone.soon,
        title: increment.status == IncrementStatus.missed
            ? l10n.timelineIncrementMissed(name(increment.tenantName))
            : l10n.timelineIncrementDue(name(increment.tenantName)),
        detail: l10n.timelineIncrementDetail(
          name(increment.unitLabel),
          moneyText(context, increment.currentRent),
          moneyText(context, increment.newRent),
        ),
        route: Routes.lease(increment.leaseId),
      ),
    for (final police in dashboard.police)
      UpcomingItem(
        date: police.deadline,
        icon: MmIcons.police,
        // Submitted: done as far as the landlord can, whatever the date.
        tone: police.status != PoliceStatus.pending
            ? UpcomingTone.later
            : police.pastLegalDeadline
            ? UpcomingTone.late
            : UpcomingTone.soon,
        title: l10n.timelinePolice(name(police.tenantName)),
        detail: police.status != PoliceStatus.pending
            ? l10n.timelinePoliceSubmitted(name(police.unitLabel))
            : police.pastLegalDeadline
            ? l10n.timelinePoliceLegalPassed(name(police.unitLabel))
            : police.rule.statutory
            ? l10n.timelinePoliceLegal(name(police.unitLabel))
            : l10n.timelinePoliceReminder(name(police.unitLabel)),
        route: Routes.lease(police.leaseId),
      ),
    for (final cnic in dashboard.cnic)
      UpcomingItem(
        date: cnic.expiry,
        icon: MmIcons.cnic,
        tone: cnic.expired ? UpcomingTone.late : UpcomingTone.soon,
        title: cnic.expired
            ? l10n.timelineCnicExpired(name(cnic.tenantName))
            : l10n.timelineCnicExpires(name(cnic.tenantName)),
        detail: l10n.timelineCnicHelp,
        route: Routes.tenant(cnic.tenantId),
      ),
  ];
  // Stable: items of one day keep the order above.
  final ordered = [...dated.indexed]
    ..sort((a, b) {
      final day = a.$2.date.compareTo(b.$2.date);
      return day != 0 ? day : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in ordered) item];
}

/// The units that can be let and stand empty, the longest first.
class _Vacant extends StatelessWidget {
  const new({required this.units});

  final List<VacantUnit> units;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.vacantSection),
        const SizedBox(height: MmSpace.s2),
        ListCard(
          children: [
            for (final unit in units)
              MmListTile(
                leading: const Icon(MmIcons.unit),
                title: l10n.unitAtProperty(
                  inSentence(unit.unitLabel, direction),
                  inSentence(unit.propertyName, direction),
                ),
                subtitle: detailLine([
                  l10n.vacantFor(unit.vacantDays),
                  if (unit.askingRent case final rent?)
                    l10n.askingRentValue(moneyText(context, rent)),
                ]),
                subtitleMaxLines: 4,
                userData: false,
                chevron: true,
                onTap: () =>
                    context.go(Routes.unit(unit.propertyId, unit.unitId)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Deposits held and agreed, the tax withheld this month, and this
/// month's expenses beside the recent average.
class _HeldAndSpent extends StatelessWidget {
  const new({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.heldAndSpentSection),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow.amount(
                label: l10n.depositsHeldLabel,
                amount: dashboard.deposits.held,
              ),
              MmDetailRow.amount(
                label: l10n.depositsAgreedLabel,
                amount: dashboard.deposits.agreed,
              ),
              MmDetailRow.amount(
                label: l10n.taxWithheldThisMonthLabel,
                amount: dashboard.month.taxWithheld,
              ),
              MmDetailRow.amount(
                label: l10n.expensesThisMonthLabel,
                amount: dashboard.expensesThisMonth,
              ),
              MmDetailRow.amount(
                label: l10n.expensesAverageLabel,
                amount: dashboard.expensesTrailingAverage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
