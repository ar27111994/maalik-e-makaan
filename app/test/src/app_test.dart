import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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

  testWidgets('sections switch from the navigation bar', (tester) async {
    await _pumpApp(tester);
    for (final (label, title) in [
      ('Properties', 'Properties is being built'),
      ('Tenants', 'Tenants is being built'),
      ('Money', 'Money is being built'),
      ('Dashboard', 'Dashboard is being built'),
    ]) {
      await tester.tap(_inNavigation(label));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: label);
    }
    // Tapping the open section again returns to its first screen.
    await tester.tap(_inNavigation('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Your details'), findsOneWidget);
    await tester.tap(_inNavigation('More'));
    await tester.pumpAndSettle();
    expect(find.text('Switch portfolio'), findsOneWidget);
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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
    expect(find.text('Money is being built'), findsOneWidget);
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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
    expect(find.text('Dashboard is being built'), findsOneWidget);
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
}
