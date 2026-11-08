import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/expense_screens.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _tall = Size(360, 2400);

/// [gulberg] with the user in [role].
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
  await tester.ensureVisible(field);
  await tester.tap(field);
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
  await tester.pump();
}

void main() {
  testWidgets('lists expenses, newest first, each leading to its '
      'details', (tester) async {
    await pumpScreen(tester, ExpensesScreen.new);
    expect(shown('4,500'), findsOneWidget);
    // What it was for is the title; its amount sits at the end edge.
    final tile = find.widgetWithText(ExpenseTile, 'Repairs and maintenance');
    expect(
      find.descendant(of: tile, matching: find.byType(MmAmount)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MmListTile>(
            find.descendant(of: tile, matching: find.byType(MmListTile)),
          )
          .title,
      'Repairs and maintenance',
    );
    expect(shown('The whole portfolio'), findsOneWidget);
    expect(shown('Khan & Co.'), findsOneWidget);
    await tester.tap(shown('18,000'));
    await tester.pumpAndSettle();
    expect(routeShown(Routes.expense(taxExpense.id)), findsOneWidget);
  });

  testWidgets('reads more expenses a page at a time', (tester) async {
    final app = TestApp()..operations.pageLimit = 2;
    await pumpScreen(tester, ExpensesScreen.new, app: app);
    expect(shown('15,000'), findsNothing);
    await _tap(tester, 'Show more');
    expect(shown('15,000'), findsOneWidget);
  });

  testWidgets('says when there are none, or why they could not be read', (
    tester,
  ) async {
    final app = TestApp()..operations.expenseList.clear();
    await pumpScreen(tester, ExpensesScreen.new, app: app);
    expect(find.text('No expenses yet'), findsOneWidget);
    await _tap(tester, 'Add expense');
    expect(routeShown(Routes.newExpense()), findsOneWidget);
    final failing = TestApp()..operations.readFailure = const Forbidden();
    await pumpScreen(tester, ExpensesScreen.new, app: failing);
    expect(find.text('The expenses could not be loaded'), findsOneWidget);
  });

  testWidgets('viewers see expenses but do not add, edit or delete them', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ExpensesScreen.new,
      app: TestApp(portfolios: const [gulbergAsViewer]),
    );
    expect(find.text('Add expense'), findsNothing);
    await pumpScreen(
      tester,
      () => ExpenseDetailScreen(expenseId: taxExpense.id),
      app: TestApp(portfolios: const [gulbergAsViewer]),
    );
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('an expense shows its details, its job and its receipts', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      () => ExpenseDetailScreen(
        expenseId: plumberExpense.id,
        extras: (expense) => Text('receipts of ${expense.id}'),
      ),
      size: _tall,
    );
    expect(find.text('Seepage in the bedroom wall'), findsOneWidget);
    expect(find.text('receipts of ${plumberExpense.id}'), findsOneWidget);
    await _tap(tester, 'Paid for the job');
    expect(
      routeShown(Routes.maintenanceRequest(seepageJob.id)),
      findsOneWidget,
    );
  });

  testWidgets('an accountant edits an expense but does not delete it', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      () => ExpenseDetailScreen(expenseId: taxExpense.id),
      app: _as(MemberRole.accountant),
    );
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(routeShown(Routes.editExpense(taxExpense.id)), findsOneWidget);
  });

  testWidgets('deleting an expense asks first, and goes back to its job', (
    tester,
  ) async {
    final app = await pumpScreen(
      tester,
      () => ExpenseDetailScreen(expenseId: plumberExpense.id),
      size: _tall,
    );
    app.operations.writeFailures.add(const NetworkFailure());
    await _tap(tester, 'Delete');
    expect(find.text('Delete this expense?'), findsOneWidget);
    await _tap(tester, 'Cancel');
    expect(app.operations.calls.where((c) => c.$1 == 'deleteExpense'), isEmpty);
    await _tap(tester, 'Delete');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(shown('No connection'), findsOneWidget);
    await _tap(tester, 'Delete');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(
      routeShown(Routes.maintenanceRequest(seepageJob.id)),
      findsOneWidget,
    );
    expect(find.text('Expense deleted.'), findsOneWidget);
  });

  testWidgets('deleting an expense of no job goes back to the list', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      () => ExpenseDetailScreen(expenseId: taxExpense.id),
      size: _tall,
    );
    await _tap(tester, 'Delete');
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(routeShown(Routes.expenses), findsOneWidget);
  });

  testWidgets('an expense that cannot be read says so', (tester) async {
    final app = TestApp()..operations.readFailure = const NotFoundFailure();
    await pumpScreen(
      tester,
      () => const ExpenseDetailScreen(expenseId: 'gone'),
      app: app,
    );
    expect(find.text('The expense could not be loaded'), findsOneWidget);
    await pumpScreen(
      tester,
      () => const ExpenseFormScreen(expenseId: 'gone'),
      app: app,
    );
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('The expense could not be loaded'), findsOneWidget);
    await pumpScreen(
      tester,
      () => const ExpenseFormScreen(requestId: 'gone'),
      app: app,
    );
    expect(find.text('The repair could not be loaded'), findsOneWidget);
  });

  testWidgets('adding an expense needs a category and an amount, and adds '
      'it once', (tester) async {
    final app = await pumpScreen(tester, ExpenseFormScreen.new, size: _tall);
    await _tap(tester, 'Save');
    expect(shown('Enter this to continue.'), findsOneWidget);
    expect(shown('Enter an amount, like 25,000.'), findsOneWidget);
    await _select(tester, 'Category', 'Society charges');
    await _type(tester, 'Amount', '3500');
    await _select(tester, 'Property', 'Gulberg House');
    await _select(tester, 'Unit', 'First floor');
    await _select(tester, 'Maintenance job', 'Gate light not working');
    await _type(tester, 'Paid to', 'DHA office');
    await _select(tester, 'Paid with', 'Bank transfer');
    expect(shown('Cash you spend comes out'), findsNothing);
    await _type(tester, 'Reference', 'TRX-11');
    await _type(tester, 'Notes', 'November');
    app.operations.writeFailures.add(const NetworkFailure());
    await _tap(tester, 'Save');
    expect(shown('No connection'), findsOneWidget);
    await _tap(tester, 'Save');
    final creates = [
      for (final call in app.operations.calls)
        if (call.$1 == 'createExpense') call,
    ];
    // The retry names the same expense.
    expect(creates, hasLength(2));
    expect(creates.first.$2.first, creates.last.$2.first);
    final draft = creates.last.$2.last! as ExpenseDraft;
    expect(draft.category, ExpenseCategory.societyCharges);
    expect(draft.amount, const Money.fromRupees(3500));
    expect(draft.unitId, firstFloor.id);
    expect(draft.maintenanceRequestId, gateLightJob.id);
    expect(draft.method, PaymentMethod.bankTransfer);
    expect(draft.toWrite()['payee'], 'DHA office');
    expect(find.text('Expense added.'), findsOneWidget);
    expect(
      routeShown(Routes.expense(creates.last.$2.first! as String)),
      findsOneWidget,
    );
  });

  testWidgets('a retry that finds the expense its first try stored says '
      'later changes were not saved', (tester) async {
    final app = await pumpScreen(tester, ExpenseFormScreen.new, size: _tall);
    await _select(tester, 'Category', 'Bank charges');
    await _type(tester, 'Amount', '250');
    await _type(tester, 'Paid to', 'HBL');
    // The first try reaches the server, but its reply is lost.
    app.operations.loseNextReply = true;
    await _tap(tester, 'Save');
    expect(shown('No connection'), findsOneWidget);
    await _type(tester, 'Paid to', 'Meezan Bank');
    await _tap(tester, 'Save');
    final creates = [
      for (final call in app.operations.calls)
        if (call.$1 == 'createExpense') call,
    ];
    expect(creates.first.$2.first, creates.last.$2.first);
    expect(app.operations.expenseList.first.payee, 'HBL');
    expect(shown('This was already saved, as first entered.'), findsOne);
    expect(find.text('Expense added.'), findsNothing);
    expect(
      routeShown(Routes.expense(creates.last.$2.first! as String)),
      findsOneWidget,
    );
  });

  testWidgets('moving an expense to the whole portfolio drops its unit and '
      'job', (tester) async {
    final app = await pumpScreen(
      tester,
      () => ExpenseFormScreen(expenseId: plumberExpense.id),
      size: _tall,
    );
    expect(find.text('Seepage in the bedroom wall'), findsOneWidget);
    await _select(tester, 'Property', 'The whole portfolio');
    expect(find.text('Maintenance job'), findsNothing);
    await _tap(tester, 'Save');
    final draft =
        app.operations.calls.lastWhere((c) => c.$1 == 'updateExpense').$2.last!
            as ExpenseDraft;
    expect(draft.propertyId, isNull);
    expect(draft.unitId, isNull);
    expect(draft.maintenanceRequestId, isNull);
    expect(find.text('Expense saved.'), findsOneWidget);
    expect(routeShown(Routes.expense(plumberExpense.id)), findsOneWidget);
  });

  testWidgets('an expense for a job starts at its property, unit and '
      'category', (tester) async {
    final app = await pumpScreen(
      tester,
      () => ExpenseFormScreen(requestId: seepageJob.id),
      size: _tall,
    );
    expect(shown('For the job: Seepage in the bedroom wall'), findsOneWidget);
    expect(find.text('Repairs and maintenance'), findsOneWidget);
    expect(shown('Cash you spend comes out'), findsOneWidget);
    await _type(tester, 'Amount', '7000');
    await _tap(tester, 'Save');
    final draft =
        app.operations.calls.lastWhere((c) => c.$1 == 'createExpense').$2.last!
            as ExpenseDraft;
    expect(draft.propertyId, gulbergHouse.id);
    expect(draft.unitId, groundFloor.id);
    expect(draft.maintenanceRequestId, seepageJob.id);
  });

  testWidgets('cancelling goes back where the form came from', (tester) async {
    await pumpScreen(tester, ExpenseFormScreen.new, size: _tall);
    await _tap(tester, 'Cancel');
    expect(routeShown(Routes.expenses), findsOneWidget);
    await pumpScreen(
      tester,
      () => ExpenseFormScreen(requestId: seepageJob.id),
      size: _tall,
    );
    await _tap(tester, 'Cancel');
    expect(
      routeShown(Routes.maintenanceRequest(seepageJob.id)),
      findsOneWidget,
    );
    await pumpScreen(
      tester,
      () => ExpenseFormScreen(expenseId: taxExpense.id),
      size: _tall,
    );
    await _tap(tester, 'Cancel');
    expect(routeShown(Routes.expense(taxExpense.id)), findsOneWidget);
  });

  testWidgets("a job closed since stays the expense's choice", (tester) async {
    final app = TestApp();
    final tap = Expense.fromRow({
      ...taxExpense.toRow(),
      'maintenance_request_id': tapJob.id,
      'request': {'title': tapJob.title},
    });
    app.operations.expenseList[1] = tap;
    await pumpScreen(
      tester,
      () => ExpenseFormScreen(expenseId: tap.id),
      app: app,
      size: _tall,
    );
    expect(find.text('Kitchen tap leaking'), findsOneWidget);
  });
}
