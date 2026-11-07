import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/presentation/delete_account_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

const _tall = Size(390, 2000);

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) =>
        (w is MmTextField && w.label == label) ||
        (w is MmPasswordField && w.label == label),
  ),
  matching: find.byType(TextField),
);

Finder get _deleteButton => find.widgetWithText(MmButton, 'Delete my account');

Future<void> _fill(WidgetTester tester, {String email = testEmail}) async {
  await tester.enterText(_field('Password'), 'Secret1234');
  await tester.enterText(_field('Type $testEmail to confirm'), email);
  await tester.pump();
}

void main() {
  testWidgets('explains exactly what goes', (tester) async {
    await pumpScreen(tester, DeleteAccountScreen.new, size: _tall);
    expect(find.text('This cannot be undone'), findsOneWidget);
    expect(
      find.textContaining('You are the only owner of these 2 portfolios'),
      findsOneWidget,
    );
    expect(find.text('Gulberg Houses'), findsOneWidget);
    expect(find.text('2 other people lose access'), findsOneWidget);
    expect(find.text('Model Town Flats'), findsOneWidget);
    expect(find.text('Only you use it'), findsOneWidget);
    expect(
      find.textContaining('removed from every other portfolio'),
      findsOneWidget,
    );
    expect(find.textContaining('the last 10 minutes'), findsOneWidget);
  });

  testWidgets('with no portfolio of its own, none is deleted', (tester) async {
    await pumpScreen(
      tester,
      DeleteAccountScreen.new,
      size: _tall,
      app: TestApp(
        preview: const DeletionPreview(
          portfoliosToDelete: [
            DoomedPortfolio(id: 'p', name: 'Solo', otherMembers: 1),
          ],
          reauthMaxAge: Duration(minutes: 1),
          secondFactorRequired: false,
        ),
      ),
    );
    expect(
      find.textContaining('the only owner of this portfolio'),
      findsOneWidget,
    );
    expect(find.text('1 other person loses access'), findsOneWidget);
    expect(find.textContaining('the last minute'), findsOneWidget);

    await pumpScreen(
      tester,
      DeleteAccountScreen.new,
      size: _tall,
      app: TestApp(
        preview: const DeletionPreview(
          portfoliosToDelete: [],
          reauthMaxAge: Duration(minutes: 10),
          secondFactorRequired: false,
        ),
      ),
    );
    expect(find.textContaining('no portfolio is deleted'), findsOneWidget);
  });

  testWidgets('the button waits for the typed address', (tester) async {
    final app = await pumpScreen(tester, DeleteAccountScreen.new, size: _tall);
    expect(tester.widget<MmButton>(_deleteButton).onPressed, isNull);
    await _fill(tester, email: 'someone@example.com');
    expect(tester.widget<MmButton>(_deleteButton).onPressed, isNull);
    // Case and surrounding spaces do not matter.
    await _fill(tester, email: ' AYESHA.KHAN@example.com ');
    expect(tester.widget<MmButton>(_deleteButton).onPressed, isNotNull);
    await tester.enterText(_field('Password'), '');
    await tester.ensureVisible(_deleteButton);
    await tester.tap(_deleteButton);
    await tester.pump();
    expect(shown('Enter this to continue.'), findsOneWidget);
    expect(app.auth.calls, isEmpty);
  });

  testWidgets('signs in again, deletes, and signs out', (tester) async {
    final app = TestApp()..auth.gate.close();
    await pumpScreen(tester, DeleteAccountScreen.new, app: app, size: _tall);
    await _fill(tester);
    await tester.ensureVisible(_deleteButton);
    await tester.tap(_deleteButton);
    await tester.pump();
    expect(tester.widget<MmButton>(_deleteButton).busy, isTrue);
    app.auth.gate.open();
    // Signed out, the screen waits for the router to leave it (a placeholder
    // pulses), so pump frames rather than settle.
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump();
    }
    expect(app.auth.calls.first.$2, ['Secret1234']);
    expect(app.account.calls.last.$2, [testEmail]);
    expect(app.auth.calls.last.$2, [SignOutCause.accountDeleted]);
  });

  testWidgets('a wrong password or address shows on its field', (tester) async {
    final app = await pumpScreen(tester, DeleteAccountScreen.new, size: _tall);
    app.auth.gate.failure = const RejectedFailure('invalid_credentials');
    await _fill(tester);
    await tester.ensureVisible(_deleteButton);
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MmPasswordField>(find.byType(MmPasswordField)).errorText,
      'The e-mail or password is not right.',
    );
    await tester.enterText(_field('Password'), 'Secret12345');
    await tester.pump();
    app.auth.gate.failure = const ReauthenticationRequired();
    await tester.tap(_deleteButton);
    await tester.pumpAndSettle();
    expect(
      find.text('For your safety, sign in again before doing this.'),
      findsOneWidget,
    );
  });

  testWidgets('cancel returns to Settings', (tester) async {
    await pumpScreen(tester, DeleteAccountScreen.new, size: _tall);
    await tester.tap(find.widgetWithText(MmButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(routeShown(Routes.settings), findsOneWidget);
  });

  testWidgets('an account with a second factor cannot be deleted here', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      DeleteAccountScreen.new,
      size: _tall,
      app: TestApp(
        preview: const DeletionPreview(
          portfoliosToDelete: [],
          reauthMaxAge: Duration(minutes: 10),
          secondFactorRequired: true,
        ),
      ),
    );
    expect(find.textContaining('second sign-in step'), findsOneWidget);
    expect(find.byType(MmPasswordField), findsNothing);
    expect(tester.widget<MmButton>(_deleteButton).onPressed, isNull);
  });

  testWidgets('a preview that fails offers a retry', (tester) async {
    final app = TestApp()..account.previewFailure = const NetworkFailure();
    await pumpScreen(tester, DeleteAccountScreen.new, app: app);
    expect(
      find.text('We could not check what would be deleted'),
      findsOneWidget,
    );
    app.account.previewFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('This cannot be undone'), findsOneWidget);
  });

  testWidgets('while the preview loads, a placeholder says so', (tester) async {
    final app = TestApp()..account.gate.close();
    await pumpScreen(tester, DeleteAccountScreen.new, app: app, settle: false);
    await tester.pump();
    expect(
      find.bySemanticsLabel('Checking what would be deleted'),
      findsOneWidget,
    );
    app.account.gate.open();
  });

  testEveryVariant('fits at 320 dp and meets the guidelines', (
    tester,
    variant,
  ) async {
    await pumpScreen(
      tester,
      DeleteAccountScreen.new,
      variant: variant,
      size: Size(320, variant == MmVariant.largeText ? 4000 : 2000),
    );
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });
}
