@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
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
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/account/presentation/delete_account_screen.dart';
import 'package:maalik_e_makaan/src/features/account/presentation/residence_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/create_portfolio_screen.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:maalik_e_makaan/src/settings/presentation/settings_screen.dart';
import 'package:maalik_e_makaan/src/shell/more_screen.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

TestApp _signedOut() => TestApp(auth: const SignedOut());

/// A taller window for the 200% text variant, where a screen needs it.
Map<MmVariant, Size> _large(double height) => {
  MmVariant.largeText: Size(360, height),
};

void main() {
  screenGoldenEveryVariant(
    'welcome',
    WelcomeScreen.new,
    app: () => TestApp(auth: const SignedOut(), language: null),
    sizes: _large(1800),
  );

  screenGoldenEveryVariant(
    'sign_in',
    SignInScreen.new,
    app: () =>
        TestApp(auth: const SignedOut(cause: SignOutCause.accountDeleted)),
    size: const Size(360, 900),
    sizes: _large(1500),
  );

  screenGoldenEveryVariant(
    'sign_up_errors',
    SignUpScreen.new,
    app: _signedOut,
    size: const Size(360, 1000),
    sizes: _large(1500),
    act: (tester) async {
      // Submitting the empty form shows every field's error.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'forgot_password',
    ForgotPasswordScreen.new,
    app: _signedOut,
    sizes: _large(1300),
  );

  screenGoldenEveryVariant(
    'check_email',
    CheckEmailScreen.new,
    app: _signedOut,
    sizes: _large(1400),
    act: (tester) async {
      ProviderScope.containerOf(tester.element(find.byType(CheckEmailScreen)))
          .read(pendingEmailProvider.notifier)
          .email = const PendingEmail(
        address: testEmail,
        purpose: EmailPurpose.passwordReset,
      );
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'update_password',
    UpdatePasswordScreen.new,
    app: () => TestApp(auth: const RecoveringPassword(userId: testUserId)),
    size: const Size(360, 800),
    sizes: _large(1500),
  );

  screenGoldenEveryVariant(
    'auth_callback_expired',
    () => AuthCallbackScreen(link: Uri.parse('/auth/callback?code=x')),
    app: () =>
        _signedOut()..auth.gate.failure = const RejectedFailure('link_expired'),
    sizes: _large(1000),
  );

  screenGoldenEveryVariant(
    'create_portfolio_first',
    CreatePortfolioScreen.new,
    app: () => TestApp(portfolios: const []),
    size: const Size(360, 900),
    sizes: _large(1900),
  );

  // Created empty: the name and the owner-abroad question ask for answers.
  screenGoldenEveryVariant(
    'create_portfolio_errors',
    CreatePortfolioScreen.new,
    app: () => TestApp(portfolios: const []),
    size: const Size(360, 900),
    sizes: _large(2000),
    act: (tester) => _tapFirst(tester, find.byType(FilledButton)),
  );

  screenGoldenEveryVariant(
    'more',
    MoreScreen.new,
    size: const Size(360, 1190),
    sizes: {
      MmVariant.largeText: const Size(360, 2510),
      MmVariant.urdu: const Size(360, 1590),
    },
  );

  screenGoldenEveryVariant(
    'portfolio_switcher',
    MoreScreen.new,
    act: (tester) async {
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
    },
    sizes: _large(1100),
  );

  screenGoldenEveryVariant(
    'settings',
    SettingsScreen.new,
    size: const Size(360, 1800),
    sizes: {..._large(3700), MmVariant.urdu: const Size(360, 2250)},
  );

  // Where the user lives (D-16): only theirs, in Settings.
  screenGoldenEveryVariant(
    'settings_residence_abroad',
    SettingsScreen.new,
    app: () => TestApp(residence: residentInLondon),
    size: const Size(360, 900),
    sizes: _large(1900),
  );

  // "Do you live in Pakistan?", asked once, with nothing chosen.
  screenGoldenEveryVariant(
    'residence_question',
    ResidenceScreen.new,
    app: () => TestApp(residence: AccountResidence.notStated),
    size: const Size(360, 800),
    sizes: _large(1500),
  );

  // Abroad, the United Kingdom chosen: the device's London is offered,
  // never chosen for the person.
  screenGoldenEveryVariant(
    'residence_abroad',
    ResidenceScreen.new,
    app: () => TestApp(
      residence: AccountResidence.notStated,
      device: const FakeDeviceTimeZone(
        ianaName: 'Europe/London',
        offset: Duration.zero,
      ),
    ),
    size: const Size(360, 1100),
    sizes: _large(2200),
    act: _chooseAbroadInTheUk,
  );

  // Abroad, saved at once: the country and the zone ask to be chosen.
  screenGoldenEveryVariant(
    'residence_errors',
    ResidenceScreen.new,
    app: () => TestApp(residence: AccountResidence.notStated),
    size: const Size(360, 1100),
    sizes: _large(2200),
    act: (tester) async {
      await _tapFirst(
        tester,
        find.byType(RadioListTile<ResidenceAnswer>).at(1),
      );
      await _tapFirst(tester, find.byType(FilledButton));
      await tester.scrollUntilVisible(
        find.byType(MmSelectField<TimeZoneId>),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'delete_account',
    DeleteAccountScreen.new,
    size: const Size(360, 1300),
    sizes: _large(2800),
  );

  // The adaptive frame, through the real app: its router, the portfolio
  // gate and the bottom bar or rail.
  testEveryVariant('shell golden', (tester, variant) async {
    await _pumpShell(tester, variant, const Size(360, 740));
    await expectAccessible(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell_${variant.name}.png'),
    );
  });

  testWidgets('shell golden (wide)', (tester) async {
    await _pumpShell(tester, MmVariant.light, const Size(1024, 640));
    await expectAccessible(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/shell_wide.png'),
    );
  });
}

/// The whole app on its dashboard, set up as [variant] through the
/// device's settings and text scale.
Future<void> _pumpShell(
  WidgetTester tester,
  MmVariant variant,
  Size size,
) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final app = TestApp(
    language: variant.locale.languageCode,
    settings: {
      AppSettings.themeKey: variant.brightness == Brightness.dark
          ? 'dark'
          : 'light',
      AppSettings.highContrastKey: variant.highContrast,
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: app.overrides,
      retry: (_, _) => null,
      child: const MaalikApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapFirst(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Answers "No, in another country" and chooses the United Kingdom, in
/// either language (it is found by its code).
Future<void> _chooseAbroadInTheUk(WidgetTester tester) async {
  await _tapFirst(tester, find.byType(RadioListTile<ResidenceAnswer>).at(1));
  await _tapFirst(tester, find.byType(MmSelectField<CountryCode>));
  final sheet = find.byType(BottomSheet);
  await tester.enterText(
    find.descendant(of: sheet, matching: find.byType(TextField)),
    'GB',
  );
  await tester.pumpAndSettle();
  await _tapFirst(
    tester,
    find.descendant(
      of: sheet,
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'United Kingdom' || w.data == 'برطانیہ'),
      ),
    ),
  );
}
