import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_banner.dart';
import 'package:maalik_e_makaan/src/features/account/application/account_deletion.dart';
import 'package:maalik_e_makaan/src/features/documents/application/lost_photo.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/leases/presentation/lease_detail_screen.dart';
import 'package:maalik_e_makaan/src/features/notifications/application/notifications.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/team_screen.dart';
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

/// One frame at 60 Hz.
const _frame = Duration(milliseconds: 16);

/// How opaque the one widget [finder] finds is drawn: the product of the
/// fades above it (a snack bar fades as it comes and goes).
double _opacity(Finder finder) {
  var opacity = 1.0;
  finder.evaluate().single.visitAncestorElements((ancestor) {
    switch (ancestor.widget) {
      case FadeTransition(opacity: Animation<double>(:final value)):
        opacity *= value;
      case Opacity(opacity: final value):
        opacity *= value;
    }
    return true;
  });
  return opacity;
}

Finder _inNavigation(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is NavigationBar || widget is NavigationRail,
  ),
  matching: find.text(label),
);

/// Taps the section [label] in a phone's navigation bar, at the middle of
/// the bar: on a screen with a bottom bar of its own a label is laid out
/// partly below the window, so a tap at its centre would miss.
Future<void> _goToSection(WidgetTester tester, String label) {
  final bar = tester.getRect(find.byType(NavigationBar));
  return tester.tapAt(
    Offset(tester.getCenter(_inNavigation(label)).dx, bar.center.dy),
  );
}

