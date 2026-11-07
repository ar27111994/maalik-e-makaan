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
  String get groupingWestern => 'مغربی (1,250,000 روپے)';

  @override
  String get groupingSouthAsian => 'لاکھ اور کروڑ (12,50,000 روپے)';

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
}
