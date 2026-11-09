import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover_repository.dart';
import 'package:maalik_e_makaan/src/features/insights/data/insights_repository.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/statement_sheets.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease_repository.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger_repository.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/document_share.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/pdf/ledger_pdfs.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/receipt_screen.dart';
import 'package:maalik_e_makaan/src/features/ledger/presentation/tenancy_ledger_screen.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification_repository.dart';
import 'package:maalik_e_makaan/src/features/operations/data/operations_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property_repository.dart';
import 'package:maalik_e_makaan/src/features/reminders/application/reminders.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder_repository.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant_repository.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'contrast.dart';
import 'fakes.dart';
import 'insights_fakes.dart';
import 'money_fakes.dart';
import 'operations_fakes.dart';

export 'contrast.dart';
export 'fakes.dart';
export 'insights_fakes.dart';
export 'money_fakes.dart';
export 'operations_fakes.dart';
export 'words.dart';

/// The ways every screen is checked (as in mm_ui's harness): each theme
/// mode, Urdu (right to left, Nastaliq), and English at 200% text size.
enum MmVariant {
  light(Brightness.light, Locale('en'), 1),
  dark(Brightness.dark, Locale('en'), 1),
  lightHighContrast(Brightness.light, Locale('en'), 1, highContrast: true),
  darkHighContrast(Brightness.dark, Locale('en'), 1, highContrast: true),
  urdu(Brightness.light, Locale('ur'), 1),
  largeText(Brightness.light, Locale('en'), 2);

  new(
    this.brightness,
    this.locale,
    this.textScale, {
    this.highContrast = false,
  });

  final Brightness brightness;
  final bool highContrast;
  final Locale locale;
  final double textScale;

  ThemeData get theme => MmTheme.data(
    brightness: brightness,
    script: MmScript.of(locale),
    highContrast: highContrast,
  );
}

/// The boundary around the whole app that screen goldens capture.
const screenKey = ValueKey<String>('mm-screen');

/// What a screen under test talks to: fakes for every repository, the
/// device's settings and cache in memory, and who is signed in.
final class TestApp {
  new({
    AuthStatus auth = signedIn,
    String? language = 'en',
    List<PortfolioMembership>? portfolios = const [gulberg, plaza],
    Profile? profile,
    DeletionPreview? preview,
    Map<String, Object> settings = const {},
  }) : auth = FakeAuthRepository(auth),
       profiles = FakeProfileRepository(profile ?? ayesha),
       portfolios = FakePortfolioRepository(portfolios),
       account = FakeAccountRepository(preview),
       settings = MemorySettingsStore({
         AppSettings.localeKey: ?language,
         ...settings,
       });

  final FakeAuthRepository auth;
  final FakeProfileRepository profiles;
  final FakePortfolioRepository portfolios;
  final FakeAccountRepository account;
  final FakeTeamRepository team = FakeTeamRepository();
  final FakePropertyRepository properties = FakePropertyRepository();
  final FakeTenantRepository tenants = FakeTenantRepository();
  final FakeLeaseRepository leases = FakeLeaseRepository();
  final FakeDocumentRepository documents = FakeDocumentRepository();
  final FakeDocumentPicker picker = FakeDocumentPicker();
  final FakeLedgerRepository ledger = FakeLedgerRepository();
  final FakeHandoverRepository handovers = FakeHandoverRepository();
  final FakeReminderRepository reminders = FakeReminderRepository();
  final FakeNotificationRepository notifications = FakeNotificationRepository();
  final FakeSharer sharer = FakeSharer();
  final FakeOperationsRepository operations = FakeOperationsRepository();
  final FakeInsightsRepository insights = FakeInsightsRepository();

  /// The documents the app made, as (kind, language) pairs.
  final made = <(String, DocumentLanguage)>[];

  /// What the report makers throw instead of making a document.
  Error? makeError;

  /// Now, for the reminders' etiquette: Saturday 7 November 2026, 10 AM in
  /// Pakistan.
  DateTime now = DateTime.utc(2026, 11, 7, 5);
  final MemorySettingsStore settings;
  final MemoryStore store = MemoryStore();
  late final SwrCache cache = SwrCache(store);

