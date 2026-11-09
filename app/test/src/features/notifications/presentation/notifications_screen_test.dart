import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification.dart';
import 'package:maalik_e_makaan/src/features/notifications/presentation/notifications_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text, findRichText: true).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

AppNotification _notification(
  NotificationKind kind,
  Map<String, Object?> params,
) => AppNotification(
  id: 'x-${kind.name}',
  kind: kind,
  params: params,
  createdAt: '2026-11-07T01:00:00+00:00',
);

void main() {
  testWidgets('lists the inbox; opening marks read and leads on', (
    tester,
  ) async {
    final app = await pumpScreen(tester, NotificationsScreen.new);
    expect(find.text('Rent overdue'), findsOneWidget);
    expect(shown('New'), findsNWidgets(2));
    await _tap(tester, 'Rent overdue');
    expect(app.notifications.calls.last.$1, 'markRead');
    expect(shown('New'), findsOneWidget);
    await _tap(tester, 'Open');
    expect(routeShown(Routes.ledger(aliLease.id)), findsOneWidget);
  });

  testWidgets('deletes one and marks all read', (tester) async {
    final app = await pumpScreen(tester, NotificationsScreen.new);
    await _tap(tester, 'Invitation accepted');
    expect(find.text('Open'), findsOneWidget);
    await _tap(tester, 'Delete');
    expect(find.text('Notification deleted.'), findsOneWidget);
    expect(find.text('Invitation accepted'), findsNothing);
    app.notifications.writeFailures.add(const NetworkFailure());
    await tester.tap(find.byIcon(MmIcons.check));
    await tester.pumpAndSettle();
    expect(shown('No connection'), findsOneWidget);
    await tester.tap(find.byIcon(MmIcons.check));
    await tester.pumpAndSettle();
    expect(shown('New'), findsNothing);
    expect(find.byIcon(MmIcons.check), findsNothing);
  });

  testWidgets('a delete that fails says why', (tester) async {
    final app = await pumpScreen(tester, NotificationsScreen.new);
    await _tap(tester, 'CNIC expiring');
    app.notifications.writeFailures.add(const NetworkFailure());
    await _tap(tester, 'Delete');
    expect(shown('No connection'), findsOneWidget);
  });

  testWidgets('pages load on; failures say why', (tester) async {
    final app = TestApp()..notifications.pageLimit = 2;
    await pumpScreen(tester, NotificationsScreen.new, app: app);
    await _tap(tester, 'Show more');
    expect(find.text('Invitation accepted'), findsOneWidget);
  });

  testWidgets('a failure to read says why', (tester) async {
    final app = TestApp()..notifications.readFailure = const ServerFailure('x');
    await pumpScreen(tester, NotificationsScreen.new, app: app);
    expect(find.text('The notifications could not be loaded'), findsOneWidget);
  });

  testWidgets('every kind has words, an icon and its way on', (tester) async {
    final app = TestApp();
    app.notifications.inbox
      ..clear()
      ..addAll([
        _notification(NotificationKind.rentDueSoon, {
          'lease_id': aliLease.id,
          'tenant_name': 'Ali Raza',
          'unit_label': 'Ground floor',
          'amount': '85000.00',
          'due_date': '2026-11-10',
        }),
        _notification(NotificationKind.leaseExpiring, {
          'lease_id': aliLease.id,
          'end_date': '2026-12-14',
        }),
        _notification(NotificationKind.incrementDue, {
          'lease_id': aliLease.id,
          'anniversary': '2027-01-15',
          'current_rent': 85000,
        }),
        _notification(NotificationKind.policeOverdue, {
          'lease_id': aliLease.id,
          'deadline': '2026-01-30',
          'statutory': true,
        }),
        _notification(NotificationKind.policePending, {
          'lease_id': aliLease.id,
          'deadline': '2026-01-16',
          'statutory': false,
        }),
        _notification(NotificationKind.utilityBillDue, {
          'property_name': 'Gulberg House',
          'amount': 'not money',
          'due_date': 12,
        }),
        _notification(NotificationKind.unknown, {}),
        _notification(NotificationKind.invitationAccepted, {
          'email': 'x@example.com',
          'role': 'chief',
        }),
      ]);
    await pumpScreen(
      tester,
      NotificationsScreen.new,
      app: app,
      size: const Size(360, 2400),
    );
    for (final title in [
      'Rent due soon',
      'Agreement ending',
      'Rent increase due',
      'Police registration overdue',
      'Police registration pending',
      'Utility bill due',
      'Notification',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(shown("the app's reminder to register"), findsOneWidget);
    expect(shown('Gulberg House: a bill of  is due on .'), findsOneWidget);
    expect(shown('Update the app to read this notification.'), findsOne);
    final routes = {
      for (final n in app.notifications.inbox) n.kind: notificationRoute(n),
    };
    expect(routes[NotificationKind.leaseExpiring], Routes.lease(aliLease.id));
    // Without its bill's id, a bill's notification leads nowhere.
    expect(routes[NotificationKind.utilityBillDue], isNull);
    expect(routes[NotificationKind.unknown], isNull);
    expect(routes[NotificationKind.invitationAccepted], Routes.team);
    expect(
      notificationRoute(
        _notification(NotificationKind.cnicExpiring, {'tenant_id': 't'}),
      ),
      Routes.tenant('t'),
    );
    expect(
      notificationRoute(_notification(NotificationKind.rentOverdue, {})),
      isNull,
    );
    // A bill's notification leads to the bill.
    expect(
      notificationRoute(
        _notification(NotificationKind.utilityBillDue, {'bill_id': 'b1'}),
      ),
      Routes.utilityBill('b1'),
    );
  });

  testWidgets('without a portfolio there is nothing to show', (tester) async {
    await pumpScreen(
      tester,
      NotificationsScreen.new,
      app: TestApp(portfolios: const []),
    );
    expect(find.text('Notifications'), findsOneWidget);
  });
}
