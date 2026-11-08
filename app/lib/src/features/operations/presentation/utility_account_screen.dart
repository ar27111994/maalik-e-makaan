import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/prose_row.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/bill_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/reading_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utilities_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// One connection (UTIL-01..03): its numbers and whose name it is in (with
/// the risk that brings), its bills and its meter readings with what was
/// used between them, and for the roles that may, adding bills and
/// readings, editing, archiving and deleting it.
class UtilityAccountScreen extends ConsumerWidget {
  const new({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(utilityAccountProvider(accountId));
    final account = state.value?.value.account;
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final runs = portfolio?.role.runsProperties ?? false;
    return MmPage(
      title: account == null
          ? l10n.utilitiesTitle
          : connectionName(
              context,
              type: account.type,
              provider: account.provider,
              providerOther: account.providerOther,
            ),
      actions: [
        if (account != null && !account.archived && runs)
          IconButton(
            tooltip: l10n.editAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => context.go(Routes.editUtility(accountId)),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(utilityAccountProvider(accountId)),
        loadingLabel: l10n.loadingUtility,
        failedTitle: l10n.utilityLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (detail) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Details(account: detail.account),
            if (portfolio != null) ...[
              const SizedBox(height: MmSpace.s8),
              _Bills(detail: detail, portfolio: portfolio),
              const SizedBox(height: MmSpace.s8),
              _Readings(detail: detail, portfolio: portfolio),
            ],
            if (runs && portfolio != null) ...[
              const SizedBox(height: MmSpace.s8),
              _AccountActions(account: detail.account, role: portfolio.role),
            ],
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const new({required this.account});

  final UtilityAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String yesNo({required bool value}) => value ? l10n.yes : l10n.no;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account.archivedAt case final archivedAt?) ...[
          MmBanner(
            tone: MmBannerTone.info,
            icon: MmIcons.archive,
            message: l10n.archivedBanner(
              dateLabel(context, pakistanDate(archivedAt)),
            ),
          ),
          const SizedBox(height: MmSpace.s4),
        ],
        if (account.inLandlordName) ...[
          MmBanner(tone: MmBannerTone.warning, message: l10n.inYourNameWarning),
          const SizedBox(height: MmSpace.s4),
        ],
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow(
                label: l10n.propertyLabel,
                value: account.propertyName,
              ),
              MmDetailRow(
                label: l10n.unitLabel,
                value: account.unitLabel ?? l10n.wholePropertyOption,
                userData: account.unitLabel != null,
              ),
              if (account.referenceNumber case final number?)
                MmDetailRow(label: l10n.referenceNumberLabel, value: number),
              if (account.customerId case final id?)
                MmDetailRow(label: l10n.customerIdLabel, value: id),
              if (account.meterNumber case final number?)
                MmDetailRow(label: l10n.meterNumberLabel, value: number),
              if (account.accountTitle case final title?)
                MmDetailRow(label: l10n.nameOnBillLabel, value: title),
              MmDetailRow(
                label: l10n.inYourName,
                value: yesNo(value: account.inLandlordName),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.whoPaysLabel,
                value: l10n.responsibility(account.responsibility),
                userData: false,
              ),
              MmDetailRow(
                label: l10n.subMeterLabel,
                value: yesNo(value: account.isSubMeter),
                userData: false,
              ),
              if (account.type == UtilityType.electricity)
                MmDetailRow(
                  label: l10n.protectedLabel,
                  value: yesNo(value: account.isProtectedConsumer),
                  userData: false,
                ),
              if (account.notes case final notes?)
                ProseRow(label: l10n.notesLabel, text: notes),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bills extends ConsumerWidget {
  const new({required this.detail, required this.portfolio});

  final UtilityAccountDetail detail;
  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = detail.account;
    final adds = portfolio.role.recordsOperations && !account.archived;
    final bills = detail.bills;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.billsSection,
          actionLabel: adds ? l10n.addBillAction : null,
          onAction: adds
              ? () => showMmSheet<void>(
                  context,
                  title: l10n.addBillAction,
                  builder: (_) => BillFormSheet(
                    portfolioId: portfolio.id,
                    connection: account.connection,
                  ),
                )
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        if (bills.items.isEmpty)
          Text(l10n.billsEmpty, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [for (final bill in bills.items) BillTile(bill: bill)],
          ),
        if (bills.hasMore)
          LoadMoreButton(
            onLoad: () => ref
                .read(utilityAccountProvider(account.id).notifier)
                .loadMoreBills(),
          ),
      ],
    );
  }
}

class _Readings extends ConsumerWidget {
  const new({required this.detail, required this.portfolio});

  final UtilityAccountDetail detail;
  final PortfolioMembership portfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = detail.account;
    final adds = portfolio.role.recordsOperations && !account.archived;
    final readings = detail.readings;
    final used = consumptionOf(readings.items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.readingsSection,
          subtitle: l10n.readingsHelp,
          actionLabel: adds ? l10n.addReadingAction : null,
          onAction: adds
              ? () => showMmSheet<void>(
                  context,
                  title: l10n.addReadingAction,
                  builder: (_) => ReadingFormSheet(
                    portfolioId: portfolio.id,
                    connection: account.connection,
                  ),
                )
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        if (readings.items.isEmpty)
          Text(l10n.readingsEmpty, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [
              for (final reading in readings.items)
                ReadingTile(
                  reading: reading,
                  consumption: used[reading.id],
                  protected: account.watchesProtectedTariff,
                ),
            ],
          ),
        if (readings.hasMore)
          LoadMoreButton(
            onLoad: () => ref
                .read(utilityAccountProvider(account.id).notifier)
                .loadMoreReadings(),
          ),
      ],
    );
  }
}

