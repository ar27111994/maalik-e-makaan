# Website copy and other privacy promises: proposed text (English and Urdu)

> **Draft for the lawyer's review. Not live.** Proposed English and Urdu for every place, outside
> the privacy page itself, that makes a privacy promise which decisions 1 to 3 change. Nothing here
> changes until the lawyer approves the new privacy text and the feature it describes ships; until
> then each line below stays as it is, and stays true, in both languages. This is not legal advice.

Part of the [legal review pack](README.md). The privacy page's own text, its meta description
included, is in [privacy-notice.en.md](privacy-notice.en.md) and
[privacy-notice.ur.md](privacy-notice.ur.md). Line numbers are at commit `ae0112c` on `main` (which includes #62, released in 1.1.1).
Short names: **PJ** and **RM** are [`.planning/PROJECT.md`](../../.planning/PROJECT.md) and
[`docs/roadmap/README.md`](../roadmap/README.md).

Where a place has an Urdu twin, the item quotes the live Urdu with its file and line, and gives the
proposed Urdu after the English. The Urdu follows the owner's glossary
([`contracts/urdu_glossary.json`](../../contracts/urdu_glossary.json)) and the words of the draft
Urdu notice, so that the FAQ and the privacy page say the same thing in the same words. The Urdu
FAQ is in Urdu script only and names a page rather than linking it
([`faq/ur.yaml`](../../website/src/content/faq/ur.yaml):1-5), so PostHog is written پوسٹ ہاگ there
and "Do Not Track" ڈو ناٹ ٹریک. The developer documents in items 9 to 13 are in English only.

The FAQ claims only what [`.planning/REQUIREMENTS.md`](../../.planning/REQUIREMENTS.md) marks done
([`faq/en.yaml`](../../website/src/content/faq/en.yaml):3-5), so each FAQ change ships with its
feature, not before. Each item says when it ships:

- **With website counting:** when PostHog starts counting on the website (decision 3).
- **With the app's switches:** when the app's privacy switches, PostHog in the app, Intercom or
  Customer.io ship (decision 3).
- **With residence:** when decision 1's screens ship.

## Summary

| #   | Place                                                              | Urdu twin                                        | Verdict after the decisions            | Ships                   |
| --- | ------------------------------------------------------------------ | ------------------------------------------------ | -------------------------------------- | ----------------------- |
| 1   | Privacy page meta description, `pages/en/privacy.md`:3             | `pages/ur/privacy.md`:3                          | Untrue                                 | With website counting   |
| 2   | Footer, `src/i18n/ui.ts`:158, on every page                        | `src/i18n/ui.ts`:286                             | Untrue                                 | With website counting   |
| 3   | FAQ "Does this website track me?", `faq/en.yaml`:61-62             | `faq/ur.yaml`:59-60                              | Untrue                                 | With website counting   |
| 4   | FAQ "Who can see my tenants' details?", `faq/en.yaml`:59-60        | `faq/ur.yaml`:57-58                              | Incomplete                             | With the app's switches |
| 5   | FAQ, a new item on the app's analytics                             | New, after `faq/ur.yaml`:58                      | New                                    | With the app's switches |
| 6   | FAQ "Can someone else collect rent for me?", `faq/en.yaml`:35-36   | `faq/ur.yaml`:33-34                              | Incomplete                             | With residence          |
| 7   | Calculators intro, `src/i18n/ui.ts`:257                            | `src/i18n/ui.ts`:385                             | Stays true, on one remaining condition | No change               |
| 8   | Rent increase calculator, `tools/en/rent-increase-calculator.md`:3 | `tools/ur/rent-increase-calculator.md`:3         | Stays true, on one remaining condition | No change               |
| 9   | `website/README.md`:4-7                                            | None                                             | Untrue                                 | With website counting   |
| 10  | `website/README.md`:101-104                                        | None                                             | Untrue                                 | With website counting   |
| 11  | `website/AGENTS.md`:3-4, and a new rule                            | None                                             | Untrue                                 | With website counting   |
| 12  | `README.md`:69                                                     | None                                             | Untrue                                 | With website counting   |
| 13  | `docs/operations.md`:179-182                                       | None                                             | The reason given changes               | With the app's switches |
| 14  | Licences page, `licences/en.yaml`:5                                | `licences/ur.yaml`:6                             | Incomplete once posthog-js is bundled  | With website counting   |
| 15  | Other pages that stay true                                         | Listed in the item                               | Kept                                   | —                       |
| 16  | Planning documents that describe today                             | The glossary's analytics entry changes with them | Kept until the features ship           | With each feature       |

## 1. Privacy page meta description

`website/src/content/pages/en/privacy.md`:3, shown in search results and link previews.

Current:

> How this website and the Maalik-e-Makaan app treat your data: no cookies or trackers on the
> site, and in the app, your records seen only by the people you invite.

Proposed (the same as the draft notice's front matter):

> How this website and the Maalik-e-Makaan app treat your data: no cookies, visits counted
> without knowing who you are, nothing sent to analytics or support chat from the app unless you
> switch it on, and your records seen only by the people you invite and the services that run the
> app.

Current Urdu, `website/src/content/pages/ur/privacy.md`:3:

> یہ ویب سائٹ اور مالکِ مکان ایپ آپ کے ڈیٹا کے ساتھ کیا کرتی ہیں: سائٹ پر نہ کوکی، نہ ٹریکر۔ ایپ میں آپ کا ریکارڈ صرف وہ لوگ دیکھ سکتے ہیں جنہیں آپ دعوت بھیجیں۔

Proposed Urdu (the same as the draft Urdu notice's front matter):

> یہ ویب سائٹ اور مالکِ مکان ایپ آپ کے ڈیٹا کے ساتھ کیا کرتی ہیں: سائٹ پر کوئی کوکی نہیں، اور وزٹس کی گنتی آپ کی پہچان کے بغیر۔ ایپ اینالیٹکس یا سپورٹ چیٹ کو کچھ نہیں بھیجتی، جب تک آپ خود انہیں آن نہ کریں۔ ایپ میں آپ کا ریکارڈ صرف وہ لوگ دیکھ سکتے ہیں جنہیں آپ دعوت بھیجیں، اور وہ سروسز جو ایپ چلاتی ہیں۔

Why: "no … trackers" is untrue once the site counts visits (PJ:141-142). It says "without knowing
who you are", not "anonymously": whether the counting is anonymous in law is
[A2](questions.md#analytics-and-consent), and the Urdu already says the narrower thing.

## 2. Footer

`website/src/i18n/ui.ts`:158 (`footer.privacy`), shown on every page by
[`SiteFooter.astro`](../../website/src/components/SiteFooter.astro):45.

Current:

> This site sets no cookies and uses no analytics or trackers.

Proposed:

> This site sets no cookies and counts visits without knowing who you are.

Current Urdu, `website/src/i18n/ui.ts`:286:

> یہ سائٹ نہ کوئی کوکی رکھتی ہے، نہ اینالیٹکس یا ٹریکنگ کا کوئی ٹول استعمال کرتی ہے۔

Proposed Urdu:

> یہ سائٹ کوئی کوکی نہیں رکھتی، اور وزٹس کی گنتی آپ کی پہچان کے بغیر کرتی ہے۔

Why: PJ:141-142 names the footer. The footer links to the privacy page already
(`SiteFooter.astro`:22), so the short line need not explain more.

## 3. FAQ: "Does this website track me?"

`website/src/content/faq/en.yaml`:61-62.

Current:

> **Does this website track me?** No. It sets no cookies, uses no analytics or trackers and makes no
> requests to other sites. The calculators work inside your browser: nothing you type is sent
> anywhere.

Proposed:

> **Does this website count my visits?** Yes, without knowing who you are. It sets no cookies and stores nothing in
> your browser to count you. Visits are counted with PostHog, in the United States, through this
> site's own address: PostHog turns your IP address and browser details into a code that changes
> every day, and removes the IP address before it keeps anything. You can switch counting off on
> the privacy page, and it does not run if your browser sends Do Not Track. The calculators work
> inside your browser: nothing you type is sent anywhere.

Current Urdu, `website/src/content/faq/ur.yaml`:59-60:

> **کیا یہ ویب سائٹ میری نگرانی کرتی ہے؟** نہیں۔ یہ کوئی کوکی نہیں رکھتی، اور نہ اینالیٹکس یا ٹریکنگ کا کوئی ٹول استعمال کرتی ہے، یعنی کوئی ایسا ٹول نہیں جو گنے کہ کون کیا دیکھتا ہے۔ یہ کسی دوسری سائٹ سے بھی کچھ نہیں منگواتی۔ کیلکولیٹر آپ کے براؤزر کے اندر ہی کام کرتے ہیں: آپ جو لکھتے ہیں وہ کہیں نہیں جاتا۔

Proposed Urdu:

> **کیا یہ ویب سائٹ میرے وزٹس کی گنتی کرتی ہے؟** جی ہاں، لیکن آپ کی پہچان کے بغیر۔ یہ کوئی کوکی نہیں رکھتی، اور آپ کو گننے کے لیے آپ کے براؤزر میں کچھ محفوظ نہیں کرتی۔ وزٹس کی گنتی امریکہ میں پوسٹ ہاگ کرتی ہے، اور یہ اسی سائٹ کے اپنے ایڈریس کے ذریعے ہوتی ہے۔ پوسٹ ہاگ آپ کے آئی پی ایڈریس اور براؤزر کی تفصیل سے ایک کوڈ بناتی ہے، جو ہر روز نیا ہوتا ہے، اور کچھ بھی رکھنے سے پہلے آئی پی ایڈریس ہٹا دیتی ہے۔ آپ پرائیویسی کے صفحے پر یہ گنتی بند کر سکتے ہیں۔ اگر آپ کا براؤزر ڈو ناٹ ٹریک کا سگنل بھیجتا ہے، تو یہ گنتی چلتی ہی نہیں۔ کیلکولیٹر آپ کے براؤزر کے اندر ہی کام کرتے ہیں: آپ جو لکھتے ہیں وہ کہیں نہیں جاتا۔

The Urdu question changes with the English one; its last sentence is kept word for word.

Why: PJ:141-142 names the FAQ; the design is RM:278-285. The question changes because its honest
answer is no longer "No". [Lawyer: A1 to A4 in [questions.md](questions.md#analytics-and-consent).]
[To confirm: RM:316's preview check that PostHog receives the visitor's IP address through the
site's rewrite. If it does not, only page views are counted, and this answer, in both languages,
and the privacy page change.]

## 4. FAQ: "Who can see my tenants' details?"

`website/src/content/faq/en.yaml`:59-60.

Current:

> **Who can see my tenants' details?** Only the people you invite to your portfolio, and only as far
> as their role allows. CNIC numbers are masked on screen by default and identity documents are kept
> in private storage, opened through short-lived links.

Proposed:

> **Who can see my tenants' details?** Only the people you invite to your portfolio, and only as far
> as their role allows, and the services that run the app for us, which the privacy page names.
> Your tenants' details are never sent to analytics. CNIC numbers are masked on screen by default
> and identity documents are kept in private storage, opened through short-lived links.

Current Urdu, `website/src/content/faq/ur.yaml`:57-58:

> **میرے کرایہ داروں کی تفصیلات کون دیکھ سکتا ہے؟** صرف وہ لوگ جنہیں آپ اپنے پورٹ فولیو میں شامل کریں، اور وہ بھی صرف اتنا جتنا ان کا رول اجازت دے۔ شناختی کارڈ نمبر اسکرین پر پہلے سے چھپے رہتے ہیں۔ شناختی کاغذات نجی اسٹوریج میں رہتے ہیں، اور ایسے لنک سے کھلتے ہیں جو تھوڑی دیر بعد کام کرنا بند کر دیتا ہے۔

Proposed Urdu:

> **میرے کرایہ داروں کی تفصیلات کون دیکھ سکتا ہے؟** صرف وہ لوگ جنہیں آپ اپنے پورٹ فولیو میں شامل کریں، اور وہ بھی صرف اتنا جتنا ان کا رول اجازت دے۔ ان لوگوں کے علاوہ صرف وہ سروسز یہ تفصیل دیکھ سکتی ہیں جو ہمارے لیے ایپ چلاتی ہیں۔ ان کے نام پرائیویسی کے صفحے پر ہیں۔ ہم آپ کے کرایہ داروں کی تفصیل کبھی اینالیٹکس کو نہیں بھیجتے۔ شناختی کارڈ نمبر اسکرین پر پہلے سے چھپے رہتے ہیں۔ شناختی کاغذات نجی اسٹوریج میں رہتے ہیں، اور ایسے لنک سے کھلتے ہیں جو تھوڑی دیر بعد کام کرنا بند کر دیتا ہے۔

Why: incomplete today (the hosting and e-mail services hold the data) and after decision 3
(e-mailed receipts through Customer.io, RM:294-297; support chat holds what a person writes). The
answer stays short and points to the privacy page. Every role can read the full CNIC through the
app's server, so "as far as their role allows" is accurate only with the masking caveat
([T3](questions.md#tenants)).

## 5. FAQ: a new item on the app's analytics

Proposed, in the "Privacy" group after item 4:

> **Does the app send my data to analytics?** Only if you switch it on. In Settings, under Privacy,
> usage analytics, support chat and tips and news by email are each off until you choose them, and
> you can switch them off again at any time. Even when analytics is on, the app sends no names,
> phone numbers, CNIC numbers, IBANs or amounts, and never records your screen. It does send
> technical details of your phone, such as its make, model and system version, which the privacy
> page lists.

Proposed Urdu, in the "پرائیویسی" group after item 4 (`faq/ur.yaml`:57-58):

> **کیا ایپ میرا ڈیٹا اینالیٹکس کو بھیجتی ہے؟** صرف تب، جب آپ اسے آن کریں۔ اینالیٹکس کا مطلب ہے یہ گنتی کہ ایپ کیسے استعمال ہوتی ہے۔ سیٹنگز میں "پرائیویسی" کے حصے میں تین سوئچ ہیں: استعمال کی اینالیٹکس، سپورٹ چیٹ، اور ای میل پر ٹپس اور خبریں۔ ہر ایک بند رہتا ہے، جب تک آپ اسے آن نہ کریں، اور آپ انہیں کبھی بھی دوبارہ بند کر سکتے ہیں۔ اینالیٹکس آن ہو تب بھی ایپ کوئی نام، فون نمبر، شناختی کارڈ نمبر، آئی بین نمبر یا رقم نہیں بھیجتی، اور کبھی آپ کی اسکرین ریکارڈ نہیں کرتی۔ یہ آپ کے فون کی کچھ تکنیکی تفصیل ضرور بھیجتی ہے، جیسے فون کی کمپنی، ماڈل اور سسٹم کا ورژن، جن کی فہرست پرائیویسی کے صفحے پر ہے۔

Why: D-18 says the app sends nothing to PostHog or Intercom until the person opts in (PJ:143), and
the FAQ is one of the places that "change to match" (PJ:141-142). The technical details are those
PostHog's libraries add to every event, as the draft notice lists them after the owner's decision
on the wrapper ([A11](questions.md#analytics-and-consent)). Optional: the owner may prefer to leave
this to the privacy page.

## 6. FAQ: "Can someone else collect rent for me?"

`website/src/content/faq/en.yaml`:35-36.

Current:

> **Can someone else collect rent for me?** Yes. Invite a relative, caretaker or accountant with a
> role of their own: owner, manager, accountant or viewer. The owner can see how much cash each of
> them has collected, handed over and still holds.

Proposed:

> **Can someone else collect rent for me?** Yes. Invite a relative, caretaker or accountant with a
> role of their own: owner, manager, accountant or viewer. An owner can name one manager as the
> portfolio's caretaker, and everyone in the portfolio can see who it is. The owner can see how much
> cash each of them has collected, handed over and still holds, and the record shows who entered
> what.

Current Urdu, `website/src/content/faq/ur.yaml`:33-34:

> **کیا کوئی اور میری طرف سے کرایہ وصول کر سکتا ہے؟** جی ہاں۔ کسی رشتہ دار، نگران یا اکاؤنٹنٹ کو ان کے اپنے رول کے ساتھ دعوت بھیجیں: مالک، منیجر، اکاؤنٹنٹ، یا صرف دیکھنے والا۔ مالک دیکھ سکتا ہے کہ ان میں سے ہر ایک نے کتنی نقدی وصول کی، کتنی آگے دی، اور کتنی ابھی ان کے پاس ہے۔

Proposed Urdu:

> **کیا کوئی اور میری طرف سے کرایہ وصول کر سکتا ہے؟** جی ہاں۔ کسی رشتہ دار، نگران یا اکاؤنٹنٹ کو ان کے اپنے رول کے ساتھ دعوت بھیجیں: مالک، منیجر، اکاؤنٹنٹ، یا صرف دیکھنے والا۔ کوئی مالک کسی ایک منیجر کو پورٹ فولیو کا نگران چن سکتا ہے، اور پورٹ فولیو میں ہر کوئی دیکھ سکتا ہے کہ نگران کون ہے۔ مالک دیکھ سکتا ہے کہ ان میں سے ہر ایک نے کتنی نقدی وصول کی، کتنی آگے دی، اور کتنی ابھی ان کے پاس ہے۔ ریکارڈ میں یہ بھی نظر آتا ہے کہ کس نے کیا درج کیا۔

Why: decision 1 (PJ:102-103; `supabase/migrations/20261112092618_residence.sql`:25-31 in pull
request [#61](https://github.com/ar27111994/maalik-e-makaan/pull/61), not merged). It stays true
until then.

## 7. Calculators intro

`website/src/i18n/ui.ts`:257 (`tools.intro`).

Current:

> Each calculator shows how it reached its figure, step by step, and works inside your browser:
> nothing you type is sent anywhere. They accept English or Urdu digits.

Proposed: **no change**, on one remaining condition that engineering meets before website
counting ships:

1. Query strings are removed before a visit is counted, and no event carries an amount (RM:283-284,
   :300-301, :320). A browser test should prove it.

The second condition of the first draft is met. #62 (`fabc088`, release 1.1.1) gave the calculator
form `method="dialog"`, so with JavaScript off nothing is submitted
([`Calculator.astro`](../../website/src/components/tools/Calculator.astro):35-39), and a browser
test fails on any request after submitting with JavaScript off
([`calculators.spec.ts`](../../website/tests/e2e/calculators.spec.ts):109-131).

Urdu, `website/src/i18n/ui.ts`:385, **no change**, on the same condition:

> ہر کیلکولیٹر قدم بہ قدم دکھاتا ہے کہ رقم کیسے نکلی۔ یہ آپ کے براؤزر کے اندر ہی کام کرتا ہے: آپ جو لکھتے ہیں وہ کہیں نہیں جاتا۔ آپ اردو یا انگریزی، دونوں ہندسوں میں لکھ سکتے ہیں۔

## 8. Rent increase calculator

`website/src/content/tools/en/rent-increase-calculator.md`:3 (its meta description).

Current:

> … Free, and private to your browser.

Proposed: **no change**, on the same condition as item 7.

Urdu, `website/src/content/tools/ur/rent-increase-calculator.md`:3, **no change**, on the same
condition:

> … مفت، اور سب کچھ آپ کے براؤزر ہی میں۔

## 9. `website/README.md`, opening

`website/README.md`:4-7 (its link to `PROJECT.md` is shown as a plain path here). No Urdu twin, as
for items 10 to 13: these are developer documents in English.

Current:

> It exists for people and for search and AI tools (decision D-01 in `.planning/PROJECT.md`), so
> every page is plain, fast, accessible HTML with no tracking.

Proposed:

> It exists for people and for search and AI tools (decision D-01 in `.planning/PROJECT.md`), so
> every page is plain, fast, accessible HTML. It sets no cookies, and counts visits with
> PostHog's cookieless mode (see the Privacy section below).

## 10. `website/README.md`, "Privacy"

`website/README.md`:101-104.

Current:

> No cookies, analytics, trackers, third-party scripts or third-party requests. Fonts and images are
> served from the site. The e2e suite fails if a page makes a request that fails or logs an error.

Proposed:

> No cookies, no third-party scripts and no third-party requests from the browser. Fonts, images and
> scripts are served from the site.
>
> Visits are counted with PostHog (decision D-18), in cookieless mode, in Maalik-e-Makaan's own
> project in the US Cloud. The slim posthog-js is bundled into the site as a module, so
> `script-src 'self'` holds; its requests go to the site's own origin and Vercel rewrites pass them
> to PostHog, so `connect-src 'self'` holds. Query strings are removed before a page view is sent,
> so calculator inputs never leave, and no event carries an amount. Session recording, heatmaps,
> console-log and dead-click capture, autocapture, web-vitals capture and surveys are off in the
> project and in the configuration, which also loads no feature flags. The configuration sets
> `person_profiles: 'never'` and never calls `identify`, so PostHog keeps no profile of a visitor.
> The counter does not load when the visitor has switched it off on the privacy page (the only thing
> the site stores in the browser) or when the browser sends Do Not Track.
>
> The e2e suite fails if a page makes a request that fails or logs an error, on any CSP or Trusted
> Types violation, and if a page writes a cookie or any browser storage other than the visitor's
> choice. Any change to what is counted changes the privacy page, in English and Urdu, in the same
> pull request.

Why: RM:278-285, :315-317; the project's settings are PJ:154-157, and feature flags are a matter
for the SDK configuration, not a project setting (RM:284-285). `person_profiles: 'never'` is the
research's recommendation, which the notice's "PostHog keeps no profile of you" depends on (draft
notice, changes table, row 9). The two new test promises are work to do: no test checks cookies or
browser storage today (no `cookies()` or `localStorage` assertion in
[`website/tests/e2e/`](../../website/tests/e2e/)), and the CSP and Trusted Types test is planned
(RM:315). The README must not claim them before they exist.

## 11. `website/AGENTS.md`

`website/AGENTS.md`:3-4.

Current:

> The public site: static Astro, English at `/` and Urdu at `/ur/` (right to left, in Noto Sans
> Arabic), no tracking, deployed to Vercel by the Deploy workflow.

Proposed:

> The public site: static Astro, English at `/` and Urdu at `/ur/` (right to left, in Noto Sans
> Arabic), no cookies, visits counted with PostHog's cookieless mode, deployed to Vercel by the
> Deploy workflow.

And a new rule under "Rules here":

> - Analytics is PostHog in cookieless mode only (D-18), bundled and sent through the site's own
>   origin, with `person_profiles: 'never'` and no `identify` call. No event carries an amount, a
>   calculator input or a query string. Any change to what is counted changes the privacy page and
>   the FAQ, in English and Urdu, in the same pull request.

## 12. Root `README.md`

`README.md`:69 (the "Website" row of the table of parts).

Current:

> Astro static site in English and Urdu: guides, calculators, no tracking.

Proposed:

> Astro static site in English and Urdu: guides, calculators, no cookies, visits counted with
> PostHog's cookieless mode.

## 13. `docs/operations.md`, Resend's tracking

`docs/operations.md`:179-182.

Current:

> In the domain's Configuration, turn **off** click tracking and open tracking: click tracking
> rewrites the sign-in links through Resend's servers, and open tracking adds a tracking pixel; the
> privacy page says the app has no trackers.

Proposed:

> In the domain's Configuration, turn **off** click tracking and open tracking: click tracking
> rewrites the sign-in links through Resend's servers, and open tracking adds a tracking pixel; the
> privacy page says that we do not track whether people open the app's service e-mails or click
> their links.

Why: the draft notice no longer says "no trackers", but keeps the promise for service e-mail, opens
and clicks alike. The design turns off link tracking on Customer.io's transactional path
(RM:294-296); open tracking must be off there too, and the notice's sentence waits for the
owner's confirmation of that ([E6](questions.md#e-mail); the owner's checklist in the
[README](README.md#before-the-pack-goes-out)). The domain's own click and open tracking are off:
the owner reported on 12 November 2026 that they had switched them off some days before
(`docs/release-readiness.md`:338-341).

## 14. Licences page

`website/src/content/licences/en.yaml`:5.

Current:

> Maalik-e-Makaan is open source. These are the licences for everything this website sends to your
> browser.

Proposed: **no change to the sentence**, but once posthog-js is bundled the page, and
[`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md), list its licence, or the sentence stops
being true.

Urdu, `website/src/content/licences/ur.yaml`:6, **no change to the sentence**, on the same
condition, and the Urdu page lists the same licence:

> مالکِ مکان ایک اوپن سورس پروجیکٹ ہے۔ یہ ویب سائٹ آپ کے براؤزر کو جو کچھ بھیجتی ہے، اس سب کے لائسنس یہاں لکھے ہیں۔

## 15. Other pages that stay true

Checked, and no change is needed for decisions 1 to 3:

- [`home/en.yaml`](../../website/src/content/home/en.yaml):67-68, "Private from the start": records
  kept apart, CNICs masked, documents in private storage.
- [`how-it-works/en.yaml`](../../website/src/content/how-it-works/en.yaml):28 (CNICs masked until
  you show them) and :37-41 (inviting a caretaker; an overseas owner sees the cash). Once decision
  1 ships, :38 may add "An owner can name one manager as the caretaker."
- [`pricing/en.yaml`](../../website/src/content/pricing/en.yaml):13, "at least 60 days' notice by
  email and in the app": true, but the e-mail must be sent by some service, possibly before
  Customer.io is approved ([E1](questions.md#e-mail)).
- `pricing/en.yaml`:112 and :121: the store account's country, "not … where you live", sets the
  currency. This matches decision 1, under which the store country is never read as residence
  (RM:144-145).
- `pricing/en.yaml`:113, "You can always take your data out": today the exports are CSV files of
  the ledger, payments and expenses, and documents one at a time (data map, gap 9). Not changed by
  decisions 1 to 3, but the lawyer may read it as a promise of a full export
  ([N1](questions.md#rights-breach-and-changes-to-the-notice)).
- [`website/deck/slides/agentsafe.html`](../../website/deck/slides/agentsafe.html):35, "data stays
  in the region": about calls to AI models, which decisions 1 to 3 do not add.

The Urdu twins, checked the same way:

- [`home/ur.yaml`](../../website/src/content/home/ur.yaml):67-68, "شروع ہی سے پرائیویسی": no change.
- [`how-it-works/ur.yaml`](../../website/src/content/how-it-works/ur.yaml):25 (CNICs masked until
  you show them) and :34-38 (inviting a caretaker; an overseas owner sees the cash): no change.
  Once decision 1 ships and the English adds its sentence to `how-it-works/en.yaml`:38, the Urdu
  adds the same sentence to :35, the twin of that line: "کوئی مالک کسی ایک منیجر کو نگران چن سکتا
  ہے۔"
- [`pricing/ur.yaml`](../../website/src/content/pricing/ur.yaml):10, "کوئی بھی رقم لینے سے کم از کم
  60 دن پہلے ہم آپ کو ای میل پر اور ایپ میں بتائیں گے": true, with the same caveat on which service
  sends the e-mail ([E1](questions.md#e-mail)).
- `pricing/ur.yaml`:109 (the store account's country decides which plans show) and :118 (it
  decides the currency, "اس پر نہیں کہ آپ کہاں رہتے ہیں"). This matches decision 1.
- `pricing/ur.yaml`:110, "آپ اپنا ڈیٹا ہمیشہ نکال سکتے ہیں": the same reading as the English
  ([N1](questions.md#rights-breach-and-changes-to-the-notice)).
- The pitch deck slide is in English only.

## 16. Planning documents that describe today

These describe the present correctly and change when the features ship, in the same pull requests:
[`.planning/STATE.md`](../../.planning/STATE.md):91, [`pilot.md`](../roadmap/pilot.md):38-40,
RM:268-271 and [`.github/roadmap.toml`](../../.github/roadmap.toml):112. The Urdu glossary's
analytics entry ([`contracts/urdu_glossary.json`](../../contracts/urdu_glossary.json):928-934)
glosses the word negatively and tells writers to "keep the full promise: no cookies, no analytics,
no tracking"; it changes with the Urdu text.

The glossary governs the copy, so it changes in the same pull request as the Urdu privacy page and
FAQ (its own `$comment`: "change the copy it governs in the same change"). Proposed, not applied:

- **The analytics entry** (`urdu_glossary.json`:928-934), `prefer`: "اینالیٹکس, with a plain
  gloss once: 'یعنی یہ گنتی کہ ایپ کیسے استعمال ہوتی ہے' in the app, 'وزٹس کی گنتی' on the
  website". Its `note` keeps the found count and the old example, and replaces the last sentence
  with: "Keep the promise exactly as the privacy page makes it: no cookies; visits counted with
  PostHog, in the United States, 'آپ کی پہچان کے بغیر'; nothing sent from the app until the person
  switches it on. Counting is گنتی or گننا (see the 'counted; excluding' entry); where the
  feminine verb گنتی could be read as the noun, write 'گنتی کرتی ہے'." This file names glossary
  entries by their English, because `tool/check_urdu_words.py` refuses the avoided words outside
  the glossary itself.
- **New `keep` lines** for the words this pack brings in, so that the app, the website and the
  e-mails use one word each: وزٹ and 'وزٹس کی گنتی'; 'سپورٹ چیٹ'; 'ٹپس اور خبریں'; 'ٹائم زون';
  'لیٹر ہیڈ'; 'آپ کی رہائش کا ملک', never 'آپ کا ملک' alone for the declared country, which can be
  read as nationality.
- **The one-word-per-thing rule** (`sentenceRules`) adds: "A portfolio's caretaker: نگران (the
  role it holds stays منیجر)."