void main() {
  testWidgets('first launch greets in both languages and keeps the choice', (
    tester,
  ) async {
    final app = await _pumpApp(
      tester,
      app: TestApp(auth: const SignedOut(), language: null),
    );
    expect(find.text('Welcome to Maalik-e-Makaan'), findsOneWidget);
    expect(find.text('مالکِ مکان ایپ میں خوش آمدید'), findsOneWidget);
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

  testWidgets("the shell loads the next account's portfolios, not failing, "
      "while its session replaces the user's", (tester) async {
    // The list is read by a provider keyed by the user: the next account's
    // is a new one, which loads as any first read does.
    final app = await _pumpApp(tester);
    final frames = await framesWhileReplaced(
      tester,
      app,
      held: [app.portfolios.gate],
      failure: find.text('Your portfolios could not be loaded'),
      loading: find.bySemanticsLabel('Loading your portfolios'),
    );
    expect(frames, (failure: 0, loading: 10));
    expect(find.text('What needs attention'), findsOneWidget);
  });

  // Sheets, dialogs and menus close when the signed-in account changes
  // (the owner's decision): another tab signs in as someone else, or the
  // session ends. A sheet or dialog shows a copy of the record it was opened
  // on, and its buttons would act for whoever is signed in. The app shell
  // removes them at once, with no closing animation, so no frame after the
  // change shows the earlier account's record in them, and snack bars go
  // at once too; the screens below are pages, which the router keeps, and
  // they show loading until that account's own answers.
  group('when the signed-in account changes', () {
    // Counts, over [frames] frames of 16 ms after another account's session
    // replaced the user's (the first at once), those on which any of
    // [earlier] is found and those on which [loading] is. What [held]
    // answers waits until then.
    Future<({int earlier, int loading})> replaced(
      WidgetTester tester,
      TestApp app, {
      required List<Finder> earlier,
      required Finder loading,
      List<Gate> held = const [],
      int frames = 10,
    }) async {
      for (final gate in held) {
        gate.close();
      }
      await app.cache.clear();
      app.auth.emit(otherAccount);
      var shown = 0;
      var waiting = 0;
      for (var frame = 0; frame < frames; frame++) {
        await tester.pump(frame == 0 ? Duration.zero : _frame);
        if (earlier.any((finder) => finder.evaluate().isNotEmpty)) shown++;
        if (loading.evaluate().isNotEmpty) waiting++;
      }
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaalikApp)),
      );
      expect(container.read(currentUserIdProvider), otherAccount.userId);
      for (final gate in held) {
        gate.open();
      }
      await tester.pumpAndSettle();
      return (earlier: shown, loading: waiting);
    }

    Future<void> openOccupant(WidgetTester tester) async {
      final occupant = find.text('Sana Raza').last;
      await tester.ensureVisible(occupant);
      await tester.tap(occupant);
      await tester.pumpAndSettle();
      expect(find.byType(OccupantSheet), findsOneWidget);
    }

    // The occupant's sheet, name and CNIC, wherever they show.
    final occupantShown = [
      find.byType(OccupantSheet),
      find.text('Sana Raza'),
      find.text('35202-7654321-2'),
    ];

    testWidgets("an occupant's sheet closes, with nothing of the occupant on "
        'any frame after the change, as the tenancy below loads', (
      tester,
    ) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      await openOccupant(tester);
      expect(
        find.descendant(
          of: find.byType(OccupantSheet),
          matching: find.text('35202-7654321-2'),
        ),
        findsOneWidget,
      );
      final frames = await replaced(
        tester,
        app,
        earlier: occupantShown,
        loading: find.bySemanticsLabel('Loading the tenancy'),
        held: [app.leases.gate],
      );
      expect(frames, (earlier: 0, loading: 10));
      // The page stays: the router keeps it, and it shows the next
      // account's own read.
      expect(find.byType(LeaseDetailScreen), findsOneWidget);
      expect(find.byType(OccupantSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a member's sheet closes, with nothing of the member on any "
        'frame after the change', (tester) async {
      final app = await _pumpApp(
        tester,
        location: Routes.team,
        size: const Size(390, 2400),
      );
      await tester.tap(find.text('Bilal Ahmed').last);
      await tester.pumpAndSettle();
      expect(find.byType(MemberSheet), findsOneWidget);
      final frames = await replaced(
        tester,
        app,
        earlier: [
          find.byType(MemberSheet),
          find.textContaining('bilal.ahmed@', findRichText: true),
        ],
        loading: find.bySemanticsLabel('Loading the team'),
        held: [app.team.gate],
      );
      expect(frames, (earlier: 0, loading: 10));
      expect(find.byType(MemberSheet), findsNothing);
      // Only the team was read again, for the next account.
      expect(
        app.team.calls.map((c) => c.$1),
        everyElement(isIn(['members', 'pendingInvitations'])),
      );
    });

    testWidgets("a confirm dialog opened on a tenant's screen closes, and "
        'nothing is deleted', (tester) async {
      final app = await _pumpApp(
        tester,
        location: Routes.tenant(aliRaza.id),
        size: const Size(390, 2400),
      );
      final delete = find.text('Delete').last;
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete Ali Raza?'), findsOneWidget);
      final frames = await replaced(
        tester,
        app,
        earlier: [find.byType(Dialog), find.text('Delete Ali Raza?')],
        loading: find.bySemanticsLabel('Loading the tenant'),
        held: [app.tenants.gate],
      );
      expect(frames, (earlier: 0, loading: 10));
      expect(find.byType(Dialog), findsNothing);
      expect(app.tenants.calls.where((c) => c.$1 == 'deleteTenant'), isEmpty);
    });

    testWidgets("removing an occupant: the dialog on the occupant's sheet "
        'closes with the sheet, and nothing is removed', (tester) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      await openOccupant(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(OccupantSheet),
          matching: find.widgetWithText(MmButton, 'Remove'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove Sana Raza?'), findsOneWidget);
      final frames = await replaced(
        tester,
        app,
        earlier: [find.byType(Dialog), ...occupantShown],
        loading: find.bySemanticsLabel('Loading the tenancy'),
        held: [app.leases.gate],
      );
      expect(frames, (earlier: 0, loading: 10));
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(OccupantSheet), findsNothing);
      expect(app.leases.calls.where((c) => c.$1 == 'deleteOccupant'), isEmpty);
    });

    testWidgets("a new tenant's warning about another tenant closes, so its "
        '"Save anyway" cannot save for the earlier account', (tester) async {
      final app = await _pumpApp(
        tester,
        location: Routes.newTenant,
        size: const Size(390, 4000),
      );
      Finder input(String label) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              (widget is MmTextField && widget.label == label) ||
              (widget is MmPhoneField && widget.label == label),
        ),
        matching: find.byType(TextField),
      );
      await tester.enterText(input('Full name').first, 'Ali R.');
      await tester.enterText(input('Phone').first, '03001112233');
      await tester.pump();
      final save = find.widgetWithText(MmButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Is this the same tenant?'), findsOneWidget);
      final frames = await replaced(
        tester,
        app,
        earlier: [
          find.byType(Dialog),
          find.textContaining('Ali Raza already has', findRichText: true),
        ],
        // The form is the next account's to fill or leave: what is typed
        // belongs to whoever is at the device.
        loading: find.text('Ali R.'),
      );
      expect(frames, (earlier: 0, loading: 10));
      expect(find.text('Save anyway'), findsNothing);
      expect(app.tenants.calls.where((c) => c.$1 == 'createTenant'), isEmpty);
    });

    testWidgets('a sheet left open in another section closes too', (
      tester,
    ) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      await openOccupant(tester);
      // A section's sheet covers that section only: the navigation bar
      // still switches sections, and the section keeps its sheet.
      await tester.tap(_inNavigation('Money'));
      await tester.pumpAndSettle();
      expect(find.text('Who owes what'), findsOneWidget);
      await app.cache.clear();
      app.auth.emit(otherAccount);
      await tester.pumpAndSettle();
      await tester.tap(_inNavigation('Tenants'));
      await tester.pumpAndSettle();
      expect(find.byType(LeaseDetailScreen), findsOneWidget);
      expect(find.byType(OccupantSheet), findsNothing);
      expect(find.text('35202-7654321-2'), findsNothing);
    });

    // A dialog, and a sheet opened from it (a date picker or a list to
    // choose from, say), are two routes on the root navigator: both go on
    // the first frame, and each answers null.
    testWidgets('a dialog and a sheet opened from it, both on the root '
        'navigator, close together, each answering null', (tester) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      final page = tester.element(find.byType(LeaseDetailScreen));
      late BuildContext dialog;
      final dialogAnswer = showDialog<bool>(
        context: page,
        builder: (context) {
          dialog = context;
          return const AlertDialog(content: Text('Remove Sana Raza?'));
        },
      );
      await tester.pumpAndSettle();
      final sheetAnswer = showMmSheet<bool>(
        dialog,
        title: 'Sana Raza',
        builder: (_) => const Text('35202-7654321-2'),
      );
      await tester.pumpAndSettle();
      final root = Navigator.of(page, rootNavigator: true);
      expect(Navigator.of(dialog), same(root));
      expect(
        Navigator.of(tester.element(find.text('35202-7654321-2'))),
        same(root),
      );
      final frames = await replaced(
        tester,
        app,
        earlier: [
          find.text('Remove Sana Raza?'),
          find.text('35202-7654321-2'),
          find.byType(Dialog),
        ],
        loading: find.bySemanticsLabel('Loading the tenancy'),
        held: [app.leases.gate],
      );
      expect(frames, (earlier: 0, loading: 10));
      expect(await sheetAnswer, isNull);
      expect(await dialogAnswer, isNull);
      expect(find.byType(LeaseDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // A snack bar that names a record (a member removed, a document
    // deleted) goes too, on the first frame: one shown from a section's
    // screen, on the messenger the frame gives the sections, and one shown
    // from above them (a dialog's context), on the app's own messenger.
    // Each is in full view as the account changes: one that has only begun
    // to come in is not drawn yet, and taking it away takes no time. With
    // normal motion, clearing the snack bars alone would play the one on
    // show out over a quarter of a second, its text fully drawn for about
    // the first tenth of a second. With reduced motion (`MmSnackbar` shows
    // it without animating) or a screen reader (no closing animation) it
    // goes at once either way.
    for (final (name, features) in [
      ('', const FakeAccessibilityFeatures()),
      (
        ' with reduced motion',
        const FakeAccessibilityFeatures(disableAnimations: true),
      ),
      (
        ' with a screen reader',
        const FakeAccessibilityFeatures(accessibleNavigation: true),
      ),
    ]) {
      testWidgets("snack bars naming the earlier account's records go on the "
          'first frame$name', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = features;
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final app = await _pumpApp(
          tester,
          location: Routes.lease(aliLease.id),
          size: const Size(390, 3600),
        );
        final shown = [
          showMmSnackbar(
            tester.element(find.byType(LeaseDetailScreen)),
            message: 'Sana Raza removed',
          ),
          showMmSnackbar(
            tester.element(find.byType(MmAdaptiveScaffold)),
            message: 'Bilal Ahmed removed',
          ),
        ];
        await tester.pumpAndSettle();
        expect(_opacity(find.text('Sana Raza removed')), 1);
        expect(_opacity(find.text('Bilal Ahmed removed')), 1);
        final frames = await replaced(
          tester,
          app,
          earlier: [
            find.text('Sana Raza removed'),
            find.text('Bilal Ahmed removed'),
          ],
          loading: find.bySemanticsLabel('Loading the tenancy'),
          held: [app.leases.gate],
        );
        expect(frames, (earlier: 0, loading: 10));
        await Future.wait(shown);
        expect(tester.takeException(), isNull);
      });
    }

    // With normal motion, a snack bar that replaces another waits while that
    // one plays out. As the account changes then, none shows on any frame:
    // the one going out goes at once, the one waiting starts to come in and
    // goes before it is drawn, and one waiting behind that never comes in.
    // The futures of the first two complete. Flutter drops the third with
    // the queue, without completing its future, which nothing in the app
    // awaits, so the test asks only that it never shows.
    testWidgets('snack bars waiting behind one going out never show', (
      tester,
    ) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      final screen = tester.element(find.byType(LeaseDetailScreen));
      final closed = <String>[];
      void show(String message) => showMmSnackbar(
        screen,
        message: message,
      ).whenComplete(() => closed.add(message)).ignore();
      show('Ali Raza archived');
      await tester.pumpAndSettle();
      show('Sana Raza removed');
      show('Bilal Ahmed removed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 48));
      expect(_opacity(find.text('Ali Raza archived')), 1);
      expect(find.text('Sana Raza removed'), findsNothing);
      expect(find.text('Bilal Ahmed removed'), findsNothing);
      final frames = await replaced(
        tester,
        app,
        earlier: [
          find.text('Ali Raza archived'),
          find.text('Sana Raza removed'),
          find.text('Bilal Ahmed removed'),
        ],
        loading: find.bySemanticsLabel('Loading the tenancy'),
        held: [app.leases.gate],
      );
      expect(frames, (earlier: 0, loading: 10));
      expect(closed, containsAll(['Ali Raza archived', 'Sana Raza removed']));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Sana Raza removed'), findsNothing);
      expect(find.text('Bilal Ahmed removed'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // What the shell removes is what is on show as the account changes. A
    // snack bar shown once it has changed is the next account's: it starts
    // to come in at once, on a messenger whose earlier snack bar went and
    // on one with none on show (the app's, whose last one closed by
    // itself), and stays its four seconds. The sheet tests earlier in this
    // group change the account with no snack bar ever shown on either
    // messenger.
    testWidgets("the next account's snack bars, shown once the account has "
        'changed, start to come in at once and stay their time', (
      tester,
    ) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      final screen = find.byType(LeaseDetailScreen);
      final appFrame = find.byType(MmAdaptiveScaffold);
      final closed = showMmSnackbar(
        tester.element(appFrame),
        message: 'Receipt shared',
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await closed;
      expect(find.text('Receipt shared'), findsNothing);
      final earlier = showMmSnackbar(
        tester.element(screen),
        message: 'Sana Raza removed',
      );
      await tester.pumpAndSettle();
      expect(_opacity(find.text('Sana Raza removed')), 1);

      await app.cache.clear();
      app.auth.emit(otherAccount);
      await tester.pump(Duration.zero);
      expect(find.text('Sana Raza removed'), findsNothing);
      await earlier;
      var closedCount = 0;
      final next = [
        showMmSnackbar(tester.element(screen), message: 'Details saved'),
        showMmSnackbar(tester.element(appFrame), message: 'Link copied'),
      ];
      for (final shown in next) {
        shown.whenComplete(() => closedCount++).ignore();
      }
      final drawn = (saved: <double>[], copied: <double>[]);
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(_frame);
        expect(find.text('Details saved'), findsOneWidget);
        expect(find.text('Link copied'), findsOneWidget);
        expect(find.text('Sana Raza removed'), findsNothing);
        drawn.saved.add(_opacity(find.text('Details saved')));
        drawn.copied.add(_opacity(find.text('Link copied')));
      }
      // Coming in: they never fade, and are drawn by the tenth frame.
      for (final opacities in [drawn.saved, drawn.copied]) {
        expect(opacities, orderedEquals([...opacities]..sort()));
        expect(opacities.last, greaterThan(0));
      }
      await tester.pumpAndSettle();
      expect(_opacity(find.text('Details saved')), 1);
      expect(_opacity(find.text('Link copied')), 1);
      await tester.pump(const Duration(seconds: 3));
      expect(closedCount, 0);
      expect(find.text('Details saved'), findsOneWidget);
      expect(find.text('Link copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await Future.wait(next);
      expect(closedCount, 2);
      expect(find.text('Details saved'), findsNothing);
      expect(find.text('Link copied'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // The same account all along is no change: a refreshed session (the
    // same status, which notifies nobody), and a new session of the same
    // account after the device was wiped (a new epoch, which notifies every
    // listener of the status although it is the same).
    for (final wiped in [false, true]) {
      testWidgets(
        'the same account ${wiped ? 'in a new session' : 'refreshed'} keeps '
        'the sheet open',
        (tester) async {
          final app = await _pumpApp(
            tester,
            location: Routes.lease(aliLease.id),
            size: const Size(390, 3600),
          );
          await openOccupant(tester);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MaalikApp)),
          );
          var heard = 0;
          container.listen(authStatusProvider, (_, _) => heard++);
          if (wiped) await app.cache.clear();
          app.auth.emit(signedIn);
          await tester.pumpAndSettle();
          expect(heard, wiped ? 1 : 0);
          expect(find.byType(OccupantSheet), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(OccupantSheet),
              matching: find.text('35202-7654321-2'),
            ),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('a session that ends with a sheet and its dialog open goes '
        'to sign-in, and signing in again opens neither', (tester) async {
      final app = await _pumpApp(
        tester,
        location: Routes.lease(aliLease.id),
        size: const Size(390, 3600),
      );
      await openOccupant(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(OccupantSheet),
          matching: find.widgetWithText(MmButton, 'Remove'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove Sana Raza?'), findsOneWidget);
      await app.cache.clear();
      app.auth.emit(const SignedOut());
      // The first frame after the sign-out, while the router moves on.
      await tester.pump(Duration.zero);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(OccupantSheet), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, testEmail);
      await tester.enterText(find.byType(TextField).last, 'Secret1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(LeaseDetailScreen), findsOneWidget);
      expect(find.byType(OccupantSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(app.leases.calls.where((c) => c.$1 == 'deleteOccupant'), isEmpty);
    });
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

  // Back cancels a deletion until its request is sent; once it is on its
  // way, Back waits for the answer, so leaving never looks like cancelling
  // (the owner's decision). Back is Android's button and its back gesture,
  // the app bar's arrow, and the browser's (the platform reporting the
  // earlier address). Pages open without a transition in these tests, so no
  // swipe drags one away.
  group('deleting the account', () {
    // Types [password] and [email] into the delete screen, in either
    // language.
    Future<void> fill(
      WidgetTester tester, {
      String password = 'Secret1234',
      String email = testEmail,
    }) async {
      await tester.enterText(
        find.descendant(
          of: find.byType(MmPasswordField),
          matching: find.byType(TextField),
        ),
        password,
      );
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is MmTextField &&
                widget.keyboardType == TextInputType.emailAddress,
          ),
          matching: find.byType(TextField),
        ),
        email,
      );
      await tester.pump();
    }

    // Taps "Delete my account", the screen's one destructive button.
    Future<void> tapDelete(WidgetTester tester) async {
      final delete = find.byWidgetPredicate(
        (widget) =>
            widget is MmButton && widget.variant == MmButtonVariant.destructive,
      );
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pump();
    }

    MmButton button(WidgetTester tester, String label) =>
        tester.widget<MmButton>(find.widgetWithText(MmButton, label));

    // The button's progress turns for as long as a command runs, so pump
    // past every transition rather than settle.
    Future<void> settleWhileBusy(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // Fills in the delete screen and deletes, with what [held] answers
    // held: the password check (the sign-in again) or the deletion.
    Future<TestApp> deleting(
      WidgetTester tester, {
      required Gate Function(TestApp app) held,
    }) async {
      final app = await _pumpApp(tester, location: Routes.deleteAccount);
      await fill(tester);
      held(app).close();
      await tapDelete(tester);
      expect(app.auth.calls.single.$1, 'reauthenticate');
      return app;
    }

    Gate checking(TestApp app) => app.auth.gate;
    Gate sending(TestApp app) => app.account.gate;

    // A message from the platform on [channel].
    Future<void> platform(
      WidgetTester tester,
      MethodChannel channel,
      String method, [
      Object? arguments,
    ]) => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );

    final backs = <String, Future<void> Function(WidgetTester tester)>{
      "Android's back button": (tester) =>
          platform(tester, SystemChannels.navigation, 'popRoute'),
      "Android's back gesture": (tester) async {
        const edge = {
          'touchOffset': [0.0, 400.0],
          'progress': 0.0,
          'swipeEdge': 0,
        };
        await platform(
          tester,
          SystemChannels.backGesture,
          'startBackGesture',
          edge,
        );
        await platform(
          tester,
          SystemChannels.backGesture,
          'updateBackGestureProgress',
          {
            ...edge,
            'touchOffset': [200.0, 400.0],
            'progress': 0.6,
          },
        );
        await platform(tester, SystemChannels.backGesture, 'commitBackGesture');
      },
      "the app bar's back": (tester) => tester.tap(find.byType(BackButton)),
      "the browser's back": (tester) =>
          tester.binding.handlePushRoute(Routes.settings),
    };

    GoRouter router(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(Navigator).first));

    void expectNothingSent(TestApp app) {
      expect(
        app.account.calls.map((call) => call.$1),
        isNot(contains('deleteAccount')),
      );
      expect(app.auth.calls.map((call) => call.$1), ['reauthenticate']);
    }

    for (final MapEntry(key: name, value: back) in backs.entries) {
      testWidgets('$name while the password is checked cancels: nothing is '
          'sent and nobody is signed out', (tester) async {
        final app = await deleting(tester, held: checking);
        await back(tester);
        await tester.pumpAndSettle();
        expect(find.text('This cannot be undone'), findsNothing);
        expect(find.text('Delete account'), findsOneWidget);
        app.auth.gate.open();
        await tester.pumpAndSettle();
        expectNothingSent(app);
        expect(router(tester).state.uri.path, Routes.settings);
        expect(find.text('Delete account'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaalikApp)),
        );
        expect(container.read(currentUserIdProvider), testUserId);
      });

      testWidgets('$name while the deletion is on its way does nothing: the '
          'screen stays, and the deletion signs out as before', (tester) async {
        final app = await deleting(tester, held: sending);
        await tester.pump();
        expect(app.account.calls.last.$1, 'deleteAccount');
        await back(tester);
        await settleWhileBusy(tester);
        expect(find.text('This cannot be undone'), findsOneWidget);
        expect(router(tester).state.uri.path, Routes.deleteAccount);
        expect(button(tester, 'Delete my account').busy, isTrue);
        // The page says it cannot be popped, which a back gesture that
        // drags a page away asks before it starts.
        expect(
          ModalRoute.of(tester.element(find.text('This cannot be undone')))!
              .popDisposition,
          RoutePopDisposition.doNotPop,
        );
        app.account.gate.open();
        await tester.pumpAndSettle();
        expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
        expect(find.text('Your account has been deleted'), findsOneWidget);
      });
    }

    // The screen is gone only at the next frame, and Riverpod disposes its
    // provider after that: a check that answers in between, with the
    // provider still there, must not send the deletion either.
    testWidgets('Back cancels also when the password check answers before '
        'the screen is gone', (tester) async {
      final app = await deleting(tester, held: checking);
      await tester.binding.handlePopRoute();
      app.auth.gate.open();
      await tester.idle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaalikApp)),
      );
      expect(container.read(accountDeletionProvider.exists), isTrue);
      expectNothingSent(app);
      await tester.pumpAndSettle();
      expectNothingSent(app);
      expect(router(tester).state.uri.path, Routes.settings);
    });

    // Cancel does what Back does: it works while the password is checked,
    // and waits once the request is on its way.
    testWidgets('Cancel while the password is checked returns to Settings '
        'and sends nothing', (tester) async {
      final app = await deleting(tester, held: checking);
      final cancel = find.widgetWithText(MmButton, 'Cancel');
      expect(tester.widget<MmButton>(cancel).onPressed, isNotNull);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(router(tester).state.uri.path, Routes.settings);
      app.auth.gate.open();
      await tester.pumpAndSettle();
      expectNothingSent(app);
    });

    // Delete, meanwhile, stays busy rather than disabled: a busy button
    // keeps its colours and keyboard focus, and ignores presses.
    testWidgets('Cancel waits while the deletion is on its way', (
      tester,
    ) async {
      final app = await deleting(tester, held: sending);
      await tester.pump();
      expect(
        tester
            .widget<MmButton>(find.widgetWithText(MmButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      expect(button(tester, 'Delete my account').busy, isTrue);
      expect(button(tester, 'Delete my account').onPressed, isNotNull);
      await tapDelete(tester);
      expect(app.auth.calls.map((call) => call.$1), ['reauthenticate']);
      app.account.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
    });

    // The screen cannot be left any other way either while the request is
    // on its way: another section of the navigation bar waits too.
    testWidgets('another section waits while the deletion is on its way', (
      tester,
    ) async {
      final app = await deleting(tester, held: sending);
      await tester.pump();
      await _goToSection(tester, 'Dashboard');
      await settleWhileBusy(tester);
      expect(find.text('This cannot be undone'), findsOneWidget);
      expect(router(tester).state.uri.path, Routes.deleteAccount);
      app.account.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
    });

    // Another account signed in meanwhile (another tab) gets the screen,
    // which the router keeps for whoever is signed in, and the screen waits
    // for the earlier request there too. Delete waits as well, as Cancel
    // does: started while the earlier request was out, that account's
    // password check would run while the screen could not be left, so
    // neither Back nor Cancel could stop it. It is enabled once the earlier
    // request is answered, and that account's own request then keeps the
    // screen in turn.
    testWidgets('another account signed in while a deletion is on its way '
        'can delete only once it is answered, and Back waits meanwhile', (
      tester,
    ) async {
      final app = await deleting(tester, held: sending);
      await tester.pump();
      final answerEarlier = app.account.gate.holdLaterCallsApart();
      await app.cache.clear();
      app.auth.emit(otherAccount);
      await settleWhileBusy(tester);
      // That account's preview answers, and its form is new.
      app.account.gate.open();
      await settleWhileBusy(tester);
      expect(button(tester, 'Delete my account').busy, isFalse);
      await fill(tester, password: 'Other1234', email: otherAccount.email!);
      expect(button(tester, 'Delete my account').onPressed, isNull);
      expect(button(tester, 'Cancel').onPressed, isNull);
      await tapDelete(tester);
      await tester.binding.handlePopRoute();
      await settleWhileBusy(tester);
      expect(router(tester).state.uri.path, Routes.deleteAccount);
      expect(
        ModalRoute.of(tester.element(find.text('This cannot be undone')))!
            .popDisposition,
        RoutePopDisposition.doNotPop,
      );
      expect(app.auth.calls.map((call) => call.$1), ['reauthenticate']);
      expect(app.account.calls.map((call) => call.$1), [
        'deletionPreview',
        'deleteAccount',
        'deletionPreview',
      ]);
      // The earlier request answers: its account no longer holds the
      // device, so nobody is signed out by it, and the screen is free.
      answerEarlier();
      await settleWhileBusy(tester);
      expect(app.auth.calls.map((call) => call.$1), ['reauthenticate']);
      expect(button(tester, 'Delete my account').onPressed, isNotNull);
      expect(button(tester, 'Cancel').onPressed, isNotNull);
      app.account.gate.close();
      await tapDelete(tester);
      await tester.pump();
      expect(
        app.account.calls
            .where((call) => call.$1 == 'deleteAccount')
            .map((call) => call.$2),
        [
          [testEmail],
          [otherAccount.email],
        ],
      );
      await tester.binding.handlePopRoute();
      await settleWhileBusy(tester);
      expect(router(tester).state.uri.path, Routes.deleteAccount);
      expect(button(tester, 'Delete my account').busy, isTrue);
      expect(button(tester, 'Cancel').onPressed, isNull);
      app.account.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
      expect(find.text('Your account has been deleted'), findsOneWidget);
    });

    // The next account presses Delete while the earlier request is out,
    // then leaves, and the earlier request answers only after that: the
    // press started nothing, so no password is checked and nothing is sent
    // for that account. Once the earlier request is answered its own
    // deletion starts, and leaving while its password is checked cancels
    // it, as for anyone.
    final leavings = <String, Future<void> Function(WidgetTester tester)>{
      'Back': (tester) => tester.binding.handlePopRoute(),
      'Cancel': (tester) => tester.tap(find.widgetWithText(MmButton, 'Cancel')),
    };
    for (final MapEntry(key: name, value: leave) in leavings.entries) {
      testWidgets("$name cancels the next account's deletion while its "
          'password is checked, also when it signed in while an earlier '
          'deletion was on its way', (tester) async {
        final app = await deleting(tester, held: sending);
        await tester.pump();
        final answerEarlier = app.account.gate.holdLaterCallsApart();
        await app.cache.clear();
        app.auth.emit(otherAccount);
        await settleWhileBusy(tester);
        app.account.gate.open();
        await settleWhileBusy(tester);
        await fill(tester, password: 'Other1234', email: otherAccount.email!);
        app.auth.gate.close();
        await tapDelete(tester);
        await leave(tester);
        await settleWhileBusy(tester);
        expect(router(tester).state.uri.path, Routes.deleteAccount);
        app.account.gate.close();
        app.auth.gate.open();
        await settleWhileBusy(tester);
        expect(
          app.account.calls
              .where((call) => call.$1 == 'deleteAccount')
              .map((call) => call.$2),
          [
            [testEmail],
          ],
        );
        expect(app.auth.calls.map((call) => call.$1), ['reauthenticate']);
        app.account.gate.open();
        answerEarlier();
        await settleWhileBusy(tester);
        expect(button(tester, 'Delete my account').busy, isFalse);
        app.auth.gate.close();
        await tapDelete(tester);
        expect(button(tester, 'Delete my account').busy, isTrue);
        await leave(tester);
        await tester.pumpAndSettle();
        expect(router(tester).state.uri.path, Routes.settings);
        app.auth.gate.open();
        await tester.pumpAndSettle();
        expect(app.auth.calls.map((call) => call.$1), [
          'reauthenticate',
          'reauthenticate',
        ]);
        expect(
          app.account.calls.where((call) => call.$1 == 'deleteAccount'),
          hasLength(1),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaalikApp)),
        );
        expect(container.read(currentUserIdProvider), otherAccount.userId);
        expect(tester.takeException(), isNull);
      });
    }

    // The first account's password check can still be out when another
    // account signs in (another tab), its form goes with it, and that
    // account starts its own deletion, which replaces the first. The first
    // check's late answer then sends nothing and touches no form: the one
    // it was started from is gone, and the screen is the next account's.
    testWidgets('a password check answered after the next account started '
        'its own deletion sends nothing, and only the later deletion is '
        'sent', (tester) async {
      final app = await deleting(tester, held: checking);
      final answerEarlierCheck = app.auth.gate.holdLaterCallsApart();
      app.account.gate.close();
      await app.cache.clear();
      app.auth.emit(otherAccount);
      await settleWhileBusy(tester);
      app.account.gate.open();
      await settleWhileBusy(tester);
      expect(find.text('This cannot be undone'), findsOneWidget);
      expect(button(tester, 'Delete my account').busy, isFalse);
      await fill(tester, password: 'Other1234', email: otherAccount.email!);
      app.account.gate.close();
      await tapDelete(tester);
      expect(app.auth.calls.map((call) => call.$1), [
        'reauthenticate',
        'reauthenticate',
      ]);
      answerEarlierCheck();
      await settleWhileBusy(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Deletion cancelled'), findsNothing);
      expect(button(tester, 'Delete my account').busy, isTrue);
      expect(
        app.account.calls.map((call) => call.$1),
        isNot(contains('deleteAccount')),
      );
      app.auth.gate.open();
      await settleWhileBusy(tester);
      expect(
        app.account.calls
            .where((call) => call.$1 == 'deleteAccount')
            .map((call) => call.$2),
        [
          [otherAccount.email],
        ],
      );
      app.account.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
      expect(find.text('Your account has been deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Another section while the password is checked cancels, as Back
    // does, but the section keeps its screens: the delete screen is still
    // there when the user comes back, no longer busy, and says that nothing
    // was sent, in English and in Urdu.
    for (final urdu in [false, true]) {
      testWidgets('another section while the password is checked cancels, '
          'and the screen says so when shown again${urdu ? ' (Urdu)' : ''}', (
        tester,
      ) async {
        final app = await _pumpApp(
          tester,
          app: TestApp(language: urdu ? 'ur' : 'en'),
          location: Routes.deleteAccount,
        );
        await fill(tester);
        app.auth.gate.close();
        await tapDelete(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(MmPasswordField)),
        );
        final notice = find.text(l10n.deletionCancelledBody);
        expect(notice, findsNothing);
        await _goToSection(tester, l10n.navDashboard);
        await settleWhileBusy(tester);
        expect(router(tester).state.uri.path, Routes.home);
        await _goToSection(tester, l10n.navMore);
        await settleWhileBusy(tester);
        expect(router(tester).state.uri.path, Routes.deleteAccount);
        expect(button(tester, l10n.deleteAccountConfirmAction).busy, isFalse);
        expect(button(tester, l10n.cancelAction).onPressed, isNotNull);
        expect(notice, findsOneWidget);
        expect(find.text(l10n.deletionCancelledTitle), findsOneWidget);
        // The check answers afterwards: still nothing is sent, and no
        // failure is shown.
        app.auth.gate.open();
        await tester.pumpAndSettle();
        expectNothingSent(app);
        expect(notice, findsOneWidget);
        expect(find.byType(FailureBanner), findsNothing);
      });
    }

    // Deleting again from that screen before the cancelled check answers
    // starts a deletion of its own, which is the one that sends; the
    // cancelled one's answer changes nothing on the screen.
    testWidgets('a deletion started again on the screen another section '
        'cancelled sends once, and stays busy until answered', (tester) async {
      final app = await deleting(tester, held: checking);
      await _goToSection(tester, 'Dashboard');
      await settleWhileBusy(tester);
      await _goToSection(tester, 'More');
      await settleWhileBusy(tester);
      expect(find.text('Deletion cancelled'), findsOneWidget);
      app.account.gate.close();
      await tapDelete(tester);
      expect(find.text('Deletion cancelled'), findsNothing);
      // Both checks answer: the cancelled one sends nothing.
      app.auth.gate.open();
      await settleWhileBusy(tester);
      expect(
        app.account.calls.where((call) => call.$1 == 'deleteAccount'),
        hasLength(1),
      );
      expect(button(tester, 'Delete my account').busy, isTrue);
      expect(button(tester, 'Cancel').onPressed, isNull);
      app.account.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.map((call) => call.$1), [
        'reauthenticate',
        'reauthenticate',
        'signOut',
      ]);
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
    });

    // The notice is only for a deletion cancelled before its request: a
    // wrong password, where nobody left, and a refused request, where one
    // was sent, show their failure and no notice.
    testWidgets('a wrong password, or a refused request, shows its failure '
        'and no cancel notice', (tester) async {
      final app = await _pumpApp(tester, location: Routes.deleteAccount);
      await fill(tester);
      app.auth.gate.failure = const RejectedFailure('invalid_credentials');
      await tapDelete(tester);
      await tester.pumpAndSettle();
      app.auth.gate.failure = null;
      expect(
        tester.widget<MmPasswordField>(find.byType(MmPasswordField)).errorText,
        'The e-mail or password is not right.',
      );
      expect(find.text('Deletion cancelled'), findsNothing);
      await fill(tester, password: 'Secret12345');
      app.account.gate.failure = const TemporarilyUnavailable();
      await tapDelete(tester);
      await tester.pumpAndSettle();
      app.account.gate.failure = null;
      expect(app.account.calls.last.$1, 'deleteAccount');
      expect(find.byType(FailureBanner), findsOneWidget);
      expect(find.text('Deletion cancelled'), findsNothing);
      expect(button(tester, 'Delete my account').busy, isFalse);
      expect(app.auth.calls.map((call) => call.$1), [
        'reauthenticate',
        'reauthenticate',
      ]);
    });

    // The router's own redirect at a sign-out is never held up: the screen
    // leaves for the sign-in screen, and the answer signs out as a
    // deletion.
    testWidgets('signs out as a deletion once its session was signed out in '
        'another tab', (tester) async {
      final app = await deleting(tester, held: sending);
      await tester.pump();
      await app.cache.clear();
      app.auth.emit(const SignedOut());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.text('Your account has been deleted'), findsNothing);
      app.account.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
      expect(find.text('Your account has been deleted'), findsOneWidget);
    });
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
