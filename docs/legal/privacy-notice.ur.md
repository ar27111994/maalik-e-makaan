# Privacy notice: proposed text (Urdu)

> **Draft for the lawyer's review. Not live.** This is the Urdu twin of
> [privacy-notice.en.md](privacy-notice.en.md): the whole Urdu privacy page as it would read once
> decisions 1 to 3 (residence, letterheads, and privacy-first analytics, support and e-mail) have
> shipped. None of them has. The live Urdu page,
> [`website/src/content/pages/ur/privacy.md`](../../website/src/content/pages/ur/privacy.md), stays
> as it is, and stays true, until the lawyer approves this text and its English twin and the
> features ship. The two pages are published together, with one `lastUpdated` (LR:159-160, :171).
> No analytics SDK ships before then (LR:108-110; RM:327; the research's order of work at
> PJ:160-161, which this plan adopts). Each part is published with the feature it describes, as
> the "Ships with" column of the English draft's table says. This is not legal advice.

Part of the [legal review pack](README.md). How to read this file:

- **It follows the English draft section for section and bullet for bullet,** so the two can be
  read side by side. Where the English draft keeps a sentence of the live English page, this draft
  keeps the matching sentence of the live Urdu page word for word.
- **It starts from the live Urdu page as #62 corrected it** (merged as `fabc088` on 12 November
  2026, and released in 1.1.1): the
  reminder log keeps "خود پیغام، اس کے پہلے 1,000 حروف تک" (the message itself, up to its first
  1,000 characters), and `lastUpdated` is 2026-11-12. #62 changes no line numbers.
- **The square brackets are the English draft's,** copied unchanged and in English, so that each
  open point has the same words and question number in both files. Among them, under "ای میلز",
  the promise that e-mails are not tracked waits for the owner to confirm that open and click
  tracking are off at Customer.io; Resend's are off, as the owner reported on 12 November 2026
  ([`docs/release-readiness.md`](../release-readiness.md):338-341; question E6). None of the
  brackets stays in the published page; each answer is written into both languages.
- **The Urdu** is plain everyday Urdu under the owner's glossary
  ([`contracts/urdu_glossary.json`](../../contracts/urdu_glossary.json)), checked by
  [`tool/check_urdu_words.py`](../../tool/check_urdu_words.py). Amounts, dates, periods (90 days,
  72 hours), legal effect and rights say exactly what the English says.
