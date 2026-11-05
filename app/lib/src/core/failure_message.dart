import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';

/// The sentence a screen shows for [failure], in the app's language.
String failureMessage(AppLocalizations l10n, AppFailure failure) =>
    switch (failure) {
      NetworkFailure() => l10n.failureNetwork,
      SessionExpired() => l10n.failureSessionExpired,
      ReauthenticationRequired() => l10n.failureReauthenticate,
      Forbidden() => l10n.failureForbidden,
      NotFoundFailure() => l10n.failureNotFound,
      ConflictFailure() => l10n.failureConflict,
      RateLimited(:final retryAfter) =>
        retryAfter == null
            ? l10n.failureRateLimited
            : l10n.failureRateLimitedFor(retryAfter.inSeconds),
      TemporarilyUnavailable() => l10n.failureBusy,
      ServerFailure() => l10n.failureServer,
      UnexpectedFailure() => l10n.failureUnexpected,
      RejectedFailure(:final reason) => _reason(l10n, reason),
    };

String _reason(AppLocalizations l10n, String reason) => switch (reason) {
  'invalid_credentials' => l10n.reasonInvalidCredentials,
  'email_not_confirmed' => l10n.reasonEmailNotConfirmed,
  'email_taken' => l10n.reasonEmailTaken,
  'weak_password' => l10n.reasonWeakPassword,
  'same_password' => l10n.reasonSamePassword,
  'last_owner' => l10n.reasonLastOwner,
  'confirmation_mismatch' => l10n.reasonConfirmationMismatch,
  'account_deleted' => l10n.reasonAccountDeleted,
  'portfolio_limit_reached' => l10n.reasonPortfolioLimit,
  _ => l10n.failureRejected,
};
