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
  /// **'Western (Rs 1,250,000)'**
  String get groupingWestern;

  /// Digit grouping option in lakh and crore, with an example.
  ///
  /// In en, this message translates to:
  /// **'Lakh and crore (Rs 12,50,000)'**
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

  /// Button that saves a form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// Button that closes a finished task.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAction;

  /// Button that sets something aside for later.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNowAction;

  /// Button that leaves a task screen for the app's first section.
  ///
  /// In en, this message translates to:
  /// **'Go to the app'**
  String get goToAppAction;

  /// A whole number is outside its allowed range.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}.'**
  String validationNumberRange(int min, int max);

  /// A percentage is not valid.
  ///
  /// In en, this message translates to:
  /// **'Enter a percentage from 0 to 100, with at most 2 decimals.'**
  String get validationPercent;

  /// A Raast ID is not a Pakistani mobile number.
  ///
  /// In en, this message translates to:
  /// **'Enter a Pakistani mobile number, like 03001234567.'**
  String get validationRaast;

  /// The IBAN is not a valid Pakistani IBAN.
  ///
  /// In en, this message translates to:
  /// **'Enter a Pakistani IBAN, like PK36 SCBL 0000 0011 2345 6702.'**
  String get validationIban;

  /// An outside app (WhatsApp, a website) could not be opened.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened.'**
  String get linkNotOpened;

  /// What an owner can do, under the role's name.
  ///
  /// In en, this message translates to:
  /// **'Everything, including the team and the payment details.'**
  String get roleOwnerHelp;

  /// What a manager (caretaker) can do.
  ///
  /// In en, this message translates to:
  /// **'Runs properties, tenants and tenancies, and records money.'**
  String get roleManagerHelp;

  /// What an accountant can do.
  ///
  /// In en, this message translates to:
  /// **'Records payments and expenses, and sees everything else.'**
  String get roleAccountantHelp;

  /// What a viewer can do.
  ///
  /// In en, this message translates to:
  /// **'Sees everything and changes nothing.'**
  String get roleViewerHelp;

  /// Title of the team screen and its entry in More.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get teamTitle;

  /// Under the Team entry in More.
  ///
  /// In en, this message translates to:
  /// **'Who can see and run this portfolio'**
  String get teamSummary;

  /// Title of the portfolio settings screen and its entry in More.
  ///
  /// In en, this message translates to:
  /// **'Portfolio details'**
  String get portfolioDetailsTitle;

  /// Under the Portfolio details entry in More.
  ///
  /// In en, this message translates to:
  /// **'Name, tenancy defaults and payment details'**
  String get portfolioDetailsSummary;

  /// Heading of the list of a portfolio's members.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get teamMembersSection;

  /// Heading of the pending invitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations waiting for an answer'**
  String get teamInvitationsSection;

  /// Under the heading of the pending invitations.
  ///
  /// In en, this message translates to:
  /// **'Each link works once, for 7 days, and only for the address it was sent to.'**
  String get teamInvitationsHelp;

  /// The signed-in user's own row in the team.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String memberYou(String name);

  /// A member who gave neither a name nor an address.
  ///
  /// In en, this message translates to:
  /// **'A member without a name'**
  String get memberNoName;

  /// A member's role and e-mail under their name.
  ///
  /// In en, this message translates to:
  /// **'{role} · {email}'**
  String memberRoleAndEmail(String role, String email);

  /// The team failed to load.
  ///
  /// In en, this message translates to:
  /// **'The team could not be loaded'**
  String get teamLoadFailedTitle;

  /// Screen-reader label of the team's loading skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the team'**
  String get loadingTeam;

  /// Button that opens the invitation form.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteAction;

  /// A pending invitation's role and expiry.
  ///
  /// In en, this message translates to:
  /// **'{role} · Until {date}'**
  String invitationExpires(String role, String date);

  /// An invitation that expired before it was accepted.
  ///
  /// In en, this message translates to:
  /// **'{role} · Expired on {date}'**
  String invitationExpired(String role, String date);

  /// Badge on an expired invitation.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get invitationExpiredBadge;

  /// Sends a new invitation to the same address.
  ///
  /// In en, this message translates to:
  /// **'Invite again'**
  String get inviteAgainAction;

  /// Withdraws a pending invitation.
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get revokeInvitationAction;

  /// Confirmation before withdrawing an invitation.
  ///
  /// In en, this message translates to:
  /// **'Cancel the invitation to {email}?'**
  String revokeInvitationTitle(String email);

  /// What withdrawing an invitation does.
  ///
  /// In en, this message translates to:
  /// **'The link stops working. You can invite them again later.'**
  String get revokeInvitationBody;

  /// After withdrawing an invitation.
  ///
  /// In en, this message translates to:
  /// **'Invitation cancelled.'**
  String get invitationCancelled;

  /// Label of the role choice of a member.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get memberRoleLabel;

  /// Saves a member's new role.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get changeRoleAction;

  /// After changing a member's role.
  ///
  /// In en, this message translates to:
  /// **'{name} is now {role}.'**
  String roleChanged(String name, String role);

  /// Shown instead of the role choice for the only owner.
  ///
  /// In en, this message translates to:
  /// **'A portfolio always keeps an owner. Make someone else an owner before changing this role.'**
  String get onlyOwnerNote;

  /// Removes a member.
  ///
  /// In en, this message translates to:
  /// **'Remove from portfolio'**
  String get removeMemberAction;

  /// Confirmation before removing a member.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeMemberTitle(String name);

  /// What removing a member does.
  ///
  /// In en, this message translates to:
  /// **'They lose access to this portfolio at once. Everything they recorded stays.'**
  String get removeMemberBody;

  /// After removing a member.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed.'**
  String memberRemoved(String name);

  /// Button with which a member leaves the portfolio.
  ///
  /// In en, this message translates to:
  /// **'Leave portfolio'**
  String get leaveAction;

  /// Confirmation before leaving a portfolio.
  ///
  /// In en, this message translates to:
  /// **'Leave {portfolio}?'**
  String leaveTitle(String portfolio);

  /// What leaving a portfolio does.
  ///
  /// In en, this message translates to:
  /// **'You lose access at once. Only an owner can invite you back.'**
  String get leaveBody;

  /// Why the only owner cannot leave.
  ///
  /// In en, this message translates to:
  /// **'You are the only owner. Make someone else an owner before you leave.'**
  String get leaveLastOwner;

  /// After leaving a portfolio.
  ///
  /// In en, this message translates to:
  /// **'You left {portfolio}.'**
  String leftPortfolio(String portfolio);

  /// Title of the invitation form.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteTitle;

  /// Explains invitations above the form.
  ///
  /// In en, this message translates to:
  /// **'They get an e-mail with a link that works once, for 7 days, and only for this address. You can also share the link yourself.'**
  String get inviteBody;

  /// Label of the invitee's e-mail field.
  ///
  /// In en, this message translates to:
  /// **'Their e-mail'**
  String get inviteEmailLabel;

  /// Label of the invitee's role choice.
  ///
  /// In en, this message translates to:
  /// **'Their role'**
  String get inviteRoleLabel;

  /// Button that creates and e-mails an invitation.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get sendInvitationAction;

  /// Heading after an invitation was created.
  ///
  /// In en, this message translates to:
  /// **'Invitation ready'**
  String get invitationReadyTitle;

  /// The invitation e-mail was sent.
  ///
  /// In en, this message translates to:
  /// **'We e-mailed the invitation to {email}.'**
  String deliverySent(String email);

  /// The server sends no e-mail.
  ///
  /// In en, this message translates to:
  /// **'E-mail is not set up, so nothing was sent. Share the link with {email} yourself.'**
  String deliveryNotConfigured(String email);

  /// The invitation e-mail was held back by a limit.
  ///
  /// In en, this message translates to:
  /// **'Too many e-mails went to this address or from you in the last hour, so none was sent. Share the link with {email} yourself.'**
  String deliveryRateLimited(String email);

  /// Sending the invitation e-mail failed.
  ///
  /// In en, this message translates to:
  /// **'The e-mail to {email} could not be sent. Share the link yourself.'**
  String deliveryFailed(String email);

  /// The server reported an e-mail state this app does not know.
  ///
  /// In en, this message translates to:
  /// **'If {email} did not get an e-mail, share the link yourself.'**
  String deliveryUnknown(String email);

  /// How long and for whom an invitation link works.
  ///
  /// In en, this message translates to:
  /// **'The link works once, until {date}, and only for {email}.'**
  String invitationValidUntil(String date, String email);

  /// Label of the invitation link.
  ///
  /// In en, this message translates to:
  /// **'Invitation link'**
  String get invitationLinkLabel;

  /// Copies a link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLinkAction;

  /// After copying a link.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get linkCopied;

  /// Opens WhatsApp with a message to send.
  ///
  /// In en, this message translates to:
  /// **'Share on WhatsApp'**
  String get shareWhatsAppAction;

  /// The WhatsApp message that carries an invitation link.
  ///
  /// In en, this message translates to:
  /// **'You are invited to {portfolio} on Maalik-e-Makaan. Open this link to join: {url}'**
  String invitationShareMessage(String portfolio, String url);

  /// Heading of a portfolio's tenancy defaults.
  ///
  /// In en, this message translates to:
  /// **'New tenancies start with'**
  String get tenancyDefaultsSection;

  /// Under the heading of the tenancy defaults.
  ///
  /// In en, this message translates to:
  /// **'You can change them for each tenancy.'**
  String get tenancyDefaultsHelp;

  /// Label of the day of the month rent is due.
  ///
  /// In en, this message translates to:
  /// **'Rent due on day'**
  String get dueDayLabel;

  /// Under the due-day field.
  ///
  /// In en, this message translates to:
  /// **'From 1 to 28, so every month has it.'**
  String get dueDayHelper;

  /// Label of the grace period in days.
  ///
  /// In en, this message translates to:
  /// **'Grace days'**
  String get graceDaysLabel;

  /// Under the grace-days field.
  ///
  /// In en, this message translates to:
  /// **'Days after the due day before rent counts as late.'**
  String get graceDaysHelper;

  /// Label of the yearly rent increase in percent.
  ///
  /// In en, this message translates to:
  /// **'Yearly increase (%)'**
  String get incrementLabel;

  /// Heading of a portfolio's payment details.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get paymentDetailsSection;

  /// Under the payment details heading.
  ///
  /// In en, this message translates to:
  /// **'Tenants see them on receipts and reminders.'**
  String get paymentDetailsHelp;

  /// Label of the landlord name printed on receipts.
  ///
  /// In en, this message translates to:
  /// **'Name on receipts'**
  String get landlordNameLabel;

  /// Label of the landlord phone printed on receipts.
  ///
  /// In en, this message translates to:
  /// **'Phone on receipts'**
  String get landlordPhoneLabel;

  /// Label of the Raast ID field.
  ///
  /// In en, this message translates to:
  /// **'Raast ID'**
  String get raastIdLabel;

  /// Under the Raast ID field.
  ///
  /// In en, this message translates to:
  /// **'The mobile number registered for Raast, like 03001234567.'**
  String get raastIdHelper;

  /// Label of the bank account title.
  ///
  /// In en, this message translates to:
  /// **'Bank account title'**
  String get bankAccountTitleLabel;

  /// Label of the IBAN field.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get ibanLabel;

  /// Under the IBAN field.
  ///
  /// In en, this message translates to:
  /// **'24 characters, starting with PK.'**
  String get ibanHelper;

  /// After saving a portfolio's details.
  ///
  /// In en, this message translates to:
  /// **'Portfolio details saved.'**
  String get portfolioDetailsSaved;

  /// The portfolio details failed to load.
  ///
  /// In en, this message translates to:
  /// **'The portfolio details could not be loaded'**
  String get portfolioDetailsLoadFailedTitle;

  /// Screen-reader label of the portfolio details' loading skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the portfolio details'**
  String get loadingPortfolioDetails;

  /// Title of the screen that accepts an invitation.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get acceptInvitationTitle;

  /// Shown while an invitation is accepted.
  ///
  /// In en, this message translates to:
  /// **'Opening your invitation…'**
  String get acceptingInvitation;

  /// After accepting an invitation.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {portfolio}'**
  String invitationAcceptedTitle(String portfolio);

  /// The role the user joined a portfolio with.
  ///
  /// In en, this message translates to:
  /// **'You joined as {role}.'**
  String invitationAcceptedBody(String role);

  /// Opens the portfolio just joined.
  ///
  /// In en, this message translates to:
  /// **'Open the portfolio'**
  String get openPortfolioAction;

  /// Heading when an invitation is refused.
  ///
  /// In en, this message translates to:
  /// **'This invitation cannot be used'**
  String get invitationFailedTitle;

  /// The invitation link is not valid.
  ///
  /// In en, this message translates to:
  /// **'This is not a working invitation link. Ask for a new invitation.'**
  String get invitationInvalidBody;

  /// The invitation was revoked.
  ///
  /// In en, this message translates to:
  /// **'This invitation was cancelled. Ask an owner of the portfolio for a new one.'**
  String get invitationRevokedBody;

  /// Someone else used the invitation.
  ///
  /// In en, this message translates to:
  /// **'This invitation was accepted already, by another account. Ask for a new one.'**
  String get invitationAlreadyUsedBody;

  /// The invitation expired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired: invitations work for 7 days. Ask for a new one.'**
  String get invitationExpiredBody;

  /// The account's e-mail is not confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your e-mail address first, then open the invitation link again.'**
  String get invitationEmailNotVerifiedBody;

  /// The signed-in account is not the invited address.
  ///
  /// In en, this message translates to:
  /// **'This invitation was sent to another e-mail address. Sign out, then sign in or create an account with the address it was sent to.'**
  String get invitationEmailMismatchBody;

  /// The server refused the invitation for a reason this app does not know.
  ///
  /// In en, this message translates to:
  /// **'This invitation cannot be accepted. Ask for a new one.'**
  String get invitationUnknownBody;

  /// The invitation screen was opened without an invitation.
  ///
  /// In en, this message translates to:
  /// **'No invitation is waiting on this device. Open the link in the invitation e-mail.'**
  String get noInvitationBody;

  /// Heading when accepting an invitation failed for a reason that may pass (offline).
  ///
  /// In en, this message translates to:
  /// **'The invitation could not be opened'**
  String get invitationNotAcceptedTitle;

  /// Tooltip of the button that lowers a number of days.
  ///
  /// In en, this message translates to:
  /// **'Fewer days'**
  String get fewerDaysAction;

  /// Tooltip of the button that raises a number of days.
  ///
  /// In en, this message translates to:
  /// **'More days'**
  String get moreDaysAction;

  /// A number of days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No days} =1{1 day} other{{count} days}}'**
  String dayCount(int count);

  /// Label of when a pending invitation expires.
  ///
  /// In en, this message translates to:
  /// **'Works until'**
  String get invitationWorksUntil;

  /// After accepting an invitation, when the portfolio's name is not known yet.
  ///
  /// In en, this message translates to:
  /// **'You joined the portfolio'**
  String get invitationAcceptedNoName;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get propertyTypeHouse;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'Apartment building'**
  String get propertyTypeApartmentBuilding;

  /// A property type: one apartment.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get propertyTypeApartment;

  /// A property type: a commercial plaza.
  ///
  /// In en, this message translates to:
  /// **'Plaza'**
  String get propertyTypePlaza;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get propertyTypeShop;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get propertyTypeOffice;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'Hostel'**
  String get propertyTypeHostel;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'Farmhouse'**
  String get propertyTypeFarmhouse;

  /// A property type.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get propertyTypeWarehouse;

  /// A property type: land.
  ///
  /// In en, this message translates to:
  /// **'Plot'**
  String get propertyTypePlot;

  /// A property or unit type that is none of the others.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get propertyTypeOther;

  /// A province.
  ///
  /// In en, this message translates to:
  /// **'Punjab'**
  String get provincePunjab;

  /// A province.
  ///
  /// In en, this message translates to:
  /// **'Sindh'**
  String get provinceSindh;

  /// A province.
  ///
  /// In en, this message translates to:
  /// **'Khyber Pakhtunkhwa'**
  String get provinceKhyberPakhtunkhwa;

  /// A province.
  ///
  /// In en, this message translates to:
  /// **'Balochistan'**
  String get provinceBalochistan;

  /// The Islamabad Capital Territory.
  ///
  /// In en, this message translates to:
  /// **'Islamabad'**
  String get provinceIslamabad;

  /// A region.
  ///
  /// In en, this message translates to:
  /// **'Gilgit-Baltistan'**
  String get provinceGilgitBaltistan;

  /// A region.
  ///
  /// In en, this message translates to:
  /// **'Azad Kashmir'**
  String get provinceAzadKashmir;

  /// The police-registration law of a province whose clock starts at possession.
  ///
  /// In en, this message translates to:
  /// **'{province}: register each tenancy with the police within {days} of the tenant moving in.'**
  String policeHintPossession(String province, String days);

  /// The police-registration law of a province whose clock starts at the agreement.
  ///
  /// In en, this message translates to:
  /// **'{province}: register each tenancy with the police within {days} of signing the agreement.'**
  String policeHintAgreement(String province, String days);

  /// Where no statute fixes a police-registration deadline.
  ///
  /// In en, this message translates to:
  /// **'{province}: no law the app knows of sets a deadline. The app reminds you to register each tenancy with the police a day after the tenant moves in.'**
  String policeHintReminder(String province);

  /// A unit of land area.
  ///
  /// In en, this message translates to:
  /// **'Marla'**
  String get areaUnitMarla;

  /// A unit of land area.
  ///
  /// In en, this message translates to:
  /// **'Kanal'**
  String get areaUnitKanal;

  /// A unit of area.
  ///
  /// In en, this message translates to:
  /// **'Square feet'**
  String get areaUnitSquareFeet;

  /// A unit of area.
  ///
  /// In en, this message translates to:
  /// **'Square yards'**
  String get areaUnitSquareYards;

  /// A unit of area.
  ///
  /// In en, this message translates to:
  /// **'Square metres'**
  String get areaUnitSquareMetres;

  /// A unit of land area.
  ///
  /// In en, this message translates to:
  /// **'Acres'**
  String get areaUnitAcre;

  /// A size and its unit, like 5 Marla.
  ///
  /// In en, this message translates to:
  /// **'{size} {unit}'**
  String areaValue(String size, String unit);

  /// A covered area in square feet.
  ///
  /// In en, this message translates to:
  /// **'{area} sq ft'**
  String coveredAreaValue(String area);

  /// A unit type.
  ///
  /// In en, this message translates to:
  /// **'Entire property'**
  String get unitTypeEntireProperty;

  /// A unit type: one portion (floor) of a house.
  ///
  /// In en, this message translates to:
  /// **'Portion'**
  String get unitTypePortion;

  /// A unit type.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get unitTypeApartment;

  /// A unit type.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get unitTypeRoom;

  /// A unit type: a bed in a shared room or hostel.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get unitTypeBed;

  /// A unit type.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get unitTypeShop;

  /// A unit type.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get unitTypeOffice;

  /// A unit type: a whole floor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get unitTypeFloor;

  /// A unit type.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get unitTypeWarehouse;

  /// Badge of a unit with a tenancy now.
  ///
  /// In en, this message translates to:
  /// **'Let'**
  String get occupancyOccupied;

  /// Badge of a unit whose tenancy starts later.
  ///
  /// In en, this message translates to:
  /// **'Tenancy starts soon'**
  String get occupancyUpcoming;

  /// Badge of a unit without a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Vacant'**
  String get occupancyVacant;

  /// A vacant unit and since when.
  ///
  /// In en, this message translates to:
  /// **'Vacant since {date}'**
  String occupancyVacantSince(String date);

  /// Badge of a unit not offered for rent.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get occupancyUnavailable;

  /// Badge of something archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get occupancyArchived;

  /// Badge when the occupancy is not known.
  ///
  /// In en, this message translates to:
  /// **'Status unknown'**
  String get occupancyUnknown;

  /// Button that opens the new-property form.
  ///
  /// In en, this message translates to:
  /// **'Add property'**
  String get addPropertyAction;

  /// Empty list of properties.
  ///
  /// In en, this message translates to:
  /// **'No properties yet'**
  String get propertiesEmptyTitle;

  /// Explains what to add to an empty property list.
  ///
  /// In en, this message translates to:
  /// **'Add a house, a plaza or a plot, then the portions, flats or shops you rent out in it.'**
  String get propertiesEmptyBody;

  /// Empty list of archived properties.
  ///
  /// In en, this message translates to:
  /// **'No archived properties.'**
  String get archivedPropertiesEmpty;

  /// Explains the archived list.
  ///
  /// In en, this message translates to:
  /// **'Properties you archive keep their history and wait here.'**
  String get archivedPropertiesEmptyBody;

  /// Filter showing what is in use.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get filterInUse;

  /// Filter showing what is archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get filterArchived;

  /// Reads the next page of a list.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get loadMoreAction;

  /// The property list failed to load.
  ///
  /// In en, this message translates to:
  /// **'The properties could not be loaded'**
  String get propertiesLoadFailedTitle;

  /// Screen-reader label of the property list's skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the properties'**
  String get loadingProperties;

  /// Two details of a list row side by side.
  ///
  /// In en, this message translates to:
  /// **'{first} · {second}'**
  String listDetail(String first, String second);

  /// Title of the new-property form.
  ///
  /// In en, this message translates to:
  /// **'New property'**
  String get newPropertyTitle;

  /// Title of the property form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit property'**
  String get editPropertyTitle;

  /// Form section with the property's name and type.
  ///
  /// In en, this message translates to:
  /// **'The property'**
  String get propertySectionBasics;

  /// Form section with the address.
  ///
  /// In en, this message translates to:
  /// **'Where it is'**
  String get propertySectionLocation;

  /// Form section with the plot and covered area.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get propertySectionSize;

  /// Form section with the purchase price and value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get propertySectionValue;

  /// Label of a property's name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get propertyNameLabel;

  /// Under a property's name field.
  ///
  /// In en, this message translates to:
  /// **'As you call it, like Gulberg house or Saddar shops.'**
  String get propertyNameHelper;

  /// Label of a type choice.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// Label of an address field.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// Label of a property's locality.
  ///
  /// In en, this message translates to:
  /// **'Area or society'**
  String get localityLabel;

  /// Label of a property's city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// Label of a property's province.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get provinceLabel;

  /// Under the province field.
  ///
  /// In en, this message translates to:
  /// **'It decides the rules that apply, such as police registration.'**
  String get provinceHelper;

  /// Label of a plot's size.
  ///
  /// In en, this message translates to:
  /// **'Plot size'**
  String get plotSizeLabel;

  /// Label of a plot size's unit.
  ///
  /// In en, this message translates to:
  /// **'Measured in'**
  String get plotUnitLabel;

  /// Label of the covered area.
  ///
  /// In en, this message translates to:
  /// **'Covered area (sq ft)'**
  String get coveredAreaLabel;

  /// Label of the year a property was built.
  ///
  /// In en, this message translates to:
  /// **'Year built'**
  String get yearBuiltLabel;

  /// Label of what a property cost.
  ///
  /// In en, this message translates to:
  /// **'Purchase price'**
  String get purchasePriceLabel;

  /// Label of when a property was bought.
  ///
  /// In en, this message translates to:
  /// **'Bought on'**
  String get purchasedOnLabel;

  /// Label of a property's estimated value.
  ///
  /// In en, this message translates to:
  /// **'Estimated value'**
  String get estimatedValueLabel;

  /// Label of when the value was estimated.
  ///
  /// In en, this message translates to:
  /// **'Value estimated on'**
  String get valueEstimatedOnLabel;

  /// Label of a property tax reference.
  ///
  /// In en, this message translates to:
  /// **'Property tax reference'**
  String get propertyTaxRefLabel;

  /// Label of a notes field.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// A size is not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Enter a number above 0, with at most 2 decimals.'**
  String get validationPositiveNumber;

  /// A plot size has no unit.
  ///
  /// In en, this message translates to:
  /// **'Choose what the plot size is measured in.'**
  String get validationPlotUnit;

  /// A money field holds text that is not an amount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount, like 25,000.'**
  String get validationAmount;

  /// After adding a property.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String propertyAdded(String name);

  /// After saving a property.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String propertySaved(String name);

  /// Heading of a record's details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get propertyDetailsSection;

  /// Heading of a property's units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get unitsSection;

  /// Under the heading of a property's units.
  ///
  /// In en, this message translates to:
  /// **'The portions, flats, rooms or shops you rent out.'**
  String get unitsSectionHelp;

  /// Button that opens the new-unit form.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get addUnitAction;

  /// Empty list of units.
  ///
  /// In en, this message translates to:
  /// **'No units yet. Add each part you rent out, even when it is the whole property.'**
  String get unitsEmpty;

  /// Opens a record's form.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// Archives a record.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveAction;

  /// Takes a record out of the archive.
  ///
  /// In en, this message translates to:
  /// **'Put back in use'**
  String get restoreAction;

  /// Deletes a record.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// Banner on an archived record.
  ///
  /// In en, this message translates to:
  /// **'Archived on {date}. It keeps its history; put it back in use to change it.'**
  String archivedBanner(String date);

  /// Confirmation before archiving a property.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String archivePropertyTitle(String name);

  /// What archiving a property does.
  ///
  /// In en, this message translates to:
  /// **'It leaves your lists but keeps its units, tenancies and money. You can put it back in use later.'**
  String get archivePropertyBody;

  /// After archiving a property.
  ///
  /// In en, this message translates to:
  /// **'{name} archived.'**
  String propertyArchived(String name);

  /// After restoring a property.
  ///
  /// In en, this message translates to:
  /// **'{name} is back in use.'**
  String propertyRestored(String name);

  /// Confirmation before deleting a property.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deletePropertyTitle(String name);

  /// What deleting a property does.
  ///
  /// In en, this message translates to:
  /// **'Only for a property added by mistake: it goes for good, with its units. A property with tenancies or expenses cannot be deleted; archive it instead.'**
  String get deletePropertyBody;

  /// Label of a typed confirmation.
  ///
  /// In en, this message translates to:
  /// **'Type {name} to confirm'**
  String typeToConfirm(String name);

  /// After deleting a property.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String propertyDeleted(String name);

  /// A property failed to load.
  ///
  /// In en, this message translates to:
  /// **'This property could not be loaded'**
  String get propertyLoadFailedTitle;

  /// Screen-reader label of a property's skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the property'**
  String get loadingProperty;

  /// A property's units failed to load.
  ///
  /// In en, this message translates to:
  /// **'The units could not be loaded'**
  String get unitsLoadFailedTitle;

  /// A property name is taken.
  ///
  /// In en, this message translates to:
  /// **'Another property in use has this name. Choose another.'**
  String get reasonDuplicatePropertyName;

  /// A unit name is taken.
  ///
  /// In en, this message translates to:
  /// **'Another unit of this property has this name. Choose another.'**
  String get reasonDuplicateUnitLabel;

  /// A delete refused because something refers to the record.
  ///
  /// In en, this message translates to:
  /// **'A tenancy or an expense still refers to this, so it cannot be deleted. Archive it instead.'**
  String get reasonStillInUse;

  /// Title of the new-unit form.
  ///
  /// In en, this message translates to:
  /// **'New unit'**
  String get newUnitTitle;

  /// Title of the unit form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit unit'**
  String get editUnitTitle;

  /// Label of a unit's name.
  ///
  /// In en, this message translates to:
  /// **'Name or number'**
  String get unitLabelLabel;

  /// Under a unit's name field.
  ///
  /// In en, this message translates to:
  /// **'Like Ground floor, Flat 2 or Shop 5.'**
  String get unitLabelHelper;

  /// Label of the floor a unit is on.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floorLabel;

  /// Label of the number of bedrooms.
  ///
  /// In en, this message translates to:
  /// **'Bedrooms'**
  String get bedroomsLabel;

  /// Label of the number of bathrooms.
  ///
  /// In en, this message translates to:
  /// **'Bathrooms'**
  String get bathroomsLabel;

  /// Tooltip of the button that lowers a count.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get fewerAction;

  /// Tooltip of the button that raises a count.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreAction;

  /// Whether a unit comes with furniture.
  ///
  /// In en, this message translates to:
  /// **'Furnished'**
  String get furnishedLabel;

  /// A unit without furniture.
  ///
  /// In en, this message translates to:
  /// **'Unfurnished'**
  String get unfurnishedValue;

  /// Label of the monthly rent asked for a unit.
  ///
  /// In en, this message translates to:
  /// **'Asking rent'**
  String get askingRentLabel;

  /// Under the asking-rent field.
  ///
  /// In en, this message translates to:
  /// **'What you ask for it each month.'**
  String get askingRentHelper;

  /// A unit's asking rent in a list.
  ///
  /// In en, this message translates to:
  /// **'Asking {rent}'**
  String askingRentValue(String rent);

  /// Whether a unit is offered for rent.
  ///
  /// In en, this message translates to:
  /// **'Available to rent'**
  String get availableLabel;

  /// Under the available switch.
  ///
  /// In en, this message translates to:
  /// **'Turn off while it is being renovated or you live in it.'**
  String get availableHelp;

  /// Label of the property a unit belongs to.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get unitPropertyLabel;

  /// Label of a unit's occupancy.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get occupancyLabel;

  /// After adding a unit.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String unitAdded(String name);

  /// After saving a unit.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String unitSaved(String name);

  /// Confirmation before archiving a unit.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String archiveUnitTitle(String name);

  /// What archiving a unit does.
  ///
  /// In en, this message translates to:
  /// **'It leaves your lists but keeps its tenancies and money. A unit that is let now can still be archived; end its tenancy first if it has ended.'**
  String get archiveUnitBody;

  /// After archiving a unit.
  ///
  /// In en, this message translates to:
  /// **'{name} archived.'**
  String unitArchived(String name);

  /// After restoring a unit.
  ///
  /// In en, this message translates to:
  /// **'{name} is back in use.'**
  String unitRestored(String name);

  /// Confirmation before deleting a unit.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteUnitTitle(String name);

  /// What deleting a unit does.
  ///
  /// In en, this message translates to:
  /// **'Only for a unit added by mistake: it goes for good. A unit with tenancies or expenses cannot be deleted; archive it instead.'**
  String get deleteUnitBody;

  /// After deleting a unit.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String unitDeleted(String name);

  /// A unit failed to load.
  ///
  /// In en, this message translates to:
  /// **'This unit could not be loaded'**
  String get unitLoadFailedTitle;

  /// Screen-reader label of a unit's skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the unit'**
  String get loadingUnit;

  /// A number of rooms in a stepper.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1} other{{count}}}'**
  String roomCount(int count);

  /// A tenant who is a person.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get tenantKindIndividual;

  /// A tenant that is a company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get tenantKindCompany;

  /// A tenant that is a government office.
  ///
  /// In en, this message translates to:
  /// **'Government office'**
  String get tenantKindGovernment;

  /// S/O: whose son a tenant is.
  ///
  /// In en, this message translates to:
  /// **'Son of'**
  String get guardianSonOf;

  /// D/O: whose daughter a tenant is.
  ///
  /// In en, this message translates to:
  /// **'Daughter of'**
  String get guardianDaughterOf;

  /// W/O: whose wife a tenant is.
  ///
  /// In en, this message translates to:
  /// **'Wife of'**
  String get guardianWifeOf;

  /// A tenant's guardian, like Son of Ahmed Khan.
  ///
  /// In en, this message translates to:
  /// **'{relation} {name}'**
  String guardianLine(String relation, String name);

  /// Opens the new-tenant form.
  ///
  /// In en, this message translates to:
  /// **'Add tenant'**
  String get addTenantAction;

  /// Hint of the tenant search.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone or CNIC'**
  String get searchTenantsHint;

  /// Empty tenant list.
  ///
  /// In en, this message translates to:
  /// **'No tenants yet'**
  String get tenantsEmptyTitle;

  /// Explains the empty tenant list.
  ///
  /// In en, this message translates to:
  /// **'Add the people or businesses who rent from you, then start their tenancy from a unit.'**
  String get tenantsEmptyBody;

  /// Empty archived tenant list.
  ///
  /// In en, this message translates to:
  /// **'No archived tenants.'**
  String get archivedTenantsEmpty;

  /// Explains the archived tenant list.
  ///
  /// In en, this message translates to:
  /// **'Tenants you archive keep their history and wait here.'**
  String get archivedTenantsEmptyBody;

  /// A search found nothing.
  ///
  /// In en, this message translates to:
  /// **'No tenant matches {search}.'**
  String noTenantMatches(String search);

  /// The tenant list failed to load.
  ///
  /// In en, this message translates to:
  /// **'The tenants could not be loaded'**
  String get tenantsLoadFailedTitle;

  /// Screen-reader label of the tenant list skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the tenants'**
  String get loadingTenants;

  /// A tenant failed to load.
  ///
  /// In en, this message translates to:
  /// **'This tenant could not be loaded'**
  String get tenantLoadFailedTitle;

  /// Screen-reader label of a tenant's skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the tenant'**
  String get loadingTenant;

  /// Title of the new-tenant form.
  ///
  /// In en, this message translates to:
  /// **'New tenant'**
  String get newTenantTitle;

  /// Title of the tenant form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit tenant'**
  String get editTenantTitle;

  /// Form section with a tenant's name.
  ///
  /// In en, this message translates to:
  /// **'Who they are'**
  String get tenantSectionWho;

  /// Form section with the CNIC and NTN.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get tenantSectionIdentity;

  /// Form section with phones and e-mail.
  ///
  /// In en, this message translates to:
  /// **'How to reach them'**
  String get tenantSectionContact;

  /// Form section with occupation and addresses.
  ///
  /// In en, this message translates to:
  /// **'Work and addresses'**
  String get tenantSectionWork;

  /// Form section with the emergency contact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get tenantSectionEmergency;

  /// Form section with two references.
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get tenantSectionReferences;

  /// Form section with household size and tax.
  ///
  /// In en, this message translates to:
  /// **'Household and tax'**
  String get tenantSectionHousehold;

  /// Form section recording consent to keep data.
  ///
  /// In en, this message translates to:
  /// **'Consent'**
  String get tenantSectionConsent;

  /// Label of whether the tenant is a person or an organisation.
  ///
  /// In en, this message translates to:
  /// **'Tenant is a'**
  String get tenantKindLabel;

  /// Label of a tenant's full name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameTenantLabel;

  /// Label of a tenant's guardian relation.
  ///
  /// In en, this message translates to:
  /// **'S/O, D/O or W/O'**
  String get guardianRelationLabel;

  /// Label of a tenant's guardian name.
  ///
  /// In en, this message translates to:
  /// **'Father\'s or husband\'s name'**
  String get guardianNameLabel;

  /// Label of a CNIC.
  ///
  /// In en, this message translates to:
  /// **'CNIC'**
  String get cnicLabel;

  /// Under the CNIC field.
  ///
  /// In en, this message translates to:
  /// **'13 digits, as on the card.'**
  String get cnicHelper;

  /// The CNIC is not valid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 13 digits of a CNIC, like 35202-1234567-1.'**
  String get validationCnic;

  /// Label of a CNIC's expiry date.
  ///
  /// In en, this message translates to:
  /// **'CNIC expires on'**
  String get cnicExpiryLabel;

  /// Badge on an expired CNIC.
  ///
  /// In en, this message translates to:
  /// **'CNIC expired'**
  String get cnicExpired;

  /// Label of a tax number.
  ///
  /// In en, this message translates to:
  /// **'NTN'**
  String get ntnLabel;

  /// The NTN is not valid.
  ///
  /// In en, this message translates to:
  /// **'Enter the NTN as issued, 6 to 15 letters, digits or dashes.'**
  String get validationNtn;

  /// Label of an alternate phone.
  ///
  /// In en, this message translates to:
  /// **'Other phone'**
  String get altPhoneLabel;

  /// Label of a tenant's occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupationLabel;

  /// Label of a tenant's employer.
  ///
  /// In en, this message translates to:
  /// **'Employer'**
  String get employerLabel;

  /// Label of a tenant's permanent address.
  ///
  /// In en, this message translates to:
  /// **'Permanent address'**
  String get permanentAddressLabel;

  /// Label of a tenant's previous address.
  ///
  /// In en, this message translates to:
  /// **'Previous address'**
  String get previousAddressLabel;

  /// Label of a contact's name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactNameLabel;

  /// Label of how a contact is related.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get contactRelationLabel;

  /// Heading of one reference.
  ///
  /// In en, this message translates to:
  /// **'Reference {number}'**
  String referenceLabel(int number);

  /// Label of a household's size.
  ///
  /// In en, this message translates to:
  /// **'People living there'**
  String get householdSizeLabel;

  /// Whether a tenant deducts s.155 tax.
  ///
  /// In en, this message translates to:
  /// **'Deducts withholding tax'**
  String get withholdingTaxLabel;

  /// Explains withholding tax.
  ///
  /// In en, this message translates to:
  /// **'Companies and government offices deduct tax under section 155 from the rent they pay.'**
  String get withholdingTaxHelp;

  /// Checkbox recording the tenant's consent.
  ///
  /// In en, this message translates to:
  /// **'I told the tenant what details are kept and why'**
  String get consentLabel;

  /// Label of the consent note.
  ///
  /// In en, this message translates to:
  /// **'What they agreed to'**
  String get consentNoteLabel;

  /// When consent was recorded.
  ///
  /// In en, this message translates to:
  /// **'Consent recorded on {date}'**
  String consentRecorded(String date);

  /// A tenant without recorded consent.
  ///
  /// In en, this message translates to:
  /// **'Consent not recorded'**
  String get consentMissing;

  /// After adding a tenant.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String tenantAdded(String name);

  /// After saving a tenant.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String tenantSaved(String name);

  /// Heading when another tenant has the same CNIC or phone.
  ///
  /// In en, this message translates to:
  /// **'Is this the same tenant?'**
  String get duplicateTenantTitle;

  /// Warning about a possible duplicate tenant.
  ///
  /// In en, this message translates to:
  /// **'{names} already has this CNIC or phone number. Save anyway?'**
  String duplicateTenantBody(String names);

  /// Saves despite a warning.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnywayAction;

  /// A CNIC belongs to another tenant.
  ///
  /// In en, this message translates to:
  /// **'Another tenant in use has this CNIC.'**
  String get reasonDuplicateCnic;

  /// Heading of a tenant's details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get tenantDetailsSection;

  /// Heading of a tenant's tenancies.
  ///
  /// In en, this message translates to:
  /// **'Tenancies'**
  String get tenantTenanciesSection;

  /// Confirmation before archiving a tenant.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String archiveTenantTitle(String name);

  /// What archiving a tenant does.
  ///
  /// In en, this message translates to:
  /// **'They leave your lists but keep their tenancies, payments and receipts. You can put them back in use later.'**
  String get archiveTenantBody;

  /// After archiving a tenant.
  ///
  /// In en, this message translates to:
  /// **'{name} archived.'**
  String tenantArchived(String name);

  /// After restoring a tenant.
  ///
  /// In en, this message translates to:
  /// **'{name} is back in use.'**
  String tenantRestored(String name);

  /// Confirmation before deleting a tenant.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteTenantTitle(String name);

  /// What deleting a tenant does.
  ///
  /// In en, this message translates to:
  /// **'Only for a tenant added by mistake: their details go for good. A tenant with a tenancy cannot be deleted; archive them instead.'**
  String get deleteTenantBody;

  /// After deleting a tenant.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String tenantDeleted(String name);

  /// Label of an optional e-mail.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get emailOptionalLabel;

  /// Label of a reference's name.
  ///
  /// In en, this message translates to:
  /// **'Reference {number}: name'**
  String referenceNameLabel(int number);

  /// Label of a reference's phone.
  ///
  /// In en, this message translates to:
  /// **'Reference {number}: phone'**
  String referencePhoneLabel(int number);

  /// Title of a tenancy's screen.
  ///
  /// In en, this message translates to:
  /// **'Tenancy'**
  String get tenancyTitle;

  /// Title of the form that starts a tenancy.
  ///
  /// In en, this message translates to:
  /// **'New tenancy'**
  String get newTenancyTitle;

  /// Title of the form that edits a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Edit tenancy terms'**
  String get editTenancyTitle;

  /// Opens the form that starts a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Start tenancy'**
  String get startTenancyAction;

  /// Badge of a running tenancy.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get leaseActive;

  /// Badge of an ended tenancy.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get leaseEnded;

  /// Badge of a tenancy that starts later.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String leaseUpcoming(String date);

  /// A unit and its property.
  ///
  /// In en, this message translates to:
  /// **'{unit}, {property}'**
  String unitAtProperty(String unit, String property);

  /// Label of a tenancy's tenant.
  ///
  /// In en, this message translates to:
  /// **'Tenant'**
  String get tenantLabel;

  /// Label of a tenancy's unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No tenant chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose the tenant.'**
  String get validationChooseTenant;

  /// Starting a tenancy without tenants.
  ///
  /// In en, this message translates to:
  /// **'Add the tenant first: there is no tenant in use to choose.'**
  String get noTenantsToChoose;

  /// Form section with the tenant and unit.
  ///
  /// In en, this message translates to:
  /// **'Who and where'**
  String get leaseSectionWho;

  /// Form section with the dates.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get leaseSectionTerm;

  /// Form section with rent and deposit.
  ///
  /// In en, this message translates to:
  /// **'Rent and deposit'**
  String get leaseSectionRent;

  /// Form section with the late-fee policy.
  ///
  /// In en, this message translates to:
  /// **'Late fees'**
  String get leaseSectionLateFee;

  /// Form section with the agreement.
  ///
  /// In en, this message translates to:
  /// **'Agreement'**
  String get leaseSectionAgreement;

  /// Form and screen section on police registration.
  ///
  /// In en, this message translates to:
  /// **'Police registration'**
  String get leaseSectionPolice;

  /// Form section with other terms.
  ///
  /// In en, this message translates to:
  /// **'Other terms'**
  String get leaseSectionOther;

  /// Label of a tenancy's start (possession).
  ///
  /// In en, this message translates to:
  /// **'Moves in on'**
  String get moveInLabel;

  /// Label of a tenancy's term.
  ///
  /// In en, this message translates to:
  /// **'Term'**
  String get termLabel;

  /// A tenancy term.
  ///
  /// In en, this message translates to:
  /// **'11 months'**
  String get term11;

  /// A tenancy term.
  ///
  /// In en, this message translates to:
  /// **'12 months'**
  String get term12;

  /// A tenancy term ending on a chosen date.
  ///
  /// In en, this message translates to:
  /// **'Until a date'**
  String get termCustom;

  /// A tenancy without an end date.
  ///
  /// In en, this message translates to:
  /// **'Month to month'**
  String get termPeriodic;

  /// Label of a tenancy's agreed end.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get endsOnLabel;

  /// A date is before the tenancy's start.
  ///
  /// In en, this message translates to:
  /// **'Choose a date on or after the move-in date.'**
  String get validationEndAfterStart;

  /// Label of the monthly rent.
  ///
  /// In en, this message translates to:
  /// **'Monthly rent'**
  String get monthlyRentLabel;

  /// The rent is missing or zero.
  ///
  /// In en, this message translates to:
  /// **'Enter the rent, an amount above 0.'**
  String get validationRent;

  /// Label of the security deposit.
  ///
  /// In en, this message translates to:
  /// **'Security deposit'**
  String get depositLabel;

  /// Label of the increment interval.
  ///
  /// In en, this message translates to:
  /// **'Increase every (months)'**
  String get incrementEveryLabel;

  /// Label of the late-fee policy.
  ///
  /// In en, this message translates to:
  /// **'Late fee'**
  String get lateFeeLabel;

  /// No late fee.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get lateFeeNone;

  /// A flat late fee.
  ///
  /// In en, this message translates to:
  /// **'A fixed amount'**
  String get lateFeeFlat;

  /// A percentage late fee.
  ///
  /// In en, this message translates to:
  /// **'A percent of the late rent'**
  String get lateFeePercent;

  /// A daily late fee.
  ///
  /// In en, this message translates to:
  /// **'An amount per day late'**
  String get lateFeeDaily;

  /// Label of a late fee amount.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get lateFeeAmountLabel;

  /// Label of a late fee percentage.
  ///
  /// In en, this message translates to:
  /// **'Fee (%)'**
  String get lateFeePercentLabel;

  /// Label of a daily late fee's cap.
  ///
  /// In en, this message translates to:
  /// **'At most'**
  String get lateFeeCapLabel;

  /// Under the late fee choice.
  ///
  /// In en, this message translates to:
  /// **'Charged once the grace days have passed.'**
  String get lateFeeHelp;

  /// Label of the notice period.
  ///
  /// In en, this message translates to:
  /// **'Notice period (days)'**
  String get noticeDaysLabel;

  /// Whether the first month is prorated.
  ///
  /// In en, this message translates to:
  /// **'Charge only the days of the first month'**
  String get prorateLabel;

  /// Under the proration switch.
  ///
  /// In en, this message translates to:
  /// **'When the tenant moves in after the 1st.'**
  String get prorateHelp;

  /// Label of the billing start date.
  ///
  /// In en, this message translates to:
  /// **'Bill from'**
  String get billingStartsLabel;

  /// Explains the billing start.
  ///
  /// In en, this message translates to:
  /// **'For a tenancy that began before you used the app: the first day the app should bill.'**
  String get billingStartsHelp;

  /// Label of the agreement's signing date.
  ///
  /// In en, this message translates to:
  /// **'Agreement signed on'**
  String get agreementSignedLabel;

  /// Label of the e-stamp paper number.
  ///
  /// In en, this message translates to:
  /// **'E-stamp number'**
  String get eStampNumberLabel;

  /// Label of the e-stamp duty paid.
  ///
  /// In en, this message translates to:
  /// **'E-stamp amount'**
  String get eStampAmountLabel;

  /// Label of what the unit may be used for.
  ///
  /// In en, this message translates to:
  /// **'Permitted use'**
  String get permittedUseLabel;

  /// Whether subletting is allowed.
  ///
  /// In en, this message translates to:
  /// **'Subletting allowed'**
  String get sublettingLabel;

  /// Label of the Rent Registrar status.
  ///
  /// In en, this message translates to:
  /// **'Rent Registrar (Punjab)'**
  String get registrarStatusLabel;

  /// Rent Registrar status.
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get registrarNotApplicable;

  /// Rent Registrar status.
  ///
  /// In en, this message translates to:
  /// **'Not presented'**
  String get registrarNotPresented;

  /// Rent Registrar status.
  ///
  /// In en, this message translates to:
  /// **'Presented'**
  String get registrarPresented;

  /// Rent Registrar or police status.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get registrarRegistered;

  /// Label of the Rent Registrar office.
  ///
  /// In en, this message translates to:
  /// **'Registrar office'**
  String get registrarOfficeLabel;

  /// Label of a registration number.
  ///
  /// In en, this message translates to:
  /// **'Registration number'**
  String get registrationNumberLabel;

  /// Label of a registration date.
  ///
  /// In en, this message translates to:
  /// **'Registered on'**
  String get registeredOnLabel;

  /// Label of the police registration status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get policeStatusLabel;

  /// Police registration status.
  ///
  /// In en, this message translates to:
  /// **'Not required'**
  String get policeNotRequired;

  /// Police registration status.
  ///
  /// In en, this message translates to:
  /// **'Not registered yet'**
  String get policePending;

  /// Police registration status.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get policeSubmitted;

  /// Label of the police registration channel.
  ///
  /// In en, this message translates to:
  /// **'Registered through'**
  String get policeChannelLabel;

  /// A registration channel.
  ///
  /// In en, this message translates to:
  /// **'Online portal'**
  String get channelOnlinePortal;

  /// A registration channel: a police service centre.
  ///
  /// In en, this message translates to:
  /// **'Khidmat Markaz'**
  String get channelKhidmatMarkaz;

  /// A registration channel.
  ///
  /// In en, this message translates to:
  /// **'Police station'**
  String get channelPoliceStation;

  /// Label of the police station.
  ///
  /// In en, this message translates to:
  /// **'Police station'**
  String get policeStationLabel;

  /// Label of the police reference number.
  ///
  /// In en, this message translates to:
  /// **'Reference number'**
  String get policeReferenceLabel;

  /// Label of the police registration fee.
  ///
  /// In en, this message translates to:
  /// **'Fee paid'**
  String get policeFeeLabel;

  /// A statutory police-registration deadline.
  ///
  /// In en, this message translates to:
  /// **'The law\'s deadline: {date}'**
  String policeLegalDeadline(String date);

  /// The app's police-registration reminder date.
  ///
  /// In en, this message translates to:
  /// **'The app\'s reminder: {date}'**
  String policeReminderDate(String date);

  /// Explains a non-statutory reminder.
  ///
  /// In en, this message translates to:
  /// **'No law the app knows of sets a deadline here: this is only a reminder.'**
  String get policeReminderNote;

  /// Police registration is late.
  ///
  /// In en, this message translates to:
  /// **'Past the deadline: register it now.'**
  String get policeLate;

  /// Opens the police registration portal.
  ///
  /// In en, this message translates to:
  /// **'Open the registration website'**
  String get openPortalAction;

  /// Label of who pays the utilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilitiesNoteLabel;

  /// After starting a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Tenancy started for {tenant}.'**
  String tenancyStarted(String tenant);

  /// After saving a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Tenancy terms saved.'**
  String get tenancySaved;

  /// Tenancies of a unit overlap.
  ///
  /// In en, this message translates to:
  /// **'The unit is let for some of these dates. End the other tenancy first, or choose other dates.'**
  String get reasonLeaseOverlap;

  /// Heading of a tenancy's terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get tenancyTermsSection;

  /// When rent is due.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of each month'**
  String dueDayValue(int day);

  /// A percentage.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String percentValue(String percent);

  /// A rent increase and how often.
  ///
  /// In en, this message translates to:
  /// **'{percent}% every {months, plural, =1{month} other{{months} months}}'**
  String everyMonths(String percent, int months);

  /// A tenancy without an end.
  ///
  /// In en, this message translates to:
  /// **'Month to month'**
  String get periodicValue;

  /// Heading of a tenancy's occupants.
  ///
  /// In en, this message translates to:
  /// **'People living there'**
  String get occupantsSection;

  /// Under the occupants heading.
  ///
  /// In en, this message translates to:
  /// **'Adults living with the tenant, needed for police registration.'**
  String get occupantsHelp;

  /// Adds an occupant.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get addOccupantAction;

  /// Title of the occupant sheet.
  ///
  /// In en, this message translates to:
  /// **'Person living there'**
  String get occupantTitle;

  /// After saving an occupant.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String occupantSaved(String name);

  /// Removes something.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// Confirmation before removing an occupant.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeOccupantTitle(String name);

  /// What removing an occupant does.
  ///
  /// In en, this message translates to:
  /// **'They are taken off this tenancy.'**
  String get removeOccupantBody;

  /// No occupants.
  ///
  /// In en, this message translates to:
  /// **'No one added yet.'**
  String get noOccupants;

  /// Heading of the rent changes.
  ///
  /// In en, this message translates to:
  /// **'Rent history'**
  String get rentHistorySection;

  /// When a rent applies from.
  ///
  /// In en, this message translates to:
  /// **'From {month}'**
  String rentFrom(String month);

  /// Why the rent is what it is.
  ///
  /// In en, this message translates to:
  /// **'Starting rent'**
  String get rentReasonInitial;

  /// Why the rent changed.
  ///
  /// In en, this message translates to:
  /// **'Yearly increase'**
  String get rentReasonAnnualIncrement;

  /// Why the rent changed.
  ///
  /// In en, this message translates to:
  /// **'Agreed change'**
  String get rentReasonRenegotiation;

  /// Why the rent changed.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get rentReasonCorrection;

  /// Opens the rent change sheet.
  ///
  /// In en, this message translates to:
  /// **'Change rent'**
  String get changeRentAction;

  /// Label of the month a new rent applies from.
  ///
  /// In en, this message translates to:
  /// **'From the month of'**
  String get changeRentFromLabel;

  /// Label of the new rent.
  ///
  /// In en, this message translates to:
  /// **'New monthly rent'**
  String get newRentLabel;

  /// Label of a reason choice.
  ///
  /// In en, this message translates to:
  /// **'Why'**
  String get changeReasonLabel;

  /// Label of a note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get rentNoteLabel;

  /// The suggested new rent.
  ///
  /// In en, this message translates to:
  /// **'At the agreed {percent}%, rounded to Rs 100: {rent}'**
  String suggestedIncrement(String percent, String rent);

  /// Fills in the suggested rent.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get useSuggestionAction;

  /// What changing the rent does.
  ///
  /// In en, this message translates to:
  /// **'Unpaid rent of that month and later is re-priced; months already paid keep their amount.'**
  String get changeRentHelp;

  /// After changing the rent.
  ///
  /// In en, this message translates to:
  /// **'Rent changed to {rent} from {month}.'**
  String rentChanged(String rent, String month);

  /// Opens the end-tenancy sheet.
  ///
  /// In en, this message translates to:
  /// **'End tenancy'**
  String get endTenancyAction;

  /// Label of the move-out date.
  ///
  /// In en, this message translates to:
  /// **'Moved out on'**
  String get movedOutLabel;

  /// Why a tenancy ended.
  ///
  /// In en, this message translates to:
  /// **'The term ended'**
  String get endTermCompleted;

  /// Why a tenancy ended.
  ///
  /// In en, this message translates to:
  /// **'The tenant moved out'**
  String get endTenantMovedOut;

  /// Why a tenancy ended.
  ///
  /// In en, this message translates to:
  /// **'Eviction'**
  String get endEviction;

  /// Why a tenancy ended.
  ///
  /// In en, this message translates to:
  /// **'Both agreed'**
  String get endMutualAgreement;

  /// What ending a tenancy does to its money.
  ///
  /// In en, this message translates to:
  /// **'Rent is billed through the month of moving out. The rent of every later month, and its automatic late fees, is voided, paid or not. Money that paid them is released and applied to the tenancy\'s other dues; what is left stays as the tenant\'s credit, to refund. The unit becomes vacant.'**
  String get endTenancyExplain;

  /// After ending a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Tenancy ended.'**
  String get tenancyEnded;

  /// Label of when a tenancy ended.
  ///
  /// In en, this message translates to:
  /// **'Ended on'**
  String get endedOnLabel;

  /// Confirmation before deleting a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Delete this tenancy?'**
  String get deleteTenancyTitle;

  /// What deleting a tenancy does.
  ///
  /// In en, this message translates to:
  /// **'Only for a tenancy entered by mistake: it goes with the dues it generated, as long as nothing was paid, waived or voided. Otherwise end the tenancy instead.'**
  String get deleteTenancyBody;

  /// After deleting a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Tenancy deleted.'**
  String get tenancyDeleted;

  /// A tenancy failed to load.
  ///
  /// In en, this message translates to:
  /// **'This tenancy could not be loaded'**
  String get tenancyLoadFailedTitle;

  /// Screen-reader label of a tenancy's skeleton.
  ///
  /// In en, this message translates to:
  /// **'Loading the tenancy'**
  String get loadingTenancy;

  /// No tenancies.
  ///
  /// In en, this message translates to:
  /// **'No tenancies yet.'**
  String get tenanciesEmpty;

  /// Tenancies failed to load.
  ///
  /// In en, this message translates to:
  /// **'The tenancies could not be loaded'**
  String get tenanciesLoadFailedTitle;

  /// A number of months.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String monthCount(int count);

  /// Tooltip of the button that lowers months.
  ///
  /// In en, this message translates to:
  /// **'Fewer months'**
  String get fewerMonthsAction;

  /// Tooltip of the button that raises months.
  ///
  /// In en, this message translates to:
  /// **'More months'**
  String get moreMonthsAction;
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
