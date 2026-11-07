// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Maalik-e-Makaan';

  @override
  String get welcomeTitle => 'Welcome to Maalik-e-Makaan';

  @override
  String get welcomeBody =>
      'Rent, tenants and receipts for your properties, in Urdu or English. Choose your language; you can change it later in Settings.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get continueAction => 'Continue';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInAction => 'Sign in';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get signUpAction => 'Create account';

  @override
  String get noAccountPrompt => 'New to Maalik-e-Makaan?';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get forgotPasswordAction => 'Forgot password?';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get passwordHelper =>
      'At least 10 characters, with capital and small letters and a number.';

  @override
  String get fullNameLabel => 'Your name';

  @override
  String get resetPasswordTitle => 'Reset your password';

  @override
  String get resetPasswordBody =>
      'Enter the e-mail address of your account and we will send you a link to choose a new password.';

  @override
  String get sendResetLinkAction => 'Send reset link';

  @override
  String get checkEmailTitle => 'Check your e-mail';

  @override
  String get resendEmailAction => 'Send the e-mail again';

  @override
  String get backToSignInAction => 'Back to sign in';

  @override
  String get choosePasswordTitle => 'Choose a new password';

  @override
  String get savePasswordAction => 'Save password';

  @override
  String get signingInCallback => 'Signing you in…';

  @override
  String get validationRequired => 'Enter this to continue.';

  @override
  String get validationEmail =>
      'Enter an e-mail address like name@example.com.';

  @override
  String get validationPassword =>
      'Use at least 10 characters, with capital and small letters and a number.';

  @override
  String get navTenants => 'Tenants';

  @override
  String get navMoney => 'Money';

  @override
  String get navProperties => 'Properties';

  @override
  String get navMore => 'More';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'Same as the phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get highContrastLabel => 'High contrast';

  @override
  String get highContrastHelper =>
      'Stronger colours and outlines, easier to read in sunlight.';

  @override
  String get settingsNumbers => 'Numbers';

  @override
  String get groupingWestern => 'Western (Rs 1,250,000)';

  @override
  String get groupingSouthAsian => 'Lakh and crore (Rs 12,50,000)';

  @override
  String get settingsAccount => 'Account';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String get failureNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get failureSessionExpired =>
      'Your session has ended. Please sign in again.';

  @override
  String get failureReauthenticate =>
      'For your safety, sign in again before doing this.';

  @override
  String get failureForbidden => 'You do not have permission to do this.';

  @override
  String get failureNotFound => 'This was not found. It may have been deleted.';

  @override
  String get failureConflict => 'This already exists.';

  @override
  String get failureRateLimited =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String failureRateLimitedFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Too many attempts. Try again in $_temp0.';
  }

  @override
  String get failureBusy => 'The service is busy. Please try again.';

  @override
  String get failureServer =>
      'Something went wrong on our side. Please try again later.';

  @override
  String get failureUnexpected => 'Something went wrong. Please try again.';

  @override
  String get failureRejected =>
      'This could not be saved. Check the details and try again.';

  @override
  String get reasonInvalidCredentials => 'The e-mail or password is not right.';

  @override
  String get reasonEmailNotConfirmed =>
      'Confirm your e-mail first: open the link we sent you.';

  @override
  String get reasonEmailTaken =>
      'An account with this e-mail already exists. Sign in instead.';

  @override
  String get reasonWeakPassword =>
      'Choose a stronger password: at least 10 characters, with capital and small letters and a number.';

  @override
  String get reasonSamePassword =>
      'Choose a password you have not used before.';

  @override
  String get reasonLastOwner =>
      'A portfolio needs at least one owner. Make someone else an owner first.';

  @override
  String get reasonConfirmationMismatch => 'The name you typed does not match.';

  @override
  String get reasonAccountDeleted => 'This account is being deleted.';

  @override
  String get reasonPortfolioLimit => 'You can own up to 20 portfolios.';

  @override
  String get retryAction => 'Try again';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String offlineShowingSaved(String time) {
    return 'You are offline. Showing what was saved at $time.';
  }

  @override
  String comingSoonTitle(String section) {
    return '$section is being built';
  }

  @override
  String get comingSoonBody =>
      'This part of the app arrives in the next update.';

  @override
  String get configErrorTitle => 'This build is not set up';

  @override
  String get reasonAlreadyMember => 'This person is already in the portfolio.';

  @override
  String get reasonMemberNotFound =>
      'This person is no longer in the portfolio.';

  @override
  String get reasonInvalidRole =>
      'Choose one of the roles: owner, manager, accountant or viewer.';

  @override
  String get reasonInvalidEmail => 'Enter a valid e-mail address.';

  @override
  String get reasonAlreadyVoided => 'This entry was already voided.';

  @override
  String get reasonAmountExceedsOutstanding =>
      'The amount is more than this tenancy owes.';

  @override
  String get reasonChargeHasPayments =>
      'Money has been received against this charge. Void that payment first.';

  @override
  String get reasonChargeNotEditable =>
      'Only charges you added can change amount. Void this one and add a new one instead.';

  @override
  String get reasonChargeVoided =>
      'This charge was voided and can no longer change.';

  @override
  String get reasonDepositAlreadyUsed =>
      'The deposit has been used since, so this cannot be undone.';

  @override
  String get reasonDepositBelowReceived =>
      'The deposit cannot be less than what has already been received.';

  @override
  String get reasonInsufficientDeposit =>
      'The deposit held is less than this amount.';

  @override
  String get reasonDocumentEntityNotFound =>
      'The record this document belongs to no longer exists.';

  @override
  String get reasonDocumentFileMissing =>
      'The file did not finish uploading. Please upload it again.';

  @override
  String get reasonDocumentFilePendingDeletion =>
      'This file is being deleted. Please upload it again.';

  @override
  String get reasonIdempotencyKeyReused =>
      'This payment was already recorded with different details. Check the ledger before trying again.';

  @override
  String get reasonInvalidAmount =>
      'Enter an amount above zero, with no more than two decimal places.';

  @override
  String get reasonInvalidChargeSelection =>
      'Choose charges from this tenancy that are still owed.';

  @override
  String get reasonInvalidDate => 'Choose a valid date.';

  @override
  String get reasonInvalidTaxWithheld =>
      'Tax withheld cannot be more than the payment.';

  @override
  String get reasonInvalidTaxYear => 'Choose a valid tax year.';

  @override
  String get reasonInvalidMethod => 'Choose how the money was paid.';

  @override
  String get reasonInvalidReason => 'Choose why the rent is changing.';

  @override
  String get reasonReasonRequired => 'Please give a reason.';

  @override
  String get reasonLeaseHasRecords =>
      'This tenancy has money recorded against it, so it cannot be deleted. End the tenancy instead.';

  @override
  String get reasonLeaseNotActive => 'This tenancy is not active.';

  @override
  String get reasonLeaseNotOnConnection =>
      'This tenancy is not on that utility connection.';

  @override
  String get reasonTenantArchived =>
      'This tenant is archived. Restore them first.';

  @override
  String get reasonUnitArchived => 'This unit is archived. Restore it first.';

  @override
  String get reasonConstraintViolation =>
      'Some details are not valid, or refer to something that no longer exists.';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get continueInEnglish => 'Continue in English';

  @override
  String get continueInUrdu => 'اردو میں جاری رکھیں';

  @override
  String validationTooLong(int max) {
    return 'Use at most $max characters.';
  }

  @override
  String get validationPasswordMismatch => 'The passwords do not match.';

  @override
  String get validationPhone => 'Enter a phone number like 03001234567.';

  @override
  String get validationTypedEmail =>
      'Type your e-mail address exactly as shown.';

  @override
  String get accountDeletedTitle => 'Your account has been deleted';

  @override
  String get accountDeletedBody =>
      'Your sign-in, your profile and the portfolios you owned alone are gone. Thank you for using Maalik-e-Makaan.';

  @override
  String get emailSentAgain => 'We sent the e-mail again.';

  @override
  String get checkEmailBodyNoAddress =>
      'We sent you a link. Open it on this device to continue. If it does not arrive in a few minutes, check your spam folder.';

  @override
  String get checkEmailResetHint =>
      'The link works once, for an hour. If no account uses this address, no e-mail is sent.';

  @override
  String resendWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'You can send it again in $_temp0.';
  }

  @override
  String get passwordSaved => 'Your new password is saved.';

  @override
  String get repeatPasswordLabel => 'Type the new password again';

  @override
  String get choosePasswordBody =>
      'Choose the password you will sign in with from now on.';

  @override
  String get linkFailedTitle => 'This link did not work';

  @override
  String get reasonLinkExpired =>
      'This link has expired or was already used. Ask for a new one.';

  @override
  String get reasonLinkInvalid =>
      'This is not a valid sign-in link. Open the latest link we e-mailed you.';

  @override
  String get reasonLinkOtherDevice =>
      'Open the link on the phone or browser where you asked for it. If you were confirming your e-mail, it is confirmed: sign in with your password.';

  @override
  String get reasonSignupDisabled =>
      'New accounts cannot be created right now. Please try again later.';

  @override
  String get reasonMfaRequired =>
      'This account has a second sign-in step, which this app cannot check yet, so it cannot be deleted here.';

  @override
  String get reasonDoesNotMatchAccount =>
      'This is not your account\'s e-mail address.';

  @override
  String get createFirstPortfolioTitle => 'Create your portfolio';

  @override
  String get newPortfolioTitle => 'New portfolio';

  @override
  String get createFirstPortfolioBody =>
      'A portfolio holds your properties, tenants and money records. Name it after the family, the building or the owner, for example “Khan family properties”.';

  @override
  String get newPortfolioBody =>
      'Keep properties apart when their money is kept apart: a relative\'s house, or a plaza with its own accounts. You will be its owner.';

  @override
  String get portfolioNameLabel => 'Portfolio name';

  @override
  String get portfolioNameHelper => 'You can rename it later.';

  @override
  String get portfolioNameInvalid =>
      'This name cannot be used. Use letters, numbers and spaces.';

  @override
  String get createPortfolioAction => 'Create portfolio';

  @override
  String get cancelAction => 'Cancel';

  @override
  String portfolioCreated(String name) {
    return '$name is ready.';
  }

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleAccountant => 'Accountant';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get switchPortfolioTitle => 'Switch portfolio';

  @override
  String get switchPortfolioAction => 'Switch portfolio';

  @override
  String get currentPortfolioLabel => 'Current portfolio';

  @override
  String get newPortfolioAction => 'New portfolio';

  @override
  String get portfolioSection => 'Portfolio';

  @override
  String yourRole(String role) {
    return 'Your role: $role';
  }

  @override
  String get settingsSummary =>
      'Your details, language, appearance and account';

  @override
  String get loadingPortfolios => 'Loading your portfolios';

  @override
  String get portfoliosLoadFailedTitle => 'Your portfolios could not be loaded';

  @override
  String get profileLoadFailedTitle => 'Your details could not be loaded';

  @override
  String get loadingProfile => 'Loading your details';

  @override
  String languageNotSavedToProfile(String reason) {
    return 'The language changed on this device but could not be saved to your account. $reason';
  }

  @override
  String get settingsLanguageHelp => 'The e-mails we send you use it too.';

  @override
  String get themeLabel => 'Theme';

  @override
  String get signedInAs => 'Signed in as';

  @override
  String get profileSection => 'Your details';

  @override
  String get profileSectionHelp =>
      'People in your portfolios see your name and phone.';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get phoneHelper =>
      'A Pakistani number like 03001234567, or a number abroad starting with 00 and its country code.';

  @override
  String get saveDetailsAction => 'Save details';

  @override
  String get detailsSaved => 'Your details are saved.';

  @override
  String get textSizeTitle => 'Text size';

  @override
  String textSizeBody(int percent) {
    return 'Your phone\'s text size is $percent%. The app follows it; change it in your phone\'s display settings.';
  }

  @override
  String get textSizePreviewLabel => 'Preview';

  @override
  String get textSizeSampleName => 'Ayesha Khan';

  @override
  String get textSizeSampleDetail => 'Shop 3, rent due on the 5th';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deletionPreviewFailedTitle =>
      'We could not check what would be deleted';

  @override
  String get loadingDeletionPreview => 'Checking what would be deleted';

  @override
  String get deleteAccountWarningTitle => 'This cannot be undone';

  @override
  String get deleteAccountWarningBody =>
      'Deleted records cannot be recovered, not even by us. Before you continue, keep copies of any receipts and statements you need.';

  @override
  String get deleteAccountWhatGoes => 'What will be deleted';

  @override
  String get deleteAccountNoPortfolios =>
      'You are not the only owner of any portfolio, so no portfolio is deleted.';

  @override
  String deleteAccountPortfolios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You are the only owner of these $count portfolios, so they are deleted with everything in them: properties, tenants, payments, receipts and files.',
      one: 'You are the only owner of this portfolio, so it is deleted with everything in it: properties, tenants, payments, receipts and files.',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountMemberships =>
      'You are removed from every other portfolio; its owners keep it and its records.';

  @override
  String get deleteAccountSignIn =>
      'Your sign-in and your profile are deleted, and you are signed out.';

  @override
  String get deleteAccountConfirmTitle => 'Confirm it is you';

  @override
  String deleteAccountConfirmBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: 'minute',
    );
    return 'Enter your password, as deleting needs a sign-in from the last $_temp0, and type your e-mail address.';
  }

  @override
  String typeEmailToConfirm(String email) {
    return 'Type $email to confirm';
  }

  @override
  String get deleteAccountConfirmAction => 'Delete my account';

  @override
  String get doomedPortfolioOnlyYou => 'Only you use it';

  @override
  String doomedPortfolioOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other people lose access',
      one: '1 other person loses access',
    );
    return '$_temp0';
  }

  @override
  String get checkEmailSentTo => 'We sent a link to:';

  @override
  String get checkEmailInstructions =>
      'Open it on this device to continue. If it does not arrive in a few minutes, check your spam folder.';

  @override
  String get groupingLabel => 'How amounts are grouped';
}
