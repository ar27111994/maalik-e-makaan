# Publish the iPhone app on the App Store

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `app-store` in
[`.github/roadmap.toml`](../../.github/roadmap.toml).

## Why it matters

An iPhone owner cannot use the app today except in the browser: the release's iPhone build is
unsigned, and installing it means signing it with one's own Apple Account every seven days. The
project's earlier research found that iOS matters mainly to owners abroad, so they are the group
this hurts most. An App Store listing, with TestFlight before it, gives them a normal install,
updates, and e-mail links that open the app.

## What is true now

Facts marked _(summary)_ were read only through a search engine's summary; confirm them before
relying on them.

- **Enrolment as an organisation**
  ([Apple Developer, Enroll](https://developer.apple.com/programs/enroll/), read 11 November 2026):
  - the organisation must be a legal entity with a D-U-N-S number, and its legal name is shown as
    the seller;
  - the person enrolling must have legal authority to bind it, and an Apple Account with two-factor
    authentication in their legal name;
  - the organisation's website "must be publicly available and functional, and its domain name must
    be associated with your organization", and the work e-mail must be on that domain;
  - the fee is US$99 a year.
- **The domain is the likeliest blocker after the D-U-N-S.** The website and the web app are on
  `vercel.app` subdomains ([urls.ts](../../website/src/config/urls.ts)). The company link in
  [site.ts](../../website/src/config/site.ts) points to a personal site, and the product mailbox is
  on a sending subdomain of that personal domain, verified with Resend on 9 November 2026
  ([STATE.md](../../.planning/STATE.md)). AR LABS has no domain of its own.
- **Build rules**
  ([Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)): since 28
  April 2026 builds need Xcode 26 and the iOS 26 SDK; privacy manifests are enforced for "required
  reason" APIs, including inside SDKs; EU storefronts need trader status under the Digital Services
  Act.
- **The review guidelines most likely to bite**
  ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)):
  - 2.1: a demo account, with the backend on;
  - 5.1.1(i) and (v): a privacy-policy link in the metadata and in the app, and account deletion in
    the app;
  - 5.1.2(i): disclose sharing with third parties "including with third-party AI" and obtain
    explicit permission first;
  - 3.1.1: in-app purchase for subscriptions.
- Guideline 4.8 does not apply: the app signs in with e-mail and password only
  ([auth_repository.dart](../../app/lib/src/auth/auth_repository.dart)).
