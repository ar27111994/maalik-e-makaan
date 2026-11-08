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

  /// Where invitation e-mails lead (`invite-member`'s link), with the token
  /// in the fragment: `/invite#token=…`.
  static const invite = '/invite';

  static const home = '/';
  static const search = '/search';
  static const reports = '/reports';
  static const taxYear = '/reports/tax-year';
  static const properties = '/properties';
  static const newProperty = '/properties/new';
  static String property(String id) => '/properties/$id';
  static String editProperty(String id) => '/properties/$id/edit';
  static String newUnit(String propertyId) =>
      '/properties/$propertyId/units/new';
  static String unit(String propertyId, String unitId) =>
      '/properties/$propertyId/units/$unitId';
  static String editUnit(String propertyId, String unitId) =>
      '/properties/$propertyId/units/$unitId/edit';
  static const tenants = '/tenants';
  static const newTenant = '/tenants/new';
  static String tenant(String id) => '/tenants/$id';
  static String editTenant(String id) => '/tenants/$id/edit';
  static const leases = '/leases';
  static String newLease({String? unitId, String? tenantId}) => Uri(
    path: '/leases/new',
    queryParameters: {'unit': ?unitId, 'tenant': ?tenantId},
  ).toString();
  static String lease(String id) => '/leases/$id';
  static String editLease(String id) => '/leases/$id/edit';
  static const money = '/money';
  static String ledger(String leaseId) => '/money/leases/$leaseId';
  static String recordPayment(String leaseId) => '/money/leases/$leaseId/pay';
  static String receipt(String leaseId, String paymentId) =>
      '/money/leases/$leaseId/receipts/$paymentId';
  static const cash = '/money/cash';
  static const more = '/more';
  static const expenses = '/more/expenses';

  /// A new expense, for the maintenance job [requestId] when given.
  static String newExpense({String? requestId}) => Uri(
    path: '/more/expenses/new',
    queryParameters: {'request': ?requestId},
  ).toString();
  static String expense(String id) => '/more/expenses/$id';
  static String editExpense(String id) => '/more/expenses/$id/edit';
  static const utilities = '/more/utilities';
  static const newUtility = '/more/utilities/new';
  static String utility(String id) => '/more/utilities/$id';
  static String editUtility(String id) => '/more/utilities/$id/edit';
  static String utilityBill(String billId) => '/more/utilities/bills/$billId';
  static String meterReading(String readingId) =>
      '/more/utilities/readings/$readingId';
  static const maintenance = '/more/maintenance';

  /// A new maintenance request, at [propertyId] (and [unitId]) when given.
  static String newMaintenance({String? propertyId, String? unitId}) => Uri(
    path: '/more/maintenance/new',
    queryParameters: {'property': ?propertyId, 'unit': ?unitId},
  ).toString();
  static String maintenanceRequest(String id) => '/more/maintenance/$id';
  static String editMaintenance(String id) => '/more/maintenance/$id/edit';
  static const team = '/more/team';
  static const notifications = '/more/notifications';
  static const inviteMember = '/more/team/invite';
  static const portfolioDetails = '/more/portfolio';
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
/// 5. a signed-in user who opened an invitation answers it first (it may
///    give them their first portfolio);
/// 6. a signed-in user without a portfolio creates one first (Settings stay
///    open, to change the language or sign out).
String? redirectFor({
  required Uri location,
  required bool languageChosen,
  required AuthStatus auth,
  PortfolioGate portfolios = PortfolioGate.unknown,
  bool invitationPending = false,
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
      if (path == Routes.invite || settings) return null;
      if (invitationPending) return Routes.invite;
      if (portfolios == PortfolioGate.none && path != Routes.createPortfolio) {
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
