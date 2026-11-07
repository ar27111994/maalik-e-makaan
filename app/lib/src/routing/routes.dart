import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';

/// Every path the app routes to.
abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const checkEmail = '/check-email';
  static const updatePassword = '/update-password';
  static const authCallback = '/auth/callback';

  static const createPortfolio = '/portfolios/new';

  static const home = '/';
  static const properties = '/properties';
  static const tenants = '/tenants';
  static const money = '/money';
  static const more = '/more';
  static const settings = '/more/settings';
  static const deleteAccount = '/more/settings/delete-account';

  /// Reachable without signing in.
  static const Set<String> public = {
    signIn,
    signUp,
    forgotPassword,
    checkEmail,
    authCallback,
  };

  /// Screens a signed-in user has no reason to see.
  static const Set<String> signedOutOnly = {
    signIn,
    signUp,
    forgotPassword,
    checkEmail,
  };
}

/// Where navigation to [location] must go instead, or null to allow it.
///
/// In order:
/// 1. a language is chosen before anything else (the first-launch screen);
/// 2. a password-reset link leads only to choosing a new password;
/// 3. signed-out users reach only the public screens, remembering where
///    they were going when their session ended by itself (not when they
///    signed out or deleted the account);
/// 4. signed-in users skip the sign-in screens;
/// 5. a signed-in user without a portfolio creates one first (Settings stay
///    open, to change the language or sign out).
String? redirectFor({
  required Uri location,
  required bool languageChosen,
  required AuthStatus auth,
  PortfolioGate portfolios = PortfolioGate.unknown,
}) {
  final path = location.path;
  if (!languageChosen) {
    return path == Routes.welcome ? null : _withFrom(Routes.welcome, location);
  }
  if (path == Routes.welcome) return _from(location) ?? Routes.home;

  switch (auth) {
    case RecoveringPassword():
      return path == Routes.updatePassword ? null : Routes.updatePassword;
    case SignedOut(:final cause):
      if (Routes.public.contains(path)) return null;
      return cause == null ? _withFrom(Routes.signIn, location) : Routes.signIn;
    case SignedIn():
      if (Routes.signedOutOnly.contains(path) || path == Routes.authCallback) {
        return _from(location) ?? Routes.home;
      }
      if (path == Routes.updatePassword) return Routes.home;
      final settings =
          path == Routes.settings || path.startsWith('${Routes.settings}/');
      if (portfolios == PortfolioGate.none &&
          path != Routes.createPortfolio &&
          !settings) {
        return Routes.createPortfolio;
      }
      return null;
  }
}

/// [target] remembering [location] in `from`, unless it is the home page.
String _withFrom(String target, Uri location) {
  final from =
      _from(location) ??
      (location.path == Routes.home ? null : location.toString());
  return from == null
      ? target
      : Uri(path: target, queryParameters: {'from': from}).toString();
}

/// The remembered destination, if it is an in-app path (never another site).
String? _from(Uri location) {
  final from = location.queryParameters['from'];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null || Routes.public.contains(path) || path == Routes.welcome) {
    return null;
  }
  return from;
}
