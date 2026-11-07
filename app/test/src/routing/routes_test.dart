import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';

const _signedIn = SignedIn(userId: 'u1', email: 'ali@example.com');
const _signedOut = SignedOut();
const _recovering = RecoveringPassword(userId: 'u1');

String? _go(
  String location,
  AuthStatus auth, {
  bool languageChosen = true,
  PortfolioGate portfolios = PortfolioGate.some,
}) => redirectFor(
  location: Uri.parse(location),
  languageChosen: languageChosen,
  auth: auth,
  portfolios: portfolios,
);

void main() {
  test('everything waits for a language, remembering the destination', () {
    expect(_go('/', _signedIn, languageChosen: false), '/welcome');
    expect(
      _go('/money', _signedOut, languageChosen: false),
      '/welcome?from=%2Fmoney',
    );
    expect(_go('/welcome', _signedOut, languageChosen: false), isNull);
  });

  test('after the language the welcome screen moves on', () {
    expect(_go('/welcome', _signedIn), '/');
    expect(_go('/welcome?from=/money', _signedIn), '/money');
    expect(_go('/welcome?from=/money', _signedOut), '/money');
  });

  test('signed-out users reach only the public screens', () {
    for (final path in Routes.public) {
      expect(_go(path, _signedOut), isNull, reason: path);
    }
    expect(_go('/', _signedOut), '/sign-in');
    expect(_go('/tenants', _signedOut), '/sign-in?from=%2Ftenants');
    expect(
      _go('/update-password', _signedOut),
      '/sign-in?from=%2Fupdate-password',
    );
  });

  test('signed-in users skip the sign-in screens, back to where they were', () {
    for (final path in [...Routes.signedOutOnly, Routes.authCallback]) {
      expect(_go(path, _signedIn), '/', reason: path);
    }
    expect(_go('/sign-in?from=/tenants', _signedIn), '/tenants');
    expect(_go('/money', _signedIn), isNull);
    expect(_go('/update-password', _signedIn), '/');
  });

  test('a password reset leads only to choosing a new password', () {
    expect(_go('/', _recovering), '/update-password');
    expect(_go('/sign-in', _recovering), '/update-password');
    expect(_go('/update-password', _recovering), isNull);
  });

  test('only in-app destinations are remembered', () {
    // Open-redirect attempts and loops back to the sign-in screens are dropped.
    expect(_go('/sign-in?from=https://evil.example', _signedIn), '/');
    expect(_go('/sign-in?from=//evil.example', _signedIn), '/');
    expect(_go('/sign-in?from=money', _signedIn), '/');
    expect(_go('/sign-in?from=/sign-up', _signedIn), '/');
    expect(_go('/sign-in?from=/welcome', _signedIn), '/');
    // A query of the remembered destination survives.
    expect(_go('/sign-in?from=/money?tab=dues', _signedIn), '/money?tab=dues');
  });

  test('after signing out on purpose, nothing is remembered', () {
    for (final cause in SignOutCause.values) {
      final signedOut = SignedOut(cause: cause);
      expect(_go('/more/settings', signedOut), '/sign-in', reason: '$cause');
      expect(_go('/sign-in', signedOut), isNull);
    }
  });

  test('a user without a portfolio creates one first', () {
    const none = PortfolioGate.none;
    expect(_go('/', _signedIn, portfolios: none), '/portfolios/new');
    expect(_go('/tenants', _signedIn, portfolios: none), '/portfolios/new');
    expect(_go('/portfolios/new', _signedIn, portfolios: none), isNull);
    // Settings stay open: the language, signing out, deleting the account.
    expect(_go('/more/settings', _signedIn, portfolios: none), isNull);
    expect(
      _go('/more/settings/delete-account', _signedIn, portfolios: none),
      isNull,
    );
    expect(_go('/more', _signedIn, portfolios: none), '/portfolios/new');
    expect(
      _go('/more/settingsx', _signedIn, portfolios: none),
      '/portfolios/new',
    );
  });

  test('while portfolios load, and with one, nothing is forced', () {
    for (final gate in [PortfolioGate.unknown, PortfolioGate.some]) {
      expect(_go('/', _signedIn, portfolios: gate), isNull);
      expect(_go('/portfolios/new', _signedIn, portfolios: gate), isNull);
    }
  });
}
