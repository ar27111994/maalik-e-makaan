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
      'At least 8 characters, with a letter and a number.';

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
  String checkEmailBody(String email) {
    return 'We sent a link to $email. Open it on this device to continue. If it does not arrive in a few minutes, check your spam folder.';
  }

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
      'Use at least 8 characters, with a letter and a number.';

  @override
  String get navHome => 'Home';

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
      'Choose a stronger password: at least 8 characters, with a letter and a number.';

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
}
