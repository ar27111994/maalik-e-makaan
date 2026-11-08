import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/command_state.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/core/text_limits.dart';
import 'package:maalik_e_makaan/src/data/ids.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/payment_preview.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/tenants/application/tenants.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// Recording money received for a tenancy (LEDGER-03, LEDGER-04,
/// LEDGER-10): how much, when and how, the tax the tenant withheld under
/// s.155 with its certificate, and which dues it settles (the oldest first,
/// or those chosen), with what it will settle shown before it is saved.
///
/// The form makes one idempotency key when it opens and sends it with
/// every try, so a payment whose answer was lost is recorded once; the
/// payment shows as recorded only once the server says so.
class RecordPaymentScreen extends ConsumerWidget {
  const new({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = tenancyLedgerProvider(leaseId);
    final state = ref.watch(provider);
    final ledger = state.value?.value;
    if (ledger != null) return PaymentForm(ledger: ledger);
    return MmPage(
      title: l10n.recordPaymentTitle,
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(provider),
        loadingLabel: l10n.loadingLedger,
        failedTitle: l10n.ledgerLoadFailedTitle,
        builder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The payment form over a tenancy's [ledger].
class PaymentForm extends ConsumerStatefulWidget {
  const new({required this.ledger, super.key});

  final TenancyLedger ledger;

  @override
  ConsumerState<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<PaymentForm> with CommandState {
  /// Made once per opening of the form and kept for every try.
  final String _key = newUuid();
  Money? _amount;
  late CalendarDate _paidOn = dates.today(context);
  PaymentMethod _method = PaymentMethod.cash;
  bool? _withheld;
  Money? _tax;
  bool _choose = false;
  final _chosen = <String>{};
  final _reference = TextEditingController();
  final _certificate = TextEditingController();
  final _notes = TextEditingController();
  bool _tried = false;

  @override
  void dispose() {
    _reference.dispose();
    _certificate.dispose();
    _notes.dispose();
    super.dispose();
  }

  TenancyLedger get _ledger => widget.ledger;

  /// Whether the tenant withheld tax: as chosen, else as the tenant's
  /// profile says they do.
  bool get _withholds =>
      _withheld ??
      ref
          .read(tenantProvider(_ledger.lease.tenantId))
          .value
          ?.value
          .deductsWithholdingTax ??
      false;

  Money get _taxWithheld => _withholds ? (_tax ?? Money.zero) : Money.zero;

  List<String> get _chosenIds => [
    for (final charge in _ledger.openCharges)
      if (_chosen.contains(charge.id)) charge.id,
  ];

  String? get _amountError {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    if (rejectedReason == 'invalid_amount' && failure != null) {
      return failureMessage(l10n, failure);
    }
    return _tried && _amount == null ? l10n.validationAmount : null;
  }

  String? get _taxError {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    if (rejectedReason == 'invalid_tax_withheld' && failure != null) {
      return failureMessage(l10n, failure);
    }
    return _tried && _taxTooHigh ? l10n.reasonInvalidTaxWithheld : null;
  }

  /// Whether the tax withheld is more than the cash, which the server
  /// refuses (`invalid_tax_withheld`).
  bool get _taxTooHigh {
    final amount = _amount;
    return _withholds && amount != null && _taxWithheld > amount;
  }

  Future<void> _record() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final amount = _amount;
    if (amount == null || !amount.isPositive || _taxTooHigh) return;
    if (_choose && _chosen.isEmpty) return;
    final lease = _ledger.lease;
    final draft = PaymentDraft(
      leaseId: lease.id,
      amount: amount,
      paidOn: _paidOn,
      method: _method,
      idempotencyKey: _key,
      taxWithheld: _taxWithheld,
      taxCertificateNo: _withholds ? _certificate.text : null,
      reference: _reference.text,
      notes: _notes.text,
      chargeIds: _choose ? _chosenIds : null,
    );
    PaymentResult? result;
    final done = await runCommand(() async {
      result = await ref
          .read(tenancyLedgerProvider(lease.id).notifier)
          .recordPayment(draft);
    });
    final recorded = result;
    if (!done || recorded == null || !mounted) return;
    unawaited(
      showMmSnackbar(
        context,
        message: l10n.paymentRecorded(recorded.payment.receiptNumber),
        tone: MmBannerTone.success,
      ),
    );
    context.go(Routes.receipt(lease.id, recorded.payment.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final ledger = _ledger;
    final lease = ledger.lease;
    final failure = this.failure;
    final reason = rejectedReason;
    final today = dates.today(context);
    // Keeps the tenant's tax default up to date.
    ref.watch(tenantProvider(lease.tenantId));
    final withholds = _withholds;
    final amount = _amount;
    final applied = (amount ?? Money.zero) + _taxWithheld;
    final preview = previewPayment(
      applied: applied,
      open: ledger.openCharges,
      paidOn: _paidOn,
      graceDays: lease.terms.graceDays,
      chosen: _choose ? _chosenIds : const [],
    );
    final plan = preview.plan;
    final byId = {for (final c in ledger.openCharges) c.id: c};
    return MmPage(
      title: l10n.recordPaymentTitle,
      bottomBar: MmActionBar(
        primary: MmButton(
          label: l10n.recordPaymentAction,
          icon: MmIcons.payment,
          busy: busy,
          onPressed: _record,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null &&
              reason != 'invalid_amount' &&
              reason != 'invalid_tax_withheld' &&
              reason != 'invalid_date')
            FailureBanner(failure: failure),
          MmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MmDetailRow(label: l10n.tenantLabel, value: lease.tenantName),
                MmDetailRow(
                  label: l10n.receiptForLabel,
                  value: l10n.unitAtProperty(
                    lease.unitLabel,
                    lease.propertyName,
                  ),
                ),
                MmDetailRow.amount(
                  label: l10n.owedNowLabel,
                  amount: ledger.balance.outstanding,
                ),
                if (ledger.balance.credit.isPositive)
                  MmDetailRow.amount(
                    label: l10n.creditLabel,
                    amount: -ledger.balance.credit,
                    creditLabel: l10n.creditWord,
                  ),
              ],
            ),
          ),
          const SizedBox(height: MmSpace.s6),
          MmFormSection(
            title: l10n.paymentSectionMoney,
            children: [
              MmMoneyField(
                label: l10n.amountReceivedLabel,
                value: _amount,
                required: true,
                allowZero: false,
                invalidText: l10n.validationAmount,
                errorText: _amountError,
                onChanged: (value) => setState(() => _amount = value),
              ),
              if (ledger.balance.outstanding.isPositive)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MmButton(
                    label: l10n.useOwedAction(
                      money.format(ledger.balance.outstanding),
                    ),
                    variant: MmButtonVariant.tertiary,
                    onPressed: () =>
                        setState(() => _amount = ledger.balance.outstanding),
                  ),
                ),
              MmDateField(
                label: l10n.receivedOnLabel,
                value: _paidOn,
                required: true,
                firstDate: lease.terms.startDate.addDays(-366),
                lastDate: today,
                errorText: reason == 'invalid_date' && failure != null
                    ? failureMessage(l10n, failure)
                    : null,
                onChanged: (date) {
                  if (date != null) setState(() => _paidOn = date);
                },
              ),
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
              MmTextField(
                label: l10n.paymentReferenceLabel,
                helper: l10n.paymentReferenceHelp,
                controller: _reference,
                optional: true,
                maxLength: Payment.maxReferenceLength,
                inputFormatters: codePointLimit(Payment.maxReferenceLength),
              ),
            ],
          ),
          const SizedBox(height: MmSpace.s6),
          MmFormSection(
            title: l10n.paymentSectionTax,
            children: [
              MmSwitchTile(
                label: l10n.taxWithheldSwitch,
                description: l10n.taxWithheldHelp,
                value: withholds,
                onChanged: (value) => setState(() => _withheld = value),
              ),
              if (withholds) ...[
                MmMoneyField(
                  label: l10n.taxWithheldLabel,
                  value: _tax,
                  optional: true,
                  invalidText: l10n.validationAmount,
                  errorText: _taxError,
                  onChanged: (value) => setState(() => _tax = value),
                ),
                MmTextField(
                  label: l10n.taxCertificateLabel,
                  controller: _certificate,
                  optional: true,
                  maxLength: Payment.maxCertificateLength,
                  inputFormatters: codePointLimit(Payment.maxCertificateLength),
                ),
                if (_taxWithheld.isPositive && amount != null)
                  MmBanner(
                    tone: MmBannerTone.info,
                    message: l10n.taxSettlesGross(
                      money.format(amount),
                      money.format(_taxWithheld),
                      money.format(applied),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: MmSpace.s6),
          MmFormSection(
            title: l10n.paymentSectionSettle,
            children: [
              if (ledger.openCharges.isEmpty)
                Text(
                  l10n.noOpenDuesCredit,
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else ...[
                MmRadioGroup<bool>(
                  label: l10n.settleLabel,
                  options: [
                    MmOption(value: false, label: l10n.settleOldestFirst),
                    MmOption(value: true, label: l10n.settleChosen),
                  ],
                  value: _choose,
                  onChanged: (value) {
                    if (value != null) setState(() => _choose = value);
                  },
                ),
                if (_choose) ...[
                  for (final charge in ledger.openCharges)
                    MmCheckboxTile(
                      label: chargeTitleOf(context, charge),
                      description: detailLine([
                        l10n.owesAmount(money.format(charge.outstanding)),
                        dateLabel(context, charge.dueDate),
                      ]),
                      value: _chosen.contains(charge.id),
                      onChanged: (checked) => setState(
                        () => checked ?? false
                            ? _chosen.add(charge.id)
                            : _chosen.remove(charge.id),
                      ),
                    ),
                  if (_tried && _chosen.isEmpty)
                    MmBanner(
                      tone: MmBannerTone.error,
                      message: l10n.chooseDuesError,
                    ),
                ],
              ],
              if (applied.isPositive) ...[
                MmSectionHeader(title: l10n.willSettleHeading),
                if (plan.allocations.isNotEmpty)
                  MmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final allocation in plan.allocations)
                          MmDetailRow.amount(
                            label: _settledLabel(
                              context,
                              byId[allocation.chargeId]!,
                              allocation.amount,
                            ),
                            amount: allocation.amount,
                          ),
                        if (plan.unallocated.isPositive)
                          MmDetailRow.amount(
                            label: l10n.creditKeptLabel,
                            amount: plan.unallocated,
                          ),
                      ],
                    ),
                  )
                else
                  MmBanner(
                    tone: MmBannerTone.info,
                    icon: MmIcons.deposit,
                    message: l10n.allCreditExplain(money.format(applied)),
                  ),
                for (final fee in preview.cancelledFees)
                  MmBanner(
                    tone: MmBannerTone.info,
                    icon: MmIcons.check,
                    message: l10n.lateFeeCancelledNote(
                      money.format(fee.outstanding),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: MmSpace.s6),
          MmTextField(
            label: l10n.notesLabel,
            controller: _notes,
            optional: true,
            maxLength: Payment.maxNotesLength,
            inputFormatters: codePointLimit(Payment.maxNotesLength),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  String _settledLabel(BuildContext context, Charge charge, Money amount) {
    final l10n = AppLocalizations.of(context);
    final title = chargeTitleOf(context, charge);
    return amount == charge.outstanding
        ? l10n.settledInFull(title)
        : l10n.settledInPart(title);
  }
}
