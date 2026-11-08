import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/documents_section.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/charge_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/reminders/presentation/reminder_sheet.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// Makes receipt PDFs; tests replace it.
final Provider<
  Future<Uint8List> Function(PaymentDetail detail, DocumentSetup setup)
>
receiptMakerProvider = Provider((ref) => receiptPdf);

/// A payment's receipt (LEDGER-05): the raseed as the tenant gets it, with
/// sharing it as a PDF in English or Urdu, thanking the tenant on
/// WhatsApp, and for owners and managers voiding the payment (LEDGER-06),
/// which keeps the receipt, marked void. Its documents hold the proof of
/// payment (LEDGER-03): a photo of the slip, the transfer or the cheque.
///
/// A voided receipt leads back to the ledger first; sharing it stays
/// possible, named as sharing a voided receipt.
class ReceiptScreen extends ConsumerWidget {
  const new({required this.leaseId, required this.paymentId, super.key});

  final String leaseId;
  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = paymentProvider(paymentId);
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final details = portfolio == null
        ? null
        : ref.watch(portfolioDetailsProvider(portfolio.id)).value?.value;
    final issuer = details?.landlordName ?? portfolio?.name ?? '';
    final role = portfolio?.role;
    return MmPage(
      title: l10n.receiptTitle,
      body: SnapshotView(
        state: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        loadingLabel: l10n.loadingReceipt,
        failedTitle: l10n.receiptLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 8),
        builder: (detail) {
          final payment = detail.payment;
          final money = MmFormats.moneyOf(context);
          final lease = detail.lease;
          final voidedAt = payment.voidedAt;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MmReceipt(
                issuer: issuer,
                numberLabel: l10n.receiptNumberLabel,
                receiptNumber: breakableNumber(payment.receiptNumber),
                amountLabel: l10n.amountReceivedLabel,
                amount: payment.amount,
                voidedLabel: voidedAt == null
                    ? null
                    : l10n.receiptVoidedOn(
                        dateLabel(context, pakistanDate(voidedAt)),
                        payment.voidReason ?? '',
                      ),
                rows: [
                  MmReceiptRow(
                    label: l10n.receivedFromLabel,
                    value: lease.tenantName,
                  ),
                  MmReceiptRow(
                    label: l10n.receiptForLabel,
                    value: l10n.unitAtProperty(
                      lease.unitLabel,
                      lease.propertyName,
                    ),
                  ),
                  MmReceiptRow(
                    label: l10n.receivedOnLabel,
                    value: dateLabel(context, payment.paidOn),
                  ),
                  MmReceiptRow(
                    label: l10n.paidByLabel,
                    value: l10n.paymentMethod(payment.method),
                  ),
                  if (payment.reference case final reference?)
                    MmReceiptRow(
                      label: l10n.paymentReferenceLabel,
                      value: reference,
                    ),
                  if (payment.taxWithheld.isPositive) ...[
                    MmReceiptRow(
                      label: l10n.taxWithheldLabel,
                      value: money.format(payment.taxWithheld),
                      semanticValue: MmFormats.spokenMoney(
                        context,
                        payment.taxWithheld,
                      ),
                    ),
                    if (payment.taxCertificateNo case final certificate?)
                      MmReceiptRow(
                        label: l10n.taxCertificateLabel,
                        value: certificate,
                      ),
                    MmReceiptRow(
                      label: l10n.totalSettledLabel,
                      value: money.format(payment.applied),
                      semanticValue: MmFormats.spokenMoney(
                        context,
                        payment.applied,
                      ),
                    ),
                  ],
                  for (final settled in detail.settled)
                    MmReceiptRow(
                      label: l10n.chargeTitle(
                        settled.kind,
                        settled.periodMonth,
                        (month) => monthLabel(context, month),
                      ),
                      value: money.format(settled.amount),
                      semanticValue: MmFormats.spokenMoney(
                        context,
                        settled.amount,
                      ),
                    ),
                  if (payment.unallocated.isPositive)
                    MmReceiptRow(
                      label: l10n.creditKeptLabel,
                      value: money.format(payment.unallocated),
                      semanticValue: MmFormats.spokenMoney(
                        context,
                        payment.unallocated,
                      ),
                    ),
                ],
                footer: l10n.receiptFooter,
              ),
              const SizedBox(height: MmSpace.s6),
              if (payment.voided) ...[
                MmButton(
                  label: l10n.openLedgerAction,
                  icon: MmIcons.ledger,
                  onPressed: () => context.go(Routes.ledger(leaseId)),
                ),
                const SizedBox(height: MmSpace.s3),
              ],
              MmButton(
                label: payment.voided
                    ? l10n.shareVoidedReceiptAction
                    : l10n.shareReceiptAction,
                icon: MmIcons.share,
                variant: payment.voided
                    ? MmButtonVariant.secondary
                    : MmButtonVariant.primary,
                onPressed: () {
                  final setup = documentSetup(context, ref);
                  final make = ref.read(receiptMakerProvider);
                  unawaited(
                    showShareDocument(
                      context,
                      title: l10n.shareReceiptAction,
                      make: (language) async {
                        final words = lookupAppLocalizations(
                          Locale(language.code),
                        );
                        return (
                          bytes: await make(detail, setup(language)),
                          fileName: documentFileName(
                            'receipt ${payment.receiptNumber}',
                          ),
                          title: words.receiptFileTitle(payment.receiptNumber),
                        );
                      },
                    ),
                  );
                },
              ),
              if ((role?.recordsMoney ?? false) && !payment.voided) ...[
                const SizedBox(height: MmSpace.s3),
                MmButton(
                  label: l10n.sendThanksAction,
                  icon: MmIcons.reminder,
                  variant: MmButtonVariant.secondary,
                  onPressed: () => showReminderComposer(
                    context,
                    leaseId: leaseId,
                    payment: payment,
                  ),
                ),
              ],
              if (!payment.voided) ...[
                const SizedBox(height: MmSpace.s3),
                MmButton(
                  label: l10n.openLedgerAction,
                  icon: MmIcons.ledger,
                  variant: MmButtonVariant.tertiary,
                  onPressed: () => context.go(Routes.ledger(leaseId)),
                ),
              ],
              if ((role?.correctsMoney ?? false) && !payment.voided) ...[
                const SizedBox(height: MmSpace.s3),
                MmButton(
                  label: l10n.voidPaymentAction,
                  icon: MmIcons.close,
                  variant: MmButtonVariant.tertiary,
                  onPressed: () {
                    final controller = ref.read(provider.notifier);
                    unawaited(
                      showMmSheet<void>(
                        context,
                        title: l10n.voidPaymentAction,
                        builder: (_) => ReasonSheet(
                          explanation: l10n.voidPaymentExplain,
                          confirmLabel: l10n.voidPaymentAction,
                          doneMessage: l10n.paymentVoided,
                          onReason: (reason, _) =>
                              controller.voidPayment(reason),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: MmSpace.s6),
              DocumentsSection(
                owner: (entity: DocumentEntity.payment, id: payment.id),
                canAdd: !payment.voided,
              ),
            ],
          );
        },
      ),
    );
  }
}
