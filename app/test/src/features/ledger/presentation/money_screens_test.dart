import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/presentation/documents_section.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/deposit_sheets.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/lease_money_section.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/money_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/receipt_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/record_payment_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

TestApp _asViewer() => TestApp(portfolios: const [gulbergAsViewer]);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _money(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is MmMoneyField && widget.label == label,
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _text(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is MmTextField && widget.label == label,
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _select(WidgetTester tester, String label, String option) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is MmSelectField && widget.label == label,
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option, findRichText: true).last);
  await tester.pumpAndSettle();
}

/// [rupees] as the app writes them (figures and "Rs" kept together).
String _rs(int rupees) => const MoneyFormat().format(Money.fromRupees(rupees));

/// [rupees] as list rows and badges write them: free to wrap before the
/// figures.
String _rows(int rupees) => _rs(rupees).replaceAll('\u00A0', ' ');

/// The arguments of the fake's last call named [name].
List<Object?> _last(List<Call> calls, String name) =>
    calls.lastWhere((c) => c.$1 == name).$2;

Widget _ledger() => TenancyLedgerScreen(leaseId: aliLease.id);
const _tall = Size(360, 4400);

void main() {
  group('the Money section', () {
    testWidgets('totals what is owed and lists who owes what', (tester) async {
      final app = await pumpScreen(tester, MoneyScreen.new, size: _tall);
      const money = MoneyFormat();
      expect(find.text(money.format(const Money.fromRupees(272450))), findsOne);
      expect(find.text(money.format(const Money.fromRupees(115000))), findsOne);
      // The badge names what is overdue and the oldest due's age, not all
      // that is owed (November's bill is not due yet).
      expect(shown('${_rows(115000)} overdue, oldest 33 days'), findsOneWidget);
      // The amount kept with its currency word: the badge's words as they
      // are, which fit (the badge holds a looser copy it does not show).
      expect(shown('Owes Rs\u00A0'), findsOneWidget);
      expect(shown('Credit Rs\u00A0'), findsOneWidget);
      expect(find.text('Settled or in credit'), findsOneWidget);
      // Owners bring the dues up to date once.
      expect(app.ledger.syncs, 1);
      await _tap(tester, 'Ali Raza');
      expect(routeShown(Routes.ledger(aliLease.id)), findsOneWidget);
    });

    testWidgets('viewers read without bringing dues up to date', (
      tester,
    ) async {
      final app = await pumpScreen(tester, MoneyScreen.new, app: _asViewer());
      expect(app.ledger.syncs, 0);
      expect(find.text('Who owes what'), findsOneWidget);
    });

    testWidgets('a failed billing sync still shows the list', (tester) async {
      final app = TestApp()
        ..ledger.writeFailures.add(const TemporarilyUnavailable());
      await pumpScreen(tester, MoneyScreen.new, app: app);
      expect(find.text('Who owes what'), findsOneWidget);
    });

    testWidgets('nobody owing says so; the cash leads on', (tester) async {
      final app = TestApp()
        ..ledger.leases.remove(aliLease.id)
        ..ledger.extraReceivables.clear();
      await pumpScreen(tester, MoneyScreen.new, app: app);
      expect(find.text('Nobody owes anything now.'), findsOneWidget);
      await tester.tap(find.byIcon(MmIcons.cash));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.cash), findsOneWidget);
    });

    testWidgets('a failure shows why, and retries', (tester) async {
      final app = TestApp()..ledger.readFailure = const NetworkFailure();
      await pumpScreen(tester, MoneyScreen.new, app: app);
      expect(find.text('The money owed could not be loaded'), findsOneWidget);
      app.ledger.readFailure = null;
      await _tap(tester, 'Try again');
      expect(find.text('Who owes what'), findsOneWidget);
    });
  });

  group('a tenancy ledger', () {
    testWidgets('shows the balance, dues, payments, deposit and reminders', (
      tester,
    ) async {
      await pumpScreen(tester, _ledger, size: _tall);
      expect(find.text('Owed now'), findsOneWidget);
      expect(find.text('Rent, October 2026'), findsNWidgets(2));
      expect(shown('${_rs(25000)} left of ${_rs(85000)}'), findsNWidgets(2));
      expect(shown('Overdue 33 days'), findsNWidgets(2));
      expect(shown('Due in 3 days'), findsNWidgets(2));
      expect(shown('Waived'), findsOneWidget);
      expect(shown('Voided'), findsNWidgets(2));
      expect(shown('Receipt MM-\u200B2026-\u200B00041'), findsOneWidget);
      expect(find.text('Deposit held'), findsOneWidget);
      expect(find.text('Rent overdue'), findsOneWidget);
      await _tap(tester, 'Tenancy details');
      expect(routeShown(Routes.lease(aliLease.id)), findsOneWidget);
    });

    testWidgets('leads to recording a payment and to a receipt', (
      tester,
    ) async {
      await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, 'Record payment');
      expect(routeShown(Routes.recordPayment(aliLease.id)), findsOneWidget);
    });

    testWidgets('a payment row opens its receipt', (tester) async {
      await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, _rows(60000));
      expect(routeShown(Routes.receipt(aliLease.id, 'pay-oct')), findsOne);
    });

    testWidgets('viewers see the money without the actions', (tester) async {
      await pumpScreen(
        tester,
        () => TenancyLedgerScreen(leaseId: endedLease.id),
        app: _asViewer(),
        size: _tall,
      );
      expect(find.text('Record payment'), findsNothing);
      expect(find.text('Add charge'), findsNothing);
      // Viewers hear the fact, not what to do with it.
      expect(shown('the tenant has ${_rs(15000)} in credit'), findsOneWidget);
      expect(shown('Refund it to the tenant'), findsNothing);
      expect(find.text('Open the payment'), findsNothing);
      expect(find.text('Nothing is owed.'), findsOneWidget);
      expect(find.text('No reminders sent yet.'), findsOneWidget);
    });

    testWidgets('owners are told what to do with an ended tenancy credit', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => TenancyLedgerScreen(leaseId: endedLease.id),
        size: _tall,
      );
      expect(shown('Refund it to the tenant'), findsOneWidget);
      await _tap(tester, 'Open the payment');
      expect(routeShown(Routes.receipt(endedLease.id, 'pay-hamid')), findsOne);
    });

    testWidgets('pages of dues and payments load on', (tester) async {
      final app = TestApp()..ledger.pageLimit = 2;
      await pumpScreen(tester, _ledger, app: app, size: _tall);
      expect(find.text('Show more'), findsNWidgets(2));
      await _tap(tester, 'Show more');
      expect(_last(app.ledger.calls, 'charges').last, isNotNull);
      await tester.tap(find.text('Show more').first);
      await tester.pumpAndSettle();
      expect(app.ledger.calls.any((c) => c.$1 == 'payments'), isTrue);
    });

    testWidgets('the statement is made in the chosen language and shared', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _ledger);
      await tester.tap(find.byIcon(MmIcons.document));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Radio<DocumentLanguage>).last);
      await tester.pumpAndSettle();
      await _tap(tester, 'Share PDF');
      expect(app.made.single, ('statement', DocumentLanguage.urdu));
      final shared = app.sharer.shared.single;
      expect(shared.fileName, 'statement-Ali-Raza-2026-11-07.pdf');
      expect(shared.title, 'اسٹیٹمنٹ، Ali Raza');
      expect(shared.bytes, fakePdf);
    });

    testWidgets('a statement that cannot be shared says why', (tester) async {
      final app = TestApp()..sharer.failure = const NetworkFailure();
      await pumpScreen(tester, _ledger, app: app);
      await tester.tap(find.byIcon(MmIcons.document));
      await tester.pumpAndSettle();
      await _tap(tester, 'Share PDF');
      expect(shown('No connection'), findsOneWidget);
      app
        ..sharer.failure = null
        ..ledger.readFailure = const ServerFailure('x');
      await _tap(tester, 'Share PDF');
      expect(shown('Something went wrong on our side'), findsOneWidget);
    });
  });

  group('a due', () {
    Future<void> openOctober(WidgetTester tester) async {
      await tester.tap(find.text('Rent, October 2026').first);
      await tester.pumpAndSettle();
    }

    testWidgets('shows its amounts; a paid one cannot be voided', (
      tester,
    ) async {
      await pumpScreen(tester, _ledger, size: _tall);
      await openOctober(tester);
      expect(find.text('Still owed'), findsOneWidget);
      expect(shown('Money was received for this due'), findsOneWidget);
      expect(find.text('Void charge'), findsNothing);
    });

    testWidgets('editing changes only its date; rent keeps its amount', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await openOctober(tester);
      await _tap(tester, 'Edit charge');
      expect(shown('Rent, late fees and the deposit keep'), findsOneWidget);
      await _text(tester, 'Note', 'Agreed to pay on the 10th');
      await _tap(tester, 'Save');
      expect(_last(app.ledger.calls, 'updateCharge'), [
        'ch-rent-10',
        null,
        null,
        'Agreed to pay on the 10th',
      ]);
      expect(find.text('Charge saved.'), findsOneWidget);
    });

    testWidgets('a charge added by hand changes amount, not below paid', (
      tester,
    ) async {
      final app = TestApp();
      final charges = app.ledger.chargesOf[aliLease.id]!;
      final index = charges.indexWhere((c) => c.id == 'ch-electricity');
      charges[index] = Charge.fromRow({
        ...charges[index].toRow(),
        'paid_amount': '1000.00',
        'outstanding': '6450.00',
      });
      await pumpScreen(tester, _ledger, app: app, size: _tall);
      await tester.tap(find.text('Electricity, October 2026').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Edit charge');
      expect(shown('At least ${_rs(1000)}'), findsOneWidget);
      await _money(tester, 'Amount', '500');
      await _tap(tester, 'Save');
      expect(app.ledger.calls.any((c) => c.$1 == 'updateCharge'), isFalse);
      await _money(tester, 'Amount', '');
      await _tap(tester, 'Save');
      expect(shown('Enter an amount'), findsWidgets);
      await _money(tester, 'Amount', '8000');
      app.ledger.writeFailures.add(const RejectedFailure('invalid_amount'));
      await _tap(tester, 'Save');
      expect(shown('Enter an amount above zero'), findsOneWidget);
      app.ledger.writeFailures.add(const RejectedFailure('charge_voided'));
      await _tap(tester, 'Save');
      expect(shown('This charge was voided'), findsOneWidget);
      await _tap(tester, 'Save');
      expect(
        _last(app.ledger.calls, 'updateCharge')[1],
        const Money.fromRupees(8000),
      );
    });

    testWidgets('waiving needs a reason and may forgive part', (tester) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await openOctober(tester);
      await _tap(tester, 'Waive');
      await _tap(tester, 'Waive');
      expect(shown('Please give a reason.'), findsOneWidget);
      await _money(tester, 'Amount to waive', '5000');
      await _text(tester, 'Reason', 'Repairs the tenant paid for');
      await _tap(tester, 'Waive');
      expect(_last(app.ledger.calls, 'waiveCharge'), [
        'ch-rent-10',
        'Repairs the tenant paid for',
        const Money.fromRupees(5000),
      ]);
      expect(find.text('Due waived.'), findsOneWidget);
    });

    testWidgets('an amount to waive that is not acceptable waives nothing', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await openOctober(tester);
      await _tap(tester, 'Waive');
      await _text(tester, 'Reason', 'Repairs the tenant paid for');
      // Zero, more than two decimals, and more than the Rs 25,000 owed:
      // each is refused beside the field, and nothing is sent (an empty
      // amount would forgive all that is owed).
      for (final (typed, error) in [
        ('0', 'Enter an amount, like 25,000.'),
        ('100.555', 'Enter an amount, like 25,000.'),
        ('30000', 'At most ${_rs(25000)}.'),
      ]) {
        await _money(tester, 'Amount to waive', typed);
        await _tap(tester, 'Waive');
        expect(shown(error), findsOneWidget, reason: typed);
        expect(app.ledger.calls.any((c) => c.$1 == 'waiveCharge'), isFalse);
      }
      // The server's refusal of the amount shows beside it too.
      await _money(tester, 'Amount to waive', '20000');
      app.ledger.writeFailures.add(
        const RejectedFailure('amount_exceeds_outstanding'),
      );
      await _tap(tester, 'Waive');
      expect(shown('more than this tenancy owes'), findsOneWidget);
      // Emptied, the field waives all of it.
      await _money(tester, 'Amount to waive', '');
      await _tap(tester, 'Waive');
      expect(_last(app.ledger.calls, 'waiveCharge'), [
        'ch-rent-10',
        'Repairs the tenant paid for',
        null,
      ]);
    });

    testWidgets('voiding an unpaid due keeps it, voided', (tester) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await tester.tap(find.text('Late fee').first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Void charge');
      app.ledger.writeFailures.add(
        const RejectedFailure('charge_has_payments'),
      );
      await _text(tester, 'Reason', 'Paid within grace');
      await _tap(tester, 'Void charge');
      expect(shown('Money has been received against this charge'), findsOne);
      await _tap(tester, 'Void charge');
      expect(_last(app.ledger.calls, 'voidCharge'), [
        'ch-fee-10',
        'Paid within grace',
      ]);
      expect(find.text('Due voided.'), findsOneWidget);
    });

    testWidgets('a voided due shows why, with no actions', (tester) async {
      await pumpScreen(tester, _ledger, size: _tall);
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      expect(find.text('Entered for the wrong tenant'), findsOneWidget);
      expect(find.text('Edit charge'), findsNothing);
    });

    testWidgets('a charge is added with its kind, month and note', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, 'Add charge');
      await _tap(tester, 'Add charge');
      expect(shown('Enter an amount'), findsWidgets);
      await _select(tester, 'What for', 'Water');
      await _money(tester, 'Amount', '900');
      await _select(tester, 'For the month of', 'October 2026');
      await _text(tester, 'Note', 'WASA');
      await _tap(tester, 'Add charge');
      final draft = _last(app.ledger.calls, 'addCharge').last! as ChargeDraft;
      expect(draft.kind, ChargeKind.water);
      expect(draft.amount, const Money.fromRupees(900));
      expect(draft.periodMonth, MonthPeriod(2026, 10));
      expect(draft.description, 'WASA');
      expect(find.text('Water added.'), findsOneWidget);
    });
  });

  group('recording a payment', () {
    Widget form() => RecordPaymentScreen(leaseId: aliLease.id);
    const size = Size(360, 3200);

    testWidgets('needs an amount, previews what it settles, records once', (
      tester,
    ) async {
      final app = await pumpScreen(tester, form, size: size);
      await _tap(tester, 'Record payment');
      expect(shown('Enter an amount'), findsWidgets);
      expect(app.ledger.calls.any((c) => c.$1 == 'recordPayment'), isFalse);
      await _tap(tester, 'Use ${_rs(122450)} owed');
      expect(find.text('Rent, November 2026, in full'), findsOneWidget);
      await _money(tester, 'Amount received', '130000');
      await tester.pumpAndSettle();
      expect(find.text('Kept as credit'), findsOneWidget);
      await _select(tester, 'Paid by', 'Bank transfer');
      await _text(tester, 'Reference', 'IBFT 99');
      // The answer is lost: the retry sends the same key.
      app.ledger.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Record payment');
      expect(shown('No connection'), findsOneWidget);
      await _tap(tester, 'Record payment');
      final tries = [
        for (final c in app.ledger.calls)
          if (c.$1 == 'recordPayment') c.$2.single! as PaymentDraft,
      ];
      expect(tries, hasLength(2));
      expect(tries.first.idempotencyKey, tries.last.idempotencyKey);
      expect(tries.last.method, PaymentMethod.bankTransfer);
      expect(tries.last.reference, 'IBFT 99');
      expect(tries.last.chargeIds, isNull);
      expect(routeShown(Routes.receipt(aliLease.id, 'pay-6')), findsNothing);
      expect(find.textContaining('route:/money/leases/'), findsOneWidget);
    });

    testWidgets('tax withheld settles the gross and needs a valid amount', (
      tester,
    ) async {
      final app = await pumpScreen(tester, form, size: size);
      await _money(tester, 'Amount received', '76500');
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await _money(tester, 'Tax withheld (s.155)', '90000');
      await _tap(tester, 'Record payment');
      expect(shown('Tax withheld cannot be more than the payment.'), findsOne);
      await _money(tester, 'Tax withheld (s.155)', '8500');
      await _text(tester, 'Certificate or CPR number', 'CPR-1');
      await tester.pumpAndSettle();
      expect(shown('settle ${_rs(85000)} of dues'), findsOneWidget);
      app.ledger.writeFailures.add(
        const RejectedFailure('invalid_tax_withheld'),
      );
      await _tap(tester, 'Record payment');
      expect(shown('Tax withheld cannot be more than the payment.'), findsOne);
      app.ledger.writeFailures.add(const RejectedFailure('invalid_amount'));
      await _tap(tester, 'Record payment');
      expect(shown('Enter an amount above zero'), findsOneWidget);
      app.ledger.writeFailures.add(const RejectedFailure('invalid_date'));
      await _tap(tester, 'Record payment');
      expect(shown('Choose a valid date.'), findsOneWidget);
      await _tap(tester, 'Record payment');
      final draft =
          _last(app.ledger.calls, 'recordPayment').single! as PaymentDraft;
      expect(draft.taxWithheld, const Money.fromRupees(8500));
      expect(draft.taxCertificateNo, 'CPR-1');
    });

    testWidgets('chosen dues are settled first', (tester) async {
      final app = await pumpScreen(tester, form, size: size);
      await _money(tester, 'Amount received', '85000');
      await _tap(tester, 'The dues I choose');
      await _tap(tester, 'Record payment');
      expect(shown('Choose at least one due.'), findsOneWidget);
      await _tap(tester, 'Rent, November 2026');
      await tester.pumpAndSettle();
      expect(find.text('Rent, November 2026, in full'), findsOneWidget);
      await _tap(tester, 'Rent, November 2026');
      await _tap(tester, 'Rent, November 2026');
      await _tap(tester, 'Record payment');
      final draft =
          _last(app.ledger.calls, 'recordPayment').single! as PaymentDraft;
      expect(draft.chargeIds, ['ch-rent-11']);
    });

    testWidgets('with nothing owed, the payment is all credit', (tester) async {
      final app = TestApp();
      app.leases.leaseList.add(endedLease);
      await pumpScreen(
        tester,
        () => RecordPaymentScreen(leaseId: endedLease.id),
        app: app,
        size: size,
      );
      expect(shown('Nothing is owed now'), findsOneWidget);
      await _money(tester, 'Amount received', '5000');
      await tester.pumpAndSettle();
      expect(shown('All ${_rs(5000)} is kept as credit'), findsOneWidget);
    });

    testWidgets('typing the amount owed keeps the field focused', (
      tester,
    ) async {
      await pumpScreen(tester, form, size: size);
      final field = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is MmMoneyField && w.label == 'Amount received',
        ),
        matching: find.byType(EditableText),
      );
      await tester.tap(field);
      await tester.pump();
      // One digit at a time, through exactly what is owed and past it.
      for (final typed in ['12245', '122450', '1224500']) {
        await tester.enterText(field, typed);
        await tester.pump();
        expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      }
      expect(tester.widget<EditableText>(field).controller.text, '1,224,500');
    });

    testWidgets('a rent paid within its grace period cancels its late fee', (
      tester,
    ) async {
      final app = TestApp();
      // Today is within October's grace period.
      app.ledger.leases[aliLease.id] = Lease.fromRow({
        ...aliLease.toRow(),
        'grace_days': 40,
      });
      await pumpScreen(tester, form, app: app, size: size);
      await _money(tester, 'Amount received', '30000');
      await tester.pumpAndSettle();
      // The fee is not shown as settled: the money goes on to November.
      expect(find.text('Rent, October 2026, in full'), findsOneWidget);
      expect(find.text('Late fee, in full'), findsNothing);
      expect(find.text('Rent, November 2026, in part'), findsOneWidget);
      expect(shown('late fee of ${_rs(5000)} will be cancelled'), findsOne);
    });

    testWidgets('a changed payment after a lost answer keeps its key', (
      tester,
    ) async {
      final app = await pumpScreen(tester, form, size: size);
      await _money(tester, 'Amount received', '50000');
      app.ledger.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Record payment');
      expect(shown('No connection'), findsOneWidget);
      // The first may have been recorded: the server refuses the same key
      // with other details, and the form says to check the ledger.
      await _money(tester, 'Amount received', '60000');
      app.ledger.writeFailures.add(
        const RejectedFailure('idempotency_key_reused'),
      );
      await _tap(tester, 'Record payment');
      expect(shown('already recorded with different details'), findsOne);
      final keys = {
        for (final c in app.ledger.calls)
          if (c.$1 == 'recordPayment')
            (c.$2.single! as PaymentDraft).idempotencyKey,
      };
      expect(keys, hasLength(1));
    });

    testWidgets('a ledger that cannot be read says why', (tester) async {
      final app = TestApp()..ledger.readFailure = const ServerFailure('x');
      await pumpScreen(tester, form, app: app);
      expect(find.text('This ledger could not be loaded'), findsOneWidget);
    });
  });

  group('a receipt', () {
    Widget receipt([String id = 'pay-oct']) =>
        ReceiptScreen(leaseId: aliLease.id, paymentId: id);
    const size = Size(360, 1600);

    testWidgets('shows the raseed and shares it in English', (tester) async {
      final app = await pumpScreen(tester, receipt, size: size);
      expect(shown('MM-\u200B2026-\u200B00041'), findsOneWidget);
      expect(find.text('IBFT 778812'), findsOneWidget);
      expect(find.text('Rent, October 2026'), findsOneWidget);
      await _tap(tester, 'Share receipt');
      await _tap(tester, 'Share PDF');
      expect(app.made.single, ('receipt', DocumentLanguage.english));
      expect(app.sharer.shared.single.fileName, 'receipt-MM-2026-00041.pdf');
      expect(app.sharer.shared.single.title, 'Receipt MM-2026-00041');
      await _tap(tester, 'Open the ledger');
      expect(routeShown(Routes.ledger(aliLease.id)), findsOneWidget);
    });

    testWidgets('tax withheld and credit show on the receipt', (tester) async {
      final app = TestApp();
      final payments = app.ledger.paymentsOf[aliLease.id]!;
      final index = payments.indexWhere((p) => p.id == 'pay-oct');
      payments[index] = Payment.fromRow({
        ...payments[index].toRow(),
        'tax_withheld': '4500.00',
        'tax_certificate_no': 'CPR-7',
      });
      await pumpScreen(tester, receipt, app: app, size: size);
      expect(find.text('CPR-7'), findsOneWidget);
      expect(find.text('Total, with tax'), findsOneWidget);
      expect(find.text('Kept as credit'), findsOneWidget);
    });

    testWidgets('voiding needs a reason and keeps the receipt, void', (
      tester,
    ) async {
      final app = await pumpScreen(tester, receipt, size: size);
      await _tap(tester, 'Void payment');
      await _text(tester, 'Reason', 'Cheque bounced');
      await _tap(tester, 'Void payment');
      expect(_last(app.ledger.calls, 'voidPayment'), [
        'pay-oct',
        'Cheque bounced',
      ]);
      expect(find.text('Payment voided.'), findsOneWidget);
      expect(shown('VOID: cancelled on 7 Nov 2026'), findsOneWidget);
      expect(find.text('Void payment'), findsNothing);
    });

    testWidgets('a voided receipt leads back to the ledger first', (
      tester,
    ) async {
      final app = await pumpScreen(tester, () => receipt('pay-twice'));
      expect(find.text('Share receipt'), findsNothing);
      expect(
        tester
            .widget<MmButton>(find.widgetWithText(MmButton, 'Open the ledger'))
            .variant,
        MmButtonVariant.primary,
      );
      await _tap(tester, 'Share voided receipt');
      await _tap(tester, 'Share PDF');
      expect(app.made.single, ('receipt', DocumentLanguage.english));
      // No proof is added to a voided payment.
      expect(find.text('Add document'), findsNothing);
    });

    testWidgets('a payment keeps its proof among its documents', (
      tester,
    ) async {
      final app = await pumpScreen(tester, receipt, size: size);
      expect(find.text('Documents'), findsOneWidget);
      expect(
        app.documents.calls.any(
          (c) =>
              c.$1 == 'documents' &&
              c.$2[1] == (entity: DocumentEntity.payment, id: 'pay-oct'),
        ),
        isTrue,
      );
      await _tap(tester, 'Add document');
      expect(find.byType(AddDocumentSheet), findsOneWidget);
    });

    testWidgets('viewers only share; a missing receipt says why', (
      tester,
    ) async {
      await pumpScreen(tester, receipt, app: _asViewer(), size: size);
      expect(find.text('Void payment'), findsNothing);
      expect(find.text('Thank on WhatsApp'), findsNothing);
      await pumpScreen(tester, () => receipt('nope'));
      expect(find.text('This receipt could not be loaded'), findsOneWidget);
    });
  });

  group('the deposit', () {
    testWidgets('settles dues, with a key kept for retries', (tester) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, 'Use for dues');
      await _money(tester, 'Amount', '500000');
      await _tap(tester, 'Use for dues');
      expect(shown('At most ${_rs(122450)}'), findsWidgets);
      await _money(tester, 'Amount', '20000');
      app.ledger.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Use for dues');
      await _tap(tester, 'Use for dues');
      final keys = [
        for (final c in app.ledger.calls)
          if (c.$1 == 'applyDeposit') c.$2.last,
      ];
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(shown('of the deposit settled dues'), findsOneWidget);
    });

    testWidgets('is refunded; a lost answer says to check first', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, 'Refund deposit');
      await _money(tester, 'Amount', '900000');
      await _tap(tester, 'Refund deposit');
      expect(shown('At most ${_rs(170000)}'), findsWidgets);
      await _money(tester, 'Amount', '50000');
      await _select(tester, 'Paid by', 'Raast');
      app.ledger.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Refund deposit');
      expect(shown('the refund may have been recorded'), findsOneWidget);
      // The sheet cannot send it again: it only closes.
      final sheet = find.byType(RefundDepositSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Refund deposit')),
        findsNothing,
      );
      await _tap(tester, 'Close and check the deposit');
      expect(sheet, findsNothing);
      expect(
        app.ledger.calls.where((c) => c.$1 == 'refundDeposit'),
        hasLength(1),
      );
      // A new refund starts from what the deposit holds now.
      await _tap(tester, 'Refund deposit');
      expect(shown('You hold ${_rs(170000)}'), findsOneWidget);
      await _money(tester, 'Amount', '50000');
      await _select(tester, 'Paid by', 'Raast');
      await _tap(tester, 'Refund deposit');
      expect(shown('of the deposit refunded'), findsOneWidget);
      expect(_last(app.ledger.calls, 'refundDeposit')[3], PaymentMethod.raast);
      // The owner voids the refund from its row.
      await _tap(tester, 'Refund of ${_rows(50000)}');
      await _text(tester, 'Reason', 'Typed twice');
      await _tap(tester, 'Void refund');
      expect(_last(app.ledger.calls, 'voidDepositRefund').last, 'Typed twice');
      expect(find.text('Refund voided.'), findsOneWidget);
    });

    testWidgets('a refund recorded but whose answer was lost is found', (
      tester,
    ) async {
      final app = await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, 'Refund deposit');
      await _money(tester, 'Amount', '50000');
      app.ledger.lostAnswers.add('refundDeposit');
      await _tap(tester, 'Refund deposit');
      // The ledger read again shows it: it is reported as recorded, once.
      expect(shown('of the deposit refunded'), findsOneWidget);
      expect(find.byType(RefundDepositSheet), findsNothing);
      expect(
        app.ledger.calls.where((c) => c.$1 == 'refundDeposit'),
        hasLength(1),
      );
      expect(shown('the refund may have been recorded'), findsNothing);
    });

    testWidgets('a running tenancy warns before the deposit is used', (
      tester,
    ) async {
      await pumpScreen(tester, _ledger, size: _tall);
      await _tap(tester, 'Use for dues');
      expect(shown('This tenancy is still running'), findsOneWidget);
      Navigator.of(tester.element(find.byType(ApplyDepositSheet))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, 'Refund deposit');
      expect(shown('This tenancy is still running'), findsOneWidget);
    });

    testWidgets('an ended tenancy still holding it is nudged', (tester) async {
      final app = TestApp();
      app.ledger.leases[aliLease.id] = Lease.fromRow({
        ...aliLease.toRow(),
        'status': 'ended',
        'moved_out_on': '2026-11-01',
        'end_reason': 'tenant_moved_out',
      });
      await pumpScreen(tester, _ledger, app: app, size: _tall);
      expect(shown('you still hold the deposit'), findsOneWidget);
      // The move-out steps carry no warning once the tenant has left.
      await _tap(tester, 'Refund deposit');
      expect(shown('This tenancy is still running'), findsNothing);
    });
  });

  testWidgets('a tenancy screen shows its balance and leads to the ledger', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      () => MmPage(
        title: 'x',
        body: LeaseMoneySection(leaseId: aliLease.id),
      ),
    );
    expect(find.text('Owed now: ${_rs(122450)}'), findsOneWidget);
    await _tap(tester, 'Open the ledger');
    expect(routeShown(Routes.ledger(aliLease.id)), findsOneWidget);
  });
}
