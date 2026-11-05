import 'package:maalik_e_makaan/src/auth/auth_repository.dart';

/// Every path the app routes to.
abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const checkEmail = '/check-email';
  static const updatePassword = '/update-password';
  static const authCallback = '/auth/callback';

  static const home = '/';
  static const tenants = '/tenants';
  static const money = '/money';
  static const properties = '/properties';
  static const more = '/more';
  static const settings = '/more/settings';

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
/// In order: a language is chosen before anything else (the first-launch
/// screen); a password-reset link leads only to choosing a new password;
/// signed-out users reach only the public screens (remembering where they
/// were going); signed-in users skip the sign-in screens.
String? redirectFor({
  required Uri location,
  required bool languageChosen,
  required AuthStatus auth,
}) {
  final path = location.path;
  if (!languageChosen) {
    return path == Routes.welcome ? null : _withFrom(Routes.welcome, location);
  }
  if (path == Routes.welcome) return _from(location) ?? Routes.home;

  switch (auth) {
    case RecoveringPassword():
      return path == Routes.updatePassword ? null : Routes.updatePassword;
    case SignedOut():
      if (Routes.public.contains(path)) return null;
      return _withFrom(Routes.signIn, location);
    case SignedIn():
      if (Routes.signedOutOnly.contains(path) || path == Routes.authCallback) {
        return _from(location) ?? Routes.home;
      }
      if (path == Routes.updatePassword) return Routes.home;
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
