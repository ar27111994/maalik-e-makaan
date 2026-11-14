import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/create_portfolio_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:maalik_e_makaan/src/shell/more_screen.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

Future<void> _name(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _create(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(MmButton, 'Create portfolio'));
  await tester.pumpAndSettle();
}

const _question = 'Does the owner of these properties live abroad?';
const _abroad = 'Yes, the owner lives abroad';
const _inPakistan = 'No, the owner lives in Pakistan';

/// Answers "Does the owner of these properties live abroad?".
Future<void> _answer(WidgetTester tester, String label) async {
  final option = find.text(label);
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  group('creating a portfolio', () {
    testWidgets('the first run explains, and offers Settings and sign out', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        CreatePortfolioScreen.new,
        app: TestApp(portfolios: const []),
      );
      expect(find.text('Create your portfolio'), findsOneWidget);
      expect(find.textContaining('A portfolio holds'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(app.auth.calls.single.$1, 'signOut');
    });

    testWidgets('the first run can open Settings', (tester) async {
      await pumpScreen(
        tester,
        CreatePortfolioScreen.new,
        app: TestApp(portfolios: const []),
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.settings), findsOneWidget);
    });

    testWidgets('names it, sends one attempt id, and opens it', (tester) async {
      final app = TestApp(portfolios: const []);
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      await _create(tester);
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _name(tester, 'x' * 81);
      // The field stops at 80 characters.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        hasLength(80),
      );
      app.portfolios.gate.failure = const NetworkFailure();
      await _name(tester, 'Khan family');
      await _answer(tester, _abroad);
      await _create(tester);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      app.portfolios.gate.failure = null;
      await _create(tester);
      final attempts = [
        for (final call in app.portfolios.calls)
          if (call.$1 == 'create') call.$2,
      ];
      expect(attempts, hasLength(2));
      // The retry is the same attempt.
      expect(attempts.first[1], attempts.last[1]);
      expect(routeShown(Routes.home), findsOneWidget);
      expect(find.text('Khan family is ready.'), findsOneWidget);
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/${attempts.last[1]}',
      );
    });

    testWidgets('an invalid name is shown on the field', (tester) async {
      final app = TestApp(portfolios: const []);
      app.portfolios.gate.failure = const RejectedFailure(
        'constraint_violation',
      );
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      await _name(tester, 'Khan family');
      await _answer(tester, _inPakistan);
      await _create(tester);
      expect(
        tester.widget<MmTextField>(find.byType(MmTextField)).errorText,
        'This name cannot be used. Use letters, numbers and spaces.',
      );
      await _name(tester, 'Khan family 2');
      expect(
        tester.widget<MmTextField>(find.byType(MmTextField)).errorText,
        isNull,
      );
    });

    testWidgets('the limit is explained above the form', (tester) async {
      final app = TestApp();
      app.portfolios.gate.failure = const RejectedFailure(
        'portfolio_limit_reached',
      );
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      expect(find.text('New portfolio'), findsOneWidget);
      await _name(tester, 'One more');
      await _answer(tester, _inPakistan);
      await _create(tester);
      expect(find.text('You can own up to 20 portfolios.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.more), findsOneWidget);
    });

    testWidgets('submitting from the keyboard creates too', (tester) async {
      final app = TestApp(portfolios: const []);
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      await _answer(tester, _abroad);
      await _name(tester, 'Khan family');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.portfolios.memberships.single.name, 'Khan family');
    });
  });

  group("the new portfolio's owner-abroad question", () {
    /// Checks that neither answer is chosen, for screen readers too.
    void expectUnanswered(WidgetTester tester) {
      expect(
        tester
            .widget<MmRadioGroup<OwnerAbroad>>(
              find.byType(MmRadioGroup<OwnerAbroad>),
            )
            .value,
        isNull,
      );
      for (final label in const [_abroad, _inPakistan]) {
        expect(
          tester.getSemantics(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(RadioListTile<OwnerAbroad>),
            ),
          ),
          isSemantics(hasCheckedState: true, isChecked: false),
          reason: label,
        );
      }
    }

    testWidgets("starts unanswered, whatever the creator's residence", (
      tester,
    ) async {
      for (final residence in [
        residentInLondon,
        residentInPakistan,
        AccountResidence.notStated,
      ]) {
        await pumpScreen(
          tester,
          CreatePortfolioScreen.new,
          app: TestApp(portfolios: const [], residence: residence),
        );
        expect(shown(_question), findsOneWidget);
        expectUnanswered(tester);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('cannot be submitted unanswered', (tester) async {
      final app = TestApp(portfolios: const []);
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      await _name(tester, 'Khan family');
      await _create(tester);
      expect(shown('Choose whether the owner lives abroad.'), findsOneWidget);
      expect(app.portfolios.calls.map((c) => c.$1), isNot(contains('create')));
      // Answering clears the error.
      await _answer(tester, _inPakistan);
      expect(shown('Choose whether the owner lives abroad.'), findsNothing);
    });

    testWidgets('sends the answer chosen', (tester) async {
      for (final (label, answer) in [
        (_abroad, OwnerAbroad.abroad),
        (_inPakistan, OwnerAbroad.inPakistan),
      ]) {
        final app = TestApp(portfolios: const []);
        await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
        await _name(tester, 'Khan family');
        await _answer(tester, label);
        await _create(tester);
        final call = app.portfolios.calls.firstWhere((c) => c.$1 == 'create');
        expect(call.$2.first, 'Khan family');
        expect(call.$2.last, answer);
        expect(find.text('Khan family is ready.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a retry that kept the first answer says so', (tester) async {
      final app = TestApp(portfolios: const []);
      app.portfolios.gate.failure = const NetworkFailure();
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      await _name(tester, 'Khan family');
      await _answer(tester, _abroad);
      await _create(tester);
      final attempt =
          app.portfolios.calls.firstWhere((c) => c.$1 == 'create').$2[1]!
              as String;
      // The first attempt reached the server before the connection dropped.
      app.portfolios.firstAnswers[attempt] = OwnerAbroad.abroad;
      app.portfolios.gate.failure = null;
      await _answer(tester, _inPakistan);
      await _create(tester);
      expect(
        find.text(
          'Khan family is ready, with the answer from your first try: '
          'Abroad. You can change it in Portfolio details.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('waits while the portfolio is created', (tester) async {
      final app = TestApp(portfolios: const []);
      app.portfolios.gate.close();
      await pumpScreen(tester, CreatePortfolioScreen.new, app: app);
      await _name(tester, 'Khan family');
      await _answer(tester, _abroad);
      await tester.tap(find.widgetWithText(MmButton, 'Create portfolio'));
      await tester.pump();
      expect(
        tester
            .widget<MmRadioGroup<OwnerAbroad>>(
              find.byType(MmRadioGroup<OwnerAbroad>),
            )
            .onChanged,
        isNull,
      );
      app.portfolios.gate.open();
      await tester.pumpAndSettle();
      expect(routeShown(Routes.home), findsOneWidget);
    });
  });

  group('the More screen and the switcher', () {
    testWidgets('shows the current portfolio and the role', (tester) async {
      await pumpScreen(tester, MoreScreen.new);
      expect(find.text('Gulberg Houses'), findsOneWidget);
      expect(find.text('Your role: Owner'), findsOneWidget);
      expect(find.byType(MmNameplate), findsOneWidget);
      await tester.ensureVisible(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.settings), findsOneWidget);
    });

    testWidgets('leads to operations, the reports and search', (tester) async {
      for (final (title, route) in [
        ('Expenses', Routes.expenses),
        ('Utilities', Routes.utilities),
        ('Maintenance', Routes.maintenance),
        ('Reports and statements', Routes.reports),
        ('Search', Routes.search),
      ]) {
        await pumpScreen(tester, MoreScreen.new);
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(routeShown(route), findsOneWidget, reason: title);
      }
    });

    testWidgets('switches portfolios', (tester) async {
      final app = await pumpScreen(tester, MoreScreen.new);
      await tester.tap(find.text('Switch portfolio'));
      await tester.pumpAndSettle();
      final sheet = find.byType(PortfolioSwitcher);
      expect(
        find.descendant(of: sheet, matching: find.text('Manager')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Current portfolio')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('Saddar Plaza')),
      );
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.text('Your role: Manager'), findsOneWidget);
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/${plaza.id}',
      );
    });

    testWidgets('the switcher leads to a new portfolio', (tester) async {
      await pumpScreen(tester, MoreScreen.new);
      await tester.tap(find.text('Switch portfolio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New portfolio'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.createPortfolio), findsOneWidget);
    });

    testWidgets('offline, it says what it shows', (tester) async {
      final app = TestApp()..portfolios.listFailure = const NetworkFailure();
      await app.cache.write(testUserId, 'portfolios', [plaza.toRow()]);
      await pumpScreen(tester, MoreScreen.new, app: app);
      expect(find.textContaining('You are offline.'), findsOneWidget);
      expect(find.text('Saddar Plaza'), findsOneWidget);
      app.portfolios.listFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You are offline.'), findsNothing);
      expect(find.text('Gulberg Houses'), findsOneWidget);
    });

    testWidgets('other refresh failures say so, with a retry', (tester) async {
      final app = TestApp()..portfolios.listFailure = const Forbidden();
      await app.cache.write(testUserId, 'portfolios', [plaza.toRow()]);
      await pumpScreen(tester, MoreScreen.new, app: app);
      expect(
        find.text('You do not have permission to do this.'),
        findsOneWidget,
      );
    });

    testWidgets('every role has a word', (tester) async {
      await pumpScreen(tester, MoreScreen.new);
      final context = tester.element(find.byType(MoreScreen));
      final l10n = AppLocalizations.of(context);
      expect(
        [for (final role in MemberRole.values) roleLabel(l10n, role)],
        ['Owner', 'Manager', 'Accountant', 'Viewer'],
      );
    });
  });

  testEveryVariant('portfolio screens fit at 320 dp', (tester, variant) async {
    for (final screen in <Widget Function()>[
      CreatePortfolioScreen.new,
      MoreScreen.new,
    ]) {
      await pumpScreen(
        tester,
        screen,
        variant: variant,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull, reason: '$screen');
      await expectAccessible(tester);
    }
  });
}
