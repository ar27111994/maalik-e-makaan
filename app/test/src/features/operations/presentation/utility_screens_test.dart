import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/operations/data/utility.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/bill_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/reading_screens.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utilities_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utility_account_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/utility_form_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _tall = Size(360, 3000);

TestApp _as(MemberRole role) => TestApp(
  portfolios: [
    PortfolioMembership(id: gulberg.id, name: gulberg.name, role: role),
  ],
);

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String label, String option) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is MmSelectField && widget.label == label,
  );
  await tester.ensureVisible(field.last);
  await tester.tap(field.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option, findRichText: true).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          (widget is MmTextField && widget.label == label) ||
          (widget is MmMoneyField && widget.label == label),
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

List<Call> _calls(TestApp app, String name) => [
  for (final call in app.operations.calls)
    if (call.$1 == name) call,
];

void main() {
  group('the utilities screen', () {
    testWidgets('lists unpaid bills, earliest due first, warning about '
        "those in the owner's name", (tester) async {
      await pumpScreen(tester, UtilitiesScreen.new, size: _tall);
      expect(shown('1 overdue bill is on a connection in your name'), findsOne);
      expect(shown('Overdue 2 days'), findsOneWidget);
      expect(shown('Due 12 Nov 2026'), findsOneWidget);
      // The bill that loses the protected tariff says so in the list.
      expect(shown('Over 200 units a month'), findsOneWidget);
      expect(find.text('Bills to pay'), findsOneWidget);
      expect(find.text('Gas, SNGPL (Sui Northern)'), findsOneWidget);
      await tester.tap(find.text('Gas, SNGPL (Sui Northern): November 2026'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.utilityBill(gasBill.id)), findsOneWidget);
    });

    testWidgets('shows archived connections, and leads to a connection', (
      tester,
    ) async {
      await pumpScreen(tester, UtilitiesScreen.new, size: _tall);
      await _tap(tester, 'Archived');
      expect(find.text('Water, WASA'), findsOneWidget);
      await _tap(tester, 'Water, WASA');
      expect(routeShown(Routes.utility(oldWater.id)), findsOneWidget);
    });

    testWidgets('says when there are no bills or connections', (tester) async {
      final app = TestApp();
      app.operations.billList.clear();
      app.operations.accountList.removeRange(0, 2);
      await pumpScreen(tester, UtilitiesScreen.new, app: app, size: _tall);
      expect(find.text('No unpaid bills.'), findsOneWidget);
      expect(find.text('No connections yet'), findsOneWidget);
      app.operations.accountList.clear();
      await _tap(tester, 'Archived');
      expect(find.text('No archived connections.'), findsOneWidget);
      await _tap(tester, 'Add connection');
      expect(routeShown(Routes.newUtility), findsOneWidget);
    });

    testWidgets('reads more connections, and lets viewers only look', (
      tester,
    ) async {
      final app = _as(MemberRole.viewer)..operations.pageLimit = 1;
      await pumpScreen(tester, UtilitiesScreen.new, app: app, size: _tall);
      expect(find.text('Add connection'), findsNothing);
      expect(find.text('Gas, SNGPL (Sui Northern)'), findsNothing);
      await _tap(tester, 'Show more');
      expect(find.text('Gas, SNGPL (Sui Northern)'), findsOneWidget);
    });

    testWidgets('says why the utilities could not be read', (tester) async {
      final app = TestApp()..operations.readFailure = const Forbidden();
      await pumpScreen(tester, UtilitiesScreen.new, app: app, size: _tall);
      expect(find.text('The utilities could not be loaded'), findsNWidgets(2));
    });
  });

  group('a connection', () {
    testWidgets('shows its numbers, bills and readings with what was used', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      expect(shown('This connection is in your name'), findsOneWidget);
      expect(find.text('09269330553008'), findsOneWidget);
      expect(shown('195 units in 31 days'), findsOneWidget);
      // Each reading's pace, which its badge measures.
      expect(shown('about 189 units a month'), findsOneWidget);
      expect(shown('about 181 units a month'), findsOneWidget);
      // October's bill and both readings' paces are near the limit;
      // November's bill is over it.
      expect(shown('Near 200 units a month'), findsNWidgets(3));
      expect(shown('Over 200 units a month'), findsOneWidget);
      expect(find.text('In your name'), findsOneWidget);
      expect(shown("On the tenant's ledger"), findsOneWidget);
      await _tap(tester, 'Reading 10450');
      expect(routeShown(Routes.meterReading(moveInReading.id)), findsOne);
    });

    testWidgets('pages its bills and readings', (tester) async {
      final app = TestApp()..operations.pageLimit = 1;
      await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        app: app,
        size: _tall,
      );
      expect(find.text('October 2026'), findsNothing);
      await tester.ensureVisible(find.text('Show more').first);
      await tester.tap(find.text('Show more').first);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      await _tap(tester, 'Show more');
      expect(find.text('Reading 12010'), findsOneWidget);
    });

    testWidgets('a bill is added for a month, once', (tester) async {
      final app = await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      await _tap(tester, 'Add bill');
      await _type(tester, 'Units used', 'lots');
      await _tap(tester, 'Add bill');
      expect(shown('Enter an amount, like 25,000.'), findsOneWidget);
      expect(shown('Enter a number of units'), findsOneWidget);
      await _type(tester, 'Amount', '8100');
      await _type(tester, 'Units used', '195');
      expect(shown('This month is close to 200 units.'), findsOneWidget);
      await _type(tester, 'Units used', '230');
      expect(shown('This month went over 200 units'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await _select(tester, 'Paid by', 'You');
      app.operations.writeFailures.add(
        const RejectedFailure('duplicate_bill_month'),
      );
      await _tap(tester, 'Add bill');
      expect(shown('already has a bill for that month'), findsOneWidget);
      await _select(tester, 'Bill for', 'October 2026');
      expect(shown('already has a bill for that month'), findsNothing);
      await _tap(tester, 'Add bill');
      final draft = _calls(app, 'createBill').last.$2.last! as BillDraft;
      expect(draft.billingMonth, MonthPeriod(2026, 10));
      expect(draft.amount, const Money.fromRupees(8100));
      expect(draft.unitsConsumed, const Hundredths(23000));
      expect(draft.paidOn, CalendarDate(2026, 11, 7));
      expect(draft.paidBy, BillPayer.landlord);
      expect(
        _calls(app, 'createBill').first.$2.first,
        _calls(app, 'createBill').last.$2.first,
      );
      expect(find.text('Bill added.'), findsOneWidget);
    });

    testWidgets('a reading is added for a tenancy, warning when it is lower '
        'than the last', (tester) async {
      final app = await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      await _tap(tester, 'Add reading');
      expect(shown('The last reading was 12205 on 1'), findsOneWidget);
      await _tap(tester, 'Add reading');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _type(tester, 'Reading', '12000');
      expect(shown('lower than the last reading'), findsOneWidget);
      await _type(tester, 'Reading', '12400.5');
      expect(shown('lower than the last reading'), findsNothing);
      await _select(tester, 'When read', 'Move-out');
      await _select(tester, 'Tenancy', 'Ali Raza\u00A0· Ground floor');
      await _tap(tester, 'Add reading');
      final draft = _calls(app, 'createReading').last.$2.last! as ReadingDraft;
      expect(draft.reading, const Hundredths(1240050));
      expect(draft.context, ReadingContext.moveOut);
      expect(draft.leaseId, aliLease.id);
      expect(find.text('Reading added.'), findsOneWidget);
    });

    testWidgets('a retried bill or reading that its first try stored says '
        'later changes were not saved', (tester) async {
      final app = await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      await _tap(tester, 'Add bill');
      await _select(tester, 'Bill for', 'October 2026');
      await _type(tester, 'Amount', '8100');
      app.operations.loseNextReply = true;
      await _tap(tester, 'Add bill');
      expect(shown('No connection'), findsOneWidget);
      await _type(tester, 'Amount', '8200');
      await _tap(tester, 'Add bill');
      expect(
        app.operations.billList.first.amount,
        const Money.fromRupees(8100),
      );
      expect(shown('This was already saved, as first entered.'), findsOne);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      await _tap(tester, 'Add reading');
      await _type(tester, 'Reading', '12300');
      app.operations.loseNextReply = true;
      await _tap(tester, 'Add reading');
      expect(shown('No connection'), findsOneWidget);
      await _type(tester, 'Reading', '12310');
      await _tap(tester, 'Add reading');
      expect(
        app.operations.readingList.first.reading,
        const Hundredths(1230000),
      );
      expect(shown('This was already saved, as first entered.'), findsOne);
    });

    testWidgets('a back-dated reading is measured against the readings '
        'around its day', (tester) async {
      await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      await _tap(tester, 'Add reading');
      // A reading of 15 October sits between October's (12010) and
      // November's (12205): lower than the latest is no warning.
      tester
          .widget<MmDateField>(
            find.byWidgetPredicate(
              (widget) => widget is MmDateField && widget.label == 'Read on',
            ),
          )
          .onChanged(CalendarDate(2026, 10, 15));
      await tester.pumpAndSettle();
      expect(shown('The last reading was 12010 on 1'), findsOneWidget);
      await _type(tester, 'Reading', '12100');
      expect(shown('lower than the last reading'), findsNothing);
      expect(shown('higher than the later reading'), findsNothing);
      await _type(tester, 'Reading', '12000');
      expect(shown('lower than the last reading'), findsOneWidget);
      await _type(tester, 'Reading', '12300');
      expect(
        shown('higher than the later reading of 12205 on 1 Nov 2026'),
        findsOneWidget,
      );
    });

    testWidgets('the owner archives, restores and deletes it', (tester) async {
      final app = await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      await _tap(tester, 'Archive');
      await _tap(tester, 'Archive');
      expect(find.text('Connection archived.'), findsOneWidget);
      expect(find.text('Add bill'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
      await _tap(tester, 'Put back in use');
      expect(find.text('The connection is back in use.'), findsOneWidget);
      app.operations.writeFailures.add(const Forbidden());
      await _tap(tester, 'Delete');
      await _tap(tester, 'Delete');
      expect(shown('You do not have permission'), findsOneWidget);
      await _tap(tester, 'Delete');
      await _tap(tester, 'Delete');
      expect(routeShown(Routes.utilities), findsOneWidget);
    });

    testWidgets('a manager edits it but does not delete it; an accountant '
        'adds bills only', (tester) async {
      await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        app: _as(MemberRole.manager),
        size: _tall,
      );
      expect(find.text('Delete'), findsNothing);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.editUtility(lescoMeter.id)), findsOneWidget);
      await pumpScreen(
        tester,
        () => UtilityAccountScreen(accountId: lescoMeter.id),
        app: _as(MemberRole.accountant),
        size: _tall,
      );
      expect(find.text('Add bill'), findsOneWidget);
      expect(find.text('Archive'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
    });

    testWidgets('one that cannot be read says so', (tester) async {
      final app = TestApp()..operations.readFailure = const NotFoundFailure();
      await pumpScreen(
        tester,
        () => const UtilityAccountScreen(accountId: 'x'),
        app: app,
      );
      expect(find.text('The connection could not be loaded'), findsOneWidget);
      await pumpScreen(
        tester,
        () => const UtilityFormScreen(accountId: 'x'),
        app: app,
      );
      expect(find.text('Edit connection'), findsOneWidget);
    });
  });

  group('the connection form', () {
    testWidgets('needs a property and a supplier, checks the numbers, and '
        'adds it once', (tester) async {
      final app = await pumpScreen(tester, UtilityFormScreen.new, size: _tall);
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsNWidgets(2));
      await _select(tester, 'Property', 'Gulberg House');
      await _select(tester, 'Unit', 'First floor');
      await _select(tester, 'Supplier', 'K-Electric (Karachi)');
      await _type(tester, 'Reference number', '0400 1234 56789');
      expect(shown('usually carry a 13-digit number'), findsNothing);
      await _type(tester, 'Reference number', '04001234');
      expect(shown('usually carry a 13-digit number'), findsOneWidget);
      await _type(tester, 'Reference number', 'ab');
      await _type(tester, 'Customer ID', 'x y!');
      await _type(tester, 'Meter number', 'm#1');
      await _tap(tester, 'Save');
      expect(shown('Use 4 to 24 letters'), findsOneWidget);
      expect(shown('Use up to 30 letters, digits or dashes.'), findsOneWidget);
      expect(shown('dashes or slashes'), findsOneWidget);
      await _type(tester, 'Reference number', '0400123456789');
      await _type(tester, 'Customer ID', 'c-77');
      await _type(tester, 'Meter number', 'ke/1');
      await _type(tester, 'Name on the bill', 'Ayesha Khan');
      app.operations.writeFailures.add(
        const RejectedFailure('duplicate_utility_reference'),
      );
      await _tap(tester, 'Save');
      expect(shown('already has this reference number'), findsOneWidget);
      await _type(tester, 'Reference number', '0400123456780');
      expect(shown('already has this reference number'), findsNothing);
      await _tap(tester, 'Save');
      final creates = _calls(app, 'createUtilityAccount');
      expect(creates.first.$2.first, creates.last.$2.first);
      final draft = creates.last.$2.last! as UtilityAccountDraft;
      expect(
        draft.toInsert(),
        containsPair('reference_number', '0400123456780'),
      );
      expect(draft.toInsert(), containsPair('customer_id', 'C-77'));
      expect(draft.toInsert(), containsPair('meter_number', 'KE/1'));
      expect(draft.unitId, firstFloor.id);
      expect(draft.provider, UtilityProvider.kElectric);
      expect(find.text('Connection added.'), findsOneWidget);
      expect(
        routeShown(Routes.utility(creates.last.$2.first! as String)),
        findsOneWidget,
      );
    });

    testWidgets('offers the suppliers of the type, a name for another, and '
        'the protected tariff for electricity', (tester) async {
      final app = await pumpScreen(
        tester,
        () => UtilityFormScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      expect(find.text('Protected tariff'), findsOneWidget);
      expect(find.text('Gulberg House'), findsOneWidget);
      await _select(tester, 'Type', 'Gas');
      expect(find.text('Protected tariff'), findsNothing);
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _select(tester, 'Supplier', 'Other');
      await _type(tester, "Supplier's name", 'Mari Gas');
      await _select(tester, 'Who pays the bills', 'Shared');
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await _tap(tester, 'Save');
      final draft =
          _calls(app, 'updateUtilityAccount').last.$2.last!
              as UtilityAccountDraft;
      expect(draft.toWrite(), containsPair('provider_other', 'Mari Gas'));
      expect(draft.toWrite(), containsPair('is_protected_consumer', false));
      expect(draft.toWrite(), containsPair('in_landlord_name', false));
      expect(draft.responsibility, BillResponsibility.shared);
      expect(find.text('Connection saved.'), findsOneWidget);
    });

    testWidgets('cancelling goes back', (tester) async {
      await pumpScreen(tester, UtilityFormScreen.new, size: _tall);
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.utilities), findsOneWidget);
      await pumpScreen(
        tester,
        () => UtilityFormScreen(accountId: lescoMeter.id),
        size: _tall,
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.utility(lescoMeter.id)), findsOneWidget);
    });
  });

  group('a bill', () {
    testWidgets('is marked paid and unpaid', (tester) async {
      final app = await pumpScreen(
        tester,
        () => BillScreen(billId: novemberBill.id),
        size: _tall,
      );
      expect(
        shown('This unpaid bill is on a connection in your name'),
        findsOne,
      );
      // Marking it paid is the one filled action of an unpaid bill.
      final markPaid = tester.widget<MmButton>(
        find.ancestor(
          of: find.text('Mark paid'),
          matching: find.byType(MmButton),
        ),
      );
      expect(markPaid.variant, MmButtonVariant.primary);
      await _tap(tester, 'Mark paid');
      await _select(tester, 'Paid by', 'You');
      await _tap(tester, 'Mark paid');
      // Only whether it is paid is written, not the screen's copy of the
      // rest of the bill.
      expect(_calls(app, 'updateBill'), isEmpty);
      expect(_calls(app, 'setBillPayment').last.$2, [
        novemberBill.id,
        BillPayment(
          paidOn: CalendarDate(2026, 11, 7),
          paidBy: BillPayer.landlord,
        ),
      ]);
      expect(find.text('Bill marked paid.'), findsOneWidget);
      // Marking it unpaid says what it clears first.
      await _tap(tester, 'Mark unpaid');
      expect(
        shown('The paid date, 7 Nov 2026, and who paid it will be cleared.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_calls(app, 'setBillPayment'), hasLength(1));
      await _tap(tester, 'Mark unpaid');
      await _tap(tester, 'Mark unpaid');
      expect(_calls(app, 'setBillPayment').last.$2, [
        novemberBill.id,
        const BillPayment.unpaid(),
      ]);
      expect(find.text('Bill marked unpaid.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 10));
      // A failure stays in the sheet, to try again.
      await pumpScreen(
        tester,
        () => BillScreen(billId: gasBill.id),
        app: app,
        size: _tall,
      );
      app.operations.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Mark paid');
      await _tap(tester, 'Mark paid');
      expect(shown('No connection'), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();
    });

    testWidgets('is charged to the only active tenancy on its connection', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        () => BillScreen(billId: novemberBill.id),
        size: _tall,
      );
      await _tap(tester, 'Charge to tenant');
      expect(shown('due on 5 Nov 2026'), findsOneWidget);
      // Its due date has passed: the due is overdue from the start.
      expect(shown('That date has passed'), findsOneWidget);
      app.operations.writeFailures.add(
        const RejectedFailure('lease_not_on_this_connection'),
      );
      await _tap(tester, 'Charge to tenant');
      expect(shown('not on that utility connection'), findsOneWidget);
      await _tap(tester, 'Charge to tenant');
      expect(_calls(app, 'billToTenant').last.$2, [
        novemberBill.id,
        aliLease.id,
      ]);
      expect(find.text("The bill is on the tenant's ledger."), findsOneWidget);
      expect(find.text('Charge to tenant'), findsNothing);
      await _tap(tester, "On the tenant's ledger");
      expect(routeShown(Routes.ledger(aliLease.id)), findsOneWidget);
    });

    testWidgets('needs a tenancy chosen when there is more than one, and says '
        'when there is none', (tester) async {
      final app = TestApp();
      app.operations.leaseList.add(
        Lease.fromRow({
          ...aliLease.toRow(),
          'id': 'lease-2',
          'tenant': const {'full_name': 'Sara Ali'},
        }),
      );
      await pumpScreen(
        tester,
        () => BillScreen(billId: gasBill.id),
        app: app,
        size: _tall,
      );
      await _tap(tester, 'Charge to tenant');
      // Due on 12 Nov: not yet passed.
      expect(shown('That date has passed'), findsNothing);
      await _tap(tester, 'Charge to tenant');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _select(
        tester,
        'Tenancy',
        'Hamid Ali\u00A0· First floor\u00A0· Ended',
      );
      await _tap(tester, 'Charge to tenant');
      expect(_calls(app, 'billToTenant').last.$2.last, endedLease.id);
      final empty = TestApp()..operations.leaseList.clear();
      await pumpScreen(
        tester,
        () => BillScreen(billId: gasBill.id),
        app: empty,
        size: _tall,
      );
      await _tap(tester, 'Charge to tenant');
      expect(shown('No tenancy was ever started'), findsOneWidget);
    });

    testWidgets('is edited, keeping whether it is paid', (tester) async {
      final app = await pumpScreen(
        tester,
        () => BillScreen(billId: novemberBill.id),
        size: _tall,
      );
      await tester.tap(find.byTooltip('Edit bill'));
      await tester.pumpAndSettle();
      expect(find.text('Already paid'), findsNothing);
      expect(shown("its amount can't change here"), findsNothing);
      await _type(tester, 'Amount', '9900');
      await _tap(tester, 'Save');
      final draft = _calls(app, 'updateBill').last.$2.last! as BillDraft;
      expect(draft.amount, const Money.fromRupees(9900));
      expect(draft.toWrite().containsKey('status'), isFalse);
      expect(find.text('Bill saved.'), findsOneWidget);
      expect(app.operations.billList[1].paid, isFalse);
    });

    testWidgets("charged to the tenant keeps the amount of the tenant's due, "
        'and is deleted', (tester) async {
      final app = await pumpScreen(
        tester,
        () => BillScreen(billId: octoberBill.id),
        size: _tall,
      );
      expect(find.text('Charge to tenant'), findsNothing);
      await tester.tap(find.byTooltip('Edit bill'));
      await tester.pumpAndSettle();
      // The amount is shown, not offered: update_charge refuses to change
      // a utility bill's due, so the two would part.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is MmMoneyField && widget.label == 'Amount',
        ),
        findsNothing,
      );
      expect(shown("its amount can't change here"), findsOneWidget);
      expect(shown('void that due in the ledger'), findsOneWidget);
      await _type(tester, 'Units used', '190');
      await _tap(tester, 'Save');
      final draft = _calls(app, 'updateBill').last.$2.last! as BillDraft;
      expect(draft.amount, octoberBill.amount);
      expect(draft.unitsConsumed, const Hundredths(19000));
      expect(find.text('Bill saved.'), findsOneWidget);
      expect(app.operations.billList[2].paid, isTrue);
      await _tap(tester, 'Delete');
      expect(shown('stays there: void it in the ledger'), findsOneWidget);
      await _tap(tester, 'Delete');
      expect(routeShown(Routes.utility(lescoMeter.id)), findsOneWidget);
      expect(find.text('Bill deleted.'), findsOneWidget);
    });

    testWidgets('whose charge was voided can be charged again', (tester) async {
      final app = TestApp();
      app.operations.billList[2] = UtilityBill.fromRow({
        ...octoberBill.toRow(),
        'charge': {
          'id': 'ch-1',
          'lease_id': aliLease.id,
          'voided_at': '2026-11-01T00:00:00Z',
        },
      });
      await pumpScreen(
        tester,
        () => BillScreen(
          billId: octoberBill.id,
          extras: (_) => const Text('photos'),
        ),
        app: app,
        size: _tall,
      );
      expect(shown('was voided'), findsOneWidget);
      expect(find.text('Charge to tenant'), findsOneWidget);
      expect(find.text('photos'), findsOneWidget);
      // Delete comes last, after the photos.
      expect(
        tester.getTopLeft(find.text('Delete')).dy,
        greaterThan(tester.getTopLeft(find.text('photos')).dy),
      );
      await _tap(tester, 'Electricity, LESCO (Lahore)');
      expect(routeShown(Routes.utility(lescoMeter.id)), findsOneWidget);
    });

    testWidgets('viewers only look; an accountant does not delete', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => BillScreen(billId: novemberBill.id),
        app: TestApp(portfolios: const [gulbergAsViewer]),
        size: _tall,
      );
      expect(find.text('Mark paid'), findsNothing);
      expect(find.byTooltip('Edit bill'), findsNothing);
      await pumpScreen(
        tester,
        () => BillScreen(billId: novemberBill.id),
        app: _as(MemberRole.accountant),
        size: _tall,
      );
      expect(find.text('Mark paid'), findsOneWidget);
      expect(find.byTooltip('Edit bill'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      final failing = TestApp()
        ..operations.readFailure = const NotFoundFailure();
      await pumpScreen(
        tester,
        () => const BillScreen(billId: 'x'),
        app: failing,
      );
      expect(find.text('The bill could not be loaded'), findsOneWidget);
    });
  });

  group('a reading', () {
    testWidgets('shows what was used since the one before, and is edited '
        'and deleted', (tester) async {
      final app = await pumpScreen(
        tester,
        () => ReadingScreen(
          readingId: novemberReading.id,
          extras: (_) => const Text('photos'),
        ),
        size: _tall,
      );
      expect(find.text('189 units a month'), findsOneWidget);
      expect(shown('At this pace a month comes close to 200 units'), findsOne);
      expect(find.text('photos'), findsOneWidget);
      // Delete comes last, after the photos.
      expect(
        tester.getTopLeft(find.text('Delete')).dy,
        greaterThan(tester.getTopLeft(find.text('photos')).dy),
      );
      await tester.tap(find.byTooltip('Edit reading'));
      await tester.pumpAndSettle();
      expect(find.text('Tenancy'), findsNothing);
      await _type(tester, 'Reading', '12000');
      expect(shown('lower than the last reading'), findsOneWidget);
      await _type(tester, 'Reading', '12300');
      await _tap(tester, 'Save');
      final draft = _calls(app, 'updateReading').last.$2.last! as ReadingDraft;
      expect(draft.reading, const Hundredths(1230000));
      expect(find.text('Reading saved.'), findsOneWidget);
      expect(shown('Over 200 units a month'), findsOneWidget);
      await _tap(tester, 'Delete');
      await _tap(tester, 'Delete');
      expect(routeShown(Routes.utility(lescoMeter.id)), findsOneWidget);
    });

    testWidgets('at move-in leads to its tenancy and connection', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => ReadingScreen(readingId: moveInReading.id),
        size: _tall,
      );
      expect(find.text('Reading before'), findsNothing);
      await _tap(tester, 'Tenancy details');
      expect(routeShown(Routes.lease(aliLease.id)), findsOneWidget);
    });

    testWidgets('viewers only look; an accountant does not delete', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => ReadingScreen(readingId: novemberReading.id),
        app: TestApp(portfolios: const [gulbergAsViewer]),
      );
      expect(find.byTooltip('Edit reading'), findsNothing);
      await pumpScreen(
        tester,
        () => ReadingScreen(readingId: novemberReading.id),
        app: _as(MemberRole.accountant),
        size: _tall,
      );
      expect(find.byTooltip('Edit reading'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await _tap(tester, 'Electricity, LESCO (Lahore)');
      expect(routeShown(Routes.utility(lescoMeter.id)), findsOneWidget);
      final failing = TestApp()
        ..operations.readFailure = const NotFoundFailure();
      await pumpScreen(
        tester,
        () => const ReadingScreen(readingId: 'x'),
        app: failing,
      );
      expect(find.text('The reading could not be loaded'), findsOneWidget);
    });
  });
}
