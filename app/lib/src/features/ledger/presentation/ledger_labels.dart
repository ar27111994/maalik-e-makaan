import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The words for the ledger values the database names.
extension LedgerWords on AppLocalizations {
  String chargeKind(ChargeKind kind) => switch (kind) {
    ChargeKind.rent => chargeKindRent,
    ChargeKind.securityDeposit => chargeKindDeposit,
    ChargeKind.electricity => chargeKindElectricity,
    ChargeKind.gas => chargeKindGas,
    ChargeKind.water => chargeKindWater,
    ChargeKind.internet => chargeKindInternet,
    ChargeKind.maintenance => chargeKindMaintenance,
    ChargeKind.societyCharges => chargeKindSociety,
    ChargeKind.lateFee => chargeKindLateFee,
    ChargeKind.damages => chargeKindDamages,
    ChargeKind.other => chargeKindOther,
  };

  String paymentMethod(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => methodCash,
    PaymentMethod.bankTransfer => methodBankTransfer,
    PaymentMethod.raast => methodRaast,
    PaymentMethod.jazzcash => methodJazzCash,
    PaymentMethod.easypaisa => methodEasypaisa,
    PaymentMethod.cheque => methodCheque,
    PaymentMethod.card => methodCard,
    PaymentMethod.depositAdjustment => methodDeposit,
    PaymentMethod.other => methodOther,
  };

  /// What a due is for: its kind, and its month when it has one ("Rent,
  /// November 2026"), [month] naming the month.
  String chargeTitle(
    ChargeKind kind,
    MonthPeriod? period,
    String Function(MonthPeriod) month,
  ) => period == null
      ? chargeKind(kind)
      : chargeForMonth(chargeKind(kind), month(period));
}

/// The title of [charge] in the app's language.
String chargeTitleOf(BuildContext context, Charge charge) =>
    AppLocalizations.of(context).chargeTitle(
      charge.kind,
      charge.periodMonth,
      (month) => monthLabel(context, month),
    );

/// A badge saying where [charge] stands today, in words, with an icon.
MmStatusBadge chargeBadge(BuildContext context, Charge charge) {
  final l10n = AppLocalizations.of(context);
  final today = dates.today(context);
  return switch (charge.stateOn(today)) {
    ChargeState.overdue => MmStatusBadge(
      status: MmStatus.overdue,
      label: l10n.overdueDays(today.differenceInDays(charge.dueDate)),
    ),
    ChargeState.dueSoon => MmStatusBadge(
      status: MmStatus.dueSoon,
      label: charge.dueDate == today
          ? l10n.dueToday
          : l10n.dueInDays(charge.dueDate.differenceInDays(today)),
    ),
    ChargeState.notDue => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.calendar,
      label: l10n.dueOn(dateLabel(context, charge.dueDate)),
    ),
    ChargeState.paid => MmStatusBadge(
      status: MmStatus.paid,
      label: l10n.chargePaid,
    ),
    ChargeState.waived => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.check,
      label: l10n.chargeWaived,
    ),
    ChargeState.voided => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.close,
      label: l10n.chargeVoided,
    ),
  };
}

/// The icon of a payment method.
IconData methodIcon(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => MmIcons.cash,
  PaymentMethod.bankTransfer || PaymentMethod.raast => MmIcons.bank,
  PaymentMethod.card => MmIcons.card,
  PaymentMethod.jazzcash || PaymentMethod.easypaisa => MmIcons.phone,
  PaymentMethod.cheque => MmIcons.receiptText,
  PaymentMethod.depositAdjustment => MmIcons.deposit,
  PaymentMethod.other => MmIcons.payment,
};
