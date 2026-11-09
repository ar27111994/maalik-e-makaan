import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/receipt_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:maalik_e_makaan/src/features/reminders/presentation/reminder_sheet.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) => _tap(tester, 'Remind on WhatsApp');

Widget _ledger() => TenancyLedgerScreen(leaseId: aliLease.id);
const _size = Size(360, 1800);

String _message(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is MmTextField && w.label == 'Message to send',
        ),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

void main() {
  testWidgets('opens WhatsApp with the message for the tenant, and logs it', (
    tester,
  ) async {
    final app = await pumpScreen(tester, _ledger, size: _size);
    await _open(tester);
    expect(_message(tester), startsWith('Assalam-o-Alaikum Ali Raza'));
    expect(_message(tester), contains('was due on 5 Oct 2026'));
    expect(find.text('To Ali Raza on 0300 1112233.'), findsOneWidget);
    final message = _message(tester);
    await _tap(tester, 'Send on WhatsApp');
    final link = app.opened.single;
    expect(link.host, 'wa.me');
    expect(link.path, '/923001112233');
    expect(link.queryParameters['text'], message);
    final log = app.reminders.logs.last;
    expect(log.template, ReminderTemplate.overdue);
    expect(log.language, ReminderLanguage.english);
    expect(find.text('Reminder sent and noted in the ledger.'), findsOneWidget);
  });

  testWidgets('an Urdu message runs right to left in the English UI', (
    tester,
  ) async {
    await pumpScreen(tester, _ledger, size: _size);
    await _open(tester);
    await tester.tap(find.byType(Radio<ReminderLanguage>).at(1));
    await tester.pumpAndSettle();
    expect(_message(tester), startsWith('السلام علیکم'));
    final field = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is MmTextField && w.label == 'Message to send',
      ),
      matching: find.byType(EditableText),
    );
    // MmTextField follows the direction of what is typed, whatever the
    // UI's: the Urdu message keeps its order and its full stop's place.
    expect(tester.widget<EditableText>(field).textDirection, TextDirection.rtl);
    await tester.tap(find.byType(Radio<ReminderLanguage>).first);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field).textDirection, TextDirection.ltr);
  });

  testWidgets('the template and language rewrite an unchanged message', (
    tester,
  ) async {
    await pumpScreen(tester, _ledger, size: _size);
    await _open(tester);
    await tester.tap(find.byType(Radio<ReminderLanguage>).at(2));
    await tester.pumpAndSettle();
    expect(_message(tester), contains('wajib-ul-ada thi'));
    await tester.tap(find.byType(Radio<ReminderLanguage>).at(1));
    await tester.pumpAndSettle();
    expect(_message(tester), startsWith('السلام علیکم'));
    final field = find.byWidgetPredicate(
      (w) => w is MmSelectField && w.label == 'Message',
    );
    for (final option in ['Rent due soon', 'Rent due today', 'Utility bill']) {
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option, findRichText: true).last);
      await tester.pumpAndSettle();
    }
    expect(_message(tester), contains('بجلی'));
    // A message changed by hand stays.
    await tester.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is MmTextField && w.label == 'Message to send',
        ),
        matching: find.byType(TextField),
      ),
      'My own words',
    );
    await tester.tap(find.byType(Radio<ReminderLanguage>).first);
    await tester.pumpAndSettle();
    expect(_message(tester), 'My own words');
  });

  testWidgets('a link that does not open is said, and nothing is logged', (
    tester,
  ) async {
    final app = TestApp()..canOpenLinks = false;
    await pumpScreen(tester, _ledger, app: app, size: _size);
    await _open(tester);
    await _tap(tester, 'Send on WhatsApp');
    expect(find.text('The link could not be opened.'), findsOneWidget);
    expect(app.reminders.logs, hasLength(1));
  });

  testWidgets('a log that fails is said, and retried without WhatsApp', (
    tester,
  ) async {
    final app = TestApp()..reminders.writeFailures.add(const NetworkFailure());
    await pumpScreen(tester, _ledger, app: app, size: _size);
    await _open(tester);
    await _tap(tester, 'Send on WhatsApp');
    expect(shown('No connection'), findsOneWidget);
    expect(app.opened, hasLength(1));
    // WhatsApp already has the message: the retry only notes it.
    expect(find.text('Send on WhatsApp'), findsNothing);
    await _tap(tester, 'Note it in the reminders sent');
    expect(app.opened, hasLength(1));
    expect(app.reminders.logs, hasLength(2));
    expect(find.text('Reminder sent and noted in the ledger.'), findsOneWidget);
  });

  testWidgets('late at night it suggests waiting; the message copies', (
    tester,
  ) async {
    final app = TestApp()..now = DateTime.utc(2026, 11, 7, 18);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await pumpScreen(tester, _ledger, app: app, size: _size);
    await _open(tester);
    expect(shown('It is late at night in Pakistan'), findsOneWidget);
    expect(shown('after 8:00'), findsOneWidget);
    expect(find.text('Send anyway'), findsOneWidget);
    await _tap(tester, 'Copy message');
    expect(copied, startsWith('Assalam-o-Alaikum'));
    expect(find.text('Message copied.'), findsOneWidget);
  });

  testWidgets('a tenant without a phone gets the chat to choose', (
    tester,
  ) async {
    final app = TestApp();
    app.tenants.byPortfolio[gulberg.id]!
      ..removeWhere((t) => t.id == aliRaza.id)
      ..add(techCorp);
    await pumpScreen(tester, _ledger, app: app, size: _size);
    await _open(tester);
    expect(shown('This tenant has no phone number'), findsOneWidget);
    await _tap(tester, 'Send on WhatsApp');
    expect(app.opened.single.path, '/');
  });

  testWidgets('a receipt thanks the tenant for the payment', (tester) async {
    await pumpScreen(
      tester,
      () => ReceiptScreen(leaseId: aliLease.id, paymentId: 'pay-oct'),
      size: _size,
    );
    await _tap(tester, 'Thank on WhatsApp');
    expect(_message(tester), contains('Receipt number: MM-2026-00041'));
  });

  testWidgets('a tenancy whose dues are only bills suggests the bill', (
    tester,
  ) async {
    final app = TestApp();
    app.ledger.chargesOf[aliLease.id]!.removeWhere(
      (c) => c.kind != ChargeKind.electricity,
    );
    await pumpScreen(tester, _ledger, app: app, size: _size);
    await _open(tester);
    expect(_message(tester), contains('electricity bill'));
  });

  testWidgets('the history says when it cannot be read', (tester) async {
    final app = TestApp()..reminders.readFailure = const ServerFailure('x');
    await pumpScreen(
      tester,
      () => MmPage(
        title: 'x',
        body: ReminderHistory(leaseId: aliLease.id),
      ),
      app: app,
    );
    expect(find.text('The reminders could not be loaded'), findsOneWidget);
  });
}