/// A reading in a list: the meter's figure, when and why it was read, and
/// what was used since the reading before it and the monthly pace that
/// makes, with a badge when that pace would lose the protected tariff.
/// Like the bills beside it, the row has no chevron: its badge, when it
/// has one, sits under the text.
class ReadingTile extends StatelessWidget {
  const new({
    required this.reading,
    this.consumption,
    this.protected = false,
    super.key,
  });

  final MeterReading reading;
  final Consumption? consumption;

  /// Whether the connection is on the protected tariff.
  final bool protected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final direction = Directionality.of(context);
    final used = consumption;
    final badge = used == null || !protected
        ? null
        : protectedBadge(context, ProtectedTariff.useOf(used.perMonth));
    return MmListTile(
      leading: const Icon(MmIcons.meter),
      title: l10n.readingValue('${reading.reading}'),
      subtitle: appText(
        detailLine([
          dateInLine(context, reading.readOn),
          l10n.readingContext(reading.context),
          if (reading.tenantName case final name?) inSentence(name, direction),
          if (used != null) ...[
            l10n.usedSince('${used.units}', used.days),
            l10n.paceAMonth('${used.perMonth}'),
          ],
        ]),
        direction,
      ),
      subtitleMaxLines: 12,
      trailing: badge == null ? null : BelowText(child: badge),
      onTap: () => context.go(Routes.meterReading(reading.id)),
    );
  }
}

class _AccountActions extends ConsumerStatefulWidget {
  const new({required this.account, required this.role});

  final UtilityAccount account;
  final MemberRole role;

  @override
  ConsumerState<_AccountActions> createState() => _AccountActionsState();
}

class _AccountActionsState extends ConsumerState<_AccountActions>
    with CommandState {
  UtilityAccountController get _controller =>
      ref.read(utilityAccountProvider(widget.account.id).notifier);

  Future<void> _archive({required bool archived}) async {
    final l10n = AppLocalizations.of(context);
    if (archived) {
      final confirmed = await showMmConfirmDialog(
        context,
        title: l10n.archiveConnectionTitle,
        message: l10n.archiveConnectionBody,
        confirmLabel: l10n.archiveAction,
      );
      if (!confirmed || !mounted) return;
    }
    final done = await runCommand(
      () => _controller.archive(archived: archived),
    );
    if (!done || !mounted) return;
    await showMmSnackbar(
      context,
      message: archived ? l10n.connectionArchived : l10n.connectionRestored,
      tone: MmBannerTone.success,
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteConnectionTitle,
      message: l10n.deleteConnectionBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(_controller.delete);
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.connectionDeleted,
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.utilities);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final archived = widget.account.archived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmButton(
          label: archived ? l10n.restoreAction : l10n.archiveAction,
          icon: archived ? MmIcons.restore : MmIcons.archive,
          variant: MmButtonVariant.secondary,
          busy: busy,
          onPressed: () => _archive(archived: !archived),
        ),
        if (widget.role.deletesRecords) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.deleteAction,
            icon: MmIcons.delete,
            variant: MmButtonVariant.tertiary,
            onPressed: busy ? null : _delete,
          ),
        ],
      ],
    );
  }
}
