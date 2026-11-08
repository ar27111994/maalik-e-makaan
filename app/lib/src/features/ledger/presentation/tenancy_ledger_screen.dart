import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/below_text.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/charge_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/deposit_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/ledger_labels.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/reminders/presentation/reminder_sheet.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

/// A tenancy's money (LEDGER-*): what it owes, since when, and its credit;
/// recording a payment and reminding the tenant; the dues still owed, the
/// payments with their receipts, every due in any state, the security
/// deposit, and the reminders sent. Each role sees the actions it may
/// take.
class TenancyLedgerScreen extends ConsumerWidget {
  const new({required this.leaseId, super.key});

  final String leaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = tenancyLedgerProvider(leaseId);
    final state = ref.watch(provider);
    final ledger = state.value?.value;
    final portfolio = ref.watch(currentPortfolioProvider).value;
    final role = portfolio?.role;
    // Receipts, statements and reminders name the landlord and their
    // payment details: kept at hand while the ledger shows.
    if (portfolio != null) ref.watch(portfolioDetailsProvider(portfolio.id));
    return MmPage(
      title: ledger?.lease.tenantName ?? l10n.ledgerTitle,
      actions: [
        if (ledger != null)
          IconButton(
            tooltip: l10n.statementAction,
            icon: const Icon(MmIcons.document),
            onPressed: () => shareStatement(context, ref, leaseId),
          ),
      ],
      body: SnapshotView(
        state: state,
        onRetry: () => ref.invalidate(provider),
        loadingLabel: l10n.loadingLedger,
        failedTitle: l10n.ledgerLoadFailedTitle,
        skeleton: const MmSkeleton.text(lines: 10),
        builder: (ledger) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Balance(ledger: ledger, role: role),
            const SizedBox(height: MmSpace.s6),
            _OpenDues(ledger: ledger, role: role),
            const SizedBox(height: MmSpace.s6),
            _Payments(ledger: ledger),
            const SizedBox(height: MmSpace.s6),
            _AllDues(ledger: ledger, role: role),
            const SizedBox(height: MmSpace.s6),
            DepositSection(ledger: ledger, role: role),
            const SizedBox(height: MmSpace.s6),
            ReminderHistory(leaseId: leaseId),
          ],
        ),
      ),
    );
  }
}

/// Makes a tenancy's statement in the language the landlord picks and
/// hands it to the share sheet (LEDGER-09).
Future<void> shareStatement(
  BuildContext context,
  WidgetRef ref,
  String leaseId,
) {
  final l10n = AppLocalizations.of(context);
  final setup = documentSetup(context, ref);
  final make = ref.read(statementMakerProvider);
  return showShareDocument(
    context,
    title: l10n.statementAction,
    make: (language) async {
      final statement = await ref
          .read(tenancyLedgerProvider(leaseId).notifier)
          .statement();
      final words = lookupAppLocalizations(Locale(language.code));
      final title = words.statementFileTitle(statement.lease.tenantName);
      return (
        bytes: await make(statement, setup(language)),
        fileName: documentFileName(
          'statement ${statement.lease.tenantName} ${setup(language).today}',
        ),
        title: title,
      );
    },
  );
}

/// Makes statement PDFs; tests replace it.
final Provider<
  Future<Uint8List> Function(LedgerStatement statement, DocumentSetup setup)
>
statementMakerProvider = Provider((ref) => statementPdf);

/// The setup of a document made now, in a language: the landlord's name
/// (else the portfolio's) and the amount grouping the app uses.
DocumentSetup Function(DocumentLanguage) documentSetup(
  BuildContext context,
  WidgetRef ref,
) {
  final portfolio = ref.read(currentPortfolioProvider).value;
  final details = portfolio == null
      ? null
      : ref.read(portfolioDetailsProvider(portfolio.id)).value?.value;
  final issuer = details?.landlordName ?? portfolio?.name ?? '';
  final grouping = MmFormats.moneyOf(context).grouping;
  final today = dates.today(context);
  return (language) => DocumentSetup(
    language: language,
    issuer: issuer,
    today: today,
    grouping: grouping,
  );
}

class _Balance extends ConsumerWidget {
  const new({required this.ledger, required this.role});

