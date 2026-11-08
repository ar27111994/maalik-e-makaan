import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/prose_row.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/operations/application/places.dart';
import 'package:maalik_e_makaan/src/features/operations/application/utilities.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/operations_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// [text] as units the database holds (`numeric(12,2)`, not negative), or
/// null when it is not.
Hundredths? _unitsOf(String text) {
  final units = Hundredths.tryParse(text);
  if (units == null || units.value < 0) return null;
  return units.compareTo(maxMeterUnits) > 0 ? null : units;
}

/// The error of a units field: empty is fine unless [required].
String? unitsError(
  AppLocalizations l10n,
  String? text, {
  bool required = false,
}) {
  final value = (text ?? '').trim();
  if (value.isEmpty) return required ? l10n.validationRequired : null;
  return _unitsOf(value) == null ? l10n.validationUnits : null;
}

/// [text] as units, or null when it is empty or not a number of units.
Hundredths? parseUnits(String text) =>
    text.trim().isEmpty ? null : _unitsOf(text);

/// Adding a month's bill to a connection, or editing one ([bill]): its
/// amount, due date and units (measured against the protected tariff as
/// they are typed), and, for a new bill, whether it is already paid. The
/// amount of a bill charged to the tenant is fixed: its due on the ledger
/// keeps the amount it was charged at (`update_charge` changes only manual
/// dues), so it is corrected by voiding that due and charging again.
class BillFormSheet extends ConsumerStatefulWidget {
  const new({
    required this.portfolioId,
    required this.connection,
    this.bill,
    super.key,
  });

  final String portfolioId;
  final UtilityConnection connection;
  final UtilityBill? bill;

