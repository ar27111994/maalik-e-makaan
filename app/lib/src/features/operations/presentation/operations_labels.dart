import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:mm_ui/mm_ui.dart';

/// The words for the operations values the database names.
extension OperationsWords on AppLocalizations {
  String expenseCategory(ExpenseCategory category) => switch (category) {
    ExpenseCategory.repairsMaintenance => expenseCategoryRepairs,
    ExpenseCategory.propertyTax => expenseCategoryPropertyTax,
    ExpenseCategory.utilities => expenseCategoryUtilities,
    ExpenseCategory.societyCharges => expenseCategorySociety,
    ExpenseCategory.insurance => expenseCategoryInsurance,
    ExpenseCategory.legalProfessional => expenseCategoryLegal,
    ExpenseCategory.agentCommission => expenseCategoryAgent,
    ExpenseCategory.staffSalaries => expenseCategorySalaries,
    ExpenseCategory.cleaningSecurity => expenseCategoryCleaning,
    ExpenseCategory.renovation => expenseCategoryRenovation,
    ExpenseCategory.bankCharges => expenseCategoryBank,
    ExpenseCategory.loanInterest => expenseCategoryLoanInterest,
    ExpenseCategory.other => chargeKindOther,
  };

  String utilityType(UtilityType type) => switch (type) {
    UtilityType.electricity => chargeKindElectricity,
    UtilityType.gas => chargeKindGas,
    UtilityType.water => chargeKindWater,
    UtilityType.internet => chargeKindInternet,
    UtilityType.other => chargeKindOther,
  };

  String utilityProvider(UtilityProvider provider) => switch (provider) {
    UtilityProvider.lesco => providerLesco,
    UtilityProvider.iesco => providerIesco,
    UtilityProvider.gepco => providerGepco,
    UtilityProvider.fesco => providerFesco,
    UtilityProvider.mepco => providerMepco,
    UtilityProvider.pesco => providerPesco,
    UtilityProvider.hesco => providerHesco,
    UtilityProvider.sepco => providerSepco,
    UtilityProvider.qesco => providerQesco,
    UtilityProvider.tesco => providerTesco,
    UtilityProvider.hazeco => providerHazeco,
    UtilityProvider.kElectric => providerKElectric,
    UtilityProvider.sngpl => providerSngpl,
    UtilityProvider.ssgc => providerSsgc,
    UtilityProvider.wasa => providerWasa,
    UtilityProvider.kwsc => providerKwsc,
    UtilityProvider.cda => providerCda,
    UtilityProvider.ptcl => providerPtcl,
    UtilityProvider.other => chargeKindOther,
  };

  String responsibility(BillResponsibility responsibility) =>
      switch (responsibility) {
        BillResponsibility.tenant => responsibilityTenant,
        BillResponsibility.landlord => responsibilityLandlord,
        BillResponsibility.shared => responsibilityShared,
      };

  String billPayer(BillPayer payer) => switch (payer) {
    BillPayer.tenant => billPaidByTenant,
    BillPayer.landlord => billPaidByLandlord,
  };

  String readingContext(ReadingContext context) => switch (context) {
    ReadingContext.moveIn => readingMoveIn,
    ReadingContext.moveOut => readingMoveOut,
    ReadingContext.monthly => readingMonthly,
    ReadingContext.other => chargeKindOther,
  };

  String maintenanceCategory(MaintenanceCategory category) =>
      switch (category) {
        MaintenanceCategory.plumbing => maintenancePlumbing,
        MaintenanceCategory.electrical => maintenanceElectrical,
        MaintenanceCategory.carpentry => maintenanceCarpentry,
        MaintenanceCategory.painting => maintenancePainting,
        MaintenanceCategory.seepage => maintenanceSeepage,
        MaintenanceCategory.appliance => maintenanceAppliance,
        MaintenanceCategory.pestControl => maintenancePestControl,
        MaintenanceCategory.cleaning => maintenanceCleaning,
        MaintenanceCategory.structural => maintenanceStructural,
        MaintenanceCategory.waterSupply => maintenanceWaterSupply,
        MaintenanceCategory.other => chargeKindOther,
      };

  String maintenancePriority(MaintenancePriority priority) =>
      switch (priority) {
        MaintenancePriority.low => priorityLow,
        MaintenancePriority.medium => priorityMedium,
        MaintenancePriority.high => priorityHigh,
        MaintenancePriority.urgent => priorityUrgent,
      };

