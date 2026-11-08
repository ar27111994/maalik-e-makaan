@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/documents_section.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/bill_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/reading_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utilities_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utility_account_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utility_form_screen.dart';

import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Taps the first button showing [icon] (the same in every language),
/// after scrolling to it.
Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final target = find
      .ancestor(of: find.byIcon(icon), matching: find.byType(MmButton))
      .first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Taps the app bar's button showing [icon].
Future<void> _tapBarIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.widgetWithIcon(IconButton, icon));
  await tester.pumpAndSettle();
}

/// Opens, over the screen, the sheet [builder] makes, titled as the app
/// titles it ([title]), as the screen's own action would.
Future<void> _openSheet(
  WidgetTester tester, {
  required String Function(AppLocalizations l10n) title,
  required Widget Function(BuildContext context) builder,
}) async {
  final context = tester.element(find.byType(MmPage).first);
  showMmSheet<void>(
    context,
    title: title(AppLocalizations.of(context)),
    builder: builder,
  ).ignore();
  await tester.pumpAndSettle();
}

/// Taps the filter chip at [index] of the screen's chips.
Future<void> _tapChip(WidgetTester tester, int index) async {
  await tester.tap(find.byType(FilterChip).at(index));
  await tester.pumpAndSettle();
}

void main() {
  screenGoldenEveryVariant(
    'expenses',
    ExpensesScreen.new,
    size: const Size(360, 900),
    sizes: {
      MmVariant.largeText: const Size(360, 1700),
      MmVariant.urdu: const Size(360, 1200),
    },
  );

  screenGoldenEveryVariant(
    'expenses_empty',
    ExpensesScreen.new,
    app: () => TestApp()..operations.expenseList.clear(),
    sizes: {MmVariant.largeText: const Size(360, 1100)},
  );

  screenGoldenEveryVariant(
    'expense_detail',
    () => ExpenseDetailScreen(expenseId: taxExpense.id),
    size: const Size(360, 1000),
    sizes: {
      MmVariant.largeText: const Size(360, 2200),
      MmVariant.urdu: const Size(360, 1300),
    },
  );

  screenGoldenEveryVariant(
    'expense_form',
    () => ExpenseFormScreen(expenseId: plumberExpense.id),
    size: const Size(360, 1560),
    sizes: {
      MmVariant.largeText: const Size(360, 4300),
      MmVariant.urdu: const Size(360, 2100),
    },
  );

  screenGoldenEveryVariant(
    'utilities',
    UtilitiesScreen.new,
    size: const Size(360, 1000),
    sizes: {
      MmVariant.largeText: const Size(360, 2500),
      MmVariant.urdu: const Size(360, 1400),
    },
  );

  screenGoldenEveryVariant(
    'utility_account',
    () => UtilityAccountScreen(accountId: lescoMeter.id),
    size: const Size(360, 1500),
    sizes: {
      MmVariant.largeText: const Size(360, 3700),
      MmVariant.urdu: const Size(360, 2000),
    },
  );

  screenGoldenEveryVariant(
    'utility_form',
    () => UtilityFormScreen(accountId: lescoMeter.id),
    size: const Size(360, 2000),
    sizes: {
      MmVariant.largeText: const Size(360, 5800),
      MmVariant.urdu: const Size(360, 2700),
    },
  );

  screenGoldenEveryVariant(
    'utility_bill',
    () => BillScreen(billId: novemberBill.id),
    size: const Size(360, 1000),
    sizes: {
      MmVariant.largeText: const Size(360, 2500),
      MmVariant.urdu: const Size(360, 1350),
    },
  );

  screenGoldenEveryVariant(
    'meter_reading',
    () => ReadingScreen(readingId: novemberReading.id),
    size: const Size(360, 900),
    sizes: {
      MmVariant.largeText: const Size(360, 2700),
      MmVariant.urdu: const Size(360, 1100),
    },
  );

  screenGoldenEveryVariant(
    'maintenance',
    MaintenanceScreen.new,
    size: const Size(360, 900),
    sizes: {
      MmVariant.largeText: const Size(360, 2000),
      MmVariant.urdu: const Size(360, 1200),
    },
  );

  screenGoldenEveryVariant(
    'maintenance_detail',
    () => MaintenanceDetailScreen(requestId: seepageJob.id),
    size: const Size(360, 1300),
    sizes: {
      MmVariant.largeText: const Size(360, 3300),
      MmVariant.urdu: const Size(360, 1700),
    },
  );

  screenGoldenEveryVariant(
    'maintenance_form',
    () => MaintenanceFormScreen(requestId: seepageJob.id),
    size: const Size(360, 1960),
    sizes: {
      MmVariant.largeText: const Size(360, 6000),
      MmVariant.urdu: const Size(360, 2400),
    },
  );

  screenGoldenEveryVariant(
    'bill_edit_sheet',
    () => BillScreen(billId: novemberBill.id),
    act: (tester) => _tapBarIcon(tester, MmIcons.edit),
    sizes: {MmVariant.largeText: const Size(360, 1400)},
  );

  // A bill already on the tenant's ledger: its amount is fixed.
  screenGoldenEveryVariant(
    'bill_edit_charged_sheet',
    () => BillScreen(billId: octoberBill.id),
    act: (tester) => _tapBarIcon(tester, MmIcons.edit),
    sizes: {MmVariant.largeText: const Size(360, 1500)},
  );

  // A new bill, already paid: the month, the paid date and who paid.
  screenGoldenEveryVariant(
    'bill_add_sheet',
    () => UtilityAccountScreen(accountId: lescoMeter.id),
    act: (tester) async {
      await _openSheet(
        tester,
        title: (l10n) => l10n.addBillAction,
        builder: (_) => BillFormSheet(
          portfolioId: gulberg.id,
          connection: lescoMeter.connection,
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
    },
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
  );

  // A reading below the one before its day.
  screenGoldenEveryVariant(
    'reading_form_sheet',
    () => UtilityAccountScreen(accountId: lescoMeter.id),
    act: (tester) async {
      await _openSheet(
        tester,
        title: (l10n) => l10n.addReadingAction,
        builder: (_) => ReadingFormSheet(
          portfolioId: gulberg.id,
          connection: lescoMeter.connection,
        ),
      );
      await tester.enterText(find.byType(TextField).first, '12000');
      await tester.pumpAndSettle();
    },
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2100)},
  );

  screenGoldenEveryVariant(
    'mark_paid_sheet',
    () => BillScreen(billId: novemberBill.id),
    act: (tester) => _tapIcon(tester, MmIcons.check),
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );

  screenGoldenEveryVariant(
    'resolve_sheet',
    () => MaintenanceDetailScreen(requestId: seepageJob.id),
    act: (tester) => _tapIcon(tester, MmIcons.check),
    sizes: {MmVariant.largeText: const Size(360, 1200)},
  );

  // The bill with its photos, as the router builds it: the photos, then
  // deleting it, last.
  screenGoldenEveryVariant(
    'utility_bill_photos',
    () => BillScreen(
      billId: novemberBill.id,
      extras: (bill) => DocumentsSection(
        owner: (entity: DocumentEntity.utilityBill, id: bill.id),
      ),
    ),
    size: const Size(360, 1400),
    sizes: {
      MmVariant.largeText: const Size(360, 3300),
      MmVariant.urdu: const Size(360, 1800),
    },
  );

  screenGoldenEveryVariant(
    'maintenance_closed',
    MaintenanceScreen.new,
    act: (tester) => _tapChip(tester, 1),
    sizes: {MmVariant.largeText: const Size(360, 1200)},
  );

  screenGoldenEveryVariant(
    'expense_form_new',
    ExpenseFormScreen.new,
    size: const Size(360, 1500),
    sizes: {
      MmVariant.largeText: const Size(360, 4000),
      MmVariant.urdu: const Size(360, 2000),
    },
  );

  screenGoldenEveryVariant(
    'charge_tenant_sheet',
    () => BillScreen(billId: novemberBill.id),
    act: (tester) => _tapIcon(tester, MmIcons.ledger),
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );
}
