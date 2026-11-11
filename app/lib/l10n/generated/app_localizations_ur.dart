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
  String get welcomeTitle => 'مالکِ مکان میں خوش آمدید';

  @override
  String get welcomeBody =>
      'اپنی جائیدادوں کا کرایہ، کرایہ دار اور رسیدیں، اردو یا انگریزی میں۔ اپنی زبان منتخب کریں؛ آپ اسے بعد میں ترتیبات میں بدل سکتے ہیں۔';

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
  String get noAccountPrompt => 'مالکِ مکان پر نئے ہیں؟';

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
  String get resetPasswordTitle => 'اپنا پاس ورڈ دوبارہ ترتیب دیں';

  @override
  String get resetPasswordBody =>
      'اپنے اکاؤنٹ کا ای میل پتہ درج کریں، ہم آپ کو نیا پاس ورڈ منتخب کرنے کا لنک بھیج دیں گے۔';

  @override
  String get sendResetLinkAction => 'ری سیٹ لنک بھیجیں';

  @override
  String get checkEmailTitle => 'اپنی ای میل دیکھیں';

  @override
  String get resendEmailAction => 'ای میل دوبارہ بھیجیں';

  @override
  String get backToSignInAction => 'سائن اِن پر واپس جائیں';

  @override
  String get choosePasswordTitle => 'نیا پاس ورڈ منتخب کریں';

  @override
  String get savePasswordAction => 'پاس ورڈ محفوظ کریں';

  @override
  String get signingInCallback => 'آپ کو سائن اِن کیا جا رہا ہے…';

  @override
  String get validationRequired => 'جاری رکھنے کے لیے یہ درج کریں۔';

  @override
  String get validationEmail => 'name@example.com جیسا ای میل پتہ درج کریں۔';

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
  String get settingsTitle => 'ترتیبات';

  @override
  String get settingsLanguage => 'زبان';

  @override
  String get settingsAppearance => 'ظاہری شکل';

  @override
  String get themeSystem => 'فون کی ترتیب کے مطابق';

  @override
  String get themeLight => 'روشن';

  @override
  String get themeDark => 'تاریک';

  @override
  String get highContrastLabel => 'زیادہ کنٹراسٹ';

  @override
  String get highContrastHelper =>
      'گہرے رنگ اور واضح حاشیے، دھوپ میں پڑھنا آسان۔';

  @override
  String get settingsNumbers => 'اعداد';

  @override
  String get groupingWestern => 'مغربی (1,250,000 روپے)';

  @override
  String get groupingSouthAsian => 'لاکھ اور کروڑ (12,50,000 روپے)';

  @override
  String get settingsAccount => 'اکاؤنٹ';

  @override
  String get signOutAction => 'سائن آؤٹ کریں';

  @override
  String get deleteAccountAction => 'اکاؤنٹ حذف کریں';

  @override
  String get settingsAbout => 'ایپ کے بارے میں';

  @override
  String get licencesAction => 'اوپن سورس لائسنس';

  @override
  String get failureNetwork =>
      'کنکشن نہیں ہے۔ اپنا انٹرنیٹ چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get failureSessionExpired =>
      'آپ کا سیشن ختم ہو گیا ہے۔ براہِ کرم دوبارہ سائن اِن کریں۔';

  @override
  String get failureReauthenticate =>
      'آپ کی حفاظت کے لیے، یہ کرنے سے پہلے دوبارہ سائن اِن کریں۔';

  @override
  String get failureForbidden => 'آپ کو یہ کرنے کی اجازت نہیں ہے۔';

  @override
  String get failureNotFound => 'یہ نہیں ملا۔ شاید اسے حذف کر دیا گیا ہے۔';

  @override
  String get failureConflict => 'یہ پہلے سے موجود ہے۔';

  @override
  String get failureRateLimited =>
      'بہت زیادہ کوششیں ہو گئیں۔ براہِ کرم تھوڑی دیر بعد دوبارہ کوشش کریں۔';

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
  String get failureBusy => 'سروس اس وقت مصروف ہے۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get failureServer =>
      'ہماری طرف کچھ خرابی ہو گئی۔ براہِ کرم کچھ دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get failureUnexpected => 'کچھ غلط ہو گیا۔ براہِ کرم دوبارہ کوشش کریں۔';

  @override
  String get failureRejected =>
      'یہ محفوظ نہیں ہو سکا۔ تفصیلات چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get reasonInvalidCredentials => 'ای میل یا پاس ورڈ درست نہیں۔';

  @override
  String get reasonEmailNotConfirmed =>
      'پہلے اپنی ای میل کی تصدیق کریں: ہمارا بھیجا ہوا لنک کھولیں۔';

  @override
  String get reasonEmailTaken =>
      'اس ای میل سے اکاؤنٹ پہلے سے موجود ہے۔ اس کے بجائے سائن اِن کریں۔';

  @override
  String get reasonWeakPassword =>
      'مضبوط پاس ورڈ منتخب کریں: کم از کم 10 حروف، جن میں انگریزی کے بڑے اور چھوٹے حروف اور ایک ہندسہ ہو۔';

  @override
  String get reasonSamePassword =>
      'ایسا پاس ورڈ منتخب کریں جو آپ نے پہلے استعمال نہ کیا ہو۔';

  @override
  String get reasonLastOwner =>
      'ہر پورٹ فولیو کا کم از کم ایک مالک ہونا ضروری ہے۔ پہلے کسی اور کو مالک بنائیں۔';

  @override
  String get reasonConfirmationMismatch =>
      'آپ کا لکھا ہوا نام مطابقت نہیں رکھتا۔';

  @override
  String get reasonAccountDeleted => 'یہ اکاؤنٹ حذف کیا جا رہا ہے۔';

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
    return 'آپ آف لائن ہیں۔ $time پر محفوظ کی گئی معلومات دکھائی جا رہی ہیں۔';
  }

  @override
  String comingSoonTitle(String section) {
    return '$section تیار کیا جا رہا ہے';
  }

  @override
  String get comingSoonBody => 'ایپ کا یہ حصہ اگلی اپ ڈیٹ میں آئے گا۔';

  @override
  String get configErrorTitle => 'یہ بلڈ ترتیب نہیں دیا گیا';

  @override
  String get reasonAlreadyMember => 'یہ شخص پہلے سے اس پورٹ فولیو میں شامل ہے۔';

  @override
  String get reasonMemberNotFound => 'یہ شخص اب اس پورٹ فولیو میں شامل نہیں۔';

  @override
  String get reasonInvalidRole =>
      'ان میں سے ایک کردار منتخب کریں: مالک، منیجر، اکاؤنٹنٹ یا ناظر۔';

  @override
  String get reasonInvalidEmail => 'درست ای میل ایڈریس درج کریں۔';

  @override
  String get reasonAlreadyVoided => 'یہ اندراج پہلے ہی منسوخ ہو چکا ہے۔';

  @override
  String get reasonAmountExceedsOutstanding =>
      'یہ رقم اس کرایہ داری کے واجبات سے زیادہ ہے۔';

  @override
  String get reasonChargeHasPayments =>
      'اس واجب الادا رقم کے خلاف ادائیگی وصول ہو چکی ہے۔ پہلے وہ ادائیگی منسوخ کریں۔';

  @override
  String get reasonChargeNotEditable =>
      'صرف آپ کی شامل کردہ واجب الادا رقم بدلی جا سکتی ہے۔ اسے منسوخ کر کے نئی رقم شامل کریں۔';

  @override
  String get reasonChargeVoided =>
      'یہ واجب الادا رقم منسوخ ہو چکی ہے اور اب تبدیل نہیں ہو سکتی۔';

  @override
  String get reasonDepositAlreadyUsed =>
      'اس کے بعد زرِ ضمانت استعمال ہو چکا ہے، اس لیے یہ واپس نہیں ہو سکتا۔';

  @override
  String get reasonDepositBelowReceived =>
      'زرِ ضمانت پہلے سے وصول شدہ رقم سے کم نہیں ہو سکتا۔';

  @override
  String get reasonInsufficientDeposit => 'جمع شدہ زرِ ضمانت اس رقم سے کم ہے۔';

  @override
  String get reasonDocumentEntityNotFound =>
      'جس ریکارڈ کے ساتھ یہ دستاویز تھی وہ اب موجود نہیں۔';

  @override
  String get reasonDocumentFileMissing =>
      'فائل مکمل اپ لوڈ نہیں ہوئی۔ براہِ کرم اسے دوبارہ اپ لوڈ کریں۔';

  @override
  String get reasonDocumentFilePendingDeletion =>
      'یہ فائل حذف ہو رہی ہے۔ براہِ کرم اسے دوبارہ اپ لوڈ کریں۔';

  @override
  String get reasonIdempotencyKeyReused =>
      'یہ ادائیگی مختلف تفصیلات کے ساتھ پہلے ہی درج ہو چکی ہے۔ دوبارہ کوشش سے پہلے حساب دیکھ لیں۔';

  @override
  String get reasonInvalidAmount =>
      'صفر سے زیادہ رقم درج کریں، اعشاریہ کے بعد زیادہ سے زیادہ دو ہندسے۔';

  @override
  String get reasonInvalidChargeSelection =>
      'اس کرایہ داری کی وہ واجب الادا رقوم منتخب کریں جو ابھی باقی ہیں۔';

  @override
  String get reasonInvalidDate => 'درست تاریخ منتخب کریں۔';

  @override
  String get reasonInvalidTaxWithheld =>
      'منہا شدہ ٹیکس ادائیگی سے زیادہ نہیں ہو سکتا۔';

  @override
  String get reasonInvalidTaxYear => 'درست ٹیکس سال منتخب کریں۔';

  @override
  String get reasonInvalidMethod => 'ادائیگی کا طریقہ منتخب کریں۔';

  @override
  String get reasonInvalidReason => 'کرایہ بدلنے کی وجہ منتخب کریں۔';

  @override
  String get reasonReasonRequired => 'براہِ کرم وجہ بتائیں۔';

  @override
  String get reasonLeaseHasRecords =>
      'اس کرایہ داری میں رقوم درج ہیں، اس لیے اسے حذف نہیں کیا جا سکتا۔ اس کے بجائے کرایہ داری ختم کریں۔';

  @override
  String get reasonLeaseNotActive => 'یہ کرایہ داری فعال نہیں ہے۔';

  @override
  String get reasonLeaseNotOnConnection =>
      'یہ کرایہ داری اس یوٹیلیٹی کنکشن پر نہیں ہے۔';

  @override
  String get reasonTenantArchived =>
      'یہ کرایہ دار آرکائیو میں ہے۔ پہلے انہیں بحال کریں۔';

  @override
  String get reasonUnitArchived =>
      'یہ یونٹ آرکائیو میں ہے۔ پہلے اسے بحال کریں۔';

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
  String get validationPhone => '03001234567 جیسا فون نمبر درج کریں۔';

  @override
  String get validationTypedEmail =>
      'اپنا ای میل پتہ بالکل ویسا ہی لکھیں جیسا دکھایا گیا ہے۔';

  @override
  String get accountDeletedTitle => 'آپ کا اکاؤنٹ حذف کر دیا گیا ہے';

  @override
  String get accountDeletedBody =>
      'آپ کا سائن اِن، پروفائل اور وہ پورٹ فولیوز جن کے آپ اکیلے مالک تھے، ختم ہو گئے ہیں۔ مالکِ مکان استعمال کرنے کا شکریہ۔';

  @override
  String get emailSentAgain => 'ہم نے ای میل دوبارہ بھیج دی ہے۔';

  @override
  String get checkEmailBodyNoAddress =>
      'ہم نے آپ کو ایک لنک بھیجا ہے۔ جاری رکھنے کے لیے اسے اسی ڈیوائس پر کھولیں۔ اگر چند منٹ میں نہ ملے تو اپنا اسپیم فولڈر دیکھیں۔';

  @override
  String get checkEmailResetHint =>
      'یہ لنک صرف ایک بار اور ایک گھنٹے تک کام کرتا ہے۔ اگر اس پتے سے کوئی اکاؤنٹ نہیں تو کوئی ای میل نہیں بھیجی جاتی۔';

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
      'وہ پاس ورڈ منتخب کریں جس سے آپ اب سے سائن اِن کریں گے۔';

  @override
  String get linkFailedTitle => 'یہ لنک کام نہیں کر سکا';

  @override
  String get reasonLinkExpired =>
      'اس لنک کی مدت ختم ہو چکی ہے یا یہ پہلے استعمال ہو چکا ہے۔ نیا لنک منگوائیں۔';

  @override
  String get reasonLinkInvalid =>
      'یہ سائن اِن کا درست لنک نہیں۔ ہماری بھیجی ہوئی تازہ ترین ای میل کا لنک کھولیں۔';

  @override
  String get reasonLinkOtherDevice =>
      'لنک اسی فون یا براؤزر پر کھولیں جہاں سے آپ نے اسے منگوایا تھا۔ اگر آپ اپنی ای میل کی تصدیق کر رہے تھے تو وہ ہو چکی ہے: اپنے پاس ورڈ سے سائن اِن کریں۔';

  @override
  String get reasonSignupDisabled =>
      'اس وقت نئے اکاؤنٹ نہیں بن سکتے۔ براہِ کرم کچھ دیر بعد کوشش کریں۔';

  @override
  String get reasonMfaRequired =>
      'اس اکاؤنٹ میں سائن اِن کا دوسرا مرحلہ ہے جسے یہ ایپ ابھی جانچ نہیں سکتی، اس لیے اسے یہاں سے حذف نہیں کیا جا سکتا۔';

  @override
  String get reasonDoesNotMatchAccount =>
      'یہ آپ کے اکاؤنٹ کا ای میل پتہ نہیں ہے۔';

  @override
  String get createFirstPortfolioTitle => 'اپنا پورٹ فولیو بنائیں';

  @override
  String get newPortfolioTitle => 'نیا پورٹ فولیو';

  @override
  String get createFirstPortfolioBody =>
      'پورٹ فولیو میں آپ کی جائیدادیں، کرایہ دار اور رقوم کا حساب رہتا ہے۔ اس کا نام خاندان، عمارت یا مالک کے نام پر رکھیں، مثلاً ”خان فیملی کی جائیدادیں“۔';

  @override
  String get newPortfolioBody =>
      'جن جائیدادوں کا حساب الگ رکھا جاتا ہے انہیں الگ پورٹ فولیو میں رکھیں: کسی رشتہ دار کا مکان، یا اپنے الگ حساب والا پلازہ۔ آپ اس کے مالک ہوں گے۔';

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
  String get cancelAction => 'منسوخ کریں';

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
  String get roleViewer => 'ناظر';

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
    return 'آپ کا کردار: $role';
  }

  @override
  String get settingsSummary => 'آپ کی تفصیلات، زبان، ظاہری شکل اور اکاؤنٹ';

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
    return 'اس ڈیوائس پر زبان بدل گئی، لیکن آپ کے اکاؤنٹ میں محفوظ نہیں ہو سکی۔ $reason';
  }

  @override
  String get settingsLanguageHelp =>
      'ہماری بھیجی گئی ای میلز بھی اسی زبان میں ہوں گی۔';

  @override
  String get themeLabel => 'تھیم';

  @override
  String get signedInAs => 'سائن اِن بطور';

  @override
  String get profileSection => 'آپ کی تفصیلات';

  @override
  String get profileSectionHelp =>
      'آپ کے پورٹ فولیوز کے لوگ آپ کا نام اور فون نمبر دیکھ سکتے ہیں۔';

  @override
  String get phoneLabel => 'فون نمبر';

  @override
  String get phoneHelper =>
      '03001234567 جیسا پاکستانی نمبر، یا بیرونِ ملک کا نمبر جو 00 اور ملکی کوڈ سے شروع ہو۔';

  @override
  String get saveDetailsAction => 'تفصیلات محفوظ کریں';

  @override
  String get detailsSaved => 'آپ کی تفصیلات محفوظ ہو گئی ہیں۔';

  @override
  String get textSizeTitle => 'تحریر کا سائز';

  @override
  String textSizeBody(int percent) {
    return 'آپ کے فون پر تحریر کا سائز $percent% ہے۔ ایپ اسی کے مطابق چلتی ہے؛ اسے فون کی ڈسپلے ترتیبات میں بدلیں۔';
  }

  @override
  String get textSizePreviewLabel => 'نمونہ';

  @override
  String get textSizeSampleName => 'عائشہ خان';

  @override
  String get textSizeSampleDetail => 'دکان نمبر 3، کرایہ 5 تاریخ کو واجب';

  @override
  String get deleteAccountTitle => 'اکاؤنٹ حذف کریں';

  @override
  String get deletionPreviewFailedTitle =>
      'ہم یہ نہیں دیکھ سکے کہ کیا حذف ہو گا';

  @override
  String get loadingDeletionPreview => 'دیکھا جا رہا ہے کہ کیا حذف ہو گا';

  @override
  String get deleteAccountWarningTitle => 'یہ واپس نہیں ہو سکتا';

  @override
  String get deleteAccountWarningBody =>
      'حذف شدہ ریکارڈ واپس نہیں آ سکتا، ہماری طرف سے بھی نہیں۔ جاری رکھنے سے پہلے جن رسیدوں اور گوشواروں کی آپ کو ضرورت ہے ان کی نقول رکھ لیں۔';

  @override
  String get deleteAccountWhatGoes => 'کیا حذف ہو گا';

  @override
  String get deleteAccountNoPortfolios =>
      'آپ کسی پورٹ فولیو کے اکیلے مالک نہیں، اس لیے کوئی پورٹ فولیو حذف نہیں ہو گا۔';

  @override
  String deleteAccountPortfolios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'آپ ان $count پورٹ فولیوز کے اکیلے مالک ہیں، اس لیے یہ اپنی ہر چیز سمیت حذف ہو جائیں گے: جائیدادیں، کرایہ دار، ادائیگیاں، رسیدیں اور فائلیں۔',
      one: 'آپ اس پورٹ فولیو کے اکیلے مالک ہیں، اس لیے یہ اپنی ہر چیز سمیت حذف ہو جائے گا: جائیدادیں، کرایہ دار، ادائیگیاں، رسیدیں اور فائلیں۔',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountMemberships =>
      'باقی تمام پورٹ فولیوز سے آپ کو نکال دیا جائے گا؛ وہ اور ان کا ریکارڈ ان کے مالکان کے پاس رہے گا۔';

  @override
  String get deleteAccountSignIn =>
      'آپ کا سائن اِن اور پروفائل حذف ہو جائیں گے اور آپ سائن آؤٹ ہو جائیں گے۔';

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
    return 'اپنا پاس ورڈ درج کریں، کیونکہ حذف کرنے کے لیے پچھلے $_temp0 کے اندر سائن اِن ضروری ہے، اور اپنا ای میل پتہ لکھیں۔';
  }

  @override
  String typeEmailToConfirm(String email) {
    return 'تصدیق کے لیے $email لکھیں';
  }

  @override
  String get deleteAccountConfirmAction => 'میرا اکاؤنٹ حذف کریں';

  @override
  String get doomedPortfolioOnlyYou => 'اسے صرف آپ استعمال کرتے ہیں';

  @override
  String doomedPortfolioOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اور افراد کی رسائی ختم ہو جائے گی',
      one: '1 اور شخص کی رسائی ختم ہو جائے گی',
    );
    return '$_temp0';
  }

  @override
  String get checkEmailSentTo => 'ہم نے اس پتے پر ایک لنک بھیجا ہے:';

  @override
  String get checkEmailInstructions =>
      'جاری رکھنے کے لیے اسے اسی ڈیوائس پر کھولیں۔ اگر چند منٹ میں نہ ملے تو اپنا اسپیم فولڈر دیکھیں۔';

  @override
  String get groupingLabel => 'رقوم کے ہندسوں کی گروہ بندی';

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
    return '$min سے $max تک کوئی عدد درج کریں۔';
  }

  @override
  String get validationPercent =>
      '0 سے 100 تک فیصد درج کریں، اعشاریہ کے بعد زیادہ سے زیادہ دو ہندسے۔';

  @override
  String get validationRaast =>
      '03001234567 جیسا پاکستانی موبائل نمبر درج کریں۔';

  @override
  String get validationIban =>
      'PK36 SCBL 0000 0011 2345 6702 جیسا پاکستانی IBAN درج کریں۔';

  @override
  String get linkNotOpened => 'لنک نہیں کھل سکا۔';

  @override
  String get roleOwnerHelp => 'سب کچھ، بشمول ٹیم اور ادائیگی کی تفصیلات۔';

  @override
  String get roleManagerHelp =>
      'جائیدادیں، کرایہ دار اور کرایہ داریاں سنبھالتا ہے، اور رقوم درج کرتا ہے۔';

  @override
  String get roleAccountantHelp =>
      'ادائیگیاں اور اخراجات درج کرتا ہے، اور باقی سب کچھ دیکھ سکتا ہے۔';

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
      'نام، کرایہ داری کی ابتدائی ترتیبات اور ادائیگی کی تفصیلات';

  @override
  String get teamMembersSection => 'افراد';

  @override
  String get teamInvitationsSection => 'جواب کے منتظر دعوت نامے';

  @override
  String get teamInvitationsHelp =>
      'ہر لنک صرف ایک بار، 7 دن تک، اور صرف اسی پتے کے لیے کام کرتا ہے جس پر بھیجا گیا۔';

  @override
  String memberYou(String name) {
    return '$name (آپ)';
  }

  @override
  String get memberNoName => 'بغیر نام کا رکن';

  @override
  String memberRoleAndEmail(String role, String email) {
    return '$role · $email';
  }

  @override
  String get teamLoadFailedTitle => 'ٹیم لوڈ نہیں ہو سکی';

  @override
  String get loadingTeam => 'ٹیم لوڈ ہو رہی ہے';

  @override
  String get inviteAction => 'کسی کو مدعو کریں';

  @override
  String invitationExpires(String role, String date) {
    return '$role · $date تک';
  }

  @override
  String invitationExpired(String role, String date) {
    return '$role · $date کو ختم ہو گیا';
  }

  @override
  String get invitationExpiredBadge => 'ختم ہو گیا';

  @override
  String get inviteAgainAction => 'دوبارہ مدعو کریں';

  @override
  String get revokeInvitationAction => 'دعوت نامہ منسوخ کریں';

  @override
  String revokeInvitationTitle(String email) {
    return '$email کا دعوت نامہ منسوخ کریں؟';
  }

  @override
  String get revokeInvitationBody =>
      'لنک کام کرنا چھوڑ دے گا۔ آپ انہیں بعد میں دوبارہ مدعو کر سکتے ہیں۔';

  @override
  String get invitationCancelled => 'دعوت نامہ منسوخ ہو گیا۔';

  @override
  String get memberRoleLabel => 'کردار';

  @override
  String get changeRoleAction => 'کردار بدلیں';

  @override
  String roleChanged(String name, String role) {
    return '$name اب $role ہیں۔';
  }

  @override
  String get onlyOwnerNote =>
      'ہر پورٹ فولیو کا ایک مالک ہونا ضروری ہے۔ یہ کردار بدلنے سے پہلے کسی اور کو مالک بنائیں۔';

  @override
  String get removeMemberAction => 'پورٹ فولیو سے نکالیں';

  @override
  String removeMemberTitle(String name) {
    return '$name کو نکال دیں؟';
  }

  @override
  String get removeMemberBody =>
      'ان کی اس پورٹ فولیو تک رسائی فوراً ختم ہو جائے گی۔ ان کا درج کیا ہوا سب کچھ باقی رہے گا۔';

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
      'آپ کی رسائی فوراً ختم ہو جائے گی۔ صرف کوئی مالک آپ کو دوبارہ مدعو کر سکتا ہے۔';

  @override
  String get leaveLastOwner =>
      'آپ واحد مالک ہیں۔ چھوڑنے سے پہلے کسی اور کو مالک بنائیں۔';

  @override
  String leftPortfolio(String portfolio) {
    return 'آپ نے $portfolio چھوڑ دیا۔';
  }

  @override
  String get inviteTitle => 'کسی کو مدعو کریں';

  @override
  String get inviteBody =>
      'انہیں ایک ای میل ملے گی جس کا لنک صرف ایک بار، 7 دن تک، اور صرف اسی پتے کے لیے کام کرے گا۔ آپ یہ لنک خود بھی بھیج سکتے ہیں۔';

  @override
  String get inviteEmailLabel => 'ان کا ای میل';

  @override
  String get inviteRoleLabel => 'ان کا کردار';

  @override
  String get sendInvitationAction => 'دعوت نامہ بھیجیں';

  @override
  String get invitationReadyTitle => 'دعوت نامہ تیار ہے';

  @override
  String deliverySent(String email) {
    return 'ہم نے دعوت نامہ $email کو ای میل کر دیا ہے۔';
  }

  @override
  String deliveryNotConfigured(String email) {
    return 'ای میل ترتیب نہیں دی گئی، اس لیے کچھ نہیں بھیجا گیا۔ یہ لنک $email کو خود بھیجیں۔';
  }

  @override
  String deliveryRateLimited(String email) {
    return 'پچھلے ایک گھنٹے میں اس پتے پر یا آپ کی طرف سے بہت زیادہ ای میلز گئیں، اس لیے یہ نہیں بھیجی گئی۔ یہ لنک $email کو خود بھیجیں۔';
  }

  @override
  String deliveryFailed(String email) {
    return '$email کو ای میل نہیں بھیجی جا سکی۔ یہ لنک خود بھیجیں۔';
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
  String get invitationLinkLabel => 'دعوت نامے کا لنک';

  @override
  String get copyLinkAction => 'لنک کاپی کریں';

  @override
  String get linkCopied => 'لنک کاپی ہو گیا۔';

  @override
  String get shareWhatsAppAction => 'واٹس ایپ پر بھیجیں';

  @override
  String invitationShareMessage(String portfolio, String url) {
    return 'آپ کو مالکِ مکان پر $portfolio میں شامل ہونے کی دعوت دی گئی ہے۔ شامل ہونے کے لیے یہ لنک کھولیں: $url';
  }

  @override
  String get tenancyDefaultsSection => 'نئی کرایہ داری کی ابتدائی ترتیبات';

  @override
  String get tenancyDefaultsHelp =>
      'آپ انہیں ہر کرایہ داری کے لیے بدل سکتے ہیں۔';

  @override
  String get dueDayLabel => 'کرایہ مہینے کی اس تاریخ کو واجب';

  @override
  String get dueDayHelper => '1 سے 28 تک، تاکہ ہر مہینے میں یہ تاریخ ہو۔';

  @override
  String get graceDaysLabel => 'رعایتی دن';

  @override
  String get graceDaysHelper =>
      'واجب تاریخ کے بعد کتنے دن تک کرایہ تاخیر شمار نہیں ہو گا۔';

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
  String get acceptInvitationTitle => 'دعوت نامہ';

  @override
  String get acceptingInvitation => 'آپ کا دعوت نامہ کھولا جا رہا ہے…';

  @override
  String invitationAcceptedTitle(String portfolio) {
    return '$portfolio میں خوش آمدید';
  }

  @override
  String invitationAcceptedBody(String role) {
    return 'آپ بطور $role شامل ہو گئے ہیں۔';
  }

  @override
  String get openPortfolioAction => 'پورٹ فولیو کھولیں';

  @override
  String get invitationFailedTitle => 'یہ دعوت نامہ استعمال نہیں ہو سکتا';

  @override
  String get invitationInvalidBody =>
      'یہ دعوت نامے کا درست لنک نہیں ہے۔ نیا دعوت نامہ منگوائیں۔';

  @override
  String get invitationRevokedBody =>
      'یہ دعوت نامہ منسوخ کر دیا گیا ہے۔ پورٹ فولیو کے کسی مالک سے نیا دعوت نامہ منگوائیں۔';

  @override
  String get invitationAlreadyUsedBody =>
      'یہ دعوت نامہ کسی اور اکاؤنٹ سے پہلے ہی قبول ہو چکا ہے۔ نیا دعوت نامہ منگوائیں۔';

  @override
  String get invitationExpiredBody =>
      'اس دعوت نامے کی مدت ختم ہو چکی ہے: دعوت نامے 7 دن تک کام کرتے ہیں۔ نیا دعوت نامہ منگوائیں۔';

  @override
  String get invitationEmailNotVerifiedBody =>
      'پہلے اپنا ای میل پتہ تصدیق کریں، پھر دعوت نامے کا لنک دوبارہ کھولیں۔';

  @override
  String get invitationEmailMismatchBody =>
      'یہ دعوت نامہ کسی اور ای میل پتے پر بھیجا گیا تھا۔ سائن آؤٹ کریں، پھر اسی پتے سے سائن اِن کریں یا اکاؤنٹ بنائیں جس پر یہ بھیجا گیا تھا۔';

  @override
  String get invitationUnknownBody =>
      'یہ دعوت نامہ قبول نہیں ہو سکتا۔ نیا دعوت نامہ منگوائیں۔';

  @override
  String get noInvitationBody =>
      'اس ڈیوائس پر کوئی دعوت نامہ منتظر نہیں۔ دعوت نامے کی ای میل میں موجود لنک کھولیں۔';

  @override
  String get invitationNotAcceptedTitle => 'دعوت نامہ نہیں کھل سکا';

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
  String get invitationWorksUntil => 'کب تک کارآمد';

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
    return '$province: ہر کرایہ داری کرایہ دار کے رہائش اختیار کرنے کے $days کے اندر پولیس میں درج کروائیں۔';
  }

  @override
  String policeHintAgreement(String province, String days) {
    return '$province: ہر کرایہ داری معاہدے پر دستخط کے $days کے اندر پولیس میں درج کروائیں۔';
  }

  @override
  String policeHintReminder(String province) {
    return '$province: ایپ کے علم میں کوئی قانون آخری تاریخ مقرر نہیں کرتا۔ ایپ کرایہ دار کے رہائش اختیار کرنے کے ایک دن بعد کرایہ داری پولیس میں درج کروانے کی یاد دہانی کرواتی ہے۔';
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
  String get occupancyUpcoming => 'کرایہ داری جلد شروع';

  @override
  String get occupancyVacant => 'خالی';

  @override
  String occupancyVacantSince(String date) {
    return '$date سے خالی';
  }

  @override
  String get occupancyUnavailable => 'دستیاب نہیں';

  @override
  String get occupancyArchived => 'آرکائیو شدہ';

  @override
  String get occupancyUnknown => 'صورتِ حال نامعلوم';

  @override
  String get addPropertyAction => 'جائیداد شامل کریں';

  @override
  String get propertiesEmptyTitle => 'ابھی کوئی جائیداد نہیں';

  @override
  String get propertiesEmptyBody =>
      'کوئی مکان، پلازہ یا پلاٹ شامل کریں، پھر اس کے وہ پورشن، فلیٹ یا دکانیں جو آپ کرائے پر دیتے ہیں۔';

  @override
  String get archivedPropertiesEmpty => 'کوئی آرکائیو شدہ جائیداد نہیں۔';

  @override
  String get archivedPropertiesEmptyBody =>
      'آپ کی آرکائیو کی گئی جائیدادیں اپنی تاریخ سمیت یہاں رہتی ہیں۔';

  @override
  String get filterInUse => 'زیرِ استعمال';

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
  String get editPropertyTitle => 'جائیداد میں ترمیم';

  @override
  String get propertySectionBasics => 'جائیداد';

  @override
  String get propertySectionLocation => 'یہ کہاں ہے';

  @override
  String get propertySectionSize => 'رقبہ';

  @override
  String get propertySectionValue => 'مالیت';

  @override
  String get propertyNameLabel => 'نام';

  @override
  String get propertyNameHelper =>
      'جیسے آپ اسے پکارتے ہیں، مثلاً گلبرگ والا مکان یا صدر کی دکانیں۔';

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
      'اسی سے لاگو قواعد طے ہوتے ہیں، مثلاً پولیس میں اندراج۔';

  @override
  String get plotSizeLabel => 'پلاٹ کا رقبہ';

  @override
  String get plotUnitLabel => 'پیمائش کی اکائی';

  @override
  String get coveredAreaLabel => 'تعمیر شدہ رقبہ (مربع فٹ)';

  @override
  String get yearBuiltLabel => 'سنِ تعمیر';

  @override
  String get purchasePriceLabel => 'قیمتِ خرید';

  @override
  String get purchasedOnLabel => 'تاریخِ خرید';

  @override
  String get estimatedValueLabel => 'اندازاً مالیت';

  @override
  String get valueEstimatedOnLabel => 'مالیت کا اندازہ کب لگایا';

  @override
  String get propertyTaxRefLabel => 'پراپرٹی ٹیکس نمبر';

  @override
  String get notesLabel => 'نوٹس';

  @override
  String get validationPositiveNumber =>
      '0 سے بڑا عدد درج کریں، اعشاریہ کے بعد زیادہ سے زیادہ دو ہندسے۔';

  @override
  String get validationPlotUnit => 'پلاٹ کے رقبے کی اکائی منتخب کریں۔';

  @override
  String get validationAmount => '25,000 جیسی رقم درج کریں۔';

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
  String get editAction => 'ترمیم کریں';

  @override
  String get archiveAction => 'آرکائیو کریں';

  @override
  String get restoreAction => 'دوبارہ استعمال میں لائیں';

  @override
  String get deleteAction => 'حذف کریں';

  @override
  String archivedBanner(String date) {
    return '$date کو آرکائیو کیا گیا۔ اس کی تاریخ محفوظ ہے؛ تبدیلی کے لیے اسے دوبارہ استعمال میں لائیں۔';
  }

  @override
  String archivePropertyTitle(String name) {
    return '$name آرکائیو کریں؟';
  }

  @override
  String get archivePropertyBody =>
      'یہ آپ کی فہرستوں سے ہٹ جائے گی لیکن اس کے یونٹ، کرایہ داریاں اور رقوم محفوظ رہیں گی۔ آپ اسے بعد میں دوبارہ استعمال میں لا سکتے ہیں۔';

  @override
  String propertyArchived(String name) {
    return '$name آرکائیو ہو گئی۔';
  }

  @override
  String propertyRestored(String name) {
    return '$name دوبارہ استعمال میں ہے۔';
  }

  @override
  String deletePropertyTitle(String name) {
    return '$name حذف کریں؟';
  }

  @override
  String get deletePropertyBody =>
      'صرف غلطی سے شامل کی گئی جائیداد کے لیے: یہ اپنے یونٹس سمیت ہمیشہ کے لیے حذف ہو جائے گی۔ جس جائیداد کی کرایہ داریاں یا اخراجات ہوں وہ حذف نہیں ہو سکتی؛ اسے آرکائیو کریں۔';

  @override
  String typeToConfirm(String name) {
    return 'تصدیق کے لیے $name لکھیں';
  }

  @override
  String propertyDeleted(String name) {
    return '$name حذف ہو گئی۔';
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
      'کوئی کرایہ داری یا خرچ ابھی اس سے منسلک ہے، اس لیے یہ حذف نہیں ہو سکتا۔ اس کے بجائے اسے آرکائیو کریں۔';

  @override
  String get newUnitTitle => 'نیا یونٹ';

  @override
  String get editUnitTitle => 'یونٹ میں ترمیم';

  @override
  String get unitLabelLabel => 'نام یا نمبر';

  @override
  String get unitLabelHelper => 'مثلاً گراؤنڈ فلور، فلیٹ 2 یا دکان 5۔';

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
  String get askingRentLabel => 'طلب کردہ کرایہ';

  @override
  String get askingRentHelper => 'آپ اس کا ماہانہ کتنا کرایہ مانگتے ہیں۔';

  @override
  String askingRentValue(String rent) {
    return 'طلب کردہ $rent';
  }

  @override
  String get availableLabel => 'کرائے کے لیے دستیاب';

  @override
  String get availableHelp =>
      'مرمت کے دوران یا جب آپ خود اس میں رہیں تو بند کر دیں۔';

  @override
  String get unitPropertyLabel => 'جائیداد';

  @override
  String get occupancyLabel => 'رہائش کی صورتِ حال';

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
      'یہ آپ کی فہرستوں سے ہٹ جائے گا لیکن اس کی کرایہ داریاں اور رقوم محفوظ رہیں گی۔ اگر کرایہ داری ختم ہو چکی ہے تو پہلے اسے ختم کریں۔';

  @override
  String unitArchived(String name) {
    return '$name آرکائیو ہو گیا۔';
  }

  @override
  String unitRestored(String name) {
    return '$name دوبارہ استعمال میں ہے۔';
  }

  @override
  String deleteUnitTitle(String name) {
    return '$name حذف کریں؟';
  }

  @override
  String get deleteUnitBody =>
      'صرف غلطی سے شامل کیے گئے یونٹ کے لیے: یہ ہمیشہ کے لیے حذف ہو جائے گا۔ جس یونٹ کی کرایہ داریاں یا اخراجات ہوں وہ حذف نہیں ہو سکتا؛ اسے آرکائیو کریں۔';

  @override
  String unitDeleted(String name) {
    return '$name حذف ہو گیا۔';
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
  String get tenantKindIndividual => 'فرد';

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
  String get searchTenantsHint => 'نام، فون یا شناختی کارڈ سے تلاش کریں';

  @override
  String get tenantsEmptyTitle => 'ابھی کوئی کرایہ دار نہیں';

  @override
  String get tenantsEmptyBody =>
      'وہ افراد یا کاروبار شامل کریں جو آپ سے کرائے پر لیتے ہیں، پھر کسی یونٹ سے ان کی کرایہ داری شروع کریں۔';

  @override
  String get archivedTenantsEmpty => 'کوئی آرکائیو شدہ کرایہ دار نہیں۔';

  @override
  String get archivedTenantsEmptyBody =>
      'آپ کے آرکائیو کیے گئے کرایہ دار اپنی تاریخ سمیت یہاں رہتے ہیں۔';

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
  String get editTenantTitle => 'کرایہ دار میں ترمیم';

  @override
  String get tenantSectionWho => 'یہ کون ہیں';

  @override
  String get tenantSectionIdentity => 'شناخت';

  @override
  String get tenantSectionContact => 'رابطہ';

  @override
  String get tenantSectionWork => 'کام اور پتے';

  @override
  String get tenantSectionEmergency => 'ہنگامی رابطہ';

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
  String get cnicHelper => 'کارڈ پر درج 13 ہندسے۔';

  @override
  String get validationCnic =>
      'شناختی کارڈ کے 13 ہندسے درج کریں، جیسے 35202-1234567-1۔';

  @override
  String get cnicExpiryLabel => 'شناختی کارڈ کی میعاد';

  @override
  String get cnicExpired => 'شناختی کارڈ کی میعاد ختم';

  @override
  String get ntnLabel => 'این ٹی این';

  @override
  String get validationNtn =>
      'این ٹی این ویسا ہی درج کریں جیسا جاری ہوا، 6 سے 15 حروف، ہندسے یا ڈیش۔';

  @override
  String get altPhoneLabel => 'دوسرا فون';

  @override
  String get occupationLabel => 'پیشہ';

  @override
  String get employerLabel => 'آجر';

  @override
  String get permanentAddressLabel => 'مستقل پتہ';

  @override
  String get previousAddressLabel => 'سابقہ پتہ';

  @override
  String get contactNameLabel => 'نام';

  @override
  String get contactRelationLabel => 'رشتہ';

  @override
  String referenceLabel(int number) {
    return 'حوالہ $number';
  }

  @override
  String get householdSizeLabel => 'رہنے والے افراد';

  @override
  String get withholdingTaxLabel => 'ود ہولڈنگ ٹیکس کاٹتے ہیں';

  @override
  String get withholdingTaxHelp =>
      'کمپنیاں اور سرکاری ادارے ادا کیے گئے کرائے سے سیکشن 155 کے تحت ٹیکس کاٹتے ہیں۔';

  @override
  String get consentLabel =>
      'میں نے کرایہ دار کو بتایا کہ کون سی تفصیلات رکھی جاتی ہیں اور کیوں';

  @override
  String get consentNoteLabel => 'انہوں نے کس بات پر رضامندی دی';

  @override
  String consentRecorded(String date) {
    return 'رضامندی $date کو درج کی گئی';
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
      'یہ آپ کی فہرستوں سے ہٹ جائیں گے لیکن ان کی کرایہ داریاں، ادائیگیاں اور رسیدیں محفوظ رہیں گی۔ آپ انہیں بعد میں دوبارہ استعمال میں لا سکتے ہیں۔';

  @override
  String tenantArchived(String name) {
    return '$name آرکائیو ہو گئے۔';
  }

  @override
  String tenantRestored(String name) {
    return '$name دوبارہ استعمال میں ہیں۔';
  }

  @override
  String deleteTenantTitle(String name) {
    return '$name کو حذف کریں؟';
  }

  @override
  String get deleteTenantBody =>
      'صرف غلطی سے شامل کیے گئے کرایہ دار کے لیے: ان کی تفصیلات ہمیشہ کے لیے حذف ہو جائیں گی۔ جس کرایہ دار کی کرایہ داری ہو وہ حذف نہیں ہو سکتا؛ انہیں آرکائیو کریں۔';

  @override
  String tenantDeleted(String name) {
    return '$name حذف ہو گئے۔';
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
  String get editTenancyTitle => 'کرایہ داری کی شرائط میں ترمیم';

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
  String get validationChooseTenant => 'کرایہ دار منتخب کریں۔';

  @override
  String get noTenantsToChoose =>
      'پہلے کرایہ دار شامل کریں: منتخب کرنے کے لیے کوئی کرایہ دار نہیں۔';

  @override
  String get leaseSectionWho => 'کون اور کہاں';

  @override
  String get leaseSectionTerm => 'مدت';

  @override
  String get leaseSectionRent => 'کرایہ اور زرِ ضمانت';

  @override
  String get leaseSectionLateFee => 'تاخیر جرمانہ';

  @override
  String get leaseSectionAgreement => 'معاہدہ';

  @override
  String get leaseSectionPolice => 'پولیس میں اندراج';

  @override
  String get leaseSectionOther => 'دیگر شرائط';

  @override
  String get moveInLabel => 'رہائش کی تاریخ';

  @override
  String get termLabel => 'مدت';

  @override
  String get term11 => '11 مہینے';

  @override
  String get term12 => '12 مہینے';

  @override
  String get termCustom => 'کسی تاریخ تک';

  @override
  String get termPeriodic => 'ماہ بہ ماہ';

  @override
  String get endsOnLabel => 'اختتام کی تاریخ';

  @override
  String get validationEndAfterStart =>
      'رہائش کی تاریخ یا اس کے بعد کی تاریخ منتخب کریں۔';

  @override
  String get monthlyRentLabel => 'ماہانہ کرایہ';

  @override
  String get validationRent => 'کرایہ درج کریں، 0 سے زیادہ رقم۔';

  @override
  String get depositLabel => 'زرِ ضمانت';

  @override
  String get incrementEveryLabel => 'اضافہ ہر (مہینے)';

  @override
  String get lateFeeLabel => 'تاخیر جرمانہ';

  @override
  String get lateFeeNone => 'کوئی نہیں';

  @override
  String get lateFeeFlat => 'مقررہ رقم';

  @override
  String get lateFeePercent => 'تاخیر شدہ کرائے کا فیصد';

  @override
  String get lateFeeDaily => 'ہر دن کی تاخیر پر رقم';

  @override
  String get lateFeeAmountLabel => 'جرمانہ';

  @override
  String get lateFeePercentLabel => 'جرمانہ (%)';

  @override
  String get lateFeeCapLabel => 'زیادہ سے زیادہ';

  @override
  String get lateFeeHelp => 'رعایتی دن گزرنے کے بعد لاگو ہوتا ہے۔';

  @override
  String get noticeDaysLabel => 'نوٹس کی مدت (دن)';

  @override
  String get prorateLabel => 'پہلے مہینے کے صرف رہائش کے دنوں کا کرایہ';

  @override
  String get prorateHelp => 'جب کرایہ دار مہینے کی پہلی تاریخ کے بعد آئے۔';

  @override
  String get billingStartsLabel => 'بلنگ کی ابتدا';

  @override
  String get billingStartsHelp =>
      'ایپ سے پہلے شروع ہونے والی کرایہ داری کے لیے: وہ پہلا دن جس سے ایپ بل بنائے۔';

  @override
  String get agreementSignedLabel => 'معاہدے پر دستخط کی تاریخ';

  @override
  String get eStampNumberLabel => 'ای اسٹامپ نمبر';

  @override
  String get eStampAmountLabel => 'ای اسٹامپ کی رقم';

  @override
  String get permittedUseLabel => 'اجازت شدہ استعمال';

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
  String get policeStatusLabel => 'صورتِ حال';

  @override
  String get policeNotRequired => 'ضروری نہیں';

  @override
  String get policePending => 'ابھی درج نہیں';

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
  String get policeFeeLabel => 'ادا کردہ فیس';

  @override
  String policeLegalDeadline(String date) {
    return 'قانونی آخری تاریخ: $date';
  }

  @override
  String policeReminderDate(String date) {
    return 'ایپ کی یاد دہانی: $date';
  }

  @override
  String get policeReminderNote =>
      'ایپ کے علم میں یہاں کوئی قانون آخری تاریخ مقرر نہیں کرتا: یہ صرف یاد دہانی ہے۔';

  @override
  String get policeLate => 'آخری تاریخ گزر چکی: ابھی درج کروائیں۔';

  @override
  String get openPortalAction => 'اندراج کی ویب سائٹ کھولیں';

  @override
  String get utilitiesNoteLabel => 'یوٹیلیٹیز';

  @override
  String tenancyStarted(String tenant) {
    return '$tenant کی کرایہ داری شروع ہو گئی۔';
  }

  @override
  String get tenancySaved => 'کرایہ داری کی شرائط محفوظ ہو گئیں۔';

  @override
  String get reasonLeaseOverlap =>
      'ان تاریخوں میں یونٹ پہلے سے کرائے پر ہے۔ پہلے دوسری کرایہ داری ختم کریں، یا دوسری تاریخیں منتخب کریں۔';

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
  String get periodicValue => 'ماہ بہ ماہ';

  @override
  String get occupantsSection => 'ساتھ رہنے والے';

  @override
  String get occupantsHelp =>
      'کرایہ دار کے ساتھ رہنے والے بالغ افراد، پولیس میں اندراج کے لیے ضروری۔';

  @override
  String get addOccupantAction => 'فرد شامل کریں';

  @override
  String get occupantTitle => 'ساتھ رہنے والا فرد';

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
  String get removeOccupantBody => 'انہیں اس کرایہ داری سے ہٹا دیا جائے گا۔';

  @override
  String get noOccupants => 'ابھی کوئی شامل نہیں۔';

  @override
  String get rentHistorySection => 'کرائے کی تاریخ';

  @override
  String rentFrom(String month) {
    return '$month سے';
  }

  @override
  String get rentReasonInitial => 'ابتدائی کرایہ';

  @override
  String get rentReasonAnnualIncrement => 'سالانہ اضافہ';

  @override
  String get rentReasonRenegotiation => 'باہمی رضامندی سے تبدیلی';

  @override
  String get rentReasonCorrection => 'تصحیح';

  @override
  String get changeRentAction => 'کرایہ تبدیل کریں';

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
    return 'طے شدہ $percent% پر، 100 روپے تک گول: $rent';
  }

  @override
  String get useSuggestionAction => 'یہی رکھیں';

  @override
  String get changeRentHelp =>
      'اس مہینے اور بعد کا غیر ادا شدہ کرایہ نئی رقم پر ہو جائے گا؛ ادا شدہ مہینوں کی رقم وہی رہے گی۔';

  @override
  String rentChanged(String rent, String month) {
    return '$month سے کرایہ $rent ہو گیا۔';
  }

  @override
  String get endTenancyAction => 'کرایہ داری ختم کریں';

  @override
  String get movedOutLabel => 'مکان خالی کرنے کی تاریخ';

  @override
  String get endTermCompleted => 'مدت پوری ہو گئی';

  @override
  String get endTenantMovedOut => 'کرایہ دار چلے گئے';

  @override
  String get endEviction => 'بے دخلی';

  @override
  String get endMutualAgreement => 'باہمی رضامندی';

  @override
  String get endTenancyExplain =>
      'مکان خالی کرنے کے مہینے تک کا کرایہ لگے گا۔ بعد کے ہر مہینے کا کرایہ اور اس کے خودکار تاخیر جرمانے منسوخ ہو جائیں گے، ادا شدہ ہوں یا نہیں۔ ان کی ادا کی گئی رقم آزاد ہو کر اس کرایہ داری کے دوسرے واجبات میں لگ جائے گی؛ جو بچے وہ کرایہ دار کا کریڈٹ رہے گا، واپسی کے لیے۔ یونٹ خالی ہو جائے گا۔';

  @override
  String get tenancyEnded => 'کرایہ داری ختم ہو گئی۔';

  @override
  String get endedOnLabel => 'ختم ہونے کی تاریخ';

  @override
  String get deleteTenancyTitle => 'یہ کرایہ داری حذف کریں؟';

  @override
  String get deleteTenancyBody =>
      'صرف غلطی سے درج کی گئی کرایہ داری کے لیے: یہ اپنے بنائے گئے واجبات سمیت حذف ہو گی، بشرطیکہ کچھ ادا، معاف یا منسوخ نہ ہوا ہو۔ ورنہ کرایہ داری ختم کریں۔';

  @override
  String get tenancyDeleted => 'کرایہ داری حذف ہو گئی۔';

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
  String get documentsSection => 'دستاویزات';

  @override
  String get documentsSectionHelp =>
      'تصاویر اور پی ڈی ایف، جنہیں صرف اس پورٹ فولیو کی ٹیم دیکھ سکتی ہے۔';

  @override
  String get addDocumentAction => 'دستاویز شامل کریں';

  @override
  String get documentsEmpty => 'ابھی کوئی دستاویز نہیں۔';

  @override
  String get documentsEmptyTenant =>
      'ابھی کوئی دستاویز نہیں۔ شناختی کارڈ کے سامنے اور پچھلے رخ کی تصاویر شامل کریں۔';

  @override
  String get documentsEmptyLease =>
      'ابھی کوئی دستاویز نہیں۔ دستخط شدہ معاہدہ اور پولیس میں اندراج شامل کریں۔';

  @override
  String get documentsEmptyUnit =>
      'ابھی کوئی دستاویز نہیں۔ یونٹ اور اس کے میٹروں کی تصاویر شامل کریں۔';

  @override
  String get documentsEmptyProperty =>
      'ابھی کوئی دستاویز نہیں۔ جائیداد کے کاغذات اور تصاویر شامل کریں۔';

  @override
  String get loadingDocuments => 'دستاویزات لوڈ ہو رہی ہیں';

  @override
  String get documentsLoadFailedTitle => 'دستاویزات لوڈ نہیں ہو سکیں';

  @override
  String get documentKindCnicFront => 'شناختی کارڈ، سامنے کا رخ';

  @override
  String get documentKindCnicBack => 'شناختی کارڈ، پچھلا رخ';

  @override
  String get documentKindPhoto => 'تصویر';

  @override
  String get documentKindTenancyAgreement => 'کرایہ داری کا معاہدہ';

  @override
  String get documentKindPoliceRegistration => 'پولیس میں اندراج';

  @override
  String get documentKindRentRegistration => 'کرایہ داری کا سرکاری اندراج';

  @override
  String get documentKindUtilityBill => 'یوٹیلیٹی بل';

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
  String get chooseFileAction => 'فائل منتخب کریں';

  @override
  String get chooseAnotherFileAction => 'کوئی اور فائل منتخب کریں';

  @override
  String get addDocumentHelp =>
      'تصویر، یا ‎10 MB‎ تک کی پی ڈی ایف شامل کریں۔ تصاویر پہلے چھوٹی کر دی جاتی ہیں۔';

  @override
  String get preparingFile => 'فائل تیار کی جا رہی ہے';

  @override
  String get photoRecovered =>
      'کیمرہ کھلا تھا کہ ایپ بند ہو گئی، لیکن آپ کی تصویر محفوظ رہی۔ اسے دیکھ لیں، پھر اپ لوڈ کریں۔';

  @override
  String get documentKindLabel => 'قسم';

  @override
  String get documentNameLabel => 'نام';

  @override
  String get documentNameHelp =>
      'خالی چھوڑنے پر اس کا نام اس کی قسم پر رکھا جائے گا۔';

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
    return '$name حذف ہو گئی۔';
  }

  @override
  String get openDocumentAction => 'کھولیں';

  @override
  String get downloadDocumentAction => 'ڈاؤن لوڈ کریں';

  @override
  String get editDocumentAction => 'نام یا قسم بدلیں';

  @override
  String deleteDocumentTitle(String name) {
    return '$name حذف کریں؟';
  }

  @override
  String get deleteDocumentBody =>
      'یہ دستاویز اور اس کی فائل اس پورٹ فولیو میں سب کے لیے حذف ہو جائیں گی۔ یہ عمل واپس نہیں ہو سکتا۔';

  @override
  String get documentAddedOnLabel => 'شامل کرنے کی تاریخ';

  @override
  String get documentFileLabel => 'فائل';

  @override
  String get documentPreviewLabel => 'تصویر کا پیش منظر';

  @override
  String get documentNameTooLong => 'یہ نام بہت لمبا ہے۔ اسے مختصر کریں۔';

  @override
  String get reasonFileTooLarge =>
      'یہ فائل ‎10 MB‎ سے بڑی ہے۔ چھوٹی فائل منتخب کریں، یا اس کی تصویر کھینچ لیں۔';

  @override
  String get reasonFileTypeNotAllowed =>
      'صرف تصاویر (JPEG، PNG، WebP یا HEIC) اور پی ڈی ایف شامل کی جا سکتی ہیں۔';

  @override
  String get reasonFileUnreadable =>
      'یہ فائل پڑھی نہیں جا سکی۔ کوئی اور فائل منتخب کریں، یا کاغذ کی تصویر کھینچ لیں۔';

  @override
  String get reasonPickerAccessDenied =>
      'اس ایپ کو کیمرہ یا آپ کی فائلیں استعمال کرنے کی اجازت نہیں۔ فون کی سیٹنگز میں اجازت دیں۔';

  @override
  String get chargeKindRent => 'کرایہ';

  @override
  String get chargeKindDeposit => 'زرِ ضمانت';

  @override
  String get chargeKindElectricity => 'بجلی';

  @override
  String get chargeKindGas => 'گیس';

  @override
  String get chargeKindWater => 'پانی';

  @override
  String get chargeKindInternet => 'انٹرنیٹ';

  @override
  String get chargeKindMaintenance => 'مرمت و دیکھ بھال';

  @override
  String get chargeKindSociety => 'سوسائٹی چارجز';

  @override
  String get chargeKindLateFee => 'تاخیر جرمانہ';

  @override
  String get chargeKindDamages => 'نقصانات';

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
  String get methodDeposit => 'زرِ ضمانت سے';

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
      other: '$days دن کی تاخیر',
      one: '1 دن کی تاخیر',
    );
    return '$_temp0';
  }

  @override
  String get dueToday => 'آج واجب';

  @override
  String dueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن میں واجب',
      one: 'کل واجب',
    );
    return '$_temp0';
  }

  @override
  String dueOn(String date) {
    return '$date کو واجب';
  }

  @override
  String get chargePaid => 'ادا شدہ';

  @override
  String get chargeWaived => 'معاف';

  @override
  String get chargeVoided => 'منسوخ';

  @override
  String get loadingReceivables => 'کس پر کتنا واجب ہے، لوڈ ہو رہا ہے';

  @override
  String get receivablesLoadFailedTitle => 'واجب الادا رقوم لوڈ نہیں ہو سکیں';

  @override
  String get receivablesEmptyTitle => 'ابھی کوئی رقم واجب الادا نہیں';

  @override
  String get receivablesEmptyBody =>
      'آپ کی شروع کی گئی ہر کرایہ داری کا کرایہ خود بخود لگتا ہے۔ کرایہ داروں کے واجبات اور ادائیگیاں یہاں نظر آئیں گی۔';

  @override
  String get totalOwedLabel => 'واجب الادا';

  @override
  String get totalOverdueLabel => 'تاخیر شدہ';

  @override
  String get totalCreditLabel => 'کریڈٹ';

  @override
  String get whoOwesSection => 'کس پر کتنا واجب ہے';

  @override
  String get whoOwesHelp => 'سب سے زیادہ تاخیر والے پہلے۔';

  @override
  String get nobodyOwes => 'اس وقت کسی پر کچھ واجب نہیں۔';

  @override
  String get settledSection => 'بے باق یا کریڈٹ میں';

  @override
  String lastPaidOn(String date) {
    return 'آخری ادائیگی $date';
  }

  @override
  String owesAmount(String amount) {
    return 'واجب $amount';
  }

  @override
  String overdueOldest(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن',
      one: '1 دن',
    );
    return '$amount تاخیر شدہ، سب سے پرانا $_temp0';
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
  String get statementAction => 'کرایہ دار کا گوشوارہ';

  @override
  String get owedNowLabel => 'اب واجب الادا';

  @override
  String owedNowValue(String amount) {
    return 'اب واجب الادا: $amount';
  }

  @override
  String get overdueLabel => 'تاخیر شدہ';

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
      'کرایہ دار نے پیشگی ادائیگی کی ہے۔ یہ کریڈٹ اگلے واجبات میں خود بخود لگ جائے گا۔';

  @override
  String get creditExplainEnded =>
      'کرایہ داری ختم ہو چکی ہے اور رقم بچی ہوئی ہے۔ یہ کرایہ دار کو واپس کریں، یا جس ادائیگی سے آئی ہے اسے منسوخ کریں۔';

  @override
  String creditHeldEnded(String amount) {
    return 'کرایہ داری ختم ہو چکی ہے اور کرایہ دار کا $amount کریڈٹ باقی ہے۔';
  }

  @override
  String get openCreditPaymentAction => 'ادائیگی کھولیں';

  @override
  String get recordPaymentAction => 'ادائیگی درج کریں';

  @override
  String get remindAction => 'واٹس ایپ پر یاد دہانی';

  @override
  String get openTenancyAction => 'کرایہ داری کی تفصیلات';

  @override
  String get openDuesSection => 'واجب الادا';

  @override
  String get openDuesHelp => 'ہر غیر ادا شدہ واجب، سب سے پرانا پہلے۔';

  @override
  String get addChargeAction => 'واجب شامل کریں';

  @override
  String get noOpenDues => 'کچھ واجب نہیں۔';

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
    return '$amount ٹیکس منہا';
  }

  @override
  String get allDuesSection => 'تمام واجبات';

  @override
  String get allDuesHelp => 'ادا شدہ، معاف اور منسوخ بھی، تازہ ترین پہلے۔';

  @override
  String get noDuesYet => 'ابھی کوئی واجب نہیں۔';

  @override
  String get moneySection => 'حساب';

  @override
  String get openLedgerAction => 'حساب کھولیں';

  @override
  String get amountLabel => 'رقم';

  @override
  String get paidLabel => 'ادا شدہ';

  @override
  String get stillOwedLabel => 'ابھی واجب';

  @override
  String get dueDateLabel => 'واجب الادا تاریخ';

  @override
  String get chargeNoteLabel => 'نوٹ';

  @override
  String get waiveReasonLabel => 'معاف کرنے کی وجہ';

  @override
  String get voidReasonLabel => 'منسوخ کرنے کی وجہ';

  @override
  String get editChargeAction => 'واجب میں ترمیم';

  @override
  String get waiveChargeAction => 'معاف کریں';

  @override
  String get voidChargeAction => 'واجب منسوخ کریں';

  @override
  String get voidChargeHasPayments =>
      'اس واجب کی ادائیگی وصول ہو چکی ہے، اس لیے اسے منسوخ نہیں کیا جا سکتا۔ پہلے وہ ادائیگی منسوخ کریں، یا باقی رقم معاف کریں۔';

  @override
  String get chargeSaved => 'واجب محفوظ ہو گیا۔';

  @override
  String get chargeAmountFixed =>
      'کرایہ، تاخیر جرمانہ اور زرِ ضمانت کی رقم کرایہ داری کی شرائط سے طے ہوتی ہے۔ کرایہ تبدیل کریں، یا یہ واجب منسوخ کر کے نیا شامل کریں۔';

  @override
  String amountAtLeast(String amount) {
    return 'کم از کم $amount، جو پہلے ہی ادا یا معاف ہو چکا۔';
  }

  @override
  String amountAtMost(String amount) {
    return 'زیادہ سے زیادہ $amount۔';
  }

  @override
  String get chargeKindLabel => 'کس مد میں';

  @override
  String get chargeMonthLabel => 'برائے مہینہ';

  @override
  String get chargeMonthHelp => 'جس مہینے کا بل ہے، اگر ہو۔';

  @override
  String get noMonthOption => 'کوئی مہینہ نہیں';

  @override
  String chargeAdded(String kind) {
    return '$kind شامل ہو گیا۔';
  }

  @override
  String get waiveExplain =>
      'معاف کرنے سے باقی واجب رقم (یا جتنی آپ لکھیں) معاف ہو جاتی ہے۔ یہ واجب آپ کی بتائی گئی وجہ کے ساتھ، معاف شدہ کے طور پر حساب میں رہے گا۔';

  @override
  String get voidChargeExplain =>
      'منسوخ کرنے سے غلطی سے درج کیا گیا واجب، اپنے غیر ادا شدہ تاخیر جرمانے سمیت، ختم ہو جاتا ہے۔ یہ آپ کی بتائی گئی وجہ کے ساتھ، منسوخ شدہ کے طور پر حساب میں رہے گا۔';

  @override
  String get waiveAmountLabel => 'معاف کی جانے والی رقم';

  @override
  String waiveAmountHelp(String amount) {
    return 'پوری $amount معاف کرنے کے لیے خالی چھوڑ دیں۔';
  }

  @override
  String get reasonLabel => 'وجہ';

  @override
  String get chargeWaivedDone => 'واجب معاف ہو گیا۔';

  @override
  String get chargeVoidedDone => 'واجب منسوخ ہو گیا۔';

  @override
  String get depositSection => 'زرِ ضمانت';

  @override
  String get depositAgreedLabel => 'طے شدہ';

  @override
  String get depositReceivedLabel => 'وصول شدہ';

  @override
  String get depositAppliedLabel => 'واجبات میں استعمال';

  @override
  String get depositRefundedLabel => 'واپس کیا گیا';

  @override
  String get depositHeldLabel => 'جمع زرِ ضمانت';

  @override
  String get depositSettleAfterEnd =>
      'کرایہ داری ختم ہو چکی ہے اور زرِ ضمانت ابھی آپ کے پاس ہے۔ اسے واجبات میں استعمال کریں، پھر باقی رقم واپس کریں۔';

  @override
  String get depositTenancyActive =>
      'یہ کرایہ داری ابھی جاری ہے۔ زرِ ضمانت عموماً کرایہ دار کے جانے پر واجبات میں استعمال یا واپس کیا جاتا ہے۔';

  @override
  String get applyDepositAction => 'واجبات میں استعمال کریں';

  @override
  String get refundDepositAction => 'زرِ ضمانت واپس کریں';

  @override
  String refundOf(String amount) {
    return '$amount کی واپسی';
  }

  @override
  String voidedBecause(String reason) {
    return 'منسوخ: $reason';
  }

  @override
  String get voidRefundAction => 'واپسی منسوخ کریں';

  @override
  String get voidRefundExplain =>
      'غلطی سے درج کی گئی واپسی منسوخ کرنے سے وہ رقم دوبارہ آپ کے پاس جمع شمار ہو گی۔ یہ منسوخ شدہ کے طور پر حساب میں رہے گی۔';

  @override
  String get refundVoided => 'واپسی منسوخ ہو گئی۔';

  @override
  String get applyDepositExplain =>
      'زرِ ضمانت سے واجبات ادا ہوں گے، سب سے پرانا پہلے، اور کرایہ دار کو اس کی رسید ملے گی۔';

  @override
  String applyDepositHelp(String held, String owed) {
    return 'جمع $held؛ واجب $owed۔';
  }

  @override
  String get appliedOnLabel => 'استعمال کی تاریخ';

  @override
  String depositApplied(String amount) {
    return 'زرِ ضمانت میں سے $amount واجبات میں لگ گئے۔';
  }

  @override
  String depositHeldHelp(String amount) {
    return 'آپ کے پاس $amount جمع ہیں۔';
  }

  @override
  String get refundedOnLabel => 'واپسی کی تاریخ';

  @override
  String depositRefunded(String amount) {
    return 'زرِ ضمانت میں سے $amount واپس کر دیے گئے۔';
  }

  @override
  String get recordPaymentTitle => 'ادائیگی درج کریں';

  @override
  String get paymentSectionMoney => 'کیا وصول ہوا';

  @override
  String get paymentSectionTax => 'منہا شدہ ٹیکس';

  @override
  String get paymentSectionSettle => 'یہ کس کی ادائیگی ہے';

  @override
  String get amountReceivedLabel => 'وصول شدہ رقم';

  @override
  String useOwedAction(String amount) {
    return 'واجب $amount لکھیں';
  }

  @override
  String get receivedOnLabel => 'وصولی کی تاریخ';

  @override
  String get paymentReferenceLabel => 'حوالہ نمبر';

  @override
  String get paymentReferenceHelp => 'ٹرانزیکشن آئی ڈی یا چیک نمبر، اگر ہو۔';

  @override
  String get taxWithheldSwitch => 'کرایہ دار نے انکم ٹیکس منہا کیا';

  @override
  String get taxWithheldHelp =>
      'کمپنیاں اور سرکاری ادارے سیکشن 155 کے تحت ٹیکس کاٹ کر سرٹیفکیٹ دیتے ہیں۔ نقد رقم اور ٹیکس مل کر کرایہ ادا کرتے ہیں۔';

  @override
  String get taxWithheldLabel => 'منہا شدہ ٹیکس (سیکشن 155)';

  @override
  String get taxCertificateLabel => 'سرٹیفکیٹ یا سی پی آر نمبر';

  @override
  String taxSettlesGross(String cash, String tax, String total) {
    return '$cash وصول اور $tax منہا شدہ ٹیکس مل کر $total کے واجبات ادا کرتے ہیں۔';
  }

  @override
  String get noOpenDuesCredit =>
      'اس وقت کچھ واجب نہیں: یہ ادائیگی اگلے واجبات کے لیے کریڈٹ کے طور پر محفوظ رہے گی۔';

  @override
  String get settleLabel => 'ادائیگی کی ترتیب';

  @override
  String get settleOldestFirst => 'سب سے پرانے واجبات پہلے';

  @override
  String get settleChosen => 'میرے منتخب کردہ واجبات';

  @override
  String get chooseDuesError => 'کم از کم ایک واجب منتخب کریں۔';

  @override
  String get willSettleHeading => 'یہ ادائیگی ادا کرے گی';

  @override
  String settledInFull(String charge) {
    return '$charge، پورا';
  }

  @override
  String settledInPart(String charge) {
    return '$charge، جزوی';
  }

  @override
  String get creditKeptLabel => 'کریڈٹ کے طور پر محفوظ';

  @override
  String allCreditExplain(String amount) {
    return 'پوری $amount اگلے واجبات کے لیے کریڈٹ کے طور پر محفوظ رہے گی۔';
  }

  @override
  String lateFeeCancelledNote(String amount) {
    return '$amount کا تاخیر جرمانہ منسوخ ہو جائے گا: یہ ادائیگی اس کا کرایہ رعایتی دنوں کے اندر پورا ادا کرتی ہے۔';
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
    return 'منسوخ شدہ رسید: $date۔ $reason';
  }

  @override
  String get receivedFromLabel => 'ادا کنندہ';

  @override
  String get receiptForLabel => 'برائے';

  @override
  String get paidByLabel => 'ادائیگی کا طریقہ';

  @override
  String get receiptFooter =>
      'شکریہ۔ یہ رسید اپنے ریکارڈ کے لیے سنبھال کر رکھیں۔';

  @override
  String get shareReceiptAction => 'رسید بھیجیں';

  @override
  String get shareVoidedReceiptAction => 'منسوخ شدہ رسید بھیجیں';

  @override
  String get sendThanksAction => 'واٹس ایپ پر شکریہ';

  @override
  String get voidPaymentAction => 'ادائیگی منسوخ کریں';

  @override
  String get voidPaymentExplain =>
      'غلطی سے درج کی گئی ادائیگی منسوخ کرنے سے اس کے ادا کردہ واجبات دوبارہ واجب ہو جائیں گے۔ رسید اپنے نمبر کے ساتھ، آپ کی بتائی گئی وجہ سمیت، منسوخ شدہ رہے گی۔';

  @override
  String get paymentVoided => 'ادائیگی منسوخ ہو گئی۔';

  @override
  String get documentLanguageLabel => 'دستاویز کی زبان';

  @override
  String get shareDocumentAction => 'پی ڈی ایف بھیجیں';

  @override
  String get receiptDocumentTitle => 'کرائے کی رسید';

  @override
  String get receiptVoid => 'منسوخ';

  @override
  String receiptVoidBecause(String reason) {
    return 'منسوخ: $reason';
  }

  @override
  String get totalSettledLabel => 'کل، ٹیکس سمیت';

  @override
  String get receiptSettledHeading => 'ادا شدہ واجبات';

  @override
  String documentMadeOn(String date) {
    return 'مالکِ مکان سے $date کو بنائی گئی۔';
  }

  @override
  String receiptFileTitle(String number) {
    return 'رسید $number';
  }

  @override
  String get statementDocumentTitle => 'کرایہ دار کا گوشوارہ';

  @override
  String get statementPeriodLabel => 'مدت';

  @override
  String dateRange(String from, String to) {
    return '$from سے $to تک';
  }

  @override
  String get statementSummaryHeading => 'خلاصہ';

  @override
  String get totalBilledLabel => 'کل واجبات';

  @override
  String get totalPaidLabel => 'ادا شدہ';

  @override
  String get totalWaivedLabel => 'معاف شدہ';

  @override
  String get balanceOwedLabel => 'اب واجب الادا';

  @override
  String get statementDuesHeading => 'واجبات';

  @override
  String get chargeForLabel => 'کس مد میں';

  @override
  String get chargeStateLabel => 'حیثیت';

  @override
  String get statementPaymentsHeading => 'ادائیگیاں';

  @override
  String voidedReceipt(String number) {
    return '$number (منسوخ)';
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
    return 'گوشوارہ، $tenant';
  }

  @override
  String get reminderTitle => 'واٹس ایپ پر یاد دہانی';

  @override
  String get reminderTemplateLabel => 'پیغام';

  @override
  String get templateUpcoming => 'کرایہ جلد واجب';

  @override
  String get templateDueToday => 'کرایہ آج واجب';

  @override
  String get templateOverdue => 'کرایہ تاخیر شدہ';

  @override
  String get templatePaymentReceived => 'ادائیگی موصول';

  @override
  String get templateUtilityBill => 'یوٹیلیٹی بل';

  @override
  String get reminderLanguageLabel => 'کرایہ دار کی زبان';

  @override
  String get languageRomanUrdu => 'Roman Urdu';

  @override
  String get reminderMessageLabel => 'بھیجا جانے والا پیغام';

  @override
  String get reminderNoPhone =>
      'اس کرایہ دار کا فون نمبر درج نہیں: واٹس ایپ کھلے گا تاکہ آپ چیٹ منتخب کریں۔';

  @override
  String reminderTo(String name, String phone) {
    return 'بنام $name، نمبر $phone۔';
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
    return 'اس کرایہ دار کو $moment کو پہلے ہی یاد دہانی بھیجی جا چکی ہے۔ بار بار یاد دہانی اچھے تعلق کو متاثر کر سکتی ہے۔';
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
    return 'السلام علیکم $tenant۔ یاد دہانی ہے کہ $unit کے $amount مورخہ $date کو واجب الادا ہیں۔';
  }

  @override
  String reminderDueToday(String tenant, String amount, String unit) {
    return 'السلام علیکم $tenant۔ $unit کے $amount آج واجب الادا ہیں۔';
  }

  @override
  String reminderOverdue(
    String tenant,
    String amount,
    String unit,
    String date,
  ) {
    return 'السلام علیکم $tenant۔ $unit کے $amount واجب الادا ہیں اور ابھی تک موصول نہیں ہوئے؛ ان میں سب سے پرانی رقم مورخہ $date کو واجب الادا تھی۔ براہِ کرم جلد از جلد ادا کر دیں۔';
  }

  @override
  String reminderReceived(
    String tenant,
    String amount,
    String date,
    String receipt,
  ) {
    return 'السلام علیکم $tenant۔ $date کو $amount موصول ہو گئے۔ رسید نمبر: $receipt۔ شکریہ۔';
  }

  @override
  String reminderUtility(
    String tenant,
    String utility,
    String amount,
    String unit,
    String date,
  ) {
    return 'السلام علیکم $tenant۔ $unit کا $utility کا بل $amount مورخہ $date تک ادا کرنا ہے۔ براہِ کرم آخری تاریخ سے پہلے ادا کر دیں۔';
  }

  @override
  String get reminderElectricity => 'بجلی';

  @override
  String get reminderGas => 'گیس';

  @override
  String get reminderWater => 'پانی';

  @override
  String get reminderInternet => 'انٹرنیٹ';

  @override
  String get reminderUtilityGeneric => 'یوٹیلیٹی';

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
  String get loadingCashBook => 'ہاتھ میں نقدی لوڈ ہو رہی ہے';

  @override
  String get cashBookLoadFailedTitle => 'ہاتھ میں نقدی لوڈ نہیں ہو سکی';

  @override
  String get cashInHandSection => 'نقدی کس کے پاس ہے';

  @override
  String get cashInHandHelp =>
      'وصول کی گئی نقدی، آگے دی گئی یا نقد خرچ کی گئی رقم نکال کر۔';

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
  String get handoversSection => 'نقدی کی حوالگی';

  @override
  String get noHandoversYet => 'ابھی کوئی نقدی حوالے نہیں کی گئی۔';

  @override
  String get formerMember => 'سابق رکن';

  @override
  String handoverFromTo(String from, String to) {
    return 'از $from بنام $to';
  }

  @override
  String get handoverConfirmed => 'تصدیق شدہ';

  @override
  String get handoverAwaiting => 'تصدیق باقی';

  @override
  String get handoverTitle => 'نقدی کی حوالگی';

  @override
  String get handedOverOnLabel => 'حوالگی کی تاریخ';

  @override
  String get confirmHandoverAction => 'تصدیق کریں کہ وصول ہوئی';

  @override
  String get handoverConfirmedDone => 'حوالگی کی تصدیق ہو گئی۔';

  @override
  String get voidHandoverAction => 'حوالگی منسوخ کریں';

  @override
  String get voidHandoverExplain =>
      'غلطی سے درج کی گئی حوالگی منسوخ کرنے سے وہ نقدی دینے والے کے پاس ہی شمار ہو گی۔ یہ منسوخ شدہ کے طور پر فہرست میں رہے گی۔';

  @override
  String get handoverVoided => 'حوالگی منسوخ ہو گئی۔';

  @override
  String get recordHandoverAction => 'حوالگی درج کریں';

  @override
  String get handoverFromLabel => 'دینے والا';

  @override
  String get handoverToLabel => 'وصول کرنے والا';

  @override
  String get handoverChooseReceiver => 'منتخب کریں کہ نقدی کس نے وصول کی۔';

  @override
  String get handoverRecorded => 'حوالگی درج ہو گئی۔';

  @override
  String get notificationsTitle => 'اطلاعات';

  @override
  String get notificationsSummary =>
      'واجب کرایہ، ختم ہوتی کرایہ داریاں، پولیس اندراج';

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
      'ایپ ہر صبح واجب کرایہ، ختم ہوتی کرایہ داریاں، کرائے میں اضافہ، پولیس اندراج اور ختم ہوتے شناختی کارڈ دیکھتی ہے، اور آپ کو یہاں بتاتی ہے۔';

  @override
  String get markAllReadAction => 'سب کو پڑھا ہوا کریں';

  @override
  String get unreadLabel => 'نئی';

  @override
  String get openNotificationAction => 'کھولیں';

  @override
  String get notificationDeleted => 'اطلاع حذف ہو گئی۔';

  @override
  String get notificationRentDueSoon => 'کرایہ جلد واجب';

  @override
  String notificationRentDueSoonBody(
    String tenancy,
    String amount,
    String date,
  ) {
    return '$tenancy: $amount مورخہ $date کو واجب۔';
  }

  @override
  String get notificationRentOverdue => 'کرایہ تاخیر شدہ';

  @override
  String notificationRentOverdueBody(
    String tenancy,
    String amount,
    String date,
  ) {
    return '$tenancy: $amount مورخہ $date کو واجب تھا۔';
  }

  @override
  String get notificationLeaseExpiring => 'معاہدہ ختم ہو رہا ہے';

  @override
  String notificationLeaseExpiringBody(String tenancy, String date) {
    return '$tenancy: معاہدہ $date کو ختم ہو گا۔';
  }

  @override
  String get notificationIncrementDue => 'کرائے میں اضافہ واجب';

  @override
  String notificationIncrementDueBody(
    String tenancy,
    String date,
    String rent,
  ) {
    return '$tenancy: $rent کرائے پر سالانہ اضافہ $date سے واجب ہے۔';
  }

  @override
  String get notificationPolicePending => 'پولیس اندراج باقی';

  @override
  String notificationPolicePendingBody(String tenancy, String date) {
    return '$tenancy: کرایہ داری $date تک پولیس میں درج کروائیں۔';
  }

  @override
  String get notificationPoliceOverdue => 'پولیس اندراج میں تاخیر';

  @override
  String notificationPoliceOverdueBody(String tenancy, String date) {
    return '$tenancy: پولیس اندراج کی آخری تاریخ $date تھی۔';
  }

  @override
  String notificationPoliceReminderBody(String tenancy, String date) {
    return '$tenancy: پولیس اندراج کے لیے ایپ کی یاد دہانی $date ہے۔ ایپ کے علم میں یہاں کوئی قانون آخری تاریخ مقرر نہیں کرتا۔';
  }

  @override
  String get notificationCnicExpiring => 'شناختی کارڈ کی میعاد ختم';

  @override
  String notificationCnicExpiringBody(String tenant, String date) {
    return '$tenant کے شناختی کارڈ کی میعاد $date کو ختم ہو رہی ہے۔';
  }

  @override
  String get notificationUtilityDue => 'یوٹیلیٹی بل واجب';

  @override
  String notificationUtilityDueBody(
    String property,
    String amount,
    String date,
  ) {
    return '$property: $amount کا بل $date کو واجب ہے۔';
  }

  @override
  String get notificationInvitationAccepted => 'دعوت قبول ہو گئی';

  @override
  String notificationInvitationAcceptedBody(String email, String role) {
    return '$email بطور $role شامل ہو گئے۔';
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
      'کنکشن ٹوٹ گیا، اس لیے ممکن ہے واپسی درج ہو چکی ہو۔ دوبارہ کوشش سے پہلے اسے بند کر کے زرِ ضمانت دیکھ لیں۔';

  @override
  String get checkDepositAction => 'بند کر کے زرِ ضمانت دیکھیں';

  @override
  String get operationsSection => 'انتظامات';

  @override
  String get expensesSummary => 'آپ کی جائیدادوں پر ہونے والے اخراجات';

  @override
  String get utilitiesSummary => 'کنکشن، بل اور میٹر ریڈنگ';

  @override
  String get maintenanceSummary => 'مرمت کے کام اور ہر ایک کی صورتِ حال';

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
  String get statusLabel => 'صورتِ حال';

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
  String get callFailed => 'اس ڈیوائس پر فون نہیں کھل سکا۔';

  @override
  String get paidOnLabel => 'ادائیگی کی تاریخ';

  @override
  String get expenseCategoryRepairs => 'مرمت و دیکھ بھال';

  @override
  String get expenseCategoryPropertyTax => 'پراپرٹی ٹیکس';

  @override
  String get expenseCategoryUtilities => 'یوٹیلیٹیز';

  @override
  String get expenseCategorySociety => 'سوسائٹی چارجز';

  @override
  String get expenseCategoryInsurance => 'انشورنس';

  @override
  String get expenseCategoryLegal => 'قانونی و پیشہ ورانہ فیس';

  @override
  String get expenseCategoryAgent => 'ایجنٹ کا کمیشن';

  @override
  String get expenseCategorySalaries => 'عملے کی تنخواہیں';

  @override
  String get expenseCategoryCleaning => 'صفائی اور سکیورٹی';

  @override
  String get expenseCategoryRenovation => 'تزئین و آرائش';

  @override
  String get expenseCategoryBank => 'بینک چارجز';

  @override
  String get expenseCategoryLoanInterest => 'قرض کا سود';

  @override
  String get expensesTitle => 'اخراجات';

  @override
  String get expenseTitle => 'خرچ';

  @override
  String get newExpenseTitle => 'نیا خرچ';

  @override
  String get editExpenseTitle => 'خرچ میں ترمیم';

  @override
  String get addExpenseAction => 'خرچ شامل کریں';

  @override
  String get loadingExpenses => 'اخراجات لوڈ ہو رہے ہیں';

  @override
  String get loadingExpense => 'خرچ لوڈ ہو رہا ہے';

  @override
  String get expensesLoadFailedTitle => 'اخراجات لوڈ نہیں ہو سکے';

  @override
  String get expenseLoadFailedTitle => 'خرچ لوڈ نہیں ہو سکا';

  @override
  String get expensesEmptyTitle => 'ابھی کوئی خرچ نہیں';

  @override
  String get expensesEmptyBody =>
      'مرمت، ٹیکس، تنخواہوں اور باقی کاموں پر ہونے والا خرچ درج کریں، ہر رسید کی تصویر کے ساتھ۔ اس سے پتا چلتا ہے کہ ہر جائیداد اصل میں کتنا کماتی ہے۔';

  @override
  String get expenseSectionWhat => 'کیا خرچ ہوا';

  @override
  String get expenseSectionWhere => 'کہاں';

  @override
  String get expenseSectionPaid => 'ادائیگی کیسے ہوئی';

  @override
  String get expenseCategoryLabel => 'زمرہ';

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
  String get expenseDeleted => 'خرچ حذف ہو گیا۔';

  @override
  String get deleteExpenseTitle => 'یہ خرچ حذف کریں؟';

  @override
  String get deleteExpenseBody =>
      'یہ اپنی رسیدوں سمیت ہمیشہ کے لیے ختم ہو جائے گا۔ صرف غلطی سے درج کیے گئے خرچ کے لیے۔';

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
  String get utilitiesTitle => 'یوٹیلیٹیز';

  @override
  String get loadingUtilities => 'یوٹیلیٹیز لوڈ ہو رہی ہیں';

  @override
  String get utilitiesLoadFailedTitle => 'یوٹیلیٹیز لوڈ نہیں ہو سکیں';

  @override
  String get unpaidBillsSection => 'واجب الادا بل';

  @override
  String get unpaidBillsHelp =>
      'غیر ادا شدہ بل، جس کی آخری تاریخ پہلے ہے وہ پہلے۔';

  @override
  String get noUnpaidBills => 'کوئی غیر ادا شدہ بل نہیں۔';

  @override
  String landlordNameOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'آپ کے نام کے کنکشنوں کے $count بل تاخیر میں ہیں۔ بقایا جات جگہ اور کنکشن کے ساتھ رہتے ہیں، اس لیے یہ آپ پر آ سکتے ہیں۔',
      one: 'آپ کے نام کے ایک کنکشن کا بل تاخیر میں ہے۔ بقایا جات جگہ اور کنکشن کے ساتھ رہتے ہیں، اس لیے یہ آپ پر آ سکتے ہیں۔',
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
      'ہر میٹر اس کے ریفرنس نمبر اور اس بات کے ساتھ شامل کریں کہ یہ کس کے نام پر ہے۔ غیر ادا شدہ بل جگہ کے ساتھ رہتے ہیں، اس لیے ان پر یہاں نظر رکھیں۔';

  @override
  String get archivedConnectionsEmpty => 'کوئی آرکائیو شدہ کنکشن نہیں۔';

  @override
  String get archivedConnectionsEmptyBody =>
      'آپ کے آرکائیو کیے گئے کنکشن اپنے بلوں اور ریڈنگز سمیت یہاں رہتے ہیں۔';

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
      'یہ کنکشن آپ کے نام پر ہے۔ غیر ادا شدہ بل اسی کے ساتھ رہتے ہیں اور آپ پر آ سکتے ہیں: ہر مہینے دیکھیں کہ بل ادا ہو گیا ہے۔';

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
      'بقایا جات جگہ کے ساتھ رہتے ہیں: آپ کے نام کے کنکشن کے غیر ادا شدہ بل آپ پر آ سکتے ہیں۔';

  @override
  String get whoPaysLabel => 'بل کون ادا کرتا ہے';

  @override
  String get subMeterLabel => 'سب میٹر';

  @override
  String get subMeterHelp =>
      'آپ کا اپنا میٹر جو مرکزی کنکشن میں سے کسی ایک پورشن کا حصہ ناپتا ہے۔';

  @override
  String get protectedLabel => 'محفوظ ٹیرف';

  @override
  String protectedHelp(int limit) {
    return '$limit یونٹ ماہانہ یا اس سے کم استعمال والے گھروں کا رعایتی ٹیرف۔ کسی ایک مہینے $limit سے زیادہ پر یہ چھ مہینے کے لیے ختم ہو جاتا ہے؛ ایپ حد کے قریب پہنچنے پر آپ کو خبردار کرتی ہے۔';
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
      'یہ آپ کی فہرستوں سے ہٹ جائے گا لیکن اس کے بل اور ریڈنگز محفوظ رہیں گی۔ آپ اسے بعد میں دوبارہ استعمال میں لا سکتے ہیں۔';

  @override
  String get connectionArchived => 'کنکشن آرکائیو ہو گیا۔';

  @override
  String get connectionRestored => 'کنکشن دوبارہ استعمال میں ہے۔';

  @override
  String get deleteConnectionTitle => 'یہ کنکشن حذف کریں؟';

  @override
  String get deleteConnectionBody =>
      'یہ اپنے بلوں اور ریڈنگز سمیت ہمیشہ کے لیے ختم ہو جائے گا۔ کرایہ دار کے کھاتے میں پہلے سے درج واجبات وہیں رہیں گے۔ صرف غلطی سے شامل کیے گئے کنکشن کے لیے؛ ورنہ اسے آرکائیو کریں۔';

  @override
  String get connectionDeleted => 'کنکشن حذف ہو گیا۔';

  @override
  String get newConnectionTitle => 'نیا کنکشن';

  @override
  String get editConnectionTitle => 'کنکشن میں ترمیم';

  @override
  String get connectionSectionWhere => 'کہاں';

  @override
  String get connectionSectionSupplier => 'کیا اور کون فراہم کرتا ہے';

  @override
  String get connectionSectionNumbers => 'کنکشن کے نمبر';

  @override
  String get connectionSectionWho => 'کس کے نام پر، کون ادا کرتا ہے';

  @override
  String get utilityTypeLabel => 'قسم';

  @override
  String get providerLabel => 'فراہم کنندہ';

  @override
  String get providerNameLabel => 'فراہم کنندہ کا نام';

  @override
  String get referenceNumberHelp => 'جیسا بل پر لکھا ہے۔';

  @override
  String referenceDigitsHint(int digits) {
    return 'اس فراہم کنندہ کے بلوں پر عموماً $digits ہندسوں کا نمبر ہوتا ہے۔ اسے بل سے ملا لیں۔';
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
  String get billUnpaid => 'غیر ادا شدہ';

  @override
  String get billMonthLabel => 'بل برائے';

  @override
  String get unitsConsumedLabel => 'استعمال شدہ یونٹ';

  @override
  String protectedUnitsHelp(int limit) {
    return 'محفوظ ٹیرف پر: ہر مہینہ $limit یونٹ یا اس سے کم رکھیں۔';
  }

  @override
  String get validationUnits => 'یونٹس کی تعداد درج کریں، جیسے 185 یا 185.5۔';

  @override
  String get alreadyPaidLabel => 'ادا ہو چکا ہے';

  @override
  String get billPaidByLabel => 'کس نے ادا کیا';

  @override
  String get billAdded => 'بل شامل ہو گیا۔';

  @override
  String get billSaved => 'بل محفوظ ہو گیا۔';

  @override
  String get billDeleted => 'بل حذف ہو گیا۔';

  @override
  String get billMarkedPaid => 'بل ادا شدہ درج ہو گیا۔';

  @override
  String get billMarkedUnpaid => 'بل غیر ادا شدہ درج ہو گیا۔';

  @override
  String get billCharged => 'بل کرایہ دار کے کھاتے میں درج ہو گیا۔';

  @override
  String get markPaidAction => 'ادا شدہ درج کریں';

  @override
  String get markUnpaidAction => 'غیر ادا شدہ درج کریں';

  @override
  String get editBillAction => 'بل میں ترمیم';

  @override
  String get chargeTenantAction => 'کرایہ دار کے ذمے ڈالیں';

  @override
  String chargeTenantExplain(String amount, String date) {
    return '$amount کا بل کرایہ دار کے کھاتے میں واجب بن جائے گا، جس کی آخری تاریخ $date ہو گی۔ کرایہ دار کا پیشگی جمع کریڈٹ اس میں لگ جائے گا۔';
  }

  @override
  String get chargedToTenantHelp =>
      'اس کی ادائیگی کرایہ داری کے کھاتے میں درج ہوتی ہے۔';

  @override
  String get billChargeVoided =>
      'اس بل کا کرایہ دار کے کھاتے میں درج واجب منسوخ کر دیا گیا تھا۔ آپ اسے دوبارہ ڈال سکتے ہیں۔';

  @override
  String get connectionDetailsAction => 'کنکشن کی تفصیل';

  @override
  String get inYourNameUnpaid =>
      'یہ غیر ادا شدہ بل آپ کے نام کے کنکشن کا ہے: اگر یہ ادا نہ ہوا تو بقایا جات آپ پر آ سکتے ہیں۔';

  @override
  String get deleteBillTitle => 'یہ بل حذف کریں؟';

  @override
  String get deleteBillBody =>
      'یہ اپنی تصاویر سمیت ہمیشہ کے لیے ختم ہو جائے گا۔ صرف غلطی سے شامل کیے گئے بل کے لیے۔';

  @override
  String get deleteChargedBillBody =>
      'یہ اپنی تصاویر سمیت ہمیشہ کے لیے ختم ہو جائے گا۔ کرایہ دار کے کھاتے میں اس کا واجب وہیں رہے گا: اگر وہ بھی غلط ہے تو کھاتے میں منسوخ کریں۔';

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
    return 'اس مہینے $limit یونٹ سے زیادہ استعمال ہوئے: اگلے چھ مہینے کے لیے محفوظ ٹیرف ختم ہو جاتا ہے، اور بل مہنگے ہوں گے۔';
  }

  @override
  String protectedNearExplain(int limit) {
    return 'اس مہینے کا استعمال $limit یونٹ کے قریب ہے۔ کسی ایک مہینے $limit سے زیادہ پر محفوظ ٹیرف چھ مہینے کے لیے ختم ہو جاتا ہے۔';
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
      'یہ پچھلی ریڈنگ سے کم ہے۔ اگر میٹر تبدیل ہوا ہے تو نیچے نوٹ میں لکھ دیں۔';

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
  String get readingDeleted => 'ریڈنگ حذف ہو گئی۔';

  @override
  String get editReadingAction => 'ریڈنگ میں ترمیم';

  @override
  String get deleteReadingTitle => 'یہ ریڈنگ حذف کریں؟';

  @override
  String get deleteReadingBody =>
      'یہ اپنی تصاویر سمیت ہمیشہ کے لیے ختم ہو جائے گی۔ صرف غلطی سے شامل کی گئی ریڈنگ کے لیے۔';

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
  String get maintenanceAppliance => 'برقی آلات';

  @override
  String get maintenancePestControl => 'کیڑے مار اسپرے';

  @override
  String get maintenanceCleaning => 'صفائی';

  @override
  String get maintenanceStructural => 'تعمیراتی';

  @override
  String get maintenanceWaterSupply => 'پانی کی فراہمی';

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
    return 'ترجیح: $priority';
  }

  @override
  String get maintenanceOpen => 'زیرِ التوا';

  @override
  String get maintenanceInProgress => 'کام جاری';

  @override
  String get maintenanceOnHold => 'روک دیا گیا';

  @override
  String get maintenanceResolved => 'مکمل';

  @override
  String get maintenanceCancelled => 'منسوخ';

  @override
  String get maintenanceTitle => 'مرمت و دیکھ بھال';

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
      'ہر مرمت کا کام اطلاع ملتے ہی درج کریں، اور مکمل ہونے تک اس پر نظر رکھیں، اس کے خرچ سمیت۔';

  @override
  String get maintenanceClosedEmptyTitle => 'ابھی کوئی بند کام نہیں';

  @override
  String get maintenanceClosedEmptyBody =>
      'جو کام آپ مکمل یا منسوخ کریں وہ یہاں محفوظ رہتے ہیں۔';

  @override
  String get addRequestAction => 'مرمت کا کام شامل کریں';

  @override
  String reportedOn(String date) {
    return 'اطلاع $date';
  }

  @override
  String get maintenanceCategoryLabel => 'کام کی قسم';

  @override
  String get priorityLabel => 'ترجیح';

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
  String get estimateLabel => 'تخمینہ';

  @override
  String get resolvedOnLabel => 'مکمل ہونے کی تاریخ';

  @override
  String get resolutionLabel => 'کیا کام کیا گیا';

  @override
  String get resolutionHelp =>
      'ریکارڈ کے لیے: کیا ٹھیک کیا گیا، اور اگر کوئی گارنٹی ہو۔';

  @override
  String get startWorkAction => 'کام شروع کریں';

  @override
  String get resumeWorkAction => 'کام دوبارہ شروع کریں';

  @override
  String get putOnHoldAction => 'روک دیں';

  @override
  String get markResolvedAction => 'مکمل درج کریں';

  @override
  String get cancelRequestAction => 'کام منسوخ کریں';

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
    return '$estimate کے تخمینے میں سے $spent';
  }

  @override
  String deleteRequestTitle(String title) {
    return '$title حذف کریں؟';
  }

  @override
  String get deleteRequestBody =>
      'یہ اپنی تصاویر سمیت ہمیشہ کے لیے ختم ہو جائے گا۔ صرف غلطی سے شامل کیے گئے کام کے لیے؛ ریکارڈ رکھنے کے لیے اسے منسوخ کریں۔';

  @override
  String get requestDeleted => 'مرمت کا کام حذف ہو گیا۔';

  @override
  String get newRequestTitle => 'مرمت کا نیا کام';

  @override
  String get editRequestTitle => 'مرمت کے کام میں ترمیم';

  @override
  String get requestSectionWhat => 'کیا کام کرنا ہے';

  @override
  String get requestSectionWhere => 'کہاں';

  @override
  String get requestSectionWho => 'کون اور کب';

  @override
  String get requestSectionStatus => 'صورتِ حال';

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
      'اس قسم کے زیرِ استعمال کسی اور کنکشن کا یہی ریفرنس نمبر پہلے سے موجود ہے۔';

  @override
  String get reasonDuplicateBillMonth =>
      'اس کنکشن کا اس مہینے کا بل پہلے سے موجود ہے۔ اسے بدلنے کے لیے وہی بل کھولیں۔';

  @override
  String get reasonRequestHasExpenses =>
      'اس مرمت کے کام پر اخراجات درج ہیں، اس لیے یہ حذف نہیں ہو سکتا۔ اس کے بجائے اسے منسوخ کریں، یا پہلے وہ اخراجات حذف کریں۔';

  @override
  String connectionReference(String number) {
    return 'ریفرنس $number';
  }

  @override
  String get whereLabel => 'کہاں';

  @override
  String pacedNearExplain(int limit) {
    return 'اس رفتار سے ایک مہینے کا استعمال $limit یونٹ کے قریب پہنچ جاتا ہے۔ کسی ایک مہینے $limit سے زیادہ پر محفوظ ٹیرف چھ مہینے کے لیے ختم ہو جاتا ہے۔';
  }

  @override
  String pacedOverExplain(int limit) {
    return 'اس رفتار سے ایک مہینے کا استعمال $limit یونٹ سے بڑھ جاتا ہے، جس سے محفوظ ٹیرف چھ مہینے کے لیے ختم ہو جاتا ہے۔ بل آنے پر اسے دیکھ لیں۔';
  }

  @override
  String get paidWithLabel => 'ادائیگی کا طریقہ';

  @override
  String get billAmountLocked =>
      'یہ بل کرایہ دار کے کھاتے میں واجب کے طور پر درج ہے، اس لیے اس کی رقم یہاں نہیں بدل سکتی۔ درست کرنے کے لیے کھاتے میں وہ واجب منسوخ کریں، پھر بل دوبارہ کرایہ دار پر ڈالیں۔';

  @override
  String paceAMonth(String units) {
    return 'تقریباً $units یونٹ ماہانہ';
  }

  @override
  String readingHigher(String value, String date) {
    return 'یہ $date کی بعد والی ریڈنگ $value سے زیادہ ہے۔ عدد اور تاریخ دوبارہ دیکھ لیں۔';
  }

  @override
  String get markUnpaidTitle => 'یہ بل غیر ادا شدہ درج کریں؟';

  @override
  String markUnpaidBody(String date) {
    return 'ادائیگی کی تاریخ ($date) اور ادا کرنے والے کا اندراج مٹ جائے گا۔';
  }

  @override
  String get cancelRequestTitle => 'یہ کام منسوخ کر کے بند کریں؟';

  @override
  String get cancelRequestBody =>
      'یہ اپنی تفصیلات اور اخراجات سمیت بند کاموں میں چلا جائے گا۔ آپ اسے بعد میں دوبارہ کھول سکتے ہیں۔';

  @override
  String get closeAsCancelledAction => 'کام بند کریں';

  @override
  String get chargeDuePassed =>
      'یہ تاریخ گزر چکی ہے، اس لیے یہ واجب فوراً تاخیر میں دکھائی دے گا۔';

  @override
  String get savedEarlierUnchanged =>
      'یہ پہلے ہی محفوظ ہو چکا تھا، جیسا پہلے درج کیا گیا۔ بعد کی تبدیلیاں محفوظ نہیں ہوئیں: انہیں کرنے کے لیے اس میں ترمیم کریں۔';

  @override
  String get requestHasExpensesClosed =>
      'اس مرمت کے کام پر اخراجات درج ہیں، اس لیے یہ حذف نہیں ہو سکتا۔ اگر یہ غلطی سے درج ہوا تھا تو پہلے وہ اخراجات حذف کریں۔';

  @override
  String get loadingDashboard => 'ڈیش بورڈ لوڈ ہو رہا ہے';

  @override
  String get dashboardLoadFailedTitle => 'ڈیش بورڈ لوڈ نہیں ہو سکا';

  @override
  String get searchAction => 'تلاش';

  @override
  String get reportsTitle => 'رپورٹس';

  @override
  String get reportsEntryTitle => 'رپورٹس اور گوشوارے';

  @override
  String get reportsEntrySummary =>
      'نقدی کا بہاؤ، ادائیگی کے اسکور، ٹیکس سال اور مالک کے گوشوارے، ایکسپورٹ';

  @override
  String thisMonthSection(String month) {
    return 'اس مہینے، $month';
  }

  @override
  String get collectedThisMonthLabel => 'اس مہینے کے واجبات کی ادائیگی';

  @override
  String collectedOfDue(String due, String rate) {
    return '$due واجب میں سے، $rate وصول';
  }

  @override
  String get receivedThisMonthLabel => 'اس مہینے موصول رقم';

  @override
  String get receivedThisMonthCaption =>
      'اس مہینے درج ہر ادائیگی، کسی بھی مہینے کے واجبات کی';

  @override
  String get nothingDueThisMonth => 'اس مہینے ابھی کچھ واجب نہیں ہوا۔';

  @override
  String owedInAll(String amount) {
    return 'کل $amount واجب الادا';
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
    return 'اس مہینے واجب $expected روپے میں سے $paid ادا ہو چکے ہیں۔';
  }

  @override
  String get insightsSection => 'توجہ طلب امور';

  @override
  String get noInsights => 'آج کسی بات پر توجہ کی ضرورت نہیں۔';

  @override
  String get insightAlert => 'فوری توجہ';

  @override
  String get insightWarning => 'توجہ دیں';

  @override
  String get insightInfo => 'جاننے کے لائق';

  @override
  String get insightGood => 'اچھی خبر';

  @override
  String insightsShowAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمام $count دکھائیں',
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
      'کرایہ پر دینے اور کرایہ وصول کرنے کے لیے کسی جائیداد میں یونٹ شامل کریں۔';

  @override
  String get dashboardNoUnitsViewer =>
      'یونٹ شامل ہونے کے بعد اس کا کرایہ یہاں نظر آئے گا۔';

  @override
  String get seePropertiesAction => 'جائیدادیں دیکھیں';

  @override
  String insightCollectionTitle(String rate) {
    return 'اس مہینے کے واجبات کا $rate وصول';
  }

  @override
  String insightCollectionBody(String amount) {
    return 'ان میں سے $amount ابھی وصول ہونا ہے۔';
  }

  @override
  String get insightCollectionDone => 'اس مہینے کے تمام واجبات ادا ہو چکے ہیں۔';

  @override
  String insightLongArrearsTitle(String amount) {
    return '$amount 90 دن سے زیادہ پرانے واجبات';
  }

  @override
  String get insightLongArrearsBody =>
      'اتنی پرانی رقم وصول کرنا سب سے مشکل ہوتا ہے۔ ان کرایہ داروں سے بات کریں، یا رخصتی پر ان کے زرِ ضمانت سے ادا کریں۔';

  @override
  String get seeWhoOwesAction => 'دیکھیں کس پر واجب ہے';

  @override
  String get insightIncrementTitle => 'کرائے میں اضافہ کرنا ہے';

  @override
  String insightIncrementMissed(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اضافے وقت پر نہیں کیے گئے',
      one: '1 اضافہ وقت پر نہیں کیا گیا',
    );
    return '$_temp0: ماہانہ $amount وصول نہیں ہو رہے۔';
  }

  @override
  String insightIncrementUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اضافے 30 دن کے اندر واجب ہیں۔',
      one: '1 اضافہ 30 دن کے اندر واجب ہے۔',
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
    return '$tenant کی سب سے پہلے ختم ہو رہی ہے، $_temp0۔ تجدید کریں یا رخصتی کی تیاری کریں۔';
  }

  @override
  String insightPoliceTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کرایہ داریاں پولیس میں درج نہیں',
      one: '1 کرایہ داری پولیس میں درج نہیں',
    );
    return '$_temp0';
  }

  @override
  String insightPoliceLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کی قانونی آخری تاریخ گزر چکی ہے: ابھی درج کروائیں۔',
      one: '1 کی قانونی آخری تاریخ گزر چکی ہے: ابھی درج کروائیں۔',
    );
    return '$_temp0';
  }

  @override
  String get insightPoliceBody =>
      'ہر ایک اپنی آخری تاریخ تک درج کروائیں۔ جہاں کوئی قانون آخری تاریخ مقرر نہیں کرتا، وہاں ایپ یاد دہانی کرواتی ہے۔';

  @override
  String insightPoliceSubmittedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'پولیس میں $count اندراج تصدیق کے منتظر ہیں',
      one: 'پولیس میں 1 اندراج تصدیق کا منتظر ہے',
    );
    return '$_temp0';
  }

  @override
  String insightPoliceSubmittedLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مزید $count جمع کرا دیے گئے ہیں، تصدیق باقی ہے۔',
      one: 'مزید 1 جمع کرا دیا گیا ہے، تصدیق باقی ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get insightPoliceSubmittedBody =>
      'قانون کا تقاضا آپ پورا کر چکے ہیں۔ پولیس کی تصدیق کے بعد کرایہ داری میں درج کریں۔';

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
      other: 'سب سے پرانا',
      one: 'یہ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days دن سے',
      one: '1 دن سے',
      zero: 'آج سے',
    );
    return 'طلب کردہ کرائے پر آپ کو ماہانہ $amount کا نقصان ہو رہا ہے۔ $_temp0 $_temp1 خالی ہے۔';
  }

  @override
  String insightDepositTitle(String cover) {
    return 'زرِ ضمانت تاخیر شدہ کرائے کا صرف $cover پورا کرتا ہے';
  }

  @override
  String insightDepositBody(String overdue, String held) {
    return '$overdue تاخیر شدہ ہے اور $held زرِ ضمانت جمع ہے۔ واجبات زرِ ضمانت سے زیادہ ہونے سے پہلے وصولی کریں۔';
  }

  @override
  String get insightUtilityTitle => 'یوٹیلیٹی بلوں پر توجہ کی ضرورت';

  @override
  String insightUtilityLandlord(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آپ کے نام پر $count بل ادا نہیں ہوئے',
      one: 'آپ کے نام پر 1 بل ادا نہیں ہوا',
    );
    return '$_temp0، کل $amount: ان کی ذمہ داری آپ پر ہے۔';
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
      other: 'محفوظ ٹیرف کے $count میٹر تازہ بل پر 200 یونٹ سے بڑھ گئے۔',
      one: 'محفوظ ٹیرف کا 1 میٹر تازہ بل پر 200 یونٹ سے بڑھ گیا۔',
    );
    return '$_temp0';
  }

  @override
  String insightUtilityNearTariff(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'محفوظ ٹیرف کے $count میٹر 200 یونٹ کے قریب ہیں۔',
      one: 'محفوظ ٹیرف کا 1 میٹر 200 یونٹ کے قریب ہے۔',
    );
    return '$_temp0';
  }

  @override
  String get seeUtilitiesAction => 'یوٹیلیٹیز دیکھیں';

  @override
  String get insightExpenseTitle => 'اس مہینے اخراجات زیادہ ہیں';

  @override
  String insightExpenseBody(String amount, String average) {
    return 'اب تک $amount، جبکہ اس سے پہلے کے تین مہینوں کی ماہانہ اوسط $average تھی۔';
  }

  @override
  String get seeExpensesAction => 'اخراجات دیکھیں';

  @override
  String insightUnderpricedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count یونٹس طلب کردہ کرائے سے کم پر دیے ہوئے ہیں',
      one: '1 یونٹ طلب کردہ کرائے سے کم پر دیا ہوا ہے',
    );
    return '$_temp0';
  }

  @override
  String insightUnderpricedBody(String amount, String unit) {
    return 'مجموعی طور پر آپ کے طلب کردہ کرائے سے ماہانہ $amount کم، سب سے زیادہ $unit پر۔ اگلے اضافے یا تجدید پر اس پر غور کریں۔';
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
      'بینک ٹرانسفر اور باقاعدہ حوالگی سے ہاتھ میں کم نقدی رہتی ہے۔';

  @override
  String get seeCashAction => 'ہاتھ میں نقدی دیکھیں';

  @override
  String get owedSection => 'آپ کے واجبات';

  @override
  String owedSectionHelp(String amount) {
    return 'کل $amount، تاخیر کی مدت کے لحاظ سے';
  }

  @override
  String get ageNotDue => 'ابھی واجب نہیں';

  @override
  String get age1to30 => '1 سے 30 دن تاخیر';

  @override
  String get age31to60 => '31 سے 60 دن تاخیر';

  @override
  String get age61to90 => '61 سے 90 دن تاخیر';

  @override
  String get ageOver90 => '90 دن سے زیادہ تاخیر';

  @override
  String ageingSummary(
    String total,
    String notDue,
    String early,
    String middle,
    String older,
    String late,
  ) {
    return '$total روپے واجب الادا: $notDue ابھی واجب نہیں، $early 30 دن تک تاخیر، $middle 31 سے 60 دن تاخیر، $older 61 سے 90 دن تاخیر، $late 90 دن سے زیادہ تاخیر۔';
  }

  @override
  String get owingMostSection => 'سب سے زیادہ واجبات';

  @override
  String get seeAllAction => 'سب دیکھیں';

  @override
  String get remindShortAction => 'یاد دہانی';

  @override
  String lastRemindedOn(String moment) {
    return 'یاد دہانی $moment';
  }

  @override
  String get upcomingSection => 'واجب اور آنے والے کام';

  @override
  String get upcomingEmpty => 'آنے والے ہفتوں میں کچھ واجب نہیں۔';

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
    return '$tenant کی کرایہ داری پولیس میں درج کروائیں';
  }

  @override
  String timelinePoliceLegal(String unit) {
    return '$unit: قانون کی مقرر کردہ آخری تاریخ';
  }

  @override
  String timelinePoliceLegalPassed(String unit) {
    return '$unit: قانون کی مقرر کردہ آخری تاریخ گزر چکی';
  }

  @override
  String timelinePoliceReminder(String unit) {
    return '$unit: ایپ کی یاد دہانی، کوئی قانونی آخری تاریخ نہیں';
  }

  @override
  String timelinePoliceSubmitted(String unit) {
    return '$unit: جمع کرا دیا، تصدیق باقی';
  }

  @override
  String timelineCnicExpires(String tenant) {
    return '$tenant کے شناختی کارڈ کی میعاد ختم ہو رہی ہے';
  }

  @override
  String timelineCnicExpired(String tenant) {
    return '$tenant کے شناختی کارڈ کی میعاد ختم ہو چکی ہے';
  }

  @override
  String get timelineCnicHelp => 'نئے کارڈ کی نقل طلب کریں۔';

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
  String get heldAndSpentSection => 'زرِ ضمانت، ٹیکس اور اخراجات';

  @override
  String get depositsHeldLabel => 'جمع شدہ زرِ ضمانت';

  @override
  String get depositsAgreedLabel => 'طے شدہ زرِ ضمانت';

  @override
  String get taxWithheldThisMonthLabel => 'اس مہینے منہا شدہ ٹیکس';

  @override
  String get expensesThisMonthLabel => 'اس مہینے کے اخراجات';

  @override
  String get expensesAverageLabel => 'پچھلے 3 مہینوں کی ماہانہ اوسط';

  @override
  String get loadingCashflow => 'نقدی کی آمد و رفت لوڈ ہو رہی ہے';

  @override
  String get cashflowLoadFailedTitle => 'نقدی کی آمد و رفت لوڈ نہیں ہو سکی';

  @override
  String get cashflowSection => 'نقدی کی آمد و رفت، پچھلے 12 مہینے';

  @override
  String get moneyInSeries => 'آمد';

  @override
  String get moneyOutSeries => 'خرچ';

  @override
  String get monthColumn => 'مہینہ';

  @override
  String cashflowSummary(
    String first,
    String last,
    String moneyIn,
    String moneyOut,
  ) {
    return '$first سے $last تک ہر مہینے کی آمد اور خرچ: کل $moneyIn روپے آمد اور $moneyOut روپے خرچ۔';
  }

  @override
  String get cashflowEmpty => 'پچھلے 12 مہینوں میں نہ کوئی رقم آئی نہ گئی۔';

  @override
  String get totalInLabel => 'کل آمد';

  @override
  String get totalOutLabel => 'کل خرچ';

  @override
  String get netLabel => 'خالص';

  @override
  String get loadingPerformance => 'جائیدادوں کے اعداد و شمار لوڈ ہو رہے ہیں';

  @override
  String get performanceLoadFailedTitle =>
      'جائیدادوں کے اعداد و شمار لوڈ نہیں ہو سکے';

  @override
  String get performanceSection => 'جائیدادیں، پچھلے 12 مہینے';

  @override
  String get performanceEmpty =>
      'یہاں آمدن اور اخراجات دیکھنے کے لیے جائیداد شامل کریں۔';

  @override
  String get rentIncomeLabel => 'وصول شدہ کرایہ';

  @override
  String get otherIncomeLabel => 'دیگر آمدن';

  @override
  String get propertyExpensesLabel => 'اخراجات';

  @override
  String get noiLabel => 'خالص آپریٹنگ آمدن';

  @override
  String get grossYieldLabel => 'مجموعی شرحِ منافع';

  @override
  String get netYieldLabel => 'خالص شرحِ منافع';

  @override
  String yieldValue(String percent) {
    return '$percent سالانہ';
  }

  @override
  String get noYieldHelp =>
      'شرحِ منافع دیکھنے کے لیے جائیداد کی تخمینی مالیت درج کریں۔';

  @override
  String get noiChartTitle => 'جائیداد کے لحاظ سے خالص آپریٹنگ آمدن';

  @override
  String noiChartSummary(String best, String amount) {
    return 'پچھلے 12 مہینوں کی خالص آپریٹنگ آمدن: سب سے زیادہ $best، $amount روپے۔';
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
  String get scoresEmpty => 'کرایہ واجب ہونے کے بعد اسکور نظر آئیں گے۔';

  @override
  String get scoreBandGood => 'وقت پر ادائیگی';

  @override
  String get scoreBandFair => 'کبھی کبھار تاخیر';

  @override
  String get scoreBandPoor => 'اکثر تاخیر';

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
      other: 'اوسطاً تقریباً $days دن تاخیر',
      one: 'اوسطاً تقریباً 1 دن تاخیر',
    );
    return '$_temp0';
  }

  @override
  String get scoreNeverLate => 'کبھی تاخیر نہیں';

  @override
  String get scoreUnderADayLate => 'اوسطاً ایک دن سے کم تاخیر';

  @override
  String scoreArrears(String months) {
    return '$months مہینوں کا کرایہ واجب';
  }

  @override
  String get scoreNoArrears => 'کوئی تاخیر شدہ واجب نہیں';

  @override
  String get scoreSectionTitle => 'ادائیگی کا اسکور';

  @override
  String get scoreNotYet => 'اسکور کے لیے ابھی کرائے کی کافی تاریخ نہیں۔';

  @override
  String get scoreFormulaHelp =>
      '100 میں سے: 50 وقت پر ادائیگی کے، 30 کم دن تاخیر کے، 20 کم واجبات کے۔';

  @override
  String get statementsSection => 'گوشوارے اور ایکسپورٹ';

  @override
  String get taxYearTitle => 'ٹیکس سال کا گوشوارہ';

  @override
  String get taxYearSummary =>
      'ہر جائیداد کی کرائے کی آمدن، جولائی تا جون، آپ کے ٹیکس مشیر کے لیے';

  @override
  String get ownerStatementTitle => 'مالک کا گوشوارہ';

  @override
  String get ownerStatementSummary =>
      'ایک مہینے کی رقم اور واجبات، بیرونِ ملک مالک کے لیے پی ڈی ایف';

  @override
  String get exportTitle => 'اسپریڈ شیٹ میں ایکسپورٹ';

  @override
  String get exportSummary =>
      'کھاتہ، ادائیگیاں یا اخراجات سی ایس وی فائل کے طور پر';

  @override
  String get taxYearLabel => 'ٹیکس سال';

  @override
  String taxYearOption(String endYear, String startYear) {
    return 'ٹیکس سال $endYear: جولائی $startYear تا جون $endYear';
  }

  @override
  String get loadingTaxYear => 'ٹیکس سال لوڈ ہو رہا ہے';

  @override
  String get taxYearLoadFailedTitle => 'ٹیکس سال لوڈ نہیں ہو سکا';

  @override
  String get notTaxAdviceTitle => 'ٹیکس کا مشورہ نہیں';

  @override
  String get notTaxAdviceBody =>
      'یہ اعداد و شمار آپ کے ریکارڈ سے ہیں، آپ کے ٹیکس مشیر کی مدد کے لیے۔ یہ ٹیکس کا حساب نہیں: ایپ کبھی آپ کے ذمے ٹیکس کا حساب نہیں لگاتی۔';

  @override
  String get grossRentLabel => 'وصول شدہ کرایہ، مجموعی';

  @override
  String get repairsAllowanceLabel => 'مرمت کی چھوٹ، پانچواں حصہ';

  @override
  String get netAfterAllowanceLabel => 'مرمت کی چھوٹ کے بعد کرایہ';

  @override
  String get expensesRecordedLabel => 'درج شدہ اخراجات';

  @override
  String get allPropertiesLabel => 'تمام جائیدادیں';

  @override
  String get taxYearEmpty => 'اس ٹیکس سال میں کوئی کرایہ یا خرچ درج نہیں ہوا۔';

  @override
  String get deductibleNote =>
      'کون سے اخراجات منہا ہو سکتے ہیں، یہ آپ کا ٹیکس مشیر طے کرے گا۔';

  @override
  String get shareCsvAction => 'سی ایس وی بھیجیں';

  @override
  String taxYearFileTitle(String endYear) {
    return 'ٹیکس سال کا گوشوارہ $endYear';
  }

  @override
  String taxYearDocumentTitle(String endYear) {
    return 'کرائے کی آمدن، ٹیکس سال $endYear';
  }

  @override
  String get ownerStatementMonthLabel => 'مہینہ';

  @override
  String ownerStatementFileTitle(String month) {
    return 'مالک کا گوشوارہ، $month';
  }

  @override
  String get moneyReceivedHeading => 'وصول شدہ رقم';

  @override
  String get rentAndFeesLabel => 'کرایہ اور تاخیر کی فیس';

  @override
  String get depositsReceivedLabel => 'زرِ ضمانت';

  @override
  String get otherDuesLabel => 'دیگر واجبات';

  @override
  String get unallocatedLabel => 'کریڈٹ کے طور پر رکھا';

  @override
  String get moneyPaidOutHeading => 'ادا شدہ رقم';

  @override
  String get depositRefundsLabel => 'واپس کیا گیا زرِ ضمانت';

  @override
  String get netCashLabel => 'مہینے کی خالص رقم';

  @override
  String owedOnHeading(String date) {
    return '$date تک کرایہ داروں کے ذمے';
  }

  @override
  String cashHeldOnHeading(String date) {
    return '$date تک ہاتھ میں نقدی';
  }

  @override
  String get ownerStatementFooter =>
      'پورٹ فولیو کے ریکارڈ سے بنایا گیا۔ صرف معلومات کے لیے: آڈٹ شدہ حساب نہیں۔';

  @override
  String get exportWhatLabel => 'کیا ایکسپورٹ کریں';

  @override
  String get exportLedger => 'کھاتہ: تمام واجبات';

  @override
  String get exportPayments => 'ادائیگیاں';

  @override
  String get exportExpenses => 'اخراجات';

  @override
  String get exportPeriodLabel => 'مدت';

  @override
  String get periodThisMonth => 'یہ مہینہ';

  @override
  String get periodLastMonth => 'پچھلا مہینہ';

  @override
  String get exportAction => 'سی ایس وی ایکسپورٹ کریں';

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
  String get csvOwed => 'واجب الادا';

  @override
  String get csvVoided => 'منسوخ';

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
      other: '$count نتائج',
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
  String get daysOverdueLabel => 'تاخیر کے دن';

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
  String get keepRepairAction => 'کام جاری رکھیں';

  @override
  String get keepInvitationAction => 'دعوت نامہ رہنے دیں';

  @override
  String get deletePortfolioSection => 'یہ پورٹ فولیو حذف کریں';

  @override
  String get deletePortfolioHelp =>
      'اس میں موجود ہر چیز سب کے لیے ہمیشہ کے لیے حذف ہو جائے گی: جائیدادیں، کرایہ دار، کرایہ داریاں، ادائیگیاں اور رسیدیں، اخراجات اور دستاویزات۔ پہلے جن رسیدوں اور گوشواروں کی ضرورت ہے ان کی نقول رکھ لیں۔';

  @override
  String get deletePortfolioAction => 'پورٹ فولیو حذف کریں';

  @override
  String deletePortfolioTitle(String name) {
    return '$name اور اس میں موجود سب کچھ حذف کریں؟';
  }

  @override
  String get deletePortfolioBody =>
      'تمام اراکین کی رسائی فوراً ختم ہو جائے گی، اور یہ واپس نہیں آ سکتا، ہماری طرف سے بھی نہیں۔';

  @override
  String portfolioDeleted(String name) {
    return '$name حذف ہو گیا۔';
  }

  @override
  String get chooseTenantTitle => 'کرایہ دار منتخب کریں';

  @override
  String get chooseTenantAction => 'کرایہ دار منتخب کریں';

  @override
  String get changeTenantAction => 'کوئی اور کرایہ دار منتخب کریں';

  @override
  String get noTenantChosen => 'ابھی منتخب نہیں کیا';

  @override
  String get chooseUnitTitle => 'یونٹ منتخب کریں';

  @override
  String get chooseUnitAction => 'یونٹ منتخب کریں';

  @override
  String get changeUnitAction => 'کوئی اور یونٹ منتخب کریں';

  @override
  String get otherPropertyAction => 'دوسری جائیدادیں';

  @override
  String get validationChooseUnit => 'یونٹ منتخب کریں۔';
}
