# Owner actions

Up to date as of 23 November 2026.

Everything waiting on you, the owner: what only you can do, and the decisions only you can make.
Each item says what to do, when it is done and what to tell the agent. Never send a password, a key,
a one-time link or anyone's personal details. The agent updates this page in the same pull request
as any change that adds or closes an item; [release-readiness, Owner
actions](release-readiness.md#owner-actions) keeps the history.

## At a glance

- **This week, by 30 November:** [ask lawyers for a
  quote](#ask-lawyers-for-a-fixed-fee-quote-this-month); [chase the D-U-N-S
  number](#chase-the-d-u-n-s-number-now); [agree the glossary and shortlist
  editors](#agree-the-glossary-and-shortlist-editors-by-30-november); [start recruiting the
  pilot](#start-recruiting-the-pilot-from-late-november). Two take two minutes each: [read two times
  on the Secrets page](#read-two-times-on-the-secrets-page-two-minutes) and [delete a
  branch](#delete-the-branch-claudepublish-dry-run-two-minutes).
- **By 30 December:** [decide whether anyone pays before March
  2027](#decide-whether-anyone-pays-before-march-2027).
- **Before launch, 28 February 2027:** [the lawyer's
  review](#get-the-lawyers-review-back-and-settle-it), [Google Play](#publish-on-google-play),
  [Apple](#enrol-in-the-apple-developer-program), [the Urdu
  review](#review-the-urdu-and-hire-an-editor).
- **Decisions, soonest first:** [residence Q1 to Q7](#residence-questions-q1-to-q7) (the screens are
  being built now); [the audit screen](#the-audit-screens-four-questions) (built from December);
  [Supabase Pro](#supabase-pro-or-stay-free); [GitHub settings](#github-protection-settings);
  [smaller choices](#smaller-choices); [P-01 and P-02](#proposals-p-01-and-p-02); [later
  ones](#later-decisions-not-due-yet).
- **Checks by hand, any time:** [the e-mails in Gmail](#check-the-apps-e-mails-in-gmail), [the old
  address](#check-the-old-web-app-address), [your phones](#check-the-links-on-your-phones), [a 1.4.3
  download](#check-a-143-download); [Checkly](#check-the-monitors-when-checklys-trial-ends) when its
  trial ends.
- **Also:** [optional](#optional), [not sure if done](#not-sure-if-done), [standing
  rules](#standing-rules), [recently done](#recently-done).

## This week (by 30 November 2026)

### Ask lawyers for a fixed-fee quote (this month)

**Why:** the privacy notice and the terms need a Pakistani lawyer's review before launch, before the
store forms are filled in and before any analytics run. The agent also could not reach the official
`.gov.pk` texts behind the website's guides ([details](roadmap/legal-review.md#design)).

1. Set the budget, and a deadline at least six weeks before the first store submission.
2. Ask two or three firms for a fixed fee: advocates of the High Court with data (PECA) and rent
   cases in Punjab or Sindh, able to review Urdu, agreeing that review materials hold no real
   personal data. The plan's deliverables include checking the guides against the official texts.
3. Choose a firm. Before the pack goes to it, settle with the agent the facts under "Before the pack
   goes out" in the pack's
   [README](https://github.com/ar27111994/maalik-e-makaan/blob/claude/legal-pack/docs/legal/README.md#before-the-pack-goes-out),
   on [pull request #66](https://github.com/ar27111994/maalik-e-makaan/pull/66), not merged yet.
   There are about fifteen, among them PostHog's retention period and signing its data processing
   agreement, Intercom's region, Customer.io's tracking and agreement, Vercel's and GitHub's
   agreements, where the weekly backup is kept and who reads the contact mailbox.
4. Answer the plan's questions:
   - Will AR LABS accept the processor role for tenant data, and say so?
   - Which city's courts for disputes?
   - Will tenants ever have accounts of their own?
   - Will any analytics run at launch?
   - Should a Pakistani hosting option be planned now?

**Done when:** a firm is engaged with a fee and a deadline. **Then tell the agent:** the firm, the
fee, the deadline and your answers. The review itself is a launch item of its own: [get the
lawyer's review back](#get-the-lawyers-review-back-and-settle-it).

### Chase the D-U-N-S number (now)

**Why:** Google Play, Apple and paid plans all wait on it, and Dun & Bradstreet quotes up to 30
business days. The pilot's closed Play track waits on it too; until then the pilot uses the APK and
the web app ([details](roadmap/play-store.md#questions-for-the-owner)).

1. Ask [Dun & Bradstreet](https://www.dnb.com/en-us/smb/duns/get-a-duns.html) where the request
   stands.
2. Check that the record's name and address match the SECP certificate character for character.
3. Set the website on the record, and on the company's LinkedIn page, to <https://mmakaan.app>:
   Apple wants the organisation's website on the domain of its work e-mail, `hello@mmakaan.app`.
   This does not change the company's own website link on the site, which stays
   `https://ar27111994.dev/` (your decision of 15 November).

**Done when:** the number has arrived and the record matches. **Then tell the agent:** the number (a
public identifier) and its date. Then come [Google Play](#publish-on-google-play) and
[Apple](#enrol-in-the-apple-developer-program).

### Agree the glossary and shortlist editors (by 30 November)

**Why:** the pilot's first round, in December, should read settled Urdu, and no native speaker has
reviewed the app's Urdu yet. The full review comes [before
launch](#review-the-urdu-and-hire-an-editor)
([details](roadmap/urdu-review.md#questions-for-the-owner)).

1. Ask the agent for the glossary as a sheet you can read on a phone (each word in English, the Urdu
   chosen, and why), and answer:
   - Western digits (123) or Urdu digits (۱۲۳) for amounts, dates and phone numbers, receipts
     included?
   - Which loanwords to accept beyond the glossary's (for example بیلنس)?
   - Keep پورٹ فولیو, explained once where a portfolio is created, or rename it?
   - Nastaliq anywhere beyond the wordmark, such as large headings or letterheads?
2. Shortlist three Urdu editors for a paid test.

**Done when:** you have answered and three editors are shortlisted. **Then tell the agent:** your
answers, and that the shortlist is ready (no names needed).

### Start recruiting the pilot (from late November)

**Why:** no landlord has run a month's rent through the app yet; starting now covers the December,
January and February rent days ([details](roadmap/pilot.md#questions-for-the-owner)).

1. Answer: how many (proposed: 15 to 25 landlords, a third abroad); where; what incentives; who runs
   the Urdu sessions, you or a hired researcher; real data (once the privacy notice covers tenants)
   or a pilot environment; and the target, such as 60% recording rent in both months.
2. Recruit through your network, overseas Pakistani groups and referrals, never estate agents: about
   10 resident landlords, 8 owners abroad with their caretakers, and 5 tenants.

**Done when:** 15 landlords are in, 5 of them abroad. **Then tell the agent:** your answers and how
many joined of each kind (never names or phone numbers).

### Read two times on the Secrets page (two minutes)

**Why:** the Edge Functions got a new version, 21, on 22 November between 13:09 and 13:14 Pakistan
time (08:09 to 08:14 UTC), and no deploy made it. Your change of `ALLOWED_ORIGINS` most likely did;
its time settles that ([details](../.planning/STATE.md#current-position-2026-11-23), release 1.4.3).

1. In the Supabase dashboard, open the project, then Edge Functions, then Secrets.
2. Read when `ALLOWED_ORIGINS` and `APP_URL` were last updated. If it shows only "2 hours ago" or
   the like, hover over it for the exact time; otherwise note what it shows. Never copy a secret's
   value.
3. If `ALLOWED_ORIGINS` was not updated in that window, version 21 is unexplained: check the
   organisation's members and the account's access tokens, and revoke any you do not know.

**Done when:** you have both times. **Then tell the agent:** both times, as shown. For `APP_URL`, 13
November between 22:39 and 22:49 Pakistan time would also explain two earlier versions, 10 and 11.

### Delete the branch `claude/publish-dry-run` (two minutes)

**Why:** a push to it would run a test workflow that makes real attestations, and the agent's own
delete was refused ([details](../.planning/STATE.md#current-position-2026-11-23), "The dry run").

1. On <https://github.com/ar27111994/maalik-e-makaan/branches>, click the branch's bin icon, or run
   `git push origin --delete claude/publish-dry-run` from a clone signed in as you.

**Done when:** the branch is gone from that page. **Then tell the agent:** "deleted".

## By 30 December 2026

### Decide whether anyone pays before March 2027

**Why:** early-access landlords were promised 60 days' notice, so a charge in February needs the
notice out by 30 December. Billing's database work starts in December either way
([details](roadmap/billing.md#questions-for-the-owner)).

1. Choose: charge before 28 February 2027, or not ("no charge before March 2027" settles it).
2. If yes, you first need the tax registrations (NTN, services tax, PSEB), a written tax opinion on
   "prices include tax", and a payment provider (PayFast or Safepay) with a written rate card that
   says whether tax is included.
3. Either way, before billing's database work: does a plan belong to the portfolio (recommended) or
   to the account? Are the 5 free units counted per portfolio (built so until you answer) or across
   all of an owner's portfolios (the plan's own proposal, so that splitting a building into
   portfolios does not multiply them)?
4. Before any paid plan in the stores (from March 2027, or earlier if charging): a Play payments
   profile, Apple's Small Business Program, and a rupee (PKR) settlement account.

**Done when:** you have chosen and answered step 3, and, if charging, the notice is sent by 30
December. **Then tell the agent:** your choice and answers.

## Before launch (due 28 February 2027)

### Publish on Google Play

**Why:** a Play listing gives Android landlords normal installs and updates. It starts once the
[D-U-N-S number](#chase-the-d-u-n-s-number-now) arrives
([details](roadmap/play-store.md#questions-for-the-owner)).

1. Open a Play Console organisation account for AR LABS (US$25), with the name and address of the
   D-U-N-S record, and choose the public developer name.
2. Before the first upload, choose:
   - keep the application ID, or move to an AR LABS one (it can never change afterwards);
   - upload the existing release key as Play's signing key (proposed, so phones with the APK update
     in place), or let Google make one;
   - the countries, and the Business category, declaring "no financial features" (both proposed);
   - whether the APK stays on GitHub; if it does, register it for Android's developer verification,
     which apps installed outside Play need in four countries since 30 September 2026 and worldwide
     from 2027.
3. Fill in Data safety, content rating, audience, ads and app access (the agent drafts them), then
   upload the release's `.aab`: the internal track, a closed track for the pilot, then production in
   stages.
4. Copy the SHA-256 from Test and release, App integrity, App signing key certificate, and upload
   `app/android/store/play-icon-512.png` in Grow users, Store presence, Main store listing, App
   icon.

**Done when:** the app is live on Play under AR LABS. **Then tell the agent:** your choices, the
SHA-256 (it is public) and the listing's address.

### Enrol in the Apple Developer Program

**Why:** without it the iPhone app stays unsigned, and owners abroad, many on iPhones, have only the
web app ([details](roadmap/app-store.md#questions-for-the-owner)).

1. Choose the Account Holder: someone who can bind the company, with an Apple Account in their legal
   name and two-factor authentication.
2. With the D-U-N-S number, enrol AR LABS as an organisation at
   <https://developer.apple.com/programs/enroll/> (US$99 a year).
3. Choose: iPhone only at launch (proposed) or iPad too; the storefronts (the EU only with AR LABS's
   trader details published); and whether a demo account for Apple's reviewers may live in
   production, and who resets it.
4. Later, when the agent says a build is ready: add the pilot's iPhone users to TestFlight, internal
   testers first, then submit the app to App Review.

**Done when:** the membership is active (steps 1 to 3); step 4 follows. **Then tell the agent:**
that, the Team ID and your choices.

### Get the lawyer's review back and settle it

**Why:** launch needs the lawyer's written review, not only a firm engaged, and the privacy notice,
the terms and the store forms follow from it ([details](roadmap/legal-review.md#done-when)).

1. Once the firm has the pack ([ask lawyers for a
   quote](#ask-lawyers-for-a-fixed-fee-quote-this-month)), get its review back as a signed memo or
   letter, dated after November 2026.
2. Go through it with the agent: each question for the lawyer answered or explicitly deferred, and
   each change to the privacy notice, the terms or the guides agreed.
3. Approve the changed texts in English and Urdu before the agent publishes them, and before the
   store forms are filled in.

**Done when:** the memo is in hand and every question in it is answered or deferred. **Then tell
the agent:** that it arrived, and send the memo (it holds no personal data); the agent records what
it decides and turns its changes into a pull request.

### Review the Urdu and hire an editor

**Why:** every screen, receipt and e-mail is in Urdu, and no native speaker has reviewed it
([details](roadmap/urdu-review.md#questions-for-the-owner)).

1. Ask the agent for the review sheet: each screen's English and Urdu side by side, with
   screenshots, then the website's pages, the e-mails and the list of amount words, starting with
   the part it marks to check first.
2. Read it and send corrections. On the amount words: do "million" and "m" stay accepted (they are
   until you answer), and should Punjabi or Saraiki number words be added later, or left to
   tap-to-confirm?
3. Give the three shortlisted editors a paid 300-word test (a screen, a receipt, an error message),
   judged for plainness and respect, and engage one.
4. Answer: one editor for everything, or a second for the legal texts? Will you review after the
   editor, or accept the editor's text with spot checks?

**Done when:** the review is done, the amount words reviewed and an editor engaged. **Then tell the
agent:** corrections (where, current text, new text), your answers, and that the editor is engaged.

## Decisions only you can make

Tell the agent your choice; "as proposed" is enough where there is a proposal.

### Residence questions Q1 to Q7

**Why:** the residence screens are being built now, each as proposed until you say otherwise, so
answer before they ship
([details](roadmap/README.md#decision-1-residence-per-person-and-per-portfolio-d-16)).

1. Q1: a person's country and time zone are seen only by them. Confirm.
2. Q2: may an owner living in Pakistan have a caretaker? Proposed: yes.
3. Q3: tell owners when a manager answers the owner-abroad question? Proposed: yes.
4. Q4: may a caretaker see the owner's local time? Proposed: not at launch.
5. Q5: Kosovo (XK, not an official ISO code) is refused. Right?
6. Q6: the Pakistan side of the dual time: "in Lahore", "Pakistan time" or the property's city?
7. Q7: may a caretaker step down without leaving? Proposed: no.

### The audit screen's four questions

**Why:** the screen that shows who changed what is built from December 2026, and these shape it. The
plan proposes no answer ([details](roadmap/audit-screen.md#questions-for-the-owner)).

1. Should managers (caretakers) see the full trail, including the owner's own actions?
2. Should the money part of the trail outlive a portfolio's deletion, for the six years the Income
   Tax Ordinance asks, or be exported and then deleted?
3. Should the four tables not yet recorded (meter readings, reminder logs, invitations and payment
   allocations) be recorded too?
4. Is pgaudit, a log of administrators' own access, wanted on the hosted project beyond this trail?

### Supabase Pro, or stay free

**Why:** two security settings need Supabase's Pro plan, about US$25 a month for the organisation:
leaked-password protection, which the security advisor flags as off, and a session time limit,
without which a sign-in kept in a phone backup outlives a sign-out that could not reach the server.
Pro also stops the project pausing after a week without activity. Supabase's [password
security](https://supabase.com/docs/guides/auth/password-security),
[sessions](https://supabase.com/docs/guides/auth/sessions) and [billing
FAQ](https://supabase.com/docs/guides/platform/billing-faq) pages say so
([details](../.planning/STATE.md#open), first entry).

1. Choose Pro, or stay free and accept both (or have the app retry such a sign-out later).
2. With Pro: Authentication, Sign In / Providers, Email: turn on leaked-password protection; agree a
   time limit with the agent, then set it in Authentication, Sessions.

### GitHub protection settings

**Why:** each tightens the rules on `main` or on production, and each has a cost. OpenSSF Scorecard,
the public security score, counts the last three
([details](operations.md#code-scanning-and-branch-rules)).

1. **A reviewer for production deploys** (Settings, Environments, `production`). It was planned at
   the start (release-readiness, item 7) but is not set: release 1.3.0's deploys waited for no one.
   With it, every release, and the website's weekly refresh, waits for your click. Proposed: not
   now, as your standing word is to release without being asked; again once a second person can
   review.
2. **The admin bypass on `main`** (Settings, Rules, Rulesets, "Default"). It lets an admin past
   every rule, and it is the only way past a required check that breaks for every pull request at
   once. Proposed: change it from "Always" to "For pull requests only", so it stays a way out for a
   pull request but no one can push to `main` directly. Removing it altogether raises the score.
3. **"Require branches to be up to date before merging"**, in the same ruleset. Each pull request
   would need `main` merged into it, and CI run again, whenever another was merged first. Proposed:
   leave it off while several pull requests are open at once.
4. Optional: a second person who can review, so the ruleset can require two approvals.

### Smaller choices

**Why:** each is rare or small and written down, but only you can weigh it.

1. **Deleting an account at the same moment as a portfolio.** Very rarely, deleting an account just
   as someone deletes a portfolio the person created or worked in makes one of the two fail once:
   the person sees an error and tries again, or the portfolio's deletion retries by itself, and the
   retries resolve it. Fixing it properly is a larger change (it writes to 20 tables and locks more
   portfolios). Proposed: keep the retries ([details](operations.md#deleting-a-user-account),
   finding M2).
2. **The order of long lists.** Maintenance requests and expenses are listed in the order they were
   entered, so an urgent repair reported late is not at the top. Keep it, order each list its own
   way, or load the short list of open requests whole, up to a limit?
   ([details](architecture/app.md#open-questions))
3. **Three rare sign-out cases**, found in testing on 22 November (STATE.md, Follow-ups, Open). For
   each: have the agent fix it, or accept it.
   - If you confirm your password to delete your account just as another tab signs you out, you end
     up signed in again, and no deletion is sent. The fix: sign out again afterwards.
   - If a sign-out fails on the phone itself (its storage cannot remove one saved item), the sign-in
     stays saved, and the next start signs you back in. The fix: remove the saved sign-in anyway.
   - If the phone's storage stalls during a sign-out and the same account signs in again, deleting
     it then can end looking like an ordinary sign-out: the sign-in screen does not say the account
     was deleted. Should the privacy page say so?
4. **The old address's sign-in links.** Copies of the app made before the move (15 November 2026)
   send sign-in links through the old address, so Supabase Auth still accepts its two return
   addresses and the Android app still opens its links. From which date, or which oldest app
   version, may they stop working? Proposed: now, unless someone you know still uses a copy from
   before 15 November (you said on 14 November that nobody used the app yet). The agent then removes
   them from the app and tells you which two addresses to delete in Auth
   ([details](operations.md#moving-the-addresses-the-order-2026-11), after step 13).

### Proposals P-01 and P-02

**Why:** each reverses an earlier decision, so none of that work (2027 and 2028) starts until you
accept it ([details](../.planning/PROJECT.md#open-proposals)).

1. P-01: automatic WhatsApp reminders through Meta, to tenants who opted in, at a cost per message.
2. P-02: rent collected through a licensed payment partner, straight to the landlord, and later
   incoming payments read from the landlord's bank with consent.

### Later decisions (not due yet)

**Why:** they hold up later work only, and the agent brings each to you before its work starts
([details](roadmap/README.md#decisions-the-owner-still-has-to-make), and each plan's last section).

- From December 2026, before the text path of draft payments: keep drafts on the server, or only on
  the phone until confirmed? Allow a draft without a transfer reference, with a duplicate warning?
  ([draft-payments](roadmap/draft-payments.md#questions-for-the-owner))
- After the agent's trial of the read-only MCP server: turn on asymmetric JWT signing keys and the
  OAuth server on the hosted project ([mcp-read](roadmap/mcp-read.md#work), item 2).
- Before support chat and lifecycle e-mail: the Intercom workspace (region, languages, a Help Center
  in English and Urdu) and Customer.io's sending subdomains ([decision
  3](roadmap/README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18)). PostHog's data
  processing agreement is due earlier, with the [lawyer's
  pack](#ask-lawyers-for-a-fixed-fee-quote-this-month), before any analytics ship.
- Letterheads and onboarding (co-owners, residence and price); how long identity documents are kept,
  with the lawyer; Meta's verification, Firebase and Apple's push key; the AI and speech-to-text
  providers; and the 2027 and 2028 plans (WhatsApp, mandates, tenants, oversight, hostels, Raast
  partners, open banking after the reply).
- Before the store artwork, with the launch milestone: screenshots plain or framed with captions,
  and which screens come first (the overdue list, a receipt, the caretaker handover)
  ([app-icon](roadmap/app-icon.md#questions-for-the-owner)).

## Checks by hand

### Check the app's e-mails in Gmail

**Why:** every new user depends on them. No e-mail has yet shown DMARC "PASS", and the agent has not
seen the reset or the invitation ([details](operations.md#e-mail), step 8).

1. On <https://app.mmakaan.app>, with Gmail addresses of your own: sign up in English and again in
   Urdu, reset a password, change an address, and invite your second address (in a portfolio: Team,
   Invite someone). Each link should open the app there.
2. In Gmail, each message's three-dot menu, "Show original": SPF, DKIM and DMARC must say "PASS".
3. On an iPhone or a Mac, look at the Urdu half of the sign-up, reset and change-of-address e-mails.
   It should use plain letters (not the joined calligraphic Nastaliq), look as large as the English,
   and have its link aligned left; Nastaliq should appear only in the header's مالکِ مکان.
4. In Supabase, Authentication, Rate Limits, "Email sent" should read about 30 an hour; leave it so.

**Done when:** every e-mail passes and looks right. **Then tell the agent:** a screenshot of each
"Show original" summary, with the To address cropped or blurred; the rate limit; and whether the
links and the Urdu were right. Do not forward the messages: their links are one-time links.

### Check the old web app address

**Why:** people who used it must reach the new address, and what the app kept in the browser there
(sessions, lists with CNICs) must be cleared
([details](operations.md#moving-the-addresses-the-order-2026-11), steps 9 and 12).

Use Chrome or Edge on a computer.

1. Open <https://maalik-e-makaan.vercel.app/invite#token=x>: you should land on
   `https://app.mmakaan.app/invite#token=x`, with `#token=x` kept.
2. Only if a browser that was signed in there before the move is left: open
   <https://maalik-e-makaan.vercel.app> in it. You should land on the new address signed out. Press
   F12, open the Application tab, then Local storage, then `https://maalik-e-makaan.vercel.app`: it
   should be empty.
3. Open <https://maalik-e-makaan.vercel.app/.well-known/assetlinks.json>. Press F12, open
   Application, Local storage, `https://maalik-e-makaan.vercel.app`, double-click the empty row,
   type `flutter.x` as the key and `1` as the value, and press Enter. Then open the Network tab and
   tick "Preserve log".
4. In the same tab, open <https://maalik-e-makaan.vercel.app/auth/callback?code=x>. The Network tab
   should show the browser go on to `https://app.mmakaan.app/auth/callback?code=x`. The page then
   says "This link did not work", or goes straight to the language choice: both are right.
5. Open the old `assetlinks.json` again: in Local storage, `flutter.x` should be gone.

**Done when:** the `#token` was kept, `flutter.x` is gone, and the old storage was empty (if such a
browser was left). **Then tell the agent:** where each step landed, with screenshots of the Network
tab and Local storage.

### Check the links on your phones

**Why:** e-mail and invitation links should open the app, not the browser, and no phone has been
checked since the move ([details](operations.md#android-app-links)).

1. On an Android 12 or later phone, install `maalik-e-makaan-v1.4.3-arm64-v8a.apk` from the
   [releases page](https://github.com/ar27111994/maalik-e-makaan/releases). On the sign-in screen,
   tap "Forgot password?", send the link to your Gmail, then tap the link in Gmail on the phone: the
   app, not the browser, should open.
2. Optional, a deeper check. Install Google's Android SDK Platform-Tools on a computer. On the
   phone, open Settings, About phone, and tap Build number seven times (on some phones it is under
   Software information); then turn on Developer options, USB debugging. Connect the phone by USB
   and run these. The second must show `app.mmakaan.app` and `maalik-e-makaan.vercel.app` as
   `verified`, and the third must open the app:

   ```bash
   adb shell pm verify-app-links --re-verify io.github.ar27111994.maalik_e_makaan
   adb shell pm get-app-links io.github.ar27111994.maalik_e_makaan
   adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d 'https://app.mmakaan.app/auth/callback?code=test'
   ```

3. On an iPhone, install `maalik-e-makaan-v1.4.3-ios-unsigned.ipa` with Sideloadly, or build the app
   from `app/ios/Runner.xcworkspace` in Xcode on a Mac ([how](operations.md#ios-builds)). Sign up
   and reset a password in it: iOS should offer to open each e-mail link in Maalik-e-Makaan.
4. While the app is open on each phone: do screens slide in when they open, and on the iPhone does a
   swipe from the left edge go back? On the Android phone, after closing the app from the recent
   apps list, about how many seconds does it take to open, and which model is the phone?

**Done when:** the links open the app on both phones. **Then tell the agent:** pass or fail for each
phone, the second command's output if you ran it, and what you saw in step 4.

### Check a 1.4.3 download

**Why:** 1.4.3 is the first release the new publish jobs made, and the agent cannot reach Sigstore
to run the full check ([details](../SECURITY.md#checking-a-download)).

1. Install GitHub's `gh`, version 2.102.0 or later (on Windows, `winget install GitHub.cli`).
2. From the [v1.4.3 release](https://github.com/ar27111994/maalik-e-makaan/releases/tag/v1.4.3),
   download `maalik-e-makaan-v1.4.3-arm64-v8a.apk` and `maalik-e-makaan-v1.4.3.intoto.jsonl`, and
   run this one line in that folder (PowerShell too):

   ```bash
   gh attestation verify maalik-e-makaan-v1.4.3-arm64-v8a.apk --bundle maalik-e-makaan-v1.4.3.intoto.jsonl --repo ar27111994/maalik-e-makaan --signer-workflow ar27111994/maalik-e-makaan/.github/workflows/release.yml --source-ref refs/heads/main --source-digest 5b3d24fd11326c2c87395248ab2835622723f77e --deny-self-hosted-runners
   ```

**Done when:** it ends without an error. **Then tell the agent:** your `gh` version and the output.

### Check the monitors when Checkly's trial ends

**Why:** the three Checkly monitors are the only outside alerts, and the end of the trial could stop
them. The agent's connector reads the plan as "Trial" (22 November 2026) but shows no end date
([details](operations.md#monitoring-and-alerts)).

1. Find when the trial ends in Checkly's account settings, and tell the agent; it will read the
   monitors that week.
2. After that date, check that "Maalik-e-Makaan", "Maalik-e-Makaan web app" and "Maalik-e-Makaan
   website" still run and pass, or ask the agent to.

**Done when:** all three still run after the trial. **Then tell the agent:** the end date, and
afterwards the plan's new name.

## Optional

Nothing in the project waits on these.

- **Send the AWS Activate reply.** The provider's three requests are met. The reply was drafted on
  15 November 2026, in that day's conversation, with the deck from <https://mmakaan.app/company/>;
  ask the agent for a fresh draft if you cannot find it. Send it from a separate mailbox made for
  the application, not by sharing the company mailbox's login (the agent's advice). Tell the agent
  the date, and any answer, without staff names.
- **Check v1.4.0 to v1.4.2 as well**, after 1.4.3:
  [SECURITY.md's](../SECURITY.md#checking-a-download) command, with each release's own tag commit
  for `--source-digest`.
- **Attach provenance files to v1.0.0 to v1.3.1**, for offline checks: the block in [operations,
  Release provenance](operations.md#release-provenance) (Past releases), once per tag, in bash or
  zsh (on Windows, Git Bash or WSL). The runbook asks only that v1.4.0's own files check out first;
  waiting for the 1.4.3 check is stricter.
- **Move the Android signing secrets into the `release` environment**, so that a run on another
  branch cannot read them. You need their values again (from where you keep them), as GitHub never
  shows a secret. In Settings, Environments, `release`, add `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` with the same values;
  delete the repository's copies (Settings, Secrets and variables, Actions); then, in the same
  environment, set Deployment branches and tags to "Selected branches and tags" with the branch
  `main` alone, never a tag rule such as `v*` ([details](release-readiness.md#owner-actions),
  "Optional hardening").
- **Tidy GitHub's branches.** 37 of its 39 branches are the agent's (`claude/…`), most of them
  merged, and the agent's deletes are refused. Turn on Settings, General, "Automatically delete head
  branches", and delete the merged ones, never one with an open pull request such as #66's (the
  agent can list them).
- **Bing Webmaster Tools:** import the Search Console properties, then use Bing's site move from
  `https://maalik-e-makaan-site.vercel.app/` to `https://mmakaan.app/`.
- **Set the sub-agent model on the cloud environment** (not set on 22 November 2026). In the cloud
  environment's settings, Edit, Environment variables, add
  `CLAUDE_CODE_SUBAGENT_MODEL=claude-opus-5-5` and `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`; new
  sessions pick them up ([details](../.planning/STATE.md#environment-notes-for-future-sessions)).
- **Renew Qodo, or let it go:** its subscription lapsed and its bot has paused reviews.

## Not sure if done

Nothing records these. Either way, tell the agent the answer ("already done", with the date, or the
result), so it can be recorded.

- **Have you opened a downloaded backup with your key?** Until someone has, no one knows the key
  opens them. If not: download the latest `database-backup-<time>` (Actions, Backup, a run,
  Artifacts) and follow [operations, Backups](operations.md#backups), "Opening a backup", on a
  trusted computer. Tell the agent "opened" or the error, never the key or the file.
- **Is the daily check saved in your SQL editor?** If not, save the query in [operations, Monitoring
  and alerts](operations.md#monitoring-and-alerts). The agent also runs it through the Supabase
  connector (no rows on 22 November 2026).

## Standing rules

Keep to these when you change something yourself, and tell the agent about any change to a secret, a
DNS record, a Vercel project or an Auth setting.

- One DMARC record only (Dynadot's own); Resend's receiving and tracking stay off; the company
  mailbox is not forwarded to Resend's inbox unless the privacy page says so first
  ([E-mail](operations.md#e-mail)).
- Resend's free plan sends 100 e-mails a day for Auth and invitations together; past that,
  confirmations and resets stop until the next day. Move to its paid plan before sign-ups come near
  it ([E-mail](operations.md#e-mail), step 4).
- The health token never goes in a URL or a monitor's name
  ([Monitoring](operations.md#monitoring-and-alerts)).
- Vercel is never rolled back to a deployment from before release 1.3.0 (15 November 2026)
  ([Rollback and restore](operations.md#rollback-and-restore)).
- No "Re-run all jobs" on a Release run; a changed e-mail template is pasted into Auth when the
  agent asks; `RELEASE_PLEASE_TOKEN` is replaced before it expires
  ([Releasing](operations.md#releasing)).
- If GitHub turns off the scheduled Backup, turn it on again (Actions, Backup, Enable workflow).
- Supabase: its Usage page weekly; restores into a new project only; a user is deleted with
  `admin_delete_account_data` first, then in Authentication, Users ([Deleting a user
  account](operations.md#deleting-a-user-account)).

## Recently done

- 23 November 2026: the reply to the State Bank's draft open-banking rules sent by e-mail, the PDF
  signed by you as chief executive and sole director ([what it
  asked](roadmap/open-banking.md#what-is-true-now)); the app icon's mark chosen, twin gables, which
  the agent is now building into every icon ([details](roadmap/app-icon.md)).
- 22 November 2026: `ALLOWED_ORIGINS` narrowed to the new web app address (move, step 12), and the
  functions refuse the old one (your check that day answered 403). That change most likely made the
  Edge Functions' version 21 that morning, which [the Secrets
  page](#read-two-times-on-the-secrets-page-two-minutes) will settle. `tool/db/time_zone_skew.sql`
  run (the agent's own run found nine rows, none for `Asia/Karachi`). Decisions D-22 to D-24,
  released in 1.4.3.
- 15 November 2026: Auth's Site URL moved and the `APP_URL` variable deleted (step 8); Search
  Console verified, sitemap read and change of address started (steps 1 and 11); Resend moved to
  `mmakaan.app` with tracking off, sending from `hello@mmakaan.app`, and the second DMARC record
  removed (step 13); the repository's homepage set; D-21; and your standing word on releases.
