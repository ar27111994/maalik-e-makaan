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

  /// Settings section: about the app, with its open-source licences.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Button that opens the licences of the open-source software, fonts and icons the app uses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get licencesAction;

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

  /// Heading of a record's documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsSection;

  /// Under the documents heading: what is kept and who sees it.
  ///
  /// In en, this message translates to:
  /// **'Photos and PDFs, seen only by this portfolio\'s team.'**
  String get documentsSectionHelp;

  /// Button and sheet title for adding a document.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get addDocumentAction;

  /// A record without documents.
  ///
  /// In en, this message translates to:
  /// **'No documents yet.'**
  String get documentsEmpty;

  /// A tenant without documents, when the member may add them: what to add.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Add photos of the CNIC, front and back.'**
  String get documentsEmptyTenant;

  /// A tenancy without documents, when the member may add them: what to add.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Add the signed agreement and the police registration.'**
  String get documentsEmptyLease;

  /// A unit without documents, when the member may add them: what to add.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Add photos of the unit and its meters.'**
  String get documentsEmptyUnit;

  /// A property without documents, when the member may add them: what to add.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Add the property papers and photos.'**
  String get documentsEmptyProperty;

  /// Spoken while documents load.
  ///
  /// In en, this message translates to:
  /// **'Loading documents'**
  String get loadingDocuments;

  /// Heading when the documents fail to load.
  ///
  /// In en, this message translates to:
  /// **'Documents could not be loaded'**
  String get documentsLoadFailedTitle;

  /// Kind of document: the front of a CNIC.
  ///
  /// In en, this message translates to:
  /// **'CNIC, front'**
  String get documentKindCnicFront;

  /// Kind of document: the back of a CNIC.
  ///
  /// In en, this message translates to:
  /// **'CNIC, back'**
  String get documentKindCnicBack;

  /// Kind of document: a photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get documentKindPhoto;

  /// Kind of document: the signed tenancy agreement.
  ///
  /// In en, this message translates to:
  /// **'Tenancy agreement'**
  String get documentKindTenancyAgreement;

  /// Kind of document: the police tenant-registration form or slip.
  ///
  /// In en, this message translates to:
  /// **'Police registration'**
  String get documentKindPoliceRegistration;

  /// Kind of document: a tenancy registered with a government office.
  ///
  /// In en, this message translates to:
  /// **'Rent registration'**
  String get documentKindRentRegistration;

  /// Kind of document: an electricity, gas or water bill.
  ///
  /// In en, this message translates to:
  /// **'Utility bill'**
  String get documentKindUtilityBill;

  /// Kind of document: a receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get documentKindReceipt;

  /// Kind of document: a vendor's invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get documentKindInvoice;

  /// Kind of document: a photo of a meter reading.
  ///
  /// In en, this message translates to:
  /// **'Meter photo'**
  String get documentKindMeterPhoto;

  /// Kind of document: ownership papers of a property.
  ///
  /// In en, this message translates to:
  /// **'Property papers'**
  String get documentKindPropertyPaper;

  /// Kind of document: anything else.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get documentKindOther;

  /// A file's type.
  ///
  /// In en, this message translates to:
  /// **'JPEG photo'**
  String get fileTypeJpeg;

  /// A file's type.
  ///
  /// In en, this message translates to:
  /// **'PNG image'**
  String get fileTypePng;

  /// A file's type.
  ///
  /// In en, this message translates to:
  /// **'WebP image'**
  String get fileTypeWebp;

  /// A file's type.
  ///
  /// In en, this message translates to:
  /// **'HEIC photo'**
  String get fileTypeHeic;

  /// A file's type.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get fileTypePdf;

  /// A file's format, short, in a list row.
  ///
  /// In en, this message translates to:
  /// **'JPEG'**
  String get fileFormatJpeg;

  /// A file's format, short, in a list row.
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get fileFormatPng;

  /// A file's format, short, in a list row.
  ///
  /// In en, this message translates to:
  /// **'WebP'**
  String get fileFormatWebp;

  /// A file's format, short, in a list row.
  ///
  /// In en, this message translates to:
  /// **'HEIC'**
  String get fileFormatHeic;

  /// A file's format, short, in a list row.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get fileFormatPdf;

  /// A file's size in kilobytes.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String fileSizeKb(String size);

  /// A file's size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String fileSizeMb(String size);

  /// Button that opens the camera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhotoAction;

  /// Button that opens the device's files.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get chooseFileAction;

  /// Button that replaces the chosen file.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get chooseAnotherFileAction;

  /// What can be added.
  ///
  /// In en, this message translates to:
  /// **'Add a photo, or a PDF of up to 10 MB. Photos are made smaller first.'**
  String get addDocumentHelp;

  /// Spoken while a picked file is checked and made smaller.
  ///
  /// In en, this message translates to:
  /// **'Getting the file ready'**
  String get preparingFile;

  /// At the top of the add-document sheet when it opens by itself with a camera photo that Android kept after closing the app; nothing is uploaded until the landlord taps Upload.
  ///
  /// In en, this message translates to:
  /// **'The app closed while the camera was open, but your photo was kept. Check it, then upload it.'**
  String get photoRecovered;

  /// Snackbar when the app starts again with a camera photo that Android kept after closing the app, and the landlord has already moved to another screen; its action (photoKeptAction) takes them to the photo.
  ///
  /// In en, this message translates to:
  /// **'The app closed while the camera was open, but your photo was kept.'**
  String get photoKeptOffer;

  /// Action of the photoKeptOffer snackbar: goes to the record the photo was taken for and opens it in the add-document sheet, where nothing is uploaded until the landlord taps Upload.
  ///
  /// In en, this message translates to:
  /// **'Show photo'**
  String get photoKeptAction;

  /// Label of a document's kind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get documentKindLabel;

  /// Label of a document's name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get documentNameLabel;

  /// Helper under a document's name.
  ///
  /// In en, this message translates to:
  /// **'Left empty, it is named after its kind.'**
  String get documentNameHelp;

  /// Button that uploads a document.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadAction;

  /// A photo was compressed before upload.
  ///
  /// In en, this message translates to:
  /// **'Made smaller from {from} to {to}.'**
  String documentCompressed(String from, String to);

  /// After uploading a document.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String documentAdded(String name);

  /// After renaming a document.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String documentSaved(String name);

  /// After deleting a document.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String documentDeleted(String name);

  /// Button that opens a document's file.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openDocumentAction;

  /// Button that downloads a document's file.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadDocumentAction;

  /// Button that edits a document.
  ///
  /// In en, this message translates to:
  /// **'Rename or change kind'**
  String get editDocumentAction;

  /// Confirming deleting a document.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteDocumentTitle(String name);

  /// What deleting a document does.
  ///
  /// In en, this message translates to:
  /// **'The document and its file are deleted for everyone in this portfolio. This cannot be undone.'**
  String get deleteDocumentBody;

  /// Label of the date a document was added.
  ///
  /// In en, this message translates to:
  /// **'Added on'**
  String get documentAddedOnLabel;

  /// Label of a document's file type and size.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get documentFileLabel;

  /// Spoken for the picture of a photo about to be uploaded.
  ///
  /// In en, this message translates to:
  /// **'Preview of the photo'**
  String get documentPreviewLabel;

  /// A document name longer than the database takes (it counts letters and their marks separately).
  ///
  /// In en, this message translates to:
  /// **'This name is too long. Shorten it.'**
  String get documentNameTooLong;

  /// A file too large for the bucket.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than 10 MB. Choose a smaller one, or take a photo of it.'**
  String get reasonFileTooLarge;

  /// A file of a type the bucket refuses.
  ///
  /// In en, this message translates to:
  /// **'Only photos (JPEG, PNG, WebP or HEIC) and PDFs can be added.'**
  String get reasonFileTypeNotAllowed;

  /// A photo whose file is damaged, so it could not be checked.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read. Choose another file, or take a photo of the paper.'**
  String get reasonFileUnreadable;

  /// The camera or files were refused to the app.
  ///
  /// In en, this message translates to:
  /// **'Maalik-e-Makaan may not use the camera or your files. Allow it in your phone\'s settings.'**
  String get reasonPickerAccessDenied;

  /// The camera was not opened: the phone could not clear what it kept about an earlier photo, so a photo taken now could end up on the wrong record.
  ///
  /// In en, this message translates to:
  /// **'Your phone could not get ready to take a photo. Try again, or choose a file instead.'**
  String get reasonCameraNotReady;

  /// A charge for rent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get chargeKindRent;

  /// A charge for the security deposit.
  ///
  /// In en, this message translates to:
  /// **'Security deposit'**
  String get chargeKindDeposit;

  /// A charge for electricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get chargeKindElectricity;

  /// A charge for gas.
  ///
  /// In en, this message translates to:
  /// **'Gas'**
  String get chargeKindGas;

  /// A charge for water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get chargeKindWater;

  /// A charge for internet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get chargeKindInternet;

  /// A charge for maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get chargeKindMaintenance;

  /// A charge for a housing society's fees.
  ///
  /// In en, this message translates to:
  /// **'Society charges'**
  String get chargeKindSociety;

  /// A late fee.
  ///
  /// In en, this message translates to:
  /// **'Late fee'**
  String get chargeKindLateFee;

  /// A charge for damage to the property.
  ///
  /// In en, this message translates to:
  /// **'Damages'**
  String get chargeKindDamages;

  /// A charge of another kind.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get chargeKindOther;

  /// Paid in cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// Paid by bank transfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get methodBankTransfer;

  /// Paid through Raast, the State Bank's instant payments.
  ///
  /// In en, this message translates to:
  /// **'Raast'**
  String get methodRaast;

  /// Paid through JazzCash.
  ///
  /// In en, this message translates to:
  /// **'JazzCash'**
  String get methodJazzCash;

  /// Paid through Easypaisa.
  ///
  /// In en, this message translates to:
  /// **'Easypaisa'**
  String get methodEasypaisa;

  /// Paid by cheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get methodCheque;

  /// Paid by card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get methodCard;

  /// Settled from the security deposit.
  ///
  /// In en, this message translates to:
  /// **'From the deposit'**
  String get methodDeposit;

  /// Paid another way.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get methodOther;

  /// Label of the payment method field.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get methodLabel;

  /// A due and its month: "Rent, November 2026".
  ///
  /// In en, this message translates to:
  /// **'{kind}, {month}'**
  String chargeForMonth(String kind, String month);

  /// A due past its date, with how long.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Overdue 1 day} other{Overdue {days} days}}'**
  String overdueDays(int days);

  /// A due whose date is today.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// A due falling due soon.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Due tomorrow} other{Due in {days} days}}'**
  String dueInDays(int days);

  /// A due falling due later.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(String date);

  /// A due paid in full.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get chargePaid;

  /// A due forgiven.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get chargeWaived;

  /// A due, payment or handover cancelled with a reason.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get chargeVoided;

  /// Read while the list loads.
  ///
  /// In en, this message translates to:
  /// **'Loading who owes what'**
  String get loadingReceivables;

  /// Heading when the list fails to load.
  ///
  /// In en, this message translates to:
  /// **'The money owed could not be loaded'**
  String get receivablesLoadFailedTitle;

  /// Empty Money screen.
  ///
  /// In en, this message translates to:
  /// **'No money is owed yet'**
  String get receivablesEmptyTitle;

  /// Empty Money screen.
  ///
  /// In en, this message translates to:
  /// **'Rent is billed for each tenancy you start. What tenants owe and pay shows here.'**
  String get receivablesEmptyBody;

  /// Stat: what all tenants owe.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get totalOwedLabel;

  /// Stat: what is owed past its date.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get totalOverdueLabel;

  /// Stat: advances tenants have paid.
  ///
  /// In en, this message translates to:
  /// **'Credit held'**
  String get totalCreditLabel;

  /// Heading of the receivables list.
  ///
  /// In en, this message translates to:
  /// **'Who owes what'**
  String get whoOwesSection;

  /// Help under the receivables heading.
  ///
  /// In en, this message translates to:
  /// **'The longest overdue first.'**
  String get whoOwesHelp;

  /// When no tenancy owes.
  ///
  /// In en, this message translates to:
  /// **'Nobody owes anything now.'**
  String get nobodyOwes;

  /// Heading of tenancies that owe nothing.
  ///
  /// In en, this message translates to:
  /// **'Settled or in credit'**
  String get settledSection;

  /// When a tenant last paid.
  ///
  /// In en, this message translates to:
  /// **'Last paid {date}'**
  String lastPaidOn(String date);

  /// Badge: owes an amount not yet late.
  ///
  /// In en, this message translates to:
  /// **'Owes {amount}'**
  String owesAmount(String amount);

  /// Badge: what is overdue, and how long the oldest overdue due has been late.
  ///
  /// In en, this message translates to:
  /// **'{amount} overdue, oldest {days, plural, =1{1 day} other{{days} days}}'**
  String overdueOldest(String amount, int days);

  /// Badge: holds credit.
  ///
  /// In en, this message translates to:
  /// **'Credit {amount}'**
  String creditAmount(String amount);

  /// Badge: owes nothing.
  ///
  /// In en, this message translates to:
  /// **'All paid'**
  String get allPaid;

  /// Title of the cash book.
  ///
  /// In en, this message translates to:
  /// **'Cash in hand'**
  String get cashBookTitle;

  /// Title of a tenancy's ledger while it loads.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledgerTitle;

  /// Read while a ledger loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the ledger'**
  String get loadingLedger;

  /// Heading when a ledger fails to load.
  ///
  /// In en, this message translates to:
  /// **'This ledger could not be loaded'**
  String get ledgerLoadFailedTitle;

  /// Action: make the statement PDF.
  ///
  /// In en, this message translates to:
  /// **'Tenant statement'**
  String get statementAction;

  /// Label of what a tenancy owes.
  ///
  /// In en, this message translates to:
  /// **'Owed now'**
  String get owedNowLabel;

  /// What a tenancy owes, in a list row.
  ///
  /// In en, this message translates to:
  /// **'Owed now: {amount}'**
  String owedNowValue(String amount);

  /// Label of what is owed past its date.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueLabel;

  /// Label of money paid in advance.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get creditLabel;

  /// Said after a credit amount.
  ///
  /// In en, this message translates to:
  /// **'credit'**
  String get creditWord;

  /// Label of the last payment date.
  ///
  /// In en, this message translates to:
  /// **'Last paid'**
  String get lastPaidLabel;

  /// Label of when the tenant was last reminded.
  ///
  /// In en, this message translates to:
  /// **'Last reminded'**
  String get lastRemindedLabel;

  /// Explains credit on a running tenancy.
  ///
  /// In en, this message translates to:
  /// **'The tenant has paid ahead. The credit settles the next dues by itself.'**
  String get creditExplainActive;

  /// Explains credit on an ended tenancy.
  ///
  /// In en, this message translates to:
  /// **'The tenancy has ended with money left over. Refund it to the tenant, or void the payment it came from.'**
  String get creditExplainEnded;

  /// Credit on an ended tenancy, said to members who cannot correct money.
  ///
  /// In en, this message translates to:
  /// **'The tenancy has ended and the tenant has {amount} in credit.'**
  String creditHeldEnded(String amount);

  /// Opens the receipt of the payment the credit came from.
  ///
  /// In en, this message translates to:
  /// **'Open the payment'**
  String get openCreditPaymentAction;

  /// Action: record money received.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPaymentAction;

  /// Action: open the reminder composer.
  ///
  /// In en, this message translates to:
  /// **'Remind on WhatsApp'**
  String get remindAction;

  /// Row leading to the tenancy screen.
  ///
  /// In en, this message translates to:
  /// **'Tenancy details'**
  String get openTenancyAction;

  /// Heading of the open dues.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get openDuesSection;

  /// Help under the open dues heading.
  ///
  /// In en, this message translates to:
  /// **'Every due not yet paid, the oldest first.'**
  String get openDuesHelp;

  /// Action: add a charge by hand.
  ///
  /// In en, this message translates to:
  /// **'Add charge'**
  String get addChargeAction;

  /// When no due is open.
  ///
  /// In en, this message translates to:
  /// **'Nothing is owed.'**
  String get noOpenDues;

  /// A due partly paid.
  ///
  /// In en, this message translates to:
  /// **'{left} left of {amount}'**
  String leftOfAmount(String left, String amount);

  /// Heading of payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsSection;

  /// When there are no payments.
  ///
  /// In en, this message translates to:
  /// **'No payments yet.'**
  String get noPaymentsYet;

  /// A payment's receipt number in a row.
  ///
  /// In en, this message translates to:
  /// **'Receipt {number}'**
  String receiptNumbered(String number);

  /// Tax withheld with a payment.
  ///
  /// In en, this message translates to:
  /// **'{amount} tax withheld'**
  String withTax(String amount);

  /// Heading of every due.
  ///
  /// In en, this message translates to:
  /// **'All dues'**
  String get allDuesSection;

  /// Help under the all dues heading.
  ///
  /// In en, this message translates to:
  /// **'Paid, waived and voided too, the newest first.'**
  String get allDuesHelp;

  /// When a tenancy has no dues.
  ///
  /// In en, this message translates to:
  /// **'No dues yet.'**
  String get noDuesYet;

  /// Heading of a tenancy's money on its screen.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get moneySection;

  /// Action: open a tenancy's ledger.
  ///
  /// In en, this message translates to:
  /// **'Open the ledger'**
  String get openLedgerAction;

  /// Label of an amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// Label of the amount paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLabel;

  /// Label of what is left of a due.
  ///
  /// In en, this message translates to:
  /// **'Still owed'**
  String get stillOwedLabel;

  /// Label of a due's date.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDateLabel;

  /// Label of a due's note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get chargeNoteLabel;

  /// Label of the waive reason.
  ///
  /// In en, this message translates to:
  /// **'Why it was waived'**
  String get waiveReasonLabel;

  /// Label of the void reason.
  ///
  /// In en, this message translates to:
  /// **'Why it was voided'**
  String get voidReasonLabel;

  /// Action: edit a due.
  ///
  /// In en, this message translates to:
  /// **'Edit charge'**
  String get editChargeAction;

  /// Action: forgive a due.
  ///
  /// In en, this message translates to:
  /// **'Waive'**
  String get waiveChargeAction;

  /// Action: cancel a due.
  ///
  /// In en, this message translates to:
  /// **'Void charge'**
  String get voidChargeAction;

  /// Why a paid due cannot be voided.
  ///
  /// In en, this message translates to:
  /// **'Money was received for this due, so it cannot be voided. Void that payment first, or waive what is left.'**
  String get voidChargeHasPayments;

  /// After editing a due.
  ///
  /// In en, this message translates to:
  /// **'Charge saved.'**
  String get chargeSaved;

  /// Why a generated due's amount cannot change.
  ///
  /// In en, this message translates to:
  /// **'Rent, late fees and the deposit keep the amount the tenancy\'s terms set. Change the rent, or void this due and add a new one.'**
  String get chargeAmountFixed;

  /// A due's amount floor.
  ///
  /// In en, this message translates to:
  /// **'At least {amount}, already paid or waived.'**
  String amountAtLeast(String amount);

  /// An amount ceiling.
  ///
  /// In en, this message translates to:
  /// **'At most {amount}.'**
  String amountAtMost(String amount);

  /// Label of the kind of a new charge.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get chargeKindLabel;

  /// Label of a charge's month.
  ///
  /// In en, this message translates to:
  /// **'For the month of'**
  String get chargeMonthLabel;

  /// Help of a charge's month.
  ///
  /// In en, this message translates to:
  /// **'The month a bill is for, if it has one.'**
  String get chargeMonthHelp;

  /// Choice: no month.
  ///
  /// In en, this message translates to:
  /// **'No month'**
  String get noMonthOption;

  /// After adding a charge.
  ///
  /// In en, this message translates to:
  /// **'{kind} added.'**
  String chargeAdded(String kind);

  /// Explains waiving.
  ///
  /// In en, this message translates to:
  /// **'Waiving forgives what is still owed (or the part you type). The due stays in the ledger, marked waived, with your reason.'**
  String get waiveExplain;

  /// Explains voiding a due.
  ///
  /// In en, this message translates to:
  /// **'Voiding cancels a due entered by mistake, with its unpaid late fee. It stays in the ledger, marked voided, with your reason.'**
  String get voidChargeExplain;

  /// Label of the amount to waive.
  ///
  /// In en, this message translates to:
  /// **'Amount to waive'**
  String get waiveAmountLabel;

  /// Help of the amount to waive.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to waive all {amount}.'**
  String waiveAmountHelp(String amount);

  /// Label of a reason field.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// After waiving.
  ///
  /// In en, this message translates to:
  /// **'Due waived.'**
  String get chargeWaivedDone;

  /// After voiding a due.
  ///
  /// In en, this message translates to:
  /// **'Due voided.'**
  String get chargeVoidedDone;

  /// Heading of the deposit.
  ///
  /// In en, this message translates to:
  /// **'Security deposit'**
  String get depositSection;

  /// Deposit agreed.
  ///
  /// In en, this message translates to:
  /// **'Agreed'**
  String get depositAgreedLabel;

  /// Deposit received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get depositReceivedLabel;

  /// Deposit used to settle dues.
  ///
  /// In en, this message translates to:
  /// **'Used for dues'**
  String get depositAppliedLabel;

  /// Deposit paid back.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get depositRefundedLabel;

  /// Deposit still held.
  ///
  /// In en, this message translates to:
  /// **'Deposit held'**
  String get depositHeldLabel;

  /// Nudge to settle the deposit at move-out.
  ///
  /// In en, this message translates to:
  /// **'The tenancy has ended and you still hold the deposit. Use it for what is owed, then refund the rest.'**
  String get depositSettleAfterEnd;

  /// Warning before using or refunding the deposit of a running tenancy.
  ///
  /// In en, this message translates to:
  /// **'This tenancy is still running. The deposit is usually used for dues or refunded when the tenant moves out.'**
  String get depositTenancyActive;

  /// Action: settle dues from the deposit.
  ///
  /// In en, this message translates to:
  /// **'Use for dues'**
  String get applyDepositAction;

  /// Action: pay the deposit back.
  ///
  /// In en, this message translates to:
  /// **'Refund deposit'**
  String get refundDepositAction;

  /// A deposit refund in a list.
  ///
  /// In en, this message translates to:
  /// **'Refund of {amount}'**
  String refundOf(String amount);

  /// Why something was voided.
  ///
  /// In en, this message translates to:
  /// **'Voided: {reason}'**
  String voidedBecause(String reason);

  /// Action: void a refund.
  ///
  /// In en, this message translates to:
  /// **'Void refund'**
  String get voidRefundAction;

  /// Explains voiding a refund.
  ///
  /// In en, this message translates to:
  /// **'Voiding a refund recorded by mistake counts that money as held again. It stays in the ledger, marked voided.'**
  String get voidRefundExplain;

  /// After voiding a refund.
  ///
  /// In en, this message translates to:
  /// **'Refund voided.'**
  String get refundVoided;

  /// Explains using the deposit.
  ///
  /// In en, this message translates to:
  /// **'The deposit settles what is owed, the oldest first, and the tenant gets a receipt for it.'**
  String get applyDepositExplain;

  /// Help of the amount to use.
  ///
  /// In en, this message translates to:
  /// **'Held {held}; owed {owed}.'**
  String applyDepositHelp(String held, String owed);

  /// Label of the date the deposit was used.
  ///
  /// In en, this message translates to:
  /// **'Used on'**
  String get appliedOnLabel;

  /// After using the deposit.
  ///
  /// In en, this message translates to:
  /// **'{amount} of the deposit settled dues.'**
  String depositApplied(String amount);

  /// Help of the refund amount.
  ///
  /// In en, this message translates to:
  /// **'You hold {amount}.'**
  String depositHeldHelp(String amount);

  /// Label of the refund date.
  ///
  /// In en, this message translates to:
  /// **'Refunded on'**
  String get refundedOnLabel;

  /// After a refund.
  ///
  /// In en, this message translates to:
  /// **'{amount} of the deposit refunded.'**
  String depositRefunded(String amount);

  /// Title of the payment form.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPaymentTitle;

  /// Form section: the money.
  ///
  /// In en, this message translates to:
  /// **'What was received'**
  String get paymentSectionMoney;

  /// Form section: s.155 tax.
  ///
  /// In en, this message translates to:
  /// **'Tax withheld'**
  String get paymentSectionTax;

  /// Form section: which dues.
  ///
  /// In en, this message translates to:
  /// **'What it pays for'**
  String get paymentSectionSettle;

  /// Label of the amount received.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get amountReceivedLabel;

  /// Action: fill in what is owed.
  ///
  /// In en, this message translates to:
  /// **'Use {amount} owed'**
  String useOwedAction(String amount);

  /// Label of the payment date.
  ///
  /// In en, this message translates to:
  /// **'Received on'**
  String get receivedOnLabel;

  /// Label of a payment's reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get paymentReferenceLabel;

  /// Help of the reference.
  ///
  /// In en, this message translates to:
  /// **'A transaction ID or cheque number, if there is one.'**
  String get paymentReferenceHelp;

  /// Switch: tax was withheld.
  ///
  /// In en, this message translates to:
  /// **'The tenant withheld income tax'**
  String get taxWithheldSwitch;

  /// Explains s.155 withholding.
  ///
  /// In en, this message translates to:
  /// **'Companies and government offices deduct tax under section 155 and give a certificate. The cash and the tax together settle the rent.'**
  String get taxWithheldHelp;

  /// Label of the tax withheld.
  ///
  /// In en, this message translates to:
  /// **'Tax withheld (s.155)'**
  String get taxWithheldLabel;

  /// Label of the tax certificate number.
  ///
  /// In en, this message translates to:
  /// **'Certificate or CPR number'**
  String get taxCertificateLabel;

  /// How cash and tax add up.
  ///
  /// In en, this message translates to:
  /// **'{cash} received and {tax} withheld settle {total} of dues.'**
  String taxSettlesGross(String cash, String tax, String total);

  /// Paying with nothing owed.
  ///
  /// In en, this message translates to:
  /// **'Nothing is owed now: this payment is kept as credit for the next dues.'**
  String get noOpenDuesCredit;

  /// Label of how to allocate.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get settleLabel;

  /// Choice: oldest first.
  ///
  /// In en, this message translates to:
  /// **'The oldest dues first'**
  String get settleOldestFirst;

  /// Choice: chosen dues.
  ///
  /// In en, this message translates to:
  /// **'The dues I choose'**
  String get settleChosen;

  /// No due chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one due.'**
  String get chooseDuesError;

  /// Heading of the allocation preview.
  ///
  /// In en, this message translates to:
  /// **'This payment settles'**
  String get willSettleHeading;

  /// A due settled in full.
  ///
  /// In en, this message translates to:
  /// **'{charge}, in full'**
  String settledInFull(String charge);

  /// A due settled in part.
  ///
  /// In en, this message translates to:
  /// **'{charge}, in part'**
  String settledInPart(String charge);

  /// What no due takes.
  ///
  /// In en, this message translates to:
  /// **'Kept as credit'**
  String get creditKeptLabel;

  /// Payment all credit.
  ///
  /// In en, this message translates to:
  /// **'All {amount} is kept as credit for the next dues.'**
  String allCreditExplain(String amount);

  /// Record payment preview: an automatic late fee the payment cancels.
  ///
  /// In en, this message translates to:
  /// **'The late fee of {amount} will be cancelled: this pays its rent in full within the grace period.'**
  String lateFeeCancelledNote(String amount);

  /// After recording a payment.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded. Receipt {number}.'**
  String paymentRecorded(String number);

  /// Title of the receipt screen.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// Read while a receipt loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the receipt'**
  String get loadingReceipt;

  /// Heading when a receipt fails to load.
  ///
  /// In en, this message translates to:
  /// **'This receipt could not be loaded'**
  String get receiptLoadFailedTitle;

  /// Label of a receipt number.
  ///
  /// In en, this message translates to:
  /// **'Receipt no.'**
  String get receiptNumberLabel;

  /// Banner of a voided receipt.
  ///
  /// In en, this message translates to:
  /// **'VOID: cancelled on {date}. {reason}'**
  String receiptVoidedOn(String date, String reason);

  /// Who paid.
  ///
  /// In en, this message translates to:
  /// **'Received from'**
  String get receivedFromLabel;

  /// What the payment is for.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get receiptForLabel;

  /// How it was paid.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get paidByLabel;

  /// Footer of a receipt.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Keep this receipt for your records.'**
  String get receiptFooter;

  /// Action: share the receipt PDF.
  ///
  /// In en, this message translates to:
  /// **'Share receipt'**
  String get shareReceiptAction;

  /// Sharing a receipt whose payment was voided.
  ///
  /// In en, this message translates to:
  /// **'Share voided receipt'**
  String get shareVoidedReceiptAction;

  /// Action: send a payment-received message.
  ///
  /// In en, this message translates to:
  /// **'Thank on WhatsApp'**
  String get sendThanksAction;

  /// Action: void a payment.
  ///
  /// In en, this message translates to:
  /// **'Void payment'**
  String get voidPaymentAction;

  /// Explains voiding a payment.
  ///
  /// In en, this message translates to:
  /// **'Voiding a payment recorded by mistake makes the dues it paid owed again. The receipt keeps its number, marked void, with your reason.'**
  String get voidPaymentExplain;

  /// After voiding a payment.
  ///
  /// In en, this message translates to:
  /// **'Payment voided.'**
  String get paymentVoided;

  /// Label of the PDF language choice.
  ///
  /// In en, this message translates to:
  /// **'Language of the document'**
  String get documentLanguageLabel;

  /// Action: make and share the PDF.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get shareDocumentAction;

  /// Heading of a receipt PDF.
  ///
  /// In en, this message translates to:
  /// **'Rent receipt'**
  String get receiptDocumentTitle;

  /// Void stamp of a receipt PDF.
  ///
  /// In en, this message translates to:
  /// **'VOID'**
  String get receiptVoid;

  /// Void stamp with its reason.
  ///
  /// In en, this message translates to:
  /// **'VOID: {reason}'**
  String receiptVoidBecause(String reason);

  /// Cash plus tax withheld.
  ///
  /// In en, this message translates to:
  /// **'Total, with tax'**
  String get totalSettledLabel;

  /// Heading of the dues a receipt settled.
  ///
  /// In en, this message translates to:
  /// **'Dues settled'**
  String get receiptSettledHeading;

  /// Footer of a PDF.
  ///
  /// In en, this message translates to:
  /// **'Made with Maalik-e-Makaan on {date}.'**
  String documentMadeOn(String date);

  /// Title of a receipt PDF.
  ///
  /// In en, this message translates to:
  /// **'Receipt {number}'**
  String receiptFileTitle(String number);

  /// Heading of a statement PDF.
  ///
  /// In en, this message translates to:
  /// **'Tenant statement'**
  String get statementDocumentTitle;

  /// The period a statement covers.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get statementPeriodLabel;

  /// A range of dates.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String dateRange(String from, String to);

  /// Heading of a statement's totals.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get statementSummaryHeading;

  /// Total billed.
  ///
  /// In en, this message translates to:
  /// **'Billed'**
  String get totalBilledLabel;

  /// Total paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get totalPaidLabel;

  /// Total waived.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get totalWaivedLabel;

  /// What is owed now.
  ///
  /// In en, this message translates to:
  /// **'Owed now'**
  String get balanceOwedLabel;

  /// Heading of a statement's dues.
  ///
  /// In en, this message translates to:
  /// **'Dues'**
  String get statementDuesHeading;

  /// Column: what a due is for.
  ///
  /// In en, this message translates to:
  /// **'What for'**
  String get chargeForLabel;

  /// Column: where a due stands.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get chargeStateLabel;

  /// Heading of a statement's payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get statementPaymentsHeading;

  /// A voided receipt number.
  ///
  /// In en, this message translates to:
  /// **'{number} (void)'**
  String voidedReceipt(String number);

  /// Footer of a statement.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No payments received.} =1{1 payment received.} other{{count} payments received.}} Every receipt number can be checked against the tenant\'s copy.'**
  String statementFooter(int count);

  /// Title of a statement PDF.
  ///
  /// In en, this message translates to:
  /// **'Statement, {tenant}'**
  String statementFileTitle(String tenant);

  /// Title of the composer.
  ///
  /// In en, this message translates to:
  /// **'Remind on WhatsApp'**
  String get reminderTitle;

  /// Label of the template choice.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get reminderTemplateLabel;

  /// Template: upcoming.
  ///
  /// In en, this message translates to:
  /// **'Rent due soon'**
  String get templateUpcoming;

  /// Template: due today.
  ///
  /// In en, this message translates to:
  /// **'Rent due today'**
  String get templateDueToday;

  /// Template: overdue.
  ///
  /// In en, this message translates to:
  /// **'Rent overdue'**
  String get templateOverdue;

  /// Template: thanks.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get templatePaymentReceived;

  /// Template: utility bill.
  ///
  /// In en, this message translates to:
  /// **'Utility bill'**
  String get templateUtilityBill;

  /// Label of the message language.
  ///
  /// In en, this message translates to:
  /// **'Tenant\'s language'**
  String get reminderLanguageLabel;

  /// Urdu written in Latin letters (its own name).
  ///
  /// In en, this message translates to:
  /// **'Roman Urdu'**
  String get languageRomanUrdu;

  /// Label of the message text.
  ///
  /// In en, this message translates to:
  /// **'Message to send'**
  String get reminderMessageLabel;

  /// No phone to send to.
  ///
  /// In en, this message translates to:
  /// **'This tenant has no phone number: WhatsApp opens for you to choose the chat.'**
  String get reminderNoPhone;

  /// Who the reminder goes to.
  ///
  /// In en, this message translates to:
  /// **'To {name} on {phone}.'**
  String reminderTo(String name, String phone);

  /// Action: open WhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send on WhatsApp'**
  String get sendOnWhatsAppAction;

  /// Action: send despite the etiquette advice.
  ///
  /// In en, this message translates to:
  /// **'Send anyway'**
  String get sendAnywayAction;

  /// Action: copy the message.
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get copyMessageAction;

  /// After copying.
  ///
  /// In en, this message translates to:
  /// **'Message copied.'**
  String get messageCopied;

  /// After sending a reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent and noted in the ledger.'**
  String get reminderLogged;

  /// After WhatsApp opened but the reminder could not be noted: tries noting it again.
  ///
  /// In en, this message translates to:
  /// **'Note it in the reminders sent'**
  String get noteReminderAction;

  /// Etiquette: late night.
  ///
  /// In en, this message translates to:
  /// **'It is late at night in Pakistan. A reminder may be better after {time}.'**
  String etiquetteLateNight(String time);

  /// Etiquette: Friday prayers.
  ///
  /// In en, this message translates to:
  /// **'It is time for Jumu\'ah prayers. A reminder may be better after {time}.'**
  String etiquetteFridayPrayer(String time);

  /// Etiquette: reminded recently.
  ///
  /// In en, this message translates to:
  /// **'A reminder already went to this tenant on {moment}. Too many reminders can strain a good tenancy.'**
  String etiquetteRecent(String moment);

  /// Heading of the reminder log.
  ///
  /// In en, this message translates to:
  /// **'Reminders sent'**
  String get remindersSection;

  /// Read while reminders load.
  ///
  /// In en, this message translates to:
  /// **'Loading the reminders'**
  String get loadingReminders;

  /// Heading when reminders fail to load.
  ///
  /// In en, this message translates to:
  /// **'The reminders could not be loaded'**
  String get remindersLoadFailedTitle;

  /// When no reminder was sent.
  ///
  /// In en, this message translates to:
  /// **'No reminders sent yet.'**
  String get noRemindersYet;

  /// A unit in a reminder.
  ///
  /// In en, this message translates to:
  /// **'{unit}, {property}'**
  String reminderUnit(String unit, String property);

  /// Reminder: rent due soon.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. A reminder that {amount} for {unit} is due on {date}.'**
  String reminderUpcoming(
    String tenant,
    String amount,
    String unit,
    String date,
  );

  /// Reminder: due today.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. {amount} for {unit} is due today.'**
  String reminderDueToday(String tenant, String amount, String unit);

  /// Reminder: overdue.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. {amount} is overdue for {unit}; the oldest of it was due on {date}. Please pay it at your earliest convenience.'**
  String reminderOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  );

  /// Message: payment received.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. We received {amount} on {date}. Receipt number: {receipt}. Thank you.'**
  String reminderReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  );

  /// Reminder: utility bill.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. The {utility} bill of {amount} for {unit} is due on {date}. Please pay it before the due date.'**
  String reminderUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  );

  /// Utility word in a reminder.
  ///
  /// In en, this message translates to:
  /// **'electricity'**
  String get reminderElectricity;

  /// Utility word in a reminder.
  ///
  /// In en, this message translates to:
  /// **'gas'**
  String get reminderGas;

  /// Utility word in a reminder.
  ///
  /// In en, this message translates to:
  /// **'water'**
  String get reminderWater;

  /// Utility word in a reminder.
  ///
  /// In en, this message translates to:
  /// **'internet'**
  String get reminderInternet;

  /// Utility word in a reminder.
  ///
  /// In en, this message translates to:
  /// **'utility'**
  String get reminderUtilityGeneric;

  /// Payment details: Raast.
  ///
  /// In en, this message translates to:
  /// **'You can pay by Raast to {raast}.'**
  String reminderPayRaast(String raast);

  /// Payment details: bank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer: {title}, IBAN {iban}.'**
  String reminderPayBank(String title, String iban);

  /// Signature of a reminder.
  ///
  /// In en, this message translates to:
  /// **'Regards, {landlord}'**
  String reminderThanks(String landlord);

  /// A unit in a Roman Urdu reminder (the same in every UI language).
  ///
  /// In en, this message translates to:
  /// **'{unit}, {property}'**
  String reminderRomanUnit(String unit, String property);

  /// Roman Urdu reminder: rent due soon (the same in every UI language).
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. Yaad dihani: {unit} ke {amount}, {date} ko dene hain.'**
  String reminderRomanUpcoming(
    String tenant,
    String amount,
    String unit,
    String date,
  );

  /// Roman Urdu reminder: due today.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. {unit} ke {amount} aaj dene hain.'**
  String reminderRomanDueToday(String tenant, String amount, String unit);

  /// Roman Urdu reminder: overdue.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. {unit} ke {amount} late hain. In mein sab se purani raqam {date} ko deni thi. Meherbani kar ke jald ada kar dein.'**
  String reminderRomanOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  );

  /// Roman Urdu message: payment received.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. {date} ko {amount} mil gaye. Raseed number: {receipt}. Shukriya.'**
  String reminderRomanReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  );

  /// Roman Urdu reminder: utility bill.
  ///
  /// In en, this message translates to:
  /// **'Assalam-o-Alaikum {tenant}. {unit} ka {utility} {amount} hai, jo {date} tak ada karna hai. Meherbani kar ke aakhri tareekh se pehle ada kar dein.'**
  String reminderRomanUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  );

  /// Roman Urdu utility word.
  ///
  /// In en, this message translates to:
  /// **'bijli ka bill'**
  String get reminderRomanElectricity;

  /// Roman Urdu utility word.
  ///
  /// In en, this message translates to:
  /// **'gas ka bill'**
  String get reminderRomanGas;

  /// Roman Urdu utility word.
  ///
  /// In en, this message translates to:
  /// **'paani ka bill'**
  String get reminderRomanWater;

  /// Roman Urdu utility word.
  ///
  /// In en, this message translates to:
  /// **'internet ka bill'**
  String get reminderRomanInternet;

  /// Roman Urdu utility word.
  ///
  /// In en, this message translates to:
  /// **'bill'**
  String get reminderRomanUtilityGeneric;

  /// Roman Urdu payment details: Raast.
  ///
  /// In en, this message translates to:
  /// **'Aap Raast ke zariye {raast} par adaigi kar sakte hain.'**
  String reminderRomanPayRaast(String raast);

  /// Roman Urdu payment details: bank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer: {title}, IBAN {iban}.'**
  String reminderRomanPayBank(String title, String iban);

  /// Roman Urdu signature.
  ///
  /// In en, this message translates to:
  /// **'Wassalam, {landlord}'**
  String reminderRomanThanks(String landlord);

  /// Read while the cash book loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the cash in hand'**
  String get loadingCashBook;

  /// Heading when the cash book fails.
  ///
  /// In en, this message translates to:
  /// **'The cash in hand could not be loaded'**
  String get cashBookLoadFailedTitle;

  /// Heading of cash positions.
  ///
  /// In en, this message translates to:
  /// **'Who holds cash'**
  String get cashInHandSection;

  /// Help of cash positions.
  ///
  /// In en, this message translates to:
  /// **'Cash collected, less what was handed on or spent in cash.'**
  String get cashInHandHelp;

  /// When nobody collected cash.
  ///
  /// In en, this message translates to:
  /// **'No cash has been collected yet.'**
  String get noCashYet;

  /// Cash in hand: what a member collected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get cashCollectedLabel;

  /// Cash in hand: what a member handed on.
  ///
  /// In en, this message translates to:
  /// **'Handed on'**
  String get cashHandedOverLabel;

  /// Cash in hand: what a member spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get cashSpentLabel;

  /// Cash in hand: what a member holds now.
  ///
  /// In en, this message translates to:
  /// **'In hand'**
  String get cashInHandLabel;

  /// Heading of handovers.
  ///
  /// In en, this message translates to:
  /// **'Handovers'**
  String get handoversSection;

  /// When there are no handovers.
  ///
  /// In en, this message translates to:
  /// **'No cash has been handed over yet.'**
  String get noHandoversYet;

  /// A member whose account is gone.
  ///
  /// In en, this message translates to:
  /// **'A former member'**
  String get formerMember;

  /// Who handed cash to whom.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String handoverFromTo(String from, String to);

  /// Badge: the owner confirmed it.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get handoverConfirmed;

  /// Badge: not yet confirmed.
  ///
  /// In en, this message translates to:
  /// **'To confirm'**
  String get handoverAwaiting;

  /// Title of a handover sheet.
  ///
  /// In en, this message translates to:
  /// **'Cash handover'**
  String get handoverTitle;

  /// Label of the handover date.
  ///
  /// In en, this message translates to:
  /// **'Handed over on'**
  String get handedOverOnLabel;

  /// Action: confirm a handover.
  ///
  /// In en, this message translates to:
  /// **'Confirm I received it'**
  String get confirmHandoverAction;

  /// After confirming.
  ///
  /// In en, this message translates to:
  /// **'Handover confirmed.'**
  String get handoverConfirmedDone;

  /// Action: void a handover.
  ///
  /// In en, this message translates to:
  /// **'Void handover'**
  String get voidHandoverAction;

  /// Explains voiding a handover.
  ///
  /// In en, this message translates to:
  /// **'Voiding a handover recorded by mistake counts that cash as still with the giver. It stays in the list, marked voided.'**
  String get voidHandoverExplain;

  /// After voiding a handover.
  ///
  /// In en, this message translates to:
  /// **'Handover voided.'**
  String get handoverVoided;

  /// Action: record a handover.
  ///
  /// In en, this message translates to:
  /// **'Record handover'**
  String get recordHandoverAction;

  /// Who gave the cash.
  ///
  /// In en, this message translates to:
  /// **'Handed over by'**
  String get handoverFromLabel;

  /// Who received the cash.
  ///
  /// In en, this message translates to:
  /// **'Handed to'**
  String get handoverToLabel;

  /// No receiver chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose who received the cash.'**
  String get handoverChooseReceiver;

  /// After recording a handover.
  ///
  /// In en, this message translates to:
  /// **'Handover recorded.'**
  String get handoverRecorded;

  /// Title of the notification centre.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Under Notifications on More.
  ///
  /// In en, this message translates to:
  /// **'Rent due, tenancies ending, police registration'**
  String get notificationsSummary;

  /// How many notifications are unread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread} other{{count} unread}}'**
  String unreadCount(int count);

  /// Read while notifications load.
  ///
  /// In en, this message translates to:
  /// **'Loading the notifications'**
  String get loadingNotifications;

  /// Heading when notifications fail.
  ///
  /// In en, this message translates to:
  /// **'The notifications could not be loaded'**
  String get notificationsLoadFailedTitle;

  /// Empty notification centre.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsEmptyTitle;

  /// Empty notification centre.
  ///
  /// In en, this message translates to:
  /// **'Each morning the app checks for rent due, tenancies ending, rent increases, police registration and CNICs expiring, and tells you here.'**
  String get notificationsEmptyBody;

  /// Action: mark all read.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllReadAction;

  /// Badge of an unread notification.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get unreadLabel;

  /// Action: open what a notification is about.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openNotificationAction;

  /// After deleting a notification.
  ///
  /// In en, this message translates to:
  /// **'Notification deleted.'**
  String get notificationDeleted;

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Rent due soon'**
  String get notificationRentDueSoon;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: {amount} due on {date}.'**
  String notificationRentDueSoonBody(
    String tenancy,
    String amount,
    String date,
  );

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Rent overdue'**
  String get notificationRentOverdue;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: {amount} was due on {date}.'**
  String notificationRentOverdueBody(
    String tenancy,
    String amount,
    String date,
  );

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Agreement ending'**
  String get notificationLeaseExpiring;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: the agreement ends on {date}.'**
  String notificationLeaseExpiringBody(String tenancy, String date);

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Rent increase due'**
  String get notificationIncrementDue;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: the yearly increase on rent of {rent} is due from {date}.'**
  String notificationIncrementDueBody(String tenancy, String date, String rent);

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Police registration pending'**
  String get notificationPolicePending;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: register the tenancy with the police by {date}.'**
  String notificationPolicePendingBody(String tenancy, String date);

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Police registration overdue'**
  String get notificationPoliceOverdue;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: the deadline to register with the police was {date}.'**
  String notificationPoliceOverdueBody(String tenancy, String date);

  /// Notification text, non-statutory.
  ///
  /// In en, this message translates to:
  /// **'{tenancy}: the app\'s reminder to register with the police is {date}. No law the app knows of sets a deadline here.'**
  String notificationPoliceReminderBody(String tenancy, String date);

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'CNIC expiring'**
  String get notificationCnicExpiring;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{tenant}\'s CNIC expires on {date}.'**
  String notificationCnicExpiringBody(String tenant, String date);

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Utility bill due'**
  String get notificationUtilityDue;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{property}: a bill of {amount} is due on {date}.'**
  String notificationUtilityDueBody(
    String property,
    String amount,
    String date,
  );

  /// Notification title.
  ///
  /// In en, this message translates to:
  /// **'Invitation accepted'**
  String get notificationInvitationAccepted;

  /// Notification text.
  ///
  /// In en, this message translates to:
  /// **'{email} joined as {role}.'**
  String notificationInvitationAcceptedBody(String email, String role);

  /// A notification this version cannot show.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationUnknown;

  /// A notification this version cannot show.
  ///
  /// In en, this message translates to:
  /// **'Update the app to read this notification.'**
  String get notificationUnknownBody;

  /// Refusal: a payment without its key.
  ///
  /// In en, this message translates to:
  /// **'This payment could not be sent safely. Close the form and open it again.'**
  String get reasonIdempotencyKeyRequired;

  /// A refund whose answer was lost.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped, so the refund may have been recorded. Close this and check the deposit before trying again.'**
  String get reasonRefundUnconfirmed;

  /// After a refund whose answer was lost: closes the sheet.
  ///
  /// In en, this message translates to:
  /// **'Close and check the deposit'**
  String get checkDepositAction;

  /// Heading on More above expenses, utilities and maintenance.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operationsSection;

  /// What the expenses screen holds.
  ///
  /// In en, this message translates to:
  /// **'What you spend on your properties'**
  String get expensesSummary;

  /// What the utilities screen holds.
  ///
  /// In en, this message translates to:
  /// **'Connections, bills and meter readings'**
  String get utilitiesSummary;

  /// What the maintenance screen holds.
  ///
  /// In en, this message translates to:
  /// **'Repairs and where each stands'**
  String get maintenanceSummary;

  /// Label of the property something belongs to.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get propertyLabel;

  /// Choice: an expense of no single property.
  ///
  /// In en, this message translates to:
  /// **'The whole portfolio'**
  String get wholePortfolioOption;

  /// Choice: no single unit, the whole property.
  ///
  /// In en, this message translates to:
  /// **'The whole property'**
  String get wholePropertyOption;

  /// A choice whose options are still loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loadingPlaces;

  /// Choice: not linked to a tenancy.
  ///
  /// In en, this message translates to:
  /// **'No tenancy'**
  String get noTenancyOption;

  /// Billing a utility: no tenancy to bill.
  ///
  /// In en, this message translates to:
  /// **'No tenancy was ever started on this connection\'s property or unit.'**
  String get noTenanciesHere;

  /// Label of a free-text description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// Label of where something stands.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// Yes, as a value.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No, as a value.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Filter: repairs still to be done.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get filterToDo;

  /// Filter: repairs resolved or cancelled.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get filterClosed;

  /// Calls a phone number.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callAction;

  /// Calling failed.
  ///
  /// In en, this message translates to:
  /// **'The phone could not be opened on this device.'**
  String get callFailed;

  /// Label of the day a bill was paid.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get paidOnLabel;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Repairs and maintenance'**
  String get expenseCategoryRepairs;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Property tax'**
  String get expenseCategoryPropertyTax;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get expenseCategoryUtilities;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Society charges'**
  String get expenseCategorySociety;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get expenseCategoryInsurance;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Legal and professional fees'**
  String get expenseCategoryLegal;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Agent\'s commission'**
  String get expenseCategoryAgent;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Staff salaries'**
  String get expenseCategorySalaries;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Cleaning and security'**
  String get expenseCategoryCleaning;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Renovation'**
  String get expenseCategoryRenovation;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Bank charges'**
  String get expenseCategoryBank;

  /// Expense category.
  ///
  /// In en, this message translates to:
  /// **'Loan interest'**
  String get expenseCategoryLoanInterest;

  /// Title of the expenses screen.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// Title of one expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expenseTitle;

  /// Title of the form adding an expense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get newExpenseTitle;

  /// Title of the form editing an expense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpenseTitle;

  /// Adds an expense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpenseAction;

  /// Screen reader: expenses loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the expenses'**
  String get loadingExpenses;

  /// Screen reader: an expense loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the expense'**
  String get loadingExpense;

  /// Expenses failed to load.
  ///
  /// In en, this message translates to:
  /// **'The expenses could not be loaded'**
  String get expensesLoadFailedTitle;

  /// An expense failed to load.
  ///
  /// In en, this message translates to:
  /// **'The expense could not be loaded'**
  String get expenseLoadFailedTitle;

  /// No expenses recorded.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get expensesEmptyTitle;

  /// Explains expenses when there are none.
  ///
  /// In en, this message translates to:
  /// **'Record what you spend on repairs, tax, salaries and the rest, with a photo of each receipt. It shows what each property really earns.'**
  String get expensesEmptyBody;

  /// Form section: category, amount, date.
  ///
  /// In en, this message translates to:
  /// **'What was spent'**
  String get expenseSectionWhat;

  /// Form section: property, unit, job.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get expenseSectionWhere;

  /// Form section: payee, method, reference.
  ///
  /// In en, this message translates to:
  /// **'How it was paid'**
  String get expenseSectionPaid;

  /// Label of an expense's category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseCategoryLabel;

  /// Label of the day money was spent.
  ///
  /// In en, this message translates to:
  /// **'Spent on'**
  String get spentOnLabel;

  /// Helper of an expense's property.
  ///
  /// In en, this message translates to:
  /// **'Choose “The whole portfolio” for costs such as an accountant\'s fee.'**
  String get expensePropertyHelp;

  /// Label of the repair an expense pays for.
  ///
  /// In en, this message translates to:
  /// **'Maintenance job'**
  String get maintenanceJobLabel;

  /// Helper of an expense's maintenance job.
  ///
  /// In en, this message translates to:
  /// **'The repair this paid for, if any.'**
  String get maintenanceJobHelp;

  /// Choice: an expense not for a repair.
  ///
  /// In en, this message translates to:
  /// **'No job'**
  String get noJobOption;

  /// Label of who was paid.
  ///
  /// In en, this message translates to:
  /// **'Paid to'**
  String get payeeLabel;

  /// Helper of who was paid.
  ///
  /// In en, this message translates to:
  /// **'A plumber, the excise office, a shop…'**
  String get payeeHelp;

  /// Helper of cash as an expense's method.
  ///
  /// In en, this message translates to:
  /// **'Cash you spend comes out of your cash in hand.'**
  String get expenseCashHelp;

  /// A new expense pays for a repair.
  ///
  /// In en, this message translates to:
  /// **'For the job: {title}'**
  String expenseForJob(String title);

  /// Link from an expense to its repair.
  ///
  /// In en, this message translates to:
  /// **'Paid for the job'**
  String get paidForJobLabel;

  /// An expense was added.
  ///
  /// In en, this message translates to:
  /// **'Expense added.'**
  String get expenseAdded;

  /// An expense was saved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved.'**
  String get expenseSaved;

  /// An expense was deleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted.'**
  String get expenseDeleted;

  /// Confirming deleting an expense.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get deleteExpenseTitle;

  /// What deleting an expense does.
  ///
  /// In en, this message translates to:
  /// **'It goes for good, with its receipts. Only for an expense recorded by mistake.'**
  String get deleteExpenseBody;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'LESCO (Lahore)'**
  String get providerLesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'IESCO (Islamabad)'**
  String get providerIesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'GEPCO (Gujranwala)'**
  String get providerGepco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'FESCO (Faisalabad)'**
  String get providerFesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'MEPCO (Multan)'**
  String get providerMepco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'PESCO (Peshawar)'**
  String get providerPesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'HESCO (Hyderabad)'**
  String get providerHesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'SEPCO (Sukkur)'**
  String get providerSepco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'QESCO (Quetta)'**
  String get providerQesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'TESCO (Tribal districts)'**
  String get providerTesco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'HAZECO (Hazara)'**
  String get providerHazeco;

  /// Electricity company.
  ///
  /// In en, this message translates to:
  /// **'K-Electric (Karachi)'**
  String get providerKElectric;

  /// Gas company.
  ///
  /// In en, this message translates to:
  /// **'SNGPL (Sui Northern)'**
  String get providerSngpl;

  /// Gas company.
  ///
  /// In en, this message translates to:
  /// **'SSGC (Sui Southern)'**
  String get providerSsgc;

  /// Water authority.
  ///
  /// In en, this message translates to:
  /// **'WASA'**
  String get providerWasa;

  /// Water authority.
  ///
  /// In en, this message translates to:
  /// **'Karachi Water (KW&SC)'**
  String get providerKwsc;

  /// Water authority.
  ///
  /// In en, this message translates to:
  /// **'CDA (Islamabad)'**
  String get providerCda;

  /// Internet company.
  ///
  /// In en, this message translates to:
  /// **'PTCL'**
  String get providerPtcl;

  /// Who pays a connection's bills.
  ///
  /// In en, this message translates to:
  /// **'The tenant'**
  String get responsibilityTenant;

  /// Who pays a connection's bills: the landlord.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get responsibilityLandlord;

  /// Who pays a connection's bills.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get responsibilityShared;

  /// Who paid a bill.
  ///
  /// In en, this message translates to:
  /// **'The tenant'**
  String get billPaidByTenant;

  /// Who paid a bill: the landlord.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get billPaidByLandlord;

  /// Why a meter was read.
  ///
  /// In en, this message translates to:
  /// **'Move-in'**
  String get readingMoveIn;

  /// Why a meter was read.
  ///
  /// In en, this message translates to:
  /// **'Move-out'**
  String get readingMoveOut;

  /// Why a meter was read.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get readingMonthly;

  /// Title of the utilities screen.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get utilitiesTitle;

  /// Screen reader: utilities loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the utilities'**
  String get loadingUtilities;

  /// Utilities failed to load.
  ///
  /// In en, this message translates to:
  /// **'The utilities could not be loaded'**
  String get utilitiesLoadFailedTitle;

  /// Heading of the unpaid bills.
  ///
  /// In en, this message translates to:
  /// **'Bills to pay'**
  String get unpaidBillsSection;

  /// Explains the unpaid bills.
  ///
  /// In en, this message translates to:
  /// **'Unpaid bills, the earliest due first.'**
  String get unpaidBillsHelp;

  /// No bills to pay.
  ///
  /// In en, this message translates to:
  /// **'No unpaid bills.'**
  String get noUnpaidBills;

  /// Warning: overdue bills on connections in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 overdue bill is on a connection in your name. Arrears stay with the premises and the connection, so they can fall on you.} other{{count} overdue bills are on connections in your name. Arrears stay with the premises and the connection, so they can fall on you.}}'**
  String landlordNameOverdue(int count);

  /// Heading of the utility connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connectionsSection;

  /// Explains the connections.
  ///
  /// In en, this message translates to:
  /// **'Electricity, gas, water and internet, per property or unit.'**
  String get connectionsHelp;

  /// No connections added.
  ///
  /// In en, this message translates to:
  /// **'No connections yet'**
  String get connectionsEmptyTitle;

  /// Explains connections when there are none.
  ///
  /// In en, this message translates to:
  /// **'Add each meter with its reference number and whose name it is in. Unpaid bills follow the premises, so keep an eye on them here.'**
  String get connectionsEmptyBody;

  /// No archived connections.
  ///
  /// In en, this message translates to:
  /// **'No archived connections.'**
  String get archivedConnectionsEmpty;

  /// Explains archived connections.
  ///
  /// In en, this message translates to:
  /// **'Connections you archive keep their bills and readings and wait here.'**
  String get archivedConnectionsEmptyBody;

  /// Adds a utility connection.
  ///
  /// In en, this message translates to:
  /// **'Add connection'**
  String get addConnectionAction;

  /// A connection: what it supplies and who supplies it.
  ///
  /// In en, this message translates to:
  /// **'{kind}, {supplier}'**
  String connectionName(String kind, String supplier);

  /// A connection in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'In your name'**
  String get inYourName;

  /// A bill of a connection, and its month.
  ///
  /// In en, this message translates to:
  /// **'{connection}: {month}'**
  String billOfMonth(String connection, String month);

  /// Units of electricity or gas used.
  ///
  /// In en, this message translates to:
  /// **'{units} units'**
  String unitsUsed(String units);

  /// A bill billed to the tenant.
  ///
  /// In en, this message translates to:
  /// **'On the tenant\'s ledger'**
  String get chargedToTenant;

  /// Screen reader: a connection loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the connection'**
  String get loadingUtility;

  /// A connection failed to load.
  ///
  /// In en, this message translates to:
  /// **'The connection could not be loaded'**
  String get utilityLoadFailedTitle;

  /// Warning on a connection in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'This connection is in your name. Unpaid bills stay with it and can fall on you: check every month that the bill is paid.'**
  String get inYourNameWarning;

  /// Label of a bill's reference or account number.
  ///
  /// In en, this message translates to:
  /// **'Reference number'**
  String get referenceNumberLabel;

  /// Label of a connection's customer ID.
  ///
  /// In en, this message translates to:
  /// **'Customer ID'**
  String get customerIdLabel;

  /// Label of a meter's number.
  ///
  /// In en, this message translates to:
  /// **'Meter number'**
  String get meterNumberLabel;

  /// Label of the name printed on the bill.
  ///
  /// In en, this message translates to:
  /// **'Name on the bill'**
  String get nameOnBillLabel;

  /// Label: the connection is in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'In my name'**
  String get inMyNameLabel;

  /// Explains a connection in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'Arrears follow the premises: unpaid bills on a connection in your name can fall on you.'**
  String get inMyNameHelp;

  /// Label of who pays a connection's bills.
  ///
  /// In en, this message translates to:
  /// **'Who pays the bills'**
  String get whoPaysLabel;

  /// Label: a sub-meter.
  ///
  /// In en, this message translates to:
  /// **'Sub-meter'**
  String get subMeterLabel;

  /// Explains a sub-meter.
  ///
  /// In en, this message translates to:
  /// **'A meter of your own that measures one portion\'s share of a main connection.'**
  String get subMeterHelp;

  /// Label: on the protected domestic tariff.
  ///
  /// In en, this message translates to:
  /// **'Protected tariff'**
  String get protectedLabel;

  /// Explains the protected tariff.
  ///
  /// In en, this message translates to:
  /// **'The subsidised domestic tariff for homes that use {limit} units a month or fewer. One month over {limit} loses it for six months; the app warns you as a month nears it.'**
  String protectedHelp(int limit);

  /// Heading of a connection's bills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get billsSection;

  /// A connection has no bills.
  ///
  /// In en, this message translates to:
  /// **'No bills yet. Add each month\'s bill with its due date and units.'**
  String get billsEmpty;

  /// Adds a bill.
  ///
  /// In en, this message translates to:
  /// **'Add bill'**
  String get addBillAction;

  /// Heading of a connection's readings.
  ///
  /// In en, this message translates to:
  /// **'Meter readings'**
  String get readingsSection;

  /// Explains meter readings.
  ///
  /// In en, this message translates to:
  /// **'Read the meter at move-in and move-out, and each month if you like.'**
  String get readingsHelp;

  /// A connection has no readings.
  ///
  /// In en, this message translates to:
  /// **'No readings yet.'**
  String get readingsEmpty;

  /// Adds a meter reading.
  ///
  /// In en, this message translates to:
  /// **'Add reading'**
  String get addReadingAction;

  /// A meter's figure.
  ///
  /// In en, this message translates to:
  /// **'Reading {value}'**
  String readingValue(String value);

  /// Units used between two readings.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{{units} units in 1 day} other{{units} units in {days} days}}'**
  String usedSince(String units, int days);

  /// Confirming archiving a connection.
  ///
  /// In en, this message translates to:
  /// **'Archive this connection?'**
  String get archiveConnectionTitle;

  /// What archiving a connection does.
  ///
  /// In en, this message translates to:
  /// **'It leaves your lists but keeps its bills and readings. You can put it back in use later.'**
  String get archiveConnectionBody;

  /// A connection was archived.
  ///
  /// In en, this message translates to:
  /// **'Connection archived.'**
  String get connectionArchived;

  /// A connection was put back in use.
  ///
  /// In en, this message translates to:
  /// **'The connection is back in use.'**
  String get connectionRestored;

  /// Confirming deleting a connection.
  ///
  /// In en, this message translates to:
  /// **'Delete this connection?'**
  String get deleteConnectionTitle;

  /// What deleting a connection does.
  ///
  /// In en, this message translates to:
  /// **'It goes for good, with its bills and readings. Dues already on a tenant\'s ledger stay there. Only for a connection added by mistake; otherwise archive it.'**
  String get deleteConnectionBody;

  /// A connection was deleted.
  ///
  /// In en, this message translates to:
  /// **'Connection deleted.'**
  String get connectionDeleted;

  /// Title of the form adding a connection.
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get newConnectionTitle;

  /// Title of the form editing a connection.
  ///
  /// In en, this message translates to:
  /// **'Edit connection'**
  String get editConnectionTitle;

  /// Form section: property and unit.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get connectionSectionWhere;

  /// Form section: type and supplier.
  ///
  /// In en, this message translates to:
  /// **'What and who supplies it'**
  String get connectionSectionSupplier;

  /// Form section: reference, customer, meter numbers.
  ///
  /// In en, this message translates to:
  /// **'Account numbers'**
  String get connectionSectionNumbers;

  /// Form section: name, responsibility.
  ///
  /// In en, this message translates to:
  /// **'Whose name, who pays'**
  String get connectionSectionWho;

  /// Label of what a connection supplies.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get utilityTypeLabel;

  /// Label of who supplies a connection.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get providerLabel;

  /// Label of another supplier's name.
  ///
  /// In en, this message translates to:
  /// **'Supplier\'s name'**
  String get providerNameLabel;

  /// Helper of a reference number.
  ///
  /// In en, this message translates to:
  /// **'As printed on the bill.'**
  String get referenceNumberHelp;

  /// A reference number of an unusual length (a hint, not an error).
  ///
  /// In en, this message translates to:
  /// **'This supplier\'s bills usually carry a {digits}-digit number. Check it against a bill.'**
  String referenceDigitsHint(int digits);

  /// A reference number in the wrong form.
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 24 letters, digits or dashes.'**
  String get referenceNumberInvalid;

  /// A customer ID in the wrong form.
  ///
  /// In en, this message translates to:
  /// **'Use up to 30 letters, digits or dashes.'**
  String get customerIdInvalid;

  /// A meter number in the wrong form.
  ///
  /// In en, this message translates to:
  /// **'Use up to 30 letters, digits, dashes or slashes.'**
  String get meterNumberInvalid;

  /// A connection was added.
  ///
  /// In en, this message translates to:
  /// **'Connection added.'**
  String get connectionAdded;

  /// A connection was saved.
  ///
  /// In en, this message translates to:
  /// **'Connection saved.'**
  String get connectionSaved;

  /// Title of a bill while it loads.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get billTitle;

  /// Screen reader: a bill loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the bill'**
  String get loadingBill;

  /// A bill failed to load.
  ///
  /// In en, this message translates to:
  /// **'The bill could not be loaded'**
  String get billLoadFailedTitle;

  /// A paid bill.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billPaid;

  /// An unpaid bill without a due date.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get billUnpaid;

  /// Label of a bill's month.
  ///
  /// In en, this message translates to:
  /// **'Bill for'**
  String get billMonthLabel;

  /// Label of a bill's units.
  ///
  /// In en, this message translates to:
  /// **'Units used'**
  String get unitsConsumedLabel;

  /// Helper of units on a protected connection.
  ///
  /// In en, this message translates to:
  /// **'On the protected tariff: keep a month at {limit} units or fewer.'**
  String protectedUnitsHelp(int limit);

  /// A number of units in the wrong form.
  ///
  /// In en, this message translates to:
  /// **'Enter a number of units, like 185 or 185.5.'**
  String get validationUnits;

  /// Label: a new bill is already paid.
  ///
  /// In en, this message translates to:
  /// **'Already paid'**
  String get alreadyPaidLabel;

  /// Label of who paid a bill.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get billPaidByLabel;

  /// A bill was added.
  ///
  /// In en, this message translates to:
  /// **'Bill added.'**
  String get billAdded;

  /// A bill was saved.
  ///
  /// In en, this message translates to:
  /// **'Bill saved.'**
  String get billSaved;

  /// A bill was deleted.
  ///
  /// In en, this message translates to:
  /// **'Bill deleted.'**
  String get billDeleted;

  /// A bill was marked paid.
  ///
  /// In en, this message translates to:
  /// **'Bill marked paid.'**
  String get billMarkedPaid;

  /// A bill was marked unpaid.
  ///
  /// In en, this message translates to:
  /// **'Bill marked unpaid.'**
  String get billMarkedUnpaid;

  /// A bill was billed to the tenant.
  ///
  /// In en, this message translates to:
  /// **'The bill is on the tenant\'s ledger.'**
  String get billCharged;

  /// Marks a bill paid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get markPaidAction;

  /// Marks a bill unpaid.
  ///
  /// In en, this message translates to:
  /// **'Mark unpaid'**
  String get markUnpaidAction;

  /// Edits a bill.
  ///
  /// In en, this message translates to:
  /// **'Edit bill'**
  String get editBillAction;

  /// Bills a utility bill to the tenant.
  ///
  /// In en, this message translates to:
  /// **'Charge to tenant'**
  String get chargeTenantAction;

  /// What billing a utility to the tenant does.
  ///
  /// In en, this message translates to:
  /// **'The bill of {amount} becomes a due on the tenant\'s ledger, due on {date}. Credit the tenant holds is applied to it.'**
  String chargeTenantExplain(String amount, String date);

  /// Where a billed bill's payment goes.
  ///
  /// In en, this message translates to:
  /// **'Its payment is recorded on the tenancy\'s ledger.'**
  String get chargedToTenantHelp;

  /// A billed bill's charge was voided.
  ///
  /// In en, this message translates to:
  /// **'The charge this bill became on the tenant\'s ledger was voided. You can charge it again.'**
  String get billChargeVoided;

  /// Leads to a bill's connection.
  ///
  /// In en, this message translates to:
  /// **'Connection details'**
  String get connectionDetailsAction;

  /// Warning on an unpaid bill in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'This unpaid bill is on a connection in your name: if it stays unpaid, the arrears can fall on you.'**
  String get inYourNameUnpaid;

  /// Confirming deleting a bill.
  ///
  /// In en, this message translates to:
  /// **'Delete this bill?'**
  String get deleteBillTitle;

  /// What deleting a bill does.
  ///
  /// In en, this message translates to:
  /// **'It goes for good, with its photos. Only for a bill added by mistake.'**
  String get deleteBillBody;

  /// What deleting a billed bill does.
  ///
  /// In en, this message translates to:
  /// **'It goes for good, with its photos. The due it became on the tenant\'s ledger stays there: void it in the ledger if it is wrong too.'**
  String get deleteChargedBillBody;

  /// Badge: a month over the protected limit.
  ///
  /// In en, this message translates to:
  /// **'Over {limit} units a month'**
  String protectedOver(int limit);

  /// Badge: a month near the protected limit.
  ///
  /// In en, this message translates to:
  /// **'Near {limit} units a month'**
  String protectedNear(int limit);

  /// A month over the protected limit.
  ///
  /// In en, this message translates to:
  /// **'This month went over {limit} units: the protected tariff is lost for the next six months, and bills will cost more.'**
  String protectedOverExplain(int limit);

  /// A month near the protected limit.
  ///
  /// In en, this message translates to:
  /// **'This month is close to {limit} units. One month over {limit} loses the protected tariff for six months.'**
  String protectedNearExplain(int limit);

  /// Title of a meter reading.
  ///
  /// In en, this message translates to:
  /// **'Meter reading'**
  String get readingTitle;

  /// Screen reader: a reading loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the reading'**
  String get loadingReading;

  /// A reading failed to load.
  ///
  /// In en, this message translates to:
  /// **'The reading could not be loaded'**
  String get readingLoadFailedTitle;

  /// Label of a meter's figure.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get readingLabel;

  /// Label of the day a meter was read.
  ///
  /// In en, this message translates to:
  /// **'Read on'**
  String get readOnLabel;

  /// Label of why a meter was read.
  ///
  /// In en, this message translates to:
  /// **'When read'**
  String get readingContextLabel;

  /// Helper of a reading's tenancy.
  ///
  /// In en, this message translates to:
  /// **'The tenancy moving in or out, if any.'**
  String get readingTenancyHelp;

  /// Helper: the previous reading.
  ///
  /// In en, this message translates to:
  /// **'The last reading was {value} on {date}.'**
  String lastReadingWas(String value, String date);

  /// A reading lower than the one before.
  ///
  /// In en, this message translates to:
  /// **'This is lower than the last reading. If the meter was replaced, note it below.'**
  String get readingLower;

  /// Label of the reading before this one.
  ///
  /// In en, this message translates to:
  /// **'Reading before'**
  String get previousReadingLabel;

  /// A reading and its day.
  ///
  /// In en, this message translates to:
  /// **'{value} on {date}'**
  String readingOn(String value, String date);

  /// Label of units used since the reading before.
  ///
  /// In en, this message translates to:
  /// **'Used since'**
  String get unitsUsedLabel;

  /// Label of units a month at the pace since the reading before.
  ///
  /// In en, this message translates to:
  /// **'At this pace'**
  String get monthlyPaceLabel;

  /// Units a month.
  ///
  /// In en, this message translates to:
  /// **'{units} units a month'**
  String unitsAMonth(String units);

  /// A reading was added.
  ///
  /// In en, this message translates to:
  /// **'Reading added.'**
  String get readingAdded;

  /// A reading was saved.
  ///
  /// In en, this message translates to:
  /// **'Reading saved.'**
  String get readingSaved;

  /// A reading was deleted.
  ///
  /// In en, this message translates to:
  /// **'Reading deleted.'**
  String get readingDeleted;

  /// Edits a reading.
  ///
  /// In en, this message translates to:
  /// **'Edit reading'**
  String get editReadingAction;

  /// Confirming deleting a reading.
  ///
  /// In en, this message translates to:
  /// **'Delete this reading?'**
  String get deleteReadingTitle;

  /// What deleting a reading does.
  ///
  /// In en, this message translates to:
  /// **'It goes for good, with its photos. Only for a reading added by mistake.'**
  String get deleteReadingBody;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Plumbing'**
  String get maintenancePlumbing;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Electrical'**
  String get maintenanceElectrical;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Carpentry'**
  String get maintenanceCarpentry;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get maintenancePainting;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Seepage'**
  String get maintenanceSeepage;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Appliance'**
  String get maintenanceAppliance;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Pest control'**
  String get maintenancePestControl;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get maintenanceCleaning;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Structural'**
  String get maintenanceStructural;

  /// Repair category.
  ///
  /// In en, this message translates to:
  /// **'Water supply'**
  String get maintenanceWaterSupply;

  /// Repair priority.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// Repair priority.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// Repair priority.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// Repair priority.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// A repair's priority in a line.
  ///
  /// In en, this message translates to:
  /// **'{priority} priority'**
  String priorityNamed(String priority);

  /// Repair status.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get maintenanceOpen;

  /// Repair status.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get maintenanceInProgress;

  /// Repair status.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get maintenanceOnHold;

  /// Repair status.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get maintenanceResolved;

  /// Repair status.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get maintenanceCancelled;

  /// Title of the maintenance screen.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// Screen reader: repairs loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the repairs'**
  String get loadingMaintenance;

  /// Screen reader: a repair loading.
  ///
  /// In en, this message translates to:
  /// **'Loading the repair'**
  String get loadingMaintenanceRequest;

  /// Repairs failed to load.
  ///
  /// In en, this message translates to:
  /// **'The repairs could not be loaded'**
  String get maintenanceLoadFailedTitle;

  /// A repair failed to load.
  ///
  /// In en, this message translates to:
  /// **'The repair could not be loaded'**
  String get maintenanceRequestLoadFailedTitle;

  /// No repairs to do.
  ///
  /// In en, this message translates to:
  /// **'Nothing to repair'**
  String get maintenanceEmptyTitle;

  /// Explains repairs when there are none.
  ///
  /// In en, this message translates to:
  /// **'Record each repair as it is reported, and follow it until it is done, with what it cost.'**
  String get maintenanceEmptyBody;

  /// No closed repairs.
  ///
  /// In en, this message translates to:
  /// **'No closed repairs yet'**
  String get maintenanceClosedEmptyTitle;

  /// Explains closed repairs.
  ///
  /// In en, this message translates to:
  /// **'Repairs you resolve or cancel are kept here.'**
  String get maintenanceClosedEmptyBody;

  /// Adds a maintenance request.
  ///
  /// In en, this message translates to:
  /// **'Add repair'**
  String get addRequestAction;

  /// When a repair was reported, in a line.
  ///
  /// In en, this message translates to:
  /// **'Reported {date}'**
  String reportedOn(String date);

  /// Label of a repair's category.
  ///
  /// In en, this message translates to:
  /// **'Kind of work'**
  String get maintenanceCategoryLabel;

  /// Label of a repair's priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// Label of the day a repair was reported.
  ///
  /// In en, this message translates to:
  /// **'Reported on'**
  String get reportedOnLabel;

  /// Label of who reported a repair.
  ///
  /// In en, this message translates to:
  /// **'Reported by'**
  String get reportedByLabel;

  /// Label of the vendor or worker doing a repair.
  ///
  /// In en, this message translates to:
  /// **'Done by'**
  String get assignedToLabel;

  /// Helper of who does a repair.
  ///
  /// In en, this message translates to:
  /// **'The plumber, electrician or company doing it.'**
  String get assignedToHelp;

  /// Label of the vendor's phone.
  ///
  /// In en, this message translates to:
  /// **'Their phone'**
  String get vendorPhoneLabel;

  /// Label of a repair's estimated cost.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get estimateLabel;

  /// Label of the day a repair was resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved on'**
  String get resolvedOnLabel;

  /// Label of how a repair was resolved.
  ///
  /// In en, this message translates to:
  /// **'What was done'**
  String get resolutionLabel;

  /// Helper of how a repair was resolved.
  ///
  /// In en, this message translates to:
  /// **'For the record: what was fixed, and any guarantee.'**
  String get resolutionHelp;

  /// Moves a repair to in progress.
  ///
  /// In en, this message translates to:
  /// **'Start work'**
  String get startWorkAction;

  /// Moves a repair on hold to in progress.
  ///
  /// In en, this message translates to:
  /// **'Resume work'**
  String get resumeWorkAction;

  /// Puts a repair on hold.
  ///
  /// In en, this message translates to:
  /// **'Put on hold'**
  String get putOnHoldAction;

  /// Resolves a repair.
  ///
  /// In en, this message translates to:
  /// **'Mark resolved'**
  String get markResolvedAction;

  /// Cancels a repair.
  ///
  /// In en, this message translates to:
  /// **'Cancel the repair'**
  String get cancelRequestAction;

  /// Reopens a closed repair.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopenAction;

  /// A repair moved to a status.
  ///
  /// In en, this message translates to:
  /// **'Now: {status}.'**
  String requestMoved(String status);

  /// A repair was resolved.
  ///
  /// In en, this message translates to:
  /// **'Repair resolved.'**
  String get requestResolved;

  /// Heading of a repair's expenses.
  ///
  /// In en, this message translates to:
  /// **'Spent on it'**
  String get jobExpensesSection;

  /// A repair has no expenses.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent on it yet.'**
  String get jobExpensesEmpty;

  /// Spent on a repair.
  ///
  /// In en, this message translates to:
  /// **'{amount} so far'**
  String spentSoFar(String amount);

  /// Spent on a repair against its estimate.
  ///
  /// In en, this message translates to:
  /// **'{spent} of the {estimate} estimate'**
  String spentOfEstimate(String spent, String estimate);

  /// Confirming deleting a repair.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}?'**
  String deleteRequestTitle(String title);

  /// What deleting a repair does.
  ///
  /// In en, this message translates to:
  /// **'It goes for good, with its photos. Only for a repair added by mistake; cancel it instead to keep it on record.'**
  String get deleteRequestBody;

  /// A repair was deleted.
  ///
  /// In en, this message translates to:
  /// **'Repair deleted.'**
  String get requestDeleted;

  /// Title of the form adding a repair.
  ///
  /// In en, this message translates to:
  /// **'New repair'**
  String get newRequestTitle;

  /// Title of the form editing a repair.
  ///
  /// In en, this message translates to:
  /// **'Edit repair'**
  String get editRequestTitle;

  /// Form section: title, category, priority.
  ///
  /// In en, this message translates to:
  /// **'What needs doing'**
  String get requestSectionWhat;

  /// Form section: property, unit, tenancy.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get requestSectionWhere;

  /// Form section: reporter, vendor, estimate.
  ///
  /// In en, this message translates to:
  /// **'Who and when'**
  String get requestSectionWho;

  /// Form section: status.
  ///
  /// In en, this message translates to:
  /// **'Where it stands'**
  String get requestSectionStatus;

  /// Label of a repair's title.
  ///
  /// In en, this message translates to:
  /// **'What is wrong'**
  String get requestTitleLabel;

  /// Helper of a repair's title.
  ///
  /// In en, this message translates to:
  /// **'In a few words: \"Kitchen tap leaking\".'**
  String get requestTitleHelp;

  /// Helper of a repair's tenancy.
  ///
  /// In en, this message translates to:
  /// **'The tenancy it was reported in, if any.'**
  String get requestTenancyHelp;

  /// A repair was added.
  ///
  /// In en, this message translates to:
  /// **'Repair added.'**
  String get requestAdded;

  /// A repair was saved.
  ///
  /// In en, this message translates to:
  /// **'Repair saved.'**
  String get requestSaved;

  /// Refusal: a reference number already used.
  ///
  /// In en, this message translates to:
  /// **'Another connection of this type in use already has this reference number.'**
  String get reasonDuplicateUtilityReference;

  /// Refusal: a second bill for the same month.
  ///
  /// In en, this message translates to:
  /// **'This connection already has a bill for that month. Open it to change it.'**
  String get reasonDuplicateBillMonth;

  /// Refusal: deleting a repair with expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses are recorded against this repair, so it cannot be deleted. Cancel it instead, or delete those expenses first.'**
  String get reasonRequestHasExpenses;

  /// A connection's reference number, in a line.
  ///
  /// In en, this message translates to:
  /// **'Ref. {number}'**
  String connectionReference(String number);

  /// Label of where something is: a property, or a unit of it.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get whereLabel;

  /// A reading's pace near the protected limit.
  ///
  /// In en, this message translates to:
  /// **'At this pace a month comes close to {limit} units. One month over {limit} loses the protected tariff for six months.'**
  String pacedNearExplain(int limit);

  /// A reading's pace over the protected limit.
  ///
  /// In en, this message translates to:
  /// **'At this pace a month goes over {limit} units, which loses the protected tariff for six months. Check the bill when it comes.'**
  String pacedOverExplain(int limit);

  /// Label of how an expense was paid (cash, bank transfer…), beside who it was paid to.
  ///
  /// In en, this message translates to:
  /// **'Paid with'**
  String get paidWithLabel;

  /// Editing a bill already charged to the tenant: why its amount is fixed and how to correct it.
  ///
  /// In en, this message translates to:
  /// **'This bill is a due on the tenant\'s ledger, so its amount can\'t change here. To correct it, void that due in the ledger, then charge the bill again.'**
  String get billAmountLocked;

  /// A reading's pace of use, in a list line.
  ///
  /// In en, this message translates to:
  /// **'about {units} units a month'**
  String paceAMonth(String units);

  /// Warning: a reading is higher than one taken on a later day.
  ///
  /// In en, this message translates to:
  /// **'This is higher than the later reading of {value} on {date}. Check the figure and the day.'**
  String readingHigher(String value, String date);

  /// Title of the dialog confirming that a paid bill is marked unpaid.
  ///
  /// In en, this message translates to:
  /// **'Mark this bill unpaid?'**
  String get markUnpaidTitle;

  /// What marking a bill unpaid clears.
  ///
  /// In en, this message translates to:
  /// **'The paid date, {date}, and who paid it will be cleared.'**
  String markUnpaidBody(String date);

  /// Title of the dialog confirming that a repair is cancelled.
  ///
  /// In en, this message translates to:
  /// **'Close this repair as cancelled?'**
  String get cancelRequestTitle;

  /// What cancelling a repair does.
  ///
  /// In en, this message translates to:
  /// **'It moves to Closed, with its details and expenses kept. You can reopen it later.'**
  String get cancelRequestBody;

  /// Confirms cancelling a repair (the dialog's other button is Cancel).
  ///
  /// In en, this message translates to:
  /// **'Close as cancelled'**
  String get closeAsCancelledAction;

  /// Charging a bill whose due date has passed.
  ///
  /// In en, this message translates to:
  /// **'That date has passed, so the due will show as overdue at once.'**
  String get chargeDuePassed;

  /// A retried add found the record already saved by the first try, which the connection lost; fields changed since then were not saved.
  ///
  /// In en, this message translates to:
  /// **'This was already saved, as first entered. Your later changes were not saved: edit it to make them.'**
  String get savedEarlierUnchanged;

  /// Why a closed repair with expenses cannot be deleted.
  ///
  /// In en, this message translates to:
  /// **'Expenses are recorded against this repair, so it cannot be deleted. If it was entered by mistake, delete those expenses first.'**
  String get requestHasExpensesClosed;

  /// What screen readers hear while the dashboard loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the dashboard'**
  String get loadingDashboard;

  /// Heading when the dashboard could not be read.
  ///
  /// In en, this message translates to:
  /// **'The dashboard could not be loaded'**
  String get dashboardLoadFailedTitle;

  /// Button that opens the search across properties, units and tenants.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;

  /// Title of the reports screen, and the button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// More: the entry leading to the reports.
  ///
  /// In en, this message translates to:
  /// **'Reports and statements'**
  String get reportsEntryTitle;

  /// More: what the reports hold.
  ///
  /// In en, this message translates to:
  /// **'Cash flow, payment scores, tax-year and owner statements, exports'**
  String get reportsEntrySummary;

  /// Heading of the month's figures on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'This month, {month}'**
  String thisMonthSection(String month);

  /// Label of the dashboard's figure of what is paid of the dues that fell due this month (not the money received this month, which receivedThisMonthLabel shows).
  ///
  /// In en, this message translates to:
  /// **'This month\'s dues paid'**
  String get collectedThisMonthLabel;

  /// Under the amount collected this month: what fell due and the share collected.
  ///
  /// In en, this message translates to:
  /// **'of {due} due, {rate} collected'**
  String collectedOfDue(String due, String rate);

  /// Label of the dashboard's figure of all the money received in payments this month, whichever month's dues it paid.
  ///
  /// In en, this message translates to:
  /// **'Received this month'**
  String get receivedThisMonthLabel;

  /// Under the money received this month: it counts payments of older dues and advances too.
  ///
  /// In en, this message translates to:
  /// **'Every payment recorded this month, for any month\'s dues'**
  String get receivedThisMonthCaption;

  /// Under the amount collected when nothing fell due this month yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing has fallen due this month yet.'**
  String get nothingDueThisMonth;

  /// Under the overdue figure: all that is owed, due or not.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed in all'**
  String owedInAll(String amount);

  /// Label of the figure of units with a tenant.
  ///
  /// In en, this message translates to:
  /// **'Units let'**
  String get unitsLetLabel;

  /// How many units are let, of the units that can be let.
  ///
  /// In en, this message translates to:
  /// **'{occupied} of {units}'**
  String unitsLetValue(String occupied, String units);

  /// Under the units let: the occupancy rate and how many units are vacant.
  ///
  /// In en, this message translates to:
  /// **'{rate} let, {vacant, plural, =0{none vacant} other{{vacant} vacant}}'**
  String occupancyCaption(String rate, int vacant);

  /// The units-let figure when the portfolio has no unit that can be let.
  ///
  /// In en, this message translates to:
  /// **'No units to let yet'**
  String get noUnitsToLet;

  /// The part of this month's dues not paid yet, in the month's bar.
  ///
  /// In en, this message translates to:
  /// **'Still to collect'**
  String get stillToCollect;

  /// What screen readers hear for the bar of this month's dues.
  ///
  /// In en, this message translates to:
  /// **'Of {expected} rupees due this month, {paid} are paid.'**
  String monthBarSummary(String expected, String paid);

  /// Heading of the insight cards on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'What needs attention'**
  String get insightsSection;

  /// Shown when there is no insight card.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs your attention today.'**
  String get noInsights;

  /// Badge of an insight card that needs action now.
  ///
  /// In en, this message translates to:
  /// **'Act now'**
  String get insightAlert;

  /// Badge of an insight card worth a look: not urgent, not only for information.
  ///
  /// In en, this message translates to:
  /// **'Worth a look'**
  String get insightWarning;

  /// Badge of an insight card worth knowing.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get insightInfo;

  /// Badge of an insight card with good news.
  ///
  /// In en, this message translates to:
  /// **'Good news'**
  String get insightGood;

  /// Button under the first insight cards: shows every card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Show all {count}}}'**
  String insightsShowAll(int count);

  /// Button under every insight card: shows only the first ones again.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get insightsShowFewer;

  /// Action of an insight card about one tenancy.
  ///
  /// In en, this message translates to:
  /// **'Open {tenant}\'s tenancy'**
  String openNamedTenancyAction(String tenant);

  /// Action of an insight card about several tenancies: the tenants, whose tenancies they open.
  ///
  /// In en, this message translates to:
  /// **'See tenants'**
  String get seeTenantsAction;

  /// Dashboard of a portfolio without properties.
  ///
  /// In en, this message translates to:
  /// **'No properties yet'**
  String get dashboardNoPropertiesTitle;

  /// Dashboard of a portfolio without properties, for those who may add one.
  ///
  /// In en, this message translates to:
  /// **'Add your first property to start collecting rent.'**
  String get dashboardNoPropertiesBody;

  /// Dashboard of a portfolio without properties, for those who may not add one.
  ///
  /// In en, this message translates to:
  /// **'Once a property is added, its rent shows here.'**
  String get dashboardNoPropertiesViewer;

  /// Dashboard of a portfolio with properties but no units.
  ///
  /// In en, this message translates to:
  /// **'No units yet'**
  String get dashboardNoUnitsTitle;

  /// Dashboard of a portfolio with properties but no units, for those who may add one.
  ///
  /// In en, this message translates to:
  /// **'Add a unit to a property to let it and collect its rent.'**
  String get dashboardNoUnitsBody;

  /// Dashboard of a portfolio with properties but no units, for those who may not add one.
  ///
  /// In en, this message translates to:
  /// **'Once a unit is added, its rent shows here.'**
  String get dashboardNoUnitsViewer;

  /// Action leading to the properties.
  ///
  /// In en, this message translates to:
  /// **'See properties'**
  String get seePropertiesAction;

  /// Insight: the share of this month's dues paid.
  ///
  /// In en, this message translates to:
  /// **'{rate} of this month\'s dues collected'**
  String insightCollectionTitle(String rate);

  /// Insight: what of this month's dues is not paid.
  ///
  /// In en, this message translates to:
  /// **'{amount} of them is still to collect.'**
  String insightCollectionBody(String amount);

  /// Insight: all of this month's dues are paid.
  ///
  /// In en, this message translates to:
  /// **'Every due of this month is paid.'**
  String get insightCollectionDone;

  /// Insight: rent owed for more than 90 days.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed for over 90 days'**
  String insightLongArrearsTitle(String amount);

  /// Insight: what to do about rent owed for more than 90 days.
  ///
  /// In en, this message translates to:
  /// **'Money this old is the hardest to recover. Talk to these tenants, or settle it from their deposit when they leave.'**
  String get insightLongArrearsBody;

  /// Opens the who-owes-what list.
  ///
  /// In en, this message translates to:
  /// **'See who owes'**
  String get seeWhoOwesAction;

  /// Insight: rent increases due or missed.
  ///
  /// In en, this message translates to:
  /// **'Rent increases to make'**
  String get insightIncrementTitle;

  /// Insight: rent increases whose date passed without the rent changing, and what they would add.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 increase was not made when due} other{{count} increases were not made when due}}: {amount} a month not charged.'**
  String insightIncrementMissed(int count, String amount);

  /// Insight: rent increases due soon.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 increase is due within 30 days.} other{{count} increases are due within 30 days.}}'**
  String insightIncrementUpcoming(int count);

  /// Insight: tenancies ending soon.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tenancy ends within 90 days} other{{count} tenancies end within 90 days}}'**
  String insightExpiringTitle(int count);

  /// Insight: the tenancy ending first.
  ///
  /// In en, this message translates to:
  /// **'{tenant}\'s ends first, {days, plural, =0{today} =1{in 1 day} other{in {days} days}}. Renew it or plan the move-out.'**
  String insightExpiringBody(String tenant, int days);

  /// Insight: tenancies not registered with the police.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tenancy is not registered with the police} other{{count} tenancies are not registered with the police}}'**
  String insightPoliceTitle(int count);

  /// Insight: registrations past a law's deadline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 is past the law\'s deadline: register it now.} other{{count} are past the law\'s deadline: register them now.}}'**
  String insightPoliceLate(int count);

  /// Insight: what police registration asks.
  ///
  /// In en, this message translates to:
  /// **'Register each by its deadline. Where no law sets one, the app reminds you.'**
  String get insightPoliceBody;

  /// Insight: tenancies whose police registration was submitted and is not yet confirmed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 police registration is waiting for confirmation} other{{count} police registrations are waiting for confirmation}}'**
  String insightPoliceSubmittedTitle(int count);

  /// Insight: besides those not registered, how many are submitted and not confirmed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more is submitted and waiting for confirmation.} other{{count} more are submitted and waiting for confirmation.}}'**
  String insightPoliceSubmittedLine(int count);

  /// Insight: what to do about a submitted registration.
  ///
  /// In en, this message translates to:
  /// **'You have done what the law asks. Update the tenancy once the police confirm it.'**
  String get insightPoliceSubmittedBody;

  /// Insight: vacant units.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit is vacant} other{{count} units are vacant}}'**
  String insightVacancyTitle(int count);

  /// Insight: what vacant units lose, and the longest vacancy.
  ///
  /// In en, this message translates to:
  /// **'Empty, {count, plural, =1{it costs} other{they cost}} you {amount} a month at the asking rent. {count, plural, =1{It has} other{The longest has}} been empty {days, plural, =0{since today} =1{for 1 day} other{for {days} days}}.'**
  String insightVacancyBody(int count, String amount, int days);

  /// Insight: deposits held are less than overdue rent.
  ///
  /// In en, this message translates to:
  /// **'Deposits cover only {cover} of overdue rent'**
  String insightDepositTitle(String cover);

  /// Insight: overdue rent against deposits held.
  ///
  /// In en, this message translates to:
  /// **'{overdue} is overdue and {held} of deposits is held. Collect before arrears grow beyond what deposits can settle.'**
  String insightDepositBody(String overdue, String held);

  /// Insight: unpaid bills and meters near the protected-tariff limit.
  ///
  /// In en, this message translates to:
  /// **'Utility bills need attention'**
  String get insightUtilityTitle;

  /// Insight: unpaid bills on connections in the landlord's name.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unpaid bill is in your name} other{{count} unpaid bills are in your name}}, {amount} in all: you are liable for them.'**
  String insightUtilityLandlord(int count, String amount);

  /// Insight: unpaid bills past their due date.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bill is past its due date.} other{{count} bills are past their due date.}}'**
  String insightUtilityOverdue(int count);

  /// Insight: protected-tariff meters over 200 units.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 protected-tariff meter went over 200 units on its latest bill.} other{{count} protected-tariff meters went over 200 units on their latest bill.}}'**
  String insightUtilityOverTariff(int count);

  /// Insight: protected-tariff meters near 200 units.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 protected-tariff meter is near 200 units.} other{{count} protected-tariff meters are near 200 units.}}'**
  String insightUtilityNearTariff(int count);

  /// Opens the utilities.
  ///
  /// In en, this message translates to:
  /// **'See utilities'**
  String get seeUtilitiesAction;

  /// Insight: expenses well above the recent average.
  ///
  /// In en, this message translates to:
  /// **'Expenses are up this month'**
  String get insightExpenseTitle;

  /// Insight: this month's expenses against the average.
  ///
  /// In en, this message translates to:
  /// **'{amount} so far, against {average} a month on average over the three months before.'**
  String insightExpenseBody(String amount, String average);

  /// Opens the expenses.
  ///
  /// In en, this message translates to:
  /// **'See expenses'**
  String get seeExpensesAction;

  /// Insight: units let for clearly less than the asking rent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit is let below its asking rent} other{{count} units are let below their asking rent}}'**
  String insightUnderpricedTitle(int count);

  /// Insight: how far rents fall short of asking rents.
  ///
  /// In en, this message translates to:
  /// **'Together {amount} a month below what you ask, the most at {unit}. Consider it at the next increase or renewal.'**
  String insightUnderpricedBody(String amount, String unit);

  /// Insight: cash held by members who are not owners.
  ///
  /// In en, this message translates to:
  /// **'{amount} in cash with caretakers'**
  String insightCashTitle(String amount);

  /// Insight: the member holding the most cash.
  ///
  /// In en, this message translates to:
  /// **'{name} holds {amount}.'**
  String insightCashHolder(String name, String amount);

  /// Insight: a large share of this month's money was cash.
  ///
  /// In en, this message translates to:
  /// **'Most of this month\'s money came in cash'**
  String get insightCashShareTitle;

  /// Insight: the share of this month's money received in cash.
  ///
  /// In en, this message translates to:
  /// **'{share} of this month\'s money came in cash.'**
  String insightCashShare(String share);

  /// Insight: how to carry less cash.
  ///
  /// In en, this message translates to:
  /// **'Bank transfers and regular handovers keep less cash in hand.'**
  String get insightCashAdvice;

  /// Opens the cash in hand.
  ///
  /// In en, this message translates to:
  /// **'See cash in hand'**
  String get seeCashAction;

  /// Heading of what tenants owe, by age, on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get owedSection;

  /// Under the heading of what is owed.
  ///
  /// In en, this message translates to:
  /// **'{amount} in all, by how long it has been owed'**
  String owedSectionHelp(String amount);

  /// Part of the amount owed not due yet.
  ///
  /// In en, this message translates to:
  /// **'Not yet due'**
  String get ageNotDue;

  /// Part of the amount owed overdue by 1 to 30 days.
  ///
  /// In en, this message translates to:
  /// **'1 to 30 days late'**
  String get age1to30;

  /// Part of the amount owed overdue by 31 to 60 days.
  ///
  /// In en, this message translates to:
  /// **'31 to 60 days late'**
  String get age31to60;

  /// Part of the amount owed overdue by 61 to 90 days.
  ///
  /// In en, this message translates to:
  /// **'61 to 90 days late'**
  String get age61to90;

  /// Part of the amount owed overdue by more than 90 days.
  ///
  /// In en, this message translates to:
  /// **'Over 90 days late'**
  String get ageOver90;

  /// What screen readers hear for the bar of what is owed by age.
  ///
  /// In en, this message translates to:
  /// **'{total} rupees owed: {notDue} not yet due, {early} up to 30 days late, {middle} 31 to 60 days late, {older} 61 to 90 days late, {late} over 90 days late.'**
  String ageingSummary(
    String total,
    String notDue,
    String early,
    String middle,
    String older,
    String late,
  );

  /// Heading of the tenancies with the most overdue.
  ///
  /// In en, this message translates to:
  /// **'Owing most'**
  String get owingMostSection;

  /// Opens the whole list.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAllAction;

  /// Button that opens the WhatsApp reminder for a tenancy.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get remindShortAction;

  /// When the tenant was last reminded.
  ///
  /// In en, this message translates to:
  /// **'Reminded {moment}'**
  String lastRemindedOn(String moment);

  /// Dashboard section: what is due or was missed, and what falls due soon.
  ///
  /// In en, this message translates to:
  /// **'Due and coming up'**
  String get upcomingSection;

  /// Shown when the timeline is empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing falls due in the coming weeks.'**
  String get upcomingEmpty;

  /// Timeline: a tenancy ends.
  ///
  /// In en, this message translates to:
  /// **'{tenant}\'s tenancy ends'**
  String timelineLeaseEnds(String tenant);

  /// Timeline: a rent increase falls due.
  ///
  /// In en, this message translates to:
  /// **'Rent increase for {tenant}'**
  String timelineIncrementDue(String tenant);

  /// Timeline: a rent increase whose date passed.
  ///
  /// In en, this message translates to:
  /// **'Rent increase not made for {tenant}'**
  String timelineIncrementMissed(String tenant);

  /// Timeline: the rent before and after an increase.
  ///
  /// In en, this message translates to:
  /// **'{unit}: {from} to {to}'**
  String timelineIncrementDetail(String unit, String from, String to);

  /// Timeline: a police registration deadline.
  ///
  /// In en, this message translates to:
  /// **'Register {tenant} with the police'**
  String timelinePolice(String tenant);

  /// Timeline: the deadline is the law's.
  ///
  /// In en, this message translates to:
  /// **'{unit}: deadline set by law'**
  String timelinePoliceLegal(String unit);

  /// Dashboard: a police registration still not made after the deadline a law sets.
  ///
  /// In en, this message translates to:
  /// **'{unit}: the deadline set by law has passed'**
  String timelinePoliceLegalPassed(String unit);

  /// Timeline: the date is only the app's reminder.
  ///
  /// In en, this message translates to:
  /// **'{unit}: the app\'s reminder, no law sets a deadline'**
  String timelinePoliceReminder(String unit);

  /// Timeline: a registration submitted and not confirmed.
  ///
  /// In en, this message translates to:
  /// **'{unit}: submitted, not yet confirmed'**
  String timelinePoliceSubmitted(String unit);

  /// Timeline: a tenant's CNIC expires.
  ///
  /// In en, this message translates to:
  /// **'{tenant}\'s CNIC expires'**
  String timelineCnicExpires(String tenant);

  /// Timeline: a tenant's CNIC expired.
  ///
  /// In en, this message translates to:
  /// **'{tenant}\'s CNIC has expired'**
  String timelineCnicExpired(String tenant);

  /// Timeline: what to do about an expiring CNIC.
  ///
  /// In en, this message translates to:
  /// **'Ask for a copy of the renewed card.'**
  String get timelineCnicHelp;

  /// Heading of the vacant units on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Vacant units'**
  String get vacantSection;

  /// How long a unit has stood vacant.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Vacant since today} =1{Vacant 1 day} other{Vacant {days} days}}'**
  String vacantFor(int days);

  /// Heading of the deposits held, tax withheld and expenses on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Deposits, tax and expenses'**
  String get heldAndSpentSection;

  /// Deposits held for active tenancies.
  ///
  /// In en, this message translates to:
  /// **'Deposits held'**
  String get depositsHeldLabel;

  /// Deposits agreed in active tenancies.
  ///
  /// In en, this message translates to:
  /// **'Deposits agreed'**
  String get depositsAgreedLabel;

  /// Income tax tenants withheld from this month's payments.
  ///
  /// In en, this message translates to:
  /// **'Tax withheld this month'**
  String get taxWithheldThisMonthLabel;

  /// This month's expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses this month'**
  String get expensesThisMonthLabel;

  /// The average monthly expenses of the three months before this one.
  ///
  /// In en, this message translates to:
  /// **'Monthly average of the 3 months before'**
  String get expensesAverageLabel;

  /// What screen readers hear while the cash flow loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the cash flow'**
  String get loadingCashflow;

  /// Heading when the cash flow could not be read.
  ///
  /// In en, this message translates to:
  /// **'The cash flow could not be loaded'**
  String get cashflowLoadFailedTitle;

  /// Heading of the cash-flow chart.
  ///
  /// In en, this message translates to:
  /// **'Cash flow, last 12 months'**
  String get cashflowSection;

  /// Chart series: money received.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get moneyInSeries;

  /// Chart series: expenses and deposits refunded.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get moneyOutSeries;

  /// Header of the chart table's month column.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthColumn;

  /// What screen readers hear for the cash-flow chart.
  ///
  /// In en, this message translates to:
  /// **'Money in and out each month from {first} to {last}: {moneyIn} rupees in and {moneyOut} rupees out in all.'**
  String cashflowSummary(
    String first,
    String last,
    String moneyIn,
    String moneyOut,
  );

  /// Shown when the cash flow is empty.
  ///
  /// In en, this message translates to:
  /// **'No money came in or went out in the last 12 months.'**
  String get cashflowEmpty;

  /// Total money received over the report.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get totalInLabel;

  /// Total expenses and refunds over the report.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get totalOutLabel;

  /// Money in less money out.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get netLabel;

  /// What screen readers hear while property performance loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the properties\' figures'**
  String get loadingPerformance;

  /// Heading when property performance could not be read.
  ///
  /// In en, this message translates to:
  /// **'The properties\' figures could not be loaded'**
  String get performanceLoadFailedTitle;

  /// Heading of each property's income and expenses.
  ///
  /// In en, this message translates to:
  /// **'Properties, last 12 months'**
  String get performanceSection;

  /// Shown when there is no property.
  ///
  /// In en, this message translates to:
  /// **'Add a property to see its income and expenses here.'**
  String get performanceEmpty;

  /// Rent and late fees received for a property.
  ///
  /// In en, this message translates to:
  /// **'Rent received'**
  String get rentIncomeLabel;

  /// Other dues received for a property.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get otherIncomeLabel;

  /// Expenses of a property.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get propertyExpensesLabel;

  /// Income less expenses of a property.
  ///
  /// In en, this message translates to:
  /// **'Net operating income'**
  String get noiLabel;

  /// Rent a year over the estimated value.
  ///
  /// In en, this message translates to:
  /// **'Gross yield'**
  String get grossYieldLabel;

  /// Net operating income a year over the estimated value.
  ///
  /// In en, this message translates to:
  /// **'Net yield'**
  String get netYieldLabel;

  /// A yield.
  ///
  /// In en, this message translates to:
  /// **'{percent} a year'**
  String yieldValue(String percent);

  /// Why a property has no yield.
  ///
  /// In en, this message translates to:
  /// **'Add the property\'s estimated value to see its yield.'**
  String get noYieldHelp;

  /// Title of the chart of each property's net operating income.
  ///
  /// In en, this message translates to:
  /// **'Net operating income by property'**
  String get noiChartTitle;

  /// What screen readers hear for the chart of net operating income.
  ///
  /// In en, this message translates to:
  /// **'Net operating income over the last 12 months: {best} earned most, {amount} rupees.'**
  String noiChartSummary(String best, String amount);

  /// Heading of tenants' payment scores.
  ///
  /// In en, this message translates to:
  /// **'Payment scores'**
  String get scoresSection;

  /// Under the heading of payment scores.
  ///
  /// In en, this message translates to:
  /// **'From each tenant\'s rent of the last 12 months.'**
  String get scoresHelp;

  /// What screen readers hear while scores load.
  ///
  /// In en, this message translates to:
  /// **'Loading the payment scores'**
  String get loadingScores;

  /// Heading when payment scores could not be read.
  ///
  /// In en, this message translates to:
  /// **'The payment scores could not be loaded'**
  String get scoresLoadFailedTitle;

  /// Shown when no tenant has a score yet.
  ///
  /// In en, this message translates to:
  /// **'Scores appear once rent has fallen due.'**
  String get scoresEmpty;

  /// Payment score band 75 to 100.
  ///
  /// In en, this message translates to:
  /// **'Pays on time'**
  String get scoreBandGood;

  /// Payment score band 50 to 74.
  ///
  /// In en, this message translates to:
  /// **'Sometimes late'**
  String get scoreBandFair;

  /// Payment score band below 50.
  ///
  /// In en, this message translates to:
  /// **'Often late'**
  String get scoreBandPoor;

  /// What screen readers hear for a payment score.
  ///
  /// In en, this message translates to:
  /// **'Payment score {score} out of 100, {band}'**
  String scoreSpoken(String score, String band);

  /// A payment score in a list.
  ///
  /// In en, this message translates to:
  /// **'{score}/100'**
  String scoreValue(String score);

  /// How many rent dues were paid on time.
  ///
  /// In en, this message translates to:
  /// **'On time {onTime} of {count}'**
  String scoreOnTime(String onTime, String count);

  /// Average days late, rounded to whole days (1 or more).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{About 1 day late on average} other{About {days} days late on average}}'**
  String scoreDaysLate(int days);

  /// Payment score: every due counted was paid on time.
  ///
  /// In en, this message translates to:
  /// **'Never late'**
  String get scoreNeverLate;

  /// Payment score: late on average by less than a day.
  ///
  /// In en, this message translates to:
  /// **'Less than a day late on average'**
  String get scoreUnderADayLate;

  /// Overdue rent in months of rent.
  ///
  /// In en, this message translates to:
  /// **'Owes {months} months\' rent'**
  String scoreArrears(String months);

  /// No overdue rent.
  ///
  /// In en, this message translates to:
  /// **'Nothing overdue'**
  String get scoreNoArrears;

  /// Heading of a tenant's payment score.
  ///
  /// In en, this message translates to:
  /// **'Payment score'**
  String get scoreSectionTitle;

  /// A tenant without a payment score.
  ///
  /// In en, this message translates to:
  /// **'Not enough rent history for a score yet.'**
  String get scoreNotYet;

  /// How the payment score is made.
  ///
  /// In en, this message translates to:
  /// **'Out of 100: 50 for paying on time, 30 for paying only a few days late, 20 for owing little.'**
  String get scoreFormulaHelp;

  /// Heading of the documents and exports on the reports screen.
  ///
  /// In en, this message translates to:
  /// **'Statements and exports'**
  String get statementsSection;

  /// Title of the tax-year statement.
  ///
  /// In en, this message translates to:
  /// **'Tax-year statement'**
  String get taxYearTitle;

  /// What the tax-year statement is.
  ///
  /// In en, this message translates to:
  /// **'Rental income per property, July to June, for your tax adviser'**
  String get taxYearSummary;

  /// Title of the monthly owner statement.
  ///
  /// In en, this message translates to:
  /// **'Owner statement'**
  String get ownerStatementTitle;

  /// What the owner statement is.
  ///
  /// In en, this message translates to:
  /// **'A month\'s money and what is owed, as a PDF for an owner abroad'**
  String get ownerStatementSummary;

  /// Title of the CSV export.
  ///
  /// In en, this message translates to:
  /// **'Export to a spreadsheet'**
  String get exportTitle;

  /// What the CSV export is.
  ///
  /// In en, this message translates to:
  /// **'The ledger, payments or expenses as a CSV file'**
  String get exportSummary;

  /// Field choosing the tax year.
  ///
  /// In en, this message translates to:
  /// **'Tax year'**
  String get taxYearLabel;

  /// A tax year in a list.
  ///
  /// In en, this message translates to:
  /// **'Tax year {endYear}: July {startYear} to June {endYear}'**
  String taxYearOption(String endYear, String startYear);

  /// What screen readers hear while the tax year loads.
  ///
  /// In en, this message translates to:
  /// **'Loading the tax year'**
  String get loadingTaxYear;

  /// Heading when the tax-year statement could not be read.
  ///
  /// In en, this message translates to:
  /// **'The tax year could not be loaded'**
  String get taxYearLoadFailedTitle;

  /// Heading of the warning on tax statements.
  ///
  /// In en, this message translates to:
  /// **'Not tax advice'**
  String get notTaxAdviceTitle;

  /// Warning on tax statements: informational only.
  ///
  /// In en, this message translates to:
  /// **'These figures come from your records, to help your tax adviser. They are not a tax calculation: the app never works out the tax you owe.'**
  String get notTaxAdviceBody;

  /// Rent and late fees settled in the tax year, cash plus tax withheld.
  ///
  /// In en, this message translates to:
  /// **'Rent received, gross'**
  String get grossRentLabel;

  /// One fifth of gross rent (s.15A).
  ///
  /// In en, this message translates to:
  /// **'Repairs allowance, one fifth'**
  String get repairsAllowanceLabel;

  /// Gross rent less the repairs allowance.
  ///
  /// In en, this message translates to:
  /// **'Rent after the repairs allowance'**
  String get netAfterAllowanceLabel;

  /// Expenses recorded for a property in the tax year.
  ///
  /// In en, this message translates to:
  /// **'Expenses recorded'**
  String get expensesRecordedLabel;

  /// Totals over every property.
  ///
  /// In en, this message translates to:
  /// **'All properties'**
  String get allPropertiesLabel;

  /// Shown when the tax year has nothing.
  ///
  /// In en, this message translates to:
  /// **'No rent or expenses were recorded in this tax year.'**
  String get taxYearEmpty;

  /// Note under expenses on tax statements.
  ///
  /// In en, this message translates to:
  /// **'Which expenses can be deducted is for your tax adviser to decide.'**
  String get deductibleNote;

  /// Shares a CSV file.
  ///
  /// In en, this message translates to:
  /// **'Share CSV'**
  String get shareCsvAction;

  /// Title of the tax-year statement file.
  ///
  /// In en, this message translates to:
  /// **'Tax-year statement {endYear}'**
  String taxYearFileTitle(String endYear);

  /// Heading of the tax-year statement PDF.
  ///
  /// In en, this message translates to:
  /// **'Rental income, tax year {endYear}'**
  String taxYearDocumentTitle(String endYear);

  /// Field choosing the month of the owner statement.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get ownerStatementMonthLabel;

  /// Title of the owner statement file and document.
  ///
  /// In en, this message translates to:
  /// **'Owner statement, {month}'**
  String ownerStatementFileTitle(String month);

  /// Owner statement: what was received.
  ///
  /// In en, this message translates to:
  /// **'Money received'**
  String get moneyReceivedHeading;

  /// Owner statement: rent and late fees received.
  ///
  /// In en, this message translates to:
  /// **'Rent and late fees'**
  String get rentAndFeesLabel;

  /// Owner statement: deposits received.
  ///
  /// In en, this message translates to:
  /// **'Security deposits'**
  String get depositsReceivedLabel;

  /// Owner statement: other dues received.
  ///
  /// In en, this message translates to:
  /// **'Other dues'**
  String get otherDuesLabel;

  /// Owner statement: money received that paid no due yet.
  ///
  /// In en, this message translates to:
  /// **'Kept as credit'**
  String get unallocatedLabel;

  /// Owner statement: what was paid out.
  ///
  /// In en, this message translates to:
  /// **'Money paid out'**
  String get moneyPaidOutHeading;

  /// Owner statement: deposits refunded.
  ///
  /// In en, this message translates to:
  /// **'Deposits refunded'**
  String get depositRefundsLabel;

  /// Owner statement: received less paid out.
  ///
  /// In en, this message translates to:
  /// **'Net for the month'**
  String get netCashLabel;

  /// Owner statement: what is owed, as of the day it is made.
  ///
  /// In en, this message translates to:
  /// **'Owed by tenants on {date}'**
  String owedOnHeading(String date);

  /// Owner statement: cash members hold, as of the day it is made.
  ///
  /// In en, this message translates to:
  /// **'Cash held on {date}'**
  String cashHeldOnHeading(String date);

  /// Footer of the owner statement.
  ///
  /// In en, this message translates to:
  /// **'Made from the portfolio\'s records. For information: not an audited account.'**
  String get ownerStatementFooter;

  /// Choice of what to export.
  ///
  /// In en, this message translates to:
  /// **'What to export'**
  String get exportWhatLabel;

  /// Export choice: every due.
  ///
  /// In en, this message translates to:
  /// **'Ledger: every rent and charge'**
  String get exportLedger;

  /// Export choice: payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get exportPayments;

  /// Export choice: expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get exportExpenses;

  /// Choice of the period to export.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get exportPeriodLabel;

  /// Period: this month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get periodThisMonth;

  /// Period: last month.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get periodLastMonth;

  /// Makes and shares the CSV file.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportAction;

  /// Shown when an export has no rows.
  ///
  /// In en, this message translates to:
  /// **'Nothing was recorded in that period.'**
  String get exportEmpty;

  /// Title of an exported file.
  ///
  /// In en, this message translates to:
  /// **'{what}, {period}'**
  String exportFileTitle(String what, String period);

  /// A column header of amounts in rupees.
  ///
  /// In en, this message translates to:
  /// **'{label} (Rs)'**
  String inRupees(String label);

  /// CSV column: the month a due is for.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get csvMonth;

  /// CSV column: the note on a due.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get csvDescription;

  /// CSV column: the amount waived.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get csvWaived;

  /// CSV column: the amount still owed.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get csvOwed;

  /// CSV column: whether it was voided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get csvVoided;

  /// CSV cell: yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get csvYes;

  /// CSV column: the repair an expense paid for.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get csvRepair;

  /// Title of the search screen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// Hint of the search field.
  ///
  /// In en, this message translates to:
  /// **'Name, phone or CNIC'**
  String get searchHint;

  /// Shown before anything is typed.
  ///
  /// In en, this message translates to:
  /// **'Find a property, unit or tenant by name, locality, phone or CNIC.'**
  String get searchIntro;

  /// Shown when the search is too short.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 letters or digits.'**
  String get searchTooShort;

  /// Search: how many results were found, said to screen readers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String searchResultCount(int count);

  /// Shown when nothing matches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches {query}.'**
  String searchNoMatches(String query);

  /// Help when nothing matches.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or search by phone or CNIC.'**
  String get searchNoMatchesBody;

  /// Heading when a search failed.
  ///
  /// In en, this message translates to:
  /// **'The search did not finish'**
  String get searchFailedTitle;

  /// What screen readers hear while searching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get searching;

  /// A search result: what it is and a detail.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {detail}'**
  String searchResultLine(String kind, String detail);

  /// Column of how many days the oldest overdue due is late.
  ///
  /// In en, this message translates to:
  /// **'Days overdue'**
  String get daysOverdueLabel;

  /// A time of day on the 12-hour clock named by its part of the day, as Urdu writes times (CLDR's flexible day periods for Urdu, pattern h:mm B): '10:42 صبح'. Only the Urdu UI shows it; English uses AM and PM. morning is 4:00-11:59, noon 12:00-15:59, afternoon 16:00-17:59, evening 18:00-19:59, other (night) 20:00-3:59.
  ///
  /// In en, this message translates to:
  /// **'{time} {period, select, morning{in the morning} noon{in the afternoon} afternoon{in the late afternoon} evening{in the evening} other{at night}}'**
  String timeOfDay(String time, String period);

  /// The way out of the dialog that asks to cancel a repair, in place of 'Cancel' beside 'Close as cancelled' (which would be ambiguous): the repair stays as it is.
  ///
  /// In en, this message translates to:
  /// **'Keep the repair'**
  String get keepRepairAction;

  /// The way out of the dialog that asks to cancel an invitation, in place of 'Cancel' beside 'Cancel invitation' (ambiguous, in Urdu too: both are منسوخ کریں): the invitation stays.
  ///
  /// In en, this message translates to:
  /// **'Keep the invitation'**
  String get keepInvitationAction;

  /// Heading of the part of the portfolio settings where an owner deletes the portfolio.
  ///
  /// In en, this message translates to:
  /// **'Delete this portfolio'**
  String get deletePortfolioSection;

  /// What deleting a portfolio does, under its heading.
  ///
  /// In en, this message translates to:
  /// **'Everything in it goes for good, for everyone in it: properties, tenants, tenancies, payments and receipts, expenses and documents. Keep copies of any receipts and statements you need first.'**
  String get deletePortfolioHelp;

  /// Button that starts deleting the portfolio (it asks for the name first), and the dialog's confirm button.
  ///
  /// In en, this message translates to:
  /// **'Delete portfolio'**
  String get deletePortfolioAction;

  /// Title of the dialog that confirms deleting a portfolio.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and everything in it?'**
  String deletePortfolioTitle(String name);

  /// Body of the dialog that confirms deleting a portfolio.
  ///
  /// In en, this message translates to:
  /// **'Every member loses it at once, and it cannot be recovered, not even by us.'**
  String get deletePortfolioBody;

  /// Confirmation after a portfolio was deleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String portfolioDeleted(String name);

  /// Title of the sheet that searches the tenants to start a tenancy with.
  ///
  /// In en, this message translates to:
  /// **'Choose the tenant'**
  String get chooseTenantTitle;

  /// Button of the new tenancy form that opens the tenant search, while none is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose the tenant'**
  String get chooseTenantAction;

  /// Button of the new tenancy form that opens the tenant search, once one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose another tenant'**
  String get changeTenantAction;

  /// Shown for the tenant or the unit of a new tenancy before one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen yet'**
  String get noTenantChosen;

  /// Title of the sheet that lists the properties, then their units, to start a tenancy in.
  ///
  /// In en, this message translates to:
  /// **'Choose the unit'**
  String get chooseUnitTitle;

  /// Button of the new tenancy form that opens the unit list, while none is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose the unit'**
  String get chooseUnitAction;

  /// Button of the new tenancy form that opens the unit list, once one is chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose another unit'**
  String get changeUnitAction;

  /// In the unit sheet, goes back from one property's units to the list of properties.
  ///
  /// In en, this message translates to:
  /// **'Other properties'**
  String get otherPropertyAction;

  /// Error when a new tenancy is started without a unit.
  ///
  /// In en, this message translates to:
  /// **'Choose the unit.'**
  String get validationChooseUnit;
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
