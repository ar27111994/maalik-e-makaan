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
  /// **'At least 10 characters, with capital and small letters and a number.'**
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
  /// **'Use at least 10 characters, with capital and small letters and a number.'**
  String get validationPassword;

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
  /// **'Choose a stronger password: at least 10 characters, with capital and small letters and a number.'**
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

  /// Inviting an existing member.
  ///
  /// In en, this message translates to:
  /// **'This person is already in the portfolio.'**
  String get reasonAlreadyMember;

  /// Changing a member who already left.
  ///
  /// In en, this message translates to:
  /// **'This person is no longer in the portfolio.'**
  String get reasonMemberNotFound;

  /// An unknown role.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the roles: owner, manager, accountant or viewer.'**
  String get reasonInvalidRole;

  /// The server refused an e-mail address.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail address.'**
  String get reasonInvalidEmail;

  /// Voiding something twice.
  ///
  /// In en, this message translates to:
  /// **'This entry was already voided.'**
  String get reasonAlreadyVoided;

  /// Waiving or applying more than is owed.
  ///
  /// In en, this message translates to:
  /// **'The amount is more than this tenancy owes.'**
  String get reasonAmountExceedsOutstanding;

  /// Voiding a charge that has payments.
  ///
  /// In en, this message translates to:
  /// **'Money has been received against this charge. Void that payment first.'**
  String get reasonChargeHasPayments;

  /// Editing the amount of a generated charge.
  ///
  /// In en, this message translates to:
  /// **'Only charges you added can change amount. Void this one and add a new one instead.'**
  String get reasonChargeNotEditable;

  /// Editing a voided charge.
  ///
  /// In en, this message translates to:
  /// **'This charge was voided and can no longer change.'**
  String get reasonChargeVoided;

  /// Voiding a deposit refund after the deposit was used.
  ///
  /// In en, this message translates to:
  /// **'The deposit has been used since, so this cannot be undone.'**
  String get reasonDepositAlreadyUsed;

  /// Lowering a deposit below what was paid.
  ///
  /// In en, this message translates to:
  /// **'The deposit cannot be less than what has already been received.'**
  String get reasonDepositBelowReceived;

  /// Refunding or applying more deposit than is held.
  ///
  /// In en, this message translates to:
  /// **'The deposit held is less than this amount.'**
  String get reasonInsufficientDeposit;

  /// Attaching a document to a deleted record.
  ///
  /// In en, this message translates to:
  /// **'The record this document belongs to no longer exists.'**
  String get reasonDocumentEntityNotFound;

  /// A document whose file never arrived.
  ///
  /// In en, this message translates to:
  /// **'The file did not finish uploading. Please upload it again.'**
  String get reasonDocumentFileMissing;

  /// A document pointing at a file queued for deletion.
  ///
  /// In en, this message translates to:
  /// **'This file is being deleted. Please upload it again.'**
  String get reasonDocumentFilePendingDeletion;

  /// A retried payment whose details changed.
  ///
  /// In en, this message translates to:
  /// **'This payment was already recorded with different details. Check the ledger before trying again.'**
  String get reasonIdempotencyKeyReused;

  /// The server refused an amount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero, with no more than two decimal places.'**
  String get reasonInvalidAmount;

  /// Paying charges that are not open on this tenancy.
  ///
  /// In en, this message translates to:
  /// **'Choose charges from this tenancy that are still owed.'**
  String get reasonInvalidChargeSelection;

  /// The server refused a date.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid date.'**
  String get reasonInvalidDate;

  /// Withholding more tax than was paid.
  ///
  /// In en, this message translates to:
  /// **'Tax withheld cannot be more than the payment.'**
  String get reasonInvalidTaxWithheld;

  /// The server refused a tax year.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid tax year.'**
  String get reasonInvalidTaxYear;

  /// A missing or reserved payment method.
  ///
  /// In en, this message translates to:
  /// **'Choose how the money was paid.'**
  String get reasonInvalidMethod;

  /// A rent change without a known reason.
  ///
  /// In en, this message translates to:
  /// **'Choose why the rent is changing.'**
  String get reasonInvalidReason;

  /// A void or waiver without a reason.
  ///
  /// In en, this message translates to:
  /// **'Please give a reason.'**
  String get reasonReasonRequired;

  /// Deleting a tenancy with money records.
  ///
  /// In en, this message translates to:
  /// **'This tenancy has money recorded against it, so it cannot be deleted. End the tenancy instead.'**
  String get reasonLeaseHasRecords;

  /// Acting on an ended tenancy.
  ///
  /// In en, this message translates to:
  /// **'This tenancy is not active.'**
  String get reasonLeaseNotActive;

  /// Billing a utility to a tenancy elsewhere.
  ///
  /// In en, this message translates to:
  /// **'This tenancy is not on that utility connection.'**
  String get reasonLeaseNotOnConnection;

  /// Using an archived tenant.
  ///
  /// In en, this message translates to:
  /// **'This tenant is archived. Restore them first.'**
  String get reasonTenantArchived;

  /// Using an archived unit.
  ///
  /// In en, this message translates to:
  /// **'This unit is archived. Restore it first.'**
  String get reasonUnitArchived;

  /// A database check or reference refused the change.
  ///
  /// In en, this message translates to:
  /// **'Some details are not valid, or refer to something that no longer exists.'**
  String get reasonConstraintViolation;

  /// Navigation destination: the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// First-launch button that chooses English, always written in English.
  ///
  /// In en, this message translates to:
  /// **'Continue in English'**
  String get continueInEnglish;

  /// First-launch button that chooses Urdu, always written in Urdu.
  ///
  /// In en, this message translates to:
  /// **'اردو میں جاری رکھیں'**
  String get continueInUrdu;

  /// A field is longer than the database accepts.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String validationTooLong(int max);

  /// The repeated password differs.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get validationPasswordMismatch;

  /// The phone number is not valid.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number like 03001234567.'**
  String get validationPhone;

  /// The typed confirmation does not match the account's e-mail.
  ///
  /// In en, this message translates to:
  /// **'Type your e-mail address exactly as shown.'**
  String get validationTypedEmail;

  /// Banner title on the sign-in screen after account deletion.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted'**
  String get accountDeletedTitle;

  /// Banner on the sign-in screen after account deletion.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in, your profile and the portfolios you owned alone are gone. Thank you for using Maalik-e-Makaan.'**
  String get accountDeletedBody;

  /// Confirmation that an e-mail was sent again.
  ///
  /// In en, this message translates to:
  /// **'We sent the e-mail again.'**
  String get emailSentAgain;

  /// After an e-mail was sent, when the address is no longer known (the page was reloaded).
  ///
  /// In en, this message translates to:
  /// **'We sent you a link. Open it on this device to continue. If it does not arrive in a few minutes, check your spam folder.'**
  String get checkEmailBodyNoAddress;

  /// Extra explanation after a password-reset e-mail.
  ///
  /// In en, this message translates to:
  /// **'The link works once, for an hour. If no account uses this address, no e-mail is sent.'**
  String get checkEmailResetHint;

  /// Countdown before an e-mail can be sent again.
  ///
  /// In en, this message translates to:
  /// **'You can send it again in {seconds, plural, =1{1 second} other{{seconds} seconds}}.'**
  String resendWait(int seconds);

  /// Confirmation after choosing a new password.
  ///
  /// In en, this message translates to:
  /// **'Your new password is saved.'**
  String get passwordSaved;

  /// Label of the field that repeats the new password.
  ///
  /// In en, this message translates to:
  /// **'Type the new password again'**
  String get repeatPasswordLabel;

  /// Explanation on the new-password screen.
  ///
  /// In en, this message translates to:
  /// **'Choose the password you will sign in with from now on.'**
  String get choosePasswordBody;

  /// Heading when an e-mail link cannot be used.
  ///
  /// In en, this message translates to:
  /// **'This link did not work'**
  String get linkFailedTitle;

  /// An e-mail link that is too old or used.
  ///
  /// In en, this message translates to:
  /// **'This link has expired or was already used. Ask for a new one.'**
  String get reasonLinkExpired;

  /// A malformed or unknown e-mail link.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid sign-in link. Open the latest link we e-mailed you.'**
  String get reasonLinkInvalid;

  /// An e-mail link opened on another device or browser than the one that asked for it.
  ///
  /// In en, this message translates to:
  /// **'Open the link on the phone or browser where you asked for it. If you were confirming your e-mail, it is confirmed: sign in with your password.'**
  String get reasonLinkOtherDevice;

  /// Sign-up is turned off on the server.
  ///
  /// In en, this message translates to:
  /// **'New accounts cannot be created right now. Please try again later.'**
  String get reasonSignupDisabled;

  /// Account deletion needs a second factor the app does not support.
  ///
  /// In en, this message translates to:
  /// **'This account has a second sign-in step, which this app cannot check yet, so it cannot be deleted here.'**
  String get reasonMfaRequired;

  /// The typed confirmation is not the account's e-mail.
  ///
  /// In en, this message translates to:
  /// **'This is not your account\'s e-mail address.'**
  String get reasonDoesNotMatchAccount;

  /// Heading of the first-run portfolio screen.
  ///
  /// In en, this message translates to:
  /// **'Create your portfolio'**
  String get createFirstPortfolioTitle;

  /// Heading of the screen that creates another portfolio.
  ///
  /// In en, this message translates to:
  /// **'New portfolio'**
  String get newPortfolioTitle;

  /// Explanation on the first-run portfolio screen.
  ///
  /// In en, this message translates to:
  /// **'A portfolio holds your properties, tenants and money records. Name it after the family, the building or the owner, for example “Khan family properties”.'**
  String get createFirstPortfolioBody;

  /// Explanation on the new-portfolio screen.
  ///
  /// In en, this message translates to:
  /// **'Keep properties apart when their money is kept apart: a relative\'s house, or a plaza with its own accounts. You will be its owner.'**
  String get newPortfolioBody;

  /// Label of the portfolio name field.
  ///
  /// In en, this message translates to:
  /// **'Portfolio name'**
  String get portfolioNameLabel;

  /// Helper under the portfolio name field.
  ///
  /// In en, this message translates to:
  /// **'You can rename it later.'**
  String get portfolioNameHelper;

  /// The server refused the portfolio name.
  ///
  /// In en, this message translates to:
  /// **'This name cannot be used. Use letters, numbers and spaces.'**
  String get portfolioNameInvalid;

  /// Button that creates a portfolio.
  ///
  /// In en, this message translates to:
  /// **'Create portfolio'**
  String get createPortfolioAction;

  /// Button that leaves a form without saving.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Confirmation after creating a portfolio.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready.'**
  String portfolioCreated(String name);

  /// Member role: owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// Member role: manager (caretaker).
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// Member role: accountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get roleAccountant;

  /// Member role: viewer (read-only).
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// Title of the portfolio switcher sheet.
  ///
  /// In en, this message translates to:
  /// **'Switch portfolio'**
  String get switchPortfolioTitle;

  /// Button that opens the portfolio switcher.
  ///
  /// In en, this message translates to:
  /// **'Switch portfolio'**
  String get switchPortfolioAction;

  /// Spoken label of the mark on the current portfolio.
  ///
  /// In en, this message translates to:
  /// **'Current portfolio'**
  String get currentPortfolioLabel;

  /// Button that opens portfolio creation.
  ///
  /// In en, this message translates to:
  /// **'New portfolio'**
  String get newPortfolioAction;

  /// Section heading for the current portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolioSection;

  /// The user's role in the current portfolio.
  ///
  /// In en, this message translates to:
  /// **'Your role: {role}'**
  String yourRole(String role);

  /// What the settings screen holds.
  ///
  /// In en, this message translates to:
  /// **'Your details, language, appearance and account'**
  String get settingsSummary;

  /// Spoken while portfolios load.
  ///
  /// In en, this message translates to:
  /// **'Loading your portfolios'**
  String get loadingPortfolios;

  /// Heading when portfolios fail to load.
  ///
  /// In en, this message translates to:
  /// **'Your portfolios could not be loaded'**
  String get portfoliosLoadFailedTitle;

  /// Heading when the profile fails to load.
  ///
  /// In en, this message translates to:
  /// **'Your details could not be loaded'**
  String get profileLoadFailedTitle;

  /// Spoken while the profile loads.
  ///
  /// In en, this message translates to:
  /// **'Loading your details'**
  String get loadingProfile;

  /// The language could not be saved to the profile; reason follows.
  ///
  /// In en, this message translates to:
  /// **'The language changed on this device but could not be saved to your account. {reason}'**
  String languageNotSavedToProfile(String reason);

  /// Explanation under the language setting.
  ///
  /// In en, this message translates to:
  /// **'The e-mails we send you use it too.'**
  String get settingsLanguageHelp;

  /// Spoken name of the theme choice.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// Label before the signed-in e-mail address.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get signedInAs;

  /// Settings section: name and phone.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get profileSection;

  /// Explanation of who sees the profile.
  ///
  /// In en, this message translates to:
  /// **'People in your portfolios see your name and phone.'**
  String get profileSectionHelp;

  /// Label of the phone field.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// Helper under the phone field.
  ///
  /// In en, this message translates to:
  /// **'A Pakistani number like 03001234567, or a number abroad starting with 00 and its country code.'**
  String get phoneHelper;

  /// Button that saves the name and phone.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get saveDetailsAction;

  /// Confirmation after saving the profile.
  ///
  /// In en, this message translates to:
  /// **'Your details are saved.'**
  String get detailsSaved;

  /// Settings section: text size preview.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSizeTitle;

  /// The current system text scale and where to change it.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s text size is {percent}%. The app follows it; change it in your phone\'s display settings.'**
  String textSizeBody(int percent);

  /// Spoken label of the text-size sample.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get textSizePreviewLabel;

  /// A sample tenant name in the text-size preview.
  ///
  /// In en, this message translates to:
  /// **'Ayesha Khan'**
  String get textSizeSampleName;

  /// A sample tenant detail in the text-size preview.
  ///
  /// In en, this message translates to:
  /// **'Shop 3, rent due on the 5th'**
  String get textSizeSampleDetail;

  /// Heading of the account deletion screen.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// Heading when the deletion preview fails.
  ///
  /// In en, this message translates to:
  /// **'We could not check what would be deleted'**
  String get deletionPreviewFailedTitle;

  /// Spoken while the deletion preview loads.
  ///
  /// In en, this message translates to:
  /// **'Checking what would be deleted'**
  String get loadingDeletionPreview;

  /// Warning title on the deletion screen.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone'**
  String get deleteAccountWarningTitle;

  /// Warning on the deletion screen.
  ///
  /// In en, this message translates to:
  /// **'Deleted records cannot be recovered, not even by us. Before you continue, keep copies of any receipts and statements you need.'**
  String get deleteAccountWarningBody;

  /// Section heading on the deletion screen.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted'**
  String get deleteAccountWhatGoes;

  /// When deletion removes no portfolio.
  ///
  /// In en, this message translates to:
  /// **'You are not the only owner of any portfolio, so no portfolio is deleted.'**
  String get deleteAccountNoPortfolios;

  /// Before the list of portfolios deleted with the account.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You are the only owner of this portfolio, so it is deleted with everything in it: properties, tenants, payments, receipts and files.} other{You are the only owner of these {count} portfolios, so they are deleted with everything in them: properties, tenants, payments, receipts and files.}}'**
  String deleteAccountPortfolios(int count);

  /// What deletion does to other memberships.
  ///
  /// In en, this message translates to:
  /// **'You are removed from every other portfolio; its owners keep it and its records.'**
  String get deleteAccountMemberships;

  /// What deletion does to the account itself.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in and your profile are deleted, and you are signed out.'**
  String get deleteAccountSignIn;

  /// Form section heading on the deletion screen.
  ///
  /// In en, this message translates to:
  /// **'Confirm it is you'**
  String get deleteAccountConfirmTitle;

  /// Explanation of the re-authentication and typed confirmation.
  ///
  /// In en, this message translates to:
  /// **'Enter your password, as deleting needs a sign-in from the last {minutes, plural, =1{minute} other{{minutes} minutes}}, and type your e-mail address.'**
  String deleteAccountConfirmBody(int minutes);

  /// Label of the typed confirmation field.
  ///
  /// In en, this message translates to:
  /// **'Type {email} to confirm'**
  String typeEmailToConfirm(String email);

  /// Button that deletes the account for good.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountConfirmAction;

  /// A deleted portfolio has no other members.
  ///
  /// In en, this message translates to:
  /// **'Only you use it'**
  String get doomedPortfolioOnlyYou;

  /// How many others lose a deleted portfolio.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other person loses access} other{{count} other people lose access}}'**
  String doomedPortfolioOthers(int count);

  /// Before the e-mail address a link was sent to.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to:'**
  String get checkEmailSentTo;

  /// What to do with the e-mailed link.
  ///
  /// In en, this message translates to:
  /// **'Open it on this device to continue. If it does not arrive in a few minutes, check your spam folder.'**
  String get checkEmailInstructions;

  /// Label of the digit grouping choice.
  ///
  /// In en, this message translates to:
  /// **'How amounts are grouped'**
  String get groupingLabel;
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
