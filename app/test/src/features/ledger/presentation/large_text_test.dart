import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/handovers/presentation/cash_book_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/receipt_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/notifications/presentation/notifications_screen.dart';

import '../../../../support/harness.dart';

/// The Money screens at 200% text on a 320 dp phone, in English and in
/// Urdu: nothing overflows, and no line breaks inside a word or a number
/// (an amount wrapping as "Rs 1,50" / "0", a date as "5" / "Nov 2026").
void main() {
  final screens = <String, Widget Function()>{
    'money': MoneyScreen.new,
    'ledger': () => TenancyLedgerScreen(leaseId: aliLease.id),
    'ended ledger': () => TenancyLedgerScreen(leaseId: endedLease.id),
    'receipt': () => ReceiptScreen(leaseId: aliLease.id, paymentId: 'pay-oct'),
    'cash book': CashBookScreen.new,
    'notifications': NotificationsScreen.new,
  };
  for (final MapEntry(key: name, value: screen) in screens.entries) {
    for (final variant in const [MmVariant.largeText, MmVariant.urdu]) {
      testWidgets('$name keeps whole words at 200% (${variant.name})', (
        tester,
      ) async {
        await pumpScreen(
          tester,
          screen,
          variant: variant,
          size: const Size(320, 12000),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        final broken = brokenWords(tester);
        expect(broken, isEmpty, reason: 'lines break inside words: $broken');
      });
    }
  }
}
