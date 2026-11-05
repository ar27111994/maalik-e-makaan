import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
  ];

  /// The app's name, shown in titles and the window bar.
  ///
  /// In en, this message translates to:
  /// **'Maalik-e-Makaan'**
  String get appName;

  /// First-launch screen heading, shown before a language is chosen.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Maalik-e-Makaan'**
  String get welcomeTitle;

  /// First-launch explanation under the heading.
  ///
  /// In en, this message translates to:
  /// **'Rent, tenants and receipts for your properties, in Urdu or English. Choose your language; you can change it later in Settings.'**
  String get welcomeBody;

  /// The English language option, always written in English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// The Urdu language option, always written in Urdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get languageUrdu;

  /// Button that moves on to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// Heading of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Button that signs the user in.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInAction;

  /// Heading of the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// Button that creates an account.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpAction;

  /// Text before the link to the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'New to Maalik-e-Makaan?'**
  String get noAccountPrompt;

  /// Text before the link to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// Link to reset a forgotten password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordAction;

  /// Label of the e-mail field.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get emailLabel;

  /// Label of the password field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Label of the field for a new password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// Rules for a new password, under the field.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with a letter and a number.'**
  String get passwordHelper;

  /// Label of the full name field on sign-up.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fullNameLabel;

  /// Heading of the forgotten-password screen.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetPasswordTitle;

  /// Explanation on the forgotten-password screen.
  ///
  /// In en, this message translates to:
  /// **'Enter the e-mail address of your account and we will send you a link to choose a new password.'**
  String get resetPasswordBody;

  /// Button that e-mails a password-reset link.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLinkAction;

  /// Heading shown after an e-mail was sent.
  ///
  /// In en, this message translates to:
  /// **'Check your e-mail'**
  String get checkEmailTitle;

  /// Explanation after a confirmation or reset e-mail was sent.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. Open it on this device to continue. If it does not arrive in a few minutes, check your spam folder.'**
  String checkEmailBody(String email);

  /// Button that sends the confirmation e-mail again.
  ///
  /// In en, this message translates to:
  /// **'Send the e-mail again'**
  String get resendEmailAction;

  /// Link back to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignInAction;

  /// Heading of the screen opened from a password-reset link.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get choosePasswordTitle;

  /// Button that saves a new password.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePasswordAction;

  /// Shown while an e-mail link signs the user in.
  ///
  /// In en, this message translates to:
  /// **'Signing you in…'**
  String get signingInCallback;

  /// A required field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter this to continue.'**
  String get validationRequired;

  /// The e-mail address is not valid.
  ///
  /// In en, this message translates to:
  /// **'Enter an e-mail address like name@example.com.'**
  String get validationEmail;

  /// The new password does not meet the rules.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters, with a letter and a number.'**
  String get validationPassword;

  /// Navigation destination: the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Navigation destination: tenants and tenancies.
  ///
  /// In en, this message translates to:
  /// **'Tenants'**
  String get navTenants;

  /// Navigation destination: dues, payments and receipts.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get navMoney;

  /// Navigation destination: properties and units.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get navProperties;

  /// Navigation destination: settings, team and account.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// Heading of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section: app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Settings section: theme and contrast.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Theme option that follows the device setting.
  ///
  /// In en, this message translates to:
  /// **'Same as the phone'**
  String get themeSystem;

  /// Light theme option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Switch for high-contrast colours.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get highContrastLabel;

  /// Explanation under the high-contrast switch.
  ///
  /// In en, this message translates to:
  /// **'Stronger colours and outlines, easier to read in sunlight.'**
  String get highContrastHelper;

  /// Settings section: how amounts are grouped.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get settingsNumbers;

  /// Digit grouping option in threes, with an example.
  ///
  /// In en, this message translates to:
  /// **'Western (Rs 1,250,000)'**
  String get groupingWestern;

  /// Digit grouping option in lakh and crore, with an example.
  ///
  /// In en, this message translates to:
  /// **'Lakh and crore (Rs 12,50,000)'**
  String get groupingSouthAsian;

  /// Settings section: the user's account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Button that signs the user out.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutAction;

  /// Opens account deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountAction;

  /// The request could not reach the server.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get failureNetwork;

  /// The user must sign in again.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get failureSessionExpired;

  /// A sensitive action needs a fresh sign-in.
  ///
  /// In en, this message translates to:
  /// **'For your safety, sign in again before doing this.'**
  String get failureReauthenticate;

  /// The user's role does not allow the action.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do this.'**
  String get failureForbidden;

  /// The record does not exist or is not visible.
  ///
  /// In en, this message translates to:
  /// **'This was not found. It may have been deleted.'**
  String get failureNotFound;

  /// A duplicate was refused.
  ///
  /// In en, this message translates to:
  /// **'This already exists.'**
  String get failureConflict;

  /// The user was rate limited, wait unknown.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get failureRateLimited;

  /// The user was rate limited for a known time.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds, plural, =1{1 second} other{{seconds} seconds}}.'**
  String failureRateLimitedFor(int seconds);

  /// A temporary server-side conflict or timeout.
  ///
  /// In en, this message translates to:
  /// **'The service is busy. Please try again.'**
  String get failureBusy;

  /// A server error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again later.'**
  String get failureServer;

  /// An unexpected app error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureUnexpected;

  /// A refusal without a specific message.
  ///
  /// In en, this message translates to:
  /// **'This could not be saved. Check the details and try again.'**
  String get failureRejected;

  /// Sign-in failed.
  ///
  /// In en, this message translates to:
  /// **'The e-mail or password is not right.'**
  String get reasonInvalidCredentials;

  /// Sign-in before confirming the e-mail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your e-mail first: open the link we sent you.'**
  String get reasonEmailNotConfirmed;

  /// Sign-up with an existing e-mail.
  ///
  /// In en, this message translates to:
  /// **'An account with this e-mail already exists. Sign in instead.'**
  String get reasonEmailTaken;

  /// The server refused a weak password.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password: at least 8 characters, with a letter and a number.'**
  String get reasonWeakPassword;

  /// The new password equals the old one.
  ///
  /// In en, this message translates to:
  /// **'Choose a password you have not used before.'**
  String get reasonSamePassword;

  /// Removing or demoting the last owner.
  ///
  /// In en, this message translates to:
  /// **'A portfolio needs at least one owner. Make someone else an owner first.'**
  String get reasonLastOwner;

  /// Typed confirmation did not match.
  ///
  /// In en, this message translates to:
  /// **'The name you typed does not match.'**
  String get reasonConfirmationMismatch;

  /// Action refused because the account is being deleted.
  ///
  /// In en, this message translates to:
  /// **'This account is being deleted.'**
  String get reasonAccountDeleted;

  /// Portfolio creation limit reached.
  ///
  /// In en, this message translates to:
  /// **'You can own up to 20 portfolios.'**
  String get reasonPortfolioLimit;

  /// Button that retries a failed load.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// When cached data was last fetched.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// Banner shown when only cached data is available.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Showing what was saved at {time}.'**
  String offlineShowingSaved(String time);

  /// Heading of a section that is not available yet.
  ///
  /// In en, this message translates to:
  /// **'{section} is being built'**
  String comingSoonTitle(String section);

  /// Explanation of a section that is not available yet.
  ///
  /// In en, this message translates to:
  /// **'This part of the app arrives in the next update.'**
  String get comingSoonBody;

  /// Developer-facing error when build settings are missing.
  ///
  /// In en, this message translates to:
  /// **'This build is not set up'**
  String get configErrorTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
