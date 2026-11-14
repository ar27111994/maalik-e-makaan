import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/routing/app_router.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

const _residenceQuestion = 'Do you live in Pakistan?';
const _ownerQuestion = 'Does the owner of these properties live abroad?';

/// Pumps the whole app over [app]'s fakes.
Future<TestApp> _pumpApp(WidgetTester tester, TestApp app) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: app.overrides,
      retry: (_, _) => null,
      child: const MaalikApp(),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaalikApp)));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// The owner-abroad question's sheet, open.
Finder get _sheet => find.descendant(
  of: find.byType(BottomSheet),
  matching: shown(_ownerQuestion),
);

TestApp _unanswered({
  List<PortfolioMembership> portfolios = const [gulberg, plaza],
  Map<String, Object> settings = const {},
}) => TestApp(
  residence: AccountResidence.notStated,
  portfolios: portfolios,
  settings: settings,
);

void main() {
  group('the residence question', () {
    testWidgets('is asked once after sign-in, and Not now waits a week', (
      tester,
    ) async {
      final app = await _pumpApp(tester, _unanswered());
      expect(shown(_residenceQuestion), findsOneWidget);
      await _tap(tester, find.text('Not now'));
      expect(shown(_residenceQuestion), findsNothing);
      expect(find.text('What needs attention'), findsOneWidget);
      expect(
        app.settings.values[AppSettings.residenceSnoozeKey],
        '$testUserId/2026-11-14T05:00:00.000Z',
      );
      // Not again in this run, whatever is opened and closed.
      await _tap(tester, find.text('More'));
      await _tap(tester, find.text('Dashboard'));
      expect(shown(_residenceQuestion), findsNothing);
    });

    testWidgets('a set-aside question waits, then is asked again', (
      tester,
    ) async {
      final snoozed = {
        AppSettings.residenceSnoozeKey: '$testUserId/2026-11-14T05:00:00.000Z',
      };
      await _pumpApp(
        tester,
        _unanswered(settings: snoozed)..now = DateTime.utc(2026, 11, 10),
      );
      expect(shown(_residenceQuestion), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pumpApp(
        tester,
        _unanswered(settings: snoozed)..now = DateTime.utc(2026, 11, 15, 6),
      );
      expect(shown(_residenceQuestion), findsOneWidget);
    });

    testWidgets('closing it with the back button sets it aside too', (
      tester,
    ) async {
      final app = await _pumpApp(tester, _unanswered());
      await _tap(tester, find.byType(BackButton));
      expect(shown(_residenceQuestion), findsNothing);
      expect(app.settings.values[AppSettings.residenceSnoozeKey], isNotNull);
    });

    testWidgets('an answer is saved and nothing is set aside', (tester) async {
      final app = await _pumpApp(tester, _unanswered());
      await _tap(tester, find.text('Yes, in Pakistan'));
      await _tap(tester, find.widgetWithText(MmButton, 'Save'));
      expect(shown(_residenceQuestion), findsNothing);
      expect(app.residences.residence.stated, isTrue);
      expect(app.settings.values[AppSettings.residenceSnoozeKey], isNull);
    });

    testWidgets('is not asked from a saved copy, or once answered', (
      tester,
    ) async {
      final offline = _unanswered()
        ..residences.fetchFailure = const NetworkFailure();
      await offline.cache.write(
        testUserId,
        'residence',
        AccountResidence.notStated.toRow(),
      );
      await _pumpApp(tester, offline);
      expect(shown(_residenceQuestion), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pumpApp(tester, TestApp());
      expect(shown(_residenceQuestion), findsNothing);
    });

    testWidgets('signing in as someone else asks them', (tester) async {
      final app = await _pumpApp(tester, _unanswered());
      await _tap(tester, find.text('Not now'));
      app.auth.emit(const SignedOut());
      await tester.pumpAndSettle();
      app.auth.emit(
        const SignedIn(userId: 'another-user', email: 'other@example.com'),
      );
      await tester.pumpAndSettle();
      expect(shown(_residenceQuestion), findsOneWidget);
    });
  });

  group("a portfolio's owner-abroad question", () {
    testWidgets('is asked of its owner, from the list just read', (
      tester,
    ) async {
      final app = await _pumpApp(
        tester,
        TestApp(portfolios: const [gulbergUnanswered, plaza]),
      );
      expect(_sheet, findsOneWidget);
      expect(
        find.text('Nobody has answered this for Gulberg Houses yet.'),
        findsOneWidget,
      );
      await _tap(tester, find.text('No, the owner lives in Pakistan'));
      await _tap(tester, find.text('Save answer'));
      expect(_sheet, findsNothing);
      expect(find.text('Answer saved.'), findsOneWidget);
      expect(app.portfolios.calls.last.$1, 'answerOwnerAbroad');
      expect(app.portfolios.calls.last.$2, [gulberg.id, false]);
      expect(
        _container(tester).read(currentPortfolioProvider).value!.ownerAbroad,
        OwnerAbroad.inPakistan,
      );
    });

    testWidgets('is asked of a manager', (tester) async {
      await _pumpApp(
        tester,
        TestApp(
          portfolios: const [gulberg, plazaUnanswered],
          settings: {
            AppSettings.currentPortfolioKey: '$testUserId/${plaza.id}',
          },
        ),
      );
      expect(_sheet, findsOneWidget);
      expect(
        find.text('Once you answer, only an owner can change it.'),
        findsOneWidget,
      );
    });

    testWidgets('is not asked of accountants and viewers', (tester) async {
      for (final role in [MemberRole.accountant, MemberRole.viewer]) {
        await _pumpApp(
          tester,
          TestApp(
            portfolios: [
              PortfolioMembership(
                id: gulberg.id,
                name: gulberg.name,
                role: role,
              ),
            ],
          ),
        );
        expect(_sheet, findsNothing, reason: '$role');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('is not asked from a saved list', (tester) async {
      final app = TestApp(portfolios: const [gulbergUnanswered])
        ..portfolios.listFailure = const NetworkFailure();
      await app.cache.write(testUserId, PortfoliosController.query, [
        gulbergUnanswered.toRow(),
      ]);
      await _pumpApp(tester, app);
      expect(find.text('What needs attention'), findsOneWidget);
      expect(_sheet, findsNothing);
    });

    testWidgets('waits for the residence question, then follows it', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        _unanswered(portfolios: const [gulbergUnanswered, plaza]),
      );
      expect(shown(_residenceQuestion), findsOneWidget);
      expect(_sheet, findsNothing);
      await _tap(tester, find.text('Not now'));
      expect(_sheet, findsOneWidget);
    });

    testWidgets('Not now waits for the next run, or another portfolio', (
      tester,
    ) async {
      final app = await _pumpApp(
        tester,
        TestApp(portfolios: const [gulbergUnanswered, plazaUnanswered]),
      );
      expect(_sheet, findsOneWidget);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Not now'),
        ),
      );
      expect(_sheet, findsNothing);
      expect(
        app.portfolios.calls.map((c) => c.$1),
        isNot(contains('answerOwnerAbroad')),
      );
      final selected = _container(tester)
          .read(selectedPortfolioProvider(testUserId).notifier);
      await selected.select(plaza.id);
      await tester.pumpAndSettle();
      expect(
        find.text('Nobody has answered this for Saddar Plaza yet.'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await selected.select(gulberg.id);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      // Signing in again is a new run for the question.
      app.auth.emit(const SignedOut());
      await tester.pumpAndSettle();
      app.auth.emit(signedIn);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
    });

    testWidgets('waits while another screen is open above the shell', (
      tester,
    ) async {
      final app = TestApp(portfolios: const [gulbergUnanswered, plaza]);
      app.portfolios.gate.close();
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: app.overrides,
          retry: (_, _) => null,
          child: const MaalikApp(),
        ),
      );
      await tester.pump();
      // "Where you live" is open when the list arrives.
      unawaited(_container(tester).read(routerProvider).push(Routes.residence));
      await tester.pumpAndSettle();
      app.portfolios.gate.open();
      await tester.pumpAndSettle();
      expect(shown(_residenceQuestion), findsOneWidget);
      expect(_sheet, findsNothing);
      await _tap(tester, find.text('Cancel'));
      expect(_sheet, findsOneWidget);
    });
  });
}