  final TenancyLedger ledger;
  final MemberRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final balance = ledger.balance;
    final lease = ledger.lease;
    final records = role?.recordsMoney ?? false;
    final paidOn = balance.lastPaidOn;
    final remindedAt = balance.lastRemindedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: balanceBadge(context, balance),
              ),
              const SizedBox(height: MmSpace.s3),
              MmDetailRow.amount(
                label: l10n.owedNowLabel,
                amount: balance.outstanding,
                emphasized: true,
              ),
              if (balance.overdue.isPositive)
                MmDetailRow.amount(
                  label: l10n.overdueLabel,
                  amount: balance.overdue,
                ),
              if (balance.credit.isPositive)
                MmDetailRow.amount(
                  label: l10n.creditLabel,
                  amount: -balance.credit,
                  creditLabel: l10n.creditWord,
                ),
              MmDetailRow(
                label: l10n.tenancyTitle,
                value: appText(
                  l10n.unitAtProperty(
                    inSentence(lease.unitLabel, Directionality.of(context)),
                    inSentence(lease.propertyName, Directionality.of(context)),
                  ),
                  Directionality.of(context),
                ),
              ),
              if (paidOn != null)
                MmDetailRow(
                  label: l10n.lastPaidLabel,
                  value: dateLabel(context, paidOn),
                  userData: false,
                ),
              if (remindedAt != null)
                MmDetailRow(
                  label: l10n.lastRemindedLabel,
                  value: momentLabel(context, remindedAt),
                  userData: false,
                ),
            ],
          ),
        ),
        if (balance.credit.isPositive) ...[
          const SizedBox(height: MmSpace.s3),
          _CreditBanner(ledger: ledger, role: role),
        ],
        if (records) ...[
          const SizedBox(height: MmSpace.s4),
          MmButton(
            label: l10n.recordPaymentAction,
            icon: MmIcons.payment,
            onPressed: () => context.go(Routes.recordPayment(lease.id)),
          ),
          const SizedBox(height: MmSpace.s3),
          MmButton(
            label: l10n.remindAction,
            icon: MmIcons.reminder,
            variant: MmButtonVariant.secondary,
            onPressed: () => showReminderComposer(context, leaseId: lease.id),
          ),
        ],
        const SizedBox(height: MmSpace.s3),
        // The tenancy's own screen: its terms, police registration and
        // documents.
        ListCard(
          children: [
            MmListTile(
              leading: const Icon(MmIcons.lease),
              title: l10n.openTenancyAction,
              subtitle: lease.tenantName,
              chevron: true,
              onTap: () => context.go(Routes.lease(lease.id)),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the tenant's credit means for the tenancy, said to every role; on
/// an ended tenancy, owners and managers are told what to do with it and
/// led to the payment it came from.
class _CreditBanner extends StatelessWidget {
  const new({required this.ledger, required this.role});

  final TenancyLedger ledger;
  final MemberRole? role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final lease = ledger.lease;
    final credit = money.format(ledger.balance.credit);
    if (lease.active) {
      return MmBanner(
        tone: MmBannerTone.info,
        icon: MmIcons.deposit,
        message: l10n.creditExplainActive,
      );
    }
    if (!(role?.correctsMoney ?? false)) {
      return MmBanner(
        tone: MmBannerTone.info,
        icon: MmIcons.deposit,
        message: l10n.creditHeldEnded(credit),
      );
    }
    // The newest payment with money left over, on the page shown.
    final source = ledger.payments.items
        .where((p) => p.unallocated.isPositive)
        .firstOrNull;
    return MmBanner(
      tone: MmBannerTone.info,
      icon: MmIcons.deposit,
      message: l10n.creditExplainEnded,
      actionLabel: source == null ? null : l10n.openCreditPaymentAction,
      onAction: source == null
          ? null
          : () => context.go(Routes.receipt(lease.id, source.id)),
    );
  }
}

/// A due as a list row: what it is for, what is left of it and when it
/// falls due, and its badge under the text.
class ChargeTile extends StatelessWidget {
  const new({required this.charge, required this.onTap, super.key});

  final Charge charge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    final direction = Directionality.of(context);
    final partial = charge.open && charge.outstanding != charge.amount;
    return MmListTile(
      leading: Icon(_kindIcon(charge.kind)),
      title: chargeTitleOf(context, charge),
      subtitle: appText(
        detailLine([
          if (partial)
            l10n.leftOfAmount(
              money.format(charge.outstanding),
              money.format(charge.amount),
            )
          else
            money.format(charge.amount),
          if (charge.open) dateInLine(context, charge.dueDate),
          if (charge.description case final note?) inSentence(note, direction),
        ]),
        direction,
      ),
      subtitleMaxLines: 4,
      trailing: BelowText(child: chargeBadge(context, charge)),
      onTap: onTap,
    );
  }
}

IconData _kindIcon(ChargeKind kind) => switch (kind) {
  ChargeKind.rent => MmIcons.home,
  ChargeKind.securityDeposit => MmIcons.deposit,
  ChargeKind.electricity => MmIcons.electricity,
  ChargeKind.gas => MmIcons.gas,
  ChargeKind.water => MmIcons.water,
  ChargeKind.internet => MmIcons.internet,
  ChargeKind.maintenance => MmIcons.maintenance,
  ChargeKind.lateFee => MmIcons.clock,
  ChargeKind.societyCharges ||
  ChargeKind.damages ||
  ChargeKind.other => MmIcons.tag,
};

class _OpenDues extends StatelessWidget {
  const new({required this.ledger, required this.role});

  final TenancyLedger ledger;
  final MemberRole? role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final records = role?.recordsMoney ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(
          title: l10n.openDuesSection,
          subtitle: l10n.openDuesHelp,
          actionLabel: records ? l10n.addChargeAction : null,
          onAction: records
              ? () => showMmSheet<void>(
                  context,
                  title: l10n.addChargeAction,
                  builder: (_) => AddChargeSheet(leaseId: ledger.lease.id),
                )
              : null,
        ),
        const SizedBox(height: MmSpace.s2),
        if (ledger.openCharges.isEmpty)
          Text(l10n.noOpenDues, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [
              for (final charge in ledger.openCharges)
                ChargeTile(
                  charge: charge,
                  onTap: () => showChargeSheet(context, ledger, charge),
                ),
            ],
          ),
      ],
    );
  }
}