  @override
  ConsumerState<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends ConsumerState<BillFormSheet>
    with CommandState {
  final _form = GlobalKey<FormState>();
  late final UtilityBill? _old = widget.bill;

  /// The id of this bill, kept for every retry.
  final String _attempt = newUuid();
  late MonthPeriod _month =
      _old?.billingMonth ?? MonthPeriod.of(dates.today(context));
  late Money? _amount = _old?.amount;
  late CalendarDate? _due = _old?.dueDate;
  late final _units = TextEditingController(
    text: _old?.unitsConsumed?.toString(),
  );
  late final _notes = TextEditingController(text: _old?.notes);
  bool _paid = false;
  late CalendarDate _paidOn = dates.today(context);
  BillPayer _paidBy = BillPayer.tenant;
  bool _tried = false;

  @override
  void dispose() {
    _units.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final valid = _form.currentState!.validate();
    final amount = _amount;
    if (!valid || amount == null) return;
    final old = _old;
    final draft = BillDraft(
      billingMonth: _month,
      amount: amount,
      dueDate: _due,
      unitsConsumed: parseUnits(_units.text),
      // Saving an edit leaves whether it is paid alone: that has its own
      // actions.
      paidOn: old == null && _paid ? _paidOn : null,
      paidBy: old == null && _paid ? _paidBy : null,
      notes: _notes.text,
    );
    late UtilityBill saved;
    final done = await runCommand(() async {
      saved = old == null
          ? await ref
                .read(utilityAccountProvider(widget.connection.id).notifier)
                .addBill(
                  id: _attempt,
                  portfolioId: widget.portfolioId,
                  draft: draft,
                )
          : await ref.read(utilityBillProvider(old.id).notifier).save(draft);
    });
    if (!done || !mounted) return;
    // A retry finds the bill its first try stored, which the connection
    // lost: fields changed since then were not saved.
    final earlier = old == null && BillDraft.of(saved) != draft;
    unawaited(
      showMmSnackbar(
        context,
        message: earlier
            ? l10n.savedEarlierUnchanged
            : old == null
            ? l10n.billAdded
            : l10n.billSaved,
        tone: earlier ? MmBannerTone.warning : MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final duplicate = rejectedReason == 'duplicate_bill_month';
    final today = dates.today(context);
    final current = MonthPeriod.of(today);
    final months = [for (var i = 1; i >= -12; i--) current.addMonths(i)];
    final units = parseUnits(_units.text);
    final use = units == null || !widget.connection.watchesProtectedTariff
        ? null
        : ProtectedTariff.useOf(units);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null && !duplicate) FailureBanner(failure: failure),
          if (_old == null)
            MmSelectField<MonthPeriod>(
              label: l10n.billMonthLabel,
              required: true,
              errorText: duplicate ? failureMessage(l10n, failure!) : null,
              options: [
                for (final month in months)
                  MmOption(value: month, label: monthLabel(context, month)),
              ],
              value: _month,
              onChanged: (month) => setState(() {
                _month = month;
                if (duplicate) this.failure = null;
              }),
            )
          else
            MmDetailRow(
              label: l10n.billMonthLabel,
              value: monthLabel(context, _month),
              userData: false,
            ),
          const SizedBox(height: MmSpace.s4),
          if (_old case final old? when old.liveCharge != null) ...[
            MmDetailRow.amount(label: l10n.amountLabel, amount: old.amount),
            const SizedBox(height: MmSpace.s2),
            MmBanner(tone: MmBannerTone.info, message: l10n.billAmountLocked),
          ] else
            MmMoneyField(
              label: l10n.amountLabel,
              value: _amount,
              required: true,
              invalidText: l10n.validationAmount,
              errorText: _tried && _amount == null
                  ? l10n.validationAmount
                  : null,
              onChanged: (amount) => setState(() => _amount = amount),
            ),
          const SizedBox(height: MmSpace.s4),
          MmDateField(
            label: l10n.dueDateLabel,
            value: _due,
            optional: true,
            firstDate: today.addYears(-2),
            lastDate: today.addYears(1),
            onChanged: (date) => setState(() => _due = date),
          ),
          const SizedBox(height: MmSpace.s4),
          MmTextField(
            label: l10n.unitsConsumedLabel,
            controller: _units,
            optional: true,
            helper: widget.connection.watchesProtectedTariff
                ? l10n.protectedUnitsHelp(ProtectedTariff.limit)
                : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            leftToRight: true,
            validator: (value) => unitsError(l10n, value),
            onChanged: (_) => setState(() {}),
          ),
          if (use == ProtectedUse.over || use == ProtectedUse.near) ...[
            const SizedBox(height: MmSpace.s3),
            ProtectedBanner(use: use!),
          ],
          if (_old == null) ...[
            const SizedBox(height: MmSpace.s4),
            MmSwitchTile(
              label: l10n.alreadyPaidLabel,
              value: _paid,
              onChanged: (paid) => setState(() => _paid = paid),
            ),
            if (_paid) ...[
              const SizedBox(height: MmSpace.s4),
              _PaidFields(
                paidOn: _paidOn,
                paidBy: _paidBy,
                onPaidOn: (date) => setState(() => _paidOn = date),
                onPaidBy: (payer) => setState(() => _paidBy = payer),
              ),
            ],
          ],
          const SizedBox(height: MmSpace.s4),
          MmTextField(
            label: l10n.notesLabel,
            controller: _notes,
            optional: true,
            maxLength: UtilityBill.maxNotesLength,
            inputFormatters: codePointLimit(UtilityBill.maxNotesLength),
          ),
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: _old == null ? l10n.addBillAction : l10n.saveAction,
            busy: busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// When a bill was paid, and by whom.
class _PaidFields extends StatelessWidget {
  const new({
    required this.paidOn,
    required this.paidBy,
    required this.onPaidOn,
    required this.onPaidBy,
  });

  final CalendarDate paidOn;
  final BillPayer paidBy;
  final ValueChanged<CalendarDate> onPaidOn;
  final ValueChanged<BillPayer> onPaidBy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = dates.today(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmDateField(
          label: l10n.paidOnLabel,
          value: paidOn,
          required: true,
          firstDate: today.addYears(-2),
          lastDate: today,
          onChanged: (date) {
            if (date != null) onPaidOn(date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<BillPayer>(
          label: l10n.billPaidByLabel,
          required: true,
          options: [
            for (final payer in BillPayer.values)
              MmOption(value: payer, label: l10n.billPayer(payer)),
          ],
          value: paidBy,
          onChanged: onPaidBy,
        ),
      ],
    );
  }
}

/// What a month's units mean for the protected tariff: near the limit, or
/// over it. A [paced] month is one a reading's pace makes, not a bill's.
class ProtectedBanner extends StatelessWidget {
  const new({required this.use, this.paced = false, super.key});

  final ProtectedUse use;
  final bool paced;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const limit = ProtectedTariff.limit;
    return use == ProtectedUse.over
        ? MmBanner(
            tone: MmBannerTone.error,
            message: paced
                ? l10n.pacedOverExplain(limit)
                : l10n.protectedOverExplain(limit),
          )
        : MmBanner(
            tone: MmBannerTone.warning,
            message: paced
                ? l10n.pacedNearExplain(limit)
                : l10n.protectedNearExplain(limit),
          );
  }
}

/// One bill (UTIL-02): where it stands, its amount, units and dates, the
/// tenant's charge it became, and for the roles that may, marking it paid
/// (the screen's one primary action while it is unpaid) or unpaid and
/// billing it to the tenant; then its photos ([extras]), and last,
/// deleting it. Editing is the app bar's pencil, as on the other records.
class BillScreen extends ConsumerWidget {
  const new({required this.billId, this.extras, super.key});

  final String billId;

  /// Content from other features (the bill's photos).
  final Widget Function(UtilityBill bill)? extras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(utilityBillProvider(billId));
    final bill = state.value?.value;
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final role = portfolio?.role;
    final records = role?.recordsOperations ?? false;
    final extras = this.extras;
    return MmPage(
      title: bill == null
          ? l10n.billTitle
          : l10n.billOfMonth(
              connectionNameOf(context, bill.connection),
              monthLabel(context, bill.billingMonth),
            ),
      actions: [
        if (bill != null && portfolio != null && records)
          IconButton(
            tooltip: l10n.editBillAction,
            icon: const Icon(MmIcons.edit),
            onPressed: () => showMmSheet<void>(
              context,
              title: l10n.editBillAction,
              builder: (_) => BillFormSheet(
                portfolioId: portfolio.id,
                connection: bill.connection,
                bill: bill,
              ),
            ),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(utilityBillProvider(billId)),
        loadingLabel: l10n.loadingBill,
        failedTitle: l10n.billLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (bill) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BillDetails(bill: bill),
            if (records) _BillActions(bill: bill),
            if (extras != null) ...[
              const SizedBox(height: MmSpace.s8),
              extras(bill),
            ],
            if (role != null && role.deletesOperations) ...[
              const SizedBox(height: MmSpace.s8),
              _DeleteBill(bill: bill),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillDetails extends StatelessWidget {
  const new({required this.bill});

  final UtilityBill bill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connection = bill.connection;
    final use = bill.protectedUse;
    final protected = protectedBadge(context, use);
    final charge = bill.charge;
    final units = bill.unitsConsumed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: MmSpace.s2,
          runSpacing: MmSpace.s2,
          children: [billBadge(context, bill), ?protected],
        ),
        const SizedBox(height: MmSpace.s4),
        if (use == ProtectedUse.over || use == ProtectedUse.near) ...[
          ProtectedBanner(use: use!),
          const SizedBox(height: MmSpace.s4),
        ],
        if (connection.inLandlordName && !bill.paid) ...[
          MmBanner(tone: MmBannerTone.warning, message: l10n.inYourNameUnpaid),
          const SizedBox(height: MmSpace.s4),
        ],
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow.amount(
                label: l10n.amountLabel,
                amount: bill.amount,
                emphasized: true,
              ),
              MmDetailRow(
                label: l10n.billMonthLabel,
                value: monthLabel(context, bill.billingMonth),
                userData: false,
              ),
              if (bill.dueDate case final due?)
                MmDetailRow(
                  label: l10n.dueDateLabel,
                  value: dateLabel(context, due),
                  userData: false,
                ),
              if (units != null)
                MmDetailRow(
                  label: l10n.unitsConsumedLabel,
                  value: '$units',
                  userData: false,
                ),
              if (bill.paidOn case final paidOn?)
                MmDetailRow(
                  label: l10n.paidOnLabel,
                  value: dateLabel(context, paidOn),
                  userData: false,
                ),
              if (bill.paidBy case final payer?)
                MmDetailRow(
                  label: l10n.billPaidByLabel,
                  value: l10n.billPayer(payer),
                  userData: false,
                ),
              MmDetailRow(
                label: l10n.whereLabel,
                value: placeLabel(
                  context,
                  connection.propertyName,
                  connection.unitLabel,
                ),
              ),
              if (bill.notes case final notes?)
                ProseRow(label: l10n.notesLabel, text: notes),
            ],
          ),
        ),
        const SizedBox(height: MmSpace.s3),
        ListCard(
          children: [
            MmListTile(
              leading: Icon(utilityIcon(connection.type)),
              title: connectionNameOf(context, connection),
              subtitle: l10n.connectionDetailsAction,
              trailing: const Icon(MmIcons.chevronEnd),
              onTap: () => context.go(Routes.utility(connection.id)),
            ),
            if (bill.liveCharge case final live?)
              MmListTile(
                leading: const Icon(MmIcons.ledger),
                title: l10n.chargedToTenant,
                subtitle: l10n.chargedToTenantHelp,
                subtitleMaxLines: 4,
                trailing: const Icon(MmIcons.chevronEnd),
                onTap: () => context.go(Routes.ledger(live.leaseId)),
              ),
          ],
        ),
        if (charge != null && charge.voided) ...[
          const SizedBox(height: MmSpace.s3),
          MmBanner(tone: MmBannerTone.info, message: l10n.billChargeVoided),
        ],
      ],
    );
  }
}

/// Marking the bill paid (its one primary action while unpaid) or unpaid,
/// and billing it to the tenant.
class _BillActions extends ConsumerStatefulWidget {
  const new({required this.bill});

  final UtilityBill bill;

  @override
  ConsumerState<_BillActions> createState() => _BillActionsState();
}

class _BillActionsState extends ConsumerState<_BillActions> with CommandState {
  /// Marks the bill unpaid once the landlord has seen what that clears.
  Future<void> _markUnpaid() async {
    final l10n = AppLocalizations.of(context);
    final paidOn = widget.bill.paidOn;
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.markUnpaidTitle,
      message: l10n.markUnpaidBody(
        paidOn == null ? '' : dateInLine(context, paidOn),
      ),
      confirmLabel: l10n.markUnpaidAction,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      () => ref
          .read(utilityBillProvider(widget.bill.id).notifier)
          .setPayment(const BillPayment.unpaid()),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.billMarkedUnpaid,
        tone: MmBannerTone.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final bill = widget.bill;
    final buttons = <Widget>[
      if (!bill.paid)
        MmButton(
          label: l10n.markPaidAction,
          icon: MmIcons.check,
          onPressed: busy
              ? null
              : () => showMmSheet<void>(
                  context,
                  title: l10n.markPaidAction,
                  builder: (_) => MarkPaidSheet(bill: bill),
                ),
        )
      else
        MmButton(
          label: l10n.markUnpaidAction,
          icon: MmIcons.undo,
          variant: MmButtonVariant.secondary,
          busy: busy,
          onPressed: _markUnpaid,
        ),
      if (bill.liveCharge == null && bill.amount.isPositive)
        MmButton(
          label: l10n.chargeTenantAction,
          icon: MmIcons.ledger,
          variant: MmButtonVariant.secondary,
          onPressed: busy
              ? null
              : () => showMmSheet<void>(
                  context,
                  title: l10n.chargeTenantAction,
                  builder: (_) => ChargeTenantSheet(bill: bill),
                ),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: MmSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FailureBanner(failure: failure),
          for (final (index, button) in buttons.indexed) ...[
            if (index > 0) const SizedBox(height: MmSpace.s3),
            button,
          ],
        ],
      ),
    );
  }
}

/// Deleting a bill entered by mistake (owners and managers), after its
/// photos: the last thing on the screen.
class _DeleteBill extends ConsumerStatefulWidget {
  const new({required this.bill});

