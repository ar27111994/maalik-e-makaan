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
}