class _Payments extends ConsumerWidget {
  const new({required this.ledger});

  final TenancyLedger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final payments = ledger.payments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.paymentsSection),
        const SizedBox(height: MmSpace.s2),
        if (payments.items.isEmpty)
          Text(l10n.noPaymentsYet, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [
              for (final payment in payments.items)
                PaymentTile(leaseId: ledger.lease.id, payment: payment),
            ],
          ),
        if (payments.hasMore)
          LoadMoreButton(
            onLoad: () => ref
                .read(tenancyLedgerProvider(ledger.lease.id).notifier)
                .loadMorePayments(),
          ),
      ],
    );
  }
}

/// A payment as a list row, leading to its receipt.
class PaymentTile extends StatelessWidget {
  const new({required this.leaseId, required this.payment, super.key});

  final String leaseId;
  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final money = MmFormats.moneyOf(context);
    return MmListTile(
      leading: Icon(methodIcon(payment.method)),
      title: wrappableAmount(money.format(payment.amount)),
      subtitle: appText(
        detailLine([
          // First, so the number starts a line and wraps only when it is
          // wider than one (at 200% text).
          l10n.receiptNumbered(breakableNumber(payment.receiptNumber)),
          dateInLine(context, payment.paidOn),
          l10n.paymentMethod(payment.method),
          if (payment.taxWithheld.isPositive)
            l10n.withTax(money.format(payment.taxWithheld)),
        ]),
        Directionality.of(context),
      ),
      subtitleMaxLines: 4,
      trailing: payment.voided
          ? BelowText(
              child: MmStatusBadge(
                status: MmStatus.neutral,
                icon: MmIcons.close,
                label: l10n.chargeVoided,
              ),
            )
          : null,
      onTap: () => context.go(Routes.receipt(leaseId, payment.id)),
    );
  }
}

class _AllDues extends ConsumerWidget {
  const new({required this.ledger, required this.role});

  final TenancyLedger ledger;
  final MemberRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final charges = ledger.charges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmSectionHeader(title: l10n.allDuesSection, subtitle: l10n.allDuesHelp),
        const SizedBox(height: MmSpace.s2),
        if (charges.items.isEmpty)
          Text(l10n.noDuesYet, style: Theme.of(context).textTheme.bodyLarge)
        else
          ListCard(
            children: [
              for (final charge in charges.items)
                ChargeTile(
                  charge: charge,
                  onTap: () => showChargeSheet(context, ledger, charge),
                ),
            ],
          ),
        if (charges.hasMore)
          LoadMoreButton(
            onLoad: () => ref
                .read(tenancyLedgerProvider(ledger.lease.id).notifier)
                .loadMoreCharges(),
          ),
      ],
    );
  }
}