  final UtilityBill bill;

  @override
  ConsumerState<_DeleteBill> createState() => _DeleteBillState();
}

class _DeleteBillState extends ConsumerState<_DeleteBill> with CommandState {
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final bill = widget.bill;
    final confirmed = await showMmConfirmDialog(
      context,
      title: l10n.deleteBillTitle,
      message: bill.liveCharge == null
          ? l10n.deleteBillBody
          : l10n.deleteChargedBillBody,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final done = await runCommand(
      ref.read(utilityBillProvider(bill.id).notifier).delete,
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.billDeleted,
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.utility(bill.connection.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmButton(
          label: l10n.deleteAction,
          icon: MmIcons.delete,
          variant: MmButtonVariant.tertiary,
          busy: busy,
          onPressed: _delete,
        ),
      ],
    );
  }
}

/// Marking a bill paid: when, and by whom.
class MarkPaidSheet extends ConsumerStatefulWidget {
  const new({required this.bill, super.key});

  final UtilityBill bill;

  @override
  ConsumerState<MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends ConsumerState<MarkPaidSheet>
    with CommandState {
  late CalendarDate _paidOn = dates.today(context);
  BillPayer _paidBy = BillPayer.tenant;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final bill = widget.bill;
    final done = await runCommand(
      () => ref
          .read(utilityBillProvider(bill.id).notifier)
          .setPayment(BillPayment(paidOn: _paidOn, paidBy: _paidBy)),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.billMarkedPaid,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        _PaidFields(
          paidOn: _paidOn,
          paidBy: _paidBy,
          onPaidOn: (date) => setState(() => _paidOn = date),
          onPaidBy: (payer) => setState(() => _paidBy = payer),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(label: l10n.markPaidAction, busy: busy, onPressed: _save),
      ],
    );
  }
}

/// Billing a utility bill to the tenant of a tenancy on its connection
/// (`bill_utility_to_tenant`): it becomes a due on their ledger, and
/// credit they hold is applied to it.
class ChargeTenantSheet extends ConsumerStatefulWidget {
  const new({required this.bill, super.key});

