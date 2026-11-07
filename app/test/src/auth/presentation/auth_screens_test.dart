import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/auth/presentation/auth_callback_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/check_email_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/forgot_password_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/sign_in_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/sign_up_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/update_password_screen.dart';
import 'package:maalik_e_makaan/src/auth/presentation/welcome_screen.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../support/harness.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (widget) =>
      (widget is MmTextField && widget.label == label) ||
      (widget is MmPasswordField && widget.label == label),
);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(
    find.descendant(of: _field(label), matching: find.byType(TextField)),
    text,
  );
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(MmButton, label);
  await tester.ensureVisible(button.first);
  await tester.tap(button.first);
  await tester.pump();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

void main() {
  group('welcome', () {
    testWidgets('greets in both scripts and directions', (tester) async {
      await pumpScreen(
        tester,
        WelcomeScreen.new,
        app: TestApp(auth: const SignedOut(), language: null),
      );
      final english = find.text('Welcome to Maalik-e-Makaan');
      final urdu = find.text('مالکِ مکان میں خوش آمدید');
      expect(Directionality.of(tester.element(english)), TextDirection.ltr);
      expect(Directionality.of(tester.element(urdu)), TextDirection.rtl);
      expect(
        Theme.of(tester.element(urdu)).textTheme.headlineSmall!.fontFamily,
        contains('Nastaliq'),
      );
      expect(
        tester.getSemantics(urdu),
        matchesSemantics(label: 'مالکِ مکان میں خوش آمدید', isHeader: true),
      );
    });

    for (final (label, code) in [
      ('Continue in English', 'en'),
      ('اردو میں جاری رکھیں', 'ur'),
    ]) {
      testWidgets('"$label" keeps $code on the device', (tester) async {
        final app = await pumpScreen(
          tester,
          WelcomeScreen.new,
          app: TestApp(auth: const SignedOut(), language: null),
        );
        await _tapButton(tester, label);
        expect(app.settings.values[AppSettings.localeKey], code);
      });
    }
  });

  group('sign in', () {
    testWidgets('checks the fields before sending', (tester) async {
      final app = await pumpScreen(
        tester,
        SignInScreen.new,
        app: TestApp(auth: const SignedOut()),
      );
      await _tapButton(tester, 'Sign in');
      expect(shown('Enter this to continue.'), findsNWidgets(2));
      await _type(tester, 'E-mail', 'ayesha@');
      expect(
        shown('Enter an e-mail address like name@example.com.'),
        findsOneWidget,
      );
      expect(app.auth.calls, isEmpty);
    });

    testWidgets('signs in with the trimmed address and shows progress', (
      tester,
    ) async {
      final app = TestApp(auth: const SignedOut())..auth.gate.close();
      await pumpScreen(tester, SignInScreen.new, app: app);
      await _type(tester, 'E-mail', ' $testEmail ');
      await _type(tester, 'Password', 'Secret1234');
      await _tapButton(tester, 'Sign in');
      expect(
        tester.widget<MmButton>(find.widgetWithText(MmButton, 'Sign in')).busy,
        isTrue,
      );
      app.auth.gate.open();
      await tester.pumpAndSettle();
      expect(app.auth.calls.single.$2, [' $testEmail ', 'Secret1234']);
    });

    testWidgets('a refusal shows above the form until the fields change', (
      tester,
    ) async {
      final app = TestApp(auth: const SignedOut());
      app.auth.gate.failure = const RejectedFailure('invalid_credentials');
      await pumpScreen(tester, SignInScreen.new, app: app);
      await _type(tester, 'E-mail', testEmail);
      await _type(tester, 'Password', 'wrong');
      await _tapButton(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(find.text('The e-mail or password is not right.'), findsOneWidget);
      await _type(tester, 'Password', 'wrong2');
      expect(find.text('The e-mail or password is not right.'), findsNothing);
    });

    testWidgets('an address the server refuses is shown on its field', (
      tester,
    ) async {
      final app = TestApp(auth: const SignedOut());
      app.auth.gate.failure = const RejectedFailure('invalid_email');
      await pumpScreen(tester, SignInScreen.new, app: app);
      await _type(tester, 'E-mail', testEmail);
      await _type(tester, 'Password', 'Secret1234');
      await _tapButton(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(
        tester.widget<MmTextField>(_field('E-mail')).errorText,
        'Enter a valid e-mail address.',
      );
    });

    testWidgets('an unconfirmed address can have its e-mail sent again', (
      tester,
    ) async {
      final app = TestApp(auth: const SignedOut());
      app.auth.gate.failure = const RejectedFailure('email_not_confirmed');
      await pumpScreen(tester, SignInScreen.new, app: app);
      await _type(tester, 'E-mail', testEmail);
      await _type(tester, 'Password', 'Secret1234');
      await _tapButton(tester, 'Sign in');
      await tester.pumpAndSettle();
      app.auth.gate.failure = null;
      await tester.tap(find.text('Send the e-mail again'));
      await tester.pumpAndSettle();
      expect(app.auth.calls.last.$1, 'resendConfirmation');
      expect(app.auth.calls.last.$2, [testEmail]);
      expect(routeShown(Routes.checkEmail), findsOneWidget);
      expect(
        _container(tester).read(pendingEmailProvider),
        const PendingEmail(
          address: testEmail,
          purpose: EmailPurpose.confirmation,
        ),
      );
    });

    testWidgets('says when the account was deleted', (tester) async {
      await pumpScreen(
        tester,
        SignInScreen.new,
        app: TestApp(auth: const SignedOut(cause: SignOutCause.accountDeleted)),
      );
      expect(find.text('Your account has been deleted'), findsOneWidget);
    });

    testWidgets('leads to a new account and to a forgotten password', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        SignInScreen.new,
        app: TestApp(auth: const SignedOut()),
      );
      await _type(tester, 'E-mail', testEmail);
      await _tapButton(tester, 'Forgot password?');
      await tester.pumpAndSettle();
      expect(
        find.text('route:${Routes.forgotPassword} $testEmail'),
        findsOneWidget,
      );

      await pumpScreen(
        tester,
        SignInScreen.new,
        app: TestApp(auth: const SignedOut()),
      );
      await _tapButton(tester, 'Create account');
      await tester.pumpAndSettle();
      expect(routeShown(Routes.signUp), findsOneWidget);
    });
  });

  group('sign up', () {
    Future<TestApp> fill(WidgetTester tester, {TestApp? app}) async {
      final testApp = await pumpScreen(
        tester,
        SignUpScreen.new,
        app: app ?? TestApp(auth: const SignedOut(), language: 'ur'),
        variant: MmVariant.urdu,
      );
      await _type(tester, 'آپ کا نام', 'Ayesha Khan');
      await _type(tester, 'ای میل', testEmail);
      await _type(tester, 'پاس ورڈ', 'Secret1234');
      return testApp;
    }

    testWidgets('asks for a password the server accepts', (tester) async {
      final app = await pumpScreen(
        tester,
        SignUpScreen.new,
        app: TestApp(auth: const SignedOut()),
      );
      await _type(tester, 'Your name', 'Ayesha');
      await _type(tester, 'E-mail', testEmail);
      await _type(tester, 'Password', 'secret');
      await _tapButton(tester, 'Create account');
      expect(
        shown('Use at least 10 characters, with capital and small letters'),
        findsOneWidget,
      );
      expect(app.auth.calls, isEmpty);
    });

    testWidgets('then shows where the confirmation went', (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      final app = await fill(tester);
      await _tapButton(tester, 'اکاؤنٹ بنائیں');
      await tester.pumpAndSettle();
      expect(app.auth.calls.single.$2, [
        testEmail,
        'Secret1234',
        'Ayesha Khan',
        'ur',
      ]);
      expect(routeShown(Routes.checkEmail), findsOneWidget);
      expect(_container(tester).read(pendingEmailProvider)?.address, testEmail);
    });

    testWidgets('signed in at once, it leaves the move to the router', (
      tester,
    ) async {
      final app = TestApp(auth: const SignedOut(), language: 'ur')
        ..auth.signUpOutcome = SignUpOutcome.signedIn;
      await fill(tester, app: app);
      await _tapButton(tester, 'اکاؤنٹ بنائیں');
      await tester.pumpAndSettle();
      expect(routeShown(Routes.checkEmail), findsNothing);
      expect(app.auth.status, isA<SignedIn>());
    });

    testWidgets('a taken address and a weak password show on their fields', (
      tester,
    ) async {
      final app = TestApp(auth: const SignedOut());
      await pumpScreen(tester, SignUpScreen.new, app: app);
      await _type(tester, 'Your name', 'Ayesha');
      await _type(tester, 'E-mail', testEmail);
      await _type(tester, 'Password', 'Secret1234');
      app.auth.gate.failure = const RejectedFailure('email_taken');
      await _tapButton(tester, 'Create account');
      await tester.pumpAndSettle();
      expect(
        tester.widget<MmTextField>(_field('E-mail')).errorText,
        startsWith('An account with this e-mail already exists.'),
      );
      // A refusal on a field holds the form until the field changes.
      await _tapButton(tester, 'Create account');
      expect(app.auth.calls, hasLength(1));
      await _type(tester, 'E-mail', 'ayesha.k@example.com');
      app.auth.gate.failure = const RejectedFailure('weak_password');
      await _tapButton(tester, 'Create account');
      await tester.pumpAndSettle();
      expect(
        tester.widget<MmPasswordField>(_field('Password')).errorText,
        startsWith('Choose a stronger password'),
      );
      await _type(tester, 'Password', 'Secret12345');
      app.auth.gate.failure = const RateLimited(null);
      await _tapButton(tester, 'Create account');
      await tester.pumpAndSettle();
      expect(
        find.text('Too many attempts. Please wait a moment and try again.'),
        findsOneWidget,
      );
      await _tapButton(tester, 'Sign in');
      await tester.pumpAndSettle();
      expect(routeShown(Routes.signIn), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('starts from the address typed on sign-in', (tester) async {
      final app = await pumpScreen(
        tester,
        () => const ForgotPasswordScreen(initialEmail: ' $testEmail'),
        app: TestApp(auth: const SignedOut()),
      );
      await _tapButton(tester, 'Send reset link');
      await tester.pumpAndSettle();
      expect(app.auth.calls.single.$2, [testEmail]);
      expect(routeShown(Routes.checkEmail), findsOneWidget);
      expect(
        _container(tester).read(pendingEmailProvider)?.purpose,
        EmailPurpose.passwordReset,
      );
    });

    testWidgets('checks the address and shows refusals', (tester) async {
      final app = await pumpScreen(
        tester,
        ForgotPasswordScreen.new,
        app: TestApp(auth: const SignedOut()),
      );
      await _tapButton(tester, 'Send reset link');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await _type(tester, 'E-mail', testEmail);
      app.auth.gate.failure = const RejectedFailure('invalid_email');
      await _tapButton(tester, 'Send reset link');
      await tester.pumpAndSettle();
      expect(
        tester.widget<MmTextField>(_field('E-mail')).errorText,
        'Enter a valid e-mail address.',
      );
      await _type(tester, 'E-mail', 'ayesha.k@example.com');
      app.auth.gate.failure = const NetworkFailure();
      await _tapButton(tester, 'Send reset link');
      await tester.pumpAndSettle();
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tapButton(tester, 'Back to sign in');
      await tester.pumpAndSettle();
      expect(routeShown(Routes.signIn), findsOneWidget);
    });
  });

  group('check e-mail', () {
    Future<TestApp> pumpCheck(WidgetTester tester, PendingEmail? email) async {
      final app = await pumpScreen(
        tester,
        CheckEmailScreen.new,
        app: TestApp(auth: const SignedOut()),
      );
      if (email != null) {
        _container(tester).read(pendingEmailProvider.notifier).email = email;
        await tester.pump();
      }
      return app;
    }

    testWidgets('can send again once a minute has passed', (tester) async {
      final app = await pumpCheck(
        tester,
        const PendingEmail(
          address: testEmail,
          purpose: EmailPurpose.confirmation,
        ),
      );
      expect(find.textContaining(testEmail), findsOneWidget);
      final resend = find.widgetWithText(MmButton, 'Send the e-mail again');
      expect(tester.widget<MmButton>(resend).onPressed, isNull);
      expect(find.text('You can send it again in 60 seconds.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('You can send it again in 1 second.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<MmButton>(resend).onPressed, isNotNull);
      await tester.tap(resend);
      await tester.pump();
      expect(app.auth.calls.single.$1, 'resendConfirmation');
      expect(find.text('We sent the e-mail again.'), findsOneWidget);
      expect(tester.widget<MmButton>(resend).onPressed, isNull);
    });

    testWidgets('a reset e-mail is sent again as a reset', (tester) async {
      final app = await pumpCheck(
        tester,
        const PendingEmail(
          address: testEmail,
          purpose: EmailPurpose.passwordReset,
        ),
      );
      expect(find.textContaining('The link works once'), findsOneWidget);
      await tester.pump(CheckEmailScreen.resendInterval);
      app.auth.gate.failure = const RateLimited(Duration(seconds: 30));
      await tester.tap(find.text('Send the e-mail again'));
      await tester.pump();
      expect(app.auth.calls.single.$1, 'sendPasswordReset');
      expect(find.text('You can send it again in 30 seconds.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      app.auth.gate.failure = const NetworkFailure();
      await tester.tap(find.text('Send the e-mail again'));
      await tester.pump();
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      // A rate limit without a wait falls back to a minute.
      app.auth.gate.failure = const RateLimited(null);
      await tester.tap(find.text('Send the e-mail again'));
      await tester.pump();
      expect(find.text('You can send it again in 60 seconds.'), findsOneWidget);
    });

    testWidgets('without the address it explains and leads back', (
      tester,
    ) async {
      await pumpCheck(tester, null);
      expect(find.textContaining('We sent you a link.'), findsOneWidget);
      expect(find.text('Send the e-mail again'), findsNothing);
      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      expect(routeShown(Routes.signIn), findsOneWidget);
    });
  });

  group('choose a new password', () {
    testWidgets('both passwords must match and follow the rules', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        UpdatePasswordScreen.new,
        app: TestApp(auth: const RecoveringPassword(userId: testUserId)),
      );
      await _type(tester, 'New password', 'NewSecret12');
      await _type(tester, 'Type the new password again', 'NewSecret13');
      await _tapButton(tester, 'Save password');
      expect(shown('The passwords do not match.'), findsOneWidget);
      expect(app.auth.calls, isEmpty);
      app.auth.gate.failure = const RejectedFailure('same_password');
      await _type(tester, 'Type the new password again', 'NewSecret12');
      await _tapButton(tester, 'Save password');
      await tester.pumpAndSettle();
      expect(
        tester.widget<MmPasswordField>(_field('New password')).errorText,
        'Choose a password you have not used before.',
      );
      app.auth.gate.failure = const ReauthenticationRequired();
      await _type(tester, 'New password', 'NewSecret14');
      await _type(tester, 'Type the new password again', 'NewSecret14');
      await _tapButton(tester, 'Save password');
      await tester.pumpAndSettle();
      expect(
        find.text('For your safety, sign in again before doing this.'),
        findsOneWidget,
      );
    });

    testWidgets('can be abandoned by signing out', (tester) async {
      final app = await pumpScreen(
        tester,
        UpdatePasswordScreen.new,
        app: TestApp(auth: const RecoveringPassword(userId: testUserId)),
      );
      await tester.tap(find.text('Sign out'));
      await tester.pump();
      expect(app.auth.calls.single.$1, 'signOut');
    });
  });

  group('e-mail link', () {
    testWidgets('exchanges the code once and shows progress', (tester) async {
      final app = TestApp(auth: const SignedOut())..auth.gate.close();
      final link = Uri.parse('/auth/callback?code=abc');
      await pumpScreen(
        tester,
        () => AuthCallbackScreen(link: link),
        app: app,
        settle: false,
      );
      await tester.pump();
      expect(find.text('Signing you in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      app.auth.gate.open();
      await tester.pump();
      expect(app.auth.calls.single.$2, [link]);
    });

    for (final (reason, message) in [
      ('link_expired', 'This link has expired or was already used.'),
      ('link_other_device', 'Open the link on the phone or browser'),
    ]) {
      testWidgets('a $reason link says why and leads back', (tester) async {
        final app = TestApp(auth: const SignedOut());
        app.auth.gate.failure = RejectedFailure(reason);
        await pumpScreen(
          tester,
          () => AuthCallbackScreen(link: Uri.parse('/auth/callback?code=x')),
          app: app,
        );
        expect(find.text('This link did not work'), findsOneWidget);
        expect(find.textContaining(message), findsOneWidget);
        await tester.tap(find.text('Back to sign in'));
        await tester.pumpAndSettle();
        expect(routeShown(Routes.signIn), findsOneWidget);
      });
    }
  });

  testWidgets('the last field submits its form from the keyboard', (
    tester,
  ) async {
    Future<TestApp> submit(
      Widget Function() screen,
      List<(String, String)> fields, {
      AuthStatus auth = const SignedOut(),
    }) async {
      final app = await pumpScreen(tester, screen, app: TestApp(auth: auth));
      for (final (label, text) in fields) {
        await _type(tester, label, text);
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      return app;
    }

    var app = await submit(SignInScreen.new, [
      ('E-mail', testEmail),
      ('Password', 'Secret1234'),
    ]);
    expect(app.auth.calls.single.$1, 'signIn');
    app = await submit(SignUpScreen.new, [
      ('Your name', 'Ayesha'),
      ('E-mail', testEmail),
      ('Password', 'Secret1234'),
    ]);
    expect(app.auth.calls.single.$1, 'signUp');
    app = await submit(ForgotPasswordScreen.new, [('E-mail', testEmail)]);
    expect(app.auth.calls.single.$1, 'sendPasswordReset');
    app = await submit(UpdatePasswordScreen.new, [
      ('New password', 'NewSecret12'),
      ('Type the new password again', 'NewSecret12'),
    ], auth: const RecoveringPassword(userId: testUserId));
    expect(app.auth.calls.single.$1, 'updatePassword');
  });

  testEveryVariant('auth screens fit at 320 dp', (tester, variant) async {
    for (final screen in <Widget Function()>[
      WelcomeScreen.new,
      SignInScreen.new,
      SignUpScreen.new,
      ForgotPasswordScreen.new,
      CheckEmailScreen.new,
      UpdatePasswordScreen.new,
    ]) {
      await pumpScreen(
        tester,
        screen,
        app: TestApp(auth: const SignedOut()),
        variant: variant,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull, reason: '$screen');
    }
  });
}