- **TestFlight** allows up to 10,000 external testers once the first build passes Beta App Review
  ([TestFlight](https://developer.apple.com/testflight/)).
- **Urdu metadata** has been possible since 31 March 2026
  ([9to5Mac](https://9to5mac.com/2026/03/31/app-store-connect-adds-11-new-languages-for-localized-app-metadata/)).
  One walkthrough says the locale code is `ur-PK`; this is unverified.
- **Repository:**
  - deployment target iOS 15.0, iPhone and iPad both enabled (`TARGETED_DEVICE_FAMILY = "1,2"`,
    [project.pbxproj](../../app/ios/Runner.xcodeproj/project.pbxproj));
  - no `PrivacyInfo.xcprivacy` and no entitlements file in [Runner](../../app/ios/Runner/);
  - CI and each release build the app with `--no-codesign` and attach an unsigned `.ipa`
    ([release.yml](../../.github/workflows/release.yml));
  - e-mail links come back through the app's own URL scheme, because there is no associated domain
    ([operations.md](../../docs/operations.md), "iOS e-mail links"); that redirect URL is still to
    be added to Auth ([release-readiness.md](../../docs/release-readiness.md)).
- The project's earlier research concluded that "iOS matters mainly for overseas owners"
  ([market-painpoints.md](../../.planning/research/market-painpoints.md)).

## Design

- **Domain and work e-mail first.** Register a domain for AR LABS, or one for the product that AR
  LABS owns, with work e-mail on it. Move the website and the web app to it, with permanent
  redirects from the `vercel.app` addresses. The same domain later carries the e-mail sending
  subdomains and Meta's business verification.
- **Enrolment.** Enrol AR LABS as an organisation once the D-U-N-S number and the domain exist. The
  Account Holder is a person with authority to bind the company.
- **Signing in CI.** A macOS job in `release.yml` on Xcode 26 that signs with an App Store Connect
  API key held in the `release` environment, and uploads to TestFlight. The unsigned `.ipa` stops
  being attached once the App Store build exists.
- **Universal links.** `Runner.entitlements` with `applinks:` for the new domain.
  `apple-app-site-association` is served as JSON, with no redirect, from `app/web/.well-known/`
  through [package_vercel.py](../../tool/web/package_vercel.py), which already serves
  `assetlinks.json`. The custom URL scheme stays as a fallback.
- **Privacy manifest.** An app-level `PrivacyInfo.xcprivacy` declaring the required-reason APIs the
  app uses, such as `NSUserDefaults` through `shared_preferences`, plus a check that every plugin
  ships its own manifest.
- **iPhone only at launch.** Set the device family to iPhone unless iPad layouts are reviewed and
  given their own screenshots; iPad can follow.
- **Review.** Review notes with a demo landlord account seeded with fictional data, already
  confirmed so e-mail confirmation cannot block it, and reset before each submission.
- **Storefronts.** Pakistan and the overseas countries; the EU only if AR LABS publishes its trader
  details.
- **Later, with [billing](billing.md).** Subscriptions through StoreKit (3.1.1); a link to web
  checkout only on the US storefront.

### Residence (decision 1)

Overseas owners lean towards iPhones, so a public TestFlight link is how most of them join the
[pilot](pilot.md) before the listing is live. Storefronts include the Gulf, the UK and North
America. The screenshots show the overseas owner with a caretaker beside the resident landlord. As
on Android, the App Store country is never read as residence.

### Letterheads (decision 2)

Once letterheads ship, one screenshot shows a receipt on a fictional letterhead.

### Analytics (decision 3)

The App Privacy answers follow the privacy notice. Contact details and the landlord's records are
collected for app functionality and linked to the account. Analytics (PostHog) and support chat
(Intercom) are declared even though they start only after opt-in. Nothing is used to track people
across other companies' apps, so App Tracking Transparency is not needed. Guideline 5.1.2(i) applies
the same opt-in pattern to AI: speech-to-text, server-side document reading and the MCP server each
need explicit permission in the app before data leaves for a third-party model, stored in the same
consent table as analytics.

## Work

1. **Owner:** register the domain and set up work e-mail on it.
2. **S:** move the website and the web app to the domain: Vercel domains, the default URLs in
   `urls.ts`, Auth's site URL and redirects, and redirects from `vercel.app`.
3. **Owner:** enrol as an organisation (D-U-N-S, Account Holder, two-factor Apple Account in a legal
   name) and pay the fee.
4. **M:** certificates, App ID and a signed TestFlight upload job on Xcode 26 in `release.yml`.
5. **S:** Associated Domains entitlement, `apple-app-site-association` through `package_vercel.py`
   with a packaging test, and the Auth redirect steps in `docs/operations.md`.
6. **M:** `PrivacyInfo.xcprivacy`, the plugin manifest audit, and the App Privacy answers.
7. **S:** iPhone-only device family (unless the owner keeps iPad) and the age-rating questionnaire.
8. **M:** listing in English and Urdu kept in `app/store/apple/` (to be created); review notes and
   the demo account with its reset script.
9. **Owner:** storefronts, and the EU decision (trader details published, or EU storefronts
   excluded).
10. **Owner:** internal, then external TestFlight groups for the pilot; App Review submission.

## Depends on / Unblocks

- **Depends on:** the D-U-N-S number and the domain (owner actions), [legal-review](legal-review.md)
  (the privacy policy and its in-app link), [app-icon](app-icon.md) (the iOS icon and screenshots),
  [urdu-review](urdu-review.md) (the Urdu metadata), and [pilot](pilot.md) for TestFlight testers.
- **Shares with:** [play-store](play-store.md), which needs the same D-U-N-S number and gains the
  same domain for App Links.
- **Unblocks:** [pilot](pilot.md) (the iPhone channel), [billing](billing.md) (StoreKit
  subscriptions), and [push-notifications](push-notifications.md), whose APNs key needs the same
  membership.

## Risks

- **Enrolment refused because of the domain.** Buy the domain and put a functional company page and
  work e-mail on it before enrolling.
- **The seller name reads "AR LABS (SMC-PRIVATE) LIMITED".** That is the legal name and cannot be
  changed; the app name and subtitle carry the brand.
- **Rejection under 2.1** if the reviewer cannot sign in. Keep a confirmed demo account and test it
  before each submission.
- **Privacy-label or manifest mismatches** with the SDKs. Audit at each SDK change, and let the
  upload's own validation fail CI.
- **No Mac in this container.** iOS changes are verified only in CI; keep the signing job's logs and
  a TestFlight install check in the definition of done.

## Done when

- [ ] An organisation membership for AR LABS is active.
- [ ] A signed build from CI (Xcode 26, iOS 26 SDK) installs through TestFlight and is approved on
      the App Store, with English and Urdu listings.
- [ ] An e-mail link opens the app on an iPhone through a universal link served from AR LABS's
      domain.
- [ ] In-app deletion and the privacy-policy link pass review, and the App Privacy answers match the
      privacy notice and the SDKs.
- [ ] Storefronts are set, with EU trader details published or the EU excluded.

## Questions for the owner

- Which domain, and which work e-mail address?
- Who is the Account Holder?
- iPhone only at launch, or iPad too?
- Which storefronts, and the EU or not?
- Is a demo account in production acceptable, and who resets it?