  final UtilityBill bill;

  @override
  ConsumerState<ChargeTenantSheet> createState() => _ChargeTenantSheetState();
}

class _ChargeTenantSheetState extends ConsumerState<ChargeTenantSheet>
    with CommandState {
  String? _leaseId;
  bool _tried = false;

  /// The tenancy chosen, or, until one is, the only active tenancy on the
  /// connection.
  String? _chosen(List<Lease>? leases) {
    final chosen = _leaseId;
    if (chosen != null || leases == null) return chosen;
    final active = [
      for (final lease in leases)
        if (lease.active) lease.id,
    ];
    return active.length == 1 ? active.single : null;
  }

  Future<void> _charge(List<Lease>? leases) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final leaseId = _chosen(leases);
    if (leaseId == null) return;
    final done = await runCommand(
      () => ref
          .read(utilityBillProvider(widget.bill.id).notifier)
          .billToTenant(leaseId),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.billCharged,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    final bill = widget.bill;
    final connection = bill.connection;
    final money = MmFormats.moneyOf(context);
    final state = ref.watch(
      tenanciesProvider((
        propertyId: connection.propertyId,
        unitId: connection.unitId,
      )),
    );
    final leases = state.value?.value;
    final today = dates.today(context);
    final due = bill.dueDate ?? today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        Text(
          l10n.chargeTenantExplain(
            money.format(bill.amount),
            dateInLine(context, due),
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (due.isBefore(today)) ...[
          const SizedBox(height: MmSpace.s3),
          MmBanner(tone: MmBannerTone.warning, message: l10n.chargeDuePassed),
        ],
        const SizedBox(height: MmSpace.s4),
        if (leases != null && leases.isEmpty)
          MmBanner(tone: MmBannerTone.info, message: l10n.noTenanciesHere)
        else
          MmSelectField<String?>(
            label: l10n.tenancyTitle,
            required: true,
            placeholder: leases == null ? l10n.loadingPlaces : null,
            errorText: _tried && _chosen(leases) == null
                ? l10n.validationRequired
                : null,
            options: tenancyOptions(l10n, leases),
            value: _chosen(leases),
            onChanged: (id) => setState(() => _leaseId = id),
          ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.chargeTenantAction,
          busy: busy,
          onPressed: leases == null || leases.isEmpty
              ? null
              : () => _charge(leases),
        ),
      ],
    );
  }
}
