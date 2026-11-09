import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/features/operations/application/expenses.dart';
import 'package:maalik_e_makaan/src/features/operations/application/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Maintenance (MAINT-01): the repairs still to be done (or those closed),
/// the latest reported first, 50 at a time, each leading to its details.
/// Owners and managers add them.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _pending = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    return MmPage(
      title: l10n.maintenanceTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MmFilterChips<bool>(
            multiSelect: false,
            options: [
              MmFilterOption(value: true, label: l10n.filterToDo),
              MmFilterOption(value: false, label: l10n.filterClosed),
            ],
            selected: {_pending},
            onChanged: (selected) {
              if (selected.isNotEmpty) {
                setState(() => _pending = selected.single);
              }
            },
          ),
          const SizedBox(height: MmSpace.s4),
          if (portfolio != null)
            _RequestList(list: (portfolioId: portfolio.id, pending: _pending)),
        ],
      ),
      bottomBar: portfolio != null && portfolio.role.runsProperties
          ? MmActionBar(
              primary: MmButton(
                label: l10n.addRequestAction,
                icon: MmIcons.add,
                onPressed: () => context.go(Routes.newMaintenance()),
              ),
            )
          : null,
    );
  }
}

class _RequestList extends ConsumerWidget {
  const new({required this.list});

