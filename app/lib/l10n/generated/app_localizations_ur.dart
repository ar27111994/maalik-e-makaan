// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'مالکِ مکان';

  @override
  String get welcomeTitle => 'مالکِ مکان ایپ میں خوش آمدید';

  @override
  String get welcomeBody =>
      'اپنی جائیدادوں کا کرایہ، کرایہ دار اور رسیدیں، اردو یا انگریزی میں۔ اپنی زبان چنیں۔ آپ اسے بعد میں سیٹنگز میں بدل سکتے ہیں۔';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUrdu => 'اردو';

  @override
  String get continueAction => 'جاری رکھیں';

  @override
  String get signInTitle => 'سائن اِن';

  @override
  String get signInAction => 'سائن اِن کریں';

  @override
  String get signUpTitle => 'اپنا اکاؤنٹ بنائیں';

  @override
  String get signUpAction => 'اکاؤنٹ بنائیں';

  @override
  String get noAccountPrompt => 'مالکِ مکان ایپ پر نئے ہیں؟';

  @override
  String get haveAccountPrompt => 'پہلے سے اکاؤنٹ ہے؟';

  @override
  String get forgotPasswordAction => 'پاس ورڈ بھول گئے؟';

  @override
  String get emailLabel => 'ای میل';

  @override
  String get passwordLabel => 'پاس ورڈ';

  @override
  String get newPasswordLabel => 'نیا پاس ورڈ';

  @override
  String get passwordHelper =>
      'کم از کم 10 حروف، جن میں انگریزی کے بڑے اور چھوٹے حروف اور ایک ہندسہ ہو۔';

  @override
  String get fullNameLabel => 'آپ کا نام';

  @override
  String get resetPasswordTitle => 'نیا پاس ورڈ بنائیں';

  @override
  String get resetPasswordBody =>
      'اپنے اکاؤنٹ کی ای میل لکھیں۔ ہم آپ کو نیا پاس ورڈ بنانے کا لنک بھیج دیں گے۔';

  @override
  String get sendResetLinkAction => 'ری سیٹ لنک بھیجیں';

  @override
  String get checkEmailTitle => 'اپنی ای میل دیکھیں';

  @override
  String get resendEmailAction => 'ای میل دوبارہ بھیجیں';

  @override
  String get backToSignInAction => 'سائن اِن پر واپس جائیں';

  @override
  String get choosePasswordTitle => 'نیا پاس ورڈ چنیں';

  @override
  String get savePasswordAction => 'پاس ورڈ محفوظ کریں';

  @override
  String get signingInCallback => 'سائن اِن ہو رہا ہے…';

  @override
  String get validationRequired => 'یہ خانہ بھرنا ضروری ہے۔';

  @override
  String get validationEmail => 'name@example.com جیسی ای میل لکھیں۔';

  @override
  String get validationPassword =>
      'کم از کم 10 حروف استعمال کریں، جن میں انگریزی کے بڑے اور چھوٹے حروف اور ایک ہندسہ ہو۔';

  @override
  String get navTenants => 'کرایہ دار';

  @override
  String get navMoney => 'حساب';

  @override
  String get navProperties => 'جائیدادیں';

  @override
  String get navMore => 'مزید';

  @override
  String get settingsTitle => 'سیٹنگز';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsAppearance => 'اسکرین کا انداز';

  @override
  String get themeSystem => 'فون کی سیٹنگ کے مطابق';

  @override
  String get themeLight => 'لائٹ';

  @override
  String get themeDark => 'ڈارک';

  @override
  String get highContrastLabel => 'زیادہ کنٹراسٹ';

  @override
  String get highContrastHelper =>
      'گہرے رنگ اور واضح حاشیے، دھوپ میں پڑھنا آسان۔';

  @override
  String get settingsNumbers => 'رقمیں';

  @override
  String get groupingWestern => 'انگریزی انداز (1,250,000 روپے)';

  @override
  String get groupingSouthAsian => 'لاکھ اور کروڑ (12,50,000 روپے)';

  @override
  String get settingsAccount => 'اکاؤنٹ';

  @override
  String get signOutAction => 'سائن آؤٹ کریں';

  @override
  String get deleteAccountAction => 'اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get settingsAbout => 'ایپ کے بارے میں';

  @override
  String get licencesAction => 'اوپن سورس لائسنس';

  @override
  String get failureNetwork =>
      'رابطہ نہیں ہو سکا۔ اپنا انٹرنیٹ چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get failureSessionExpired =>
      'آپ سائن آؤٹ ہو گئے ہیں۔ دوبارہ سائن اِن کریں۔';

  @override
  String get failureReauthenticate =>
      'آپ کی حفاظت کے لیے، یہ کرنے سے پہلے دوبارہ سائن اِن کریں۔';

  @override
  String get failureForbidden => 'آپ کو یہ کرنے کی اجازت نہیں ہے۔';

  @override
  String get failureNotFound => 'یہ نہیں ملا۔ شاید یہ ڈیلیٹ ہو چکا ہے۔';

  @override
  String get failureConflict => 'یہ پہلے سے موجود ہے۔';

  @override
  String get failureRateLimited =>
      'بہت زیادہ کوششیں ہو گئیں۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String failureRateLimitedFor(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds سیکنڈ',
      one: '1 سیکنڈ',
    );
    return 'بہت زیادہ کوششیں ہو گئیں۔ $_temp0 بعد دوبارہ کوشش کریں۔';
  }

  @override
  String get failureBusy => 'سروس اس وقت مصروف ہے۔ دوبارہ کوشش کریں۔';

  @override
  String get failureServer =>
      'ہماری طرف کچھ خرابی ہو گئی۔ کچھ دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get failureUnexpected => 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get failureRejected =>
      'یہ محفوظ نہیں ہو سکا۔ تفصیلات چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get reasonInvalidCredentials => 'ای میل یا پاس ورڈ درست نہیں۔';

  @override
  String get reasonEmailNotConfirmed =>
      'پہلے اپنی ای میل کی تصدیق کریں۔ ہمارا بھیجا ہوا لنک کھولیں۔';

  @override
  String get reasonEmailTaken =>
      'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔ اس کے بجائے سائن اِن کریں۔';

  @override
  String get reasonWeakPassword =>
      'اس سے مضبوط پاس ورڈ چنیں۔ کم از کم 10 حروف ہوں، جن میں انگریزی کے بڑے اور چھوٹے حروف اور ایک ہندسہ ہو۔';

  @override
  String get reasonSamePassword =>
      'ایسا پاس ورڈ چنیں جو آپ نے پہلے استعمال نہ کیا ہو۔';

  @override
  String get reasonLastOwner =>
      'ہر پورٹ فولیو کا کم از کم ایک مالک ہونا ضروری ہے۔ پہلے کسی اور کو مالک بنائیں۔';

  @override
  String get reasonConfirmationMismatch => 'آپ کا لکھا نام نہیں ملتا۔';

  @override
  String get reasonAccountDeleted => 'یہ اکاؤنٹ ڈیلیٹ ہو رہا ہے۔';

  @override
  String get reasonPortfolioLimit =>
      'آپ زیادہ سے زیادہ 20 پورٹ فولیوز کے مالک ہو سکتے ہیں۔';

  @override
  String get retryAction => 'دوبارہ کوشش کریں';

  @override
  String updatedAt(String time) {
    return '$time پر اپ ڈیٹ ہوا';
  }

  @override
  String offlineShowingSaved(String time) {
    return 'آپ آف لائن ہیں۔ یہ وہ معلومات ہیں جو $time پر محفوظ ہوئیں۔';
  }

  @override
  String comingSoonTitle(String section) {
    return '$section ابھی تیار ہو رہا ہے';
  }

  @override
  String get comingSoonBody => 'ایپ کا یہ حصہ اگلی اپ ڈیٹ میں آئے گا۔';

  @override
  String get configErrorTitle => 'یہ بلڈ سیٹ اپ نہیں';

  @override
  String get reasonAlreadyMember => 'یہ شخص پہلے سے اس پورٹ فولیو میں شامل ہے۔';

  @override
  String get reasonMemberNotFound => 'یہ شخص اب اس پورٹ فولیو میں شامل نہیں۔';

  @override
  String get reasonInvalidRole =>
      'ان میں سے ایک رول چنیں: مالک، منیجر، اکاؤنٹنٹ یا صرف دیکھنے والا۔';

  @override
  String get reasonInvalidEmail => 'درست ای میل لکھیں۔';

  @override
  String get reasonAlreadyVoided => 'یہ انٹری پہلے ہی کینسل ہو چکی ہے۔';

  @override
  String get reasonAmountExceedsOutstanding =>
      'یہ رقم اس کرایہ داری کے ذمے باقی رقم سے زیادہ ہے۔';

  @override
  String get reasonChargeHasPayments =>
      'اس چارج کی ادائیگی مل چکی ہے۔ پہلے وہ ادائیگی کینسل کریں۔';

  @override
  String get reasonChargeNotEditable =>
      'صرف آپ کے لگائے ہوئے چارج کی رقم بدل سکتی ہے۔ اسے کینسل کر کے نیا چارج لگائیں۔';

  @override
  String get reasonChargeVoided => 'یہ چارج کینسل ہو چکا ہے، اب بدل نہیں سکتا۔';

  @override
  String get reasonDepositAlreadyUsed =>
      'اس کے بعد سیکیورٹی میں سے رقم استعمال ہو چکی ہے، اس لیے یہ واپس نہیں ہو سکتا۔';

  @override
  String get reasonDepositBelowReceived =>
      'سیکیورٹی اس رقم سے کم نہیں ہو سکتی جو پہلے مل چکی ہے۔';

  @override
  String get reasonInsufficientDeposit =>
      'جتنی سیکیورٹی جمع ہے، وہ اس رقم سے کم ہے۔';

  @override
  String get reasonDocumentEntityNotFound =>
      'جس ریکارڈ کے ساتھ یہ فائل تھی، وہ اب موجود نہیں۔';

  @override
  String get reasonDocumentFileMissing =>
      'فائل پوری اپ لوڈ نہیں ہوئی۔ اسے دوبارہ اپ لوڈ کریں۔';

  @override
  String get reasonDocumentFilePendingDeletion =>
      'یہ فائل ڈیلیٹ ہو رہی ہے۔ اسے دوبارہ اپ لوڈ کریں۔';

  @override
  String get reasonIdempotencyKeyReused =>
      'یہ ادائیگی مختلف تفصیلات کے ساتھ پہلے ہی درج ہو چکی ہے۔ دوبارہ کوشش سے پہلے حساب دیکھ لیں۔';

  @override
  String get reasonInvalidAmount =>
      'صفر سے زیادہ رقم لکھیں، پوائنٹ کے بعد زیادہ سے زیادہ دو ہندسے۔';

  @override
  String get reasonInvalidChargeSelection =>
      'اس کرایہ داری کے وہ چارج چنیں جو ابھی باقی ہیں۔';

  @override
  String get reasonInvalidDate => 'درست تاریخ چنیں۔';

  @override
  String get reasonInvalidTaxWithheld =>
      'کٹا ہوا ٹیکس ادائیگی سے زیادہ نہیں ہو سکتا۔';

  @override
  String get reasonInvalidTaxYear => 'درست ٹیکس سال چنیں۔';

  @override
  String get reasonInvalidMethod => 'ادائیگی کا طریقہ چنیں۔';

  @override
  String get reasonInvalidReason => 'کرایہ بدلنے کی وجہ چنیں۔';

  @override
  String get reasonReasonRequired => 'وجہ بتائیں۔';

  @override
  String get reasonLeaseHasRecords =>
      'اس کرایہ داری میں رقمیں درج ہیں، اس لیے اسے ڈیلیٹ نہیں کیا جا سکتا۔ اس کے بجائے کرایہ داری ختم کریں۔';

  @override
  String get reasonLeaseNotActive => 'یہ کرایہ داری جاری نہیں۔';

  @override
  String get reasonLeaseNotOnConnection => 'یہ کرایہ داری اس کنکشن پر نہیں ہے۔';

  @override
  String get reasonTenantArchived =>
      'یہ کرایہ دار آرکائیو میں ہیں۔ پہلے انہیں آرکائیو سے واپس لائیں۔';

  @override
  String get reasonUnitArchived =>
      'یہ یونٹ آرکائیو میں ہے۔ پہلے اسے آرکائیو سے واپس لائیں۔';

  @override
  String get reasonConstraintViolation =>
      'کچھ تفصیلات درست نہیں، یا کسی ایسی چیز کی طرف اشارہ کرتی ہیں جو اب موجود نہیں۔';

  @override
  String get navDashboard => 'ڈیش بورڈ';

  @override
  String get continueInEnglish => 'Continue in English';

  @override
  String get continueInUrdu => 'اردو میں جاری رکھیں';

  @override
  String validationTooLong(int max) {
    return 'زیادہ سے زیادہ $max حروف استعمال کریں۔';
  }

  @override
  String get validationPasswordMismatch => 'دونوں پاس ورڈ ایک جیسے نہیں ہیں۔';

  @override
  String get validationPhone => '03001234567 جیسا فون نمبر لکھیں۔';

  @override
  String get validationTypedEmail =>
      'اپنی ای میل بالکل ویسے ہی لکھیں جیسے دکھائی گئی ہے۔';

  @override
  String get accountDeletedTitle => 'آپ کا اکاؤنٹ ڈیلیٹ ہو گیا ہے';

  @override
  String get accountDeletedBody =>
      'آپ کا سائن اِن، پروفائل اور وہ پورٹ فولیوز جن کے آپ اکیلے مالک تھے، ختم ہو گئے ہیں۔ مالکِ مکان ایپ استعمال کرنے کا شکریہ۔';

  @override
  String get emailSentAgain => 'ہم نے ای میل دوبارہ بھیج دی ہے۔';

  @override
  String get checkEmailBodyNoAddress =>
      'ہم نے آپ کو ایک لنک بھیجا ہے۔ جاری رکھنے کے لیے اسے اسی فون یا کمپیوٹر پر کھولیں۔ اگر چند منٹ میں نہ ملے تو اپنا اسپیم فولڈر دیکھیں۔';

  @override
  String get checkEmailResetHint =>
      'یہ لنک صرف ایک بار اور ایک گھنٹے تک کام کرتا ہے۔ اگر اس ای میل سے کوئی اکاؤنٹ نہیں تو ہم کوئی ای میل نہیں بھیجتے۔';

  @override
  String resendWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds سیکنڈ',
      one: '1 سیکنڈ',
    );
    return 'آپ $_temp0 بعد اسے دوبارہ بھیج سکتے ہیں۔';
  }

  @override
  String get passwordSaved => 'آپ کا نیا پاس ورڈ محفوظ ہو گیا ہے۔';

  @override
  String get repeatPasswordLabel => 'نیا پاس ورڈ دوبارہ لکھیں';

  @override
  String get choosePasswordBody =>
      'وہ پاس ورڈ چنیں جس سے آپ اب سے سائن اِن کریں گے۔';

  @override
  String get linkFailedTitle => 'یہ لنک کام نہیں کر سکا';

  @override
  String get reasonLinkExpired =>
      'یہ لنک ایکسپائر ہو چکا ہے یا پہلے استعمال ہو چکا ہے۔ نیا لنک منگوائیں۔';

  @override
  String get reasonLinkInvalid =>
      'یہ سائن اِن کا درست لنک نہیں۔ ہماری بھیجی ہوئی تازہ ترین ای میل کا لنک کھولیں۔';

  @override
  String get reasonLinkOtherDevice =>
      'لنک اسی فون یا براؤزر پر کھولیں جہاں سے آپ نے اسے منگوایا تھا۔ اگر آپ اپنی ای میل کی تصدیق کر رہے تھے تو وہ ہو چکی ہے۔ اپنے پاس ورڈ سے سائن اِن کریں۔';

  @override
  String get reasonSignupDisabled =>
      'اس وقت نئے اکاؤنٹ نہیں بن سکتے۔ کچھ دیر بعد کوشش کریں۔';

  @override
  String get reasonMfaRequired =>
      'اس اکاؤنٹ میں سائن اِن کے لیے دوسرا کوڈ بھی لگتا ہے (ٹو اسٹیپ)، جسے یہ ایپ ابھی چیک نہیں کر سکتی، اس لیے اسے یہاں سے ڈیلیٹ نہیں کیا جا سکتا۔';

  @override
  String get reasonDoesNotMatchAccount => 'یہ آپ کے اکاؤنٹ کی ای میل نہیں ہے۔';

  @override
  String get createFirstPortfolioTitle => 'اپنا پورٹ فولیو بنائیں';

  @override
  String get newPortfolioTitle => 'نیا پورٹ فولیو';

  @override
  String get createFirstPortfolioBody =>
      'پورٹ فولیو میں آپ کی جائیدادیں، کرایہ دار اور رقم کا حساب ایک جگہ رہتا ہے۔ اس کا نام خاندان، عمارت یا مالک کے نام پر رکھیں، جیسے ”خان فیملی کی جائیدادیں“۔';

  @override
  String get newPortfolioBody =>
      'جن جائیدادوں کا حساب الگ ہے، انہیں الگ پورٹ فولیو میں رکھیں، جیسے کسی رشتہ دار کا مکان، یا اپنے الگ حساب والا پلازہ۔ آپ اس کے مالک ہوں گے۔';

  @override
  String get portfolioNameLabel => 'پورٹ فولیو کا نام';

  @override
  String get portfolioNameHelper => 'آپ بعد میں نام بدل سکتے ہیں۔';

  @override
  String get portfolioNameInvalid =>
      'یہ نام استعمال نہیں ہو سکتا۔ حروف، ہندسے اور خالی جگہیں استعمال کریں۔';

  @override
  String get createPortfolioAction => 'پورٹ فولیو بنائیں';

  @override
  String get cancelAction => 'رہنے دیں';

  @override
  String portfolioCreated(String name) {
    return '$name تیار ہے۔';
  }

  @override
  String get roleOwner => 'مالک';

  @override
  String get roleManager => 'منیجر';

  @override
  String get roleAccountant => 'اکاؤنٹنٹ';

  @override
  String get roleViewer => 'صرف دیکھنے والا';

  @override
  String get switchPortfolioTitle => 'پورٹ فولیو بدلیں';

  @override
  String get switchPortfolioAction => 'پورٹ فولیو بدلیں';

  @override
  String get currentPortfolioLabel => 'موجودہ پورٹ فولیو';

  @override
  String get newPortfolioAction => 'نیا پورٹ فولیو';

  @override
  String get portfolioSection => 'پورٹ فولیو';

  @override
  String yourRole(String role) {
    return 'آپ کا رول: $role';
  }

  @override
  String get settingsSummary =>
      'آپ کی تفصیلات، زبان، اسکرین کا انداز اور اکاؤنٹ';

  @override
  String get loadingPortfolios => 'آپ کے پورٹ فولیوز لوڈ ہو رہے ہیں';

  @override
  String get portfoliosLoadFailedTitle => 'آپ کے پورٹ فولیوز لوڈ نہیں ہو سکے';

  @override
  String get profileLoadFailedTitle => 'آپ کی تفصیلات لوڈ نہیں ہو سکیں';

  @override
  String get loadingProfile => 'آپ کی تفصیلات لوڈ ہو رہی ہیں';

  @override
  String languageNotSavedToProfile(String reason) {
    return 'اس فون یا کمپیوٹر پر زبان بدل گئی، لیکن آپ کے اکاؤنٹ میں محفوظ نہیں ہو سکی۔ $reason';
  }

  @override
  String get settingsLanguageHelp =>
      'ہماری بھیجی گئی ای میلز بھی اسی زبان میں ہوں گی۔';

  @override
  String get themeLabel => 'تھیم';

  @override
  String get signedInAs => 'آپ اس ای میل سے سائن اِن ہیں';

  @override
  String get profileSection => 'آپ کی تفصیلات';

  @override
  String get profileSectionHelp =>
      'آپ کے پورٹ فولیوز کے لوگ آپ کا نام اور فون نمبر دیکھ سکتے ہیں۔';

  @override
  String get phoneLabel => 'فون نمبر';

  @override
  String get phoneHelper =>
      '03001234567 جیسا پاکستانی نمبر، یا باہر کے ملک کا نمبر جو 00 اور ملک کے کوڈ سے شروع ہو۔';

  @override
  String get saveDetailsAction => 'تفصیلات محفوظ کریں';

  @override
  String get detailsSaved => 'آپ کی تفصیلات محفوظ ہو گئی ہیں۔';

  @override
  String get textSizeTitle => 'الفاظ کا سائز';

  @override
  String textSizeBody(int percent) {
    return 'آپ کے فون پر الفاظ کا سائز $percent% ہے۔ ایپ بھی یہی سائز رکھتی ہے۔ اسے فون کی ڈسپلے سیٹنگز میں بدلیں۔';
  }

  @override
  String get textSizePreviewLabel => 'نمونہ';

  @override
  String get textSizeSampleName => 'عائشہ خان';

  @override
  String get textSizeSampleDetail => 'دکان نمبر 3، کرائے کی تاریخ 5';

  @override
  String get deleteAccountTitle => 'اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get deletionPreviewFailedTitle =>
      'ہم یہ نہیں دیکھ سکے کہ کیا ڈیلیٹ ہو گا';

  @override
  String get loadingDeletionPreview => 'ہم دیکھ رہے ہیں کہ کیا ڈیلیٹ ہو گا';

  @override
  String get deleteAccountWarningTitle => 'یہ واپس نہیں ہو سکتا';

  @override
  String get deleteAccountWarningBody =>
      'ڈیلیٹ کیا ہوا ریکارڈ واپس نہیں آ سکتا، ہماری طرف سے بھی نہیں۔ جاری رکھنے سے پہلے جو رسیدیں اور اسٹیٹمنٹ آپ کو چاہییں، ان کی کاپیاں رکھ لیں۔';

  @override
  String get deleteAccountWhatGoes => 'کیا ڈیلیٹ ہو گا';

  @override
  String get deleteAccountNoPortfolios =>
      'آپ کسی پورٹ فولیو کے اکیلے مالک نہیں، اس لیے کوئی پورٹ فولیو ڈیلیٹ نہیں ہو گا۔';

  @override
  String deleteAccountPortfolios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'آپ ان $count پورٹ فولیوز کے اکیلے مالک ہیں، اس لیے یہ اپنی ہر چیز سمیت ڈیلیٹ ہو جائیں گے: جائیدادیں، کرایہ دار، ادائیگیاں، رسیدیں اور فائلیں۔',
      one: 'آپ اس پورٹ فولیو کے اکیلے مالک ہیں، اس لیے یہ اپنی ہر چیز سمیت ڈیلیٹ ہو جائے گا: جائیدادیں، کرایہ دار، ادائیگیاں، رسیدیں اور فائلیں۔',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountMemberships =>
      'آپ باقی سب پورٹ فولیوز سے نکل جائیں گے۔ وہ پورٹ فولیو اور ان کا ریکارڈ ان کے مالکوں کے پاس رہے گا۔';

  @override
  String get deleteAccountSignIn =>
      'آپ کا سائن اِن اور پروفائل ڈیلیٹ ہو جائیں گے، اور آپ سائن آؤٹ ہو جائیں گے۔';

  @override
  String get deleteAccountConfirmTitle => 'تصدیق کریں کہ یہ آپ ہیں';

  @override
  String deleteAccountConfirmBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes منٹ',
      one: '1 منٹ',
    );
    return 'اپنا پاس ورڈ لکھیں، کیونکہ ڈیلیٹ کرنے کے لیے پچھلے $_temp0 کے اندر سائن اِن ضروری ہے۔ پھر اپنی ای میل لکھیں۔';
  }

  @override
  String typeEmailToConfirm(String email) {
    return 'تصدیق کے لیے $email لکھیں';
  }

  @override
  String get deleteAccountConfirmAction => 'میرا اکاؤنٹ ڈیلیٹ کریں';

  @override
  String get doomedPortfolioOnlyYou => 'اسے صرف آپ استعمال کرتے ہیں';

  @override
  String doomedPortfolioOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اور لوگ اسے نہیں دیکھ سکیں گے',
      one: '1 اور شخص اسے نہیں دیکھ سکے گا',
    );
    return '$_temp0';
  }

  @override
  String get checkEmailSentTo => 'ہم نے اس ای میل پر ایک لنک بھیجا ہے:';

  @override
  String get checkEmailInstructions =>
      'جاری رکھنے کے لیے اسے اسی فون یا کمپیوٹر پر کھولیں۔ اگر چند منٹ میں نہ ملے تو اپنا اسپیم فولڈر دیکھیں۔';

  @override
  String get groupingLabel => 'رقم لکھنے کا انداز';

  @override
  String get saveAction => 'محفوظ کریں';

  @override
  String get doneAction => 'ہو گیا';

  @override
  String get notNowAction => 'ابھی نہیں';

  @override
  String get goToAppAction => 'ایپ پر جائیں';

  @override
  String validationNumberRange(int min, int max) {
    return '$min سے $max تک کوئی نمبر لکھیں۔';
  }

  @override
  String get validationPercent =>
      '0 سے 100 تک فیصد لکھیں، پوائنٹ کے بعد زیادہ سے زیادہ دو ہندسے۔';

  @override
  String get validationRaast => '03001234567 جیسا پاکستانی موبائل نمبر لکھیں۔';

  @override
  String get validationIban =>
      'PK36 SCBL 0000 0011 2345 6702 جیسا پاکستانی IBAN لکھیں۔';

  @override
  String get linkNotOpened => 'لنک نہیں کھل سکا۔';

  @override
  String get roleOwnerHelp => 'سب کچھ، ٹیم اور ادائیگی کی تفصیلات سمیت۔';

  @override
  String get roleManagerHelp =>
      'جائیدادیں، کرایہ دار اور کرایہ داریاں سنبھالتا ہے، اور رقمیں درج کرتا ہے۔';

  @override
  String get roleAccountantHelp =>
      'ادائیگیاں اور خرچے درج کرتا ہے، اور باقی سب کچھ دیکھ سکتا ہے۔';

  @override
  String get roleViewerHelp => 'سب کچھ دیکھ سکتا ہے، کچھ بدل نہیں سکتا۔';

  @override
  String get teamTitle => 'ٹیم';

  @override
  String get teamSummary => 'کون یہ پورٹ فولیو دیکھ اور چلا سکتا ہے';

  @override
  String get portfolioDetailsTitle => 'پورٹ فولیو کی تفصیلات';

  @override
  String get portfolioDetailsSummary =>
      'نام، نئی کرایہ داری میں پہلے سے کیا بھرا جائے، اور ادائیگی کی تفصیلات';

  @override
  String get teamMembersSection => 'ٹیم کے لوگ';

  @override
  String get teamInvitationsSection => 'جن دعوتوں کا جواب نہیں آیا';

  @override
  String get teamInvitationsHelp =>
      'ہر لنک صرف ایک بار، 7 دن تک، اور صرف اسی ای میل کے لیے کام کرتا ہے جس پر بھیجا گیا۔';

  @override
  String memberYou(String name) {
    return '$name (آپ)';
  }

  @override
  String get memberNoName => 'بغیر نام کا ممبر';

  @override
  String memberRoleAndEmail(String role, String email) {
    return '$role · $email';
  }

  @override
  String get teamLoadFailedTitle => 'ٹیم لوڈ نہیں ہو سکی';

  @override
  String get loadingTeam => 'ٹیم لوڈ ہو رہی ہے';

  @override
  String get inviteAction => 'کسی کو دعوت بھیجیں';

  @override
  String invitationExpires(String role, String date) {
    return '$role · $date تک';
  }

  @override
  String invitationExpired(String role, String date) {
    return '$role · $date کو ایکسپائر ہو گئی';
  }

  @override
  String get invitationExpiredBadge => 'ایکسپائر ہو گئی';

  @override
  String get inviteAgainAction => 'دوبارہ دعوت بھیجیں';

  @override
  String get revokeInvitationAction => 'دعوت واپس لیں';

  @override
  String revokeInvitationTitle(String email) {
    return '$email کو بھیجی گئی دعوت واپس لیں؟';
  }

  @override
  String get revokeInvitationBody =>
      'لنک کام کرنا بند کر دے گا۔ آپ انہیں بعد میں دوبارہ دعوت بھیج سکتے ہیں۔';

  @override
  String get invitationCancelled => 'آپ نے دعوت واپس لے لی۔';

  @override
  String get memberRoleLabel => 'رول';

  @override
  String get changeRoleAction => 'رول بدلیں';

  @override
  String roleChanged(String name, String role) {
    return '$name کا رول اب $role ہے۔';
  }

  @override
  String get onlyOwnerNote =>
      'ہر پورٹ فولیو کا ایک مالک ہونا ضروری ہے۔ یہ رول بدلنے سے پہلے کسی اور کو مالک بنائیں۔';

  @override
  String get removeMemberAction => 'پورٹ فولیو سے نکالیں';

  @override
  String removeMemberTitle(String name) {
    return '$name کو نکال دیں؟';
  }

  @override
  String get removeMemberBody =>
      'وہ یہ پورٹ فولیو فوراً نہیں دیکھ سکیں گے۔ ان کا درج کیا ہوا سب کچھ ریکارڈ میں رہے گا۔';

  @override
  String memberRemoved(String name) {
    return '$name کو نکال دیا گیا۔';
  }

  @override
  String get leaveAction => 'پورٹ فولیو چھوڑیں';

  @override
  String leaveTitle(String portfolio) {
    return '$portfolio چھوڑ دیں؟';
  }

  @override
  String get leaveBody =>
      'آپ یہ پورٹ فولیو فوراً نہیں دیکھ سکیں گے۔ صرف کوئی مالک آپ کو دوبارہ دعوت بھیج سکتا ہے۔';

  @override
  String get leaveLastOwner =>
      'آپ اکیلے مالک ہیں۔ چھوڑنے سے پہلے کسی اور کو مالک بنائیں۔';

  @override
  String leftPortfolio(String portfolio) {
    return 'آپ نے $portfolio چھوڑ دیا۔';
  }

  @override
  String get inviteTitle => 'کسی کو دعوت بھیجیں';

  @override
  String get inviteBody =>
      'انہیں ایک ای میل ملے گی۔ اس کا لنک صرف ایک بار، 7 دن تک، اور صرف اسی ای میل کے لیے کام کرے گا۔ آپ یہ لنک خود بھی بھیج سکتے ہیں۔';

  @override
  String get inviteEmailLabel => 'ان کی ای میل';

  @override
  String get inviteRoleLabel => 'ان کا رول';

  @override
  String get sendInvitationAction => 'دعوت بھیجیں';

  @override
  String get invitationReadyTitle => 'دعوت تیار ہے';

  @override
  String deliverySent(String email) {
    return 'ہم نے دعوت $email کو ای میل کر دی ہے۔';
  }

  @override
  String deliveryNotConfigured(String email) {
    return 'ای میل سیٹ اپ نہیں، اس لیے ہم نے کچھ نہیں بھیجا۔ یہ لنک $email کو خود بھیجیں۔';
  }

  @override
  String deliveryRateLimited(String email) {
    return 'پچھلے ایک گھنٹے میں اس ای میل پر یا آپ کی طرف سے بہت زیادہ ای میلز گئیں، اس لیے ہم نے یہ نہیں بھیجی۔ یہ لنک $email کو خود بھیجیں۔';
  }

  @override
  String deliveryFailed(String email) {
    return '$email کو ای میل نہیں جا سکی۔ یہ لنک خود بھیجیں۔';
  }

  @override
  String deliveryUnknown(String email) {
    return 'اگر $email کو ای میل نہ ملے تو یہ لنک خود بھیجیں۔';
  }

  @override
  String invitationValidUntil(String date, String email) {
    return 'یہ لنک صرف ایک بار، $date تک، اور صرف $email کے لیے کام کرے گا۔';
  }

  @override
  String get invitationLinkLabel => 'دعوت کا لنک';

  @override
  String get copyLinkAction => 'لنک کاپی کریں';

  @override
  String get linkCopied => 'لنک کاپی ہو گیا۔';

  @override
  String get shareWhatsAppAction => 'واٹس ایپ پر بھیجیں';

  @override
  String invitationShareMessage(String portfolio, String url) {
    return 'آپ کو مالکِ مکان ایپ پر $portfolio میں شامل ہونے کی دعوت بھیجی گئی ہے۔ شامل ہونے کے لیے یہ لنک کھولیں: $url';
  }

  @override
  String get tenancyDefaultsSection =>
      'نئی کرایہ داری میں پہلے سے بھرا جائے گا';

  @override
  String get tenancyDefaultsHelp =>
      'آپ انہیں ہر کرایہ داری کے لیے بدل سکتے ہیں۔';

  @override
  String get dueDayLabel => 'ہر مہینے کرائے کی تاریخ';

  @override
  String get dueDayHelper => '1 سے 28 تک، تاکہ ہر مہینے میں یہ تاریخ ہو۔';

  @override
  String get graceDaysLabel => 'کتنے دن بعد لیٹ فیس لگے';

  @override
  String get graceDaysHelper =>
      'تاریخ کے بعد اتنے دن تک کرایہ لیٹ نہیں مانا جائے گا۔';

  @override
  String get incrementLabel => 'سالانہ اضافہ (%)';

  @override
  String get paymentDetailsSection => 'ادائیگی کی تفصیلات';

  @override
  String get paymentDetailsHelp =>
      'کرایہ دار یہ رسیدوں اور یاد دہانیوں پر دیکھتے ہیں۔';

  @override
  String get landlordNameLabel => 'رسیدوں پر نام';

  @override
  String get landlordPhoneLabel => 'رسیدوں پر فون نمبر';

  @override
  String get raastIdLabel => 'راست آئی ڈی';

  @override
  String get raastIdHelper =>
      'راست کے لیے رجسٹرڈ موبائل نمبر، جیسے 03001234567۔';

  @override
  String get bankAccountTitleLabel => 'بینک اکاؤنٹ کا ٹائٹل';

  @override
  String get ibanLabel => 'IBAN';

  @override
  String get ibanHelper => '24 حروف، جو PK سے شروع ہوں۔';

  @override
  String get portfolioDetailsSaved => 'پورٹ فولیو کی تفصیلات محفوظ ہو گئیں۔';

  @override
  String get portfolioDetailsLoadFailedTitle =>
      'پورٹ فولیو کی تفصیلات لوڈ نہیں ہو سکیں';

  @override
  String get loadingPortfolioDetails => 'پورٹ فولیو کی تفصیلات لوڈ ہو رہی ہیں';

  @override
  String get acceptInvitationTitle => 'دعوت';

  @override
  String get acceptingInvitation => 'آپ کی دعوت کھل رہی ہے…';

  @override
  String invitationAcceptedTitle(String portfolio) {
    return '$portfolio میں خوش آمدید';
  }

  @override
  String invitationAcceptedBody(String role) {
    return 'آپ شامل ہو گئے ہیں۔ آپ کا رول: $role۔';
  }

  @override
  String get openPortfolioAction => 'پورٹ فولیو کھولیں';

  @override
  String get invitationFailedTitle => 'یہ دعوت استعمال نہیں ہو سکتی';

  @override
  String get invitationInvalidBody =>
      'یہ دعوت کا درست لنک نہیں ہے۔ نئی دعوت منگوائیں۔';

  @override
  String get invitationRevokedBody =>
      'یہ دعوت واپس لے لی گئی ہے۔ پورٹ فولیو کے کسی مالک سے نئی دعوت منگوائیں۔';

  @override
  String get invitationAlreadyUsedBody =>
      'یہ دعوت کسی اور اکاؤنٹ سے پہلے ہی قبول ہو چکی ہے۔ نئی دعوت منگوائیں۔';

  @override
  String get invitationExpiredBody =>
      'یہ دعوت ایکسپائر ہو چکی ہے: دعوت 7 دن تک کام کرتی ہے۔ نئی دعوت منگوائیں۔';

  @override
  String get invitationEmailNotVerifiedBody =>
      'پہلے اپنی ای میل کی تصدیق کریں، پھر دعوت کا لنک دوبارہ کھولیں۔';

  @override
  String get invitationEmailMismatchBody =>
      'یہ دعوت کسی اور ای میل پر بھیجی گئی تھی۔ سائن آؤٹ کریں۔ پھر اسی ای میل سے سائن اِن کریں یا اکاؤنٹ بنائیں جس پر یہ بھیجی گئی تھی۔';

  @override
  String get invitationUnknownBody =>
      'یہ دعوت قبول نہیں ہو سکتی۔ نئی دعوت منگوائیں۔';

  @override
  String get noInvitationBody =>
      'اس فون یا کمپیوٹر پر کوئی دعوت انتظار میں نہیں۔ دعوت کی ای میل میں دیا گیا لنک کھولیں۔';

  @override
  String get invitationNotAcceptedTitle => 'دعوت نہیں کھل سکی';

  @override
  String get fewerDaysAction => 'کم دن';

  @override
  String get moreDaysAction => 'زیادہ دن';

  @override
  String dayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دن',
      one: '1 دن',
      zero: 'کوئی دن نہیں',
    );
    return '$_temp0';
  }

  @override
  String get invitationWorksUntil => 'کب تک چلے گی';

  @override
  String get invitationAcceptedNoName => 'آپ پورٹ فولیو میں شامل ہو گئے';

  @override
  String get propertyTypeHouse => 'مکان';

  @override
  String get propertyTypeApartmentBuilding => 'اپارٹمنٹ کی عمارت';

  @override
  String get propertyTypeApartment => 'فلیٹ';

  @override
  String get propertyTypePlaza => 'پلازہ';

  @override
  String get propertyTypeShop => 'دکان';

  @override
  String get propertyTypeOffice => 'دفتر';

  @override
  String get propertyTypeHostel => 'ہاسٹل';

  @override
  String get propertyTypeFarmhouse => 'فارم ہاؤس';

  @override
  String get propertyTypeWarehouse => 'گودام';

  @override
  String get propertyTypePlot => 'پلاٹ';

  @override
  String get propertyTypeOther => 'دیگر';

  @override
  String get provincePunjab => 'پنجاب';

  @override
  String get provinceSindh => 'سندھ';

  @override
  String get provinceKhyberPakhtunkhwa => 'خیبر پختونخوا';

  @override
  String get provinceBalochistan => 'بلوچستان';

  @override
  String get provinceIslamabad => 'اسلام آباد';

  @override
  String get provinceGilgitBaltistan => 'گلگت بلتستان';

  @override
  String get provinceAzadKashmir => 'آزاد کشمیر';

  @override
  String policeHintPossession(String province, String days) {
    return '$province: کرایہ دار کو جگہ ملنے کے $days کے اندر ہر کرایہ داری کی پولیس رجسٹریشن کروائیں۔';
  }

  @override
  String policeHintAgreement(String province, String days) {
    return '$province: کرایہ نامے پر دستخط کے $days کے اندر ہر کرایہ داری کی پولیس رجسٹریشن کروائیں۔';
  }

  @override
  String policeHintReminder(String province) {
    return '$province: ہمیں ایسا کوئی قانون نہیں ملا جو آخری تاریخ دے۔ کرایہ دار کو جگہ ملنے کے ایک دن بعد ایپ آپ کو ہر کرایہ داری کی پولیس رجسٹریشن یاد دلاتی ہے۔ یہ صرف ایپ کی یاد دہانی ہے۔';
  }

  @override
  String get areaUnitMarla => 'مرلہ';

  @override
  String get areaUnitKanal => 'کنال';

  @override
  String get areaUnitSquareFeet => 'مربع فٹ';

  @override
  String get areaUnitSquareYards => 'مربع گز';

  @override
  String get areaUnitSquareMetres => 'مربع میٹر';

  @override
  String get areaUnitAcre => 'ایکڑ';

  @override
  String areaValue(String size, String unit) {
    return '$size $unit';
  }

  @override
  String coveredAreaValue(String area) {
    return '$area مربع فٹ';
  }

  @override
  String get unitTypeEntireProperty => 'پوری جائیداد';

  @override
  String get unitTypePortion => 'پورشن';

  @override
  String get unitTypeApartment => 'فلیٹ';

  @override
  String get unitTypeRoom => 'کمرہ';

  @override
  String get unitTypeBed => 'بستر';

  @override
  String get unitTypeShop => 'دکان';

  @override
  String get unitTypeOffice => 'دفتر';

  @override
  String get unitTypeFloor => 'منزل';

  @override
  String get unitTypeWarehouse => 'گودام';

  @override
  String get occupancyOccupied => 'کرائے پر';

  @override
  String get occupancyUpcoming => 'کرایہ داری جلد شروع ہو گی';

  @override
  String get occupancyVacant => 'خالی';

  @override
  String occupancyVacantSince(String date) {
    return '$date سے خالی';
  }

  @override
  String get occupancyUnavailable => 'دستیاب نہیں';

  @override
  String get occupancyArchived => 'آرکائیو میں';

  @override
  String get occupancyUnknown => 'معلوم نہیں';

  @override
  String get addPropertyAction => 'جائیداد شامل کریں';

  @override
  String get propertiesEmptyTitle => 'ابھی کوئی جائیداد نہیں';

  @override
  String get propertiesEmptyBody =>
      'کوئی مکان، پلازہ یا پلاٹ شامل کریں، پھر اس کے وہ پورشن، فلیٹ یا دکانیں جو آپ کرائے پر دیتے ہیں۔';

  @override
  String get archivedPropertiesEmpty => 'آرکائیو میں کوئی جائیداد نہیں۔';

  @override
  String get archivedPropertiesEmptyBody =>
      'آپ جو جائیدادیں آرکائیو کریں، وہ اپنے پورے ریکارڈ سمیت یہاں رہتی ہیں۔';

  @override
  String get filterInUse => 'استعمال میں';

  @override
  String get filterArchived => 'آرکائیو';

  @override
  String get loadMoreAction => 'مزید دکھائیں';

  @override
  String get propertiesLoadFailedTitle => 'جائیدادیں لوڈ نہیں ہو سکیں';

  @override
  String get loadingProperties => 'جائیدادیں لوڈ ہو رہی ہیں';

  @override
  String listDetail(String first, String second) {
    return '$first · $second';
  }

  @override
  String get newPropertyTitle => 'نئی جائیداد';

  @override
  String get editPropertyTitle => 'جائیداد کی تفصیل بدلیں';

  @override
  String get propertySectionBasics => 'جائیداد';

  @override
  String get propertySectionLocation => 'یہ کہاں ہے';

  @override
  String get propertySectionSize => 'رقبہ';

  @override
  String get propertySectionValue => 'قیمت';

  @override
  String get propertyNameLabel => 'نام';

  @override
  String get propertyNameHelper =>
      'جس نام سے آپ اسے بلاتے ہیں، جیسے گلبرگ والا مکان یا صدر کی دکانیں۔';

  @override
  String get typeLabel => 'قسم';

  @override
  String get addressLabel => 'پتہ';

  @override
  String get localityLabel => 'علاقہ یا سوسائٹی';

  @override
  String get cityLabel => 'شہر';

  @override
  String get provinceLabel => 'صوبہ';

  @override
  String get provinceHelper =>
      'اسی سے پتہ چلتا ہے کون سے قانون اور اصول لاگو ہیں، جیسے پولیس رجسٹریشن۔';

  @override
  String get plotSizeLabel => 'پلاٹ کا رقبہ';

  @override
  String get plotUnitLabel => 'رقبہ کس میں';

  @override
  String get coveredAreaLabel => 'کورڈ ایریا، بنا ہوا رقبہ (مربع فٹ)';

  @override
  String get yearBuiltLabel => 'کس سال بنی';

  @override
  String get purchasePriceLabel => 'خریدنے کی قیمت';

  @override
  String get purchasedOnLabel => 'کب خریدی';

  @override
  String get estimatedValueLabel => 'اندازاً قیمت';

  @override
  String get valueEstimatedOnLabel => 'قیمت کا اندازہ کب لگایا';

  @override
  String get propertyTaxRefLabel => 'پراپرٹی ٹیکس نمبر';

  @override
  String get notesLabel => 'نوٹس';

  @override
  String get validationPositiveNumber =>
      '0 سے بڑا نمبر لکھیں، پوائنٹ کے بعد زیادہ سے زیادہ دو ہندسے۔';

  @override
  String get validationPlotUnit => 'رقبہ کس میں ہے، یہ چنیں۔';

  @override
  String get validationAmount => '25,000 جیسی رقم لکھیں۔';

  @override
  String propertyAdded(String name) {
    return '$name شامل ہو گئی۔';
  }

  @override
  String propertySaved(String name) {
    return '$name محفوظ ہو گئی۔';
  }

  @override
  String get propertyDetailsSection => 'تفصیلات';

  @override
  String get unitsSection => 'یونٹس';

  @override
  String get unitsSectionHelp =>
      'وہ پورشن، فلیٹ، کمرے یا دکانیں جو آپ کرائے پر دیتے ہیں۔';

  @override
  String get addUnitAction => 'یونٹ شامل کریں';

  @override
  String get unitsEmpty =>
      'ابھی کوئی یونٹ نہیں۔ ہر وہ حصہ شامل کریں جو آپ کرائے پر دیتے ہیں، چاہے وہ پوری جائیداد ہی ہو۔';

  @override
  String get editAction => 'ایڈٹ کریں';

  @override
  String get archiveAction => 'آرکائیو کریں';

  @override
  String get restoreAction => 'آرکائیو سے واپس لائیں';

  @override
  String get deleteAction => 'ڈیلیٹ کریں';

  @override
  String archivedBanner(String date) {
    return '$date کو آرکائیو کیا گیا۔ اس کا ریکارڈ محفوظ ہے۔ کچھ بدلنے کے لیے اسے آرکائیو سے واپس لائیں۔';
  }

  @override
  String archivePropertyTitle(String name) {
    return '$name آرکائیو کریں؟';
  }

  @override
  String get archivePropertyBody =>
      'یہ آپ کی فہرستوں سے ہٹ جائے گی، لیکن اس کے یونٹ، کرایہ داریاں اور رقمیں محفوظ رہیں گی۔ آپ اسے بعد میں آرکائیو سے واپس لا سکتے ہیں۔';

  @override
  String propertyArchived(String name) {
    return '$name آرکائیو ہو گئی۔';
  }

  @override
  String propertyRestored(String name) {
    return '$name آرکائیو سے واپس آ گئی۔';
  }

  @override
  String deletePropertyTitle(String name) {
    return '$name ڈیلیٹ کریں؟';
  }

  @override
  String get deletePropertyBody =>
      'یہ اپنے یونٹس سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گی۔ صرف تب کریں جب یہ جائیداد غلطی سے شامل ہوئی ہو۔ جس جائیداد کی کرایہ داریاں یا خرچے ہوں وہ ڈیلیٹ نہیں ہو سکتی۔ اسے آرکائیو کریں۔';

  @override
  String typeToConfirm(String name) {
    return 'تصدیق کے لیے $name لکھیں';
  }

  @override
  String propertyDeleted(String name) {
    return '$name ڈیلیٹ ہو گئی۔';
  }

  @override
  String get propertyLoadFailedTitle => 'یہ جائیداد لوڈ نہیں ہو سکی';

  @override
  String get loadingProperty => 'جائیداد لوڈ ہو رہی ہے';

  @override
  String get unitsLoadFailedTitle => 'یونٹس لوڈ نہیں ہو سکے';

  @override
  String get reasonDuplicatePropertyName =>
      'استعمال میں موجود ایک اور جائیداد کا یہی نام ہے۔ کوئی اور نام رکھیں۔';

  @override
  String get reasonDuplicateUnitLabel =>
      'اس جائیداد کے ایک اور یونٹ کا یہی نام ہے۔ کوئی اور نام رکھیں۔';

  @override
  String get reasonStillInUse =>
      'کوئی کرایہ داری یا خرچ ابھی اس سے جڑا ہے، اس لیے یہ ڈیلیٹ نہیں ہو سکتا۔ اس کے بجائے اسے آرکائیو کریں۔';

  @override
  String get newUnitTitle => 'نیا یونٹ';

  @override
  String get editUnitTitle => 'یونٹ کی تفصیل بدلیں';

  @override
  String get unitLabelLabel => 'نام یا نمبر';

  @override
  String get unitLabelHelper => 'جیسے گراؤنڈ فلور، فلیٹ 2 یا دکان 5۔';

  @override
  String get floorLabel => 'منزل';

  @override
  String get bedroomsLabel => 'سونے کے کمرے';

  @override
  String get bathroomsLabel => 'باتھ روم';

  @override
  String get fewerAction => 'کم';

  @override
  String get moreAction => 'زیادہ';

  @override
  String get furnishedLabel => 'فرنیچر سمیت';

  @override
  String get unfurnishedValue => 'بغیر فرنیچر';

  @override
  String get askingRentLabel => 'کتنا کرایہ مانگ رہے ہیں';

  @override
  String get askingRentHelper =>
      'آپ ہر مہینے اس کا کتنا کرایہ مانگتے ہیں۔ پراپرٹی ڈیلر اسے ڈیمانڈ کہتے ہیں۔';

  @override
  String askingRentValue(String rent) {
    return 'ڈیمانڈ: $rent';
  }

  @override
  String get availableLabel => 'کرائے کے لیے دستیاب';

  @override
  String get availableHelp =>
      'مرمت کے دوران یا جب آپ خود اس میں رہیں تو بند کر دیں۔';

  @override
  String get unitPropertyLabel => 'جائیداد';

  @override
  String get occupancyLabel => 'کرائے کا اسٹیٹس';

  @override
  String unitAdded(String name) {
    return '$name شامل ہو گیا۔';
  }

  @override
  String unitSaved(String name) {
    return '$name محفوظ ہو گیا۔';
  }

  @override
  String archiveUnitTitle(String name) {
    return '$name آرکائیو کریں؟';
  }

  @override
  String get archiveUnitBody =>
      'یہ آپ کی فہرستوں سے ہٹ جائے گا، لیکن اس کی کرایہ داریاں اور رقمیں محفوظ رہیں گی۔ جو یونٹ ابھی کرائے پر ہے، وہ بھی آرکائیو ہو سکتا ہے۔ اگر اس کی کرایہ داری ختم ہو چکی ہے تو پہلے اسے ختم کریں۔';

  @override
  String unitArchived(String name) {
    return '$name آرکائیو ہو گیا۔';
  }

  @override
  String unitRestored(String name) {
    return '$name آرکائیو سے واپس آ گیا۔';
  }

  @override
  String deleteUnitTitle(String name) {
    return '$name ڈیلیٹ کریں؟';
  }

  @override
  String get deleteUnitBody =>
      'یہ ہمیشہ کے لیے ڈیلیٹ ہو جائے گا۔ صرف تب کریں جب یہ یونٹ غلطی سے شامل ہوا ہو۔ جس یونٹ کی کرایہ داریاں یا خرچے ہوں وہ ڈیلیٹ نہیں ہو سکتا۔ اسے آرکائیو کریں۔';

  @override
  String unitDeleted(String name) {
    return '$name ڈیلیٹ ہو گیا۔';
  }

  @override
  String get unitLoadFailedTitle => 'یہ یونٹ لوڈ نہیں ہو سکا';

  @override
  String get loadingUnit => 'یونٹ لوڈ ہو رہا ہے';

  @override
  String roomCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '1',
      zero: 'کوئی نہیں',
    );
    return '$_temp0';
  }

  @override
  String get tenantKindIndividual => 'شخص';

  @override
  String get tenantKindCompany => 'کمپنی';

  @override
  String get tenantKindGovernment => 'سرکاری ادارہ';

  @override
  String get guardianSonOf => 'ولد';

  @override
  String get guardianDaughterOf => 'دختر';

  @override
  String get guardianWifeOf => 'زوجہ';

  @override
  String guardianLine(String relation, String name) {
    return '$relation $name';
  }

  @override
  String get addTenantAction => 'کرایہ دار شامل کریں';

  @override
  String get searchTenantsHint => 'نام، فون یا شناختی کارڈ سے تلاش';

  @override
  String get tenantsEmptyTitle => 'ابھی کوئی کرایہ دار نہیں';

  @override
  String get tenantsEmptyBody =>
      'وہ لوگ یا کاروبار شامل کریں جو آپ سے کرائے پر لیتے ہیں۔ پھر کسی یونٹ سے ان کی کرایہ داری شروع کریں۔';

  @override
  String get archivedTenantsEmpty => 'آرکائیو میں کوئی کرایہ دار نہیں۔';

  @override
  String get archivedTenantsEmptyBody =>
      'آپ جو کرایہ دار آرکائیو کریں، وہ اپنے پورے ریکارڈ سمیت یہاں رہتے ہیں۔';

  @override
  String noTenantMatches(String search) {
    return '$search سے کوئی کرایہ دار نہیں ملا۔';
  }

  @override
  String get tenantsLoadFailedTitle => 'کرایہ دار لوڈ نہیں ہو سکے';

  @override
  String get loadingTenants => 'کرایہ دار لوڈ ہو رہے ہیں';

  @override
  String get tenantLoadFailedTitle => 'یہ کرایہ دار لوڈ نہیں ہو سکا';

  @override
  String get loadingTenant => 'کرایہ دار لوڈ ہو رہا ہے';

  @override
  String get newTenantTitle => 'نیا کرایہ دار';

  @override
  String get editTenantTitle => 'کرایہ دار کی تفصیل بدلیں';

  @override
  String get tenantSectionWho => 'یہ کون ہیں';

  @override
  String get tenantSectionIdentity => 'شناخت';

  @override
  String get tenantSectionContact => 'رابطہ';

  @override
  String get tenantSectionWork => 'کام اور پتے';

  @override
  String get tenantSectionEmergency => 'ایمرجنسی رابطہ';

  @override
  String get tenantSectionReferences => 'حوالے';

  @override
  String get tenantSectionHousehold => 'گھرانہ اور ٹیکس';

  @override
  String get tenantSectionConsent => 'رضامندی';

  @override
  String get tenantKindLabel => 'کرایہ دار';

  @override
  String get fullNameTenantLabel => 'پورا نام';

  @override
  String get guardianRelationLabel => 'ولد، دختر یا زوجہ';

  @override
  String get guardianNameLabel => 'والد یا شوہر کا نام';

  @override
  String get cnicLabel => 'شناختی کارڈ نمبر';

  @override
  String get cnicHelper => 'کارڈ پر لکھے 13 ہندسے۔';

  @override
  String get validationCnic =>
      'شناختی کارڈ کے 13 ہندسے لکھیں، جیسے 35202-1234567-1۔';

  @override
  String get cnicExpiryLabel => 'شناختی کارڈ ایکسپائر ہونے کی تاریخ';

  @override
  String get cnicExpired => 'شناختی کارڈ ایکسپائر ہو چکا';

  @override
  String get ntnLabel => 'این ٹی این';

  @override
  String get validationNtn =>
      'این ٹی این ویسا ہی لکھیں جیسا جاری ہوا: 6 سے 15 حروف، ہندسے یا ڈیش۔';

  @override
  String get altPhoneLabel => 'دوسرا فون';

  @override
  String get occupationLabel => 'کیا کام کرتے ہیں';

  @override
  String get employerLabel => 'کہاں کام کرتے ہیں';

  @override
  String get permanentAddressLabel => 'مستقل پتہ';

  @override
  String get previousAddressLabel => 'پچھلا پتہ';

  @override
  String get contactNameLabel => 'نام';

  @override
  String get contactRelationLabel => 'رشتہ';

  @override
  String referenceLabel(int number) {
    return 'حوالہ $number';
  }

  @override
  String get householdSizeLabel => 'کتنے لوگ رہتے ہیں';

  @override
  String get withholdingTaxLabel => 'ود ہولڈنگ ٹیکس کاٹتے ہیں';

  @override
  String get withholdingTaxHelp =>
      'کمپنیاں اور سرکاری ادارے جو کرایہ دیتے ہیں، اس میں سے دفعہ 155 کے تحت ٹیکس کاٹتے ہیں۔';

  @override
  String get consentLabel =>
      'میں نے کرایہ دار کو بتایا کہ کون سی تفصیلات رکھی جاتی ہیں اور کیوں';

  @override
  String get consentNoteLabel => 'انہوں نے کس بات پر رضامندی دی';

  @override
  String consentRecorded(String date) {
    return 'رضامندی $date کو درج ہوئی';
  }

  @override
  String get consentMissing => 'رضامندی درج نہیں';

  @override
  String tenantAdded(String name) {
    return '$name شامل ہو گئے۔';
  }

  @override
  String tenantSaved(String name) {
    return '$name کی تفصیلات محفوظ ہو گئیں۔';
  }

  @override
  String get duplicateTenantTitle => 'کیا یہ وہی کرایہ دار ہیں؟';

  @override
  String duplicateTenantBody(String names) {
    return '$names کا بھی یہی شناختی کارڈ یا فون نمبر ہے۔ پھر بھی محفوظ کریں؟';
  }

  @override
  String get saveAnywayAction => 'پھر بھی محفوظ کریں';

  @override
  String get reasonDuplicateCnic =>
      'استعمال میں موجود ایک اور کرایہ دار کا یہی شناختی کارڈ نمبر ہے۔';

  @override
  String get tenantDetailsSection => 'تفصیلات';

  @override
  String get tenantTenanciesSection => 'کرایہ داریاں';

  @override
  String archiveTenantTitle(String name) {
    return '$name کو آرکائیو کریں؟';
  }

  @override
  String get archiveTenantBody =>
      'یہ آپ کی فہرستوں سے ہٹ جائیں گے، لیکن ان کی کرایہ داریاں، ادائیگیاں اور رسیدیں محفوظ رہیں گی۔ آپ انہیں بعد میں آرکائیو سے واپس لا سکتے ہیں۔';

  @override
  String tenantArchived(String name) {
    return '$name آرکائیو ہو گئے۔';
  }

  @override
  String tenantRestored(String name) {
    return '$name آرکائیو سے واپس آ گئے۔';
  }

  @override
  String deleteTenantTitle(String name) {
    return '$name کو ڈیلیٹ کریں؟';
  }

  @override
  String get deleteTenantBody =>
      'ان کی تفصیلات ہمیشہ کے لیے ڈیلیٹ ہو جائیں گی۔ صرف تب کریں جب یہ کرایہ دار غلطی سے شامل ہوئے ہوں۔ جس کرایہ دار کی کرایہ داری ہو، وہ ڈیلیٹ نہیں ہو سکتے۔ انہیں آرکائیو کریں۔';

  @override
  String tenantDeleted(String name) {
    return '$name ڈیلیٹ ہو گئے۔';
  }

  @override
  String get emailOptionalLabel => 'ای میل';

  @override
  String referenceNameLabel(int number) {
    return 'حوالہ $number: نام';
  }

  @override
  String referencePhoneLabel(int number) {
    return 'حوالہ $number: فون';
  }

  @override
  String get tenancyTitle => 'کرایہ داری';

  @override
  String get newTenancyTitle => 'نئی کرایہ داری';

  @override
  String get editTenancyTitle => 'کرایہ داری کی شرائط بدلیں';

  @override
  String get startTenancyAction => 'کرایہ داری شروع کریں';

  @override
  String get leaseActive => 'جاری';

  @override
  String get leaseEnded => 'ختم';

  @override
  String leaseUpcoming(String date) {
    return '$date سے شروع';
  }

  @override
  String unitAtProperty(String unit, String property) {
    return '$unit، $property';
  }

  @override
  String get tenantLabel => 'کرایہ دار';

  @override
  String get unitLabel => 'یونٹ';

  @override
  String get validationChooseTenant => 'کرایہ دار چنیں۔';

  @override
  String get noTenantsToChoose =>
      'پہلے کرایہ دار شامل کریں۔ ابھی چننے کے لیے کوئی کرایہ دار نہیں۔';

  @override
  String get leaseSectionWho => 'کون اور کہاں';

  @override
  String get leaseSectionTerm => 'مدت';

  @override
  String get leaseSectionRent => 'کرایہ اور سیکیورٹی ڈپازٹ';

  @override
  String get leaseSectionLateFee => 'لیٹ فیس';

  @override
  String get leaseSectionAgreement => 'کرایہ نامہ';

  @override
  String get leaseSectionPolice => 'پولیس رجسٹریشن';

  @override
  String get leaseSectionOther => 'دوسری شرائط';

  @override
  String get moveInLabel => 'جگہ ملنے کی تاریخ';

  @override
  String get termLabel => 'مدت';

  @override
  String get term11 => '11 مہینے';

  @override
  String get term12 => '12 مہینے';

  @override
  String get termCustom => 'کسی تاریخ تک';

  @override
  String get termPeriodic => 'مدت طے نہیں (مہینہ وار)';

  @override
  String get endsOnLabel => 'کرایہ داری کب تک طے ہے';

  @override
  String get validationEndAfterStart =>
      'جگہ ملنے کی تاریخ یا اس کے بعد کی تاریخ چنیں۔';

  @override
  String get monthlyRentLabel => 'ماہانہ کرایہ';

  @override
  String get validationRent => 'کرایہ لکھیں، 0 سے زیادہ رقم۔';

  @override
  String get depositLabel => 'سیکیورٹی';

  @override
  String get incrementEveryLabel => 'ہر کتنے مہینے بعد اضافہ';

  @override
  String get lateFeeLabel => 'لیٹ فیس';

  @override
  String get lateFeeNone => 'کوئی نہیں';

  @override
  String get lateFeeFlat => 'فکس رقم';

  @override
  String get lateFeePercent => 'لیٹ کرائے کا فیصد';

  @override
  String get lateFeeDaily => 'ہر لیٹ دن پر رقم';

  @override
  String get lateFeeAmountLabel => 'فیس';

  @override
  String get lateFeePercentLabel => 'فیس (%)';

  @override
  String get lateFeeCapLabel => 'زیادہ سے زیادہ';

  @override
  String get lateFeeHelp => 'تاریخ کے بعد اوپر لکھے دن گزرنے پر لگتی ہے۔';

  @override
  String get noticeDaysLabel => 'نوٹس کی مدت (دن)';

  @override
  String get prorateLabel => 'پہلے مہینے کا کرایہ دنوں کے حساب سے';

  @override
  String get prorateHelp =>
      'جب کرایہ دار کو جگہ مہینے کی پہلی تاریخ کے بعد ملے۔';

  @override
  String get billingStartsLabel => 'کرایہ کب سے شروع ہو';

  @override
  String get billingStartsHelp =>
      'یہ اس کرایہ داری کے لیے ہے جو ایپ سے پہلے شروع ہوئی تھی۔ وہ پہلا دن چنیں جس سے ایپ کرایہ لگائے۔';

  @override
  String get agreementSignedLabel => 'کرایہ نامے پر دستخط کی تاریخ';

  @override
  String get eStampNumberLabel => 'ای اسٹامپ نمبر';

  @override
  String get eStampAmountLabel => 'ای اسٹامپ کی رقم';

  @override
  String get permittedUseLabel => 'کس استعمال کی اجازت ہے';

  @override
  String get sublettingLabel => 'آگے کرائے پر دینے کی اجازت';

  @override
  String get registrarStatusLabel => 'رینٹ رجسٹرار (پنجاب)';

  @override
  String get registrarNotApplicable => 'لاگو نہیں';

  @override
  String get registrarNotPresented => 'پیش نہیں کیا';

  @override
  String get registrarPresented => 'پیش کر دیا';

  @override
  String get registrarRegistered => 'رجسٹرڈ';

  @override
  String get registrarOfficeLabel => 'رجسٹرار کا دفتر';

  @override
  String get registrationNumberLabel => 'رجسٹریشن نمبر';

  @override
  String get registeredOnLabel => 'رجسٹریشن کی تاریخ';

  @override
  String get policeStatusLabel => 'اسٹیٹس';

  @override
  String get policeNotRequired => 'ضروری نہیں';

  @override
  String get policePending => 'ابھی نہیں ہوئی';

  @override
  String get policeSubmitted => 'جمع کرا دیا';

  @override
  String get policeChannelLabel => 'کس ذریعے سے';

  @override
  String get channelOnlinePortal => 'آن لائن پورٹل';

  @override
  String get channelKhidmatMarkaz => 'خدمت مرکز';

  @override
  String get channelPoliceStation => 'تھانہ';

  @override
  String get policeStationLabel => 'تھانہ';

  @override
  String get policeReferenceLabel => 'حوالہ نمبر';

  @override
  String get policeFeeLabel => 'کتنی فیس دی';

  @override
  String policeLegalDeadline(String date) {
    return 'قانون کی آخری تاریخ: $date';
  }

  @override
  String policeReminderDate(String date) {
    return 'ایپ کی یاد دہانی: $date';
  }

  @override
  String get policeReminderNote =>
      'ہمیں ایسا کوئی قانون نہیں ملا جو یہاں آخری تاریخ دے۔ یہ صرف ایپ کی یاد دہانی ہے۔';

  @override
  String get policeLate => 'آخری تاریخ گزر چکی۔ ابھی پولیس رجسٹریشن کروائیں۔';

  @override
  String get openPortalAction => 'رجسٹریشن کی ویب سائٹ کھولیں';

  @override
  String get utilitiesNoteLabel => 'بل';

  @override
  String tenancyStarted(String tenant) {
    return '$tenant کی کرایہ داری شروع ہو گئی۔';
  }

  @override
  String get tenancySaved => 'کرایہ داری کی شرائط محفوظ ہو گئیں۔';

  @override
  String get reasonLeaseOverlap =>
      'ان تاریخوں میں یونٹ پہلے سے کرائے پر ہے۔ پہلے دوسری کرایہ داری ختم کریں، یا دوسری تاریخیں چنیں۔';

  @override
  String get tenancyTermsSection => 'شرائط';

  @override
  String dueDayValue(int day) {
    return 'ہر مہینے کی $day تاریخ';
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
      other: '$months مہینے',
      one: 'مہینے',
    );
    return '$percent% ہر $_temp0';
  }

  @override
  String get periodicValue => 'مدت طے نہیں (مہینہ وار)';

  @override
  String get occupantsSection => 'ساتھ رہنے والے';

  @override
  String get occupantsHelp =>
      'کرایہ دار کے ساتھ رہنے والے بالغ لوگ۔ پولیس رجسٹریشن کے لیے ضروری۔';

  @override
  String get addOccupantAction => 'شخص شامل کریں';

  @override
  String get occupantTitle => 'ساتھ رہنے والا شخص';

  @override
  String occupantSaved(String name) {
    return '$name محفوظ ہو گئے۔';
  }

  @override
  String get removeAction => 'ہٹائیں';

  @override
  String removeOccupantTitle(String name) {
    return '$name کو ہٹائیں؟';
  }

  @override
  String get removeOccupantBody => 'وہ اس کرایہ داری سے ہٹ جائیں گے۔';

  @override
  String get noOccupants => 'ابھی کوئی شامل نہیں۔';

  @override
  String get rentHistorySection => 'کرائے میں تبدیلیاں';

  @override
  String rentFrom(String month) {
    return '$month سے';
  }

  @override
  String get rentReasonInitial => 'شروع کا کرایہ';

  @override
  String get rentReasonAnnualIncrement => 'سالانہ اضافہ';

  @override
  String get rentReasonRenegotiation => 'دونوں کی مرضی سے نیا کرایہ';

  @override
  String get rentReasonCorrection => 'غلطی ٹھیک کی';

  @override
  String get changeRentAction => 'کرایہ بدلیں';

  @override
  String get changeRentFromLabel => 'اس مہینے سے';

  @override
  String get newRentLabel => 'نیا ماہانہ کرایہ';

  @override
  String get changeReasonLabel => 'وجہ';

  @override
  String get rentNoteLabel => 'نوٹ';

  @override
  String suggestedIncrement(String percent, String rent) {
    return 'طے ہوئے $percent% کے حساب سے، 100 روپے تک گول: $rent';
  }

  @override
  String get useSuggestionAction => 'یہی رکھیں';

  @override
  String get changeRentHelp =>
      'اس مہینے اور بعد کا جو کرایہ ابھی ادا نہیں ہوا وہ نئی رقم پر ہو جائے گا۔ جن مہینوں کا کرایہ ادا ہو چکا، ان کی رقم وہی رہے گی۔';

  @override
  String rentChanged(String rent, String month) {
    return '$month سے کرایہ $rent ہو گیا۔';
  }

  @override
  String get endTenancyAction => 'کرایہ داری ختم کریں';

  @override
  String get movedOutLabel => 'جگہ خالی کرنے کی تاریخ';

  @override
  String get endTermCompleted => 'مدت پوری ہو گئی';

  @override
  String get endTenantMovedOut => 'کرایہ دار چلے گئے';

  @override
  String get endEviction => 'خالی کروایا';

  @override
  String get endMutualAgreement => 'دونوں کی مرضی سے';

  @override
  String get endTenancyExplain =>
      'جگہ خالی کرنے کے مہینے تک کا کرایہ لگے گا۔ اس کے بعد کے ہر مہینے کا کرایہ، اور اس پر خود لگنے والی لیٹ فیس، کینسل ہو جائیں گے، چاہے ادا ہو چکے ہوں یا نہیں۔ ان کے لیے دی گئی رقم اس کرایہ داری کے دوسرے باقی چارجز میں لگ جائے گی۔ جو رقم بچے وہ کرایہ دار کا کریڈٹ رہے گی، واپس کرنے کے لیے۔ یونٹ خالی ہو جائے گا۔';

  @override
  String get tenancyEnded => 'کرایہ داری ختم ہو گئی۔';

  @override
  String get endedOnLabel => 'کب ختم ہوئی';

  @override
  String get deleteTenancyTitle => 'یہ کرایہ داری ڈیلیٹ کریں؟';

  @override
  String get deleteTenancyBody =>
      'یہ کرایہ داری اپنے بنائے ہوئے سب چارجز سمیت ڈیلیٹ ہو جائے گی، اگر ابھی تک کچھ ادا، معاف یا کینسل نہیں ہوا۔ صرف تب کریں جب یہ غلطی سے درج ہوئی ہو۔ ورنہ کرایہ داری ختم کریں۔';

  @override
  String get tenancyDeleted => 'کرایہ داری ڈیلیٹ ہو گئی۔';

  @override
  String get tenancyLoadFailedTitle => 'یہ کرایہ داری لوڈ نہیں ہو سکی';

  @override
  String get loadingTenancy => 'کرایہ داری لوڈ ہو رہی ہے';

  @override
  String get tenanciesEmpty => 'ابھی کوئی کرایہ داری نہیں۔';

  @override
  String get tenanciesLoadFailedTitle => 'کرایہ داریاں لوڈ نہیں ہو سکیں';

  @override
  String monthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مہینے',
      one: '1 مہینہ',
    );
    return '$_temp0';
  }

  @override
  String get fewerMonthsAction => 'کم مہینے';

  @override
  String get moreMonthsAction => 'زیادہ مہینے';

  @override
  String get documentsSection => 'کاغذات اور تصویریں';

  @override
  String get documentsSectionHelp =>
      'تصویریں اور پی ڈی ایف، جنہیں صرف اس پورٹ فولیو کی ٹیم دیکھ سکتی ہے۔';

  @override
  String get addDocumentAction => 'کاغذ یا تصویر شامل کریں';

  @override
  String get documentsEmpty => 'ابھی کوئی کاغذ یا تصویر نہیں۔';

  @override
  String get documentsEmptyTenant =>
      'ابھی کوئی کاغذ یا تصویر نہیں۔ شناختی کارڈ کے سامنے اور پیچھے کی تصویریں شامل کریں۔';

  @override
  String get documentsEmptyLease =>
      'ابھی کوئی کاغذ یا تصویر نہیں۔ دستخط والا کرایہ نامہ اور پولیس رجسٹریشن شامل کریں۔';

  @override
  String get documentsEmptyUnit =>
      'ابھی کوئی کاغذ یا تصویر نہیں۔ یونٹ اور اس کے میٹروں کی تصویریں شامل کریں۔';

  @override
  String get documentsEmptyProperty =>
      'ابھی کوئی کاغذ یا تصویر نہیں۔ جائیداد کے کاغذات اور تصویریں شامل کریں۔';

  @override
  String get loadingDocuments => 'کاغذات لوڈ ہو رہے ہیں';

  @override
  String get documentsLoadFailedTitle => 'کاغذات لوڈ نہیں ہو سکے';

  @override
  String get documentKindCnicFront => 'شناختی کارڈ، سامنے کا رخ';

  @override
  String get documentKindCnicBack => 'شناختی کارڈ، پچھلا رخ';

  @override
  String get documentKindPhoto => 'تصویر';

  @override
  String get documentKindTenancyAgreement => 'کرایہ نامہ';

  @override
  String get documentKindPoliceRegistration => 'پولیس رجسٹریشن';

  @override
  String get documentKindRentRegistration => 'رینٹ رجسٹرار کے پاس رجسٹریشن';

  @override
  String get documentKindUtilityBill => 'بل (بجلی، گیس، پانی، انٹرنیٹ)';

  @override
  String get documentKindReceipt => 'رسید';

  @override
  String get documentKindInvoice => 'انوائس';

  @override
  String get documentKindMeterPhoto => 'میٹر کی تصویر';

  @override
  String get documentKindPropertyPaper => 'جائیداد کے کاغذات';

  @override
  String get documentKindOther => 'دیگر';

  @override
  String get fileTypeJpeg => 'تصویر (JPEG)';

  @override
  String get fileTypePng => 'تصویر (PNG)';

  @override
  String get fileTypeWebp => 'تصویر (WebP)';

  @override
  String get fileTypeHeic => 'تصویر (HEIC)';

  @override
  String get fileTypePdf => 'پی ڈی ایف';

  @override
  String get fileFormatJpeg => 'JPEG';

  @override
  String get fileFormatPng => 'PNG';

  @override
  String get fileFormatWebp => 'WebP';

  @override
  String get fileFormatHeic => 'HEIC';

  @override
  String get fileFormatPdf => 'پی ڈی ایف';

  @override
  String fileSizeKb(String size) {
    return '$size KB';
  }

  @override
  String fileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get takePhotoAction => 'تصویر کھینچیں';

  @override
  String get chooseFileAction => 'فائل چنیں';

  @override
  String get chooseAnotherFileAction => 'کوئی اور فائل چنیں';

  @override
  String get addDocumentHelp =>
      'تصویر، یا ‎10 MB‎ تک کی پی ڈی ایف شامل کریں۔ ایپ تصویروں کو پہلے چھوٹا کر دیتی ہے۔';

  @override
  String get preparingFile => 'فائل تیار ہو رہی ہے';

  @override
  String get photoRecovered =>
      'کیمرہ کھلا تھا کہ ایپ بند ہو گئی، لیکن آپ کی تصویر محفوظ رہی۔ اسے دیکھ لیں، پھر اپ لوڈ کریں۔';

  @override
  String get photoKeptOffer =>
      'کیمرہ کھلا تھا کہ ایپ بند ہو گئی، لیکن آپ کی تصویر محفوظ رہی۔';

  @override
  String get photoKeptAction => 'تصویر دیکھیں';

  @override
  String get documentKindLabel => 'قسم';

  @override
  String get documentNameLabel => 'نام';

  @override
  String get documentNameHelp => 'خالی چھوڑیں تو اس کی قسم ہی اس کا نام ہو گی۔';

  @override
  String get uploadAction => 'اپ لوڈ کریں';

  @override
  String documentCompressed(String from, String to) {
    return '$from سے چھوٹی کر کے $to کر دی گئی۔';
  }

  @override
  String documentAdded(String name) {
    return '$name شامل ہو گئی۔';
  }

  @override
  String documentSaved(String name) {
    return '$name محفوظ ہو گئی۔';
  }

  @override
  String documentDeleted(String name) {
    return '$name ڈیلیٹ ہو گئی۔';
  }

  @override
  String get openDocumentAction => 'کھولیں';

  @override
  String get downloadDocumentAction => 'ڈاؤن لوڈ کریں';

  @override
  String get editDocumentAction => 'نام یا قسم بدلیں';

  @override
  String deleteDocumentTitle(String name) {
    return '$name ڈیلیٹ کریں؟';
  }

  @override
  String get deleteDocumentBody =>
      'یہ فائل اس پورٹ فولیو میں سب کے لیے ڈیلیٹ ہو جائے گی۔ ڈیلیٹ کرنے کے بعد یہ واپس نہیں آئے گی۔';

  @override
  String get documentAddedOnLabel => 'شامل کرنے کی تاریخ';

  @override
  String get documentFileLabel => 'فائل';

  @override
  String get documentPreviewLabel => 'تصویر کی جھلک';

  @override
  String get documentNameTooLong => 'یہ نام بہت لمبا ہے۔ اسے چھوٹا کریں۔';

  @override
  String get reasonFileTooLarge =>
      'یہ فائل ‎10 MB‎ سے بڑی ہے۔ چھوٹی فائل چنیں، یا اس کی تصویر کھینچ لیں۔';

  @override
  String get reasonFileTypeNotAllowed =>
      'صرف تصویریں (JPEG، PNG، WebP یا HEIC) اور پی ڈی ایف شامل ہو سکتی ہیں۔';

  @override
  String get reasonFileUnreadable =>
      'ایپ یہ فائل پڑھ نہیں سکی۔ کوئی اور فائل چنیں، یا کاغذ کی تصویر کھینچ لیں۔';

  @override
  String get reasonPickerAccessDenied =>
      'اس ایپ کو کیمرہ یا آپ کی فائلیں استعمال کرنے کی اجازت نہیں۔ فون کی سیٹنگز میں اجازت دیں۔';

  @override
  String get reasonCameraNotReady =>
      'آپ کا فون تصویر کھینچنے کے لیے تیار نہیں ہو سکا۔ دوبارہ کوشش کریں، یا اس کی جگہ کوئی فائل چنیں۔';

  @override
  String get chargeKindRent => 'کرایہ';

  @override
  String get chargeKindDeposit => 'سیکیورٹی';

  @override
  String get chargeKindElectricity => 'بجلی';

  @override
  String get chargeKindGas => 'گیس';

  @override
  String get chargeKindWater => 'پانی';

  @override
  String get chargeKindInternet => 'انٹرنیٹ';

  @override
  String get chargeKindMaintenance => 'مرمت اور دیکھ بھال';

  @override
  String get chargeKindSociety => 'سوسائٹی چارجز';

  @override
  String get chargeKindLateFee => 'لیٹ فیس';

  @override
  String get chargeKindDamages => 'نقصان';

  @override
  String get chargeKindOther => 'دیگر';

  @override
  String get methodCash => 'نقد';

  @override
  String get methodBankTransfer => 'بینک ٹرانسفر';

  @override
  String get methodRaast => 'راست';

  @override
  String get methodJazzCash => 'جاز کیش';

  @override
  String get methodEasypaisa => 'ایزی پیسہ';

  @override
  String get methodCheque => 'چیک';

  @override
  String get methodCard => 'کارڈ';

  @override
  String get methodDeposit => 'سیکیورٹی میں سے';

  @override
  String get methodOther => 'دیگر';

  @override
  String get methodLabel => 'ادائیگی کا طریقہ';

  @override
  String chargeForMonth(String kind, String month) {
    return '$kind، $month';
  }

  @override
  String overdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن لیٹ',
      one: '1 دن لیٹ',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'آج تاریخ ہے';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن بعد تاریخ',
      one: 'کل تاریخ ہے',
    );
    return '$_temp0';
  }

  @override
  String dueOn(String date) {
    return 'تاریخ: $date';
  }

  @override
  String get chargePaid => 'ادا شدہ';

  @override
  String get chargeWaived => 'معاف';

  @override
  String get chargeVoided => 'کینسل';

  @override
  String get loadingReceivables => 'کس کے ذمے کتنا باقی ہے، لوڈ ہو رہا ہے';

  @override
  String get receivablesLoadFailedTitle => 'باقی رقم لوڈ نہیں ہو سکی';

  @override
  String get receivablesEmptyTitle => 'ابھی کسی کے ذمے کچھ باقی نہیں';

  @override
  String get receivablesEmptyBody =>
      'آپ جو بھی کرایہ داری شروع کریں، اس کا کرایہ خود بخود لگتا ہے۔ کرایہ داروں کے ذمے باقی رقم اور ان کی ادائیگیاں یہاں نظر آئیں گی۔';

  @override
  String get totalOwedLabel => 'باقی رقم';

  @override
  String get totalOverdueLabel => 'لیٹ رقم';

  @override
  String get totalCreditLabel => 'کریڈٹ';

  @override
  String get whoOwesSection => 'کس کے ذمے کتنا باقی ہے';

  @override
  String get whoOwesHelp => 'جو سب سے زیادہ دن لیٹ ہیں، وہ پہلے۔';

  @override
  String get nobodyOwes => 'اس وقت کسی کے ذمے کچھ باقی نہیں۔';

  @override
  String get settledSection => 'حساب صاف یا کریڈٹ میں';

  @override
  String lastPaidOn(String date) {
    return 'آخری ادائیگی $date';
  }

  @override
  String owesAmount(String amount) {
    return 'باقی $amount';
  }

  @override
  String overdueOldest(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن',
      one: '1 دن',
    );
    return '$amount لیٹ، سب سے پرانی رقم $_temp0 سے';
  }

  @override
  String creditAmount(String amount) {
    return 'کریڈٹ $amount';
  }

  @override
  String get allPaid => 'سب ادا';

  @override
  String get cashBookTitle => 'ہاتھ میں نقدی';

  @override
  String get ledgerTitle => 'حساب';

  @override
  String get loadingLedger => 'حساب لوڈ ہو رہا ہے';

  @override
  String get ledgerLoadFailedTitle => 'یہ حساب لوڈ نہیں ہو سکا';

  @override
  String get statementAction => 'کرایہ دار کی اسٹیٹمنٹ';

  @override
  String get owedNowLabel => 'ابھی باقی';

  @override
  String owedNowValue(String amount) {
    return 'ابھی باقی: $amount';
  }

  @override
  String get overdueLabel => 'لیٹ';

  @override
  String get creditLabel => 'کریڈٹ';

  @override
  String get creditWord => 'کریڈٹ';

  @override
  String get lastPaidLabel => 'آخری ادائیگی';

  @override
  String get lastRemindedLabel => 'آخری یاد دہانی';

  @override
  String get creditExplainActive =>
      'کرایہ دار نے رقم پہلے دے دی ہے۔ یہ کریڈٹ اگلے چارجز میں خود بخود لگ جائے گا۔';

  @override
  String get creditExplainEnded =>
      'کرایہ داری ختم ہو چکی ہے اور رقم بچی ہوئی ہے۔ یہ کرایہ دار کو واپس کریں، یا جس ادائیگی سے آئی ہے وہ ادائیگی کینسل کریں۔';

  @override
  String creditHeldEnded(String amount) {
    return 'کرایہ داری ختم ہو چکی ہے، اور کرایہ دار کا $amount کریڈٹ ابھی بچا ہوا ہے۔';
  }

  @override
  String get openCreditPaymentAction => 'ادائیگی کھولیں';

  @override
  String get recordPaymentAction => 'ادائیگی درج کریں';

  @override
  String get remindAction => 'واٹس ایپ پر یاد دلائیں';

  @override
  String get openTenancyAction => 'کرایہ داری کی تفصیلات';

  @override
  String get openDuesSection => 'باقی';

  @override
  String get openDuesHelp => 'ہر چارج جو ابھی ادا نہیں ہوا، سب سے پرانا پہلے۔';

  @override
  String get addChargeAction => 'چارج لگائیں';

  @override
  String get noOpenDues => 'کچھ باقی نہیں۔';

  @override
  String leftOfAmount(String left, String amount) {
    return '$amount میں سے $left باقی';
  }

  @override
  String get paymentsSection => 'ادائیگیاں';

  @override
  String get noPaymentsYet => 'ابھی کوئی ادائیگی نہیں۔';

  @override
  String receiptNumbered(String number) {
    return 'رسید $number';
  }

  @override
  String withTax(String amount) {
    return '$amount ٹیکس کٹا';
  }

  @override
  String get allDuesSection => 'سب چارجز';

  @override
  String get allDuesHelp => 'ادا شدہ، معاف اور کینسل بھی، سب سے نئے پہلے۔';

  @override
  String get noDuesYet => 'ابھی کوئی چارج نہیں۔';

  @override
  String get moneySection => 'حساب';

  @override
  String get openLedgerAction => 'حساب کھولیں';

  @override
  String get amountLabel => 'رقم';

  @override
  String get paidLabel => 'ادا شدہ';

  @override
  String get stillOwedLabel => 'ابھی باقی';

  @override
  String get dueDateLabel => 'دینے کی تاریخ';

  @override
  String get chargeNoteLabel => 'نوٹ';

  @override
  String get waiveReasonLabel => 'معاف کرنے کی وجہ';

  @override
  String get voidReasonLabel => 'کینسل کرنے کی وجہ';

  @override
  String get editChargeAction => 'چارج ایڈٹ کریں';

  @override
  String get waiveChargeAction => 'معاف کریں';

  @override
  String get voidChargeAction => 'چارج کینسل کریں';

  @override
  String get voidChargeHasPayments =>
      'اس چارج کی ادائیگی مل چکی ہے، اس لیے اسے کینسل نہیں کیا جا سکتا۔ پہلے وہ ادائیگی کینسل کریں، یا باقی رقم معاف کریں۔';

  @override
  String get chargeSaved => 'چارج محفوظ ہو گیا۔';

  @override
  String get chargeAmountFixed =>
      'کرایہ، لیٹ فیس اور سیکیورٹی کی رقم کرایہ داری کی شرائط سے طے ہوتی ہے۔ کرایہ بدلیں، یا یہ چارج کینسل کر کے نیا لگائیں۔';

  @override
  String amountAtLeast(String amount) {
    return 'کم از کم $amount، جو پہلے ہی ادا یا معاف ہو چکا۔';
  }

  @override
  String amountAtMost(String amount) {
    return 'زیادہ سے زیادہ $amount۔';
  }

  @override
  String get chargeKindLabel => 'کس چیز کا';

  @override
  String get chargeMonthLabel => 'کس مہینے کا';

  @override
  String get chargeMonthHelp => 'جس مہینے کا بل ہے، اگر ہو۔';

  @override
  String get noMonthOption => 'کوئی مہینہ نہیں';

  @override
  String chargeAdded(String kind) {
    return 'چارج لگ گیا: $kind';
  }

  @override
  String get waiveExplain =>
      'معاف کرنے سے باقی رقم (یا جتنی آپ لکھیں) معاف ہو جاتی ہے۔ چارج حساب میں رہے گا، اس پر معاف لکھا ہو گا اور آپ کی بتائی وجہ بھی۔';

  @override
  String get voidChargeExplain =>
      'کینسل کرنے سے غلطی سے لگا چارج ختم ہو جاتا ہے، اور اس کی لیٹ فیس بھی جو ابھی ادا نہیں ہوئی۔ یہ حساب میں رہے گا، اس پر کینسل لکھا ہو گا اور آپ کی بتائی وجہ بھی۔';

  @override
  String get waiveAmountLabel => 'کتنی رقم معاف کریں';

  @override
  String waiveAmountHelp(String amount) {
    return 'پوری $amount معاف کرنے کے لیے خالی چھوڑ دیں۔';
  }

  @override
  String get reasonLabel => 'وجہ';

  @override
  String get chargeWaivedDone => 'چارج معاف ہو گیا۔';

  @override
  String get chargeVoidedDone => 'چارج کینسل ہو گیا۔';

  @override
  String get depositSection => 'سیکیورٹی';

  @override
  String get depositAgreedLabel => 'طے ہوئی';

  @override
  String get depositReceivedLabel => 'وصول ہوئی';

  @override
  String get depositAppliedLabel => 'باقی رقم میں کاٹی';

  @override
  String get depositRefundedLabel => 'واپس کی';

  @override
  String get depositHeldLabel => 'اب جمع سیکیورٹی';

  @override
  String get depositSettleAfterEnd =>
      'کرایہ داری ختم ہو چکی ہے اور سیکیورٹی ابھی آپ کے پاس ہے۔ اس میں سے کرایہ دار کے ذمے باقی رقم کاٹیں، پھر جو بچے وہ واپس کریں۔';

  @override
  String get depositTenancyActive =>
      'یہ کرایہ داری ابھی جاری ہے۔ سیکیورٹی عام طور پر کرایہ دار کے جانے پر باقی رقم میں کٹتی ہے یا واپس ہوتی ہے۔';

  @override
  String get applyDepositAction => 'باقی رقم سیکیورٹی میں سے کاٹیں';

  @override
  String get refundDepositAction => 'سیکیورٹی واپس کریں';

  @override
  String refundOf(String amount) {
    return '$amount کی واپسی';
  }

  @override
  String voidedBecause(String reason) {
    return 'کینسل: $reason';
  }

  @override
  String get voidRefundAction => 'واپسی کینسل کریں';

  @override
  String get voidRefundExplain =>
      'غلطی سے درج ہوئی واپسی کینسل کرنے سے وہ رقم دوبارہ آپ کے پاس جمع مانی جائے گی۔ یہ واپسی حساب میں رہے گی، اس پر کینسل لکھا ہو گا۔';

  @override
  String get refundVoided => 'واپسی کینسل ہو گئی۔';

  @override
  String get applyDepositExplain =>
      'سیکیورٹی میں سے کرایہ دار کے ذمے باقی رقم ادا ہو گی، سب سے پرانا چارج پہلے۔ کرایہ دار کو اس کی رسید ملے گی۔';

  @override
  String applyDepositHelp(String held, String owed) {
    return 'جمع: $held۔ ذمے باقی: $owed۔';
  }

  @override
  String get appliedOnLabel => 'کاٹنے کی تاریخ';

  @override
  String depositApplied(String amount) {
    return 'سیکیورٹی میں سے $amount باقی رقم میں کٹ گئے۔';
  }

  @override
  String depositHeldHelp(String amount) {
    return 'آپ کے پاس $amount جمع ہیں۔';
  }

  @override
  String get refundedOnLabel => 'واپسی کی تاریخ';

  @override
  String depositRefunded(String amount) {
    return 'سیکیورٹی میں سے $amount واپس ہو گئے۔';
  }

  @override
  String get recordPaymentTitle => 'ادائیگی درج کریں';

  @override
  String get paymentSectionMoney => 'کیا وصول ہوا';

  @override
  String get paymentSectionTax => 'کٹا ہوا ٹیکس';

  @override
  String get paymentSectionSettle => 'یہ کس کی ادائیگی ہے';

  @override
  String get amountReceivedLabel => 'کتنی رقم ملی';

  @override
  String useOwedAction(String amount) {
    return 'باقی $amount لکھیں';
  }

  @override
  String get receivedOnLabel => 'وصولی کی تاریخ';

  @override
  String get paymentReferenceLabel => 'حوالہ نمبر';

  @override
  String get paymentReferenceHelp => 'ٹرانزیکشن آئی ڈی یا چیک نمبر، اگر ہو۔';

  @override
  String get taxWithheldSwitch => 'کرایہ دار نے انکم ٹیکس کاٹا';

  @override
  String get taxWithheldHelp =>
      'کمپنیاں اور سرکاری ادارے دفعہ 155 (سیکشن 155) کے تحت ٹیکس کاٹ کر سرٹیفکیٹ دیتے ہیں۔ نقد رقم اور ٹیکس مل کر کرایہ ادا کرتے ہیں۔';

  @override
  String get taxWithheldLabel => 'کٹا ہوا ٹیکس (دفعہ 155)';

  @override
  String get taxCertificateLabel => 'سرٹیفکیٹ یا سی پی آر نمبر';

  @override
  String taxSettlesGross(String cash, String tax, String total) {
    return '$cash وصول اور $tax کٹا ہوا ٹیکس مل کر $total کے چارجز ادا کرتے ہیں۔';
  }

  @override
  String get noOpenDuesCredit =>
      'اس وقت کچھ باقی نہیں۔ یہ ادائیگی اگلے چارجز کے لیے کریڈٹ کے طور پر محفوظ رہے گی۔';

  @override
  String get settleLabel => 'ادائیگی کس میں لگے';

  @override
  String get settleOldestFirst => 'سب سے پرانے چارج پہلے';

  @override
  String get settleChosen => 'جو چارج میں خود چنوں';

  @override
  String get chooseDuesError => 'کم از کم ایک چارج چنیں۔';

  @override
  String get willSettleHeading => 'یہ ادائیگی ان میں لگے گی';

  @override
  String settledInFull(String charge) {
    return '$charge، پورا';
  }

  @override
  String settledInPart(String charge) {
    return '$charge، کچھ ادا';
  }

  @override
  String get creditKeptLabel => 'کریڈٹ کے طور پر محفوظ';

  @override
  String allCreditExplain(String amount) {
    return 'پوری $amount اگلے چارجز کے لیے کریڈٹ کے طور پر محفوظ رہے گی۔';
  }

  @override
  String lateFeeCancelledNote(String amount) {
    return '$amount کی لیٹ فیس کینسل ہو جائے گی، کیونکہ یہ ادائیگی اس کا پورا کرایہ ان دنوں کے اندر ادا کرتی ہے جن میں لیٹ فیس نہیں لگتی۔';
  }

  @override
  String paymentRecorded(String number) {
    return 'ادائیگی درج ہو گئی۔ رسید $number۔';
  }

  @override
  String get receiptTitle => 'رسید';

  @override
  String get loadingReceipt => 'رسید لوڈ ہو رہی ہے';

  @override
  String get receiptLoadFailedTitle => 'یہ رسید لوڈ نہیں ہو سکی';

  @override
  String get receiptNumberLabel => 'رسید نمبر';

  @override
  String receiptVoidedOn(String date, String reason) {
    return 'کینسل: یہ رسید $date کو کینسل ہوئی۔ $reason';
  }

  @override
  String get receivedFromLabel => 'کس سے وصول ہوا';

  @override
  String get receiptForLabel => 'کس لیے';

  @override
  String get paidByLabel => 'ادائیگی کا طریقہ';

  @override
  String get receiptFooter =>
      'شکریہ۔ یہ رسید اپنے ریکارڈ کے لیے سنبھال کر رکھیں۔';

  @override
  String get shareReceiptAction => 'رسید بھیجیں';

  @override
  String get shareVoidedReceiptAction => 'کینسل ہوئی رسید بھیجیں';

  @override
  String get sendThanksAction => 'واٹس ایپ پر شکریہ';

  @override
  String get voidPaymentAction => 'ادائیگی کینسل کریں';

  @override
  String get voidPaymentExplain =>
      'غلطی سے درج ہوئی ادائیگی کینسل کرنے سے جو چارج اس نے ادا کیے تھے وہ دوبارہ باقی ہو جائیں گے۔ رسید کا نمبر وہی رہے گا، اس پر کینسل لکھا ہو گا اور آپ کی بتائی وجہ بھی۔';

  @override
  String get paymentVoided => 'ادائیگی کینسل ہو گئی۔';

  @override
  String get documentLanguageLabel => 'پی ڈی ایف کی زبان';

  @override
  String get shareDocumentAction => 'پی ڈی ایف بھیجیں';

  @override
  String get receiptDocumentTitle => 'کرائے کی رسید';

  @override
  String get receiptVoid => 'کینسل';

  @override
  String receiptVoidBecause(String reason) {
    return 'کینسل: $reason';
  }

  @override
  String get totalSettledLabel => 'کل رقم، ٹیکس سمیت';

  @override
  String get receiptSettledHeading => 'ادا ہوئے چارجز';

  @override
  String documentMadeOn(String date) {
    return '$date کو مالکِ مکان ایپ سے بنائی گئی۔';
  }

  @override
  String receiptFileTitle(String number) {
    return 'رسید $number';
  }

  @override
  String get statementDocumentTitle => 'کرایہ دار کی اسٹیٹمنٹ';

  @override
  String get statementPeriodLabel => 'مدت';

  @override
  String dateRange(String from, String to) {
    return '$from سے $to تک';
  }

  @override
  String get statementSummaryHeading => 'خلاصہ';

  @override
  String get totalBilledLabel => 'کل چارجز';

  @override
  String get totalPaidLabel => 'ادا شدہ';

  @override
  String get totalWaivedLabel => 'معاف';

  @override
  String get balanceOwedLabel => 'ابھی باقی';

  @override
  String get statementDuesHeading => 'چارجز';

  @override
  String get chargeForLabel => 'کس چیز کا';

  @override
  String get chargeStateLabel => 'اسٹیٹس';

  @override
  String get statementPaymentsHeading => 'ادائیگیاں';

  @override
  String voidedReceipt(String number) {
    return '$number (کینسل)';
  }

  @override
  String statementFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ادائیگیاں وصول ہوئیں۔',
      one: '1 ادائیگی وصول ہوئی۔',
      zero: 'کوئی ادائیگی وصول نہیں ہوئی۔',
    );
    return '$_temp0 ہر رسید نمبر کرایہ دار کی کاپی سے ملایا جا سکتا ہے۔';
  }

  @override
  String statementFileTitle(String tenant) {
    return 'اسٹیٹمنٹ، $tenant';
  }

  @override
  String get reminderTitle => 'واٹس ایپ پر یاد دہانی';

  @override
  String get reminderTemplateLabel => 'پیغام';

  @override
  String get templateUpcoming => 'کرائے کی تاریخ قریب ہے';

  @override
  String get templateDueToday => 'کرائے کی تاریخ آج ہے';

  @override
  String get templateOverdue => 'کرایہ لیٹ';

  @override
  String get templatePaymentReceived => 'ادائیگی مل گئی';

  @override
  String get templateUtilityBill => 'بل';

  @override
  String get reminderLanguageLabel => 'کرایہ دار کی زبان';

  @override
  String get languageRomanUrdu => 'Roman Urdu';

  @override
  String get reminderMessageLabel => 'بھیجنے کے لیے پیغام';

  @override
  String get reminderNoPhone =>
      'اس کرایہ دار کا فون نمبر درج نہیں۔ واٹس ایپ کھلے گا تاکہ آپ خود چیٹ چنیں۔';

  @override
  String reminderTo(String name, String phone) {
    return '$name کو، $phone پر۔';
  }

  @override
  String get sendOnWhatsAppAction => 'واٹس ایپ پر بھیجیں';

  @override
  String get sendAnywayAction => 'پھر بھی بھیجیں';

  @override
  String get copyMessageAction => 'پیغام کاپی کریں';

  @override
  String get messageCopied => 'پیغام کاپی ہو گیا۔';

  @override
  String get reminderLogged => 'یاد دہانی بھیج دی گئی اور حساب میں درج ہو گئی۔';

  @override
  String get noteReminderAction => 'بھیجی گئی یاد دہانیوں میں درج کریں';

  @override
  String etiquetteLateNight(String time) {
    return 'پاکستان میں رات کافی ہو چکی ہے۔ بہتر ہو گا کہ یاد دہانی $time کے بعد بھیجیں۔';
  }

  @override
  String etiquetteFridayPrayer(String time) {
    return 'یہ نمازِ جمعہ کا وقت ہے۔ بہتر ہو گا کہ یاد دہانی $time کے بعد بھیجیں۔';
  }

  @override
  String etiquetteRecent(String moment) {
    return 'اس کرایہ دار کو $moment کو پہلے ہی یاد دہانی جا چکی ہے۔ بہت زیادہ یاد دہانیاں اچھا تعلق خراب کر سکتی ہیں۔';
  }

  @override
  String get remindersSection => 'بھیجی گئی یاد دہانیاں';

  @override
  String get loadingReminders => 'یاد دہانیاں لوڈ ہو رہی ہیں';

  @override
  String get remindersLoadFailedTitle => 'یاد دہانیاں لوڈ نہیں ہو سکیں';

  @override
  String get noRemindersYet => 'ابھی کوئی یاد دہانی نہیں بھیجی گئی۔';

  @override
  String reminderUnit(String unit, String property) {
    return '$unit، $property';
  }

  @override
  String reminderUpcoming(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'السلام علیکم $tenant۔ یاد دہانی: $unit کے $amount، $date کو دینے ہیں۔';
  }

  @override
  String reminderDueToday(String tenant, String amount, String unit) {
    return 'السلام علیکم $tenant۔ $unit کے $amount آج دینے ہیں۔';
  }

  @override
  String reminderOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'السلام علیکم $tenant۔ $unit کے $amount لیٹ ہیں۔ ان میں سب سے پرانی رقم $date کو دینی تھی۔ مہربانی کر کے جلد ادا کر دیں۔';
  }

  @override
  String reminderReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  ) {
    return 'السلام علیکم $tenant۔ $date کو $amount مل گئے۔ رسید نمبر: $receipt۔ شکریہ۔';
  }

  @override
  String reminderUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  ) {
    return 'السلام علیکم $tenant۔ $unit کا $utility $amount ہے، جو $date تک ادا کرنا ہے۔ مہربانی کر کے آخری تاریخ سے پہلے ادا کر دیں۔';
  }

  @override
  String get reminderElectricity => 'بجلی کا بل';

  @override
  String get reminderGas => 'گیس کا بل';

  @override
  String get reminderWater => 'پانی کا بل';

  @override
  String get reminderInternet => 'انٹرنیٹ کا بل';

  @override
  String get reminderUtilityGeneric => 'بل';

  @override
  String reminderPayRaast(String raast) {
    return 'آپ راست کے ذریعے $raast پر ادائیگی کر سکتے ہیں۔';
  }

  @override
  String reminderPayBank(String title, String iban) {
    return 'بینک ٹرانسفر: $title، آئی بی اے این:\n$iban';
  }

  @override
  String reminderThanks(String landlord) {
    return 'والسلام، $landlord';
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
    return 'Assalam-o-Alaikum $tenant. Yaad dihani: $unit ke $amount, $date ko dene hain.';
  }

  @override
  String reminderRomanDueToday(String tenant, String amount, String unit) {
    return 'Assalam-o-Alaikum $tenant. $unit ke $amount aaj dene hain.';
  }

  @override
  String reminderRomanOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. $unit ke $amount late hain. In mein sab se purani raqam $date ko deni thi. Meherbani kar ke jald ada kar dein.';
  }

  @override
  String reminderRomanReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  ) {
    return 'Assalam-o-Alaikum $tenant. $date ko $amount mil gaye. Raseed number: $receipt. Shukriya.';
  }

  @override
  String reminderRomanUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  ) {
    return 'Assalam-o-Alaikum $tenant. $unit ka $utility $amount hai, jo $date tak ada karna hai. Meherbani kar ke aakhri tareekh se pehle ada kar dein.';
  }

  @override
  String get reminderRomanElectricity => 'bijli ka bill';

  @override
  String get reminderRomanGas => 'gas ka bill';

  @override
  String get reminderRomanWater => 'paani ka bill';

  @override
  String get reminderRomanInternet => 'internet ka bill';

  @override
  String get reminderRomanUtilityGeneric => 'bill';

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
  String get loadingCashBook => 'ہاتھ میں نقدی لوڈ ہو رہی ہے';

  @override
  String get cashBookLoadFailedTitle => 'ہاتھ میں نقدی لوڈ نہیں ہو سکی';

  @override
  String get cashInHandSection => 'نقدی کس کے پاس ہے';

  @override
  String get cashInHandHelp =>
      'جتنی نقدی وصول ہوئی، اس میں سے جو آگے دی یا نقد خرچ ہوئی، وہ نکال کر۔';

  @override
  String get noCashYet => 'ابھی کوئی نقدی وصول نہیں ہوئی۔';

  @override
  String get cashCollectedLabel => 'وصول';

  @override
  String get cashHandedOverLabel => 'آگے دی';

  @override
  String get cashSpentLabel => 'خرچ';

  @override
  String get cashInHandLabel => 'پاس موجود';

  @override
  String get handoversSection => 'آگے دی گئی نقدی';

  @override
  String get noHandoversYet => 'ابھی کوئی نقدی آگے نہیں دی گئی۔';

  @override
  String get formerMember => 'سابق ممبر';

  @override
  String handoverFromTo(String from, String to) {
    return '$from سے $to کو';
  }

  @override
  String get handoverConfirmed => 'تصدیق شدہ';

  @override
  String get handoverAwaiting => 'تصدیق کا انتظار';

  @override
  String get handoverTitle => 'نقدی کس کو دی';

  @override
  String get handedOverOnLabel => 'نقدی دینے کی تاریخ';

  @override
  String get confirmHandoverAction => 'تصدیق کریں کہ وصول ہوئی';

  @override
  String get handoverConfirmedDone => 'نقدی ملنے کی تصدیق ہو گئی۔';

  @override
  String get voidHandoverAction => 'نقدی کی انٹری کینسل کریں';

  @override
  String get voidHandoverExplain =>
      'غلطی سے درج ہوئی نقدی کی انٹری کینسل کرنے سے وہ نقدی دینے والے کے پاس ہی مانی جائے گی۔ یہ انٹری فہرست میں رہے گی، اس پر کینسل لکھا ہو گا۔';

  @override
  String get handoverVoided => 'نقدی کی انٹری کینسل ہو گئی۔';

  @override
  String get recordHandoverAction => 'نقدی دینے کی انٹری کریں';

  @override
  String get handoverFromLabel => 'دینے والا';

  @override
  String get handoverToLabel => 'وصول کرنے والا';

  @override
  String get handoverChooseReceiver => 'چنیں کہ نقدی کس نے وصول کی۔';

  @override
  String get handoverRecorded => 'نقدی دینے کی انٹری ہو گئی۔';

  @override
  String get notificationsTitle => 'اطلاعات';

  @override
  String get notificationsSummary =>
      'کرائے کی تاریخیں، ختم ہوتی کرایہ داریاں، پولیس رجسٹریشن';

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نئی',
      one: '1 نئی',
    );
    return '$_temp0';
  }

  @override
  String get loadingNotifications => 'اطلاعات لوڈ ہو رہی ہیں';

  @override
  String get notificationsLoadFailedTitle => 'اطلاعات لوڈ نہیں ہو سکیں';

  @override
  String get notificationsEmptyTitle => 'کوئی اطلاع نہیں';

  @override
  String get notificationsEmptyBody =>
      'ایپ ہر صبح کرائے کی تاریخیں، ختم ہوتی کرایہ داریاں، کرائے میں اضافہ، پولیس رجسٹریشن اور ایکسپائر ہوتے شناختی کارڈ دیکھتی ہے، اور آپ کو یہاں بتاتی ہے۔';

  @override
  String get markAllReadAction => 'سب کو پڑھا ہوا کریں';

  @override
  String get unreadLabel => 'نئی';

  @override
  String get openNotificationAction => 'کھولیں';

  @override
  String get notificationDeleted => 'اطلاع ڈیلیٹ ہو گئی۔';

  @override
  String get notificationRentDueSoon => 'کرائے کی تاریخ قریب ہے';

  @override
  String notificationRentDueSoonBody(
    String tenancy,
    String amount,
    String date,
  ) {
    return '$tenancy: $amount کی تاریخ $date ہے۔';
  }

  @override
  String get notificationRentOverdue => 'کرایہ لیٹ';

  @override
  String notificationRentOverdueBody(
    String tenancy,
    String amount,
    String date,
  ) {
    return '$tenancy: $amount کی تاریخ $date تھی۔';
  }

  @override
  String get notificationLeaseExpiring => 'کرایہ نامہ ختم ہو رہا ہے';

  @override
  String notificationLeaseExpiringBody(String tenancy, String date) {
    return '$tenancy: کرایہ نامہ $date کو ختم ہو گا۔';
  }

  @override
  String get notificationIncrementDue => 'کرایہ بڑھنے کی تاریخ';

  @override
  String notificationIncrementDueBody(
    String tenancy,
    String date,
    String rent,
  ) {
    return '$tenancy: $rent کرائے پر سالانہ اضافہ $date سے لاگو ہونا ہے۔';
  }

  @override
  String get notificationPolicePending => 'پولیس رجسٹریشن ابھی نہیں ہوئی';

  @override
  String notificationPolicePendingBody(String tenancy, String date) {
    return '$tenancy: $date تک کرایہ داری کی پولیس رجسٹریشن کروائیں۔';
  }

  @override
  String get notificationPoliceOverdue => 'پولیس رجسٹریشن لیٹ';

  @override
  String notificationPoliceOverdueBody(String tenancy, String date) {
    return '$tenancy: پولیس رجسٹریشن کی آخری تاریخ $date تھی۔';
  }

  @override
  String notificationPoliceReminderBody(String tenancy, String date) {
    return '$tenancy: پولیس رجسٹریشن کے لیے ایپ کی یاد دہانی $date کو ہے۔ ہمیں ایسا کوئی قانون نہیں ملا جو یہاں آخری تاریخ دے۔';
  }

  @override
  String get notificationCnicExpiring => 'شناختی کارڈ ایکسپائر ہو رہا ہے';

  @override
  String notificationCnicExpiringBody(String tenant, String date) {
    return '$tenant کا شناختی کارڈ $date کو ایکسپائر ہو گا۔';
  }

  @override
  String get notificationUtilityDue => 'بل ادا ہونا ہے';

  @override
  String notificationUtilityDueBody(
    String property,
    String amount,
    String date,
  ) {
    return '$property: $amount کے بل کی آخری تاریخ $date ہے۔';
  }

  @override
  String get notificationInvitationAccepted => 'دعوت قبول ہو گئی';

  @override
  String notificationInvitationAcceptedBody(String email, String role) {
    return '$email شامل ہو گئے۔ رول: $role۔';
  }

  @override
  String get notificationUnknown => 'اطلاع';

  @override
  String get notificationUnknownBody =>
      'یہ اطلاع پڑھنے کے لیے ایپ اپ ڈیٹ کریں۔';

  @override
  String get reasonIdempotencyKeyRequired =>
      'یہ ادائیگی محفوظ طریقے سے نہیں بھیجی جا سکی۔ فارم بند کر کے دوبارہ کھولیں۔';

  @override
  String get reasonRefundUnconfirmed =>
      'رابطہ ٹوٹ گیا، اس لیے ہو سکتا ہے واپسی درج ہو چکی ہو۔ دوبارہ کوشش سے پہلے اسے بند کر کے سیکیورٹی دیکھ لیں۔';

  @override
  String get checkDepositAction => 'بند کر کے سیکیورٹی دیکھیں';

  @override
  String get operationsSection => 'خرچ، بل اور مرمت';

  @override
  String get expensesSummary => 'آپ اپنی جائیدادوں پر کیا خرچ کرتے ہیں';

  @override
  String get utilitiesSummary => 'کنکشن، بل اور میٹر ریڈنگ';

  @override
  String get maintenanceSummary => 'مرمت کے کام، اور ہر کام کہاں تک پہنچا';

  @override
  String get propertyLabel => 'جائیداد';

  @override
  String get wholePortfolioOption => 'پورا پورٹ فولیو';

  @override
  String get wholePropertyOption => 'پوری جائیداد';

  @override
  String get loadingPlaces => 'لوڈ ہو رہا ہے…';

  @override
  String get noTenancyOption => 'کوئی کرایہ داری نہیں';

  @override
  String get noTenanciesHere =>
      'اس کنکشن کی جائیداد یا یونٹ پر کبھی کوئی کرایہ داری شروع نہیں ہوئی۔';

  @override
  String get descriptionLabel => 'تفصیل';

  @override
  String get statusLabel => 'اسٹیٹس';

  @override
  String get yes => 'ہاں';

  @override
  String get no => 'نہیں';

  @override
  String get filterToDo => 'باقی کام';

  @override
  String get filterClosed => 'بند';

  @override
  String get callAction => 'کال کریں';

  @override
  String get callFailed => 'اس فون یا کمپیوٹر پر فون کی ایپ نہیں کھل سکی۔';

  @override
  String get paidOnLabel => 'ادائیگی کی تاریخ';

  @override
  String get expenseCategoryRepairs => 'مرمت اور دیکھ بھال';

  @override
  String get expenseCategoryPropertyTax => 'پراپرٹی ٹیکس';

  @override
  String get expenseCategoryUtilities => 'بل (بجلی، گیس، پانی، انٹرنیٹ)';

  @override
  String get expenseCategorySociety => 'سوسائٹی چارجز';

  @override
  String get expenseCategoryInsurance => 'انشورنس';

  @override
  String get expenseCategoryLegal => 'قانونی اور پروفیشنل فیس (وکیل، اکاؤنٹنٹ)';

  @override
  String get expenseCategoryAgent => 'ایجنٹ کا کمیشن';

  @override
  String get expenseCategorySalaries => 'عملے کی تنخواہیں';

  @override
  String get expenseCategoryCleaning => 'صفائی اور چوکیدار';

  @override
  String get expenseCategoryRenovation => 'رینوویشن (مرمت اور رنگ روغن)';

  @override
  String get expenseCategoryBank => 'بینک چارجز';

  @override
  String get expenseCategoryLoanInterest => 'قرض کا سود';

  @override
  String get expensesTitle => 'خرچ';

  @override
  String get expenseTitle => 'خرچ';

  @override
  String get newExpenseTitle => 'نیا خرچ';

  @override
  String get editExpenseTitle => 'خرچ کی تفصیل بدلیں';

  @override
  String get addExpenseAction => 'خرچ شامل کریں';

  @override
  String get loadingExpenses => 'خرچے لوڈ ہو رہے ہیں';

  @override
  String get loadingExpense => 'خرچ لوڈ ہو رہا ہے';

  @override
  String get expensesLoadFailedTitle => 'خرچے لوڈ نہیں ہو سکے';

  @override
  String get expenseLoadFailedTitle => 'خرچ لوڈ نہیں ہو سکا';

  @override
  String get expensesEmptyTitle => 'ابھی کوئی خرچ نہیں';

  @override
  String get expensesEmptyBody =>
      'مرمت، ٹیکس، تنخواہوں اور دوسرے کاموں پر جو خرچ کریں وہ درج کریں، ہر رسید کی تصویر کے ساتھ۔ اس سے پتہ چلتا ہے کہ ہر جائیداد اصل میں کتنا کماتی ہے۔';

  @override
  String get expenseSectionWhat => 'کیا خرچ ہوا';

  @override
  String get expenseSectionWhere => 'کہاں';

  @override
  String get expenseSectionPaid => 'ادائیگی کیسے ہوئی';

  @override
  String get expenseCategoryLabel => 'کس چیز پر خرچ';

  @override
  String get spentOnLabel => 'خرچ کی تاریخ';

  @override
  String get expensePropertyHelp =>
      'اکاؤنٹنٹ کی فیس جیسے خرچ کے لیے “پورا پورٹ فولیو” چنیں۔';

  @override
  String get maintenanceJobLabel => 'مرمت کا کام';

  @override
  String get maintenanceJobHelp => 'اگر یہ کسی مرمت کے لیے تھا تو وہ کام۔';

  @override
  String get noJobOption => 'کوئی کام نہیں';

  @override
  String get payeeLabel => 'کس کو ادا کیا';

  @override
  String get payeeHelp => 'پلمبر، ایکسائز آفس، کوئی دکان…';

  @override
  String get expenseCashHelp =>
      'نقد خرچ آپ کے ہاتھ میں موجود نقدی سے کم ہو جاتا ہے۔';

  @override
  String expenseForJob(String title) {
    return 'اس کام کے لیے: $title';
  }

  @override
  String get paidForJobLabel => 'اس کام کے لیے ادائیگی';

  @override
  String get expenseAdded => 'خرچ شامل ہو گیا۔';

  @override
  String get expenseSaved => 'خرچ محفوظ ہو گیا۔';

  @override
  String get expenseDeleted => 'خرچ ڈیلیٹ ہو گیا۔';

  @override
  String get deleteExpenseTitle => 'یہ خرچ ڈیلیٹ کریں؟';

  @override
  String get deleteExpenseBody =>
      'یہ اپنی رسیدوں سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گا۔ صرف تب کریں جب یہ خرچ غلطی سے درج ہوا ہو۔';

  @override
  String get providerLesco => 'لیسکو (لاہور)';

  @override
  String get providerIesco => 'آئیسکو (اسلام آباد)';

  @override
  String get providerGepco => 'گیپکو (گوجرانوالہ)';

  @override
  String get providerFesco => 'فیسکو (فیصل آباد)';

  @override
  String get providerMepco => 'میپکو (ملتان)';

  @override
  String get providerPesco => 'پیسکو (پشاور)';

  @override
  String get providerHesco => 'حیسکو (حیدرآباد)';

  @override
  String get providerSepco => 'سیپکو (سکھر)';

  @override
  String get providerQesco => 'کیسکو (کوئٹہ)';

  @override
  String get providerTesco => 'ٹیسکو (قبائلی اضلاع)';

  @override
  String get providerHazeco => 'ہزیکو (ہزارہ)';

  @override
  String get providerKElectric => 'کے الیکٹرک (کراچی)';

  @override
  String get providerSngpl => 'ایس این جی پی ایل (سوئی ناردرن)';

  @override
  String get providerSsgc => 'ایس ایس جی سی (سوئی سدرن)';

  @override
  String get providerWasa => 'واسا';

  @override
  String get providerKwsc => 'کراچی واٹر (KW&SC)';

  @override
  String get providerCda => 'سی ڈی اے (اسلام آباد)';

  @override
  String get providerPtcl => 'پی ٹی سی ایل';

  @override
  String get responsibilityTenant => 'کرایہ دار';

  @override
  String get responsibilityLandlord => 'آپ';

  @override
  String get responsibilityShared => 'مشترکہ';

  @override
  String get billPaidByTenant => 'کرایہ دار';

  @override
  String get billPaidByLandlord => 'آپ';

  @override
  String get readingMoveIn => 'کرایہ دار کے آنے پر';

  @override
  String get readingMoveOut => 'کرایہ دار کے جانے پر';

  @override
  String get readingMonthly => 'ماہانہ';

  @override
  String get utilitiesTitle => 'بل اور کنکشن';

  @override
  String get loadingUtilities => 'بل اور کنکشن لوڈ ہو رہے ہیں';

  @override
  String get utilitiesLoadFailedTitle => 'بل اور کنکشن لوڈ نہیں ہو سکے';

  @override
  String get unpaidBillsSection => 'جو بل ادا کرنے ہیں';

  @override
  String get unpaidBillsHelp =>
      'جو بل ادا نہیں ہوئے، جس کی آخری تاریخ پہلے ہے وہ پہلے۔';

  @override
  String get noUnpaidBills => 'کوئی بل باقی نہیں۔';

  @override
  String landlordNameOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'آپ کے نام کے کنکشنوں کے $count بل لیٹ ہیں۔ بقایا جگہ اور کنکشن کے ساتھ رہتا ہے، اس لیے یہ آپ پر آ سکتا ہے۔',
      one: 'آپ کے نام کے ایک کنکشن کا بل لیٹ ہے۔ بقایا جگہ اور کنکشن کے ساتھ رہتا ہے، اس لیے یہ آپ پر آ سکتا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get connectionsSection => 'کنکشن';

  @override
  String get connectionsHelp =>
      'بجلی، گیس، پانی اور انٹرنیٹ، ہر جائیداد یا یونٹ کے لیے۔';

  @override
  String get connectionsEmptyTitle => 'ابھی کوئی کنکشن نہیں';

  @override
  String get connectionsEmptyBody =>
      'ہر میٹر اس کے ریفرنس نمبر کے ساتھ شامل کریں، اور یہ بھی کہ وہ کس کے نام پر ہے۔ جو بل ادا نہ ہوں وہ جگہ کے ساتھ رہتے ہیں، اس لیے ان پر یہاں نظر رکھیں۔';

  @override
  String get archivedConnectionsEmpty => 'آرکائیو میں کوئی کنکشن نہیں۔';

  @override
  String get archivedConnectionsEmptyBody =>
      'آپ جو کنکشن آرکائیو کریں، وہ اپنے بلوں اور ریڈنگز سمیت یہاں رہتے ہیں۔';

  @override
  String get addConnectionAction => 'کنکشن شامل کریں';

  @override
  String connectionName(String kind, String supplier) {
    return '$kind، $supplier';
  }

  @override
  String get inYourName => 'آپ کے نام پر';

  @override
  String billOfMonth(String connection, String month) {
    return '$connection: $month';
  }

  @override
  String unitsUsed(String units) {
    return '$units یونٹ';
  }

  @override
  String get chargedToTenant => 'کرایہ دار کے کھاتے میں';

  @override
  String get loadingUtility => 'کنکشن لوڈ ہو رہا ہے';

  @override
  String get utilityLoadFailedTitle => 'کنکشن لوڈ نہیں ہو سکا';

  @override
  String get inYourNameWarning =>
      'یہ کنکشن آپ کے نام پر ہے۔ جو بل ادا نہ ہوں وہ اسی کے ساتھ رہتے ہیں اور آپ پر آ سکتے ہیں۔ ہر مہینے دیکھیں کہ بل ادا ہو گیا ہے۔';

  @override
  String get referenceNumberLabel => 'ریفرنس نمبر';

  @override
  String get customerIdLabel => 'کسٹمر آئی ڈی';

  @override
  String get meterNumberLabel => 'میٹر نمبر';

  @override
  String get nameOnBillLabel => 'بل پر نام';

  @override
  String get inMyNameLabel => 'میرے نام پر';

  @override
  String get inMyNameHelp =>
      'بقایا جگہ کے ساتھ رہتا ہے۔ آپ کے نام کے کنکشن کے جو بل ادا نہ ہوں، وہ آپ پر آ سکتے ہیں۔';

  @override
  String get whoPaysLabel => 'بل کون ادا کرتا ہے';

  @override
  String get subMeterLabel => 'سب میٹر';

  @override
  String get subMeterHelp =>
      'آپ کا اپنا میٹر جو مرکزی کنکشن میں سے کسی ایک پورشن کا حصہ ناپتا ہے۔';

  @override
  String get protectedLabel => 'پروٹیکٹڈ ٹیرف';

  @override
  String protectedHelp(int limit) {
    return '$limit یا اس سے کم بجلی کے یونٹ ماہانہ استعمال کرنے والے گھروں کا سبسڈی والا (سستا) ٹیرف۔ کسی ایک مہینے $limit سے زیادہ یونٹ پر یہ چھ مہینے کے لیے ختم ہو جاتا ہے۔ جب کوئی مہینہ اس حد کے قریب پہنچے تو ایپ آپ کو خبردار کرتی ہے۔';
  }

  @override
  String get billsSection => 'بل';

  @override
  String get billsEmpty =>
      'ابھی کوئی بل نہیں۔ ہر مہینے کا بل اس کی آخری تاریخ اور یونٹس کے ساتھ شامل کریں۔';

  @override
  String get addBillAction => 'بل شامل کریں';

  @override
  String get readingsSection => 'میٹر ریڈنگ';

  @override
  String get readingsHelp =>
      'کرایہ دار کے آنے اور جانے کے وقت میٹر پڑھیں، اور چاہیں تو ہر مہینے بھی۔';

  @override
  String get readingsEmpty => 'ابھی کوئی ریڈنگ نہیں۔';

  @override
  String get addReadingAction => 'ریڈنگ شامل کریں';

  @override
  String readingValue(String value) {
    return 'ریڈنگ $value';
  }

  @override
  String usedSince(String units, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن میں $units یونٹ',
      one: '1 دن میں $units یونٹ',
    );
    return '$_temp0';
  }

  @override
  String get archiveConnectionTitle => 'یہ کنکشن آرکائیو کریں؟';

  @override
  String get archiveConnectionBody =>
      'یہ آپ کی فہرستوں سے ہٹ جائے گا، لیکن اس کے بل اور ریڈنگز محفوظ رہیں گی۔ آپ اسے بعد میں آرکائیو سے واپس لا سکتے ہیں۔';

  @override
  String get connectionArchived => 'کنکشن آرکائیو ہو گیا۔';

  @override
  String get connectionRestored => 'کنکشن آرکائیو سے واپس آ گیا۔';

  @override
  String get deleteConnectionTitle => 'یہ کنکشن ڈیلیٹ کریں؟';

  @override
  String get deleteConnectionBody =>
      'یہ اپنے بلوں اور ریڈنگز سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گا۔ کرایہ دار کے کھاتے میں پہلے سے لگے چارجز وہیں رہیں گے۔ صرف تب کریں جب یہ کنکشن غلطی سے شامل ہوا ہو۔ ورنہ اسے آرکائیو کریں۔';

  @override
  String get connectionDeleted => 'کنکشن ڈیلیٹ ہو گیا۔';

  @override
  String get newConnectionTitle => 'نیا کنکشن';

  @override
  String get editConnectionTitle => 'کنکشن کی تفصیل بدلیں';

  @override
  String get connectionSectionWhere => 'کہاں';

  @override
  String get connectionSectionSupplier => 'کیا کنکشن، کون سی کمپنی یا ادارہ';

  @override
  String get connectionSectionNumbers => 'کنکشن کے نمبر';

  @override
  String get connectionSectionWho => 'کس کے نام پر، کون ادا کرتا ہے';

  @override
  String get utilityTypeLabel => 'قسم';

  @override
  String get providerLabel => 'کمپنی یا ادارہ';

  @override
  String get providerNameLabel => 'کمپنی یا ادارے کا نام';

  @override
  String get referenceNumberHelp => 'جیسا بل پر لکھا ہے۔';

  @override
  String referenceDigitsHint(int digits) {
    return 'اس کمپنی کے بلوں پر عام طور پر $digits ہندسوں کا نمبر ہوتا ہے۔ اسے بل سے ملا لیں۔';
  }

  @override
  String get referenceNumberInvalid =>
      '4 سے 24 تک حروف، ہندسے یا ڈیش استعمال کریں۔';

  @override
  String get customerIdInvalid =>
      'زیادہ سے زیادہ 30 حروف، ہندسے یا ڈیش استعمال کریں۔';

  @override
  String get meterNumberInvalid =>
      'زیادہ سے زیادہ 30 حروف، ہندسے، ڈیش یا سلیش استعمال کریں۔';

  @override
  String get connectionAdded => 'کنکشن شامل ہو گیا۔';

  @override
  String get connectionSaved => 'کنکشن محفوظ ہو گیا۔';

  @override
  String get billTitle => 'بل';

  @override
  String get loadingBill => 'بل لوڈ ہو رہا ہے';

  @override
  String get billLoadFailedTitle => 'بل لوڈ نہیں ہو سکا';

  @override
  String get billPaid => 'ادا شدہ';

  @override
  String get billUnpaid => 'ادا نہیں ہوا';

  @override
  String get billMonthLabel => 'کس مہینے کا بل';

  @override
  String get billDueDateLabel => 'آخری تاریخ';

  @override
  String get unitsConsumedLabel => 'کتنے یونٹ استعمال ہوئے';

  @override
  String protectedUnitsHelp(int limit) {
    return 'پروٹیکٹڈ ٹیرف کے لیے ہر مہینے $limit یا اس سے کم بجلی کے یونٹ استعمال کریں۔';
  }

  @override
  String get validationUnits => 'یونٹس کی تعداد لکھیں، جیسے 185 یا 185.5۔';

  @override
  String get alreadyPaidLabel => 'ادا ہو چکا ہے';

  @override
  String get billPaidByLabel => 'کس نے ادا کیا';

  @override
  String get billAdded => 'بل شامل ہو گیا۔';

  @override
  String get billSaved => 'بل محفوظ ہو گیا۔';

  @override
  String get billDeleted => 'بل ڈیلیٹ ہو گیا۔';

  @override
  String get billMarkedPaid => 'بل پر ادا شدہ کا نشان لگ گیا۔';

  @override
  String get billMarkedUnpaid => 'بل سے ادا شدہ کا نشان ہٹ گیا۔';

  @override
  String get billCharged => 'بل کرایہ دار کے کھاتے میں درج ہو گیا۔';

  @override
  String get markPaidAction => 'ادا شدہ کا نشان لگائیں';

  @override
  String get markUnpaidAction => 'ادا شدہ کا نشان ہٹائیں';

  @override
  String get editBillAction => 'بل کی تفصیل بدلیں';

  @override
  String get chargeTenantAction => 'کرایہ دار پر چارج لگائیں';

  @override
  String chargeTenantExplain(String amount, String date) {
    return '$amount کا بل کرایہ دار کے کھاتے میں چارج بن جائے گا، جسے $date تک دینا ہو گا۔ کرایہ دار کا کریڈٹ اس میں لگ جائے گا۔';
  }

  @override
  String get chargedToTenantHelp =>
      'اس کی ادائیگی کرایہ داری کے کھاتے میں درج ہوتی ہے۔';

  @override
  String get billChargeVoided =>
      'اس بل کا کرایہ دار کے کھاتے میں لگا چارج کینسل ہو گیا تھا۔ آپ اسے دوبارہ لگا سکتے ہیں۔';

  @override
  String get connectionDetailsAction => 'کنکشن کی تفصیل';

  @override
  String get inYourNameUnpaid =>
      'یہ بل ادا نہیں ہوا اور آپ کے نام کے کنکشن کا ہے۔ اگر یہ ادا نہ ہوا تو بقایا آپ پر آ سکتا ہے۔';

  @override
  String get deleteBillTitle => 'یہ بل ڈیلیٹ کریں؟';

  @override
  String get deleteBillBody =>
      'یہ اپنی تصویروں سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گا۔ صرف تب کریں جب یہ بل غلطی سے شامل ہوا ہو۔';

  @override
  String get deleteChargedBillBody =>
      'یہ اپنی تصویروں سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گا۔ کرایہ دار کے کھاتے میں اس کا چارج وہیں رہے گا۔ اگر وہ بھی غلط ہے تو اسے کھاتے میں کینسل کریں۔';

  @override
  String protectedOver(int limit) {
    return 'ماہانہ $limit یونٹ سے زیادہ';
  }

  @override
  String protectedNear(int limit) {
    return 'ماہانہ $limit یونٹ کے قریب';
  }

  @override
  String protectedOverExplain(int limit) {
    return 'اس مہینے $limit سے زیادہ بجلی کے یونٹ استعمال ہوئے۔ اگلے چھ مہینے کے لیے پروٹیکٹڈ ٹیرف ختم ہو جاتا ہے، اور بل مہنگے ہوں گے۔';
  }

  @override
  String protectedNearExplain(int limit) {
    return 'اس مہینے کا استعمال $limit یونٹ کے قریب ہے۔ کسی ایک مہینے $limit سے زیادہ یونٹ پر پروٹیکٹڈ ٹیرف چھ مہینے کے لیے ختم ہو جاتا ہے۔';
  }

  @override
  String get readingTitle => 'میٹر ریڈنگ';

  @override
  String get loadingReading => 'ریڈنگ لوڈ ہو رہی ہے';

  @override
  String get readingLoadFailedTitle => 'ریڈنگ لوڈ نہیں ہو سکی';

  @override
  String get readingLabel => 'ریڈنگ';

  @override
  String get readOnLabel => 'ریڈنگ کی تاریخ';

  @override
  String get readingContextLabel => 'کس موقع پر';

  @override
  String get readingTenancyHelp =>
      'اگر کوئی ہو تو آنے یا جانے والی کرایہ داری۔';

  @override
  String lastReadingWas(String value, String date) {
    return 'پچھلی ریڈنگ $date کو $value تھی۔';
  }

  @override
  String get readingLower =>
      'یہ پچھلی ریڈنگ سے کم ہے۔ اگر میٹر بدلا گیا ہے تو نیچے نوٹ میں لکھ دیں۔';

  @override
  String get previousReadingLabel => 'پچھلی ریڈنگ';

  @override
  String readingOn(String value, String date) {
    return '$date کو $value';
  }

  @override
  String get unitsUsedLabel => 'تب سے استعمال';

  @override
  String get monthlyPaceLabel => 'اس رفتار سے';

  @override
  String unitsAMonth(String units) {
    return '$units یونٹ ماہانہ';
  }

  @override
  String get readingAdded => 'ریڈنگ شامل ہو گئی۔';

  @override
  String get readingSaved => 'ریڈنگ محفوظ ہو گئی۔';

  @override
  String get readingDeleted => 'ریڈنگ ڈیلیٹ ہو گئی۔';

  @override
  String get editReadingAction => 'ریڈنگ کی تفصیل بدلیں';

  @override
  String get deleteReadingTitle => 'یہ ریڈنگ ڈیلیٹ کریں؟';

  @override
  String get deleteReadingBody =>
      'یہ اپنی تصویروں سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گی۔ صرف تب کریں جب یہ ریڈنگ غلطی سے شامل ہوئی ہو۔';

  @override
  String get maintenancePlumbing => 'پلمبنگ';

  @override
  String get maintenanceElectrical => 'بجلی کا کام';

  @override
  String get maintenanceCarpentry => 'لکڑی کا کام';

  @override
  String get maintenancePainting => 'رنگ و روغن';

  @override
  String get maintenanceSeepage => 'سیلن';

  @override
  String get maintenanceAppliance => 'گھر کی مشینیں (اے سی، فریج، گیزر، موٹر)';

  @override
  String get maintenancePestControl => 'کیڑے مار اسپرے';

  @override
  String get maintenanceCleaning => 'صفائی';

  @override
  String get maintenanceStructural => 'عمارت کا ڈھانچہ (دیوار، چھت، فرش)';

  @override
  String get maintenanceWaterSupply => 'پانی کی سپلائی';

  @override
  String get priorityLow => 'کم';

  @override
  String get priorityMedium => 'درمیانی';

  @override
  String get priorityHigh => 'زیادہ';

  @override
  String get priorityUrgent => 'فوری';

  @override
  String priorityNamed(String priority) {
    return 'کتنا ضروری: $priority';
  }

  @override
  String get maintenanceOpen => 'شروع نہیں ہوا';

  @override
  String get maintenanceInProgress => 'کام جاری';

  @override
  String get maintenanceOnHold => 'رکا ہوا';

  @override
  String get maintenanceResolved => 'مکمل';

  @override
  String get maintenanceCancelled => 'کینسل';

  @override
  String get maintenanceTitle => 'مرمت اور دیکھ بھال';

  @override
  String get loadingMaintenance => 'مرمت کے کام لوڈ ہو رہے ہیں';

  @override
  String get loadingMaintenanceRequest => 'مرمت کا کام لوڈ ہو رہا ہے';

  @override
  String get maintenanceLoadFailedTitle => 'مرمت کے کام لوڈ نہیں ہو سکے';

  @override
  String get maintenanceRequestLoadFailedTitle => 'مرمت کا کام لوڈ نہیں ہو سکا';

  @override
  String get maintenanceEmptyTitle => 'مرمت کا کوئی کام نہیں';

  @override
  String get maintenanceEmptyBody =>
      'ہر مرمت کا کام اطلاع ملتے ہی درج کریں۔ کام پورا ہونے تک اس پر نظر رکھیں، اور اس کا خرچ بھی لکھیں۔';

  @override
  String get maintenanceClosedEmptyTitle => 'ابھی کوئی بند کام نہیں';

  @override
  String get maintenanceClosedEmptyBody =>
      'جو کام آپ مکمل یا کینسل کریں، وہ یہاں محفوظ رہتے ہیں۔';

  @override
  String get addRequestAction => 'مرمت کا کام شامل کریں';

  @override
  String reportedOn(String date) {
    return 'اطلاع $date';
  }

  @override
  String get maintenanceCategoryLabel => 'کام کی قسم';

  @override
  String get priorityLabel => 'کتنا ضروری';

  @override
  String get reportedOnLabel => 'اطلاع کی تاریخ';

  @override
  String get reportedByLabel => 'اطلاع دینے والا';

  @override
  String get assignedToLabel => 'کام کرنے والا';

  @override
  String get assignedToHelp => 'پلمبر، الیکٹریشن یا کمپنی جو یہ کام کر رہی ہے۔';

  @override
  String get vendorPhoneLabel => 'ان کا فون';

  @override
  String get estimateLabel => 'اندازاً خرچ';

  @override
  String get resolvedOnLabel => 'مکمل ہونے کی تاریخ';

  @override
  String get resolutionLabel => 'کیا کام ہوا';

  @override
  String get resolutionHelp =>
      'ریکارڈ کے لیے لکھیں کہ کیا ٹھیک ہوا، اور اگر کوئی گارنٹی ملی ہو۔';

  @override
  String get startWorkAction => 'کام شروع کریں';

  @override
  String get resumeWorkAction => 'کام دوبارہ شروع کریں';

  @override
  String get putOnHoldAction => 'روک دیں';

  @override
  String get markResolvedAction => 'مکمل درج کریں';

  @override
  String get cancelRequestAction => 'کام کینسل کریں';

  @override
  String get reopenAction => 'دوبارہ کھولیں';

  @override
  String requestMoved(String status) {
    return 'اب: $status۔';
  }

  @override
  String get requestResolved => 'مرمت کا کام مکمل ہو گیا۔';

  @override
  String get jobExpensesSection => 'اس پر خرچ';

  @override
  String get jobExpensesEmpty => 'ابھی اس پر کچھ خرچ نہیں ہوا۔';

  @override
  String spentSoFar(String amount) {
    return 'اب تک $amount';
  }

  @override
  String spentOfEstimate(String spent, String estimate) {
    return '$estimate کے اندازے میں سے $spent';
  }

  @override
  String deleteRequestTitle(String title) {
    return '$title ڈیلیٹ کریں؟';
  }

  @override
  String get deleteRequestBody =>
      'یہ اپنی تصویروں سمیت ہمیشہ کے لیے ڈیلیٹ ہو جائے گا۔ صرف تب کریں جب یہ کام غلطی سے شامل ہوا ہو۔ ریکارڈ رکھنے کے لیے اسے کینسل کریں۔';

  @override
  String get requestDeleted => 'مرمت کا کام ڈیلیٹ ہو گیا۔';

  @override
  String get newRequestTitle => 'مرمت کا نیا کام';

  @override
  String get editRequestTitle => 'مرمت کے کام کی تفصیل بدلیں';

  @override
  String get requestSectionWhat => 'کیا کام کرنا ہے';

  @override
  String get requestSectionWhere => 'کہاں';

  @override
  String get requestSectionWho => 'کون اور کب';

  @override
  String get requestSectionStatus => 'اسٹیٹس';

  @override
  String get requestTitleLabel => 'کیا خرابی ہے';

  @override
  String get requestTitleHelp => 'چند الفاظ میں: \"کچن کا نل ٹپک رہا ہے\"۔';

  @override
  String get requestTenancyHelp =>
      'اگر کوئی ہو تو وہ کرایہ داری جس میں اس کی اطلاع ملی۔';

  @override
  String get requestAdded => 'مرمت کا کام شامل ہو گیا۔';

  @override
  String get requestSaved => 'مرمت کا کام محفوظ ہو گیا۔';

  @override
  String get reasonDuplicateUtilityReference =>
      'اس قسم کے استعمال میں کسی اور کنکشن کا یہی ریفرنس نمبر پہلے سے موجود ہے۔';

  @override
  String get reasonDuplicateBillMonth =>
      'اس کنکشن کا اس مہینے کا بل پہلے سے موجود ہے۔ اسے بدلنے کے لیے وہی بل کھولیں۔';

  @override
  String get reasonRequestHasExpenses =>
      'اس مرمت کے کام پر خرچے درج ہیں، اس لیے یہ ڈیلیٹ نہیں ہو سکتا۔ اس کے بجائے اسے کینسل کریں، یا پہلے وہ خرچے ڈیلیٹ کریں۔';

  @override
  String connectionReference(String number) {
    return 'ریفرنس $number';
  }

  @override
  String get whereLabel => 'کہاں';

  @override
  String pacedNearExplain(int limit) {
    return 'اس رفتار سے ایک مہینے کا استعمال $limit یونٹ کے قریب پہنچ جاتا ہے۔ کسی ایک مہینے $limit سے زیادہ یونٹ پر پروٹیکٹڈ ٹیرف چھ مہینے کے لیے ختم ہو جاتا ہے۔';
  }

  @override
  String pacedOverExplain(int limit) {
    return 'اس رفتار سے ایک مہینے کا استعمال $limit یونٹ سے بڑھ جاتا ہے، جس سے پروٹیکٹڈ ٹیرف چھ مہینے کے لیے ختم ہو جاتا ہے۔ بل آنے پر اسے دیکھ لیں۔';
  }

  @override
  String get paidWithLabel => 'ادائیگی کا طریقہ';

  @override
  String get billAmountLocked =>
      'یہ بل کرایہ دار کے کھاتے میں چارج بن چکا ہے، اس لیے اس کی رقم یہاں نہیں بدل سکتی۔ ٹھیک کرنے کے لیے کھاتے میں وہ چارج کینسل کریں، پھر بل دوبارہ کرایہ دار پر چارج کریں۔';

  @override
  String paceAMonth(String units) {
    return 'تقریباً $units یونٹ ماہانہ';
  }

  @override
  String readingHigher(String value, String date) {
    return 'یہ $date کی بعد والی ریڈنگ $value سے زیادہ ہے۔ نمبر اور تاریخ دوبارہ دیکھ لیں۔';
  }

  @override
  String get markUnpaidTitle => 'اس بل سے ادا شدہ کا نشان ہٹائیں؟';

  @override
  String markUnpaidBody(String date) {
    return 'ادائیگی کی تاریخ ($date) اور ادا کرنے والے کی انٹری مٹ جائے گی۔';
  }

  @override
  String get cancelRequestTitle => 'یہ کام کینسل کر کے بند کریں؟';

  @override
  String get cancelRequestBody =>
      'یہ اپنی تفصیلات اور خرچوں سمیت بند کاموں میں چلا جائے گا۔ آپ اسے بعد میں دوبارہ کھول سکتے ہیں۔';

  @override
  String get closeAsCancelledAction => 'کینسل کر کے بند کریں';

  @override
  String get chargeDuePassed =>
      'یہ تاریخ گزر چکی ہے، اس لیے یہ چارج فوراً لیٹ دکھائی دے گا۔';

  @override
  String get savedEarlierUnchanged =>
      'یہ پہلے ہی محفوظ ہو چکا تھا، جیسا پہلی بار درج ہوا۔ آپ کی بعد کی تبدیلیاں محفوظ نہیں ہوئیں۔ انہیں کرنے کے لیے اسے ایڈٹ کریں۔';

  @override
  String get requestHasExpensesClosed =>
      'اس مرمت کے کام پر خرچے درج ہیں، اس لیے یہ ڈیلیٹ نہیں ہو سکتا۔ اگر یہ غلطی سے درج ہوا تھا تو پہلے وہ خرچے ڈیلیٹ کریں۔';

  @override
  String get loadingDashboard => 'ڈیش بورڈ لوڈ ہو رہا ہے';

  @override
  String get dashboardLoadFailedTitle => 'ڈیش بورڈ لوڈ نہیں ہو سکا';

  @override
  String get searchAction => 'تلاش';

  @override
  String get reportsTitle => 'رپورٹس';

  @override
  String get reportsEntryTitle => 'رپورٹس اور اسٹیٹمنٹ';

  @override
  String get reportsEntrySummary =>
      'پیسہ کتنا آیا، کتنا گیا، ادائیگی کے اسکور، ٹیکس سال اور مالک کی اسٹیٹمنٹ، ایکسپورٹ';

  @override
  String thisMonthSection(String month) {
    return 'اس مہینے، $month';
  }

  @override
  String get collectedThisMonthLabel => 'اس مہینے کے چارجز میں سے ادا ہوئے';

  @override
  String collectedOfDue(String due, String rate) {
    return '$due کے چارجز میں سے $rate وصول';
  }

  @override
  String get receivedThisMonthLabel => 'اس مہینے ملی رقم';

  @override
  String get receivedThisMonthCaption =>
      'اس مہینے درج ہر ادائیگی، کسی بھی مہینے کے چارجز کی';

  @override
  String get nothingDueThisMonth => 'اس مہینے ابھی کسی چارج کی تاریخ نہیں آئی۔';

  @override
  String owedInAll(String amount) {
    return 'کل باقی رقم $amount';
  }

  @override
  String get unitsLetLabel => 'کرائے پر دیے گئے یونٹس';

  @override
  String unitsLetValue(String occupied, String units) {
    return '$units میں سے $occupied';
  }

  @override
  String occupancyCaption(String rate, int vacant) {
    String _temp0 = intl.Intl.pluralLogic(
      vacant,
      locale: localeName,
      other: '$vacant خالی',
      zero: 'کوئی خالی نہیں',
    );
    return '$rate کرائے پر، $_temp0';
  }

  @override
  String get noUnitsToLet => 'ابھی کرائے کے لیے کوئی یونٹ نہیں';

  @override
  String get stillToCollect => 'ابھی وصول ہونا ہے';

  @override
  String monthBarSummary(String expected, String paid) {
    return 'اس مہینے کے $expected روپے میں سے $paid ادا ہو چکے ہیں۔';
  }

  @override
  String get insightsSection => 'کن باتوں پر دھیان دیں';

  @override
  String get noInsights => 'آج کسی بات پر دھیان دینے کی ضرورت نہیں۔';

  @override
  String get insightAlert => 'فوری دھیان دیں';

  @override
  String get insightWarning => 'ایک نظر دیکھ لیں';

  @override
  String get insightInfo => 'جاننا اچھا ہے';

  @override
  String get insightGood => 'اچھی خبر';

  @override
  String insightsShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سب $count دکھائیں',
    );
    return '$_temp0';
  }

  @override
  String get insightsShowFewer => 'کم دکھائیں';

  @override
  String openNamedTenancyAction(String tenant) {
    return '$tenant کی کرایہ داری کھولیں';
  }

  @override
  String get seeTenantsAction => 'کرایہ دار دیکھیں';

  @override
  String get dashboardNoPropertiesTitle => 'ابھی کوئی جائیداد نہیں';

  @override
  String get dashboardNoPropertiesBody =>
      'کرایہ وصول کرنا شروع کرنے کے لیے اپنی پہلی جائیداد شامل کریں۔';

  @override
  String get dashboardNoPropertiesViewer =>
      'جائیداد شامل ہونے کے بعد اس کا کرایہ یہاں نظر آئے گا۔';

  @override
  String get dashboardNoUnitsTitle => 'ابھی کوئی یونٹ نہیں';

  @override
  String get dashboardNoUnitsBody =>
      'کرائے پر دینے اور کرایہ وصول کرنے کے لیے کسی جائیداد میں یونٹ شامل کریں۔';

  @override
  String get dashboardNoUnitsViewer =>
      'یونٹ شامل ہونے کے بعد اس کا کرایہ یہاں نظر آئے گا۔';

  @override
  String get seePropertiesAction => 'جائیدادیں دیکھیں';

  @override
  String insightCollectionTitle(String rate) {
    return 'اس مہینے کے چارجز کا $rate وصول';
  }

  @override
  String insightCollectionBody(String amount) {
    return 'ان میں سے $amount ابھی وصول ہونا ہے۔';
  }

  @override
  String get insightCollectionDone => 'اس مہینے کے سب چارجز ادا ہو چکے ہیں۔';

  @override
  String insightLongArrearsTitle(String amount) {
    return '90 دن سے زیادہ پرانی باقی رقم: $amount';
  }

  @override
  String get insightLongArrearsBody =>
      'اتنی پرانی رقم وصول کرنا سب سے مشکل ہوتا ہے۔ ان کرایہ داروں سے بات کریں، یا جگہ خالی کرتے وقت ان کی سیکیورٹی میں سے کاٹ لیں۔';

  @override
  String get seeWhoOwesAction => 'دیکھیں کس کے ذمے باقی ہے';

  @override
  String get insightIncrementTitle => 'کرائے میں اضافہ کرنا ہے';

  @override
  String insightIncrementMissed(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اضافے وقت پر نہیں ہوئے',
      one: '1 اضافہ وقت پر نہیں ہوا',
    );
    return '$_temp0: ہر مہینے $amount کا چارج نہیں لگ رہا۔';
  }

  @override
  String insightIncrementUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اگلے 30 دن میں $count کرائے بڑھنے ہیں۔',
      one: 'اگلے 30 دن میں 1 کرایہ بڑھنا ہے۔',
    );
    return '$_temp0';
  }

  @override
  String insightExpiringTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کرایہ داریاں 90 دن کے اندر ختم ہو رہی ہیں',
      one: '1 کرایہ داری 90 دن کے اندر ختم ہو رہی ہے',
    );
    return '$_temp0';
  }

  @override
  String insightExpiringBody(String tenant, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن میں',
      one: '1 دن میں',
      zero: 'آج',
    );
    return '$tenant کی سب سے پہلے ختم ہو رہی ہے، $_temp0۔ کرایہ نامہ رینیو کریں یا جگہ خالی ہونے کی تیاری کریں۔';
  }

  @override
  String insightPoliceTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کرایہ داریوں کی پولیس رجسٹریشن نہیں ہوئی',
      one: '1 کرایہ داری کی پولیس رجسٹریشن نہیں ہوئی',
    );
    return '$_temp0';
  }

  @override
  String insightPoliceLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کی قانون کی آخری تاریخ گزر چکی ہے۔ ابھی رجسٹریشن کروائیں۔',
      one: '1 کی قانون کی آخری تاریخ گزر چکی ہے۔ ابھی رجسٹریشن کروائیں۔',
    );
    return '$_temp0';
  }

  @override
  String get insightPoliceBody =>
      'ہر ایک کی رجسٹریشن اس کی آخری تاریخ تک کروائیں۔ جہاں ہمیں آخری تاریخ دینے والا کوئی قانون نہیں ملا، وہاں ایپ یاد دلاتی ہے۔';

  @override
  String insightPoliceSubmittedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پولیس رجسٹریشن پر پولیس کی تصدیق کا انتظار ہے',
      one: '1 پولیس رجسٹریشن پر پولیس کی تصدیق کا انتظار ہے',
    );
    return '$_temp0';
  }

  @override
  String insightPoliceSubmittedLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اور جمع ہو چکی ہیں، پولیس کی تصدیق کا انتظار ہے۔',
      one: '1 اور جمع ہو چکی ہے، پولیس کی تصدیق کا انتظار ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get insightPoliceSubmittedBody =>
      'قانون کی شرط آپ پوری کر چکے ہیں۔ پولیس تصدیق کر دے تو کرایہ داری میں اپ ڈیٹ کریں۔';

  @override
  String insightVacancyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count یونٹس خالی ہیں',
      one: '1 یونٹ خالی ہے',
    );
    return '$_temp0';
  }

  @override
  String insightVacancyBody(int count, String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سب سے پرانا خالی یونٹ',
      one: 'یہ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن سے',
      one: '1 دن سے',
      zero: 'آج سے',
    );
    return 'جتنا کرایہ آپ مانگتے ہیں، اس حساب سے خالی رہنے پر ہر مہینے $amount کا نقصان ہو رہا ہے۔ $_temp0 $_temp1 خالی ہے۔';
  }

  @override
  String insightDepositTitle(String cover) {
    return 'سیکیورٹی ڈپازٹ سے لیٹ کرائے کا صرف $cover پورا ہوتا ہے';
  }

  @override
  String insightDepositBody(String overdue, String held) {
    return '$overdue لیٹ ہے اور $held سیکیورٹی جمع ہے۔ بقایا سیکیورٹی سے بڑھنے سے پہلے وصول کریں۔';
  }

  @override
  String get insightUtilityTitle => 'بلوں پر دھیان دیں';

  @override
  String insightUtilityLandlord(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آپ کے نام پر $count بل ادا نہیں ہوئے',
      one: 'آپ کے نام پر 1 بل ادا نہیں ہوا',
    );
    return '$_temp0، کل رقم $amount۔ ان کی ذمہ داری آپ پر ہے۔';
  }

  @override
  String insightUtilityOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بلوں کی آخری تاریخ گزر چکی ہے۔',
      one: '1 بل کی آخری تاریخ گزر چکی ہے۔',
    );
    return '$_temp0';
  }

  @override
  String insightUtilityOverTariff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'پروٹیکٹڈ ٹیرف کے $count میٹر تازہ بل پر 200 یونٹ سے بڑھ گئے۔',
      one: 'پروٹیکٹڈ ٹیرف کا 1 میٹر تازہ بل پر 200 یونٹ سے بڑھ گیا۔',
    );
    return '$_temp0';
  }

  @override
  String insightUtilityNearTariff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'پروٹیکٹڈ ٹیرف کے $count میٹر 200 یونٹ کے قریب ہیں۔',
      one: 'پروٹیکٹڈ ٹیرف کا 1 میٹر 200 یونٹ کے قریب ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get seeUtilitiesAction => 'بل اور کنکشن دیکھیں';

  @override
  String get insightExpenseTitle => 'اس مہینے خرچ زیادہ ہے';

  @override
  String insightExpenseBody(String amount, String average) {
    return 'اب تک $amount، جبکہ اس سے پہلے کے تین مہینوں کی ماہانہ اوسط $average تھی۔';
  }

  @override
  String get seeExpensesAction => 'خرچ دیکھیں';

  @override
  String insightUnderpricedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count یونٹس اس کرائے سے کم پر ہیں جو آپ مانگتے ہیں',
      one: '1 یونٹ اس کرائے سے کم پر ہے جو آپ مانگتے ہیں',
    );
    return '$_temp0';
  }

  @override
  String insightUnderpricedBody(String amount, String unit) {
    return 'کل ملا کر یہ اس سے ہر مہینے $amount کم ہے جتنا آپ مانگتے ہیں، سب سے زیادہ $unit پر۔ اگلے اضافے یا رینیو پر اس کے بارے میں سوچیں۔';
  }

  @override
  String insightCashTitle(String amount) {
    return 'نگرانوں کے پاس $amount نقد';
  }

  @override
  String insightCashHolder(String name, String amount) {
    return '$name کے پاس $amount ہیں۔';
  }

  @override
  String get insightCashShareTitle => 'اس مہینے کی زیادہ تر رقم نقد آئی';

  @override
  String insightCashShare(String share) {
    return 'اس مہینے کی رقم کا $share نقد آیا۔';
  }

  @override
  String get insightCashAdvice =>
      'بینک ٹرانسفر اور نقدی کو باقاعدگی سے آگے دینے سے ہاتھ میں کم نقدی رہتی ہے۔';

  @override
  String get seeCashAction => 'ہاتھ میں نقدی دیکھیں';

  @override
  String get owedSection => 'کرایہ داروں کے ذمے باقی رقم';

  @override
  String owedSectionHelp(String amount) {
    return 'کل رقم $amount، اس حساب سے کہ کتنی دیر سے باقی ہے';
  }

  @override
  String get ageNotDue => 'ابھی تاریخ نہیں آئی';

  @override
  String get age1to30 => '1 سے 30 دن لیٹ';

  @override
  String get age31to60 => '31 سے 60 دن لیٹ';

  @override
  String get age61to90 => '61 سے 90 دن لیٹ';

  @override
  String get ageOver90 => '90 دن سے زیادہ لیٹ';

  @override
  String ageingSummary(
    String total,
    String notDue,
    String early,
    String middle,
    String older,
    String late,
  ) {
    return '$total روپے باقی: $notDue کی ابھی تاریخ نہیں آئی، $early 30 دن تک لیٹ، $middle 31 سے 60 دن لیٹ، $older 61 سے 90 دن لیٹ، $late 90 دن سے زیادہ لیٹ۔';
  }

  @override
  String get owingMostSection => 'جن کے ذمے سب سے زیادہ باقی ہے';

  @override
  String get seeAllAction => 'سب دیکھیں';

  @override
  String get remindShortAction => 'یاد دلائیں';

  @override
  String lastRemindedOn(String moment) {
    return 'یاد دہانی $moment';
  }

  @override
  String get upcomingSection => 'رہ گئے، آج کے اور آنے والے کام';

  @override
  String get upcomingEmpty => 'آنے والے ہفتوں میں کسی چیز کی تاریخ نہیں۔';

  @override
  String timelineLeaseEnds(String tenant) {
    return '$tenant کی کرایہ داری ختم';
  }

  @override
  String timelineIncrementDue(String tenant) {
    return '$tenant کے کرائے میں اضافہ';
  }

  @override
  String timelineIncrementMissed(String tenant) {
    return '$tenant کے کرائے میں اضافہ نہیں ہوا';
  }

  @override
  String timelineIncrementDetail(String unit, String from, String to) {
    return '$unit: $from سے $to';
  }

  @override
  String timelinePolice(String tenant) {
    return '$tenant کی کرایہ داری کی پولیس رجسٹریشن کروائیں';
  }

  @override
  String timelinePoliceLegal(String unit) {
    return '$unit: قانون کی آخری تاریخ';
  }

  @override
  String timelinePoliceLegalPassed(String unit) {
    return '$unit: قانون کی آخری تاریخ گزر چکی';
  }

  @override
  String timelinePoliceReminder(String unit) {
    return '$unit: ایپ کی یاد دہانی، ہمیں آخری تاریخ دینے والا کوئی قانون نہیں ملا';
  }

  @override
  String timelinePoliceSubmitted(String unit) {
    return '$unit: جمع کرا دیا، پولیس کی تصدیق کا انتظار';
  }

  @override
  String timelineCnicExpires(String tenant) {
    return '$tenant کا شناختی کارڈ ایکسپائر ہو رہا ہے';
  }

  @override
  String timelineCnicExpired(String tenant) {
    return '$tenant کا شناختی کارڈ ایکسپائر ہو چکا ہے';
  }

  @override
  String get timelineCnicHelp => 'نئے کارڈ کی کاپی مانگیں۔';

  @override
  String get vacantSection => 'خالی یونٹس';

  @override
  String vacantFor(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن سے خالی',
      one: '1 دن سے خالی',
      zero: 'آج سے خالی',
    );
    return '$_temp0';
  }

  @override
  String get heldAndSpentSection => 'سیکیورٹی ڈپازٹ، ٹیکس اور خرچ';

  @override
  String get depositsHeldLabel => 'جمع سیکیورٹی';

  @override
  String get depositsAgreedLabel => 'طے ہوئی سیکیورٹی';

  @override
  String get taxWithheldThisMonthLabel => 'اس مہینے کٹا ہوا ٹیکس';

  @override
  String get expensesThisMonthLabel => 'اس مہینے کا خرچ';

  @override
  String get expensesAverageLabel => 'پچھلے 3 مہینوں کی ماہانہ اوسط';

  @override
  String get loadingCashflow => 'آئی اور گئی رقم لوڈ ہو رہی ہے';

  @override
  String get cashflowLoadFailedTitle => 'آئی اور گئی رقم لوڈ نہیں ہو سکی';

  @override
  String get cashflowSection => 'آئی اور گئی رقم، پچھلے 12 مہینے';

  @override
  String get moneyInSeries => 'آئی رقم';

  @override
  String get moneyOutSeries => 'گئی رقم';

  @override
  String get monthColumn => 'مہینہ';

  @override
  String cashflowSummary(
    String first,
    String last,
    String moneyIn,
    String moneyOut,
  ) {
    return '$first سے $last تک ہر مہینے آئی اور گئی رقم: کل ملا کر $moneyIn روپے آئے اور $moneyOut روپے گئے۔';
  }

  @override
  String get cashflowEmpty => 'پچھلے 12 مہینوں میں نہ کوئی رقم آئی نہ گئی۔';

  @override
  String get totalInLabel => 'آئی رقم';

  @override
  String get totalOutLabel => 'گئی رقم';

  @override
  String get netLabel => 'آئی اور گئی رقم کا فرق';

  @override
  String get loadingPerformance => 'جائیدادوں کا حساب لوڈ ہو رہا ہے';

  @override
  String get performanceLoadFailedTitle => 'جائیدادوں کا حساب لوڈ نہیں ہو سکا';

  @override
  String get performanceSection => 'جائیدادیں، پچھلے 12 مہینے';

  @override
  String get performanceEmpty =>
      'یہاں آمدنی اور خرچ دیکھنے کے لیے جائیداد شامل کریں۔';

  @override
  String get rentIncomeLabel => 'جو کرایہ ملا';

  @override
  String get otherIncomeLabel => 'دوسری آمدنی';

  @override
  String get propertyExpensesLabel => 'خرچ';

  @override
  String get noiLabel => 'خرچوں کے بعد آمدنی';

  @override
  String get grossYieldLabel => 'خرچ سے پہلے سالانہ منافع (قیمت کا فیصد)';

  @override
  String get netYieldLabel => 'خرچ کے بعد سالانہ منافع (قیمت کا فیصد)';

  @override
  String yieldValue(String percent) {
    return '$percent سالانہ';
  }

  @override
  String get noYieldHelp =>
      'سالانہ منافع کا فیصد دیکھنے کے لیے جائیداد کی اندازاً قیمت لکھیں۔';

  @override
  String get noiChartTitle => 'ہر جائیداد کی خرچوں کے بعد آمدنی';

  @override
  String noiChartSummary(String best, String amount) {
    return 'پچھلے 12 مہینوں میں خرچوں کے بعد آمدنی: سب سے زیادہ $best کی، $amount روپے۔';
  }

  @override
  String get scoresSection => 'ادائیگی کے اسکور';

  @override
  String get scoresHelp => 'ہر کرایہ دار کے پچھلے 12 مہینوں کے کرائے سے۔';

  @override
  String get loadingScores => 'ادائیگی کے اسکور لوڈ ہو رہے ہیں';

  @override
  String get scoresLoadFailedTitle => 'ادائیگی کے اسکور لوڈ نہیں ہو سکے';

  @override
  String get scoresEmpty => 'کرائے کی تاریخ آنے کے بعد اسکور نظر آئیں گے۔';

  @override
  String get scoreBandGood => 'وقت پر ادائیگی';

  @override
  String get scoreBandFair => 'کبھی کبھی لیٹ';

  @override
  String get scoreBandPoor => 'اکثر لیٹ';

  @override
  String scoreSpoken(String score, String band) {
    return 'ادائیگی کا اسکور 100 میں سے $score، $band';
  }

  @override
  String scoreValue(String score) {
    return '$score/100';
  }

  @override
  String scoreOnTime(String onTime, String count) {
    return '$count میں سے $onTime بار وقت پر';
  }

  @override
  String scoreDaysLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'اوسطاً تقریباً $days دن لیٹ',
      one: 'اوسطاً تقریباً 1 دن لیٹ',
    );
    return '$_temp0';
  }

  @override
  String get scoreNeverLate => 'کبھی لیٹ نہیں';

  @override
  String get scoreUnderADayLate => 'اوسطاً ایک دن سے کم لیٹ';

  @override
  String scoreArrears(String months) {
    return '$months مہینوں کا کرایہ باقی';
  }

  @override
  String get scoreNoArrears => 'کچھ لیٹ نہیں';

  @override
  String get scoreSectionTitle => 'ادائیگی کا اسکور';

  @override
  String get scoreNotYet => 'اسکور کے لیے ابھی کرائے کا کافی ریکارڈ نہیں۔';

  @override
  String get scoreFormulaHelp =>
      '100 میں سے: 50 وقت پر ادائیگی کے، 30 صرف چند دن لیٹ ہونے کے، 20 کم باقی رقم کے۔';

  @override
  String get statementsSection => 'اسٹیٹمنٹ اور ایکسپورٹ';

  @override
  String get taxYearTitle => 'ٹیکس سال کی اسٹیٹمنٹ';

  @override
  String get taxYearSummary =>
      'ہر جائیداد کی کرائے کی آمدنی، جولائی سے جون تک، آپ کے ٹیکس مشیر کے لیے';

  @override
  String get ownerStatementTitle => 'مالک کی اسٹیٹمنٹ';

  @override
  String get ownerStatementSummary =>
      'ایک مہینے کی رقم اور کرایہ داروں کے ذمے باقی رقم، اوورسیز مالک کے لیے پی ڈی ایف';

  @override
  String get exportTitle => 'فائل ایکسپورٹ (CSV)';

  @override
  String get exportSummary =>
      'کھاتہ، ادائیگیاں یا خرچ، ایک CSV فائل میں۔ یہ فائل ایکسل میں کھلتی ہے۔';

  @override
  String get taxYearLabel => 'ٹیکس سال';

  @override
  String taxYearOption(String endYear, String startYear) {
    return 'ٹیکس سال $endYear: جولائی $startYear سے جون $endYear تک';
  }

  @override
  String get loadingTaxYear => 'ٹیکس سال لوڈ ہو رہا ہے';

  @override
  String get taxYearLoadFailedTitle => 'ٹیکس سال لوڈ نہیں ہو سکا';

  @override
  String get notTaxAdviceTitle => 'ٹیکس کا مشورہ نہیں';

  @override
  String get notTaxAdviceBody =>
      'یہ نمبر آپ کے ریکارڈ سے ہیں، آپ کے ٹیکس مشیر کی مدد کے لیے۔ یہ ٹیکس کا حساب نہیں۔ ایپ کبھی یہ حساب نہیں لگاتی کہ آپ کے ذمے کتنا ٹیکس ہے۔';

  @override
  String get grossRentLabel => 'کرایہ، ٹیکس کٹنے سے پہلے';

  @override
  String get repairsAllowanceLabel =>
      'مرمت کے لیے پانچواں حصہ (آمدنی میں سے نکلتا ہے)';

  @override
  String get netAfterAllowanceLabel => 'مرمت کا حصہ نکال کر کرایہ';

  @override
  String get expensesRecordedLabel => 'درج کیے گئے خرچ';

  @override
  String get allPropertiesLabel => 'سب جائیدادیں';

  @override
  String get taxYearEmpty => 'اس ٹیکس سال میں کوئی کرایہ یا خرچ درج نہیں ہوا۔';

  @override
  String get deductibleNote =>
      'ٹیکس کے حساب میں آمدنی میں سے کون سے خرچ نکل سکتے ہیں، یہ آپ کا ٹیکس مشیر طے کرے گا۔';

  @override
  String get shareCsvAction => 'فائل بھیجیں (CSV)';

  @override
  String taxYearFileTitle(String endYear) {
    return 'ٹیکس سال کی اسٹیٹمنٹ $endYear';
  }

  @override
  String taxYearDocumentTitle(String endYear) {
    return 'کرائے کی آمدنی، ٹیکس سال $endYear';
  }

  @override
  String get ownerStatementMonthLabel => 'مہینہ';

  @override
  String ownerStatementFileTitle(String month) {
    return 'مالک کی اسٹیٹمنٹ، $month';
  }

  @override
  String get moneyReceivedHeading => 'جو رقم ملی';

  @override
  String get rentAndFeesLabel => 'کرایہ اور لیٹ فیس';

  @override
  String get depositsReceivedLabel => 'سیکیورٹی ڈپازٹ';

  @override
  String get otherDuesLabel => 'دوسرے چارجز';

  @override
  String get unallocatedLabel => 'کریڈٹ کے طور پر رکھا';

  @override
  String get moneyPaidOutHeading => 'جو رقم دی';

  @override
  String get depositRefundsLabel => 'سیکیورٹی ڈپازٹ کی واپسی';

  @override
  String get netCashLabel => 'مہینے میں آئی اور گئی رقم کا فرق';

  @override
  String owedOnHeading(String date) {
    return '$date کو کرایہ داروں کے ذمے باقی';
  }

  @override
  String cashHeldOnHeading(String date) {
    return '$date کو ہاتھ میں نقدی';
  }

  @override
  String get ownerStatementFooter =>
      'پورٹ فولیو کے ریکارڈ سے بنائی گئی۔ صرف معلومات کے لیے ہے، آڈٹ کیا ہوا حساب نہیں۔';

  @override
  String get exportWhatLabel => 'کیا ایکسپورٹ کریں';

  @override
  String get exportLedger => 'کھاتہ: ہر کرایہ اور چارج';

  @override
  String get exportPayments => 'ادائیگیاں';

  @override
  String get exportExpenses => 'خرچ';

  @override
  String get exportPeriodLabel => 'مدت';

  @override
  String get periodThisMonth => 'یہ مہینہ';

  @override
  String get periodLastMonth => 'پچھلا مہینہ';

  @override
  String get exportAction => 'فائل بنائیں (CSV)';

  @override
  String get exportEmpty => 'اس مدت میں کچھ درج نہیں ہوا۔';

  @override
  String exportFileTitle(String what, String period) {
    return '$what، $period';
  }

  @override
  String inRupees(String label) {
    return '$label (روپے)';
  }

  @override
  String get csvMonth => 'مہینہ';

  @override
  String get csvDescription => 'نوٹ';

  @override
  String get csvWaived => 'معاف';

  @override
  String get csvOwed => 'باقی';

  @override
  String get csvVoided => 'کینسل';

  @override
  String get csvYes => 'ہاں';

  @override
  String get csvRepair => 'مرمت';

  @override
  String get searchTitle => 'تلاش';

  @override
  String get searchHint => 'نام، فون یا شناختی کارڈ';

  @override
  String get searchIntro =>
      'نام، علاقے، فون یا شناختی کارڈ سے جائیداد، یونٹ یا کرایہ دار تلاش کریں۔';

  @override
  String get searchTooShort => 'کم از کم 2 حروف یا ہندسے لکھیں۔';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتیجے',
      one: '1 نتیجہ',
    );
    return '$_temp0';
  }

  @override
  String searchNoMatches(String query) {
    return '$query سے کچھ نہیں ملا۔';
  }

  @override
  String get searchNoMatchesBody =>
      'ہجے دیکھ لیں، یا فون یا شناختی کارڈ سے تلاش کریں۔';

  @override
  String get searchFailedTitle => 'تلاش مکمل نہیں ہو سکی';

  @override
  String get searching => 'تلاش جاری ہے';

  @override
  String searchResultLine(String kind, String detail) {
    return '$kind: $detail';
  }

  @override
  String get daysOverdueLabel => 'کتنے دن لیٹ';

  @override
  String timeOfDay(String time, String period) {
    String _temp0 = intl.Intl.selectLogic(period, {
      'morning': 'صبح',
      'noon': 'دوپہر',
      'afternoon': 'سہ پہر',
      'evening': 'شام',
      'other': 'رات',
    });
    return '$time $_temp0';
  }

  @override
  String get keepRepairAction => 'رہنے دیں';

  @override
  String get keepInvitationAction => 'رہنے دیں';

  @override
  String get deletePortfolioSection => 'یہ پورٹ فولیو ڈیلیٹ کریں';

  @override
  String get deletePortfolioHelp =>
      'اس میں موجود ہر چیز سب کے لیے ہمیشہ کے لیے ڈیلیٹ ہو جائے گی: جائیدادیں، کرایہ دار، کرایہ داریاں، ادائیگیاں اور رسیدیں، خرچے اور کاغذات۔ پہلے جو رسیدیں اور اسٹیٹمنٹ آپ کو چاہییں، ان کی کاپیاں رکھ لیں۔';

  @override
  String get deletePortfolioAction => 'پورٹ فولیو ڈیلیٹ کریں';

  @override
  String deletePortfolioTitle(String name) {
    return '$name اور اس میں موجود سب کچھ ڈیلیٹ کریں؟';
  }

  @override
  String get deletePortfolioBody =>
      'فوراً کوئی ممبر اسے نہیں دیکھ سکے گا، اور یہ واپس نہیں آ سکتا، ہماری طرف سے بھی نہیں۔';

  @override
  String portfolioDeleted(String name) {
    return '$name ڈیلیٹ ہو گیا۔';
  }

  @override
  String get chooseTenantTitle => 'کرایہ دار چنیں';

  @override
  String get chooseTenantAction => 'کرایہ دار چنیں';

  @override
  String get changeTenantAction => 'کوئی اور کرایہ دار چنیں';

  @override
  String get noTenantChosen => 'ابھی نہیں چنا';

  @override
  String get chooseUnitTitle => 'یونٹ چنیں';

  @override
  String get chooseUnitAction => 'یونٹ چنیں';

  @override
  String get changeUnitAction => 'کوئی اور یونٹ چنیں';

  @override
  String get otherPropertyAction => 'دوسری جائیدادیں';

  @override
  String get validationChooseUnit => 'یونٹ چنیں۔';
}
