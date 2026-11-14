import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/owner_abroad_question.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_details_screen.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _tall = Size(390, 2600);
const _abroad = 'Yes, the owner lives abroad';
const _inPakistan = 'No, the owner lives in Pakistan';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text));

/// The details screen for [app], in [portfolio].
Future<TestApp> _details(
  WidgetTester tester,
  TestApp app, {
  PortfolioMembership? portfolio,
}) async {
  if (portfolio != null) {
    await app.settings.setString(
      AppSettings.currentPortfolioKey,
      '$testUserId/${portfolio.id}',
    );
  }
  return await pumpScreen(
    tester,
    PortfolioDetailsScreen.new,
    app: app,
    size: _tall,
  );
}

/// [app] with [id]'s owner-abroad answer stored as [answer].
TestApp _withAnswer(TestApp app, String id, OwnerAbroad answer) {
  app.portfolios.details_[id] = withSettings(
    app.portfolios.details_[id]!,
    ownerAbroad: answer,
  );
  return app;
}

List<String> _calls(TestApp app) => [
  for (final call in app.portfolios.calls) call.$1,
];

void main() {
  group('where the owner lives', () {
    testWidgets('owners change a given answer, starting from it', (
      tester,
    ) async {
      final app = await _details(tester, TestApp());
      expect(find.text('Owner and caretaker'), findsOneWidget);
      expect(find.text('In Pakistan'), findsOneWidget);
      await _tapText(tester, 'Change the answer');
      final group = find.byType(MmRadioGroup<OwnerAbroad>);
      expect(
        tester.widget<MmRadioGroup<OwnerAbroad>>(group).value,
        OwnerAbroad.inPakistan,
      );
      final save = find.widgetWithText(MmButton, 'Save answer');
      expect(tester.widget<MmButton>(save).onPressed, isNull);
      await _tapText(tester, _abroad);
      await _tap(tester, save);
      expect(
        app.portfolios.calls.any((c) => c.$1 == 'changeOwnerAbroad'),
        isTrue,
      );
      expect(
        app.portfolios.calls.lastWhere((c) => c.$1 == 'changeOwnerAbroad').$2,
        [gulberg.id, true],
      );
      expect(find.text('Answer changed.'), findsOneWidget);
      expect(find.text('Abroad'), findsOneWidget);
    });

    testWidgets('a refused change stays in the sheet', (tester) async {
      final app = await _details(tester, TestApp());
      await _tapText(tester, 'Change the answer');
      await _tapText(tester, _abroad);
      app.portfolios.ownerAbroadFailure = const Forbidden();
      await _tap(tester, find.widgetWithText(MmButton, 'Save answer'));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(shown('You do not have permission'), findsWidgets);
    });

    testWidgets('owners answer a question nobody has answered', (tester) async {
      final app = _withAnswer(
        TestApp(portfolios: const [gulbergUnanswered, plaza]),
        gulberg.id,
        OwnerAbroad.notAnswered,
      );
      await _details(tester, app);
      expect(find.text('Not answered yet'), findsOneWidget);
      expect(find.text('Change the answer'), findsNothing);
      await _tapText(tester, 'Answer the question');
      await _tapText(tester, _abroad);
      await _tapText(tester, 'Save answer');
      expect(_calls(app), contains('answerOwnerAbroad'));
      expect(_calls(app), isNot(contains('changeOwnerAbroad')));
      // The details are read again: the answer shows at once.
      expect(find.text('Abroad'), findsOneWidget);
      expect(find.text('Change the answer'), findsOneWidget);
    });

    testWidgets('a manager cannot change a given answer', (tester) async {
      final app = await _details(tester, TestApp(), portfolio: plaza);
      expect(find.text('Abroad'), findsOneWidget);
      expect(find.text('Only an owner can change this answer.'), findsOne);
      expect(find.text('Change the answer'), findsNothing);
      expect(find.text('Answer the question'), findsNothing);
      expect(find.byType(MmRadioGroup<OwnerAbroad>), findsNothing);
      expect(_calls(app), isNot(contains('changeOwnerAbroad')));
    });

    testWidgets('a manager who answers late sees the answer that won', (
      tester,
    ) async {
      final app = _withAnswer(
        TestApp(portfolios: const [gulberg, plazaUnanswered]),
        plaza.id,
        OwnerAbroad.notAnswered,
      );
      await _details(tester, app, portfolio: plaza);
      expect(find.text('Not answered yet'), findsOneWidget);
      // An owner answered on another device after this screen was read.
      final index = app.portfolios.memberships.indexWhere(
        (m) => m.id == plaza.id,
      );
      app.portfolios.memberships[index] = plazaUnanswered.withOwnerAbroad(
        OwnerAbroad.inPakistan,
      );
      _withAnswer(app, plaza.id, OwnerAbroad.inPakistan);
      await _tapText(tester, 'Answer the question');
      await _tapText(tester, _abroad);
      await _tapText(tester, 'Save answer');
      expect(find.text('Someone answered first'), findsOneWidget);
      expect(
        find.text(
          'Another member already answered. They said the owner lives in '
          'Pakistan.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Only an owner can change this answer.'),
        ),
        findsOneWidget,
      );
      expect(_calls(app), isNot(contains('changeOwnerAbroad')));
      await _tapText(tester, 'Done');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('In Pakistan'), findsOneWidget);
    });

    testWidgets('accountants and viewers only read it', (tester) async {
      for (final role in [MemberRole.accountant, MemberRole.viewer]) {
        final app = _withAnswer(
          TestApp(
            portfolios: [
              PortfolioMembership(
                id: gulberg.id,
                name: gulberg.name,
                role: role,
              ),
            ],
          ),
          gulberg.id,
          OwnerAbroad.notAnswered,
        );
        await _details(tester, app);
        expect(find.text('Not answered yet'), findsOneWidget, reason: '$role');
        expect(find.text('Answer the question'), findsNothing);
        expect(find.text('Change the answer'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('the caretaker', () {
    testWidgets('owners choose a manager, and see since when', (tester) async {
      final app = await _details(tester, TestApp());
      expect(
        find.textContaining('A caretaker is a manager who looks after'),
        findsOneWidget,
      );
      expect(find.text('No caretaker'), findsOneWidget);
      await _tapText(tester, 'Choose the caretaker');
      // Managers only, and none.
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Ayesha Khan'),
        ),
        findsNothing,
      );
      expect(find.text('sara@example.com'), findsNothing);
      final save = find.widgetWithText(MmButton, 'Save caretaker');
      expect(tester.widget<MmButton>(save).onPressed, isNull);
      await _tapText(tester, 'Bilal Ahmed');
      await _tap(tester, save);
      expect(app.team.calls.last.$1, 'setCaretaker');
      expect(app.team.calls.last.$2, [gulberg.id, bilalMember.userId]);
      expect(find.text('Bilal Ahmed is now the caretaker.'), findsOneWidget);
      expect(find.text('Caretaker since'), findsOneWidget);
      // Named at 11:00 on 3 November in Pakistan.
      expect(find.text('3 Nov 2026'), findsOneWidget);
      expect(find.text('Change the caretaker'), findsOneWidget);
    });

    testWidgets('owners clear the caretaker', (tester) async {
      final app = TestApp();
      app.portfolios.setCaretakerOf(
        gulberg.id,
        bilalMember.userId,
        DateTime.utc(2026, 11, 1, 20),
      );
      await _details(tester, app);
      // 1 November 20:00 UTC is 2 November in Pakistan.
      expect(find.text('2 Nov 2026'), findsOneWidget);
      await _tapText(tester, 'Change the caretaker');
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('No caretaker'),
        ),
      );
      await _tapText(tester, 'Save caretaker');
      expect(app.team.calls.last.$2, [gulberg.id, null]);
      expect(find.text('There is no caretaker now.'), findsOneWidget);
      expect(find.text('Caretaker since'), findsNothing);
    });

    testWidgets('managers are listed by name', (tester) async {
      final app = TestApp();
      app.team.people[gulberg.id]!.add(
        TeamMember(
          userId: 'manager-without-a-name',
          role: MemberRole.manager,
          fullName: '',
          email: 'amna@example.com',
          joinedAt: DateTime.utc(2026, 3),
        ),
      );
      await _details(tester, app);
      await _tapText(tester, 'Choose the caretaker');
      final amna = tester.getTopLeft(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.textContaining('amna@'),
            )
            .first,
      );
      final bilal = tester.getTopLeft(find.text('Bilal Ahmed'));
      expect(amna.dy, lessThan(bilal.dy));
    });

    testWidgets('a team that cannot be read offers a retry', (tester) async {
      final app = TestApp();
      await _details(tester, app);
      app.team.readFailure = const ServerFailure('XX000');
      // The sheet reads the team afresh.
      ProviderScope.containerOf(
        tester.element(find.byType(PortfolioDetailsScreen)),
      ).invalidate(teamProvider(gulberg));
      await _tapText(tester, 'Choose the caretaker');
      expect(find.text('The team could not be loaded'), findsOneWidget);
      app.team.readFailure = null;
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Try again'),
        ),
      );
      expect(find.text('Bilal Ahmed'), findsOneWidget);
    });

    testWidgets('without a manager, the sheet leads to the team', (
      tester,
    ) async {
      final app = TestApp();
      app.team.people[gulberg.id]!.removeWhere(
        (m) => m.role == MemberRole.manager,
      );
      await _details(tester, app);
      await _tapText(tester, 'Choose the caretaker');
      expect(
        find.textContaining('This team has no manager yet.'),
        findsOneWidget,
      );
      await _tapText(tester, 'Open the team');
      expect(routeShown(Routes.team), findsOneWidget);
    });

    testWidgets('refusals are explained and the team read again', (
      tester,
    ) async {
      for (final (failure, message) in [
        (
          const RejectedFailure('caretaker_not_manager'),
          'Only a manager can be the caretaker.',
        ),
        (const RejectedFailure('member_not_found'), null),
      ]) {
        final app = await _details(tester, TestApp());
        await _tapText(tester, 'Choose the caretaker');
        await _tapText(tester, 'Bilal Ahmed');
        app.team.gate.failure = failure;
        final reads = app.team.calls.where((c) => c.$1 == 'members').length;
        await _tapText(tester, 'Save caretaker');
        app.team.gate.failure = null;
        await tester.pumpAndSettle();
        if (message != null) expect(shown(message), findsWidgets);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(
          app.team.calls.where((c) => c.$1 == 'members').length,
          greaterThan(reads),
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a lost connection is said, and the team is not read again', (
      tester,
    ) async {
      final app = await _details(tester, TestApp());
      await _tapText(tester, 'Choose the caretaker');
      await _tapText(tester, 'Bilal Ahmed');
      app.team.gate.failure = const NetworkFailure();
      final reads = app.team.calls.where((c) => c.$1 == 'members').length;
      await _tapText(tester, 'Save caretaker');
      expect(shown('No connection'), findsOneWidget);
      expect(app.team.calls.where((c) => c.$1 == 'members').length, reads);
    });

    testWidgets('the caretaker sees it is them, and cannot step down', (
      tester,
    ) async {
      final app = TestApp();
      app.portfolios.setCaretakerOf(
        plaza.id,
        testUserId,
        DateTime.utc(2026, 11, 3, 6),
      );
      await _details(tester, app, portfolio: plaza);
      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(
        find.text(
          'You are the caretaker. To stop, ask an owner, or leave the team.',
        ),
        findsOneWidget,
      );
      expect(find.text('Change the caretaker'), findsNothing);
    });

    testWidgets('others see who it is, and that owners choose', (tester) async {
      final app = TestApp(portfolios: const [gulbergAsViewer]);
      app.portfolios.setCaretakerOf(
        gulberg.id,
        bilalMember.userId,
        DateTime.utc(2026, 11, 3, 6),
      );
      await _details(tester, app);
      expect(find.text('Bilal Ahmed'), findsOneWidget);
      expect(find.text('Only owners choose the caretaker.'), findsOneWidget);
      expect(find.text('Change the caretaker'), findsNothing);
    });

    testWidgets('while the team loads, the name waits; a stale team says so', (
      tester,
    ) async {
      final app = TestApp();
      app.portfolios.setCaretakerOf(
        gulberg.id,
        'someone-who-left',
        DateTime.utc(2026, 11, 3, 6),
      );
      app.team.gate.close();
      await pumpScreen(
        tester,
        PortfolioDetailsScreen.new,
        app: app,
        size: _tall,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Loading the team'), findsOneWidget);
      app.team.gate.open();
      await tester.pumpAndSettle();
      expect(find.text('A team member'), findsOneWidget);
    });
  });

  group('the question sheet', () {
    /// Opens the question for [membership] above a plain screen, and keeps
    /// what it closed with.
    Future<List<bool?>> open(
      WidgetTester tester,
      TestApp app,
      PortfolioMembership membership,
    ) async {
      final results = <bool?>[];
      await pumpScreen(
        tester,
        () => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showOwnerAbroadQuestion(context, membership),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        app: app,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('starts unanswered and asks for an answer', (tester) async {
      final app = TestApp(portfolios: const [gulbergUnanswered, plaza]);
      await open(tester, app, gulbergUnanswered);
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
        );
      }
      await _tapText(tester, 'Save answer');
      expect(shown('Choose an answer.'), findsOneWidget);
      expect(_calls(app), isNot(contains('answerOwnerAbroad')));
    });

    testWidgets('an owner who answered first is told they can change it', (
      tester,
    ) async {
      // The list says unanswered; the server already has an answer.
      final app = TestApp();
      await open(tester, app, gulbergUnanswered);
      await _tapText(tester, _abroad);
      await _tapText(tester, 'Save answer');
      expect(find.text('Someone answered first'), findsOneWidget);
      expect(
        find.text('You can change it later in Portfolio details.'),
        findsOneWidget,
      );
      expect(_calls(app), isNot(contains('changeOwnerAbroad')));
    });

    testWidgets('the answer that won is said whichever it was', (tester) async {
      // Someone said abroad first; this member says Pakistan.
      final app = TestApp(portfolios: [plaza]);
      await open(tester, app, plazaUnanswered);
      await _tapText(tester, _inPakistan);
      await _tapText(tester, 'Save answer');
      expect(
        find.text(
          'Another member already answered. They said the owner lives '
          'abroad.',
        ),
        findsOneWidget,
      );
      expect(find.text('Only an owner can change this answer.'), findsOne);
    });

    testWidgets('a lost connection keeps the answer', (tester) async {
      final app = TestApp(portfolios: const [gulbergUnanswered, plaza])
        ..portfolios.ownerAbroadFailure = const NetworkFailure();
      final results = await open(tester, app, gulbergUnanswered);
      await _tapText(tester, _inPakistan);
      await _tapText(tester, 'Save answer');
      expect(shown('No connection'), findsOneWidget);
      expect(
        tester
            .widget<MmRadioGroup<OwnerAbroad>>(
              find.byType(MmRadioGroup<OwnerAbroad>),
            )
            .value,
        OwnerAbroad.inPakistan,
      );
      // A new choice clears the message; the next save goes through.
      await _tapText(tester, _abroad);
      expect(shown('No connection'), findsNothing);
      app.portfolios.ownerAbroadFailure = null;
      await _tapText(tester, 'Save answer');
      expect(results, [true]);
    });

    testWidgets('a role that changed meanwhile reads the list again', (
      tester,
    ) async {
      final app = TestApp(portfolios: const [gulbergUnanswered, plaza])
        ..portfolios.ownerAbroadFailure = const Forbidden();
      await open(tester, app, gulbergUnanswered);
      final reads = _calls(app).where((c) => c == 'listMine').length;
      await _tapText(tester, _inPakistan);
      await _tapText(tester, 'Save answer');
      expect(shown('You do not have permission'), findsOneWidget);
      expect(
        _calls(app).where((c) => c == 'listMine').length,
        greaterThan(reads),
      );
      // A list that cannot be read changes nothing more.
      app.portfolios.listFailure = const NetworkFailure();
      await _tapText(tester, 'Save answer');
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('signed out, saving says the session ended', (tester) async {
      final app = TestApp(portfolios: const [gulbergUnanswered]);
      final results = await open(tester, app, gulbergUnanswered);
      app.auth.emit(const SignedOut());
      await tester.pumpAndSettle();
      await _tapText(tester, _inPakistan);
      await _tapText(tester, 'Save answer');
      expect(results, isEmpty);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('Not now closes without an answer', (tester) async {
      final app = TestApp(portfolios: const [gulbergUnanswered, plaza]);
      final results = await open(tester, app, gulbergUnanswered);
      await _tapText(tester, 'Not now');
      expect(results, [false]);
      expect(_calls(app), isNot(contains('answerOwnerAbroad')));
    });
  });
}
