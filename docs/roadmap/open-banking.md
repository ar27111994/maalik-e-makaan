# Bank account data through open banking

Milestone **Money that moves** (`money`), due 30 November 2028. Issue `open-banking` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). One step cannot wait: comments on the State
Bank's draft regulations close on **30 November 2026**. Everything else waits for the final rules.

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Rent paid by bank transfer or Raast lands in the landlord's account, and today someone has to
notice it and enter it, or share a statement. With the landlord's consent, open banking would let
the app see new credits to that account and suggest which tenant and month each one pays, for
the landlord to approve. Nothing would be recorded without that approval, and the landlord's
other spending would never be kept.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **Only a draft exists.** The State Bank published draft Open Banking Regulations on 30 October
  2026 for public consultation. Comments go by e-mail (subject "Feedback on Draft Open Banking
  Regulations") or by post to the Payment Systems Policy & Oversight Department in Karachi, by
  30 November 2026
  ([ProPakistani](https://propakistani.pk/2026/10/30/sbp-wants-fintechs-to-have-more-access-to-banking-data/),
  [APP](https://www.app.com.pk/business/sbp-opens-up-public-consultation-on-draft-open-banking-regulations-2/)).
- **What the draft would do**, as reported in news coverage _(summary)_
  ([Investify](https://www.investify.pk/news/100000159811/sbp-proposes-open-banking-rules-requiring-customer-authorised-data-sharing)):
  - oblige banks, microfinance banks and EMIs to give authorised third-party providers consented
    access to balances, transaction histories and payment initiation;
  - make Raast the hub for data sharing and payment initiation;
  - require consent dashboards where customers see, change or withdraw consent;
  - forbid providers to collect or store banking passwords, PINs or other credentials;
  - set dispute timelines of 7 working days for initial findings and 30 days for resolution.
- **Providers are licensed only after the rules are final** _(summary)_
  ([TechX](https://techx.pk/sbp-open-banking-rules-pakistan-fintech-financial-inclusion/)).
- **One report conflicts.** NextGen wrote in August 2026 that a framework had been "rolled out"
  ([NextGen](https://nextgen.pk/news/sbp-open-banking-framework-pakistan)); every other outlet
  describes a draft.
- **The draft text was not read**
  ([draft PDF](https://www.sbp.org.pk/assets/document/Open_Banking_Regulations_for_Public_Consulatation_Draft.pdf)).
  Provider categories, capital, the interface standard, how long a consent lasts and the banks'
  timetable are unknown.
- **"Account information" is already an EMI service** in the State Bank's EMI Regulations
  ([SBP EMI Regulations](https://www.sbp.org.pk/assets/document/C3-Enclosure-Regulations-EMIs.pdf)).
- **Nothing reads a bank account today.** The schema holds `portfolios.bank_iban`, checked by
  `app.is_valid_iban` ([foundation.sql](../../supabase/migrations/20261103192528_foundation.sql))
  and by `Iban` in `mm_core` ([iban.dart](../../packages/mm_core/lib/src/identity/iban.dart)).
- **The matcher is planned.** [reconciliation](reconciliation.md) plans the `incoming_credits`
  staging table, the matching engine and approval through `record_payment`, and lists open
  banking as a later input.

## Design

**Comment now.** A response of about two pages, from AR LABS as a prospective user of account
information, sent by 30 November 2026. Reading the draft PDF is the first step. It asks for:

- a proportionate, read-only account-information category for small software firms;
- the remitter's name and the Raast or IBFT reference in transaction data, without which rent
  cannot be matched to a tenant;
- consent that can be limited to credits;
- clear rules for joint and family accounts, which often receive rental income.

**Wait for the rules, then use a partner.** Final rules, then licensing, then banks' interfaces
going live make production access unlikely before 2028 (an inference). The route is a licensed
provider as partner, not a licence for AR LABS. There is no interim route: the draft bans
collecting credentials, so screen-scraping is out. Statement and message import in
[reconciliation](reconciliation.md) covers the gap.

**When a partner exists:**

- **Consent per account and portfolio.** The account holder chooses the portfolio, is sent to the
  provider and the bank to consent, and returns. Consent covers credits only, a fixed look-back
  on first connection and an expiry. It is recorded in `consents` with the purpose `bank_data`,
  the text version, the provider's consent ID and the expiry.
- **No credentials, and tokens outside tables.** The provider holds the bank's tokens where it
  can. Any token AR LABS must hold sits in Vault, referenced by ID, and is deleted on revocation.
- **Credits only.** A step in the existing ten-minute job wakes an import function that asks for
  new transactions. Debits are dropped in the function's memory and never written or logged.
  Credits go to `incoming_credits` with the source `open_banking`, de-duplicated against
  statement and message imports and against recorded payments by reference, then matched by the
  [reconciliation](reconciliation.md) engine. A person approves each one through `record_payment`.
- **Revocation from both ends.** From the app's connected-accounts screen, or from the bank's
  consent dashboard; the first import the provider refuses marks the connection revoked and
  deletes the token, so imports stop within one cycle.
- **Retention.** Kept credits follow reconciliation's deletion period after they are resolved.

### Residence (decision 1)

The research recommends limiting this to resident landlords' Pakistani accounts; Roshan Digital
Accounts and foreign accounts are probably out of scope. Whether an owner abroad may connect a
Pakistani account too is the owner's call (question 2). If the owner allows it, a bank's consent
step that needs a Pakistani SIM may not work from abroad, which the connect screen says plainly.
Either way, only the account holder connects an account, from their own session; a caretaker never
connects the owner's account, because the bank's data belongs to the holder. Credit dates stay
Pakistan dates; "consent expires soon" and "new credits to match" notices follow the holder's time
zone and quiet hours.

### Letterheads (decision 2)

No new document. An approved credit produces the ordinary receipt, on the portfolio's letterhead.

### Consent and analytics (decision 3)

The consent record uses the shared shape (subject, purpose, text version, granted and withdrawn
times, method, evidence). The provider is named in the privacy notice, and the data export
includes connections, consents and kept credits. No transaction, amount, name or reference
reaches analytics; counts of connections and imports come from server aggregates.

## Work

1. **Owner + S:** read the draft; write and send the consultation response by 30 November 2026,
   and record it in [STATE.md](../../.planning/STATE.md).
2. **Owner:** track the final rules, the licensed providers and which banks go live; choose a
   partner provider.
3. **M:** design record: consent scope, look-back, minimisation, retention, token storage,
   revocation and the privacy notice text.
4. **M:** migration: `bank_connections` (portfolio, holder, provider, masked account, consent ID,
   scope, expiry, status, last import) and the `open_banking` source on `incoming_credits`; RLS
   so that only the holder manages a connection and owners see its status; pgTAP.
5. **M:** consent redirect and callback function, token storage in Vault, revocation; Deno tests.
6. **M:** import function: fetch, drop debits in memory, normalise and de-duplicate; Deno tests
   with provider fixtures that mix debits and credits.
7. **S:** `open_banking` credits in the reconciliation inbox; pgTAP that a credit already recorded
   by hand shows as matched.
8. **M:** connected-accounts screen (status, last import, scope, expiry, paused, revoke), in
   English and Urdu, with goldens.
9. **M:** end-to-end test in the provider's sandbox, a UAT journey in [`uat.md`](../uat.md), and
   the revocation test.

## Depends on / Unblocks

- **Depends on:** the final State Bank rules and provider licensing; a partner contract;
  [reconciliation](reconciliation.md) (staging table and matcher);
  [draft-payments](draft-payments.md) (key derivation and de-duplication);
  [audit-screen](audit-screen.md) (approvals shown with their source);
  [legal-review](legal-review.md) (consent and notice text).
- **Unblocks:** [agent-coordination](agent-coordination.md), where bank data reaches assistants
  only as rows from a licensed provider, never through an agent protocol. Related:
  [raast-request-to-pay](raast-request-to-pay.md) (payment initiation under the same rules).

## Risks

- **The timeline overruns the milestone.** Mitigation: nothing beyond the response and the design
  is built before the rules are final; statement import covers the gap.
- **Uneven coverage across banks.** Mitigation: the connect screen lists the banks that work;
  statement import stays for the rest.
- **Private spending in the data.** Mitigation: credits only; debits dropped in memory, proved by
  a test over every table and log.
- **The provider fails or leaves.** Mitigation: one adapter interface; connections show as
  paused; credits already kept are not lost.
- **Consent expires unnoticed.** Mitigation: a reminder before expiry, in the holder's time.

## Done when

- [ ] The consultation response is sent by 30 November 2026, or the owner has decided not to.
- [ ] Imports run only under an active, recorded consent (pgTAP and Deno tests).
- [ ] Revoking consent in the app or at the bank stops imports within one cycle and deletes the
      token.
- [ ] No banking password, PIN or other credential is ever asked for or stored.
- [ ] Only credits are written: fixtures that mix both leave no debit in any table or log.
- [ ] No credit becomes a payment without a person's approval, and a credit already recorded by
      hand with the same reference shows as matched, not as a new suggestion.
- [ ] Every string exists in English and Urdu, and the design lint passes.

## Questions for the owner

1. Will AR LABS send comments on the draft by 30 November 2026, and who signs them?
2. Resident landlords' Pakistani accounts only (the research's recommendation), or Pakistani
   accounts held by owners abroad too? Roshan Digital Accounts if the rules allow?
3. Is a partner provider acceptable, given that landlords consent to it as well as to AR LABS?
4. How far back should the first import look: 30 days or 90?
5. Which plans include it?