- **Names are written as the live Urdu page writes them.** The services are in Urdu script, with
  their links: سوپابیس، ورسل، ری سینڈ، گٹ ہب، گوگل فونٹس (PUR:17, :25, :32, :36, :37, :50), and the
  new ones the same way: پوسٹ ہاگ (PostHog), انٹرکام (Intercom), کسٹمر ڈاٹ آئی او (Customer.io).
  The company's registered name, the e-mail address and anything a reader may type or look for in
  Latin letters (the Mumbai region's code, "Do Not Track", "user agent", the "?" of an address) sit
  in `<kbd lang="en" dir="ltr">`, as the live page does for `fonts.gstatic.com` (PUR:37, :58).
- **Figures** are joined to the unit after them by a no-break space (U+00A0), as
  [`website/AGENTS.md`](../../website/AGENTS.md):26-28 requires on the site and the live page does
  (PUR:21, :50). The page has no number range, so no `<span dir="ltr">` is needed.
- After the page: [Words chosen for legal and technical terms](#words-chosen-for-legal-and-technical-terms),
  for the lawyer's check of the Urdu, and
  [Changes from the live Urdu notice](#changes-from-the-live-urdu-notice).

Short names: **PUR** is the live Urdu page and **PEN** the live English page, at commit `ae0112c`
on `main` (which includes #62's two corrections, released in 1.1.1); **PJ**, **RM** and **LR** are
[`.planning/PROJECT.md`](../../.planning/PROJECT.md),
[`docs/roadmap/README.md`](../roadmap/README.md) and
[`docs/roadmap/legal-review.md`](../roadmap/legal-review.md), at the same commit (LR as this pack's
pull request leaves it: [README](README.md#sources-and-conventions)). The reasons and
sources for every change are in the English draft's table, under the same row numbers.

## The proposed page

Front matter:

```yaml
title: "پرائیویسی"
description: "یہ ویب سائٹ اور مالکِ مکان ایپ آپ کے ڈیٹا کے ساتھ کیا کرتی ہیں: سائٹ پر کوئی کوکی نہیں، اور وزٹس کی گنتی آپ کی پہچان کے بغیر۔ ایپ اینالیٹکس یا سپورٹ چیٹ کو کچھ نہیں بھیجتی، جب تک آپ خود انہیں آن نہ کریں۔ ایپ میں آپ کا ریکارڈ صرف وہ لوگ دیکھ سکتے ہیں جنہیں آپ دعوت بھیجیں، اور وہ سروسز جو ایپ چلاتی ہیں۔"
lastUpdated: "[Owner: one date, shared by the English and Urdu pages]"
```

### خلاصہ

- یہ ویب سائٹ کوئی کوکی نہیں رکھتی۔ یہ وزٹس کی گنتی کرتی ہے، لیکن آپ کی پہچان کے بغیر۔ یہ گنتی امریکہ میں پوسٹ ہاگ کرتی ہے، اور آپ اسے اس صفحے پر بند کر سکتے ہیں۔
- کیلکولیٹر آپ کے براؤزر کے اندر ہی کام کرتے ہیں۔ ان میں آپ جو کچھ لکھتے ہیں، وہ آپ کے فون یا کمپیوٹر سے باہر نہیں جاتا۔
- ایپ اینالیٹکس (یعنی یہ گنتی کہ ایپ کیسے استعمال ہوتی ہے) یا سپورٹ چیٹ کو کچھ نہیں بھیجتی، جب تک آپ انہیں سیٹنگز میں آن نہ کریں۔ آپ انہیں کبھی بھی بند کر سکتے ہیں۔
- ایپ میں آپ کا ریکارڈ آپ کا ہے۔ اسے صرف وہ لوگ دیکھ سکتے ہیں جنہیں آپ دعوت بھیجیں، اور وہ بھی صرف اتنا جتنا ان کا رول اجازت دے۔ جو سروسز ہمارے لیے ایپ چلاتی ہیں، وہ اسے صرف ایپ چلانے کے لیے سنبھالتی ہیں۔ یہ ریکارڈ کبھی بیچا نہیں جاتا، اور نہ اشتہاروں کے لیے استعمال ہوتا ہے۔
- آپ اپنے کرایہ داروں کی جو تفصیل درج کرتے ہیں، اس کی دیکھ بھال آپ کی ذمہ داری ہے۔ ہم یہ تفصیل آپ کے لیے رکھتے ہیں، اور اسے صرف ایپ چلانے کے لیے استعمال کرتے ہیں۔

### یہ ویب سائٹ

اس سائٹ میں صرف سادہ صفحے ہیں۔ اس کے فونٹ، تصویریں اور اسکرپٹ اسی سائٹ سے آتے ہیں۔

#### وزٹس کی گنتی

ہم [پوسٹ ہاگ](https://posthog.com/privacy) کے ذریعے وزٹس گنتے ہیں، تاکہ ہمیں پتہ چلے کہ لوگ کون سے صفحے پڑھتے ہیں، اور کن صفحوں سے سائٹ چھوڑ کر چلے جاتے ہیں۔ پوسٹ ہاگ یہ کام ہمارے لیے کرتی ہے، اور ڈیٹا امریکہ میں رکھتی ہے (مزید تفصیل "ڈیٹا کہاں رہتا ہے" والے حصے میں ہے)۔

- سائٹ کوئی کوکی نہیں رکھتی، اور آپ کو گننے کے لیے آپ کے براؤزر میں کچھ محفوظ نہیں کرتی۔
- جب آپ کوئی صفحہ کھولتے ہیں، تو آپ کا براؤزر اس صفحے کا ایڈریس اسی سائٹ کو بھیجتا ہے۔ سائٹ یہ ایڈریس آگے پوسٹ ہاگ کو بھیج دیتی ہے۔ آگے بھیجنے سے پہلے سائٹ ایڈریس میں <kbd lang="en" dir="ltr">?</kbd> کے بعد کا سب کچھ ہٹا دیتی ہے۔ ہر درخواست کی طرح اس کے ساتھ بھی آپ کا آئی پی ایڈریس اور آپ کے براؤزر کی تفصیل (<kbd lang="en" dir="ltr">user agent</kbd>) جاتی ہے۔
- پوسٹ ہاگ تین چیزیں ملا کر ایک کوڈ بناتی ہے: آپ کا آئی پی ایڈریس، آپ کے براؤزر کی تفصیل اور اس سائٹ کا نام۔ ان کے ساتھ وہ ایک رینڈم نمبر بھی ملاتی ہے، جو ہر روز بدلتا ہے۔ وزٹ محفوظ کرنے سے پہلے وہ آپ کا آئی پی ایڈریس ہٹا دیتی ہے۔ ہر دن کے وزٹس گننے کے بعد وہ اس دن کا رینڈم نمبر ڈیلیٹ کر دیتی ہے۔ اس لیے آج کا وزٹ اور اگلے دن کا وزٹ دو الگ الگ لوگوں کے لگتے ہیں، اور بعد میں کوئی اس کوڈ کو آپ سے نہیں جوڑ سکتا۔ [Lawyer: A2] [To confirm: RM:316's preview check that PostHog receives the visitor's IP address through the site's rewrite. If it does not, PostHog counts page views but not visitors, and this bullet and the FAQ answer change.]
- آپ کے آئی پی ایڈریس سے یہ نہیں نکالا جاتا کہ آپ کہاں ہیں۔ آپ کی اسکرین، آپ کے کلک یا آپ کا لکھا ہوا کچھ بھی ریکارڈ نہیں ہوتا، اور سائٹ کوئی سروے نہیں دکھاتی۔
- پوسٹ ہاگ آپ کی کوئی پروفائل نہیں رکھتی، اور ہم یہ جاننے کی کوشش نہیں کرتے کہ آپ کون ہیں۔ [To confirm: the website's configuration sets `person_profiles: 'never'` and never calls `identify` (changes table, row 9).]
- [Owner: list what each counted visit carries, from the final configuration: for example the page, the site that linked to it, and the type of browser and device.]

#### گنتی بند کرنا

- اس صفحے پر دیا گیا سوئچ استعمال کریں۔ پھر آپ کا براؤزر اس سائٹ کے لیے آپ کا یہ فیصلہ یاد رکھتا ہے، اور سائٹ گنتی کرنے والا حصہ لوڈ کرنا بند کر دیتی ہے۔ یہ سائٹ آپ کے براؤزر میں صرف آپ کا یہی فیصلہ رکھتی ہے، اور کچھ نہیں۔ [Lawyer: A3]
- اگر آپ کا براؤزر "ڈو ناٹ ٹریک" (<kbd lang="en" dir="ltr">Do Not Track</kbd>) کا سگنل بھیجتا ہے، تو گنتی کرنے والا حصہ لوڈ ہی نہیں ہوتا۔ [Lawyer: A4]

#### ہوسٹنگ

ہر ویب سائٹ کی طرح اس کے صفحے بھی ایک ہوسٹنگ کمپنی، [ورسل](https://vercel.com/legal/privacy-policy) [To confirm: in the United States]، کے ذریعے آپ تک پہنچتے ہیں۔ ہر درخواست کی تکنیکی تفصیل، جیسے آپ کا آئی پی ایڈریس اور آپ کا مانگا ہوا صفحہ، ضرور اس کمپنی کے سرورز تک پہنچتی ہے۔ وزٹس کی گنتی بھی ورسل ہی کے ذریعے پوسٹ ہاگ تک پہنچتی ہے۔ ہم ان تفصیلات کو آپ کو پہچاننے کے لیے استعمال نہیں کرتے۔

#### کیلکولیٹر

کیلکولیٹر آپ کے براؤزر کے اندر ہی کام کرتے ہیں۔ ان میں آپ جو کچھ لکھتے ہیں، وہ آپ کے فون یا کمپیوٹر سے باہر نہیں جاتا، اور وزٹس کی گنتی میں بھی کبھی شامل نہیں ہوتا۔

### ایپ

یہ حصہ ایپ کے ورژن [Owner: the version in which these changes ship] اور اس کے بعد کے ورژنوں کے بارے میں ہے۔ یہ ورژن [Owner: date] کو جاری ہوا۔

#### ایپ کیا کیا محفوظ کرتی ہے

- **آپ کا اکاؤنٹ:** آپ کی ای میل، آپ کا نام، آپ کا فون نمبر اگر آپ دیں، اور آپ کی چنی ہوئی زبان۔ سائن اِن کی سروس، سوپابیس آتھ، آپ کا پاس ورڈ ایسی شکل (ہیش) میں رکھتی ہے جس سے اصل پاس ورڈ واپس نہیں نکالا جا سکتا۔ یہ سائن اِن کی تفصیل بھی رکھتی ہے، جیسے آپ نے آخری بار کب سائن اِن کیا، اور ہر سائن اِن کس آئی پی ایڈریس سے اور کس براؤزر یا ایپ سے ہوا۔
- **آپ کہاں رہتے ہیں، اگر آپ بتائیں:** آپ کس ملک میں رہتے ہیں، اور آپ کا ٹائم زون۔ یہ دونوں آپ خود چنتے ہیں۔ ایپ وہ ٹائم زون تجویز کر سکتی ہے جو آپ کے فون میں لگا ہے، لیکن صرف وہی محفوظ کرتی ہے جس کی آپ تصدیق کریں۔ ایپ آپ کے لیے جو ملک اور ٹائم زون رکھتی ہے، وہ صرف وہی ہیں جو آپ اسے بتائیں۔ ہم انہیں کبھی آپ کے فون نمبر، آپ کے ایپ اسٹور اکاؤنٹ کے ملک، آپ کے آئی پی ایڈریس، آپ کی زبان یا آپ کے ادائیگی کے طریقے سے اندازہ لگا کر نہیں نکالتے۔ ہم آپ کی قومیت یا امیگریشن اسٹیٹس کبھی نہیں پوچھتے، اور نہ کبھی محفوظ کرتے ہیں۔
- **آپ کے پورٹ فولیو (یعنی آپ کی سب جائیدادیں، ایک جگہ) کی تفصیل:** اس کا نام۔ وہ نام اور فون نمبر جو اس کی رسیدوں پر چھپتے ہیں۔ راست آئی ڈی یا بینک اکاؤنٹ، جو آپ کرایہ داروں کو دکھانے کے لیے چنیں۔ اور یہ کہ رسیدوں پر نمبر کس طرح لگتے ہیں۔ اس کے ساتھ اس سوال کا جواب: "کیا ان جائیدادوں کا مالک ملک سے باہر رہتا ہے؟" یہ جواب ایپ میں کوئی مالک یا منیجر دیتا ہے۔ اور یہ کہ پورٹ فولیو کا نگران کون ہے، اور کب سے۔
- **لیٹر ہیڈ:** وہ لیٹر ہیڈ جو پورٹ فولیو اپنے کاغذات پر چھاپتا ہے، اور اس کا اردو ورژن، اگر آپ شامل کریں۔ اور یہ کہ رسیدیں اے فائیو کاغذ پر چھپتی ہیں یا اے فور پر۔ لیٹر ہیڈ ایک تصویر ہو سکتی ہے جو آپ اپ لوڈ کریں (پی این جی یا جے پی جی فائل) [Owner: or a PDF, once PDF uploads ship]۔ یا آپ اسے ایپ میں ایک لوگو اور کچھ تفصیل سے بنا سکتے ہیں، جیسے انگریزی اور اردو میں کاروبار کا نام، ایک پتہ، اور ایک فون نمبر یا ای میل۔ [Owner: the builder's fields are not decided.]
- **جو آپ درج کریں:** آپ کی جائیدادیں اور یونٹ۔ آپ کے کرایہ داروں کی تفصیل، جیسے نام، شناختی کارڈ نمبر، فون نمبر اور حوالے۔ کرایہ داریاں، کرایہ، ادائیگیاں، رسیدیں، خرچے، بجلی، گیس اور پانی وغیرہ کے بل، اور میٹر ریڈنگ۔ اور جو تصویریں یا کاغذات آپ ساتھ لگائیں۔
- **یاد دہانیاں:** آپ ایپ سے جو بھی واٹس ایپ یاد دہانی کھولیں، اس کا ریکارڈ: کب کھولی، کس کرایہ داری کے لیے، کس زبان میں، اور خود پیغام، اس کے پہلے 1,000 حروف تک۔ اس پیغام میں کرایہ دار کا نام، ان کے ذمے باقی رقم، اور ادائیگی کی وہ تفصیل ہو سکتی ہے جو کرایہ دار کو دکھائی جاتی ہے۔ [Lawyer: T4]
- **کس نے کیا کیا:** ریکارڈ اور رقم میں ہر تبدیلی کا آڈٹ ریکارڈ، یعنی کس نے کیا بدلا اور کب، تاکہ مالک اس پر بھروسا کر سکے جو نگران درج کرتا ہے۔ یہ ریکارڈ یہ بھی رکھتا ہے کہ مالک کے ملک سے باہر رہنے کے سوال کا جواب کس نے دیا، نگران کس نے چنا، اور لیٹر ہیڈ میں کیا تبدیلیاں ہوئیں۔ جب کوئی ریکارڈ بدلتا ہے یا ڈیلیٹ ہوتا ہے، تو یہ اس کی پہلے والی تفصیل بھی رکھتا ہے۔ ایپ شناختی کارڈ نمبر اس آڈٹ ریکارڈ میں نہیں لکھتی، اور نہ یہ کہ آپ کہاں رہتے ہیں۔
- **اطلاعات:** ایپ کے "اطلاعات" والے حصے میں آپ کے پیغام، جن میں کسی کرایہ دار، یونٹ اور رقم کا ذکر ہو سکتا ہے۔
- **پرائیویسی کے بارے میں آپ کے فیصلے:** نیچے "پرائیویسی کے بارے میں آپ کے فیصلے" والے حصے میں بتائے گئے ہر سوئچ کے لیے: وہ آن ہے یا نہیں، آپ نے اس کے بارے میں جو الفاظ دیکھے ان کا ورژن، آپ نے اسے کب آن یا بند کیا، اور کیسے۔

#### کون دیکھ سکتا ہے

- کسی پورٹ فولیو کا ریکارڈ صرف وہی لوگ دیکھ سکتے ہیں جنہیں آپ اس پورٹ فولیو میں دعوت بھیجیں، اور ہر شخص صرف اتنا جتنا اس کا رول اجازت دے: مالک، منیجر، اکاؤنٹنٹ، یا صرف دیکھنے والا۔ [Lawyer: T3]
- ایک پورٹ فولیو کے لوگ ایک دوسرے کا نام، ای میل اور فون نمبر دیکھ سکتے ہیں۔ [Lawyer: C7]
- ایپ استعمال کرنے والا کوئی اور شخص یہ نہیں دیکھ سکتا کہ آپ کہاں رہتے ہیں، یا آپ کا ٹائم زون کیا ہے: نہ آپ کے کسی بھی پورٹ فولیو کے لوگ، نگران سمیت، اور نہ کبھی کرایہ دار۔
- پورٹ فولیو کا ہر ممبر دیکھ سکتا ہے کہ اس کا مالک ملک سے باہر رہتا ہے یا نہیں، اور اس کا نگران کون ہے۔
- نگران ہمیشہ ایپ استعمال کرتا ہے، منیجر کے رول والے ممبر کے طور پر۔ نگران کو صرف کوئی مالک چن یا بدل سکتا ہے۔ اگر نگران خود پورٹ فولیو چھوڑ دے یا کوئی مالک اسے نکال دے، اس کا رول بدل جائے، یا اس کا اکاؤنٹ ڈیلیٹ ہو جائے، تو وہ نگران نہیں رہتا۔
- کرایہ دار ایپ استعمال نہیں کرتے۔ وہ صرف وہی دیکھتے ہیں جو آپ انہیں دیں: رسیدیں اور اسٹیٹمنٹ، اور واٹس ایپ کے وہ پیغام جو آپ بھیجیں۔ رسیدوں اور اسٹیٹمنٹ پر پورٹ فولیو کا لیٹر ہیڈ ہوتا ہے، اور جاری کرنے والے کے طور پر آپ کی تفصیل۔
- اسکرین پر شناختی کارڈ نمبر کا زیادہ حصہ پہلے سے چھپا رہتا ہے۔ پورا نمبر صرف تب نظر آتا ہے جب آپ خود اسے دکھائیں۔
- شناختی کاغذات اور تصویریں نجی اسٹوریج میں رہتی ہیں۔ یہ صرف ایسے لنک سے کھلتی ہیں جو تھوڑی دیر بعد ایکسپائر ہو جاتے ہیں۔ لیٹر ہیڈ کی فائلیں بھی نجی اسٹوریج میں رہتی ہیں، ہر پورٹ فولیو کی الگ۔ کوئی مالک کسی پورٹ فولیو کا لیٹر ہیڈ اپنے دوسرے پورٹ فولیو میں کاپی کر سکتا ہے، جن میں دوسرے ممبر بھی ہو سکتے ہیں۔ [Owner: which roles may see and change a letterhead. Lawyer: L4]
- جو لوگ ہمارے لیے ایپ چلاتے ہیں، وہ ڈیٹابیس تک پہنچ سکتے ہیں: اسے چلتا رکھنے کے لیے، کسی خرابی کے بعد اسے واپس لانے کے لیے، اور آپ کی درخواستوں کا جواب دینے کے لیے۔ [Owner: who they are, and the rule for when they may look at records.] [Lawyer: R5]

#### ہم یہ ڈیٹا کیوں استعمال کرتے ہیں

- آپ کے لیے، اور ان لوگوں کے لیے جنہیں آپ دعوت بھیجیں، ایپ چلانے کے لیے: آپ کا اکاؤنٹ، آپ کا ریکارڈ، رسیدیں، یاد دہانیاں اور آڈٹ ریکارڈ۔
- ایپ اور آپ کے اکاؤنٹ کو محفوظ رکھنے کے لیے، اور کسی غلطی یا خرابی کے بعد آپ کا ریکارڈ واپس لانے کے لیے۔
- آپ کو وہ ای میلز بھیجنے کے لیے جو سروس کے لیے ضروری ہیں، جن کا ذکر "ای میلز" والے حصے میں ہے۔
- آپ کا ٹائم زون: صرف آپ کی اپنی اطلاعات اور خلاصوں کے لیے، ان گھنٹوں کے لیے جن میں آپ اطلاعات نہیں چاہتے، اور اس وقت کے لیے جو ایپ آپ کو پاکستان کے وقت کے ساتھ دکھاتی ہے۔ کرائے کی تاریخیں، چارجز دینے کی تاریخیں، پولیس رجسٹریشن کی آخری تاریخیں، ٹیکس سال، اور کرایہ داروں کو جانے والا ہر پیغام، یہ سب پاکستان کے وقت پر ہی رہتے ہیں۔
- آپ کی رہائش کا ملک: صرف کوئی پلان تجویز کرنے کے لیے۔ اس سے کبھی کوئی قیمت نہیں بدلتی۔ قیمت وہ ایپ اسٹور طے کرتا ہے جو آپ استعمال کرتے ہیں۔ جو ملک آپ ہمیں بتائیں، وہ ہم کبھی اینالیٹکس یا ای میل کی سروسز کو نہیں بھیجتے۔
- صرف اگر آپ انہیں آن کریں: استعمال کی اینالیٹکس، سپورٹ چیٹ، اور ای میل پر ٹپس اور خبریں۔
- اس ویب سائٹ پر: وزٹس گننے کے لیے، جب تک آپ یہ گنتی بند نہ کریں۔

[Lawyer: N7, the basis for each purpose.]

#### ڈیٹا کہاں رہتا ہے، اور ایپ چلانے والی سروسز

یہ سروسز ہمارے لیے ڈیٹا سنبھالتی ہیں، اور ہر ایک صرف سروس کا اپنا حصہ چلانے کے لیے:

- **[سوپابیس](https://supabase.com/privacy)** ڈیٹابیس، سائن اِن کی سروس اور محفوظ کی گئی فائلیں بھارت میں، اپنے ممبئی ریجن (<kbd lang="en" dir="ltr">ap-south-1</kbd>) میں رکھتی ہے۔ جو فائلیں آپ کھولیں، وہ سوپابیس کے ایسے سرورز سے بھی آ سکتی ہیں جو بھارت سے باہر ہوں، اور یہ سرورز ان کی کاپیاں رکھ سکتے ہیں۔ اس کی سروس کے لاگ، یعنی سروس کا اپنا ریکارڈ کہ کب کیا ہوا، یورپی یونین میں رہتے ہیں۔ اس کا سپورٹ اسٹاف کئی ملکوں سے کام کرتا ہے۔ جب ہم ان سے مدد مانگیں، یا جب سوپابیس سیکیورٹی کے کسی مسئلے سے نمٹ رہی ہو، تو وہ سسٹم تک پہنچ سکتے ہیں۔ کچھ کام، جیسے دعوت بھیجنا یا اکاؤنٹ ڈیلیٹ کرنا، سوپابیس کے ایسے سرورز پر بھی چل سکتے ہیں جو بھارت سے باہر ہوں۔ [To confirm: where Supabase runs these tasks (data map, gap 11). Lawyer: X1] سوپابیس سنگاپور کی کمپنی ہے، اور امریکہ میں اس کی کمپنی سپورٹ دیتی ہے اور سسٹم چلانے کا کام کرتی ہے۔
- **[ری سینڈ](https://resend.com/legal/privacy-policy)** [To confirm: in the United States] وہ ای میلز بھیجتی ہے جن سے آپ اپنی ای میل کی تصدیق کرتے ہیں اور نیا پاس ورڈ بناتے ہیں۔ اسے پتہ ہوتا ہے کہ ای میل کس کو جا رہی ہے، اور پیغام کیا ہے۔ [To confirm: that Supabase Auth sends these emails through Resend. The owner reported it set up, and it has not been checked (`.planning/STATE.md`:197-199).]
- **[کسٹمر ڈاٹ آئی او](https://customer.io/legal/privacy-policy)**، امریکہ میں، ایپ کی دوسری ای میلز بھیجتی ہے، جن کا ذکر "ای میلز" والے حصے میں ہے۔
- **[پوسٹ ہاگ](https://posthog.com/privacy)**، امریکہ میں، ویب سائٹ کے وزٹس کی گنتی کرتی ہے۔ ایپ اسے استعمال کی اینالیٹکس صرف تب بھیجتی ہے جب آپ اس کا سوئچ آن کریں۔ یہ ڈیٹا برطانیہ اور جرمنی میں پوسٹ ہاگ کی اپنی کمپنیاں بھی سنبھال سکتی ہیں، اور جرمنی اور فرانس میں سیکیورٹی کی ایک سروس بھی، جو پوسٹ ہاگ استعمال کرتی ہے۔ پوسٹ ہاگ تک پہنچتے ہوئے یہ ڈیٹا کلاؤڈ فلیئر کے نیٹ ورک سے گزرتا ہے، جو دنیا بھر میں ہے۔ [Lawyer: X1]
- **[انٹرکام](https://www.intercom.com/legal/privacy)** [Owner: the region chosen for the workspace] سپورٹ چیٹ چلاتی ہے، صرف اگر آپ اسے آن کریں۔
- **[ورسل](https://vercel.com/legal/privacy-policy)** [To confirm: in the United States] یہ ویب سائٹ، اور ویب براؤزر میں چلنے والی ایپ، آپ تک پہنچاتی ہے۔
- **[گٹ ہب](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)** ہفتہ وار انکرپٹ کیا ہوا بیک اپ اپنے سرورز پر رکھتا ہے، جو امریکہ اور دوسرے ملکوں میں ہیں۔ اس بیک اپ کا ذکر "ڈیٹا کب تک رہتا ہے" والے حصے میں ہے۔
- ویب براؤزر میں ایپ اپنے فونٹ ساتھ رکھتی ہے۔ اگر الفاظ میں کوئی ایسا حرف ہو جو ان فونٹس میں نہیں، جیسے کوئی ایموجی یا کسی اور زبان کا حرف، تو براؤزر اس کے لیے [گوگل فونٹس](https://policies.google.com/privacy) (<kbd lang="en" dir="ltr">fonts.gstatic.com</kbd>) سے ایک فونٹ ڈاؤن لوڈ کرتا ہے۔ تب گوگل کو آپ کا آئی پی ایڈریس اور مانگے گئے فونٹ کا نام ملتا ہے، آپ کے الفاظ نہیں۔ اینڈرائیڈ اور آئی فون پر ایپ ایسا نہیں کرتی۔
- واٹس ایپ یاد دہانیاں آپ کے اپنے فون پر واٹس ایپ میں کھلتی ہیں، اور آپ انہیں خود اپنے نمبر سے بھیجتے ہیں۔ ایپ انہیں آپ کی طرف سے نہیں بھیجتی، اور نہ آپ کا واٹس ایپ پڑھتی ہے۔

بھارت، سنگاپور، یورپی یونین، امریکہ اور اوپر بتائے گئے دوسرے ملک پاکستان سے باہر ہیں۔ یہ سروسز ڈیٹا کو اپنی اسٹینڈرڈ شرائط کے تحت سنبھالتی ہیں، جو ڈیٹا ایک ملک سے دوسرے ملک بھیجنے کے بارے میں ہیں۔ [Lawyer: X1, X2]

#### پرائیویسی کے بارے میں آپ کے فیصلے

سیٹنگز میں "پرائیویسی" کے حصے میں تین سوئچ ہیں۔ تینوں بند رہتے ہیں، جب تک آپ انہیں آن نہ کریں۔ آپ ہر ایک کو کبھی بھی دوبارہ بند کر سکتے ہیں، اور اسی وقت سے اس کا کام رک جاتا ہے۔ جو کچھ پہلے جا چکا ہے، اسے ڈیلیٹ کروانا ہو تو ہمیں لکھیں، یا اپنا اکاؤنٹ ڈیلیٹ کریں۔

- **استعمال کی اینالیٹکس** ([پوسٹ ہاگ](https://posthog.com/privacy)، امریکہ)۔ ایپ پوسٹ ہاگ کو بتاتی ہے کہ آپ تقریباً 20 کاموں میں سے کون سے کام کرتے ہیں، جیسے جائیداد شامل کرنا یا رسید بھیجنا۔ ایپ یہ بات ایک ایسے کوڈ کے ساتھ بھیجتی ہے جو اینالیٹکس کے لیے بنا ہے۔ یہ کوڈ آپ کے اکاؤنٹ کی آئی ڈی نہیں ہے۔ کچھ بھی بھیجنے سے پہلے ایپ اس میں سے نام، فون نمبر، شناختی کارڈ نمبر، آئی بین نمبر اور رقمیں نکال دیتی ہے۔ آپ کے ریکارڈ میں سے کچھ نہیں جاتا، اور آپ کی اسکرین کبھی ریکارڈ نہیں ہوتی۔ ایپ ہر کام کے ساتھ آپ کے فون کی کچھ تکنیکی تفصیل بھی بھیجتی ہے: فون کی کمپنی اور ماڈل، سسٹم کا ورژن، ایپ کا ورژن اور اسکرین کا سائز۔ [Owner: the final list. PostHog's libraries also add the phone's language and time-zone settings and, on Android, its mobile network; either the analytics wrapper removes them, or this sentence names them. Lawyer: A11] پوسٹ ہاگ آپ کے آئی پی ایڈریس سے معلوم کرتی ہے کہ آپ کس ملک اور شہر میں ہیں، یہ بات رکھتی ہے، اور آئی پی ایڈریس مٹا دیتی ہے۔ یہ وہ ملک نہیں جو آپ نے ایپ کو بتایا، اور ہم اسے کبھی آپ کے پلان یا اطلاعات کے لیے استعمال نہیں کرتے۔ [Owner: or switch off the GeoIP step in PostHog, and delete the last two sentences. Lawyer: A5] [Owner: whether the app in a web browser has analytics at all. Lawyer: A10]
- **سپورٹ چیٹ** ([انٹرکام](https://www.intercom.com/legal/privacy) [Owner: region])۔ جب یہ آن ہو، تو آپ اینڈرائیڈ اور آئی فون پر ایپ سے ہمارے ساتھ چیٹ کر سکتے ہیں۔ ابھی ویب ایپ میں چیٹ نہیں ہے۔ انٹرکام کو یہ چیزیں ملتی ہیں: ہمارا بنایا ہوا آپ کا ایک کوڈ (آپ کی ای میل یا فون نمبر نہیں)، آپ کی زبان، ایپ کا ورژن، اور جو کچھ آپ چیٹ میں لکھیں۔ اس کا سافٹ ویئر کچھ چیزیں خود بھی جمع کرتا ہے، جیسے آپ کے فون کی ایک پہچان، اور یہ کہ آپ چیٹ کیسے استعمال کرتے ہیں۔ ہر درخواست کی طرح اسے آپ کے فون کا آئی پی ایڈریس بھی ملتا ہے۔ [To confirm: what Intercom's Android and iOS libraries send and keep about the phone and its location. Lawyer: A8] چیٹ میں اپنے کرایہ داروں کے شناختی کارڈ نمبر یا ان کی کوئی اور تفصیل نہ لکھیں۔ جب آپ یہ سوئچ بند کریں یا سائن آؤٹ کریں، تو ایپ آپ کو چیٹ سے بھی سائن آؤٹ کر دیتی ہے۔
- **ای میل پر ٹپس اور خبریں** ([کسٹمر ڈاٹ آئی او](https://customer.io/legal/privacy-policy)، امریکہ)۔ ان کا ذکر "ای میلز" والے حصے میں ہے۔

ایپ میں کوئی اشتہار نہیں، اور ایپ دوسری ایپس یا ویب سائٹس پر آپ کا پیچھا نہیں کرتی۔

#### ای میلز

- **سروس کی ای میلز** سروس کا حصہ ہیں، اس لیے یہ جاتی ہیں، چاہے ٹپس اور خبروں کے بارے میں آپ کا فیصلہ کچھ بھی ہو۔ یہ ای میلز ہیں: کسی پورٹ فولیو میں شامل ہونے کی دعوت، وہ رسیدیں جو آپ ای میل کرنا چنیں، ایپ اور اکاؤنٹ کی سیکیورٹی کے بارے میں اطلاعات، اور آپ کے اکاؤنٹ اور سروس کے بارے میں پیغام۔ ان پیغاموں میں وہ اطلاع بھی ہے جو ہم کوئی بھی رقم لینے سے کم از کم 60 دن پہلے بھیجتے ہیں۔ یہ ای میلز کسٹمر ڈاٹ آئی او بھیجتی ہے، سوائے سائن اِن کی ای میلز کے، جو ری سینڈ بھیجتی ہے۔ ان میں آپ کی ای میل، آپ کا نام، آپ کی زبان اور پیغام ہوتا ہے۔ جو رسید آپ ای میل کریں، اس میں وہ سب ہوتا ہے جو رسید پر ہے۔ ہم یہ ٹریک نہیں کرتے کہ آپ یہ ای میلز کھولتے ہیں یا ان کے لنک پر کلک کرتے ہیں۔ [Owner: confirm that open and click tracking are off for these emails at Customer.io before this sentence is published. At Resend they are off, as the owner reported on 12 November 2026 (docs/release-readiness.md, item 5). Lawyer: E6] [Owner: E2, what an emailed receipt carries. Lawyer: E1, E3]
- **ٹپس اور خبریں** صرف تب آتی ہیں جب آپ انہیں آن کریں: سیٹنگز میں، یا اکاؤنٹ بناتے وقت ایک خانے پر نشان لگا کر، جو پہلے سے خالی ہوتا ہے۔ ہر ای میل میں ان ای میلز کو بند کرنے کا لنک (ان سبسکرائب) ہوتا ہے۔ اس لنک سے بند کرنے پر ایپ میں بھی یہ سوئچ بند ہو جاتا ہے۔ ان ای میلز کے لیے کسٹمر ڈاٹ آئی او کو یہ چیزیں ملتی ہیں: آپ کی ای میل، نام، زبان اور پلان، اور یہ کہ آپ نے ایپ میں کچھ کام پہلی بار کب کیے، جیسے جائیداد شامل کرنا یا ادائیگی درج کرنا۔ اسے آپ کے کرایہ داروں کی تفصیل یا کوئی رقم کبھی نہیں ملتی۔ [Owner: whether opens and clicks are counted; if they are, say so here. Lawyer: E4]
- ہم آپ کے کرایہ داروں کو کبھی ای میل نہیں بھیجتے۔

#### آپ کے کرایہ داروں کی تفصیل

جب آپ کسی کرایہ دار کو درج کرتے ہیں، تو ان کی ذاتی تفصیل آپ کے پاس ہوتی ہے، اور آپ ہی طے کرتے ہیں کہ کیا درج کرنا ہے اور کیوں۔ ہم یہ تفصیل آپ کے لیے، آپ کی ہدایت پر رکھتے ہیں، اور اسے صرف آپ کے لیے ایپ چلانے میں استعمال کرتے ہیں۔ [Lawyer: R1]

- ایپ آپ سے کہتی ہے کہ کرایہ دار کی رضامندی درج کریں: انہوں نے کب دی، اور کس مقصد کے لیے۔ صرف وہی معلومات لیں جن کی ضرورت ہو، جیسے وہ معلومات جو پولیس رجسٹریشن کے لیے مانگتی ہے، اور انہیں تازہ رکھیں۔ [Lawyer: T5]
- کوئی نگران یا دوسرا ممبر آپ کے لیے کرایہ دار درج کر سکتا ہے۔ وہ جو کچھ درج کریں، وہ آپ کے پورٹ فولیو کا حصہ ہے، اور آڈٹ ریکارڈ دکھاتا ہے کہ اسے کس نے درج کیا۔
- ہم آپ کے کرایہ داروں کی تفصیل کبھی اینالیٹکس، سپورٹ چیٹ یا ٹپس اور خبروں کو نہیں بھیجتے۔ یہ کسی ای میل سروس تک صرف اس ای میل میں پہنچتی ہے جو آپ ایپ سے بھجوائیں، جیسے وہ رسید جو آپ ای میل کرنا چنیں، اور سپورٹ چیٹ تک صرف تب جب آپ خود اسے وہاں لکھیں۔ [Owner: once they ship, name the weekly summary and the owner's statement by email (`docs/roadmap/overseas-oversight.md`:99-102, :129). Lawyer: E2]
- اگر کوئی کرایہ دار اپنی تفصیل دیکھنا، ٹھیک کروانا یا ڈیلیٹ کروانا چاہیں، تو وہ آپ سے کہیں۔ اگر کوئی کرایہ دار ہمیں لکھیں، تو ہم ان کی درخواست آپ تک پہنچا دیتے ہیں۔ [Lawyer: R4]
- آپ کسی کرایہ دار کو صرف تب ڈیلیٹ کر سکتے ہیں جب کوئی کرایہ داری ان سے جڑی نہ ہو۔ ورنہ آپ انہیں آرکائیو کر سکتے ہیں۔ اس سے وہ آپ کی فہرستوں میں نظر نہیں آتے، لیکن ان کی تفصیل کرایہ داری کے ریکارڈ کے ساتھ رہتی ہے۔ [Lawyer: T2]
- [Owner: once work item 5 exists, a link to the printable notice and consent form for tenants, on your letterhead.]

#### ڈیٹا کب تک رہتا ہے

- **آپ کا اکاؤنٹ:** جب تک آپ اسے ڈیلیٹ نہ کریں۔
- **آپ کہاں رہتے ہیں، اور آپ کا ٹائم زون:** جب تک آپ انہیں بدل یا مٹا نہ دیں، یا اپنا اکاؤنٹ ڈیلیٹ کرنا شروع نہ کریں۔ اکاؤنٹ ڈیلیٹ ہونا شروع ہوتے ہی یہ فوراً مٹ جاتے ہیں۔
- **آپ کا ریکارڈ، کاغذات اور تصویریں:** جب تک آپ انہیں ڈیلیٹ نہ کریں، پورٹ فولیو ڈیلیٹ نہ کریں، یا اپنا اکاؤنٹ ڈیلیٹ نہ کریں۔ یہ ورژن کرایہ داری ختم ہونے پر شناختی کاغذات خود بخود ڈیلیٹ نہیں کرتا۔ ہمارا ارادہ ہے کہ یہ کام بعد کے کسی ورژن میں آئے۔ رقم کی جو انٹری کینسل ہو، وہ مٹائی نہیں جاتی۔ وہ کینسل کے نشان کے ساتھ ریکارڈ میں رہتی ہے، تاکہ رسیدوں کے نمبر ایک کے بعد ایک رہیں اور بیچ میں کوئی نمبر خالی نہ ہو۔
- **لیٹر ہیڈ:** جب تک آپ انہیں بدل یا ہٹا نہ دیں، یا پورٹ فولیو ڈیلیٹ نہ کریں۔ [Owner: whether a replaced letterhead's file is kept for documents already issued.]
- **یاد دہانیوں کا ریکارڈ اور آڈٹ ریکارڈ:** جب تک پورٹ فولیو رہے۔
- **ایپ میں آپ کی اطلاعات:** 180 دن۔
- **وہ دعوتیں جو قبول نہیں ہوئیں:** ایکسپائر ہونے کے بعد 90 دن تک۔ ہر دعوت 7 دن تک کام کرتی ہے، پھر ایکسپائر ہو جاتی ہے۔
- **پرائیویسی کے بارے میں آپ کے فیصلے:** [Owner and Lawyer: A6, how long a record is kept after you switch a choice off.]
- **پوسٹ ہاگ کے پاس وزٹس کی گنتی اور استعمال کی اینالیٹکس:** [Owner: a period that the organisation's PostHog plan allows. Today the project keeps events for 84 months (7 years), the organisation's setting. Lawyer: A9]
- **انٹرکام کے پاس سپورٹ چیٹ:** [Owner: a period.]
- **کسٹمر ڈاٹ آئی او کے پاس ای میلز:** [Owner: a period, and whether the text of each email is kept in its delivery records. Lawyer: E5]
- **ری سینڈ کے پاس ای میلز:** [To confirm: 30 days.]
- **ورسل کے پاس ہوسٹنگ کا ریکارڈ:** [To confirm: Vercel's period.]

ہفتے میں ایک بار ڈیٹابیس کا، تصویروں اور کاغذات سمیت، ایک انکرپٹ کیا ہوا (تالا لگا) بیک اپ بنتا ہے۔ اس سے کسی غلطی یا خرابی کے بعد ریکارڈ واپس لایا جا سکتا ہے۔ اس بیک اپ میں یہ بھی ہوتا ہے کہ آپ کہاں رہتے ہیں، پرائیویسی کے بارے میں آپ کے فیصلے، اور آپ کے لیٹر ہیڈ کی تفصیل۔ [Owner: whether it also includes the letterhead files.] یہ بیک اپ [گٹ ہب](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement) کے سرورز پر ایک خود چلنے والا کام بناتا ہے، اور وہیں اسے انکرپٹ کرتا ہے، تاکہ صرف ایپ چلانے والا اسے کھول سکے۔ گٹ ہب یہ بیک اپ 90 دن رکھتا ہے۔ جو کچھ آپ ڈیلیٹ کریں، وہ ان بیک اپ میں ان کے ختم ہونے تک، یعنی زیادہ سے زیادہ 90 دن بعد تک، رہ سکتا ہے۔ [Lawyer: X3]

#### اکاؤنٹ ڈیلیٹ کرنا

آپ ایپ کے اندر سیٹنگز میں جا کر اپنا اکاؤنٹ ڈیلیٹ کر سکتے ہیں۔ اگر آپ ایپ استعمال نہیں کر سکتے، تو نیچے دی گئی ای میل پر ہمیں لکھیں۔ اکاؤنٹ ڈیلیٹ کرنے پر:

- آپ کا اکاؤنٹ ڈیلیٹ ہو جاتا ہے، اور ہر وہ پورٹ فولیو بھی جس کے آپ اکیلے مالک ہیں، اپنے ریکارڈ، لیٹر ہیڈ اور فائلوں سمیت۔
- جو پورٹ فولیو دوسروں کے ہیں، ان سے آپ نکل جاتے ہیں، اور اگر آپ ان میں نگران ہیں تو آپ کا نگران ہونا بھی ختم ہو جاتا ہے۔
- ڈیلیٹ ہونا شروع ہوتے ہی آپ کی رہائش کا ملک اور ٹائم زون مٹ جاتے ہیں۔
- ہم پوسٹ ہاگ، انٹرکام اور کسٹمر ڈاٹ آئی او سے کہتے ہیں کہ آپ کے بارے میں ان کے پاس جو کچھ ہے، اسے ڈیلیٹ کریں، اور یہ سروسز اسے [Owner: a time limit. Lawyer: D3] کے اندر ڈیلیٹ کرتی ہیں۔

جو پورٹ فولیو دوسروں کے ہیں، ان میں آپ کا بنایا ہوا ریکارڈ رہتا ہے، کیونکہ وہ انہی پورٹ فولیو کا ہے۔ لیکن پھر وہ آپ کے اکاؤنٹ سے نہیں جڑا رہتا۔ وہاں کا آڈٹ ریکارڈ پھر بھی دکھاتا ہے کہ آپ نے کیا درج کیا تھا، اور وہاں آپ کی قبول کی ہوئی دعوت میں آپ کی ای میل رہتی ہے، جب تک وہ پورٹ فولیو ڈیلیٹ نہ ہو۔ جب آپ کسی پورٹ فولیو میں شامل ہوئے، تو وہاں کے دوسرے مالکوں کو جو اطلاع ملی، اس میں آپ کی ای میل زیادہ سے زیادہ 180 دن تک رہتی ہے۔ [Lawyer: D5]

### آپ کے حقوق، اور انہیں کیسے استعمال کریں

- **اپنا ڈیٹا دیکھنا:** [Owner: in the app, once a data export exists; until then, write to us and we send you a copy. Lawyer: N1]
- **اسے ٹھیک کرنا:** اپنا نام، فون نمبر، زبان، رہائش کا ملک اور ٹائم زون سیٹنگز میں بدلیں۔ کچھ اور ٹھیک کروانا ہو تو ہمیں لکھیں۔
- **اسے ڈیلیٹ کرنا:** ایپ میں ریکارڈ یا اپنا پورا اکاؤنٹ ڈیلیٹ کریں، جیسا اوپر لکھا ہے، یا ہمیں لکھیں۔
- **اپنا فیصلہ بدلنا:** اینالیٹکس، سپورٹ چیٹ یا ٹپس اور خبریں سیٹنگز میں کبھی بھی بند کریں، یا ٹپس اور خبروں کی کسی بھی ای میل میں انہیں بند کرنے کا لنک (ان سبسکرائب) استعمال کریں۔
- **وزٹس کی گنتی پر اعتراض:** اس صفحے پر دیا گیا سوئچ استعمال کریں، یا اپنے براؤزر میں "ڈو ناٹ ٹریک" آن کریں۔
- **اگر آپ کرایہ دار ہیں:** اپنے مالکِ مکان سے کہیں، کیونکہ وہی طے کرتے ہیں کہ آپ کے بارے میں کیا درج ہو۔ اگر آپ ہمیں لکھیں، تو ہم آپ کی درخواست انہیں پہنچا دیتے ہیں۔

ہم [Owner: a number of] دن کے اندر جواب دیتے ہیں۔ اگر آپ ہمارے جواب سے مطمئن نہ ہوں، تو ہمیں بتائیں۔ [Lawyer: N1, any authority a person can complain to]

### اگر کچھ غلط ہو جائے

اگر ہمیں پتہ چلے کہ سیکیورٹی میں کوئی ایسی خرابی ہوئی ہے جس سے آپ کا ذاتی ڈیٹا خطرے میں ہے (ڈیٹا بریچ)، تو ہم آپ کو بلا وجہ دیر کیے بغیر بتائیں گے۔ جہاں ہو سکے، ہم پتہ چلنے کے 72 گھنٹے کے اندر بتائیں گے۔ ہم ای میل پر بھی بتائیں گے اور ایپ میں بھی۔ ہم بتائیں گے کہ کیا ہوا، کس ڈیٹا پر اس کا اثر پڑا، ہم نے کیا کیا، اور آپ کیا کر سکتے ہیں۔ اگر آپ کے کرایہ داروں کی تفصیل پر اس کا اثر پڑا ہو، تو ہم آپ کو بتائیں گے، تاکہ آپ انہیں بتا سکیں۔ [Lawyer: N2]

### یہ سب کون چلاتا ہے، اور ہم سے کیسے رابطہ کریں

یہ ویب سائٹ اور ایپ <kbd lang="en" dir="ltr">AR LABS (SMC-PRIVATE) LIMITED</kbd> چلاتی ہے۔ یہ سیکیورٹیز اینڈ ایکسچینج کمیشن آف پاکستان (ایس ای سی پی) میں رجسٹرڈ کمپنی ہے (سی یو آئی این 0361950)۔

- یہ ہم طے کرتے ہیں کہ آپ کے اکاؤنٹ کا ڈیٹا، پرائیویسی کے بارے میں آپ کے فیصلے، ویب سائٹ کے وزٹس کی گنتی، استعمال کی اینالیٹکس، سپورٹ چیٹ اور ہماری اپنی ای میلز کیسے استعمال ہوں۔
- اپنی جائیدادوں اور کرایہ داروں کے بارے میں جو ریکارڈ آپ درج کرتے ہیں، وہ آپ کا ہے۔ کیا درج کرنا ہے اور کیوں، یہ آپ طے کرتے ہیں، اور ہم اسے آپ کی طرف سے سنبھالتے ہیں۔ [Lawyer: R1]

اپنا ڈیٹا دیکھنا ہو، اسے ٹھیک کروانا ہو یا ڈیلیٹ کروانا ہو، تو ہمیں [<kbd lang="en" dir="ltr">maalik-e-makaan@news.ar27111994.dev</kbd>](mailto:maalik-e-makaan@news.ar27111994.dev) پر لکھیں۔ [Owner: the address may move with the planned domain (RM:443).]

### اس صفحے میں تبدیلیاں

اگر یہاں کچھ بدلا تو یہ صفحہ سب سے اوپر نئی تاریخ دکھائے گا۔ [Lawyer: N3, whether a change that adds a new kind of data or a new service must also be announced in the app or by email.]

### سوالات

اس ویب سائٹ اور ایپ کا کوڈ سب کے لیے کھلا ہے، اس لیے کوئی بھی دیکھ سکتا ہے کہ یہ کیا کرتی ہیں۔ ہم کچھ سیٹنگز کوڈ میں نہیں، بلکہ خود سروسز کے اندر رکھتے ہیں۔ پوسٹ ہاگ میں یہ سب بند ہیں:

- اسکرین ریکارڈنگ؛
- ہیٹ میپ (صفحے پر کلک کہاں ہوئے، اس کا نقشہ)؛
- کنسول لاگ (براؤزر کے تکنیکی پیغام)؛
- ڈیڈ کلک (ایسے کلک جن سے کچھ نہ ہوا) کا ریکارڈ؛
- آٹو کیپچر (کلک جیسے کام خود بخود ریکارڈ کرنا)؛
- ویب وائٹلز (صفحہ کتنی جلدی کھلا) کا ریکارڈ؛
- سروے۔

پوسٹ ہاگ آئی پی ایڈریس مٹا دیتی ہے، اور کوکی کے بغیر گنتی آن ہے۔ [Owner: the matching settings for Intercom and Customer.io. Lawyer: N4]

کوئی سوال پوچھنا ہو یا کوئی خرابی بتانی ہو، تو پروجیکٹ کے [گٹ ہب صفحے](https://github.com/ar27111994/maalik-e-makaan/issues) پر لکھیں۔ سیکیورٹی کا کوئی مسئلہ ہو تو اسے سب کے سامنے نہیں، الگ سے بتائیں، جیسا کہ ہماری [سیکیورٹی پالیسی](https://github.com/ar27111994/maalik-e-makaan/security/policy) میں لکھا ہے۔

## Words chosen for legal and technical terms

For the lawyer's check that the Urdu carries the same meaning and legal effect as the English. Each
choice follows the glossary where it has an entry, and the live Urdu pages where they already use
the word. A glossary entry is named here by the English it stands for, so that this file does not
repeat the words the glossary avoids.

| English in the draft                                                               | Urdu in this draft                                                                   | Why                                                                                                                                                                                                                                                                                                                                                 |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| privacy                                                                            | پرائیویسی                                                                            | The glossary's "privacy" entry: the formal word it avoids means secrecy                                                                                                                                                                                                                                                                             |
| analytics; usage analytics                                                         | اینالیٹکس, glossed once; استعمال کی اینالیٹکس                                        | The glossary's "analytics" entry. Its gloss suits the old promise of no analytics, so this draft says what analytics now is: "یعنی یہ گنتی کہ ایپ کیسے استعمال ہوتی ہے" ([website-copy.md](website-copy.md), item 16)                                                                                                                               |
| count visits; without knowing who you are                                          | وزٹس گننا، وزٹس کی گنتی کرنا؛ آپ کی پہچان کے بغیر                                    | The glossary's "counted" entry prefers گنتی. Where the verb "گنتی ہے" could be read as the noun, the draft writes "گنتی کرتی ہے". The English now says "without knowing who you are" too; whether the counting is anonymous in law is question A2                                                                                                   |
| cookie; we do not track whether you open emails or click their links; Do Not Track | کوکی؛ "ٹریک نہیں کرتے کہ آپ … کھولتے ہیں یا … کلک کرتے ہیں"؛ "ڈو ناٹ ٹریک"           | کوکی as the live page writes it (PUR:3, :9); ٹریک, the verb behind its ٹریکنگ (PUR:9, :17)                                                                                                                                                                                                                                                          |
| switch on, switch off; off until you switch it on (opt-in)                         | آن کرنا، بند کرنا؛ "تینوں بند رہتے ہیں، جب تک آپ انہیں آن نہ کریں"                   | Everyday words for a switch. What happens comes first, and the opt-in condition stays in the same sentence                                                                                                                                                                                                                                          |
| a privacy choice; your choice (to switch counting off)                             | فیصلہ; "پرائیویسی کے بارے میں آپ کے فیصلے"                                           | An everyday word for what a person has decided. انتخاب (selection) is bookish, and the glossary's "choose, select" entry prefers the plain چننا to the formal verb                                                                                                                                                                                  |
| support chat; tips and news by email; unsubscribe                                  | سپورٹ چیٹ؛ ای میل پر ٹپس اور خبریں؛ ان سبسکرائب, glossed as the link that stops them | Words people say. "Tips" is not مشورے, so that it is never read as advice                                                                                                                                                                                                                                                                           |
| your browser's description ("user agent")                                          | آپ کے براؤزر کی تفصیل, with the Latin term                                           | Not یوزر, which the glossary's "user(s)" entry says most readers do not say                                                                                                                                                                                                                                                                         |
| a code; a random value that changes every day                                      | ایک کوڈ؛ ہر روز بدلنے والا ایک رینڈم نمبر                                            | The hashed password keeps the live page's "ایسی شکل (ہیش)" (PUR:25); encryption keeps "انکرپٹ کیا ہوا (تالا لگا)" (PUR:50). Hashing and encryption never share a word (the glossary's "encryption; encrypted; hashed" entry)                                                                                                                        |
| the message itself, up to its first 1,000 characters                               | خود پیغام، اس کے پہلے 1,000 حروف تک                                                  | The live page's words after #62 (PUR:27)                                                                                                                                                                                                                                                                                                            |
| the amount due (in a reminder)                                                     | ان کے ذمے باقی رقم                                                                   | The glossary's one-word-per-thing rule: what is owed is باقی, with ذمے to say who owes it, whether or not its date has come                                                                                                                                                                                                                         |
| where you live; your country                                                       | آپ کہاں رہتے ہیں؛ آپ کی رہائش کا ملک                                                 | Never "آپ کا ملک" alone for the declared country: it can be read as nationality, which the notice says is never asked for. Where PostHog infers a location, the draft says "آپ کس ملک اور شہر میں ہیں"                                                                                                                                              |
| nationality; immigration status                                                    | قومیت؛ امیگریشن اسٹیٹس                                                               | قومیت is the usual word for nationality; اسٹیٹس follows the glossary's "status, situation" entry                                                                                                                                                                                                                                                    |
| lives abroad                                                                       | ملک سے باہر رہتا ہے                                                                  | The glossary's "overseas, living abroad" entry offers this beside اوورسیز. The question is written out in full, as the app asks it (PJ:109-110)                                                                                                                                                                                                     |
| caretaker; name the caretaker                                                      | نگران؛ نگران چننا                                                                    | The glossary keeps نگران for a caretaker in prose and منیجر for the role. چننا, as its "choose, select" entry prefers                                                                                                                                                                                                                               |
| owner, manager, accountant, viewer                                                 | مالک، منیجر، اکاؤنٹنٹ، صرف دیکھنے والا                                               | The app's role names ([`app_ur.arb`](../../app/lib/l10n/arb/app_ur.arb):143-146)                                                                                                                                                                                                                                                                    |
| member                                                                             | ممبر                                                                                 | The glossary's "member" entry                                                                                                                                                                                                                                                                                                                       |
| letterhead; issuer                                                                 | لیٹر ہیڈ؛ جاری کرنے والا                                                             | لیٹر ہیڈ is the word printers and offices use. جاری کرنا is the everyday verb for issuing a paper; the live page already uses جاری for a release (PUR:21)                                                                                                                                                                                           |
| documents                                                                          | کاغذات                                                                               | The glossary's "document(s)" entry                                                                                                                                                                                                                                                                                                                  |
| you decide what to record and why; on your instructions                            | آپ ہی طے کرتے ہیں کہ کیا درج کرنا ہے اور کیوں؛ آپ کی ہدایت پر                        | The English's plain words for the landlord deciding and AR LABS acting for them, without the terms "controller" and "processor" (R1)                                                                                                                                                                                                                |
| on your behalf                                                                     | آپ کی طرف سے                                                                         | As the live page says it of WhatsApp (PUR:38)                                                                                                                                                                                                                                                                                                       |
| consent                                                                            | رضامندی                                                                              | The glossary's keep list; never اجازت, which means permission                                                                                                                                                                                                                                                                                       |
| standard data-transfer terms                                                       | اپنی اسٹینڈرڈ شرائط … جو ڈیٹا ایک ملک سے دوسرے ملک بھیجنے کے بارے میں ہیں            | Says what the terms are about, in words a reader knows; X1 and X2 ask what they must be                                                                                                                                                                                                                                                             |
| breach of security                                                                 | "سیکیورٹی میں کوئی ایسی خرابی … (ڈیٹا بریچ)"                                         | The plain meaning first and the term once in brackets, the glossary's rule for a term of art. خلاف ورزی, which the glossary keeps for breaking a law, would say that someone broke a rule: narrower than a breach, which can be an accident. No deposit is near, so the deposit sense of سیکیورٹی does not arise. The lawyer confirms the word (N2) |
| security notices (e-mails)                                                         | ایپ اور اکاؤنٹ کی سیکیورٹی کے بارے میں اطلاعات                                       | Beside "receipts", a bare "سیکیورٹی کی اطلاعات" could be read as notices about the deposit (the glossary's "security deposit" entry)                                                                                                                                                                                                                |
| without undue delay; within 72 hours                                               | بلا وجہ دیر کیے بغیر؛ 72 گھنٹے کے اندر                                               | The unit stays hours, written as the glossary's "deadline; time allowed" entry writes a period ("48 گھنٹے کے اندر")                                                                                                                                                                                                                                 |
| object to                                                                          | اعتراض                                                                               | Everyday ("اعتراض ہے")                                                                                                                                                                                                                                                                                                                              |
| rights                                                                             | حقوق                                                                                 | An Arabic plural, but the one everyone knows from the news ("انسانی حقوق"); the glossary lets such plurals stay, as it does ذرائع                                                                                                                                                                                                                   |
| delete; clear; archive                                                             | ڈیلیٹ؛ مٹانا؛ آرکائیو                                                                | The glossary's "delete" entry and its آرکائیو keep line; مٹانا as the live page uses it for cancelled entries (PUR:48). Archiving hides a tenant: "فہرستوں میں نظر نہیں آتے", never ہٹ جانا, which reads as removed                                                                                                                                 |
| expire                                                                             | ایکسپائر                                                                             | The glossary's "validity, expiry" entry, and the live page (PUR:35)                                                                                                                                                                                                                                                                                 |
| portfolio                                                                          | پورٹ فولیو, explained at its first use as "یعنی آپ کی سب جائیدادیں، ایک جگہ"         | The glossary's "portfolio" entry keeps the word only with that explanation                                                                                                                                                                                                                                                                          |
| a content delivery network; tasks that may run outside India                       | "ایسے سرورز … جو بھارت سے باہر ہوں"                                                  | What they do, in words readers know; the English also names the network                                                                                                                                                                                                                                                                             |
| an identifier for your phone; make and model                                       | فون کی ایک پہچان؛ فون کی کمپنی اور ماڈل                                              | فون, as the glossary's "device" entry asks: most readers do not say the English word                                                                                                                                                                                                                                                                |

## Changes from the live Urdu notice

The rows that change live Urdu text, by the English draft's row numbers; the reasons and sources
are in [the English table](privacy-notice.en.md#changes-from-the-live-notice). Rows 7, 8, 12, 13,
14, 18, 19, 21, 22, 25, 26, 30, 32 and 38 are new text in both languages and are not repeated.
"Live Urdu" quotes the [live Urdu page](../../website/src/content/pages/ur/privacy.md) at the line
given, as #62 corrected it. When each row is published is the English table's "Ships with" column, under the same number.

| #   | Live Urdu (PUR line)                                                                                  | Note on the Urdu                                                                                                                                                                                                                                                                                                                      |
| --- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | "…سائٹ پر نہ کوکی، نہ ٹریکر۔ ایپ میں آپ کا ریکارڈ صرف وہ لوگ دیکھ سکتے ہیں جنہیں آپ دعوت بھیجیں۔" (3) | Replaced, as in the English                                                                                                                                                                                                                                                                                                           |
| 2   | `lastUpdated: 2026-11-12` (4), the date #62 sets                                                      | One new date for both languages                                                                                                                                                                                                                                                                                                       |
| 3   | "یہ ویب سائٹ نہ کوکی رکھتی ہے، نہ اینالیٹکس اور نہ ٹریکنگ کا کوئی ٹول استعمال کرتی ہے…" (9)           | Replaced. The gloss of اینالیٹکس moves to the third bullet, where the app's analytics first appears                                                                                                                                                                                                                                   |
| 4   | "کیلکولیٹر آپ کے براؤزر کے اندر ہی کام کرتے ہیں…" (10)                                                | Kept word for word. #62 (`fabc088`, release 1.1.1) met the English row's JavaScript-off condition: with JavaScript off, the calculator form sends nothing                                                                                                                                                                             |
| 5   | "ایپ میں آپ کا ریکارڈ آپ کا ہے…" (11)                                                                 | Kept, with one sentence added on the services, and bullets 3 and 5 added                                                                                                                                                                                                                                                              |
| 6   | "…اس لیے پڑھتے وقت آپ کا براؤزر کسی اور سے رابطہ نہیں کرتا۔" (15)                                     | The clause dropped, as in the English; اسکرپٹ added                                                                                                                                                                                                                                                                                   |
| 9   | "ہم اس میں کوئی ٹریکنگ نہیں جوڑتے…" (17)                                                              | The first two sentences kept word for word, under a new heading "ہوسٹنگ"; the last replaced                                                                                                                                                                                                                                           |
| 10  | "یہ حصہ ایپ کے ورژن 1.0 اور اس کے بعد کے ورژنوں کے بارے میں ہے…" (21)                                 | The version and date become placeholders; the sentence on changes moves to "اس صفحے میں تبدیلیاں", word for word                                                                                                                                                                                                                      |
| 11  | "**آپ کا اکاؤنٹ:** …" (25)                                                                            | Kept word for word, with the IP address and the browser or app of each sign-in added at the end                                                                                                                                                                                                                                       |
| 15  | "**جو آپ درج کریں:** …" (26)                                                                          | Kept word for word. The live Urdu already writes "utility bills" as "بجلی، گیس اور پانی وغیرہ کے بل"                                                                                                                                                                                                                                  |
| 16  | "…اور خود پیغام، اس کے پہلے 1,000 حروف تک۔" (27), as #62 corrects it                                  | Kept word for word, with one sentence on what the message can hold. The English draft now takes #62's words too                                                                                                                                                                                                                       |
| 17  | "**کس نے کیا کیا:** …" (28)                                                                           | Kept, with the new entries, the earlier values, and residence never written                                                                                                                                                                                                                                                           |
| 20  | "ڈیٹابیس میں ہر پورٹ فولیو کا ریکارڈ الگ رہتا ہے…" (33)                                               | Follows the proposed English, which leaves out "kept apart in the database" and adds the four roles, named as the FAQ names them (`faq/ur.yaml`:34)                                                                                                                                                                                   |
| 23  | "…پورا نمبر بٹن دبا کر دیکھا جا سکتا ہے۔" (34)                                                        | The English now says what the Urdu said. The new Urdu follows the new English ("only when you choose to see it"), in the words of `home/ur.yaml`:68                                                                                                                                                                                   |
| 24  | "شناختی کاغذات اور تصویریں نجی اسٹوریج میں رہتی ہیں…" (35)                                            | Kept, with the letterhead sentence added                                                                                                                                                                                                                                                                                              |
| 27  | "ریکارڈ ایک ڈیٹابیس میں رہتا ہے جسے سوپابیس چلاتی ہے، اس کے ممبئی ریجن میں۔" (32)                     | Adds بھارت, the region code `ap-south-1` (which the live Urdu leaves out and the live English gives), files served from servers outside India, the logs in the European Union, the support staff (on request or for a security incident), tasks on servers outside India, and Supabase's companies in Singapore and the United States |
| 28  | "ایپ کی ای میلز… ری سینڈ کے ذریعے جاتی ہیں…" (36)                                                     | Resend keeps only the two sign-in e-mails; its last sentence is kept, with "ری سینڈ کو" written as "اسے"                                                                                                                                                                                                                              |
| 29  | Google Fonts (37); WhatsApp (38)                                                                      | Kept word for word                                                                                                                                                                                                                                                                                                                    |
| 31  | "ایپ میں نہ اشتہار ہیں، نہ اینالیٹکس اور نہ ٹریکر۔" (40)                                              | Replaced by the three switches and "…دوسری ایپس یا ویب سائٹس پر آپ کا پیچھا نہیں کرتی"                                                                                                                                                                                                                                                |
| 33  | "جب آپ کسی کرایہ دار کو درج کرتے ہیں…" (44)                                                           | The first sentence kept and extended; the consent sentences kept word for word as the first bullet                                                                                                                                                                                                                                    |
| 34  | "آپ کا ریکارڈ تب تک رہتا ہے…" (48)                                                                    | One line per class, under the heading "ڈیٹا کب تک رہتا ہے", since the section now covers more than records. "ورژن 1.0" becomes "یہ ورژن"; the rest of the paragraph is kept word for word                                                                                                                                             |
| 35  | "ہفتے میں ایک بار ڈیٹابیس کا…" (50)                                                                   | Kept word for word, with one sentence and a placeholder added                                                                                                                                                                                                                                                                         |
| 36  | "آپ ایپ کے اندر سیٹنگز میں جا کر اپنا اکاؤنٹ ڈیلیٹ کر سکتے ہیں…" (54)                                 | The first sentence kept; the rest becomes a list                                                                                                                                                                                                                                                                                      |
| 37  | "اپنے ڈیٹا کے بارے میں پوچھنا ہو، اسے ٹھیک کروانا ہو یا ڈیلیٹ کروانا ہو…" (58)                        | Moves to a section on rights; the contact sentence now says "دیکھنا" (to see it), as the English does                                                                                                                                                                                                                                 |
| 39  | "…اور یہی طے کرتی ہے کہ یہ ڈیٹا کیسے استعمال ہو۔" (58)                                                | Split into what AR LABS decides and what the landlord decides                                                                                                                                                                                                                                                                         |
| 40  | "اگر یہاں کچھ بدلا تو یہ صفحہ سب سے اوپر نئی تاریخ دکھائے گا۔" (21)                                   | Its own section, word for word                                                                                                                                                                                                                                                                                                        |
| 41  | "اس ویب سائٹ اور ایپ کا کوڈ سب کے لیے کھلا ہے…" (62)                                                  | Kept word for word, with the services' settings added, as a list                                                                                                                                                                                                                                                                      |