  final MaintenanceList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = maintenanceListProvider(list);
    return SnapshotView(
      state: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      loadingLabel: l10n.loadingMaintenance,
      failedTitle: l10n.maintenanceLoadFailedTitle,
      builder: (page) {
        if (page.items.isEmpty) {
          return list.pending
              ? MmEmptyState(
                  icon: MmIcons.maintenance,
                  title: l10n.maintenanceEmptyTitle,
                  message: l10n.maintenanceEmptyBody,
                )
              : MmEmptyState(
                  icon: MmIcons.history,
                  title: l10n.maintenanceClosedEmptyTitle,
                  message: l10n.maintenanceClosedEmptyBody,
                );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListCard(
              children: [
                for (final request in page.items)
                  MaintenanceTile(request: request),
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

/// A request in a list: what, where, since when, and where it stands; a
/// job still to be done that is urgent or high priority says so in a badge
/// beside its status, where the eye scanning the list finds it.
class MaintenanceTile extends StatelessWidget {
  const new({required this.request, super.key});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final urgency = request.status.pending
        ? priorityBadge(context, request.priority)
        : null;
    return MmListTile(
      leading: const Icon(MmIcons.maintenance),
      title: request.title,
      subtitle: appText(
        detailLine([
          l10n.maintenanceCategory(request.category),
          if (urgency == null)
            l10n.priorityNamed(l10n.maintenancePriority(request.priority)),
          placeLabel(context, request.propertyName, request.unitLabel),
          l10n.reportedOn(dateInLine(context, request.reportedOn)),
        ]),
        direction,
      ),
      subtitleMaxLines: null,
      trailing: BelowText(
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: MmSpace.s2,
          runSpacing: MmSpace.s2,
          children: [maintenanceBadge(context, request.status), ?urgency],
        ),
      ),
      onTap: () => context.go(Routes.maintenanceRequest(request.id)),
    );
  }
}

/// A badge saying how urgent a repair is; null for the usual priorities.
MmStatusBadge? priorityBadge(BuildContext context, MaintenancePriority p) {
  final l10n = AppLocalizations.of(context);
  final label = l10n.priorityNamed(l10n.maintenancePriority(p));
  return switch (p) {
    MaintenancePriority.urgent => MmStatusBadge(
      status: MmStatus.overdue,
      icon: MmIcons.warning,
      label: label,
    ),
    MaintenancePriority.high => MmStatusBadge(
      status: MmStatus.dueSoon,
      icon: MmIcons.warning,
      label: label,
    ),
    MaintenancePriority.medium || MaintenancePriority.low => null,
  };
}

/// One repair: where it stands and how urgent it is, its details, what was
/// spent on it, its photos ([extras]), and for owners and managers, moving
/// it along, editing and deleting it.
class MaintenanceDetailScreen extends ConsumerWidget {
  const new({required this.requestId, this.extras, super.key});

  final String requestId;

  /// Content from other features (the request's photos and invoices).
  final Widget Function(MaintenanceRequest request)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(maintenanceRequestProvider(requestId));
    final request = state.value?.value;
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final role = portfolio?.role;
    final runs = role?.runsProperties ?? false;
    final extras = this.extras;
    return MmPage(
      title: request?.title ?? l10n.maintenanceTitle,
      actions: [
        if (request != null && runs)
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editMaintenance(requestId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(maintenanceRequestProvider(requestId)),
        loadingLabel: l10n.loadingMaintenanceRequest,
        failedTitle: l10n.maintenanceRequestLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (request) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: MmSpace.s2,
              runSpacing: MmSpace.s2,
              children: [
                maintenanceBadge(context, request.status),
                ?priorityBadge(context, request.priority),
              ],
            ),
            const SizedBox(height: MmSpace.s4),
            _RequestDetails(request: request),
            if (runs) ...[
              const SizedBox(height: MmSpace.s6),
              _StatusActions(request: request),
            ],
            if (portfolio != null) ...[
              const SizedBox(height: MmSpace.s8),
              _JobExpenses(request: request, portfolio: portfolio),
            ],
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(request),
            ],
            if (runs && portfolio != null) ...[
              const SizedBox(height: MmSpace.s8),
              _DeleteRequest(request: request, portfolio: portfolio),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestDetails extends ConsumerWidget {
  const new({required this.request});

  final MaintenanceRequest request;

  Future<void> _call(
    BuildContext context,
    WidgetRef ref,
    PhoneNumber phone,
  ) async {
    final l10n = AppLocalizations.of(context);
    final opened = await ref.read(linkOpenerProvider)(
      Uri(scheme: 'tel', path: phone.e164),
    );
    if (!opened && context.mounted) {
      await showMmSnackbar(
        context,
        message: l10n.callFailed,
        tone: MmBannerTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final lease = request.leaseId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.maintenanceCategoryLabel,
                value: l10n.maintenanceCategory(request.category),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.priorityLabel,
                value: l10n.maintenancePriority(request.priority),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.propertyLabel,
                value: request.propertyName,
              ),
              if (request.unitLabel case final unit?)
                MmDetailRow(label: l10n.unitLabel, value: unit),
              MmDetailRow(
                label: l10n.reportedOnLabel,
                value: dateLabel(context, request.reportedOn),
                userData: false,
              ),
              if (request.reportedBy case final name?)
                MmDetailRow(label: l10n.reportedByLabel, value: name),
              if (request.assignedTo case final name?)
                MmDetailRow(label: l10n.assignedToLabel, value: name),
              if (request.vendorPhone case final phone?)
                MmDetailRow(
                  label: l10n.vendorPhoneLabel,
                  value: phoneLabel(phone, direction),
                  action: IconButton(
                    tooltip: l10n.callAction,
                    icon: const Icon(MmIcons.phone),
                    onPressed: () => _call(context, ref, phone),
                  ),
                ),
              if (request.estimatedCost case final estimate?)
                MmDetailRow.amount(label: l10n.estimateLabel, amount: estimate),
              if (request.resolvedOn case final date?)
                MmDetailRow(
                  label: l10n.resolvedOnLabel,
                  value: dateLabel(context, date),
                  userData: false,
                ),
              if (request.description case final text?)
                MmDetailRow.prose(label: l10n.descriptionLabel, value: text),
              if (request.resolutionNote case final note?)
                MmDetailRow.prose(label: l10n.resolutionLabel, value: note),
            ],
          ),
        ),
        if (lease != null) ...[
          const SizedBox(height: MmSpace.s3),
          ListCard(
            children: [
              MmListTile(
                leading: const Icon(MmIcons.lease),
                title: l10n.openTenancyAction,
                subtitle: request.tenantName,
                chevron: true,
                onTap: () => context.go(Routes.lease(lease)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Moving a request along its workflow: starting, holding, resolving,
/// cancelling or reopening it.
class _StatusActions extends ConsumerStatefulWidget {
  const new({required this.request});

  final MaintenanceRequest request;

  @override
  ConsumerState<_StatusActions> createState() => _StatusActionsState();
}

class _StatusActionsState extends ConsumerState<_StatusActions>
    with CommandState {
  Future<void> _move(MaintenanceStatus status) async {
    final l10n = AppLocalizations.of(context);
    final request = widget.request;
    final done = await runCommand(
      () => ref
          .read(maintenanceRequestProvider(request.id).notifier)
          .move(MaintenanceMove(status)),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.requestMoved(l10n.maintenanceStatus(status)),
        tone: MmBannerTone.success,
      ),
    );
  }

  /// Cancels the job once the landlord has confirmed it: it closes the job,
  /// which a slip of the thumb should not do.
  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.cancelRequestTitle,
      message: l10n.cancelRequestBody,
      confirmLabel: l10n.closeAsCancelledAction,
      // "Cancel" beside cancelling the repair would be ambiguous.
      cancelLabel: l10n.keepRepairAction,
    );
    if (!confirmed || !mounted) return;
    await _move(MaintenanceStatus.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final status = widget.request.status;
    final buttons = <Widget>[
      if (status == MaintenanceStatus.open)
        MmButton(
          label: l10n.startWorkAction,
          icon: MmIcons.maintenance,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : () => _move(MaintenanceStatus.inProgress),
        ),
      if (status == MaintenanceStatus.onHold)
        MmButton(
          label: l10n.resumeWorkAction,
          icon: MmIcons.maintenance,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : () => _move(MaintenanceStatus.inProgress),
        ),
      if (status.pending)
        MmButton(
          label: l10n.markResolvedAction,
          icon: MmIcons.check,
          variant: MmButtonVariant.secondary,
          onPressed: busy
              ? null
              : () => showMmSheet<void>(
                  context,
                  title: l10n.markResolvedAction,
                  builder: (_) => ResolveSheet(request: widget.request),
                ),
        ),
      if (status == MaintenanceStatus.open ||
          status == MaintenanceStatus.inProgress)
        MmButton(
          label: l10n.putOnHoldAction,
          icon: MmIcons.history,
          variant: MmButtonVariant.secondary,
          onPressed: busy ? null : () => _move(MaintenanceStatus.onHold),
        ),
      if (status.pending)
        MmButton(
          label: l10n.cancelRequestAction,
          icon: MmIcons.close,
          // It asks first (or opens the flow that does): the filled red
          // button is at the point of no return.
          variant: MmButtonVariant.destructiveOutlined,
          onPressed: busy ? null : _cancel,
        )
      else
        MmButton(
          label: l10n.reopenAction,
          icon: MmIcons.undo,
          variant: MmButtonVariant.secondary,
          busy: busy,
          onPressed: () => _move(MaintenanceStatus.open),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        for (final (index, button) in buttons.indexed) ...[
          if (index > 0) const SizedBox(height: MmSpace.s3),
          button,
        ],
      ],
    );
  }
}

/// Closing a repair as resolved: when, and how.
class ResolveSheet extends ConsumerStatefulWidget {
  const new({required this.request, super.key});

  final MaintenanceRequest request;

  @override
  ConsumerState<ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends ConsumerState<ResolveSheet> with CommandState {
  late CalendarDate _on = dates.today(context);
  late final _note = TextEditingController(text: widget.request.resolutionNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final l10n = AppLocalizations.of(context);
    final request = widget.request;
    final done = await runCommand(
      () => ref
          .read(maintenanceRequestProvider(request.id).notifier)
          .move(
            MaintenanceMove(
              MaintenanceStatus.resolved,
              resolvedOn: _on,
              resolutionNote: _note.text,
            ),
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.requestResolved,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final today = dates.today(context);
    final reported = widget.request.reportedOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmDateField(
          label: l10n.resolvedOnLabel,
          value: _on,
          required: true,
          firstDate: reported.isAfter(today) ? today : reported,
          lastDate: today,
          onChanged: (date) {
            if (date != null) setState(() => _on = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.resolutionLabel,
          controller: _note,
          optional: true,
          helper: l10n.resolutionHelp,
          minLines: 2,
          maxLines: 6,
          maxLength: MaintenanceRequest.maxResolutionLength,
          inputFormatters: codePointLimit(
            MaintenanceRequest.maxResolutionLength,
          ),
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.markResolvedAction,
          busy: busy,
          onPressed: _resolve,
        ),
      ],
    );
  }
}

/// What was spent on the job, against its estimate, and the way to add an
/// expense for it.
class _JobExpenses extends ConsumerWidget {
  const new({required this.request, required this.portfolio});

  final MaintenanceRequest request;
  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final list = (portfolioId: portfolio.id, requestId: request.id);
    final page = ref.watch(expensesProvider(list)).value?.value;
    final adds = portfolio.role.recordsOperations;
    final estimate = request.estimatedCost;
    final spent = page == null || page.hasMore
        ? null
        : Money.sum([for (final e in page.items) e.amount]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.jobExpensesSection,
          subtitle: spent == null || spent.isZero
              ? null
              : estimate == null
              ? l10n.spentSoFar(money.format(spent))
              : l10n.spentOfEstimate(
                  money.format(spent),
                  money.format(estimate),
                ),
          actionLabel: adds ? l10n.addExpenseAction : null,
          onAction: adds
              ? () => context.go(Routes.newExpense(requestId: request.id))
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        ExpensesList(
          list: list,
          empty: Text(
            l10n.jobExpensesEmpty,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

/// Deleting a request entered by mistake. One with expenses recorded
/// against it cannot be deleted (`request_has_expenses`), so instead of a
/// button that would only be refused after its confirmation, it says why
/// and what to do: cancel the job, or delete those expenses first.
class _DeleteRequest extends ConsumerStatefulWidget {
  const new({required this.request, required this.portfolio});

  final MaintenanceRequest request;
  final PortfolioMembership portfolio;

  @override
  ConsumerState<_DeleteRequest> createState() => _DeleteRequestState();
}

class _DeleteRequestState extends ConsumerState<_DeleteRequest>
    with CommandState {
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final title = inSentence(widget.request.title, Directionality.of(context));
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteRequestTitle(title),
      message: l10n.deleteRequestBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => ref
          .read(maintenanceRequestProvider(widget.request.id).notifier)
          .delete(),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.requestDeleted,
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.maintenance);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final expenses = ref
        .watch(
          expensesProvider((
            portfolioId: widget.portfolio.id,
            requestId: widget.request.id,
          )),
        )
        .value
        ?.value;
    if (expenses != null && expenses.items.isNotEmpty) {
      return Text(
        widget.request.status.pending
            ? l10n.reasonRequestHasExpenses
            : l10n.requestHasExpensesClosed,
        style: Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: context.mm.colors.inkMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmButton(
          label: l10n.deleteAction,
          icon: MmIcons.delete,
          // It asks first (or opens the flow that does): the filled red
          // button is at the point of no return.
          variant: MmButtonVariant.destructiveOutlined,
          busy: busy,
          onPressed: _delete,
        ),
      ],
    );
  }
}
