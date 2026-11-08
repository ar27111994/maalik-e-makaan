import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/handovers/presentation/cash_book_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

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

const _size = Size(360, 1800);

void main() {
  testWidgets('shows who holds cash and the handovers', (tester) async {
    await pumpScreen(tester, CashBookScreen.new, size: _size);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('Bilal Ahmed to Ayesha Khan'), findsNWidgets(3));
    expect(shown('To confirm'), findsOneWidget);
    expect(shown('Confirmed'), findsOneWidget);
  });

  testWidgets('the owner records a handover from the caretaker', (
    tester,
  ) async {
    final app = await pumpScreen(tester, CashBookScreen.new, size: _size);
    await _tap(tester, 'Record handover');
    await _tap(tester, 'Record handover');
    expect(shown('Choose who received the cash.'), findsOneWidget);
    await _select(tester, 'Handed over by', 'Bilal Ahmed');
    await _select(tester, 'Handed to', 'Ayesha Khan');
    final amount = find.descendant(
      of: find.byType(MmMoneyField),
      matching: find.byType(TextField),
    );
    await tester.enterText(amount, '40000');
    await _select(tester, 'Paid by', 'JazzCash');
    await _tap(tester, 'Record handover');
    final draft =
        app.handovers.calls.lastWhere((c) => c.$1 == 'record').$2.last!
            as HandoverDraft;
    expect(draft.fromUserId, caretakerId);
    expect(draft.toUserId, testUserId);
    expect(draft.amount, const Money.fromRupees(40000));
    expect(find.text('Handover recorded.'), findsOneWidget);
  });

  testWidgets('a manager records only their own handover, to the owner', (
    tester,
  ) async {
    final app = TestApp(
      portfolios: const [
        PortfolioMembership(
          id: '0192d0c4-0000-7000-8000-000000000001',
          name: 'Gulberg Houses',
          role: MemberRole.manager,
        ),
      ],
    );
    app.handovers.positions = [
      for (final p in app.handovers.positions)
        CashPosition(
          userId: p.userId == testUserId ? caretakerId : testUserId,
          fullName: p.fullName,
          role: p.role,
          collected: p.collected,
          handedOver: p.handedOver,
          spent: p.spent,
          inHand: p.inHand,
        ),
    ];
    await pumpScreen(tester, CashBookScreen.new, app: app, size: _size);
    await _tap(tester, 'Record handover');
    expect(find.text('Handed over by'), findsOneWidget);
    final amount = find.descendant(
      of: find.byType(MmMoneyField),
      matching: find.byType(TextField),
    );
    await tester.enterText(amount, '1000');
    await _tap(tester, 'Record handover');
    final draft =
        app.handovers.calls.lastWhere((c) => c.$1 == 'record').$2.last!
            as HandoverDraft;
    expect(draft.fromUserId, testUserId);
    expect(draft.toUserId, caretakerId);
    // Only owners confirm.
    await tester.tap(find.text('Bilal Ahmed to Ayesha Khan').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm I received it'), findsNothing);
  });

  testWidgets('the owner confirms and voids handovers', (tester) async {
    final app = await pumpScreen(tester, CashBookScreen.new, size: _size);
    await _tap(tester, 'Bilal Ahmed to Ayesha Khan');
    app.handovers.writeFailures.add(const RejectedFailure('already_voided'));
    await tester.tap(find.text('Bilal Ahmed to Ayesha Khan').first);
    await tester.pumpAndSettle();
    await _tap(tester, 'Confirm I received it');
    expect(shown('This entry was already voided.'), findsOneWidget);
    await _tap(tester, 'Confirm I received it');
    expect(find.text('Handover confirmed.'), findsOneWidget);
    await tester.tap(find.text('Bilal Ahmed to Ayesha Khan').at(1));
    await tester.pumpAndSettle();
    await _tap(tester, 'Void handover');
    await tester.enterText(
      find.descendant(
        of: find.byType(MmTextField),
        matching: find.byType(TextField),
      ),
      'Counted twice',
    );
    await _tap(tester, 'Void handover');
    expect(app.handovers.calls.lastWhere((c) => c.$1 == 'voidHandover').$2, [
      'ho-1',
      'Counted twice',
    ]);
    expect(find.text('Handover voided.'), findsOneWidget);
  });

  testWidgets('pages load on', (tester) async {
    final app = TestApp()..handovers.pageLimit = 1;
    await pumpScreen(tester, CashBookScreen.new, app: app, size: _size);
    await _tap(tester, 'Show more');
    expect(find.text('Bilal Ahmed to Ayesha Khan'), findsNWidgets(2));
  });

  testWidgets('nobody holding cash says so', (tester) async {
    final empty = TestApp()
      ..handovers.positions = []
      ..handovers.handoverList.clear();
    await pumpScreen(tester, CashBookScreen.new, app: empty);
    expect(find.text('No cash has been collected yet.'), findsOneWidget);
    expect(find.text('No cash has been handed over yet.'), findsOneWidget);
  });

  testWidgets('viewers read only', (tester) async {
    await pumpScreen(
      tester,
      CashBookScreen.new,
      app: TestApp(portfolios: const [gulbergAsViewer]),
    );
    expect(find.text('Record handover'), findsNothing);
  });

  testWidgets('a failure says why', (tester) async {
    final app = TestApp()..handovers.readFailure = const ServerFailure('x');
    await pumpScreen(tester, CashBookScreen.new, app: app);
    expect(find.text('The cash in hand could not be loaded'), findsOneWidget);
  });

  testWidgets("a former member's name is said as such", (tester) async {
    final gone = TestApp()
      ..handovers.positions = [
        const CashPosition(
          userId: caretakerId,
          fullName: '',
          role: MemberRole.accountant,
          collected: Money.fromRupees(1),
          handedOver: Money.zero,
          spent: Money.zero,
          inHand: Money.fromRupees(1),
        ),
      ];
    await pumpScreen(tester, CashBookScreen.new, app: gone);
    expect(find.text('A former member'), findsWidgets);
  });
}
