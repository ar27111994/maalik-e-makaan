import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/harness.dart';

/// Pumps the whole app (its router, redirects and shell) over [app]'s
/// fakes, opening [location].
Future<TestApp> _pumpApp(
  WidgetTester tester, {
  TestApp? app,
  String? location,
  Size size = const Size(390, 844),
}) async {
  final testApp = app ?? TestApp();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (location != null) {
    tester.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: testApp.overrides,
      retry: (_, _) => null,
      child: const MaalikApp(),
    ),
  );
  await tester.pumpAndSettle();
  return testApp;
}

Finder _inNavigation(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is NavigationBar || widget is NavigationRail,
  ),
  matching: find.text(label),
);

void main() {
  testWidgets('first launch greets in both languages and keeps the choice', (
    tester,
  ) async {
    final app = await _pumpApp(
      tester,
      app: TestApp(auth: const SignedOut(), language: null),
    );
    expect(find.text('Welcome to Maalik-e-Makaan'), findsOneWidget);
    expect(find.text('مالکِ مکان میں خوش آمدید'), findsOneWidget);
    await tester.tap(find.text('اردو میں جاری رکھیں'));
    await tester.pumpAndSettle();
    expect(app.settings.values[AppSettings.localeKey], 'ur');
    // On to signing in, in Urdu and right to left.
    final title = find.text('سائن اِن').first;
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
  });

  testWidgets('a signed-out user with a language lands on sign-in', (
    tester,
  ) async {
    await _pumpApp(tester, app: TestApp(auth: const SignedOut()));
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('signing in leads to the dashboard of the remembered portfolio', (
    tester,
  ) async {
    final app = TestApp(
      auth: const SignedOut(),
      settings: {AppSettings.currentPortfolioKey: '$testUserId/${plaza.id}'},
    );
    await _pumpApp(tester, app: app);
    await tester.enterText(find.byType(TextField).first, testEmail);
    await tester.enterText(find.byType(TextField).last, 'Secret1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('What needs attention'), findsOneWidget);
    // The device's language is saved to the profile.
    expect(
      app.profiles.calls,
      contains(isA<Call>().having((c) => c.$1, 'name', 'updateLanguage')),
    );
    await tester.tap(_inNavigation('More'));
    await tester.pumpAndSettle();
    expect(find.text('Saddar Plaza'), findsOneWidget);
  });

  testWidgets(
    'a signed-in user sees the five sections, in Urdu and right to left',
    (tester) async {
      await _pumpApp(tester, app: TestApp(language: 'ur'));
      for (final label in [
        'ڈیش بورڈ',
        'جائیدادیں',
        'کرایہ دار',
        'حساب',
        'مزید',
      ]) {
        expect(_inNavigation(label), findsOneWidget, reason: label);
      }
      expect(
        Directionality.of(tester.element(find.byType(NavigationBar))),
        TextDirection.rtl,
      );
    },
  );

  testWidgets('expenses, utilities and maintenance open under More, with '
      'their documents', (tester) async {
    for (final (location, title) in [
      (Routes.expenses, 'Expenses'),
      (Routes.newExpense(requestId: seepageJob.id), 'New expense'),
      (Routes.expense(taxExpense.id), 'Excise and Taxation, Lahore'),
      (Routes.editExpense(taxExpense.id), 'Edit expense'),
      (Routes.utilities, 'Bills to pay'),
      (Routes.newUtility, 'New connection'),
      (
        Routes.utilityBill(novemberBill.id),
        'Electricity, LESCO (Lahore): November 2026',
      ),
      (Routes.meterReading(novemberReading.id), 'Meter reading'),
      (Routes.utility(lescoMeter.id), 'Electricity, LESCO (Lahore)'),
      (Routes.editUtility(lescoMeter.id), 'Edit connection'),
      (Routes.maintenance, 'Maintenance'),
      (
        Routes.newMaintenance(
          propertyId: gulbergHouse.id,
          unitId: groundFloor.id,
        ),
        'New repair',
      ),
      (Routes.maintenanceRequest(seepageJob.id), 'Seepage in the bedroom wall'),
      (Routes.editMaintenance(seepageJob.id), 'Edit repair'),
    ]) {
      // A new app for each address: the router reads it when it starts.
      await tester.pumpWidget(const SizedBox.shrink());
      final app = await _pumpApp(
        tester,
        location: location,
        size: const Size(390, 4000),
      );
      expect(find.text(title), findsWidgets, reason: location);
      final documents = [
        for (final call in app.documents.calls)
          if (call.$1 == 'documents') call,
      ];
      final hasDocuments =
          location.contains('/expenses/0') ||
          location.contains('/bills/') ||
          location.contains('/readings/') ||
          location.contains('/maintenance/0');
      expect(
        documents.isNotEmpty,
        hasDocuments && !location.endsWith('/edit'),
        reason: location,
      );
    }
  });

  testWidgets('search, the reports, the tax year and a payment score open '
      'from the dashboard', (tester) async {
    for (final (location, title) in [
      (
        Routes.search,
        'Find a property, unit or tenant by name, locality, '
            'phone or CNIC.',
      ),
      (Routes.reports, 'Payment scores'),
      (Routes.taxYear, 'Not tax advice'),
      (Routes.tenant(aliRaza.id), 'Payment score'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpApp(tester, location: location, size: const Size(390, 4000));
      expect(find.text(title), findsWidgets, reason: location);
    }
  });

  testWidgets('sections switch from the navigation bar', (tester) async {
    await _pumpApp(tester);
    for (final (label, title) in [
      ('Properties', 'Gulberg House'),
      ('Tenants', 'Ali Raza'),
      ('Money', 'Who owes what'),
      ('Dashboard', 'What needs attention'),
    ]) {
      await tester.tap(_inNavigation(label));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: label);
    }
    // Tapping the open section again returns to its first screen.
    await tester.tap(_inNavigation('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Your details'), findsOneWidget);
    await tester.tap(_inNavigation('More'));
    await tester.pumpAndSettle();
    expect(find.text('Switch portfolio'), findsOneWidget);
  });

  testWidgets('the unread badge on More keeps up with the inbox', (
    tester,
  ) async {
    final app = await _pumpApp(tester);
    int reads() =>
        app.notifications.calls.where((c) => c.$1 == 'unreadCount').length;
    final first = reads();
    expect(first, greaterThan(0));
    // While it shows, it is read again from time to time.
    await tester.pump(unreadRefreshInterval);
    await tester.pumpAndSettle();
    expect(reads(), first + 1);
    // A failed read is tried again soon, not kept as unknown.
    app.notifications.readFailure = const NetworkFailure();
    await tester.pump(unreadRefreshInterval);
    await tester.pumpAndSettle();
    app.notifications.readFailure = null;
    final failed = reads();
    await tester.pump(unreadRetryDelay);
    await tester.pumpAndSettle();
    expect(reads(), failed + 1);
    // Coming back to the app reads it again.
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final away = reads();
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads(), away + 1);
    // The inbox read from the server brings the badge along.
    await tester.tap(_inNavigation('More'));
    await tester.pumpAndSettle();
    final before = reads();
    await tester.ensureVisible(find.text('Notifications').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications').last);
    await tester.pumpAndSettle();
    expect(reads(), greaterThan(before));
  });

  testWidgets('wide windows use an extended navigation rail', (tester) async {
    await _pumpApp(tester, size: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });

  testWidgets('without a portfolio the user creates their first', (
    tester,
  ) async {
    final app = await _pumpApp(tester, app: TestApp(portfolios: const []));
    expect(find.text('Create your portfolio'), findsOneWidget);
    // Settings stay open without a portfolio.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Your details'), findsOneWidget);
    await tester.tap(_inNavigation('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Create your portfolio'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Khan family');
    await tester.tap(find.widgetWithText(FilledButton, 'Create portfolio'));
    await tester.pumpAndSettle();
    expect(app.portfolios.memberships.single.name, 'Khan family');
    expect(find.text('What needs attention'), findsOneWidget);
    expect(find.text('Khan family is ready.'), findsOneWidget);
  });

  testWidgets('the shell says when portfolios cannot load, and retries', (
    tester,
  ) async {
    final app = TestApp()
      ..portfolios.listFailure = const ServerFailure('XX000');
    await _pumpApp(tester, app: app);
    expect(find.text('Your portfolios could not be loaded'), findsOneWidget);
    app.portfolios.listFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('What needs attention'), findsOneWidget);
  });

  testWidgets('the shell shows progress while portfolios load', (tester) async {
    final app = TestApp()..portfolios.gate.close();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: app.overrides,
        retry: (_, _) => null,
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaalikApp(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MmSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Loading your portfolios'), findsOneWidget);
    app.portfolios.gate.open();
    await tester.pumpAndSettle();
    expect(find.text('What needs attention'), findsOneWidget);
  });

  testWidgets('a session that ends elsewhere returns to sign-in, then back', (
    tester,
  ) async {
    final app = await _pumpApp(tester);
    await tester.tap(_inNavigation('Money'));
    await tester.pumpAndSettle();
    app.auth.emit(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, testEmail);
    await tester.enterText(find.byType(TextField).last, 'Secret1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Who owes what'), findsOneWidget);
  });

  testWidgets('signing out from Settings forgets where the user was', (
    tester,
  ) async {
    final app = await _pumpApp(tester, location: '/more/settings');
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(app.auth.calls.last.$1, 'signOut');
    expect(app.auth.calls.last.$2, [SignOutCause.userRequest]);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, testEmail);
    await tester.enterText(find.byType(TextField).last, 'Secret1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('What needs attention'), findsOneWidget);
  });

  testWidgets('an e-mail link signs in and opens the app', (tester) async {
    final app = await _pumpApp(
      tester,
      app: TestApp(auth: const SignedOut()),
      location: '/auth/callback?code=abc123',
    );
    expect(app.auth.calls.first.$1, 'completeEmailLink');
    expect(
      (app.auth.calls.first.$2.single! as Uri).queryParameters['code'],
      'abc123',
    );
    expect(find.text('What needs attention'), findsOneWidget);
  });

  testWidgets('a reset link leads only to choosing a new password', (
    tester,
  ) async {
    final app = await _pumpApp(
      tester,
      app: TestApp(auth: const RecoveringPassword(userId: testUserId)),
    );
    expect(find.text('Choose a new password'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'NewSecret12');
    await tester.enterText(find.byType(TextField).last, 'NewSecret12');
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pumpAndSettle();
    expect(app.auth.calls.last.$1, 'updatePassword');
    expect(app.auth.calls.last.$2, ['NewSecret12']);
    expect(find.text('What needs attention'), findsOneWidget);
    expect(find.text('Your new password is saved.'), findsOneWidget);
  });

  testWidgets('the sign-in screen leads to the other auth screens', (
    tester,
  ) async {
    await _pumpApp(tester, app: TestApp(auth: const SignedOut()));
    await tester.enterText(find.byType(TextField).first, testEmail);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    // The address typed on sign-in comes along.
    expect(find.text(testEmail), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('Settings lead to account deletion', (tester) async {
    await _pumpApp(tester, location: '/more/settings');
    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('This cannot be undone'), findsOneWidget);
  });

  testWidgets('an invitation link keeps its token through signing in', (
    tester,
  ) async {
    final app = TestApp(auth: const SignedOut(), portfolios: const [])
      ..team.acceptOutcome = InvitationAccepted(
        portfolioId: plaza.id,
        role: MemberRole.manager,
      );
    await _pumpApp(tester, app: app, location: '/invite#token=abc.def');
    // The token is kept on the device, never in the address.
    expect(app.settings.values[AppSettings.pendingInvitationKey], 'abc.def');
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/sign-in?from=%2Finvite',
    );
    // Signing in answers the invitation before asking for a portfolio.
    app.portfolios.memberships.add(plaza);
    await tester.enterText(find.byType(TextField).first, testEmail);
    await tester.enterText(find.byType(TextField).last, 'Secret123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(app.team.calls.single.$2, ['abc.def']);
    expect(find.text('Welcome to Saddar Plaza'), findsOneWidget);
    expect(
      app.settings.values,
      isNot(contains(AppSettings.pendingInvitationKey)),
    );
    await tester.tap(find.text('Open the portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('What needs attention'), findsOneWidget);
  });

  testWidgets('a signed-in user opening an invitation answers it', (
    tester,
  ) async {
    final app = await _pumpApp(tester, location: '/invite#token=abc.def');
    expect(app.team.calls.single.$2, ['abc.def']);
    expect(find.text('Welcome to Gulberg Houses'), findsOneWidget);
  });

  testWidgets('More leads to the team and the portfolio details', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/more');
    await tester.ensureVisible(find.text('Team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Khan (you)'), findsOneWidget);
    await tester.tap(find.text('Invite someone'));
    await tester.pumpAndSettle();
    expect(find.text('Send invitation'), findsOneWidget);
  });

  testWidgets('the portfolio details open from their link', (tester) async {
    await _pumpApp(tester, location: '/more/portfolio');
    expect(find.text('Payment details'), findsOneWidget);
  });

  testWidgets('a property leads to its unit and to starting a tenancy', (
    tester,
  ) async {
    await _pumpApp(tester, location: '/properties');
    await tester.tap(find.text('Gulberg House'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Annexe room'), 200);
    await tester.tap(find.text('Annexe room'));
    await tester.pumpAndSettle();
    expect(find.text('No tenancies yet.'), findsOneWidget);
    await tester.ensureVisible(find.text('Start tenancy'));
    await tester.tap(find.text('Start tenancy'));
    await tester.pumpAndSettle();
    expect(find.text('New tenancy'), findsOneWidget);
  });

  testWidgets('a tenant lists their tenancies, which open', (tester) async {
    await _pumpApp(tester, location: '/tenants/${aliRaza.id}');
    await tester.scrollUntilVisible(
      find.text('Ground floor, Gulberg House'),
      200,
    );
    await tester.tap(find.text('Ground floor, Gulberg House'));
    await tester.pumpAndSettle();
    expect(find.text('Police registration'), findsOneWidget);
  });

  for (final (location, document) in [
    ('/tenants/${aliRaza.id}', 'CNIC front'),
    ('/leases/${aliLease.id}', 'Signed agreement, January 2026'),
    (
      '/properties/${gulbergHouse.id}',
      'No documents yet. Add the property papers and photos.',
    ),
    (
      '/properties/${gulbergHouse.id}/units/${groundFloor.id}',
      'No documents yet. Add photos of the unit and its meters.',
    ),
  ]) {
    testWidgets('$location shows its documents', (tester) async {
      await _pumpApp(tester, location: location);
      await tester.scrollUntilVisible(find.text(document), 300);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Add document'), findsOneWidget);
    });
  }

  group('a camera photo Android kept after closing the app', () {
    const notice =
        'The app closed while the camera was open, but your photo was kept. '
        'Check it, then upload it.';

    /// An app whose camera kept a photo for Ali Raza's documents in
    /// [portfolioId], the camera having opened [ago].
    TestApp keptFor({String? portfolioId, Duration ago = Duration.zero}) {
      final target = CameraTarget(
        userId: testUserId,
        portfolioId: portfolioId ?? gulberg.id,
        owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
        location: Routes.tenant(aliRaza.id),
        // The test's clock, which the app reads.
        openedAt: clock.now().toUtc().subtract(ago),
      );
      final app = TestApp(
        settings: {AppSettings.cameraTargetKey: target.toJson()},
      );
      app.picker.lostPhoto = app.picker.photo;
      return app;
    }

    testWidgets('comes back to its record, ready to upload', (tester) async {
      final app = await _pumpApp(tester, app: keptFor());
      // On Ali Raza's screen, in the add-document sheet.
      expect(find.text('Ali Raza'), findsWidgets);
      expect(find.text(notice), findsOneWidget);
      expect(
        find.text('Made smaller from 2.4\u00a0MB to 286\u00a0KB.'),
        findsOneWidget,
      );
      expect(app.settings.values, isNot(contains(AppSettings.cameraTargetKey)));
      // Nothing goes up before the landlord says so.
      expect(
        app.documents.calls.map((c) => c.$1),
        isNot(contains('uploadFile')),
      );
      await tester.ensureVisible(find.text('Upload'));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('CNIC, front added.'), findsOneWidget);
      expect(
        app.documents.calls.lastWhere((c) => c.$1 == 'recordDocument').$2.first,
        startsWith('${gulberg.id}/tenant/${aliRaza.id}/'),
      );
      // Back at the documents, the photo is not offered again.
      expect(find.text(notice), findsNothing);
    });

    testWidgets('comes back in the portfolio it was taken in', (tester) async {
      final app = await _pumpApp(tester, app: keptFor(portfolioId: plaza.id));
      expect(find.text(notice), findsOneWidget);
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/${plaza.id}',
      );
      await tester.ensureVisible(find.text('Upload'));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(
        app.documents.calls.lastWhere((c) => c.$1 == 'recordDocument').$2.first,
        startsWith('${plaza.id}/tenant/${aliRaza.id}/'),
      );
    });

    testWidgets('a device that cannot write still gets it back', (
      tester,
    ) async {
      final app = keptFor(portfolioId: plaza.id)
        ..settings.writeFailure = Exception('read-only');
      await _pumpApp(tester, app: app);
      // In the other portfolio for this run, though the device could not
      // note it, nor forget the camera's target.
      expect(find.text(notice), findsOneWidget);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.currentPortfolioKey)),
      );
      expect(app.settings.values, contains(AppSettings.cameraTargetKey));
      app.settings.writeFailure = null;
      await tester.ensureVisible(find.text('Upload'));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(
        app.documents.calls.lastWhere((c) => c.$1 == 'recordDocument').$2.first,
        startsWith('${plaza.id}/tenant/${aliRaza.id}/'),
      );
    });

    testWidgets('a day later it is let go', (tester) async {
      final app = await _pumpApp(
        tester,
        app: keptFor(ago: const Duration(days: 1, minutes: 1)),
      );
      expect(find.text('What needs attention'), findsOneWidget);
      expect(find.text(notice), findsNothing);
      expect(app.picker.calls, ['recoverLostPhoto']);
      expect(app.settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    testWidgets("the camera's failure says so, as any failure does", (
      tester,
    ) async {
      final app = keptFor()
        ..picker.lostPhoto = null
        ..picker.lostFailure = const RejectedFailure('picker_access_denied');
      await _pumpApp(tester, app: app);
      expect(find.text('What needs attention'), findsOneWidget);
      expect(
        find.text(
          'Maalik-e-Makaan may not use the camera or your files. Allow it '
          "in your phone's settings.",
        ),
        findsOneWidget,
      );
      expect(app.settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    testWidgets('is looked for once, after signing in', (tester) async {
      final app = keptFor();
      app.auth.emit(const SignedOut());
      await _pumpApp(tester, app: app);
      expect(app.picker.calls, isEmpty);
      await tester.enterText(find.byType(TextField).first, testEmail);
      await tester.enterText(find.byType(TextField).last, 'Secret1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);
      // Coming back to the foreground does not look again.
      const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pumpAndSettle();
      expect(app.picker.calls, ['recoverLostPhoto']);
    });

    testWidgets('iOS keeps no photo to look for', (tester) async {
      final app = keptFor();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _pumpApp(tester, app: app);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(find.text('What needs attention'), findsOneWidget);
      expect(app.picker.calls, isEmpty);
      expect(app.settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    const offer =
        'The app closed while the camera was open, but your photo was kept.';

    /// The path the app shows.
    String location(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path;

    testWidgets('a record that no longer takes documents moves nothing', (
      tester,
    ) async {
      // Archived since, in the other portfolio.
      final app = keptFor(portfolioId: plaza.id);
      app.documents.closedOwners.add((
        entity: DocumentEntity.tenant,
        id: aliRaza.id,
      ));
      await _pumpApp(tester, app: app);
      expect(app.picker.calls, ['recoverLostPhoto']);
      expect(
        app.documents.calls.map((c) => c.$1),
        contains('ownerTakesDocuments'),
      );
      expect(find.text('What needs attention'), findsOneWidget);
      expect(location(tester), Routes.home);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.currentPortfolioKey)),
      );
      expect(find.text(notice), findsNothing);
      expect(find.text(offer), findsNothing);
      expect(app.settings.values, isNot(contains(AppSettings.cameraTargetKey)));
    });

    testWidgets('a landlord who moved on meanwhile is offered the photo, '
        'not taken to it', (tester) async {
      final app = keptFor(portfolioId: plaza.id);
      // The record's check is slow to answer.
      app.documents.gate.close();
      await _pumpApp(tester, app: app);
      await tester.tap(_inNavigation('Tenants'));
      await tester.pumpAndSettle();
      app.documents.gate.open();
      await tester.pumpAndSettle();
      // Still where they went, in the portfolio they were in.
      expect(location(tester), Routes.tenants);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.currentPortfolioKey)),
      );
      expect(find.text(notice), findsNothing);
      expect(find.text(offer), findsOneWidget);
      // Asked, the app takes them to it.
      await tester.tap(find.text('Show photo'));
      await tester.pumpAndSettle();
      expect(location(tester), Routes.tenant(aliRaza.id));
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/${plaza.id}',
      );
      expect(find.text(notice), findsOneWidget);
      await tester.ensureVisible(find.text('Upload'));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(
        app.documents.calls.lastWhere((c) => c.$1 == 'recordDocument').$2.first,
        startsWith('${plaza.id}/tenant/${aliRaza.id}/'),
      );
    });

    testWidgets('a record check with no answer keeps the photo', (
      tester,
    ) async {
      final app = keptFor();
      app.documents.gate.close();
      await _pumpApp(tester, app: app);
      expect(location(tester), Routes.home);
      await tester.pump(lostPhotoCheckLimit);
      await tester.pump();
      // On to the record without the answer, which comes later.
      expect(location(tester), Routes.tenant(aliRaza.id));
      app.documents.gate.open();
      await tester.pumpAndSettle();
      expect(find.text(notice), findsOneWidget);
    });
  });

  testWidgets('/leases on its own shows the tenants', (tester) async {
    await _pumpApp(tester, location: '/leases');
    expect(find.text('Add tenant'), findsOneWidget);
  });

  for (final (location, title) in [
    ('/properties/new', 'New property'),
    ('/properties/${gulbergHouse.id}/edit', 'Edit property'),
    ('/properties/${gulbergHouse.id}/units/new', 'New unit'),
    (
      '/properties/${gulbergHouse.id}/units/${groundFloor.id}/edit',
      'Edit unit',
    ),
    ('/tenants/new', 'New tenant'),
    ('/tenants/${aliRaza.id}/edit', 'Edit tenant'),
    ('/leases/new?unit=${annexe.id}', 'New tenancy'),
    ('/leases/${aliLease.id}/edit', 'Edit tenancy terms'),
    ('/more/team/invite', 'Invite someone'),
    ('/money/cash', 'Cash in hand'),
    ('/money/leases/${aliLease.id}', 'Ali Raza'),
    ('/money/leases/${aliLease.id}/pay', 'Record payment'),
    ('/money/leases/${aliLease.id}/receipts/pay-oct', 'Receipt'),
    ('/more/notifications', 'Notifications'),
    ('/leases/${aliLease.id}', 'Open the ledger'),
  ]) {
    testWidgets('$location opens', (tester) async {
      await _pumpApp(tester, location: location);
      expect(find.text(title), findsWidgets);
    });
  }
}
