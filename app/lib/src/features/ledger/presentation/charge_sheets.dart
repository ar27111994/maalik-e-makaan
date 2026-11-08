import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Opens [charge]'s sheet.
Future<void> showChargeSheet(
  BuildContext context,
  TenancyLedger ledger,
  Charge charge,
) => showMmSheet<void>(
  context,
  title: chargeTitleOf(context, charge),
  builder: (_) => ChargeSheet(leaseId: ledger.lease.id, charge: charge),
);

/// One due: its amounts and dates, why it was waived or voided, and for
/// the roles that may, editing it (`update_charge`: the due date and note,
/// and the amount of a charge added by hand), waiving it and voiding it.
class ChargeSheet extends ConsumerWidget {
  const new({required this.leaseId, required this.charge, super.key});

  final String leaseId;
  final Charge charge;

  Future<void> _open(BuildContext context, String title, Widget sheet) async {
    Navigator.of(context).pop();
    await showMmSheet<void>(context, title: title, builder: (_) => sheet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final role = ref.watch(currentPortfolioProvider).value?.role;
    final records = role?.recordsMoney ?? false;
    final corrects = role?.correctsMoney ?? false;
    final live = !charge.voided;
    // Read now: the sheets it opens outlive this one.
    final ledger = ref.read(tenancyLedgerProvider(leaseId).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: chargeBadge(context, charge),
        ),
        const SizedBox(height: MmSpace.s3),
        MmDetailRow.amount(label: l10n.amountLabel, amount: charge.amount),
        if (charge.paidAmount.isPositive)
          MmDetailRow.amount(label: l10n.paidLabel, amount: charge.paidAmount),
        if (charge.waivedAmount.isPositive)
          MmDetailRow.amount(
            label: l10n.totalWaivedLabel,
            amount: charge.waivedAmount,
          ),
        if (live)
          MmDetailRow.amount(
            label: l10n.stillOwedLabel,
            amount: charge.outstanding,
            emphasized: true,
          ),
        MmDetailRow(
          label: l10n.dueDateLabel,
          value: dateLabel(context, charge.dueDate),
          userData: false,
        ),
        if (charge.description case final note?)
          MmDetailRow(label: l10n.chargeNoteLabel, value: note),
        if (charge.waiveReason case final reason?)
          MmDetailRow(label: l10n.waiveReasonLabel, value: reason),
        if (charge.voidReason case final reason?)
          MmDetailRow(label: l10n.voidReasonLabel, value: reason),
        if (live && records) ...[
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: l10n.editChargeAction,
            icon: MmIcons.edit,
            variant: MmButtonVariant.secondary,
            onPressed: () => _open(
              context,
              l10n.editChargeAction,
              EditChargeSheet(leaseId: leaseId, charge: charge),
            ),
          ),
        ],
        if (charge.open && corrects) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.waiveChargeAction,
            icon: MmIcons.check,
            variant: MmButtonVariant.secondary,
            onPressed: () => _open(
              context,
              l10n.waiveChargeAction,
              ReasonSheet(
                explanation: l10n.waiveExplain,
                confirmLabel: l10n.waiveChargeAction,
                doneMessage: l10n.chargeWaivedDone,
                destructive: false,
                waiveOf: charge,
                onReason: (reason, amount) => ledger.waiveCharge(
                  charge.id,
                  reason: reason,
                  amount: amount,
                ),
              ),
            ),
          ),
        ],
        if (live && corrects && !charge.paidAmount.isPositive) ...[
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.voidChargeAction,
            icon: MmIcons.close,
            variant: MmButtonVariant.tertiary,
            onPressed: () => _open(
              context,
              l10n.voidChargeAction,
              ReasonSheet(
                explanation: l10n.voidChargeExplain,
                confirmLabel: l10n.voidChargeAction,
                doneMessage: l10n.chargeVoidedDone,
                onReason: (reason, _) => ledger.voidCharge(charge.id, reason),
              ),
            ),
          ),
        ],
        if (live && corrects && charge.paidAmount.isPositive) ...[
          const SizedBox(height: MmSpace.s3),
          Text(
            l10n.voidChargeHasPayments,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// Changing a due's date and note, and the amount of one added by hand
/// (never below what was paid or waived).
class EditChargeSheet extends ConsumerStatefulWidget {
  const new({required this.leaseId, required this.charge, super.key});

  final String leaseId;
  final Charge charge;

  @override
  ConsumerState<EditChargeSheet> createState() => _EditChargeSheetState();
}

class _EditChargeSheetState extends ConsumerState<EditChargeSheet>
    with CommandState {
  late Money? _amount = widget.charge.amount;
  late CalendarDate _due = widget.charge.dueDate;
  late final _note = TextEditingController(text: widget.charge.description);
  bool _tried = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Money get _floor => widget.charge.paidAmount + widget.charge.waivedAmount;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final amount = _amount;
    if (amount == null || amount < _floor || !amount.isPositive) return;
    final charge = widget.charge;
    final note = sanitizeSingleLine(_note.text);
    final done = await runCommand(
      () => ref
          .read(tenancyLedgerProvider(widget.leaseId).notifier)
          .updateCharge(
            charge.id,
            amount: amount == charge.amount ? null : amount,
            dueDate: _due == charge.dueDate ? null : _due,
            description: note == (charge.description ?? '') ? null : note,
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.chargeSaved,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final failure = this.failure;
    final charge = widget.charge;
    final amount = _amount;
    final reason = rejectedReason;
    final today = dates.today(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null && reason != 'invalid_amount')
          FailureBanner(failure: failure),
        if (charge.amountEditable)
          MmMoneyField(
            label: l10n.amountLabel,
            value: _amount,
            required: true,
            allowZero: false,
            invalidText: l10n.validationAmount,
            helper: _floor.isPositive
                ? l10n.amountAtLeast(money.format(_floor))
                : null,
            errorText: reason == 'invalid_amount' && failure != null
                ? failureMessage(l10n, failure)
                : _tried && (amount == null || amount < _floor)
                ? (amount == null
                      ? l10n.validationAmount
                      : l10n.amountAtLeast(money.format(_floor)))
                : null,
            onChanged: (value) => setState(() => _amount = value),
          )
        else
          MmBanner(tone: MmBannerTone.info, message: l10n.chargeAmountFixed),
        const SizedBox(height: MmSpace.s4),
        MmDateField(
          label: l10n.dueDateLabel,
          value: _due,
          required: true,
          firstDate: today.addYears(-5),
          lastDate: today.addYears(2),
          onChanged: (date) {
            if (date != null) setState(() => _due = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.chargeNoteLabel,
          controller: _note,
          optional: true,
          maxLength: Charge.maxDescriptionLength,
          inputFormatters: codePointLimit(Charge.maxDescriptionLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(label: l10n.saveAction, busy: busy, onPressed: _save),
      ],
    );
  }
}

/// Adding a charge by hand (LEDGER-02): a bill, maintenance, society
/// charges, damages or anything else the tenant owes.
class AddChargeSheet extends ConsumerStatefulWidget {
  const new({required this.leaseId, super.key});

  final String leaseId;

  @override
  ConsumerState<AddChargeSheet> createState() => _AddChargeSheetState();
}

class _AddChargeSheetState extends ConsumerState<AddChargeSheet>
    with CommandState {
  /// The id of this charge, kept for every retry.
  final String _attempt = newUuid();
  ChargeKind _kind = ChargeKind.electricity;
  Money? _amount;
  late CalendarDate _due = dates.today(context);
  MonthPeriod? _month;
  final _note = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add(String portfolioId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final amount = _amount;
    if (amount == null || !amount.isPositive) return;
    final done = await runCommand(
      () => ref
          .read(tenancyLedgerProvider(widget.leaseId).notifier)
          .addCharge(
            id: _attempt,
            portfolioId: portfolioId,
            draft: ChargeDraft(
              kind: _kind,
              amount: amount,
              dueDate: _due,
              periodMonth: _month,
              description: _note.text,
            ),
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.chargeAdded(l10n.chargeKind(_kind)),
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final failure = this.failure;
    final today = dates.today(context);
    final current = MonthPeriod.of(today);
    final months = [for (var i = -6; i <= 2; i++) current.addMonths(i)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        MmSelectField<ChargeKind>(
          label: l10n.chargeKindLabel,
          required: true,
          options: [
            for (final kind in ChargeKind.manual)
              MmOption(value: kind, label: l10n.chargeKind(kind)),
          ],
          value: _kind,
          onChanged: (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: MmSpace.s4),
        MmMoneyField(
          label: l10n.amountLabel,
          value: _amount,
          required: true,
          allowZero: false,
          invalidText: l10n.validationAmount,
          errorText: _tried && _amount == null ? l10n.validationAmount : null,
          onChanged: (amount) => setState(() => _amount = amount),
        ),
        const SizedBox(height: MmSpace.s4),
        MmDateField(
          label: l10n.dueDateLabel,
          value: _due,
          required: true,
          firstDate: today.addYears(-2),
          lastDate: today.addYears(1),
          onChanged: (date) {
            if (date != null) setState(() => _due = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<MonthPeriod?>(
          label: l10n.chargeMonthLabel,
          optional: true,
          helper: l10n.chargeMonthHelp,
          options: [
            MmOption(value: null, label: l10n.noMonthOption),
            for (final month in months)
              MmOption(value: month, label: monthLabel(context, month)),
          ],
          value: _month,
          onChanged: (month) => setState(() => _month = month),
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.chargeNoteLabel,
          controller: _note,
          optional: true,
          maxLength: Charge.maxDescriptionLength,
          inputFormatters: codePointLimit(Charge.maxDescriptionLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: l10n.addChargeAction,
          busy: busy,
          onPressed: portfolio == null ? null : () => _add(portfolio.id),
        ),
      ],
    );
  }
}

/// Asking why before a change that is kept for the record: waiving a due
/// (all of what is owed, or part), voiding a due, a payment, a deposit
/// refund or a cash handover. The reason is required and kept; [onReason]
/// makes the change with it.
class ReasonSheet extends StatefulWidget {
  const new({
    required this.explanation,
    required this.confirmLabel,
    required this.doneMessage,
    required this.onReason,
    this.destructive = true,
    this.waiveOf,
    super.key,
  });

  /// What the change does, said before it is made.
  final String explanation;
  final String confirmLabel;

  /// Said once the change is made.
  final String doneMessage;
  final Future<void> Function(String reason, Money? amount) onReason;
  final bool destructive;

  /// When waiving: the due, part of whose outstanding amount may be
  /// waived (all of it when no amount is typed).
  final Charge? waiveOf;

  @override
  State<ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<ReasonSheet> with CommandState {
  final _reason = TextEditingController();

  /// What the amount to waive holds, as typed: an empty field waives all
  /// that is owed; text that is not an acceptable amount waives nothing.
  MmValueEntry<Money> _entry = const MmValueEntry(text: '', value: null);
  bool _tried = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Why the amount to waive cannot be sent, or null when it can (empty
  /// for all of it, or an amount above zero and at most what is owed).
  String? _amountProblem(AppLocalizations l10n, Charge charge) {
    if (!_entry.isInvalid) return null;
    final typed = Money.tryParseDecimal(_entry.text.replaceAll(',', ''));
    if (typed != null && typed > charge.outstanding) {
      return l10n.amountAtMost(
        MmFormats.moneyOf(context).format(charge.outstanding),
      );
    }
    return l10n.validationAmount;
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final reason = sanitizeSingleLine(_reason.text);
    final charge = widget.waiveOf;
    if (charge != null && _amountProblem(l10n, charge) != null) return;
    if (reason.isEmpty) return;
    // Only an empty field waives the whole of what is owed.
    final amount = _entry.isEmpty ? null : _entry.value;
    final done = await runCommand(() => widget.onReason(reason, amount));
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: widget.doneMessage,
        tone: MmBannerTone.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final failure = this.failure;
    final reasonCode = rejectedReason;
    final charge = widget.waiveOf;
    // The server's refusals about the amount show beside it.
    final amountRefused =
        charge != null &&
        failure != null &&
        (reasonCode == 'invalid_amount' ||
            reasonCode == 'amount_exceeds_outstanding');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null && !amountRefused) FailureBanner(failure: failure),
        MmBanner(tone: MmBannerTone.warning, message: widget.explanation),
        const SizedBox(height: MmSpace.s4),
        if (charge != null) ...[
          MmMoneyField(
            label: l10n.waiveAmountLabel,
            value: _entry.value,
            optional: true,
            allowZero: false,
            max: charge.outstanding,
            invalidText: l10n.validationAmount,
            helper: l10n.waiveAmountHelp(money.format(charge.outstanding)),
            errorText: amountRefused
                ? failureMessage(l10n, failure)
                : _tried
                ? _amountProblem(l10n, charge)
                : null,
            onChanged: (_) {},
            onEntryChanged: (entry) => setState(() => _entry = entry),
          ),
          const SizedBox(height: MmSpace.s4),
        ],
        MmTextField(
          label: l10n.reasonLabel,
          controller: _reason,
          required: true,
          maxLength: Charge.maxReasonLength,
          inputFormatters: codePointLimit(Charge.maxReasonLength),
          errorText: _tried && sanitizeSingleLine(_reason.text).isEmpty
              ? l10n.reasonReasonRequired
              : null,
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(
          label: widget.confirmLabel,
          variant: widget.destructive
              ? MmButtonVariant.destructive
              : MmButtonVariant.primary,
          busy: busy,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