  /// The links the app asked to open in another app.
  final opened = <Uri>[];

  /// Whether opening a link works.
  bool canOpenLinks = true;

  List<Override> get overrides => [
    settingsStoreProvider.overrideWithValue(settings),
    swrCacheProvider.overrideWithValue(cache),
    authRepositoryProvider.overrideWithValue(auth),
    profileRepositoryProvider.overrideWithValue(profiles),
    portfolioRepositoryProvider.overrideWithValue(portfolios),
    accountRepositoryProvider.overrideWithValue(account),
    teamRepositoryProvider.overrideWithValue(team),
    propertyRepositoryProvider.overrideWithValue(properties),
    tenantRepositoryProvider.overrideWithValue(tenants),
    leaseRepositoryProvider.overrideWithValue(leases),
    documentRepositoryProvider.overrideWithValue(documents),
    documentPickerProvider.overrideWithValue(picker),
    filePreparerProvider.overrideWithValue(picker.prepare),
    ledgerRepositoryProvider.overrideWithValue(ledger),
    handoverRepositoryProvider.overrideWithValue(handovers),
    reminderRepositoryProvider.overrideWithValue(reminders),
    notificationRepositoryProvider.overrideWithValue(notifications),
    operationsRepositoryProvider.overrideWithValue(operations),
    documentSharerProvider.overrideWithValue(sharer.share),
    insightsRepositoryProvider.overrideWithValue(insights),
    ownerStatementMakerProvider.overrideWithValue((statement, setup) async {
      if (makeError case final error?) throw error;
      made.add(('owner statement', setup.language));
      return fakePdf;
    }),
    taxYearMakerProvider.overrideWithValue((statement, setup) async {
      made.add(('tax year', setup.language));
      return fakePdf;
    }),
    receiptMakerProvider.overrideWithValue((detail, setup) async {
      made.add(('receipt', setup.language));
      return fakePdf;
    }),
    statementMakerProvider.overrideWithValue((statement, setup) async {
      made.add(('statement', setup.language));
      return fakePdf;
    }),
    nowProvider.overrideWithValue(() => now),
    // The day every test's dates and deadlines are measured from.
    todayProvider.overrideWithValue(CalendarDate(2026, 11, 7)),
    linkOpenerProvider.overrideWithValue((link) async {
      opened.add(link);
      return canOpenLinks;
    }),
  ];
}

/// The location of the screen under test in [pumpScreen]'s router.
const screenPath = '/screen';

/// A router that shows [screen] at [screenPath] and a placeholder reading
/// `route:<path>` at every route of the app, so a test sees where a screen
/// navigates.
GoRouter testRouter(Widget Function() screen, {Object? extra}) => GoRouter(
  initialLocation: screenPath,
  initialExtra: extra,
  routes: [
    GoRoute(path: screenPath, builder: (context, state) => screen()),
    for (final path in const [
      Routes.welcome,
      Routes.signIn,
      Routes.signUp,
      Routes.forgotPassword,
      Routes.checkEmail,
      Routes.updatePassword,
      Routes.createPortfolio,
      Routes.invite,
      Routes.home,
      Routes.search,
      Routes.reports,
      Routes.taxYear,
      Routes.more,
      Routes.team,
      Routes.inviteMember,
      Routes.portfolioDetails,
      Routes.settings,
      Routes.deleteAccount,
      Routes.properties,
      Routes.newProperty,
      '/properties/:propertyId',
      '/properties/:propertyId/edit',
      '/properties/:propertyId/units/new',
      '/properties/:propertyId/units/:unitId',
      '/properties/:propertyId/units/:unitId/edit',
      Routes.tenants,
      '/tenants/new',
      '/tenants/:tenantId',
      '/tenants/:tenantId/edit',
      '/leases/new',
      '/leases/:leaseId',
      '/leases/:leaseId/edit',
      Routes.money,
      Routes.cash,
      '/money/leases/:leaseId',
      '/money/leases/:leaseId/pay',
      '/money/leases/:leaseId/receipts/:paymentId',
      Routes.notifications,
      Routes.expenses,
      '/more/expenses/new',
      '/more/expenses/:expenseId',
      '/more/expenses/:expenseId/edit',
      Routes.utilities,
      Routes.newUtility,
      '/more/utilities/bills/:billId',
      '/more/utilities/readings/:readingId',
      '/more/utilities/:accountId',
      '/more/utilities/:accountId/edit',
      Routes.maintenance,
      '/more/maintenance/new',
      '/more/maintenance/:requestId',
      '/more/maintenance/:requestId/edit',
    ])
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(
          body: Text(
            'route:${state.uri}'
            '${state.extra == null ? '' : ' ${state.extra}'}',
          ),
        ),
      ),
  ],
);

