import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/charge_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// A tenancy's security deposit (LEDGER-08): agreed, received, used for
/// dues, paid back and still held; for owners and managers, using it to
/// settle dues and paying it back; the refunds, which owners may void.
class DepositSection extends ConsumerWidget {
  const new({required this.ledger, required this.role, super.key});

  final TenancyLedger ledger;
  final MemberRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final direction = Directionality.of(context);
    final deposit = ledger.deposit;
    final corrects = role?.correctsMoney ?? false;
    final approves = role?.approvesMoney ?? false;
    final held = deposit.held.isPositive;
    final active = ledger.lease.active;
    final owed = Money.sum([
      for (final c in ledger.openCharges)
        if (c.kind != ChargeKind.securityDeposit) c.outstanding,
    ]);
    final controller = ref.read(
      tenancyLedgerProvider(ledger.lease.id).notifier,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.depositSection),
        const SizedBox(height: MmSpace.s2),
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmDetailRow.amount(
                label: l10n.depositAgreedLabel,
                amount: deposit.agreed,
              ),
              MmDetailRow.amount(
                label: l10n.depositReceivedLabel,
                amount: deposit.received,
              ),
              if (deposit.applied.isPositive)
                MmDetailRow.amount(
                  label: l10n.depositAppliedLabel,
                  amount: deposit.applied,
                ),
              if (deposit.refunded.isPositive)
                MmDetailRow.amount(
                  label: l10n.depositRefundedLabel,
                  amount: deposit.refunded,
                ),
              MmDetailRow.amount(
                label: l10n.depositHeldLabel,
                amount: deposit.held,
                emphasized: true,
              ),
            ],
          ),
        ),
        if (!ledger.lease.active && held) ...[
          const SizedBox(height: MmSpace.s3),
          MmBanner(
            tone: MmBannerTone.warning,
            icon: MmIcons.deposit,
            message: l10n.depositSettleAfterEnd,
          ),
        ],
        // Move-out steps (LEDGER-08): on a tenancy still running they stay
        // within reach (a tenant may ask for the last months' rent to come
        // from the deposit) but quiet, and each sheet says so first.
        if (corrects && held) ...[
          const SizedBox(height: MmSpace.s3),
          if (owed.isPositive) ...[
            MmButton(
              label: l10n.applyDepositAction,
              icon: MmIcons.deposit,
              variant: active
                  ? MmButtonVariant.tertiary
                  : MmButtonVariant.secondary,
              onPressed: () => showMmSheet<void>(
                context,
                title: l10n.applyDepositAction,
                builder: (_) => ApplyDepositSheet(
                  leaseId: ledger.lease.id,
                  held: deposit.held,
                  owed: owed,
                  tenancyActive: active,
                ),
              ),
            ),
            const SizedBox(height: MmSpace.s3),
          ],
          MmButton(
            label: l10n.refundDepositAction,
            icon: MmIcons.undo,
            variant: active
                ? MmButtonVariant.tertiary
                : MmButtonVariant.secondary,
            onPressed: () => showMmSheet<void>(
              context,
              title: l10n.refundDepositAction,
              builder: (_) => RefundDepositSheet(
                leaseId: ledger.lease.id,
                held: deposit.held,
                tenancyActive: active,
              ),
            ),
          ),
        ],
        if (ledger.refunds.isNotEmpty) ...[
          const SizedBox(height: MmSpace.s3),
          ListCard(
            children: [
              for (final refund in ledger.refunds)
                MmListTile(
                  leading: Icon(methodIcon(refund.method)),
                  title: l10n.refundOf(
                    wrappableAmount(money.format(refund.amount)),
                  ),
                  subtitle: appText(
                    detailLine([
                      dateInLine(context, refund.refundedOn),
                      l10n.paymentMethod(refund.method),
                      if (refund.reference case final reference?)
                        inSentence(reference, direction),
                      if (refund.voidReason case final reason?)
                        l10n.voidedBecause(inSentence(reason, direction)),
                    ]),
                    direction,
                  ),
                  subtitleMaxLines: 4,
                  trailing: refund.voided
                      ? BelowText(
                          child: MmStatusBadge(
                            status: MmStatus.neutral,
                            icon: MmIcons.close,
                            label: l10n.chargeVoided,
                          ),
                        )
                      : null,
                  onTap: approves && !refund.voided
                      ? () => showMmSheet<void>(
                          context,
                          title: l10n.voidRefundAction,
                          builder: (_) => ReasonSheet(
                            explanation: l10n.voidRefundExplain,
                            confirmLabel: l10n.voidRefundAction,
                            doneMessage: l10n.refundVoided,
                            onReason: (reason, _) =>
                                controller.voidRefund(refund.id, reason),
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Settling dues from the deposit held (`apply_deposit`), oldest first,
/// at most what is held and what is owed. One key per sheet, kept for
/// retries.
class ApplyDepositSheet extends ConsumerStatefulWidget {
  const new({
    required this.leaseId,
    required this.held,
    required this.owed,
    this.tenancyActive = false,
    super.key,
  });

  final String leaseId;
  final Money held;
  final Money owed;

  /// Whether the tenant still lives there: the sheet says so first.
  final bool tenancyActive;

  @override
  ConsumerState<ApplyDepositSheet> createState() => _ApplyDepositSheetState();
}

class _ApplyDepositSheetState extends ConsumerState<ApplyDepositSheet>
    with CommandState {
  final String _key = newUuid();
  late Money? _amount = Money.min(widget.held, widget.owed);
  late CalendarDate _on = dates.today(context);
  final _notes = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Money get _most => Money.min(widget.held, widget.owed);

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final amount = _amount;
    if (amount == null || !amount.isPositive || amount > _most) return;
    final done = await runCommand(
      () => ref
          .read(tenancyLedgerProvider(widget.leaseId).notifier)
          .applyDeposit(
            amount: amount,
            appliedOn: _on,
            idempotencyKey: _key,
            notes: _notes.text,
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.depositApplied(MmFormats.moneyOf(context).format(amount)),
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
    final amount = _amount;
    final today = dates.today(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) FailureBanner(failure: failure),
        if (widget.tenancyActive) ...[
          MmBanner(
            tone: MmBannerTone.warning,
            message: l10n.depositTenancyActive,
          ),
          const SizedBox(height: MmSpace.s3),
        ],
        MmBanner(tone: MmBannerTone.info, message: l10n.applyDepositExplain),
        const SizedBox(height: MmSpace.s4),
        MmMoneyField(
          label: l10n.amountLabel,
          value: _amount,
          required: true,
          allowZero: false,
          max: _most,
          invalidText: l10n.validationAmount,
          helper: l10n.applyDepositHelp(
            money.format(widget.held),
            money.format(widget.owed),
          ),
          errorText: _tried && (amount == null || amount > _most)
              ? l10n.amountAtMost(money.format(_most))
              : null,
          onChanged: (value) => setState(() => _amount = value),
        ),
        const SizedBox(height: MmSpace.s4),
        MmDateField(
          label: l10n.appliedOnLabel,
          value: _on,
          required: true,
          firstDate: today.addYears(-2),
          lastDate: today,
          onChanged: (date) {
            if (date != null) setState(() => _on = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.notesLabel,
          controller: _notes,
          optional: true,
          maxLength: Payment.maxNotesLength,
          inputFormatters: codePointLimit(Payment.maxNotesLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmButton(label: l10n.applyDepositAction, busy: busy, onPressed: _apply),
      ],
    );
  }
}

/// Paying deposit money back to the tenant (`refund_deposit`). The
/// database takes no key for a refund: after a lost connection whose
/// refund the ledger does not show, the sheet cannot send it again; it
/// says to check the deposit, and closes, so a new refund starts from
/// what the deposit now holds.
class RefundDepositSheet extends ConsumerStatefulWidget {
  const new({
    required this.leaseId,
    required this.held,
    this.tenancyActive = false,
    super.key,
  });

  final String leaseId;
  final Money held;

  /// Whether the tenant still lives there: the sheet says so first.
  final bool tenancyActive;

  @override
  ConsumerState<RefundDepositSheet> createState() => _RefundDepositSheetState();
}

class _RefundDepositSheetState extends ConsumerState<RefundDepositSheet>
    with CommandState {
  late Money? _amount = widget.held;
  late CalendarDate _on = dates.today(context);
  PaymentMethod _method = PaymentMethod.cash;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _refund() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final amount = _amount;
    if (amount == null || !amount.isPositive || amount > widget.held) return;
    final done = await runCommand(
      () => ref
          .read(tenancyLedgerProvider(widget.leaseId).notifier)
          .refundDeposit(
            amount: amount,
            refundedOn: _on,
            method: _method,
            reference: _reference.text,
            notes: _notes.text,
          ),
    );
    if (!done || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.depositRefunded(
          MmFormats.moneyOf(context).format(amount),
        ),
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
    final amount = _amount;
    final today = dates.today(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null)
          FailureBanner(
            failure: failure is NetworkFailure
                ? const RejectedFailure('refund_unconfirmed')
                : failure,
          ),
        if (widget.tenancyActive) ...[
          MmBanner(
            tone: MmBannerTone.warning,
            message: l10n.depositTenancyActive,
          ),
          const SizedBox(height: MmSpace.s3),
        ],
        MmMoneyField(
          label: l10n.amountLabel,
          value: _amount,
          required: true,
          allowZero: false,
          max: widget.held,
          invalidText: l10n.validationAmount,
          helper: l10n.depositHeldHelp(money.format(widget.held)),
          errorText: _tried && (amount == null || amount > widget.held)
              ? l10n.amountAtMost(money.format(widget.held))
              : null,
          onChanged: (value) => setState(() => _amount = value),
        ),
        const SizedBox(height: MmSpace.s4),
        MmDateField(
          label: l10n.refundedOnLabel,
          value: _on,
          required: true,
          firstDate: today.addYears(-2),
          lastDate: today,
          onChanged: (date) {
            if (date != null) setState(() => _on = date);
          },
        ),
        const SizedBox(height: MmSpace.s4),
        MmSelectField<PaymentMethod>(
          label: l10n.methodLabel,
          required: true,
          options: [
            for (final method in PaymentMethod.received)
              MmOption(value: method, label: l10n.paymentMethod(method)),
          ],
          value: _method,
          onChanged: (method) => setState(() => _method = method),
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.paymentReferenceLabel,
          controller: _reference,
          optional: true,
          maxLength: Payment.maxReferenceLength,
          inputFormatters: codePointLimit(Payment.maxReferenceLength),
        ),
        const SizedBox(height: MmSpace.s4),
        MmTextField(
          label: l10n.notesLabel,
          controller: _notes,
          optional: true,
          maxLength: Payment.maxNotesLength,
          inputFormatters: codePointLimit(Payment.maxNotesLength),
        ),
        const SizedBox(height: MmSpace.s4),
        if (failure is NetworkFailure)
          MmButton(
            label: l10n.checkDepositAction,
            variant: MmButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          )
        else
          MmButton(
            label: l10n.refundDepositAction,
            busy: busy,
            onPressed: _refund,
          ),
      ],
    );
  }
}
