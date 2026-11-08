import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/operations/data/expense.dart';
import 'package:maalik_e_makaan/src/features/operations/data/maintenance.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_form_screen.dart';
import 'package:maalik_e_makaan/src/features/operations/presentation/maintenance_screens.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
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
          (widget is MmMoneyField && widget.label == label) ||
          (widget is MmPhoneField && widget.label == label),
    ),
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

MaintenanceDraft _lastSaved(TestApp app) =>
    app.operations.calls
            .lastWhere((c) => c.$1 == 'updateMaintenanceRequest')
            .$2
            .last!
        as MaintenanceDraft;

/// The last move along the workflow: only the status (and resolution) is
/// written, never the screen's copy of the rest of the request.
MaintenanceMove _lastMove(TestApp app) =>
    app.operations.calls
            .lastWhere((c) => c.$1 == 'moveMaintenanceRequest')
            .$2
            .last!
        as MaintenanceMove;

void main() {
  group('the maintenance screen', () {
    testWidgets('lists repairs to do, then the closed ones', (tester) async {
      await pumpScreen(tester, MaintenanceScreen.new);
      expect(find.text('Seepage in the bedroom wall'), findsOneWidget);
      // How urgent a job is shows as a badge beside where it stands, so it
      // is not lost in the grey line under the title.
      final urgent = find.byWidgetPredicate(
        (widget) =>
            widget is MmStatusBadge && widget.label == 'Urgent priority',
      );
      expect(urgent, findsOneWidget);
      expect(
        find.ancestor(
          of: urgent,
          matching: find.widgetWithText(
            MaintenanceTile,
            'Seepage in the bedroom wall',
          ),
        ),
        findsOneWidget,
      );
      // A low priority job has no badge and says its priority in words.
      expect(shown('Low priority'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is MmStatusBadge && widget.label == 'Low priority',
        ),
        findsNothing,
      );
      expect(shown('In progress'), findsOneWidget);
      expect(find.text('Kitchen tap leaking'), findsNothing);
      await _tap(tester, 'Closed');
      expect(find.text('Kitchen tap leaking'), findsOneWidget);
      expect(shown('Resolved'), findsOneWidget);
      await _tap(tester, 'Kitchen tap leaking');
      expect(routeShown(Routes.maintenanceRequest(tapJob.id)), findsOneWidget);
    });

    testWidgets('says when there are none, pages and lets viewers only look', (
      tester,
    ) async {
      final empty = TestApp()..operations.requestList.clear();
      await pumpScreen(tester, MaintenanceScreen.new, app: empty);
      expect(find.text('Nothing to repair'), findsOneWidget);
      await _tap(tester, 'Closed');
      expect(find.text('No closed repairs yet'), findsOneWidget);
      await _tap(tester, 'Add repair');
      expect(routeShown(Routes.newMaintenance()), findsOneWidget);
      final viewer = TestApp(portfolios: const [gulbergAsViewer])
        ..operations.pageLimit = 1;
      await pumpScreen(tester, MaintenanceScreen.new, app: viewer);
      expect(find.text('Add repair'), findsNothing);
      await _tap(tester, 'Show more');
      expect(find.text('Seepage in the bedroom wall'), findsOneWidget);
    });

    testWidgets('says why the repairs could not be read', (tester) async {
      final failing = TestApp()..operations.readFailure = const Forbidden();
      await pumpScreen(tester, MaintenanceScreen.new, app: failing);
      expect(find.text('The repairs could not be loaded'), findsOneWidget);
    });
  });

  group('a repair', () {
    testWidgets('shows its details, what was spent against its estimate, and '
        'its photos', (tester) async {
      final app = await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(
          requestId: seepageJob.id,
          extras: (_) => const Text('photos'),
        ),
        size: _tall,
      );
      expect(shown('Rs 4,500 of the Rs 12,000 estimate'), findsOne);
      expect(find.text('photos'), findsOneWidget);
      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();
      expect(app.opened.single, Uri.parse('tel:+923001112233'));
      app.canOpenLinks = false;
      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();
      expect(
        find.text('The phone could not be opened on this device.'),
        findsOneWidget,
      );
      await _tap(tester, 'Add expense');
      expect(
        routeShown(Routes.newExpense(requestId: seepageJob.id)),
        findsOneWidget,
      );
    });

    testWidgets('leads to its tenancy and its expenses', (tester) async {
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: seepageJob.id),
        size: _tall,
      );
      await _tap(tester, 'Tenancy details');
      expect(routeShown(Routes.lease(aliLease.id)), findsOneWidget);
    });

    testWidgets('without expenses says so', (tester) async {
      final app = TestApp();
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: gateLightJob.id),
        app: app,
        size: _tall,
      );
      expect(find.text('Nothing spent on it yet.'), findsOneWidget);
    });

    testWidgets('without an estimate shows what was spent', (tester) async {
      final app = TestApp();
      app.operations.expenseList.insert(
        0,
        Expense.fromRow({
          ...plumberExpense.toRow(),
          'id': 'e-gate',
          'maintenance_request_id': gateLightJob.id,
          'request': {'title': gateLightJob.title},
        }),
      );
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: gateLightJob.id),
        app: app,
        size: _tall,
      );
      expect(shown('Rs 4,500 so far'), findsOneWidget);
    });

    testWidgets('moves along its workflow', (tester) async {
      final app = TestApp();
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: gateLightJob.id),
        app: app,
        size: _tall,
      );
      await _tap(tester, 'Start work');
      expect(
        _lastMove(app),
        const MaintenanceMove(MaintenanceStatus.inProgress),
      );
      expect(find.text('Now: In progress.'), findsOneWidget);
      await _tap(tester, 'Put on hold');
      expect(_lastMove(app).status, MaintenanceStatus.onHold);
      app.operations.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Resume work');
      expect(shown('No connection'), findsOneWidget);
      await _tap(tester, 'Resume work');
      expect(_lastMove(app).status, MaintenanceStatus.inProgress);
      // Cancelling closes the job, so it asks first.
      await _tap(tester, 'Cancel the repair');
      expect(find.text('Close this repair as cancelled?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_lastMove(app).status, MaintenanceStatus.inProgress);
      await _tap(tester, 'Cancel the repair');
      await _tap(tester, 'Close as cancelled');
      expect(_lastMove(app).status, MaintenanceStatus.cancelled);
      await _tap(tester, 'Reopen');
      expect(_lastMove(app).status, MaintenanceStatus.open);
      // No move rewrote the job's details.
      expect(
        app.operations.calls.where((c) => c.$1 == 'updateMaintenanceRequest'),
        isEmpty,
      );
    });

    testWidgets('is resolved with a date and what was done', (tester) async {
      final app = await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: seepageJob.id),
        size: _tall,
      );
      await _tap(tester, 'Mark resolved');
      await _type(tester, 'What was done', 'Wall sealed and painted');
      app.operations.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Mark resolved');
      expect(shown('No connection'), findsOneWidget);
      await _tap(tester, 'Mark resolved');
      expect(_lastMove(app).toWrite(), {
        'status': 'resolved',
        'resolved_on': '2026-11-07',
        'resolution_note': 'Wall sealed and painted',
      });
      expect(find.text('Repair resolved.'), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('with expenses cannot be deleted; without, it can', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: seepageJob.id),
        size: _tall,
      );
      // Its expense is on screen, so it says why it cannot be deleted
      // rather than offering a delete the server would refuse.
      expect(find.text('Delete'), findsNothing);
      expect(
        shown(
          'Expenses are recorded against this repair, so it cannot be '
          'deleted. Cancel it instead',
        ),
        findsOne,
      );
      // Should the server still refuse (an expense added meanwhile), it
      // says so.
      final meanwhile = TestApp()..operations.expenseList.clear();
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: seepageJob.id),
        app: meanwhile,
        size: _tall,
      );
      meanwhile.operations.expenseList.add(plumberExpense);
      await _tap(tester, 'Delete');
      expect(find.text('Delete Seepage in the bedroom wall?'), findsOneWidget);
      await _tap(tester, 'Delete');
      expect(shown('Expenses are recorded against this repair'), findsOne);
      // A closed job with expenses is not offered cancelling.
      final closed = TestApp();
      closed.operations.expenseList.add(
        Expense.fromRow({
          ...plumberExpense.toRow(),
          'id': 'e-tap',
          'maintenance_request_id': tapJob.id,
          'request': {'title': tapJob.title},
        }),
      );
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: tapJob.id),
        app: closed,
        size: _tall,
      );
      expect(shown('If it was entered by mistake'), findsOneWidget);
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: gateLightJob.id),
        size: _tall,
      );
      await _tap(tester, 'Delete');
      await _tap(tester, 'Delete');
      expect(routeShown(Routes.maintenance), findsOneWidget);
      expect(find.text('Repair deleted.'), findsOneWidget);
    });

    testWidgets('accountants add expenses to it but do not run it', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => MaintenanceDetailScreen(requestId: seepageJob.id),
        app: _as(MemberRole.accountant),
        size: _tall,
      );
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('Mark resolved'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      final failing = TestApp()
        ..operations.readFailure = const NotFoundFailure();
      await pumpScreen(
        tester,
        () => const MaintenanceDetailScreen(requestId: 'x'),
        app: failing,
      );
      expect(find.text('The repair could not be loaded'), findsOneWidget);
      await pumpScreen(
        tester,
        () => const MaintenanceFormScreen(requestId: 'x'),
        app: failing,
      );
      expect(find.text('Edit repair'), findsOneWidget);
    });
  });

  group('the repair form', () {
    testWidgets('needs what and where, and adds it once', (tester) async {
      final app = await pumpScreen(
        tester,
        MaintenanceFormScreen.new,
        size: _tall,
      );
      await _tap(tester, 'Save');
      expect(shown('Enter this to continue.'), findsNWidgets(2));
      await _type(tester, 'What is wrong', 'Geyser not heating');
      await _select(tester, 'Kind of work', 'Appliance');
      await _select(tester, 'Priority', 'High');
      await _select(tester, 'Property', 'Gulberg House');
      await _select(tester, 'Unit', 'Ground floor');
      await _select(tester, 'Tenancy', 'Ali Raza · Ground floor');
      await _type(tester, 'Reported by', 'Sana Raza');
      await _type(tester, 'Done by', 'Gas Wala');
      await _type(tester, 'Their phone', '123');
      await _tap(tester, 'Save');
      expect(shown('Enter a phone number like'), findsOneWidget);
      await _type(tester, 'Their phone', '0301 7654321');
      await _type(tester, 'Estimate', '3000');
      app.operations.writeFailures.add(const NetworkFailure());
      await _tap(tester, 'Save');
      expect(shown('No connection'), findsOneWidget);
      await _tap(tester, 'Save');
      final creates = [
        for (final c in app.operations.calls)
          if (c.$1 == 'createMaintenanceRequest') c,
      ];
      expect(creates.first.$2.first, creates.last.$2.first);
      final draft = creates.last.$2.last! as MaintenanceDraft;
      expect(draft.category, MaintenanceCategory.appliance);
      expect(draft.priority, MaintenancePriority.high);
      expect(draft.unitId, groundFloor.id);
      expect(draft.leaseId, aliLease.id);
      expect(draft.vendorPhone, PhoneNumber.fromE164('+923017654321'));
      expect(draft.estimatedCost, const Money.fromRupees(3000));
      expect(find.text('Repair added.'), findsOneWidget);
      expect(
        routeShown(Routes.maintenanceRequest(creates.last.$2.first! as String)),
        findsOneWidget,
      );
    });

    testWidgets('starts at a property and unit, and resolving needs a '
        'date', (tester) async {
      final app = await pumpScreen(
        tester,
        () => MaintenanceFormScreen(
          propertyId: gulbergHouse.id,
          unitId: firstFloor.id,
        ),
        size: _tall,
      );
      expect(find.text('First floor'), findsOneWidget);
      await _type(tester, 'What is wrong', 'Door jammed');
      await _select(tester, 'Status', 'Resolved');
      expect(shown('Resolved on'), findsOneWidget);
      await _type(tester, 'What was done', 'Hinge oiled');
      await _tap(tester, 'Save');
      final draft =
          app.operations.calls
                  .lastWhere((c) => c.$1 == 'createMaintenanceRequest')
                  .$2
                  .last!
              as MaintenanceDraft;
      expect(draft.unitId, firstFloor.id);
      expect(draft.toWrite()['resolved_on'], '2026-11-07');
      expect(draft.toWrite()['resolution_note'], 'Hinge oiled');
    });

    testWidgets('edits a repair, its property fixed, and cancels back', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        () => MaintenanceFormScreen(requestId: seepageJob.id),
        size: _tall,
      );
      expect(find.text('Gulberg House'), findsOneWidget);
      await _select(tester, 'Unit', 'The whole property');
      await _tap(tester, 'Save');
      final draft = _lastSaved(app);
      expect(draft.unitId, isNull);
      // A new place forgets the tenancy chosen at the old one.
      expect(draft.leaseId, isNull);
      expect(find.text('Repair saved.'), findsOneWidget);
      await pumpScreen(
        tester,
        () => MaintenanceFormScreen(requestId: seepageJob.id),
        size: _tall,
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.maintenanceRequest(seepageJob.id)), findsOne);
      await pumpScreen(tester, MaintenanceFormScreen.new, size: _tall);
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.maintenance), findsOneWidget);
    });
  });
}
