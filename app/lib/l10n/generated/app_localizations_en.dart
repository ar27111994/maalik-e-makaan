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
  String get groupingWestern => 'Western (Rs 1,250,000)';

  @override
  String get groupingSouthAsian => 'Lakh and crore (Rs 12,50,000)';

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

  @override
  String get saveAction => 'Save';

  @override
  String get doneAction => 'Done';

  @override
  String get notNowAction => 'Not now';

  @override
  String get goToAppAction => 'Go to the app';

  @override
  String validationNumberRange(int min, int max) {
    return 'Enter a number from $min to $max.';
  }

  @override
  String get validationPercent =>
      'Enter a percentage from 0 to 100, with at most 2 decimals.';

  @override
  String get validationRaast =>
      'Enter a Pakistani mobile number, like 03001234567.';

  @override
  String get validationIban =>
      'Enter a Pakistani IBAN, like PK36 SCBL 0000 0011 2345 6702.';

  @override
  String get linkNotOpened => 'The link could not be opened.';

  @override
  String get roleOwnerHelp =>
      'Everything, including the team and the payment details.';

  @override
  String get roleManagerHelp =>
      'Runs properties, tenants and tenancies, and records money.';

  @override
  String get roleAccountantHelp =>
      'Records payments and expenses, and sees everything else.';

  @override
  String get roleViewerHelp => 'Sees everything and changes nothing.';

  @override
  String get teamTitle => 'Team';

  @override
  String get teamSummary => 'Who can see and run this portfolio';

  @override
  String get portfolioDetailsTitle => 'Portfolio details';

  @override
  String get portfolioDetailsSummary =>
      'Name, tenancy defaults and payment details';

  @override
  String get teamMembersSection => 'People';

  @override
  String get teamInvitationsSection => 'Invitations waiting for an answer';

  @override
  String get teamInvitationsHelp =>
      'Each link works once, for 7 days, and only for the address it was sent to.';

  @override
  String memberYou(String name) {
    return '$name (you)';
  }

  @override
  String get memberNoName => 'A member without a name';

  @override
  String memberRoleAndEmail(String role, String email) {
    return '$role · $email';
  }

  @override
  String get teamLoadFailedTitle => 'The team could not be loaded';

  @override
  String get loadingTeam => 'Loading the team';

  @override
  String get inviteAction => 'Invite someone';

  @override
  String invitationExpires(String role, String date) {
    return '$role · Until $date';
  }

  @override
  String invitationExpired(String role, String date) {
    return '$role · Expired on $date';
  }

  @override
  String get invitationExpiredBadge => 'Expired';

  @override
  String get inviteAgainAction => 'Invite again';

  @override
  String get revokeInvitationAction => 'Cancel invitation';

  @override
  String revokeInvitationTitle(String email) {
    return 'Cancel the invitation to $email?';
  }

  @override
  String get revokeInvitationBody =>
      'The link stops working. You can invite them again later.';

  @override
  String get invitationCancelled => 'Invitation cancelled.';

  @override
  String get memberRoleLabel => 'Role';

  @override
  String get changeRoleAction => 'Change role';

  @override
  String roleChanged(String name, String role) {
    return '$name is now $role.';
  }

  @override
  String get onlyOwnerNote =>
      'A portfolio always keeps an owner. Make someone else an owner before changing this role.';

  @override
  String get removeMemberAction => 'Remove from portfolio';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeMemberBody =>
      'They lose access to this portfolio at once. Everything they recorded stays.';

  @override
  String memberRemoved(String name) {
    return '$name was removed.';
  }

  @override
  String get leaveAction => 'Leave portfolio';

  @override
  String leaveTitle(String portfolio) {
    return 'Leave $portfolio?';
  }

  @override
  String get leaveBody =>
      'You lose access at once. Only an owner can invite you back.';

  @override
  String get leaveLastOwner =>
      'You are the only owner. Make someone else an owner before you leave.';

  @override
  String leftPortfolio(String portfolio) {
    return 'You left $portfolio.';
  }

  @override
  String get inviteTitle => 'Invite someone';

  @override
  String get inviteBody =>
      'They get an e-mail with a link that works once, for 7 days, and only for this address. You can also share the link yourself.';

  @override
  String get inviteEmailLabel => 'Their e-mail';

  @override
  String get inviteRoleLabel => 'Their role';

  @override
  String get sendInvitationAction => 'Send invitation';

  @override
  String get invitationReadyTitle => 'Invitation ready';

  @override
  String deliverySent(String email) {
    return 'We e-mailed the invitation to $email.';
  }

  @override
  String deliveryNotConfigured(String email) {
    return 'E-mail is not set up, so nothing was sent. Share the link with $email yourself.';
  }

  @override
  String deliveryRateLimited(String email) {
    return 'Too many e-mails went to this address or from you in the last hour, so none was sent. Share the link with $email yourself.';
  }

  @override
  String deliveryFailed(String email) {
    return 'The e-mail to $email could not be sent. Share the link yourself.';
  }

  @override
  String deliveryUnknown(String email) {
    return 'If $email did not get an e-mail, share the link yourself.';
  }

  @override
  String invitationValidUntil(String date, String email) {
    return 'The link works once, until $date, and only for $email.';
  }

  @override
  String get invitationLinkLabel => 'Invitation link';

  @override
  String get copyLinkAction => 'Copy link';

  @override
  String get linkCopied => 'Link copied.';

  @override
  String get shareWhatsAppAction => 'Share on WhatsApp';

  @override
  String invitationShareMessage(String portfolio, String url) {
    return 'You are invited to $portfolio on Maalik-e-Makaan. Open this link to join: $url';
  }

  @override
  String get tenancyDefaultsSection => 'New tenancies start with';

  @override
  String get tenancyDefaultsHelp => 'You can change them for each tenancy.';

  @override
  String get dueDayLabel => 'Rent due on day';

  @override
  String get dueDayHelper => 'From 1 to 28, so every month has it.';

  @override
  String get graceDaysLabel => 'Grace days';

  @override
  String get graceDaysHelper =>
      'Days after the due day before rent counts as late.';

  @override
  String get incrementLabel => 'Yearly increase (%)';

  @override
  String get paymentDetailsSection => 'Payment details';

  @override
  String get paymentDetailsHelp =>
      'Tenants see them on receipts and reminders.';

  @override
  String get landlordNameLabel => 'Name on receipts';

  @override
  String get landlordPhoneLabel => 'Phone on receipts';

  @override
  String get raastIdLabel => 'Raast ID';

  @override
  String get raastIdHelper =>
      'The mobile number registered for Raast, like 03001234567.';

  @override
  String get bankAccountTitleLabel => 'Bank account title';

  @override
  String get ibanLabel => 'IBAN';

  @override
  String get ibanHelper => '24 characters, starting with PK.';

  @override
  String get portfolioDetailsSaved => 'Portfolio details saved.';

  @override
  String get portfolioDetailsLoadFailedTitle =>
      'The portfolio details could not be loaded';

  @override
  String get loadingPortfolioDetails => 'Loading the portfolio details';

  @override
  String get acceptInvitationTitle => 'Invitation';

  @override
  String get acceptingInvitation => 'Opening your invitation…';

  @override
  String invitationAcceptedTitle(String portfolio) {
    return 'Welcome to $portfolio';
  }

  @override
  String invitationAcceptedBody(String role) {
    return 'You joined as $role.';
  }

  @override
  String get openPortfolioAction => 'Open the portfolio';

  @override
  String get invitationFailedTitle => 'This invitation cannot be used';

  @override
  String get invitationInvalidBody =>
      'This is not a working invitation link. Ask for a new invitation.';

  @override
  String get invitationRevokedBody =>
      'This invitation was cancelled. Ask an owner of the portfolio for a new one.';

  @override
  String get invitationAlreadyUsedBody =>
      'This invitation was accepted already, by another account. Ask for a new one.';

  @override
  String get invitationExpiredBody =>
      'This invitation has expired: invitations work for 7 days. Ask for a new one.';

  @override
  String get invitationEmailNotVerifiedBody =>
      'Confirm your e-mail address first, then open the invitation link again.';

  @override
  String get invitationEmailMismatchBody =>
      'This invitation was sent to another e-mail address. Sign out, then sign in or create an account with the address it was sent to.';

  @override
  String get invitationUnknownBody =>
      'This invitation cannot be accepted. Ask for a new one.';

  @override
  String get noInvitationBody =>
      'No invitation is waiting on this device. Open the link in the invitation e-mail.';

  @override
  String get invitationNotAcceptedTitle => 'The invitation could not be opened';

  @override
  String get fewerDaysAction => 'Fewer days';

  @override
  String get moreDaysAction => 'More days';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: 'No days',
    );
    return '$_temp0';
  }

  @override
  String get invitationWorksUntil => 'Works until';

  @override
  String get invitationAcceptedNoName => 'You joined the portfolio';

  @override
  String get propertyTypeHouse => 'House';

  @override
  String get propertyTypeApartmentBuilding => 'Apartment building';

  @override
  String get propertyTypeApartment => 'Flat';

  @override
  String get propertyTypePlaza => 'Plaza';

  @override
  String get propertyTypeShop => 'Shop';

  @override
  String get propertyTypeOffice => 'Office';

  @override
  String get propertyTypeHostel => 'Hostel';

  @override
  String get propertyTypeFarmhouse => 'Farmhouse';

  @override
  String get propertyTypeWarehouse => 'Warehouse';

  @override
  String get propertyTypePlot => 'Plot';

  @override
  String get propertyTypeOther => 'Other';

  @override
  String get provincePunjab => 'Punjab';

  @override
  String get provinceSindh => 'Sindh';

  @override
  String get provinceKhyberPakhtunkhwa => 'Khyber Pakhtunkhwa';

  @override
  String get provinceBalochistan => 'Balochistan';

  @override
  String get provinceIslamabad => 'Islamabad';

  @override
  String get provinceGilgitBaltistan => 'Gilgit-Baltistan';

  @override
  String get provinceAzadKashmir => 'Azad Kashmir';

  @override
  String policeHintPossession(String province, String days) {
    return '$province: register each tenancy with the police within $days of the tenant moving in.';
  }

  @override
  String policeHintAgreement(String province, String days) {
    return '$province: register each tenancy with the police within $days of signing the agreement.';
  }

  @override
  String policeHintReminder(String province) {
    return '$province: no law the app knows of sets a deadline. The app reminds you to register each tenancy with the police a day after the tenant moves in.';
  }

  @override
  String get areaUnitMarla => 'Marla';

  @override
  String get areaUnitKanal => 'Kanal';

  @override
  String get areaUnitSquareFeet => 'Square feet';

  @override
  String get areaUnitSquareYards => 'Square yards';

  @override
  String get areaUnitSquareMetres => 'Square metres';

  @override
  String get areaUnitAcre => 'Acres';

  @override
  String areaValue(String size, String unit) {
    return '$size $unit';
  }

  @override
  String coveredAreaValue(String area) {
    return '$area sq ft';
  }

  @override
  String get unitTypeEntireProperty => 'Entire property';

  @override
  String get unitTypePortion => 'Portion';

  @override
  String get unitTypeApartment => 'Flat';

  @override
  String get unitTypeRoom => 'Room';

  @override
  String get unitTypeBed => 'Bed';

  @override
  String get unitTypeShop => 'Shop';

  @override
  String get unitTypeOffice => 'Office';

  @override
  String get unitTypeFloor => 'Floor';

  @override
  String get unitTypeWarehouse => 'Warehouse';

  @override
  String get occupancyOccupied => 'Let';

  @override
  String get occupancyUpcoming => 'Tenancy starts soon';

  @override
  String get occupancyVacant => 'Vacant';

  @override
  String occupancyVacantSince(String date) {
    return 'Vacant since $date';
  }

  @override
  String get occupancyUnavailable => 'Not available';

  @override
  String get occupancyArchived => 'Archived';

  @override
  String get occupancyUnknown => 'Status unknown';

  @override
  String get addPropertyAction => 'Add property';

  @override
  String get propertiesEmptyTitle => 'No properties yet';

  @override
  String get propertiesEmptyBody =>
      'Add a house, a plaza or a plot, then the portions, flats or shops you rent out in it.';

  @override
  String get archivedPropertiesEmpty => 'No archived properties.';

  @override
  String get archivedPropertiesEmptyBody =>
      'Properties you archive keep their history and wait here.';

  @override
  String get filterInUse => 'In use';

  @override
  String get filterArchived => 'Archived';

  @override
  String get loadMoreAction => 'Show more';

  @override
  String get propertiesLoadFailedTitle => 'The properties could not be loaded';

  @override
  String get loadingProperties => 'Loading the properties';

  @override
  String listDetail(String first, String second) {
    return '$first · $second';
  }

  @override
  String get newPropertyTitle => 'New property';

  @override
  String get editPropertyTitle => 'Edit property';

  @override
  String get propertySectionBasics => 'The property';

  @override
  String get propertySectionLocation => 'Where it is';

  @override
  String get propertySectionSize => 'Size';

  @override
  String get propertySectionValue => 'Value';

  @override
  String get propertyNameLabel => 'Name';

  @override
  String get propertyNameHelper =>
      'As you call it, like Gulberg house or Saddar shops.';

  @override
  String get typeLabel => 'Type';

  @override
  String get addressLabel => 'Address';

  @override
  String get localityLabel => 'Area or society';

  @override
  String get cityLabel => 'City';

  @override
  String get provinceLabel => 'Province';

  @override
  String get provinceHelper =>
      'It decides the rules that apply, such as police registration.';

  @override
  String get plotSizeLabel => 'Plot size';

  @override
  String get plotUnitLabel => 'Measured in';

  @override
  String get coveredAreaLabel => 'Covered area (sq ft)';

  @override
  String get yearBuiltLabel => 'Year built';

  @override
  String get purchasePriceLabel => 'Purchase price';

  @override
  String get purchasedOnLabel => 'Bought on';

  @override
  String get estimatedValueLabel => 'Estimated value';

  @override
  String get valueEstimatedOnLabel => 'Value estimated on';

  @override
  String get propertyTaxRefLabel => 'Property tax reference';

  @override
  String get notesLabel => 'Notes';

  @override
  String get validationPositiveNumber =>
      'Enter a number above 0, with at most 2 decimals.';

  @override
  String get validationPlotUnit => 'Choose what the plot size is measured in.';

  @override
  String get validationAmount => 'Enter an amount, like 25,000.';

  @override
  String propertyAdded(String name) {
    return '$name added.';
  }

  @override
  String propertySaved(String name) {
    return '$name saved.';
  }

  @override
  String get propertyDetailsSection => 'Details';

  @override
  String get unitsSection => 'Units';

  @override
  String get unitsSectionHelp =>
      'The portions, flats, rooms or shops you rent out.';

  @override
  String get addUnitAction => 'Add unit';

  @override
  String get unitsEmpty =>
      'No units yet. Add each part you rent out, even when it is the whole property.';

  @override
  String get editAction => 'Edit';

  @override
  String get archiveAction => 'Archive';

  @override
  String get restoreAction => 'Put back in use';

  @override
  String get deleteAction => 'Delete';

  @override
  String archivedBanner(String date) {
    return 'Archived on $date. It keeps its history; put it back in use to change it.';
  }

  @override
  String archivePropertyTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get archivePropertyBody =>
      'It leaves your lists but keeps its units, tenancies and money. You can put it back in use later.';

  @override
  String propertyArchived(String name) {
    return '$name archived.';
  }

  @override
  String propertyRestored(String name) {
    return '$name is back in use.';
  }

  @override
  String deletePropertyTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deletePropertyBody =>
      'Only for a property added by mistake: it goes for good, with its units. A property with tenancies or expenses cannot be deleted; archive it instead.';

  @override
  String typeToConfirm(String name) {
    return 'Type $name to confirm';
  }

  @override
  String propertyDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String get propertyLoadFailedTitle => 'This property could not be loaded';

  @override
  String get loadingProperty => 'Loading the property';

  @override
  String get unitsLoadFailedTitle => 'The units could not be loaded';

  @override
  String get reasonDuplicatePropertyName =>
      'Another property in use has this name. Choose another.';

  @override
  String get reasonDuplicateUnitLabel =>
      'Another unit of this property has this name. Choose another.';

  @override
  String get reasonStillInUse =>
      'A tenancy or an expense still refers to this, so it cannot be deleted. Archive it instead.';

  @override
  String get newUnitTitle => 'New unit';

  @override
  String get editUnitTitle => 'Edit unit';

  @override
  String get unitLabelLabel => 'Name or number';

  @override
  String get unitLabelHelper => 'Like Ground floor, Flat 2 or Shop 5.';

  @override
  String get floorLabel => 'Floor';

  @override
  String get bedroomsLabel => 'Bedrooms';

  @override
  String get bathroomsLabel => 'Bathrooms';

  @override
  String get fewerAction => 'Fewer';

  @override
  String get moreAction => 'More';

  @override
  String get furnishedLabel => 'Furnished';

  @override
  String get unfurnishedValue => 'Unfurnished';

  @override
  String get askingRentLabel => 'Asking rent';

  @override
  String get askingRentHelper => 'What you ask for it each month.';

  @override
  String askingRentValue(String rent) {
    return 'Asking $rent';
  }

  @override
  String get availableLabel => 'Available to rent';

  @override
  String get availableHelp =>
      'Turn off while it is being renovated or you live in it.';

  @override
  String get unitPropertyLabel => 'Property';

  @override
  String get occupancyLabel => 'Occupancy';

  @override
  String unitAdded(String name) {
    return '$name added.';
  }

  @override
  String unitSaved(String name) {
    return '$name saved.';
  }

  @override
  String archiveUnitTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get archiveUnitBody =>
      'It leaves your lists but keeps its tenancies and money. A unit that is let now can still be archived; end its tenancy first if it has ended.';

  @override
  String unitArchived(String name) {
    return '$name archived.';
  }

  @override
  String unitRestored(String name) {
    return '$name is back in use.';
  }

  @override
  String deleteUnitTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteUnitBody =>
      'Only for a unit added by mistake: it goes for good. A unit with tenancies or expenses cannot be deleted; archive it instead.';

  @override
  String unitDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String get unitLoadFailedTitle => 'This unit could not be loaded';

  @override
  String get loadingUnit => 'Loading the unit';

  @override
  String roomCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '1',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get tenantKindIndividual => 'Person';

  @override
  String get tenantKindCompany => 'Company';

  @override
  String get tenantKindGovernment => 'Government office';

  @override
  String get guardianSonOf => 'Son of';

  @override
  String get guardianDaughterOf => 'Daughter of';

  @override
  String get guardianWifeOf => 'Wife of';

  @override
  String guardianLine(String relation, String name) {
    return '$relation $name';
  }

  @override
  String get addTenantAction => 'Add tenant';

  @override
  String get searchTenantsHint => 'Search by name, phone or CNIC';

  @override
  String get tenantsEmptyTitle => 'No tenants yet';

  @override
  String get tenantsEmptyBody =>
      'Add the people or businesses who rent from you, then start their tenancy from a unit.';

  @override
  String get archivedTenantsEmpty => 'No archived tenants.';

  @override
  String get archivedTenantsEmptyBody =>
      'Tenants you archive keep their history and wait here.';

  @override
  String noTenantMatches(String search) {
    return 'No tenant matches $search.';
  }

  @override
  String get tenantsLoadFailedTitle => 'The tenants could not be loaded';

  @override
  String get loadingTenants => 'Loading the tenants';

  @override
  String get tenantLoadFailedTitle => 'This tenant could not be loaded';

  @override
  String get loadingTenant => 'Loading the tenant';

  @override
  String get newTenantTitle => 'New tenant';

  @override
  String get editTenantTitle => 'Edit tenant';

  @override
  String get tenantSectionWho => 'Who they are';

  @override
  String get tenantSectionIdentity => 'Identity';

  @override
  String get tenantSectionContact => 'How to reach them';

  @override
  String get tenantSectionWork => 'Work and addresses';

  @override
  String get tenantSectionEmergency => 'Emergency contact';

  @override
  String get tenantSectionReferences => 'References';

  @override
  String get tenantSectionHousehold => 'Household and tax';

  @override
  String get tenantSectionConsent => 'Consent';

  @override
  String get tenantKindLabel => 'Tenant is a';

  @override
  String get fullNameTenantLabel => 'Full name';

  @override
  String get guardianRelationLabel => 'S/O, D/O or W/O';

  @override
  String get guardianNameLabel => 'Father\'s or husband\'s name';

  @override
  String get cnicLabel => 'CNIC';

  @override
  String get cnicHelper => '13 digits, as on the card.';

  @override
  String get validationCnic =>
      'Enter the 13 digits of a CNIC, like 35202-1234567-1.';

  @override
  String get cnicExpiryLabel => 'CNIC expires on';

  @override
  String get cnicExpired => 'CNIC expired';

  @override
  String get ntnLabel => 'NTN';

  @override
  String get validationNtn =>
      'Enter the NTN as issued, 6 to 15 letters, digits or dashes.';

  @override
  String get altPhoneLabel => 'Other phone';

  @override
  String get occupationLabel => 'Occupation';

  @override
  String get employerLabel => 'Employer';

  @override
  String get permanentAddressLabel => 'Permanent address';

  @override
  String get previousAddressLabel => 'Previous address';

  @override
  String get contactNameLabel => 'Name';

  @override
  String get contactRelationLabel => 'Relation';

  @override
  String referenceLabel(int number) {
    return 'Reference $number';
  }

  @override
  String get householdSizeLabel => 'People living there';

  @override
  String get withholdingTaxLabel => 'Deducts withholding tax';

  @override
  String get withholdingTaxHelp =>
      'Companies and government offices deduct tax under section 155 from the rent they pay.';

  @override
  String get consentLabel => 'I told the tenant what details are kept and why';

  @override
  String get consentNoteLabel => 'What they agreed to';

  @override
  String consentRecorded(String date) {
    return 'Consent recorded on $date';
  }

  @override
  String get consentMissing => 'Consent not recorded';

  @override
  String tenantAdded(String name) {
    return '$name added.';
  }

  @override
  String tenantSaved(String name) {
    return '$name saved.';
  }

  @override
  String get duplicateTenantTitle => 'Is this the same tenant?';

  @override
  String duplicateTenantBody(String names) {
    return '$names already has this CNIC or phone number. Save anyway?';
  }

  @override
  String get saveAnywayAction => 'Save anyway';

  @override
  String get reasonDuplicateCnic => 'Another tenant in use has this CNIC.';

  @override
  String get tenantDetailsSection => 'Details';

  @override
  String get tenantTenanciesSection => 'Tenancies';

  @override
  String archiveTenantTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get archiveTenantBody =>
      'They leave your lists but keep their tenancies, payments and receipts. You can put them back in use later.';

  @override
  String tenantArchived(String name) {
    return '$name archived.';
  }

  @override
  String tenantRestored(String name) {
    return '$name is back in use.';
  }

  @override
  String deleteTenantTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteTenantBody =>
      'Only for a tenant added by mistake: their details go for good. A tenant with a tenancy cannot be deleted; archive them instead.';

  @override
  String tenantDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String get emailOptionalLabel => 'E-mail';

  @override
  String referenceNameLabel(int number) {
    return 'Reference $number: name';
  }

  @override
  String referencePhoneLabel(int number) {
    return 'Reference $number: phone';
  }

  @override
  String get tenancyTitle => 'Tenancy';

  @override
  String get newTenancyTitle => 'New tenancy';

  @override
  String get editTenancyTitle => 'Edit tenancy terms';

  @override
  String get startTenancyAction => 'Start tenancy';

  @override
  String get leaseActive => 'Active';

  @override
  String get leaseEnded => 'Ended';

  @override
  String leaseUpcoming(String date) {
    return 'Starts $date';
  }

  @override
  String unitAtProperty(String unit, String property) {
    return '$unit, $property';
  }

  @override
  String get tenantLabel => 'Tenant';

  @override
  String get unitLabel => 'Unit';

  @override
  String get validationChooseTenant => 'Choose the tenant.';

  @override
  String get noTenantsToChoose =>
      'Add the tenant first: there is no tenant in use to choose.';

  @override
  String get leaseSectionWho => 'Who and where';

  @override
  String get leaseSectionTerm => 'Term';

  @override
  String get leaseSectionRent => 'Rent and deposit';

  @override
  String get leaseSectionLateFee => 'Late fees';

  @override
  String get leaseSectionAgreement => 'Agreement';

  @override
  String get leaseSectionPolice => 'Police registration';

  @override
  String get leaseSectionOther => 'Other terms';

  @override
  String get moveInLabel => 'Moves in on';

  @override
  String get termLabel => 'Term';

  @override
  String get term11 => '11 months';

  @override
  String get term12 => '12 months';

  @override
  String get termCustom => 'Until a date';

  @override
  String get termPeriodic => 'Month to month';

  @override
  String get endsOnLabel => 'Ends on';

  @override
  String get validationEndAfterStart =>
      'Choose a date on or after the move-in date.';

  @override
  String get monthlyRentLabel => 'Monthly rent';

  @override
  String get validationRent => 'Enter the rent, an amount above 0.';

  @override
  String get depositLabel => 'Security deposit';

  @override
  String get incrementEveryLabel => 'Increase every (months)';

  @override
  String get lateFeeLabel => 'Late fee';

  @override
  String get lateFeeNone => 'None';

  @override
  String get lateFeeFlat => 'A fixed amount';

  @override
  String get lateFeePercent => 'A percent of the late rent';

  @override
  String get lateFeeDaily => 'An amount per day late';

  @override
  String get lateFeeAmountLabel => 'Fee';

  @override
  String get lateFeePercentLabel => 'Fee (%)';

  @override
  String get lateFeeCapLabel => 'At most';

  @override
  String get lateFeeHelp => 'Charged once the grace days have passed.';

  @override
  String get noticeDaysLabel => 'Notice period (days)';

  @override
  String get prorateLabel => 'Charge only the days of the first month';

  @override
  String get prorateHelp => 'When the tenant moves in after the 1st.';

  @override
  String get billingStartsLabel => 'Bill from';

  @override
  String get billingStartsHelp =>
      'For a tenancy that began before you used the app: the first day the app should bill.';

  @override
  String get agreementSignedLabel => 'Agreement signed on';

  @override
  String get eStampNumberLabel => 'E-stamp number';

  @override
  String get eStampAmountLabel => 'E-stamp amount';

  @override
  String get permittedUseLabel => 'Permitted use';

  @override
  String get sublettingLabel => 'Subletting allowed';

  @override
  String get registrarStatusLabel => 'Rent Registrar (Punjab)';

  @override
  String get registrarNotApplicable => 'Not applicable';

  @override
  String get registrarNotPresented => 'Not presented';

  @override
  String get registrarPresented => 'Presented';

  @override
  String get registrarRegistered => 'Registered';

  @override
  String get registrarOfficeLabel => 'Registrar office';

  @override
  String get registrationNumberLabel => 'Registration number';

  @override
  String get registeredOnLabel => 'Registered on';

  @override
  String get policeStatusLabel => 'Status';

  @override
  String get policeNotRequired => 'Not required';

  @override
  String get policePending => 'Not registered yet';

  @override
  String get policeSubmitted => 'Submitted';

  @override
  String get policeChannelLabel => 'Registered through';

  @override
  String get channelOnlinePortal => 'Online portal';

  @override
  String get channelKhidmatMarkaz => 'Khidmat Markaz';

  @override
  String get channelPoliceStation => 'Police station';

  @override
  String get policeStationLabel => 'Police station';

  @override
  String get policeReferenceLabel => 'Reference number';

  @override
  String get policeFeeLabel => 'Fee paid';

  @override
  String policeLegalDeadline(String date) {
    return 'The law\'s deadline: $date';
  }

  @override
  String policeReminderDate(String date) {
    return 'The app\'s reminder: $date';
  }

  @override
  String get policeReminderNote =>
      'No law the app knows of sets a deadline here: this is only a reminder.';

  @override
  String get policeLate => 'Past the deadline: register it now.';

  @override
  String get openPortalAction => 'Open the registration website';

  @override
  String get utilitiesNoteLabel => 'Utilities';

  @override
  String tenancyStarted(String tenant) {
    return 'Tenancy started for $tenant.';
  }

  @override
  String get tenancySaved => 'Tenancy terms saved.';

  @override
  String get reasonLeaseOverlap =>
      'The unit is let for some of these dates. End the other tenancy first, or choose other dates.';

  @override
  String get tenancyTermsSection => 'Terms';

  @override
  String dueDayValue(int day) {
    return 'Day $day of each month';
  }

  @override
  String percentValue(String percent) {
    return '$percent%';
  }

  @override
  String everyMonths(String percent, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: 'month',
    );
    return '$percent% every $_temp0';
  }

  @override
  String get periodicValue => 'Month to month';

  @override
  String get occupantsSection => 'People living there';

  @override
  String get occupantsHelp =>
      'Adults living with the tenant, needed for police registration.';

  @override
  String get addOccupantAction => 'Add person';

  @override
  String get occupantTitle => 'Person living there';

  @override
  String occupantSaved(String name) {
    return '$name saved.';
  }

  @override
  String get removeAction => 'Remove';

  @override
  String removeOccupantTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeOccupantBody => 'They are taken off this tenancy.';

  @override
  String get noOccupants => 'No one added yet.';

  @override
  String get rentHistorySection => 'Rent history';

  @override
  String rentFrom(String month) {
    return 'From $month';
  }

  @override
  String get rentReasonInitial => 'Starting rent';

  @override
  String get rentReasonAnnualIncrement => 'Yearly increase';

  @override
  String get rentReasonRenegotiation => 'Agreed change';

  @override
  String get rentReasonCorrection => 'Correction';

  @override
  String get changeRentAction => 'Change rent';

  @override
  String get changeRentFromLabel => 'From the month of';

  @override
  String get newRentLabel => 'New monthly rent';

  @override
  String get changeReasonLabel => 'Why';

  @override
  String get rentNoteLabel => 'Note';

  @override
  String suggestedIncrement(String percent, String rent) {
    return 'At the agreed $percent%, rounded to Rs 100: $rent';
  }

  @override
  String get useSuggestionAction => 'Use this';

  @override
  String get changeRentHelp =>
      'Unpaid rent of that month and later is re-priced; months already paid keep their amount.';

  @override
  String rentChanged(String rent, String month) {
    return 'Rent changed to $rent from $month.';
  }

  @override
  String get endTenancyAction => 'End tenancy';

  @override
  String get movedOutLabel => 'Moved out on';

  @override
  String get endTermCompleted => 'The term ended';

  @override
  String get endTenantMovedOut => 'The tenant moved out';

  @override
  String get endEviction => 'Eviction';

  @override
  String get endMutualAgreement => 'Both agreed';

  @override
  String get endTenancyExplain =>
      'Rent is billed through the month of moving out. The rent of every later month, and its automatic late fees, is voided, paid or not. Money that paid them is released and applied to the tenancy\'s other dues; what is left stays as the tenant\'s credit, to refund. The unit becomes vacant.';

  @override
  String get tenancyEnded => 'Tenancy ended.';

  @override
  String get endedOnLabel => 'Ended on';

  @override
  String get deleteTenancyTitle => 'Delete this tenancy?';

  @override
  String get deleteTenancyBody =>
      'Only for a tenancy entered by mistake: it goes with the dues it generated, as long as nothing was paid, waived or voided. Otherwise end the tenancy instead.';

  @override
  String get tenancyDeleted => 'Tenancy deleted.';

  @override
  String get tenancyLoadFailedTitle => 'This tenancy could not be loaded';

  @override
  String get loadingTenancy => 'Loading the tenancy';

  @override
  String get tenanciesEmpty => 'No tenancies yet.';

  @override
  String get tenanciesLoadFailedTitle => 'The tenancies could not be loaded';

  @override
  String monthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get fewerMonthsAction => 'Fewer months';

  @override
  String get moreMonthsAction => 'More months';

  @override
  String get documentsSection => 'Documents';

  @override
  String get documentsSectionHelp =>
      'Photos and PDFs, seen only by this portfolio\'s team.';

  @override
  String get addDocumentAction => 'Add document';

  @override
  String get documentsEmpty => 'No documents yet.';

  @override
  String get documentsEmptyTenant =>
      'No documents yet. Add photos of the CNIC, front and back.';

  @override
  String get documentsEmptyLease =>
      'No documents yet. Add the signed agreement and the police registration.';

  @override
  String get documentsEmptyUnit =>
      'No documents yet. Add photos of the unit and its meters.';

  @override
  String get documentsEmptyProperty =>
      'No documents yet. Add the property papers and photos.';

  @override
  String get loadingDocuments => 'Loading documents';

  @override
  String get documentsLoadFailedTitle => 'Documents could not be loaded';

  @override
  String get documentKindCnicFront => 'CNIC, front';

  @override
  String get documentKindCnicBack => 'CNIC, back';

  @override
  String get documentKindPhoto => 'Photo';

  @override
  String get documentKindTenancyAgreement => 'Tenancy agreement';

  @override
  String get documentKindPoliceRegistration => 'Police registration';

  @override
  String get documentKindRentRegistration => 'Rent registration';

  @override
  String get documentKindUtilityBill => 'Utility bill';

  @override
  String get documentKindReceipt => 'Receipt';

  @override
  String get documentKindInvoice => 'Invoice';

  @override
  String get documentKindMeterPhoto => 'Meter photo';

  @override
  String get documentKindPropertyPaper => 'Property papers';

  @override
  String get documentKindOther => 'Other';

  @override
  String get fileTypeJpeg => 'JPEG photo';

  @override
  String get fileTypePng => 'PNG image';

  @override
  String get fileTypeWebp => 'WebP image';

  @override
  String get fileTypeHeic => 'HEIC photo';

  @override
  String get fileTypePdf => 'PDF';

  @override
  String get fileFormatJpeg => 'JPEG';

  @override
  String get fileFormatPng => 'PNG';

  @override
  String get fileFormatWebp => 'WebP';

  @override
  String get fileFormatHeic => 'HEIC';

  @override
  String get fileFormatPdf => 'PDF';

  @override
  String fileSizeKb(String size) {
    return '$size KB';
  }

  @override
  String fileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get takePhotoAction => 'Take a photo';

  @override
  String get chooseFileAction => 'Choose a file';

  @override
  String get chooseAnotherFileAction => 'Choose another file';

  @override
  String get addDocumentHelp =>
      'Add a photo, or a PDF of up to 10 MB. Photos are made smaller first.';

  @override
  String get preparingFile => 'Getting the file ready';

  @override
  String get documentKindLabel => 'Kind';

  @override
  String get documentNameLabel => 'Name';

  @override
  String get documentNameHelp => 'Left empty, it is named after its kind.';

  @override
  String get uploadAction => 'Upload';

  @override
  String documentCompressed(String from, String to) {
    return 'Made smaller from $from to $to.';
  }

  @override
  String documentAdded(String name) {
    return '$name added.';
  }

  @override
  String documentSaved(String name) {
    return '$name saved.';
  }

  @override
  String documentDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String get openDocumentAction => 'Open';

  @override
  String get downloadDocumentAction => 'Download';

  @override
  String get editDocumentAction => 'Rename or change kind';

  @override
  String deleteDocumentTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteDocumentBody =>
      'The document and its file are deleted for everyone in this portfolio. This cannot be undone.';

  @override
  String get documentAddedOnLabel => 'Added on';

  @override
  String get documentFileLabel => 'File';

  @override
  String get documentSheetTitle => 'Document';

  @override
  String get documentPreviewLabel => 'Preview of the photo';

  @override
  String get documentNameTooLong => 'This name is too long. Shorten it.';

  @override
  String get reasonFileTooLarge =>
      'This file is larger than 10 MB. Choose a smaller one, or take a photo of it.';

  @override
  String get reasonFileTypeNotAllowed =>
      'Only photos (JPEG, PNG, WebP or HEIC) and PDFs can be added.';

  @override
  String get reasonFileUnreadable =>
      'This file could not be read. Choose another file, or take a photo of the paper.';

  @override
  String get reasonPickerAccessDenied =>
      'Maalik-e-Makaan may not use the camera or your files. Allow it in your phone\'s settings.';

  @override
  String get chargeKindRent => 'Rent';

  @override
  String get chargeKindDeposit => 'Security deposit';

  @override
  String get chargeKindElectricity => 'Electricity';

  @override
  String get chargeKindGas => 'Gas';

  @override
  String get chargeKindWater => 'Water';

  @override
  String get chargeKindInternet => 'Internet';

  @override
  String get chargeKindMaintenance => 'Maintenance';

  @override
  String get chargeKindSociety => 'Society charges';

  @override
  String get chargeKindLateFee => 'Late fee';

  @override
  String get chargeKindDamages => 'Damages';

  @override
  String get chargeKindOther => 'Other';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodBankTransfer => 'Bank transfer';

  @override
  String get methodRaast => 'Raast';

  @override
  String get methodJazzCash => 'JazzCash';

  @override
  String get methodEasypaisa => 'Easypaisa';

  @override
  String get methodCheque => 'Cheque';

  @override
  String get methodCard => 'Card';

  @override
  String get methodDeposit => 'From the deposit';

  @override
  String get methodOther => 'Other';

  @override
  String get methodLabel => 'Paid by';

  @override
  String chargeForMonth(String kind, String month) {
    return '$kind, $month';
  }

  @override
  String overdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue $days days',
      one: 'Overdue 1 day',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'Due today';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Due in $days days',
      one: 'Due tomorrow',
    );
    return '$_temp0';
  }

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String get chargePaid => 'Paid';

  @override
  String get chargeWaived => 'Waived';

  @override
  String get chargeVoided => 'Voided';

  @override
  String get loadingReceivables => 'Loading who owes what';

  @override
  String get receivablesLoadFailedTitle => 'The money owed could not be loaded';

  @override
  String get receivablesEmptyTitle => 'No money is owed yet';

  @override
  String get receivablesEmptyBody =>
      'Rent is billed for each tenancy you start. What tenants owe and pay shows here.';

  @override
  String get totalOwedLabel => 'Owed';

  @override
  String get totalOverdueLabel => 'Overdue';

  @override
  String get totalCreditLabel => 'Credit held';

  @override
  String get whoOwesSection => 'Who owes what';

  @override
  String get whoOwesHelp => 'The longest overdue first.';

  @override
  String get nobodyOwes => 'Nobody owes anything now.';

  @override
  String get settledSection => 'Settled or in credit';

  @override
  String lastPaidOn(String date) {
    return 'Last paid $date';
  }

  @override
  String owesAmount(String amount) {
    return 'Owes $amount';
  }

  @override
  String overdueOldest(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$amount overdue, oldest $_temp0';
  }

  @override
  String creditAmount(String amount) {
    return 'Credit $amount';
  }

  @override
  String get allPaid => 'All paid';

  @override
  String get cashBookTitle => 'Cash in hand';

  @override
  String get ledgerTitle => 'Ledger';

  @override
  String get loadingLedger => 'Loading the ledger';

  @override
  String get ledgerLoadFailedTitle => 'This ledger could not be loaded';

  @override
  String get statementAction => 'Tenant statement';

  @override
  String get owedNowLabel => 'Owed now';

  @override
  String owedNowValue(String amount) {
    return 'Owed now: $amount';
  }

  @override
  String get overdueLabel => 'Overdue';

  @override
  String get creditLabel => 'Credit';

  @override
  String get creditWord => 'credit';

  @override
  String get lastPaidLabel => 'Last paid';

  @override
  String get lastRemindedLabel => 'Last reminded';

  @override
  String get creditExplainActive =>
      'The tenant has paid ahead. The credit settles the next dues by itself.';

  @override
  String get creditExplainEnded =>
      'The tenancy has ended with money left over. Refund it to the tenant, or void the payment it came from.';

  @override
  String creditHeldEnded(String amount) {
    return 'The tenancy has ended and the tenant has $amount in credit.';
  }

  @override
  String get openCreditPaymentAction => 'Open the payment';

  @override
  String get recordPaymentAction => 'Record payment';

  @override
  String get remindAction => 'Remind on WhatsApp';

  @override
  String get openTenancyAction => 'Tenancy details';

  @override
  String get openDuesSection => 'Owed';

  @override
  String get openDuesHelp => 'Every due not yet paid, the oldest first.';

  @override
  String get addChargeAction => 'Add charge';

  @override
  String get noOpenDues => 'Nothing is owed.';

  @override
  String leftOfAmount(String left, String amount) {
    return '$left left of $amount';
  }

  @override
  String get paymentsSection => 'Payments';

  @override
  String get noPaymentsYet => 'No payments yet.';

  @override
  String receiptNumbered(String number) {
    return 'Receipt $number';
  }

  @override
  String withTax(String amount) {
    return '$amount tax withheld';
  }

  @override
  String get allDuesSection => 'All dues';

  @override
  String get allDuesHelp => 'Paid, waived and voided too, the newest first.';

  @override
  String get noDuesYet => 'No dues yet.';

  @override
  String get moneySection => 'Money';

  @override
  String get openLedgerAction => 'Open the ledger';

  @override
  String get amountLabel => 'Amount';

  @override
  String get paidLabel => 'Paid';

  @override
  String get stillOwedLabel => 'Still owed';

  @override
  String get dueDateLabel => 'Due date';

  @override
  String get chargeNoteLabel => 'Note';

  @override
  String get waiveReasonLabel => 'Why it was waived';

  @override
  String get voidReasonLabel => 'Why it was voided';

  @override
  String get editChargeAction => 'Edit charge';

  @override
  String get waiveChargeAction => 'Waive';

  @override
  String get voidChargeAction => 'Void charge';

  @override
  String get voidChargeHasPayments =>
      'Money was received for this due, so it cannot be voided. Void that payment first, or waive what is left.';

  @override
  String get chargeSaved => 'Charge saved.';

  @override
  String get chargeAmountFixed =>
      'Rent, late fees and the deposit keep the amount the tenancy\'s terms set. Change the rent, or void this due and add a new one.';

  @override
  String amountAtLeast(String amount) {
    return 'At least $amount, already paid or waived.';
  }

  @override
  String amountAtMost(String amount) {
    return 'At most $amount.';
  }

  @override
  String get chargeKindLabel => 'What for';

  @override
  String get chargeMonthLabel => 'For the month of';

  @override
  String get chargeMonthHelp => 'The month a bill is for, if it has one.';

  @override
  String get noMonthOption => 'No month';

  @override
  String chargeAdded(String kind) {
    return '$kind added.';
  }

  @override
  String get waiveExplain =>
      'Waiving forgives what is still owed (or the part you type). The due stays in the ledger, marked waived, with your reason.';

  @override
  String get voidChargeExplain =>
      'Voiding cancels a due entered by mistake, with its unpaid late fee. It stays in the ledger, marked voided, with your reason.';

  @override
  String get waiveAmountLabel => 'Amount to waive';

  @override
  String waiveAmountHelp(String amount) {
    return 'Leave empty to waive all $amount.';
  }

  @override
  String get reasonLabel => 'Reason';

  @override
  String get chargeWaivedDone => 'Due waived.';

  @override
  String get chargeVoidedDone => 'Due voided.';

  @override
  String get depositSection => 'Security deposit';

  @override
  String get depositAgreedLabel => 'Agreed';

  @override
  String get depositReceivedLabel => 'Received';

  @override
  String get depositAppliedLabel => 'Used for dues';

  @override
  String get depositRefundedLabel => 'Refunded';

  @override
  String get depositHeldLabel => 'Deposit held';

  @override
  String get depositSettleAfterEnd =>
      'The tenancy has ended and you still hold the deposit. Use it for what is owed, then refund the rest.';

  @override
  String get depositTenancyActive =>
      'This tenancy is still running. The deposit is usually used for dues or refunded when the tenant moves out.';

  @override
  String get applyDepositAction => 'Use for dues';

  @override
  String get refundDepositAction => 'Refund deposit';

  @override
  String refundOf(String amount) {
    return 'Refund of $amount';
  }

  @override
  String voidedBecause(String reason) {
    return 'Voided: $reason';
  }

  @override
  String get voidRefundAction => 'Void refund';

  @override
  String get voidRefundExplain =>
      'Voiding a refund recorded by mistake counts that money as held again. It stays in the ledger, marked voided.';

  @override
  String get refundVoided => 'Refund voided.';

  @override
  String get applyDepositExplain =>
      'The deposit settles what is owed, the oldest first, and the tenant gets a receipt for it.';

  @override
  String applyDepositHelp(String held, String owed) {
    return 'Held $held; owed $owed.';
  }

  @override
  String get appliedOnLabel => 'Used on';

  @override
  String depositApplied(String amount) {
    return '$amount of the deposit settled dues.';
  }

  @override
  String depositHeldHelp(String amount) {
    return 'You hold $amount.';
  }

  @override
  String get refundedOnLabel => 'Refunded on';

  @override
  String depositRefunded(String amount) {
    return '$amount of the deposit refunded.';
  }

  @override
  String get recordPaymentTitle => 'Record payment';

  @override
  String get paymentSectionMoney => 'What was received';

  @override
  String get paymentSectionTax => 'Tax withheld';

  @override
  String get paymentSectionSettle => 'What it pays for';

  @override
  String get amountReceivedLabel => 'Amount received';

  @override
  String useOwedAction(String amount) {
    return 'Use $amount owed';
  }

  @override
  String get receivedOnLabel => 'Received on';

  @override
  String get paymentReferenceLabel => 'Reference';

  @override
  String get paymentReferenceHelp =>
      'A transaction ID or cheque number, if there is one.';

  @override
  String get taxWithheldSwitch => 'The tenant withheld income tax';

  @override
  String get taxWithheldHelp =>
      'Companies and government offices deduct tax under section 155 and give a certificate. The cash and the tax together settle the rent.';

  @override
  String get taxWithheldLabel => 'Tax withheld (s.155)';

  @override
  String get taxCertificateLabel => 'Certificate or CPR number';

  @override
  String taxSettlesGross(String cash, String tax, String total) {
    return '$cash received and $tax withheld settle $total of dues.';
  }

  @override
  String get noOpenDuesCredit =>
      'Nothing is owed now: this payment is kept as credit for the next dues.';

  @override
  String get settleLabel => 'Settle';

  @override
  String get settleOldestFirst => 'The oldest dues first';

  @override
  String get settleChosen => 'The dues I choose';

  @override
  String get chooseDuesError => 'Choose at least one due.';

  @override
  String get willSettleHeading => 'This payment settles';

  @override
  String settledInFull(String charge) {
    return '$charge, in full';
  }

  @override
  String settledInPart(String charge) {
    return '$charge, in part';
  }

  @override
  String get creditKeptLabel => 'Kept as credit';

  @override
  String allCreditExplain(String amount) {
    return 'All $amount is kept as credit for the next dues.';
  }

  @override
  String lateFeeCancelledNote(String amount) {
    return 'The late fee of $amount will be cancelled: this pays its rent in full within the grace period.';
  }

  @override
  String paymentRecorded(String number) {
    return 'Payment recorded. Receipt $number.';
  }

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get loadingReceipt => 'Loading the receipt';

  @override
  String get receiptLoadFailedTitle => 'This receipt could not be loaded';

  @override
  String get receiptNumberLabel => 'Receipt no.';

  @override
  String receiptVoidedOn(String date, String reason) {
    return 'VOID: cancelled on $date. $reason';
  }

  @override
  String get receivedFromLabel => 'Received from';

  @override
  String get receiptForLabel => 'For';

  @override
  String get paidByLabel => 'Paid by';

  @override
  String get receiptFooter => 'Thank you. Keep this receipt for your records.';

  @override
  String get shareReceiptAction => 'Share receipt';

  @override
  String get shareVoidedReceiptAction => 'Share voided receipt';

  @override
  String get sendThanksAction => 'Thank on WhatsApp';

  @override
  String get voidPaymentAction => 'Void payment';

  @override
  String get voidPaymentExplain =>
      'Voiding a payment recorded by mistake makes the dues it paid owed again. The receipt keeps its number, marked void, with your reason.';

  @override
  String get paymentVoided => 'Payment voided.';

  @override
  String get documentLanguageLabel => 'Language of the document';

  @override
  String get shareDocumentAction => 'Share PDF';

  @override
  String get receiptDocumentTitle => 'Rent receipt';

  @override
  String get receiptVoid => 'VOID';

  @override
  String receiptVoidBecause(String reason) {
    return 'VOID: $reason';
  }

  @override
  String get totalSettledLabel => 'Total, with tax';

  @override
  String get receiptSettledHeading => 'Dues settled';

  @override
  String documentMadeOn(String date) {
    return 'Made with Maalik-e-Makaan on $date.';
  }

  @override
  String receiptFileTitle(String number) {
    return 'Receipt $number';
  }

  @override
  String get statementDocumentTitle => 'Tenant statement';

  @override
  String get statementPeriodLabel => 'Period';

  @override
  String dateRange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get statementSummaryHeading => 'Summary';

  @override
  String get totalBilledLabel => 'Billed';

  @override
  String get totalPaidLabel => 'Paid';

  @override
  String get totalWaivedLabel => 'Waived';

  @override
  String get balanceOwedLabel => 'Owed now';

  @override
  String get statementDuesHeading => 'Dues';

  @override
  String get chargeForLabel => 'What for';

  @override
  String get chargeStateLabel => 'Status';

  @override
  String get statementPaymentsHeading => 'Payments';

  @override
  String voidedReceipt(String number) {
    return '$number (void)';
  }

  @override
  String statementFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments received.',
      one: '1 payment received.',
      zero: 'No payments received.',
    );
    return '$_temp0 Every receipt number can be checked against the tenant\'s copy.';
  }

  @override
  String statementFileTitle(String tenant) {
    return 'Statement, $tenant';
  }

  @override
  String get reminderTitle => 'Remind on WhatsApp';

  @override
  String get reminderTemplateLabel => 'Message';

  @override
  String get templateUpcoming => 'Rent due soon';

  @override
  String get templateDueToday => 'Rent due today';

  @override
  String get templateOverdue => 'Rent overdue';

  @override
  String get templatePaymentReceived => 'Payment received';

  @override
  String get templateUtilityBill => 'Utility bill';

  @override
  String get reminderLanguageLabel => 'Tenant\'s language';

  @override
  String get languageRomanUrdu => 'Roman Urdu';

  @override
  String get reminderMessageLabel => 'Message to send';

  @override
  String get reminderNoPhone =>
      'This tenant has no phone number: WhatsApp opens for you to choose the chat.';

  @override
  String reminderTo(String name, String phone) {
    return 'To $name on $phone.';
  }

  @override
  String get sendOnWhatsAppAction => 'Send on WhatsApp';

  @override
  String get sendAnywayAction => 'Send anyway';

  @override
  String get copyMessageAction => 'Copy message';

  @override
  String get messageCopied => 'Message copied.';

  @override
  String get reminderLogged => 'Reminder sent and noted in the ledger.';

  @override
  String get noteReminderAction => 'Note it in the reminders sent';

  @override
  String etiquetteLateNight(String time) {
    return 'It is late at night in Pakistan. A reminder may be better after $time.';
  }

  @override
  String etiquetteFridayPrayer(String time) {
    return 'It is time for Jumu\'ah prayers. A reminder may be better after $time.';
  }

  @override
  String etiquetteRecent(String moment) {
    return 'A reminder already went to this tenant on $moment. Too many reminders can strain a good tenancy.';
  }

  @override
  String get remindersSection => 'Reminders sent';

  @override
  String get loadingReminders => 'Loading the reminders';

  @override
  String get remindersLoadFailedTitle => 'The reminders could not be loaded';

  @override
  String get noRemindersYet => 'No reminders sent yet.';

  @override
  String reminderUnit(String unit, String property) {
    return '$unit, $property';
  }

  @override
  String reminderUpcoming(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. A reminder that $amount for $unit is due on $date.';
  }

  @override
  String reminderDueToday(String tenant, String amount, String unit) {
    return 'Assalam-o-Alaikum $tenant. $amount for $unit is due today.';
  }

  @override
  String reminderOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. $amount is overdue for $unit; the oldest of it was due on $date. Please pay it at your earliest convenience.';
  }

  @override
  String reminderReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  ) {
    return 'Assalam-o-Alaikum $tenant. We received $amount on $date. Receipt number: $receipt. Thank you.';
  }

  @override
  String reminderUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. The $utility bill of $amount for $unit is due on $date. Please pay it before the due date.';
  }

  @override
  String get reminderElectricity => 'electricity';

  @override
  String get reminderGas => 'gas';

  @override
  String get reminderWater => 'water';

  @override
  String get reminderInternet => 'internet';

  @override
  String get reminderUtilityGeneric => 'utility';

  @override
  String reminderPayRaast(String raast) {
    return 'You can pay by Raast to $raast.';
  }

  @override
  String reminderPayBank(String title, String iban) {
    return 'Bank transfer: $title, IBAN $iban.';
  }

  @override
  String reminderThanks(String landlord) {
    return 'Regards, $landlord';
  }

  @override
  String reminderRomanUnit(String unit, String property) {
    return '$unit, $property';
  }

  @override
  String reminderRomanUpcoming(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. Yaad dihani hai ke $unit ke $amount $date ko wajib-ul-ada hain.';
  }

  @override
  String reminderRomanDueToday(String tenant, String amount, String unit) {
    return 'Assalam-o-Alaikum $tenant. $unit ke $amount aaj wajib-ul-ada hain.';
  }

  @override
  String reminderRomanOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. $unit ke $amount wajib-ul-ada hain aur abhi tak mosool nahi hue; in mein sab se purani raqam $date ko wajib-ul-ada thi. Barah-e-karam jald az jald ada kar dein.';
  }

  @override
  String reminderRomanReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  ) {
    return 'Assalam-o-Alaikum $tenant. $date ko $amount mosool ho gaye. Raseed number: $receipt. Shukriya.';
  }

  @override
  String reminderRomanUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. $unit ka $utility ka bill $amount $date tak ada karna hai. Barah-e-karam aakhri tareekh se pehle ada kar dein.';
  }

  @override
  String get reminderRomanElectricity => 'bijli';

  @override
  String get reminderRomanGas => 'gas';

  @override
  String get reminderRomanWater => 'paani';

  @override
  String get reminderRomanInternet => 'internet';

  @override
  String get reminderRomanUtilityGeneric => 'utility';

  @override
  String reminderRomanPayRaast(String raast) {
    return 'Aap Raast ke zariye $raast par adaigi kar sakte hain.';
  }

  @override
  String reminderRomanPayBank(String title, String iban) {
    return 'Bank transfer: $title, IBAN $iban.';
  }

  @override
  String reminderRomanThanks(String landlord) {
    return 'Wassalam, $landlord';
  }

  @override
  String get loadingCashBook => 'Loading the cash in hand';

  @override
  String get cashBookLoadFailedTitle => 'The cash in hand could not be loaded';

  @override
  String get cashInHandSection => 'Who holds cash';

  @override
  String get cashInHandHelp =>
      'Cash collected, less what was handed on or spent in cash.';

  @override
  String get noCashYet => 'No cash has been collected yet.';

  @override
  String get cashCollectedLabel => 'Collected';

  @override
  String get cashHandedOverLabel => 'Handed on';

  @override
  String get cashSpentLabel => 'Spent';

  @override
  String get cashInHandLabel => 'In hand';

  @override
  String get handoversSection => 'Handovers';

  @override
  String get noHandoversYet => 'No cash has been handed over yet.';

  @override
  String get formerMember => 'A former member';

  @override
  String handoverFromTo(String from, String to) {
    return '$from to $to';
  }

  @override
  String get handoverConfirmed => 'Confirmed';

  @override
  String get handoverAwaiting => 'To confirm';

  @override
  String get handoverTitle => 'Cash handover';

  @override
  String get handedOverOnLabel => 'Handed over on';

  @override
  String get confirmHandoverAction => 'Confirm I received it';

  @override
  String get handoverConfirmedDone => 'Handover confirmed.';

  @override
  String get voidHandoverAction => 'Void handover';

  @override
  String get voidHandoverExplain =>
      'Voiding a handover recorded by mistake counts that cash as still with the giver. It stays in the list, marked voided.';

  @override
  String get handoverVoided => 'Handover voided.';

  @override
  String get recordHandoverAction => 'Record handover';

  @override
  String get handoverFromLabel => 'Handed over by';

  @override
  String get handoverToLabel => 'Handed to';

  @override
  String get handoverChooseReceiver => 'Choose who received the cash.';

  @override
  String get handoverRecorded => 'Handover recorded.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSummary =>
      'Rent due, tenancies ending, police registration';

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get loadingNotifications => 'Loading the notifications';

  @override
  String get notificationsLoadFailedTitle =>
      'The notifications could not be loaded';

  @override
  String get notificationsEmptyTitle => 'No notifications';

  @override
  String get notificationsEmptyBody =>
      'Each morning the app checks for rent due, tenancies ending, rent increases, police registration and CNICs expiring, and tells you here.';

  @override
  String get markAllReadAction => 'Mark all as read';

  @override
  String get unreadLabel => 'New';

  @override
  String get openNotificationAction => 'Open';

  @override
  String get notificationDeleted => 'Notification deleted.';

  @override
  String get notificationRentDueSoon => 'Rent due soon';

  @override
  String notificationRentDueSoonBody(
    String tenancy,
    String amount,
    String date,
  ) {
    return '$tenancy: $amount due on $date.';
  }

  @override
  String get notificationRentOverdue => 'Rent overdue';

  @override
  String notificationRentOverdueBody(
    String tenancy,
    String amount,
    String date,
  ) {
    return '$tenancy: $amount was due on $date.';
  }

  @override
  String get notificationLeaseExpiring => 'Agreement ending';

  @override
  String notificationLeaseExpiringBody(String tenancy, String date) {
    return '$tenancy: the agreement ends on $date.';
  }

  @override
  String get notificationIncrementDue => 'Rent increase due';

  @override
  String notificationIncrementDueBody(
    String tenancy,
    String date,
    String rent,
  ) {
    return '$tenancy: the yearly increase on rent of $rent is due from $date.';
  }

  @override
  String get notificationPolicePending => 'Police registration pending';

  @override
  String notificationPolicePendingBody(String tenancy, String date) {
    return '$tenancy: register the tenancy with the police by $date.';
  }

  @override
  String get notificationPoliceOverdue => 'Police registration overdue';

  @override
  String notificationPoliceOverdueBody(String tenancy, String date) {
    return '$tenancy: the deadline to register with the police was $date.';
  }

  @override
  String notificationPoliceReminderBody(String tenancy, String date) {
    return '$tenancy: the app\'s reminder to register with the police is $date. No law the app knows of sets a deadline here.';
  }

  @override
  String get notificationCnicExpiring => 'CNIC expiring';

  @override
  String notificationCnicExpiringBody(String tenant, String date) {
    return '$tenant\'s CNIC expires on $date.';
  }

  @override
  String get notificationUtilityDue => 'Utility bill due';

  @override
  String notificationUtilityDueBody(
    String property,
    String amount,
    String date,
  ) {
    return '$property: a bill of $amount is due on $date.';
  }

  @override
  String get notificationInvitationAccepted => 'Invitation accepted';

  @override
  String notificationInvitationAcceptedBody(String email, String role) {
    return '$email joined as $role.';
  }

  @override
  String get notificationUnknown => 'Notification';

  @override
  String get notificationUnknownBody =>
      'Update the app to read this notification.';

  @override
  String get reasonIdempotencyKeyRequired =>
      'This payment could not be sent safely. Close the form and open it again.';

  @override
  String get reasonRefundUnconfirmed =>
      'The connection dropped, so the refund may have been recorded. Close this and check the deposit before trying again.';

  @override
  String get checkDepositAction => 'Close and check the deposit';

  @override
  String get operationsSection => 'Operations';

  @override
  String get expensesSummary => 'What you spend on your properties';

  @override
  String get utilitiesSummary => 'Connections, bills and meter readings';

  @override
  String get maintenanceSummary => 'Repairs and where each stands';

  @override
  String get propertyLabel => 'Property';

  @override
  String get wholePortfolioOption => 'The whole portfolio';

  @override
  String get wholePropertyOption => 'The whole property';

  @override
  String get loadingPlaces => 'Loading…';

  @override
  String get noTenancyOption => 'No tenancy';

  @override
  String get noTenanciesHere =>
      'No tenancy was ever started on this connection\'s property or unit.';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get statusLabel => 'Status';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get filterToDo => 'To do';

  @override
  String get filterClosed => 'Closed';

  @override
  String get callAction => 'Call';

  @override
  String get callFailed => 'The phone could not be opened on this device.';

  @override
  String get paidOnLabel => 'Paid on';

  @override
  String get expenseCategoryRepairs => 'Repairs and maintenance';

  @override
  String get expenseCategoryPropertyTax => 'Property tax';

  @override
  String get expenseCategoryUtilities => 'Utilities';

  @override
  String get expenseCategorySociety => 'Society charges';

  @override
  String get expenseCategoryInsurance => 'Insurance';

  @override
  String get expenseCategoryLegal => 'Legal and professional fees';

  @override
  String get expenseCategoryAgent => 'Agent\'s commission';

  @override
  String get expenseCategorySalaries => 'Staff salaries';

  @override
  String get expenseCategoryCleaning => 'Cleaning and security';

  @override
  String get expenseCategoryRenovation => 'Renovation';

  @override
  String get expenseCategoryBank => 'Bank charges';

  @override
  String get expenseCategoryLoanInterest => 'Loan interest';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get expenseTitle => 'Expense';

  @override
  String get newExpenseTitle => 'New expense';

  @override
  String get editExpenseTitle => 'Edit expense';

  @override
  String get addExpenseAction => 'Add expense';

  @override
  String get loadingExpenses => 'Loading the expenses';

  @override
  String get loadingExpense => 'Loading the expense';

  @override
  String get expensesLoadFailedTitle => 'The expenses could not be loaded';

  @override
  String get expenseLoadFailedTitle => 'The expense could not be loaded';

  @override
  String get expensesEmptyTitle => 'No expenses yet';

  @override
  String get expensesEmptyBody =>
      'Record what you spend on repairs, tax, salaries and the rest, with a photo of each receipt. It shows what each property really earns.';

  @override
  String get expenseSectionWhat => 'What was spent';

  @override
  String get expenseSectionWhere => 'Where';

  @override
  String get expenseSectionPaid => 'How it was paid';

  @override
  String get expenseCategoryLabel => 'Category';

  @override
  String get spentOnLabel => 'Spent on';

  @override
  String get expensePropertyHelp =>
      'Choose “The whole portfolio” for costs such as an accountant\'s fee.';

  @override
  String get maintenanceJobLabel => 'Maintenance job';

  @override
  String get maintenanceJobHelp => 'The repair this paid for, if any.';

  @override
  String get noJobOption => 'No job';

  @override
  String get payeeLabel => 'Paid to';

  @override
  String get payeeHelp => 'A plumber, the excise office, a shop…';

  @override
  String get expenseCashHelp =>
      'Cash you spend comes out of your cash in hand.';

  @override
  String expenseForJob(String title) {
    return 'For the job: $title';
  }

  @override
  String get paidForJobLabel => 'Paid for the job';

  @override
  String get expenseAdded => 'Expense added.';

  @override
  String get expenseSaved => 'Expense saved.';

  @override
  String get expenseDeleted => 'Expense deleted.';

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String get deleteExpenseBody =>
      'It goes for good, with its receipts. Only for an expense recorded by mistake.';

  @override
  String get providerLesco => 'LESCO (Lahore)';

  @override
  String get providerIesco => 'IESCO (Islamabad)';

  @override
  String get providerGepco => 'GEPCO (Gujranwala)';

  @override
  String get providerFesco => 'FESCO (Faisalabad)';

  @override
  String get providerMepco => 'MEPCO (Multan)';

  @override
  String get providerPesco => 'PESCO (Peshawar)';

  @override
  String get providerHesco => 'HESCO (Hyderabad)';

  @override
  String get providerSepco => 'SEPCO (Sukkur)';

  @override
  String get providerQesco => 'QESCO (Quetta)';

  @override
  String get providerTesco => 'TESCO (Tribal districts)';

  @override
  String get providerHazeco => 'HAZECO (Hazara)';

  @override
  String get providerKElectric => 'K-Electric (Karachi)';

  @override
  String get providerSngpl => 'SNGPL (Sui Northern)';

  @override
  String get providerSsgc => 'SSGC (Sui Southern)';

  @override
  String get providerWasa => 'WASA';

  @override
  String get providerKwsc => 'Karachi Water (KW&SC)';

  @override
  String get providerCda => 'CDA (Islamabad)';

  @override
  String get providerPtcl => 'PTCL';

  @override
  String get responsibilityTenant => 'The tenant';

  @override
  String get responsibilityLandlord => 'You';

  @override
  String get responsibilityShared => 'Shared';

  @override
  String get billPaidByTenant => 'The tenant';

  @override
  String get billPaidByLandlord => 'You';

  @override
  String get readingMoveIn => 'Move-in';

  @override
  String get readingMoveOut => 'Move-out';

  @override
  String get readingMonthly => 'Monthly';

  @override
  String get utilitiesTitle => 'Utilities';

  @override
  String get loadingUtilities => 'Loading the utilities';

  @override
  String get utilitiesLoadFailedTitle => 'The utilities could not be loaded';

  @override
  String get unpaidBillsSection => 'Bills to pay';

  @override
  String get unpaidBillsHelp => 'Unpaid bills, the earliest due first.';

  @override
  String get noUnpaidBills => 'No unpaid bills.';

  @override
  String landlordNameOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count overdue bills are on connections in your name. Arrears stay with the premises and the connection, so they can fall on you.',
      one: '1 overdue bill is on a connection in your name. Arrears stay with the premises and the connection, so they can fall on you.',
    );
    return '$_temp0';
  }

  @override
  String get connectionsSection => 'Connections';

  @override
  String get connectionsHelp =>
      'Electricity, gas, water and internet, per property or unit.';

  @override
  String get connectionsEmptyTitle => 'No connections yet';

  @override
  String get connectionsEmptyBody =>
      'Add each meter with its reference number and whose name it is in. Unpaid bills follow the premises, so keep an eye on them here.';

  @override
  String get archivedConnectionsEmpty => 'No archived connections.';

  @override
  String get archivedConnectionsEmptyBody =>
      'Connections you archive keep their bills and readings and wait here.';

  @override
  String get addConnectionAction => 'Add connection';

  @override
  String connectionName(String kind, String supplier) {
    return '$kind, $supplier';
  }

  @override
  String get inYourName => 'In your name';

  @override
  String billOfMonth(String connection, String month) {
    return '$connection: $month';
  }

  @override
  String unitsUsed(String units) {
    return '$units units';
  }

  @override
  String get chargedToTenant => 'On the tenant\'s ledger';

  @override
  String get loadingUtility => 'Loading the connection';

  @override
  String get utilityLoadFailedTitle => 'The connection could not be loaded';

  @override
  String get inYourNameWarning =>
      'This connection is in your name. Unpaid bills stay with it and can fall on you: check every month that the bill is paid.';

  @override
  String get referenceNumberLabel => 'Reference number';

  @override
  String get customerIdLabel => 'Customer ID';

  @override
  String get meterNumberLabel => 'Meter number';

  @override
  String get nameOnBillLabel => 'Name on the bill';

  @override
  String get inMyNameLabel => 'In my name';

  @override
  String get inMyNameHelp =>
      'Arrears follow the premises: unpaid bills on a connection in your name can fall on you.';

  @override
  String get whoPaysLabel => 'Who pays the bills';

  @override
  String get subMeterLabel => 'Sub-meter';

  @override
  String get subMeterHelp =>
      'A meter of your own that measures one portion\'s share of a main connection.';

  @override
  String get protectedLabel => 'Protected tariff';

  @override
  String protectedHelp(int limit) {
    return 'The subsidised domestic tariff for homes that use $limit units a month or fewer. One month over $limit loses it for six months; the app warns you as a month nears it.';
  }

  @override
  String get billsSection => 'Bills';

  @override
  String get billsEmpty =>
      'No bills yet. Add each month\'s bill with its due date and units.';

  @override
  String get addBillAction => 'Add bill';

  @override
  String get readingsSection => 'Meter readings';

  @override
  String get readingsHelp =>
      'Read the meter at move-in and move-out, and each month if you like.';

  @override
  String get readingsEmpty => 'No readings yet.';

  @override
  String get addReadingAction => 'Add reading';

  @override
  String readingValue(String value) {
    return 'Reading $value';
  }

  @override
  String usedSince(String units, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$units units in $days days',
      one: '$units units in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get archiveConnectionTitle => 'Archive this connection?';

  @override
  String get archiveConnectionBody =>
      'It leaves your lists but keeps its bills and readings. You can put it back in use later.';

  @override
  String get connectionArchived => 'Connection archived.';

  @override
  String get connectionRestored => 'The connection is back in use.';

  @override
  String get deleteConnectionTitle => 'Delete this connection?';

  @override
  String get deleteConnectionBody =>
      'It goes for good, with its bills and readings. Dues already on a tenant\'s ledger stay there. Only for a connection added by mistake; otherwise archive it.';

  @override
  String get connectionDeleted => 'Connection deleted.';

  @override
  String get newConnectionTitle => 'New connection';

  @override
  String get editConnectionTitle => 'Edit connection';

  @override
  String get connectionSectionWhere => 'Where';

  @override
  String get connectionSectionSupplier => 'What and who supplies it';

  @override
  String get connectionSectionNumbers => 'Account numbers';

  @override
  String get connectionSectionWho => 'Whose name, who pays';

  @override
  String get utilityTypeLabel => 'Type';

  @override
  String get providerLabel => 'Supplier';

  @override
  String get providerNameLabel => 'Supplier\'s name';

  @override
  String get referenceNumberHelp => 'As printed on the bill.';

  @override
  String referenceDigitsHint(int digits) {
    return 'This supplier\'s bills usually carry a $digits-digit number. Check it against a bill.';
  }

  @override
  String get referenceNumberInvalid => 'Use 4 to 24 letters, digits or dashes.';

  @override
  String get customerIdInvalid => 'Use up to 30 letters, digits or dashes.';

  @override
  String get meterNumberInvalid =>
      'Use up to 30 letters, digits, dashes or slashes.';

  @override
  String get connectionAdded => 'Connection added.';

  @override
  String get connectionSaved => 'Connection saved.';

  @override
  String get billTitle => 'Bill';

  @override
  String get loadingBill => 'Loading the bill';

  @override
  String get billLoadFailedTitle => 'The bill could not be loaded';

  @override
  String get billPaid => 'Paid';

  @override
  String get billUnpaid => 'Unpaid';

  @override
  String get billMonthLabel => 'Bill for';

  @override
  String get unitsConsumedLabel => 'Units used';

  @override
  String protectedUnitsHelp(int limit) {
    return 'On the protected tariff: keep a month at $limit units or fewer.';
  }

  @override
  String get validationUnits => 'Enter a number of units, like 185 or 185.5.';

  @override
  String get alreadyPaidLabel => 'Already paid';

  @override
  String get billPaidByLabel => 'Paid by';

  @override
  String get billAdded => 'Bill added.';

  @override
  String get billSaved => 'Bill saved.';

  @override
  String get billDeleted => 'Bill deleted.';

  @override
  String get billMarkedPaid => 'Bill marked paid.';

  @override
  String get billMarkedUnpaid => 'Bill marked unpaid.';

  @override
  String get billCharged => 'The bill is on the tenant\'s ledger.';

  @override
  String get markPaidAction => 'Mark paid';

  @override
  String get markUnpaidAction => 'Mark unpaid';

  @override
  String get editBillAction => 'Edit bill';

  @override
  String get chargeTenantAction => 'Charge to tenant';

  @override
  String chargeTenantExplain(String amount, String date) {
    return 'The bill of $amount becomes a due on the tenant\'s ledger, due on $date. Credit the tenant holds is applied to it.';
  }

  @override
  String get chargedToTenantHelp =>
      'Its payment is recorded on the tenancy\'s ledger.';

  @override
  String get billChargeVoided =>
      'The charge this bill became on the tenant\'s ledger was voided. You can charge it again.';

  @override
  String get connectionDetailsAction => 'Connection details';

  @override
  String get inYourNameUnpaid =>
      'This unpaid bill is on a connection in your name: if it stays unpaid, the arrears can fall on you.';

  @override
  String get deleteBillTitle => 'Delete this bill?';

  @override
  String get deleteBillBody =>
      'It goes for good, with its photos. Only for a bill added by mistake.';

  @override
  String get deleteChargedBillBody =>
      'It goes for good, with its photos. The due it became on the tenant\'s ledger stays there: void it in the ledger if it is wrong too.';

  @override
  String protectedOver(int limit) {
    return 'Over $limit units a month';
  }

  @override
  String protectedNear(int limit) {
    return 'Near $limit units a month';
  }

  @override
  String protectedOverExplain(int limit) {
    return 'This month went over $limit units: the protected tariff is lost for the next six months, and bills will cost more.';
  }

  @override
  String protectedNearExplain(int limit) {
    return 'This month is close to $limit units. One month over $limit loses the protected tariff for six months.';
  }

  @override
  String get readingTitle => 'Meter reading';

  @override
  String get loadingReading => 'Loading the reading';

  @override
  String get readingLoadFailedTitle => 'The reading could not be loaded';

  @override
  String get readingLabel => 'Reading';

  @override
  String get readOnLabel => 'Read on';

  @override
  String get readingContextLabel => 'When read';

  @override
  String get readingTenancyHelp => 'The tenancy moving in or out, if any.';

  @override
  String lastReadingWas(String value, String date) {
    return 'The last reading was $value on $date.';
  }

  @override
  String get readingLower =>
      'This is lower than the last reading. If the meter was replaced, note it below.';

  @override
  String get previousReadingLabel => 'Reading before';

  @override
  String readingOn(String value, String date) {
    return '$value on $date';
  }

  @override
  String get unitsUsedLabel => 'Used since';

  @override
  String get monthlyPaceLabel => 'At this pace';

  @override
  String unitsAMonth(String units) {
    return '$units units a month';
  }

  @override
  String get readingAdded => 'Reading added.';

  @override
  String get readingSaved => 'Reading saved.';

  @override
  String get readingDeleted => 'Reading deleted.';

  @override
  String get editReadingAction => 'Edit reading';

  @override
  String get deleteReadingTitle => 'Delete this reading?';

  @override
  String get deleteReadingBody =>
      'It goes for good, with its photos. Only for a reading added by mistake.';

  @override
  String get maintenancePlumbing => 'Plumbing';

  @override
  String get maintenanceElectrical => 'Electrical';

  @override
  String get maintenanceCarpentry => 'Carpentry';

  @override
  String get maintenancePainting => 'Painting';

  @override
  String get maintenanceSeepage => 'Seepage';

  @override
  String get maintenanceAppliance => 'Appliance';

  @override
  String get maintenancePestControl => 'Pest control';

  @override
  String get maintenanceCleaning => 'Cleaning';

  @override
  String get maintenanceStructural => 'Structural';

  @override
  String get maintenanceWaterSupply => 'Water supply';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String priorityNamed(String priority) {
    return '$priority priority';
  }

  @override
  String get maintenanceOpen => 'Open';

  @override
  String get maintenanceInProgress => 'In progress';

  @override
  String get maintenanceOnHold => 'On hold';

  @override
  String get maintenanceResolved => 'Resolved';

  @override
  String get maintenanceCancelled => 'Cancelled';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get loadingMaintenance => 'Loading the repairs';

  @override
  String get loadingMaintenanceRequest => 'Loading the repair';

  @override
  String get maintenanceLoadFailedTitle => 'The repairs could not be loaded';

  @override
  String get maintenanceRequestLoadFailedTitle =>
      'The repair could not be loaded';

  @override
  String get maintenanceEmptyTitle => 'Nothing to repair';

  @override
  String get maintenanceEmptyBody =>
      'Record each repair as it is reported, and follow it until it is done, with what it cost.';

  @override
  String get maintenanceClosedEmptyTitle => 'No closed repairs yet';

  @override
  String get maintenanceClosedEmptyBody =>
      'Repairs you resolve or cancel are kept here.';

  @override
  String get addRequestAction => 'Add repair';

  @override
  String reportedOn(String date) {
    return 'Reported $date';
  }

  @override
  String get maintenanceCategoryLabel => 'Kind of work';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get reportedOnLabel => 'Reported on';

  @override
  String get reportedByLabel => 'Reported by';

  @override
  String get assignedToLabel => 'Done by';

  @override
  String get assignedToHelp => 'The plumber, electrician or company doing it.';

  @override
  String get vendorPhoneLabel => 'Their phone';

  @override
  String get estimateLabel => 'Estimate';

  @override
  String get resolvedOnLabel => 'Resolved on';

  @override
  String get resolutionLabel => 'What was done';

  @override
  String get resolutionHelp =>
      'For the record: what was fixed, and any guarantee.';

  @override
  String get startWorkAction => 'Start work';

  @override
  String get resumeWorkAction => 'Resume work';

  @override
  String get putOnHoldAction => 'Put on hold';

  @override
  String get markResolvedAction => 'Mark resolved';

  @override
  String get cancelRequestAction => 'Cancel the repair';

  @override
  String get reopenAction => 'Reopen';

  @override
  String requestMoved(String status) {
    return 'Now: $status.';
  }

  @override
  String get requestResolved => 'Repair resolved.';

  @override
  String get jobExpensesSection => 'Spent on it';

  @override
  String get jobExpensesEmpty => 'Nothing spent on it yet.';

  @override
  String spentSoFar(String amount) {
    return '$amount so far';
  }

  @override
  String spentOfEstimate(String spent, String estimate) {
    return '$spent of the $estimate estimate';
  }

  @override
  String deleteRequestTitle(String title) {
    return 'Delete $title?';
  }

  @override
  String get deleteRequestBody =>
      'It goes for good, with its photos. Only for a repair added by mistake; cancel it instead to keep it on record.';

  @override
  String get requestDeleted => 'Repair deleted.';

  @override
  String get newRequestTitle => 'New repair';

  @override
  String get editRequestTitle => 'Edit repair';

  @override
  String get requestSectionWhat => 'What needs doing';

  @override
  String get requestSectionWhere => 'Where';

  @override
  String get requestSectionWho => 'Who and when';

  @override
  String get requestSectionStatus => 'Where it stands';

  @override
  String get requestTitleLabel => 'What is wrong';

  @override
  String get requestTitleHelp => 'In a few words: \"Kitchen tap leaking\".';

  @override
  String get requestTenancyHelp => 'The tenancy it was reported in, if any.';

  @override
  String get requestAdded => 'Repair added.';

  @override
  String get requestSaved => 'Repair saved.';

  @override
  String get reasonDuplicateUtilityReference =>
      'Another connection of this type in use already has this reference number.';

  @override
  String get reasonDuplicateBillMonth =>
      'This connection already has a bill for that month. Open it to change it.';

  @override
  String get reasonRequestHasExpenses =>
      'Expenses are recorded against this repair, so it cannot be deleted. Cancel it instead, or delete those expenses first.';

  @override
  String connectionReference(String number) {
    return 'Ref. $number';
  }

  @override
  String get whereLabel => 'Where';

  @override
  String pacedNearExplain(int limit) {
    return 'At this pace a month comes close to $limit units. One month over $limit loses the protected tariff for six months.';
  }

  @override
  String pacedOverExplain(int limit) {
    return 'At this pace a month goes over $limit units, which loses the protected tariff for six months. Check the bill when it comes.';
  }

  @override
  String get paidWithLabel => 'Paid with';

  @override
  String get billAmountLocked =>
      'This bill is a due on the tenant\'s ledger, so its amount can\'t change here. To correct it, void that due in the ledger, then charge the bill again.';

  @override
  String paceAMonth(String units) {
    return 'about $units units a month';
  }

  @override
  String readingHigher(String value, String date) {
    return 'This is higher than the later reading of $value on $date. Check the figure and the day.';
  }

  @override
  String get markUnpaidTitle => 'Mark this bill unpaid?';

  @override
  String markUnpaidBody(String date) {
    return 'The paid date, $date, and who paid it will be cleared.';
  }

  @override
  String get cancelRequestTitle => 'Close this repair as cancelled?';

  @override
  String get cancelRequestBody =>
      'It moves to Closed, with its details and expenses kept. You can reopen it later.';

  @override
  String get closeAsCancelledAction => 'Close as cancelled';

  @override
  String get chargeDuePassed =>
      'That date has passed, so the due will show as overdue at once.';

  @override
  String get savedEarlierUnchanged =>
      'This was already saved, as first entered. Your later changes were not saved: edit it to make them.';

  @override
  String get requestHasExpensesClosed =>
      'Expenses are recorded against this repair, so it cannot be deleted. If it was entered by mistake, delete those expenses first.';

  @override
  String get loadingDashboard => 'Loading the dashboard';

  @override
  String get dashboardLoadFailedTitle => 'The dashboard could not be loaded';

  @override
  String get searchAction => 'Search';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsEntryTitle => 'Reports and statements';

  @override
  String get reportsEntrySummary =>
      'Cash flow, payment scores, tax-year and owner statements, exports';

  @override
  String thisMonthSection(String month) {
    return 'This month, $month';
  }

  @override
  String get collectedThisMonthLabel => 'Collected this month';

  @override
  String collectedOfDue(String due, String rate) {
    return 'of $due due, $rate collected';
  }

  @override
  String get nothingDueThisMonth => 'Nothing has fallen due this month yet.';

  @override
  String owedInAll(String amount) {
    return '$amount owed in all';
  }

  @override
  String get unitsLetLabel => 'Units let';

  @override
  String unitsLetValue(String occupied, String units) {
    return '$occupied of $units';
  }

  @override
  String occupancyCaption(String rate, int vacant) {
    String _temp0 = intl.Intl.pluralLogic(
      vacant,
      locale: localeName,
      other: '$vacant vacant',
      zero: 'none vacant',
    );
    return '$rate let, $_temp0';
  }

  @override
  String get noUnitsToLet => 'No units to let yet';

  @override
  String get stillToCollect => 'Still to collect';

  @override
  String monthBarSummary(String expected, String paid) {
    return 'Of $expected rupees due this month, $paid are paid.';
  }

  @override
  String get insightsSection => 'What needs attention';

  @override
  String get noInsights => 'Nothing needs your attention today.';

  @override
  String get insightAlert => 'Act now';

  @override
  String get insightWarning => 'Worth a look';

  @override
  String get insightInfo => 'Good to know';

  @override
  String get insightGood => 'Good news';

  @override
  String insightsShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show all $count',
    );
    return '$_temp0';
  }

  @override
  String get insightsShowFewer => 'Show fewer';

  @override
  String openNamedTenancyAction(String tenant) {
    return 'Open $tenant\'s tenancy';
  }

  @override
  String get seeTenantsAction => 'See tenants';

  @override
  String over60Split(String amount) {
    return 'Of the $amount over 60 days late:';
  }

  @override
  String get dashboardNoPropertiesTitle => 'No properties yet';

  @override
  String get dashboardNoPropertiesBody =>
      'Add your first property to start collecting rent.';

  @override
  String get dashboardNoPropertiesViewer =>
      'Once a property is added, its rent shows here.';

  @override
  String get dashboardNoUnitsTitle => 'No units yet';

  @override
  String get dashboardNoUnitsBody =>
      'Add a unit to a property to let it and collect its rent.';

  @override
  String get dashboardNoUnitsViewer =>
      'Once a unit is added, its rent shows here.';

  @override
  String get seePropertiesAction => 'See properties';

  @override
  String insightCollectionTitle(String rate) {
    return '$rate of this month\'s dues collected';
  }

  @override
  String insightCollectionBody(String amount) {
    return '$amount of them is still to collect.';
  }

  @override
  String get insightCollectionDone => 'Every due of this month is paid.';

  @override
  String insightLongArrearsTitle(String amount) {
    return '$amount owed for over 90 days';
  }

  @override
  String get insightLongArrearsBody =>
      'Money this old is the hardest to recover. Talk to these tenants, or settle it from their deposit when they leave.';

  @override
  String get seeWhoOwesAction => 'See who owes';

  @override
  String get insightIncrementTitle => 'Rent increases to make';

  @override
  String insightIncrementMissed(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count increases were not made when due',
      one: '1 increase was not made when due',
    );
    return '$_temp0: $amount a month not charged.';
  }

  @override
  String insightIncrementUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count increases are due within 30 days.',
      one: '1 increase is due within 30 days.',
    );
    return '$_temp0';
  }

  @override
  String insightExpiringTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tenancies end within 90 days',
      one: '1 tenancy ends within 90 days',
    );
    return '$_temp0';
  }

  @override
  String insightExpiringBody(String tenant, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'in 1 day',
      zero: 'today',
    );
    return '$tenant\'s ends first, $_temp0. Renew it or plan the move-out.';
  }

  @override
  String insightPoliceTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tenancies are not registered with the police',
      one: '1 tenancy is not registered with the police',
    );
    return '$_temp0';
  }

  @override
  String insightPoliceLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are past the law\'s deadline: register them now.',
      one: '1 is past the law\'s deadline: register it now.',
    );
    return '$_temp0';
  }

  @override
  String get insightPoliceBody =>
      'Register each by its deadline. Where no law sets one, the app reminds you.';

  @override
  String insightPoliceSubmittedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count police registrations are waiting for confirmation',
      one: '1 police registration is waiting for confirmation',
    );
    return '$_temp0';
  }

  @override
  String insightPoliceSubmittedLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more are submitted and waiting for confirmation.',
      one: '1 more is submitted and waiting for confirmation.',
    );
    return '$_temp0';
  }

  @override
  String get insightPoliceSubmittedBody =>
      'You have done what the law asks. Update the tenancy once the police confirm it.';

  @override
  String insightVacancyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units are vacant',
      one: '1 unit is vacant',
    );
    return '$_temp0';
  }

  @override
  String insightVacancyBody(int count, String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'they cost',
      one: 'it costs',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The longest has',
      one: 'It has',
    );
    String _temp2 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'for $days days',
      one: 'for 1 day',
      zero: 'since today',
    );
    return 'Empty, $_temp0 you $amount a month at the asking rent. $_temp1 been empty $_temp2.';
  }

  @override
  String insightDepositTitle(String cover) {
    return 'Deposits cover only $cover of overdue rent';
  }

  @override
  String insightDepositBody(String overdue, String held) {
    return '$overdue is overdue and $held of deposits is held. Collect before arrears grow beyond what deposits can settle.';
  }

  @override
  String get insightUtilityTitle => 'Utility bills need attention';

  @override
  String insightUtilityLandlord(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unpaid bills are in your name',
      one: '1 unpaid bill is in your name',
    );
    return '$_temp0, $amount in all: you are liable for them.';
  }

  @override
  String insightUtilityOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills are past their due date.',
      one: '1 bill is past its due date.',
    );
    return '$_temp0';
  }

  @override
  String insightUtilityOverTariff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count protected-tariff meters went over 200 units on their latest bill.',
      one: '1 protected-tariff meter went over 200 units on its latest bill.',
    );
    return '$_temp0';
  }

  @override
  String insightUtilityNearTariff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count protected-tariff meters are near 200 units.',
      one: '1 protected-tariff meter is near 200 units.',
    );
    return '$_temp0';
  }

  @override
  String get seeUtilitiesAction => 'See utilities';

  @override
  String get insightExpenseTitle => 'Expenses are up this month';

  @override
  String insightExpenseBody(String amount, String average) {
    return '$amount so far, against $average a month on average over the three months before.';
  }

  @override
  String get seeExpensesAction => 'See expenses';

  @override
  String insightUnderpricedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units are let below their asking rent',
      one: '1 unit is let below its asking rent',
    );
    return '$_temp0';
  }

  @override
  String insightUnderpricedBody(String amount, String unit) {
    return 'Together $amount a month below what you ask, the most at $unit. Consider it at the next increase or renewal.';
  }

  @override
  String insightCashTitle(String amount) {
    return '$amount in cash with caretakers';
  }

  @override
  String insightCashHolder(String name, String amount) {
    return '$name holds $amount.';
  }

  @override
  String get insightCashShareTitle =>
      'Most of this month\'s money came in cash';

  @override
  String insightCashShare(String share) {
    return '$share of this month\'s money came in cash.';
  }

  @override
  String get insightCashAdvice =>
      'Bank transfers and regular handovers keep less cash in hand.';

  @override
  String get seeCashAction => 'See cash in hand';

  @override
  String get owedSection => 'Owed to you';

  @override
  String owedSectionHelp(String amount) {
    return '$amount in all, by how long it has been owed';
  }

  @override
  String get ageNotDue => 'Not yet due';

  @override
  String get age1to30 => '1 to 30 days late';

  @override
  String get age31to60 => '31 to 60 days late';

  @override
  String get ageOver60 => 'Over 60 days late';

  @override
  String get age61to90 => '61 to 90 days late';

  @override
  String get ageOver90 => 'Over 90 days late';

  @override
  String ageingSummary(
    String total,
    String notDue,
    String early,
    String middle,
    String late,
  ) {
    return '$total rupees owed: $notDue not yet due, $early up to 30 days late, $middle 31 to 60 days late, $late over 60 days late.';
  }

  @override
  String get owingMostSection => 'Owing most';

  @override
  String get seeAllAction => 'See all';

  @override
  String get remindShortAction => 'Remind';

  @override
  String lastRemindedOn(String moment) {
    return 'Reminded $moment';
  }

  @override
  String get upcomingSection => 'Due and coming up';

  @override
  String get upcomingEmpty => 'Nothing falls due in the coming weeks.';

  @override
  String timelineLeaseEnds(String tenant) {
    return '$tenant\'s tenancy ends';
  }

  @override
  String timelineIncrementDue(String tenant) {
    return 'Rent increase for $tenant';
  }

  @override
  String timelineIncrementMissed(String tenant) {
    return 'Rent increase not made for $tenant';
  }

  @override
  String timelineIncrementDetail(String unit, String from, String to) {
    return '$unit: $from to $to';
  }

  @override
  String timelinePolice(String tenant) {
    return 'Register $tenant with the police';
  }

  @override
  String timelinePoliceLegal(String unit) {
    return '$unit: deadline set by law';
  }

  @override
  String timelinePoliceLegalPassed(String unit) {
    return '$unit: the deadline set by law has passed';
  }

  @override
  String timelinePoliceReminder(String unit) {
    return '$unit: the app\'s reminder, no law sets a deadline';
  }

  @override
  String timelinePoliceSubmitted(String unit) {
    return '$unit: submitted, not yet confirmed';
  }

  @override
  String timelineCnicExpires(String tenant) {
    return '$tenant\'s CNIC expires';
  }

  @override
  String timelineCnicExpired(String tenant) {
    return '$tenant\'s CNIC has expired';
  }

  @override
  String get timelineCnicHelp => 'Ask for a copy of the renewed card.';

  @override
  String get vacantSection => 'Vacant units';

  @override
  String vacantFor(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vacant $days days',
      one: 'Vacant 1 day',
      zero: 'Vacant since today',
    );
    return '$_temp0';
  }

  @override
  String get heldAndSpentSection => 'Deposits, tax and expenses';

  @override
  String get depositsHeldLabel => 'Deposits held';

  @override
  String get depositsAgreedLabel => 'Deposits agreed';

  @override
  String get taxWithheldThisMonthLabel => 'Tax withheld this month';

  @override
  String get expensesThisMonthLabel => 'Expenses this month';

  @override
  String get expensesAverageLabel => 'Monthly average of the 3 months before';

  @override
  String get loadingCashflow => 'Loading the cash flow';

  @override
  String get cashflowLoadFailedTitle => 'The cash flow could not be loaded';

  @override
  String get cashflowSection => 'Cash flow, last 12 months';

  @override
  String get moneyInSeries => 'Money in';

  @override
  String get moneyOutSeries => 'Money out';

  @override
  String get monthColumn => 'Month';

  @override
  String cashflowSummary(
    String first,
    String last,
    String moneyIn,
    String moneyOut,
  ) {
    return 'Money in and out each month from $first to $last: $moneyIn rupees in and $moneyOut rupees out in all.';
  }

  @override
  String get cashflowEmpty =>
      'No money came in or went out in the last 12 months.';

  @override
  String get totalInLabel => 'Money in';

  @override
  String get totalOutLabel => 'Money out';

  @override
  String get netLabel => 'Net';

  @override
  String get loadingPerformance => 'Loading the properties\' figures';

  @override
  String get performanceLoadFailedTitle =>
      'The properties\' figures could not be loaded';

  @override
  String get performanceSection => 'Properties, last 12 months';

  @override
  String get performanceEmpty =>
      'Add a property to see its income and expenses here.';

  @override
  String get rentIncomeLabel => 'Rent received';

  @override
  String get otherIncomeLabel => 'Other income';

  @override
  String get propertyExpensesLabel => 'Expenses';

  @override
  String get noiLabel => 'Net operating income';

  @override
  String get grossYieldLabel => 'Gross yield';

  @override
  String get netYieldLabel => 'Net yield';

  @override
  String yieldValue(String percent) {
    return '$percent a year';
  }

  @override
  String get noYieldHelp =>
      'Add the property\'s estimated value to see its yield.';

  @override
  String get noiChartTitle => 'Net operating income by property';

  @override
  String noiChartSummary(String best, String amount) {
    return 'Net operating income over the last 12 months: $best earned most, $amount rupees.';
  }

  @override
  String get scoresSection => 'Payment scores';

  @override
  String get scoresHelp => 'From each tenant\'s rent of the last 12 months.';

  @override
  String get loadingScores => 'Loading the payment scores';

  @override
  String get scoresLoadFailedTitle => 'The payment scores could not be loaded';

  @override
  String get scoresEmpty => 'Scores appear once rent has fallen due.';

  @override
  String get scoreBandGood => 'Pays on time';

  @override
  String get scoreBandFair => 'Sometimes late';

  @override
  String get scoreBandPoor => 'Often late';

  @override
  String scoreSpoken(String score, String band) {
    return 'Payment score $score out of 100, $band';
  }

  @override
  String scoreValue(String score) {
    return '$score/100';
  }

  @override
  String scoreOnTime(String onTime, String count) {
    return 'On time $onTime of $count';
  }

  @override
  String scoreDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'About $days days late on average',
      one: 'About 1 day late on average',
    );
    return '$_temp0';
  }

  @override
  String get scoreNeverLate => 'Never late';

  @override
  String get scoreUnderADayLate => 'Less than a day late on average';

  @override
  String scoreArrears(String months) {
    return 'Owes $months months\' rent';
  }

  @override
  String get scoreNoArrears => 'Nothing overdue';

  @override
  String get scoreSectionTitle => 'Payment score';

  @override
  String get scoreNotYet => 'Not enough rent history for a score yet.';

  @override
  String get scoreFormulaHelp =>
      'Out of 100: 50 for paying on time, 30 for paying only a few days late, 20 for owing little.';

  @override
  String get statementsSection => 'Statements and exports';

  @override
  String get taxYearTitle => 'Tax-year statement';

  @override
  String get taxYearSummary =>
      'Rental income per property, July to June, for your tax adviser';

  @override
  String get ownerStatementTitle => 'Owner statement';

  @override
  String get ownerStatementSummary =>
      'A month\'s money and what is owed, as a PDF for an owner abroad';

  @override
  String get exportTitle => 'Export to a spreadsheet';

  @override
  String get exportSummary => 'The ledger, payments or expenses as a CSV file';

  @override
  String get taxYearLabel => 'Tax year';

  @override
  String taxYearOption(String endYear, String startYear) {
    return 'Tax year $endYear: July $startYear to June $endYear';
  }

  @override
  String get loadingTaxYear => 'Loading the tax year';

  @override
  String get taxYearLoadFailedTitle => 'The tax year could not be loaded';

  @override
  String get notTaxAdviceTitle => 'Not tax advice';

  @override
  String get notTaxAdviceBody =>
      'These figures come from your records, to help your tax adviser. They are not a tax calculation: the app never works out the tax you owe.';

  @override
  String get grossRentLabel => 'Rent received, gross';

  @override
  String get repairsAllowanceLabel => 'Repairs allowance, one fifth';

  @override
  String get netAfterAllowanceLabel => 'Rent after the repairs allowance';

  @override
  String get expensesRecordedLabel => 'Expenses recorded';

  @override
  String get allPropertiesLabel => 'All properties';

  @override
  String get taxYearEmpty =>
      'No rent or expenses were recorded in this tax year.';

  @override
  String get deductibleNote =>
      'Which expenses can be deducted is for your tax adviser to decide.';

  @override
  String get shareCsvAction => 'Share CSV';

  @override
  String taxYearFileTitle(String endYear) {
    return 'Tax-year statement $endYear';
  }

  @override
  String taxYearDocumentTitle(String endYear) {
    return 'Rental income, tax year $endYear';
  }

  @override
  String get ownerStatementMonthLabel => 'Month';

  @override
  String ownerStatementFileTitle(String month) {
    return 'Owner statement, $month';
  }

  @override
  String get moneyReceivedHeading => 'Money received';

  @override
  String get rentAndFeesLabel => 'Rent and late fees';

  @override
  String get depositsReceivedLabel => 'Security deposits';

  @override
  String get otherDuesLabel => 'Other dues';

  @override
  String get unallocatedLabel => 'Kept as credit';

  @override
  String get moneyPaidOutHeading => 'Money paid out';

  @override
  String get depositRefundsLabel => 'Deposits refunded';

  @override
  String get netCashLabel => 'Net for the month';

  @override
  String owedOnHeading(String date) {
    return 'Owed by tenants on $date';
  }

  @override
  String cashHeldOnHeading(String date) {
    return 'Cash held on $date';
  }

  @override
  String get ownerStatementFooter =>
      'Made from the portfolio\'s records. For information: not an audited account.';

  @override
  String get exportWhatLabel => 'What to export';

  @override
  String get exportLedger => 'Ledger: every rent and charge';

  @override
  String get exportPayments => 'Payments';

  @override
  String get exportExpenses => 'Expenses';

  @override
  String get exportPeriodLabel => 'Period';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodLastMonth => 'Last month';

  @override
  String get exportAction => 'Export CSV';

  @override
  String get exportEmpty => 'Nothing was recorded in that period.';

  @override
  String exportFileTitle(String what, String period) {
    return '$what, $period';
  }

  @override
  String inRupees(String label) {
    return '$label (Rs)';
  }

  @override
  String get csvMonth => 'Month';

  @override
  String get csvDescription => 'Note';

  @override
  String get csvWaived => 'Waived';

  @override
  String get csvOwed => 'Owed';

  @override
  String get csvVoided => 'Voided';

  @override
  String get csvYes => 'Yes';

  @override
  String get csvRepair => 'Repair';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Name, phone or CNIC';

  @override
  String get searchIntro =>
      'Find a property, unit or tenant by name, locality, phone or CNIC.';

  @override
  String get searchTooShort => 'Type at least 2 letters or digits.';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String searchNoMatches(String query) {
    return 'Nothing matches $query.';
  }

  @override
  String get searchNoMatchesBody =>
      'Check the spelling, or search by phone or CNIC.';

  @override
  String get searchFailedTitle => 'The search did not finish';

  @override
  String get searching => 'Searching';

  @override
  String searchResultLine(String kind, String detail) {
    return '$kind: $detail';
  }

  @override
  String get daysOverdueLabel => 'Days overdue';
}