/// Pumps [screen] as the app's page for [variant] on a window of [size]
/// (one device pixel per logical pixel) with [app]'s fakes, and lets it
/// settle unless [settle] is false (a busy or loading screen animates).
/// [textScale] replaces the variant's text size (Urdu at 200%).
Future<TestApp> pumpScreen(
  WidgetTester tester,
  Widget Function() screen, {
  TestApp? app,
  MmVariant variant = MmVariant.light,
  Size size = const Size(360, 740),
  Object? extra,
  bool settle = true,
  double? textScale,
}) async {
  final testApp = app ?? TestApp();
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = testRouter(screen, extra: extra);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testApp.overrides,
      retry: (_, _) => null,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: variant.theme,
        locale: variant.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale ?? variant.textScale),
          ),
          child: MmFormats(
            money: MoneyFormat(
              language: variant.locale.languageCode == 'ur'
                  ? MoneyLanguage.urdu
                  : MoneyLanguage.english,
            ),
            child: RepaintBoundary(
              key: screenKey,
              child: ColoredBox(color: context.mm.colors.bg, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return testApp;
}

/// Asserts the accessibility guidelines: 48 dp tap targets (Android) and
/// 44 pt (iOS), a label on every tappable element, and text contrast
/// measured by [mmTextContrastGuideline].
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(mmTextContrastGuideline));
}

/// Registers one widget test per variant, named `<description> (<variant>)`.
void testEveryVariant(
  String description,
  Future<void> Function(WidgetTester tester, MmVariant variant) body, {
  Iterable<MmVariant> variants = MmVariant.values,
}) {
  for (final variant in variants) {
    testWidgets(
      '$description (${variant.name})',
      (tester) => body(tester, variant),
    );
  }
}

/// Registers, for every variant, a test that pumps [screen] (see
/// [pumpScreen]) with the fakes [app] makes, runs [act] (to open a sheet or
/// show an error), checks the accessibility guidelines and compares the
/// whole window with `goldens/<name>_<variant>.png`.
///
/// The window is [size], or the size [sizes] gives a variant. Call it from
/// a file tagged `@Tags(['golden'])`.
void screenGoldenEveryVariant(
  String name,
  Widget Function() screen, {
  TestApp Function()? app,
  Future<void> Function(WidgetTester tester)? act,
  Size size = const Size(360, 740),
  Map<MmVariant, Size> sizes = const {},
  Iterable<MmVariant> variants = MmVariant.values,
}) {
  testEveryVariant('$name golden', (tester, variant) async {
    await pumpScreen(
      tester,
      screen,
      app: app?.call(),
      variant: variant,
      size: sizes[variant] ?? size,
    );
    await act?.call(tester);
    await expectAccessible(tester);
    await expectLater(
      find.byKey(screenKey),
      matchesGoldenFile('goldens/${name}_${variant.name}.png'),
    );
  }, variants: variants);
}

/// The text of the placeholder of [path] in [testRouter].
Finder routeShown(String path) => find.text('route:$path');

/// Text shown anywhere, including in a paragraph with an icon (a field's
/// error line, a labelled icon).
Finder shown(String text) => find.textContaining(text, findRichText: true);