  String maintenanceStatus(MaintenanceStatus status) => switch (status) {
    MaintenanceStatus.open => maintenanceOpen,
    MaintenanceStatus.inProgress => maintenanceInProgress,
    MaintenanceStatus.onHold => maintenanceOnHold,
    MaintenanceStatus.resolved => maintenanceResolved,
    MaintenanceStatus.cancelled => maintenanceCancelled,
  };
}

/// A connection's name: its type and supplier ("Electricity, LESCO
/// (Lahore)"), or the supplier the landlord typed.
String connectionName(
  BuildContext context, {
  required UtilityType type,
  required UtilityProvider provider,
  String? providerOther,
}) {
  final l10n = AppLocalizations.of(context);
  final kind = l10n.utilityType(type);
  final supplier = provider == UtilityProvider.other
      ? (providerOther == null
            ? null
            : inSentence(providerOther, Directionality.of(context)))
      : l10n.utilityProvider(provider);
  return supplier == null ? kind : l10n.connectionName(kind, supplier);
}

/// [connection]'s name, as [connectionName] gives it.
String connectionNameOf(BuildContext context, UtilityConnection connection) =>
    connectionName(
      context,
      type: connection.type,
      provider: connection.provider,
      providerOther: connection.providerOther,
    );

/// Where something is: a property, or a unit of it ("Ground floor, Gulberg
/// House"), each kept in its own direction.
String placeLabel(BuildContext context, String propertyName, String? unit) {
  final l10n = AppLocalizations.of(context);
  final direction = Directionality.of(context);
  final property = inSentence(propertyName, direction);
  return unit == null
      ? property
      : l10n.unitAtProperty(inSentence(unit, direction), property);
}

/// The icon of a kind of connection.
IconData utilityIcon(UtilityType type) => switch (type) {
  UtilityType.electricity => MmIcons.electricity,
  UtilityType.gas => MmIcons.gas,
  UtilityType.water => MmIcons.water,
  UtilityType.internet => MmIcons.internet,
  UtilityType.other => MmIcons.utility,
};

/// A badge saying where [bill] stands today: paid, or how soon or how
/// long ago it is due.
MmStatusBadge billBadge(BuildContext context, UtilityBill bill) {
  final l10n = AppLocalizations.of(context);
  final today = dates.today(context);
  final due = bill.dueDate;
  if (bill.paid) {
    return MmStatusBadge(status: MmStatus.paid, label: l10n.billPaid);
  }
  if (due == null) {
    return MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.clock,
      label: l10n.billUnpaid,
    );
  }
  if (due.isBefore(today)) {
    return MmStatusBadge(
      status: MmStatus.overdue,
      label: l10n.overdueDays(today.differenceInDays(due)),
    );
  }
  final days = due.differenceInDays(today);
  if (days <= Charge.dueSoonDays) {
    return MmStatusBadge(
      status: MmStatus.dueSoon,
      label: days == 0 ? l10n.dueToday : l10n.dueInDays(days),
    );
  }
  return MmStatusBadge(
    status: MmStatus.neutral,
    icon: MmIcons.calendar,
    label: l10n.dueOn(dateLabel(context, due)),
  );
}

/// A badge saying where a month's [use] stands against the protected
/// tariff, or null while it is well within it.
MmStatusBadge? protectedBadge(BuildContext context, ProtectedUse? use) {
  final l10n = AppLocalizations.of(context);
  return switch (use) {
    ProtectedUse.over => MmStatusBadge(
      status: MmStatus.overdue,
      icon: MmIcons.warning,
      label: l10n.protectedOver(ProtectedTariff.limit),
    ),
    ProtectedUse.near => MmStatusBadge(
      status: MmStatus.dueSoon,
      icon: MmIcons.electricity,
      label: l10n.protectedNear(ProtectedTariff.limit),
    ),
    ProtectedUse.within || null => null,
  };
}

/// A badge saying where a repair stands.
MmStatusBadge maintenanceBadge(BuildContext context, MaintenanceStatus status) {
  final l10n = AppLocalizations.of(context);
  final label = l10n.maintenanceStatus(status);
  return switch (status) {
    MaintenanceStatus.open => MmStatusBadge(
      status: MmStatus.dueSoon,
      icon: MmIcons.maintenance,
      label: label,
    ),
    MaintenanceStatus.inProgress => MmStatusBadge(
      status: MmStatus.credit,
      icon: MmIcons.clock,
      label: label,
    ),
    MaintenanceStatus.onHold => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.history,
      label: label,
    ),
    MaintenanceStatus.resolved => MmStatusBadge(
      status: MmStatus.paid,
      label: label,
    ),
    MaintenanceStatus.cancelled => MmStatusBadge(
      status: MmStatus.neutral,
      icon: MmIcons.close,
      label: label,
    ),
  };
}
