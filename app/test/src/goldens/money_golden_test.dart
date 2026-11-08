@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/handovers/presentation/cash_book_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/charge_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/deposit_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/receipt_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/record_payment_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/notifications/presentation/notifications_screen.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// Taps the control showing [icon] (the same in every language), after
/// scrolling to it.
Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  final target = find.byIcon(icon).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Taps the control showing [icon] inside the open [sheet] (its primary
/// button when [icon] is null), after scrolling to it.
Future<void> _tapIn(WidgetTester tester, Type sheet, IconData? icon) async {
  final target = find
      .descendant(
        of: find.byType(sheet),
        matching: icon == null ? find.byType(MmButton) : find.byIcon(icon),
      )
      .last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Taps the first or last button of [section], after scrolling to it.
Future<void> _tapButton(
  WidgetTester tester,
  Type section, {
  required bool first,
}) async {
  final buttons = find.descendant(
    of: find.byType(section),
    matching: find.byType(MmButton),
  );
  final target = first ? buttons.first : buttons.last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

TestApp _asViewer() => TestApp(portfolios: const [gulbergAsViewer]);

TestApp _plazaOnly() => TestApp(portfolios: const [plaza]);

/// October's payment with tax withheld beside it, which the rent did not
/// need: it is kept as credit.
TestApp _withTaxedPayment() {
  final app = TestApp();
  final payments = app.ledger.paymentsOf[aliLease.id]!;
  final index = payments.indexWhere((p) => p.id == 'pay-oct');
  payments[index] = Payment.fromRow({
    ...payments[index].toRow(),
    'tax_withheld': '4500.00',
    'tax_certificate_no': 'CPR-2026-118822',
  });
  return app;
}

void main() {
  screenGoldenEveryVariant(
    'money',
    MoneyScreen.new,
    size: const Size(360, 1100),
    sizes: {MmVariant.largeText: const Size(360, 2600)},
  );

  screenGoldenEveryVariant(
    'money_empty',
    MoneyScreen.new,
    app: _plazaOnly,
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );

  screenGoldenEveryVariant(
    'ledger',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 4200),
    sizes: {
      MmVariant.largeText: const Size(360, 9600),
      MmVariant.urdu: const Size(360, 5600),
    },
  );

  screenGoldenEveryVariant(
    'ledger_viewer',
    () => TenancyLedgerScreen(leaseId: endedLease.id),
    app: _asViewer,
    size: const Size(360, 1700),
    sizes: {
      MmVariant.largeText: const Size(360, 3600),
      MmVariant.urdu: const Size(360, 2200),
    },
  );

  screenGoldenEveryVariant(
    'charge_sheet',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 1800)},
    act: (tester) async {
      // October's rent: part paid, overdue, with a late fee.
      await _tapIcon(tester, MmIcons.home);
    },
  );

  screenGoldenEveryVariant(
    'waive_sheet',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2400)},
    act: (tester) async {
      await _tapIcon(tester, MmIcons.home);
      // The Waive button inside the open sheet (a "Waived" badge behind it
      // has the same icon).
      await _tapIn(tester, ChargeSheet, MmIcons.check);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(ReasonSheet),
              matching: find.byType(TextField),
            )
            .first,
        '30000',
      );
      await _tapIn(tester, ReasonSheet, null);
    },
  );

  screenGoldenEveryVariant(
    'edit_charge_sheet',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2400)},
    act: (tester) async {
      await _tapIcon(tester, MmIcons.electricity);
      await _tapIn(tester, ChargeSheet, MmIcons.edit);
    },
  );

  screenGoldenEveryVariant(
    'apply_deposit_sheet',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 1100),
    sizes: {MmVariant.largeText: const Size(360, 2600)},
    act: (tester) => _tapButton(tester, DepositSection, first: true),
  );

  screenGoldenEveryVariant(
    'refund_deposit_sheet',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 1300),
    sizes: {MmVariant.largeText: const Size(360, 3000)},
    act: (tester) => _tapButton(tester, DepositSection, first: false),
  );

  screenGoldenEveryVariant(
    'add_charge_sheet',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2200)},
    act: (tester) async {
      final add = find.descendant(
        of: find.byType(MmSectionHeader),
        matching: find.byType(TextButton),
      );
      await tester.ensureVisible(add.first);
      await tester.tap(add.first);
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'record_payment',
    () => RecordPaymentScreen(leaseId: aliLease.id),
    size: const Size(360, 2200),
    sizes: {
      MmVariant.largeText: const Size(360, 4800),
      MmVariant.urdu: const Size(360, 2900),
    },
    act: (tester) async {
      await tester.enterText(find.byType(TextField).first, '100000');
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'record_payment_chosen',
    () => RecordPaymentScreen(leaseId: aliLease.id),
    size: const Size(360, 2900),
    sizes: {
      MmVariant.largeText: const Size(360, 6400),
      MmVariant.urdu: const Size(360, 3800),
    },
    act: (tester) async {
      await tester.enterText(find.byType(TextField).first, '80000');
      await tester.pumpAndSettle();
      // Tax withheld, then choose November's rent.
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '8000');
      await tester.pumpAndSettle();
      final choose = find.byType(RadioGroup<bool>);
      await tester.ensureVisible(choose);
      await tester.tap(
        find.descendant(of: choose, matching: find.byType(Radio<bool>)).last,
      );
      await tester.pumpAndSettle();
      final boxes = find.byType(Checkbox);
      await tester.ensureVisible(boxes.at(2));
      await tester.tap(boxes.at(2));
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'receipt',
    () => ReceiptScreen(leaseId: aliLease.id, paymentId: 'pay-oct'),
    app: _withTaxedPayment,
    size: const Size(360, 1500),
    sizes: {
      MmVariant.largeText: const Size(360, 3300),
      MmVariant.urdu: const Size(360, 1900),
    },
  );

  screenGoldenEveryVariant(
    'receipt_voided',
    () => ReceiptScreen(leaseId: aliLease.id, paymentId: 'pay-twice'),
    size: const Size(360, 1100),
    sizes: {MmVariant.largeText: const Size(360, 2400)},
  );

  screenGoldenEveryVariant(
    'void_payment_sheet',
    () => ReceiptScreen(leaseId: aliLease.id, paymentId: 'pay-oct'),
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: (tester) async {
      await _tapIcon(tester, MmIcons.close);
      // Confirmed without a reason: the sheet asks for one.
      await _tapIn(tester, ReasonSheet, null);
    },
  );

  screenGoldenEveryVariant(
    'share_document_sheet',
    () => ReceiptScreen(leaseId: aliLease.id, paymentId: 'pay-oct'),
    sizes: {MmVariant.largeText: const Size(360, 1200)},
    act: (tester) => _tapIcon(tester, MmIcons.share),
  );

  screenGoldenEveryVariant(
    'reminder_composer',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    size: const Size(360, 1500),
    sizes: {MmVariant.largeText: const Size(360, 3200)},
    act: (tester) => _tapIcon(tester, MmIcons.reminder),
  );

  screenGoldenEveryVariant(
    'reminder_etiquette',
    () => TenancyLedgerScreen(leaseId: aliLease.id),
    app: () => TestApp()
      // Friday 13 November 2026, 1 PM in Pakistan, two days after the last
      // reminder.
      ..now = DateTime.utc(2026, 11, 13, 8)
      ..reminders.logs.first = ReminderLog(
        id: 'rem-1',
        leaseId: aliLease.id,
        channel: ReminderChannel.whatsapp,
        template: ReminderTemplate.overdue,
        language: ReminderLanguage.urdu,
        sentAt: DateTime.utc(2026, 11, 11, 6),
      ),
    size: const Size(360, 1700),
    sizes: {MmVariant.largeText: const Size(360, 3800)},
    act: (tester) => _tapIcon(tester, MmIcons.reminder),
  );

  screenGoldenEveryVariant(
    'cash_book',
    CashBookScreen.new,
    size: const Size(360, 1200),
    sizes: {MmVariant.largeText: const Size(360, 2800)},
  );

  screenGoldenEveryVariant(
    'handover_sheet',
    CashBookScreen.new,
    size: const Size(360, 1300),
    sizes: {MmVariant.largeText: const Size(360, 2900)},
    act: (tester) => _tapIcon(tester, MmIcons.transfer),
  );

  screenGoldenEveryVariant(
    'handover_actions',
    CashBookScreen.new,
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 1800)},
    act: (tester) => _tapIcon(tester, MmIcons.cash),
  );

  screenGoldenEveryVariant(
    'void_handover_sheet',
    CashBookScreen.new,
    size: const Size(360, 900),
    sizes: {MmVariant.largeText: const Size(360, 2000)},
    act: (tester) async {
      await _tapIcon(tester, MmIcons.cash);
      await _tapIn(tester, HandoverActions, MmIcons.close);
    },
  );

  screenGoldenEveryVariant(
    'notifications',
    NotificationsScreen.new,
    size: const Size(360, 1000),
    sizes: {MmVariant.largeText: const Size(360, 2400)},
  );

  screenGoldenEveryVariant(
    'notification_sheet',
    NotificationsScreen.new,
    sizes: {MmVariant.largeText: const Size(360, 1400)},
    act: (tester) async {
      await tester.tap(find.byType(MmListTile).first);
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'notifications_empty',
    NotificationsScreen.new,
    app: _plazaOnly,
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );

  screenGoldenEveryVariant(
    'money_error',
    MoneyScreen.new,
    app: () => TestApp()..ledger.readFailure = const NetworkFailure(),
    sizes: {MmVariant.largeText: const Size(360, 1000)},
  );
}
