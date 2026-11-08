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
}
