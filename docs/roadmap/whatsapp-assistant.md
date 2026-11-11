# A WhatsApp assistant, with voice notes

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `whatsapp-assistant` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). It rests on five other items, so it is the
last of the milestone to start, in the second half of 2027.

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Many landlords and caretakers live in WhatsApp and send voice notes rather than open an app.
Asking "who still owes rent this month?", or saying "Flat 2 paid twenty-five thousand" in a voice
note and getting back a filled-in entry to confirm with one tap, fits how they already work.
Munshi, the assistant, only drafts: nothing is recorded until the landlord taps Confirm.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

- **Meta's terms bar general-purpose AI assistants** as the primary function of a WhatsApp
  Business integration, for all businesses since 15 January 2026
  ([TechCrunch](https://techcrunch.com/2025/10/18/whatssapp-changes-its-terms-to-bar-general-purpose-chatbots-from-its-platform/)).
  Bots that serve a specific business function remain allowed, though how an open-ended bot tied
  to a business is judged is not settled _(summary)_
  ([respond.io](https://respond.io/blog/whatsapp-general-purpose-chatbots-ban)).
- **Conversations started by the landlord are cheap.** Incoming messages are free; replies inside
  the 24-hour window are free up to 1,000 a month per number, then charged at the utility rate of
  the recipient's country, about US$0.015 in Pakistan _(summary)_
  ([YCloud](https://www.ycloud.com/blog/whatsapp-api-message-pricing-update-effective-october-1-2026)).
- **Voice notes** are fetched in two steps through the media endpoint _(summary)_
  ([Meta](https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/audio-messages)).
  Interactive reply buttons exist, and Flows (forms in the chat) that call an endpoint need
  their own RSA key pair _(summary)_
  ([Meta](https://developers.facebook.com/documentation/business-messaging/whatsapp/flows/guides/implementingyourflowendpoint)).
- **Phone numbers in profiles are unverified:** SMS sign-up is off
  ([config.toml](../../supabase/config.toml)), and people type their own number
  ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
- **The money parser is half built:** `mm_core` already reads digits followed by a unit word,
  such as "1.5 lac" or "50k" ([money_parse.dart](../../packages/mm_core/lib/src/money/money_parse.dart));
  words and Urdu numerals come with [amount-parser](amount-parser.md).
- **The pieces this item reuses are all planned, none built:** the WhatsApp account and webhook
  ([whatsapp-reminders](whatsapp-reminders.md)), drafts ([draft-payments](draft-payments.md)),
  read functions and OAuth clients ([mcp-read](mcp-read.md)), mandates
  ([agent-limits](agent-limits.md)) and attribution in the trail
  ([audit-screen](audit-screen.md)).
- **The deck's principle:** "the model drafts, a person confirms, and the database decides what
  is allowed" ([agents slide](../../website/deck/slides/agents.html)).
- **Apple** requires apps to disclose, and get explicit permission for, personal data shared
  with third-party AI (guideline 5.1.2(i),
  [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

## Design

**A business function, not a chatbot.** Munshi answers only about the linked person's
portfolios: dues, payments, receipts and reminders. Anything else gets a fixed refusal in the
person's language. That keeps it within Meta's terms and limits what planted text can do.

**Linking.** A person links their WhatsApp number from inside the signed-in app. The app shows a
single-use code in a `wa.me` link to the business number; the message that arrives binds that
number to the person in `whatsapp_links` (person, number, linked and revoked times), which is
audited. Owners and managers can link. Unlinking in the app, or sending "STOP" from the linked
number, revokes it. Unlinked numbers get no portfolio data. A tenant who writes gets a fixed
reply, not from a model, pointing to their [tenant-portal](tenant-portal.md) link and their
landlord.

**Acting as the person.** Munshi is a first-party OAuth client. Every read and draft runs as the
linked person with Munshi's `client_id`, so RLS, the mandate check and the audit marking apply
exactly as for an outside assistant. The service-role key never acts for a person. How the
webhook holds a short-lived token for the person (a refresh token in Vault, or a token issued per
message) is settled by the first spike.

**Reads** use the functions built for [mcp-read](mcp-read.md) (`who_owes`, `tenant_statement`,
`overdue_list`), whose output carries no CNIC or phone number.

**Writes are drafts.** A payment becomes a `payment_drafts` row with source `whatsapp`; a
reminder becomes a pending action. Munshi replies with the fields read back in words, and Confirm
and Cancel buttons; a Flow serves entries with several fields. Only a Confirm tap from the linked
number commits, through `record_payment` with the draft's idempotency key. The trail then reads
"drafted through Munshi, confirmed by the person on WhatsApp". Drafts expire after 24 hours. A
second tap, or a tap on an expired draft, gets an answer and records nothing.

**Amounts never come from the model.** The model may choose the intent and suggest the lease. The
amount and the date come from the deterministic grammar of [amount-parser](amount-parser.md),
shared with TypeScript through contract vectors. When the parser refuses, Munshi asks again.

**Voice notes.** Download the audio, transcribe it, show the transcript before any draft, parse
the amount from the transcript, and delete the audio straight away. The transcript lives only as
long as the draft.

**Untrusted text.** Tenant names, notes and forwarded messages reach the model marked as data,
capped in length and cleaned by the clean-text rules. The model has no tool that writes without a
draft, and none for voids, waivers, deletions or team changes.

**Reminders** Munshi drafts go out through [whatsapp-reminders](whatsapp-reminders.md), with its
consent and etiquette rules.

**Limits.** Per number and per person through `admin_rate_limit_hit`, and a monthly cap on model
cost per account.

**Evaluation.** A set of questions and amounts in English, Urdu and Roman Urdu, as text and as
synthetic voice recordings with no real people, scored against an accuracy target the owner
sets. The deterministic parts (router, parser, refusals) are tested in CI.

### Residence (decision 1)

An owner abroad writes from a foreign number, so replies to them are billed at that country's
rate. Replies go at once; anything Munshi starts itself, such as "this draft expires in an hour",
follows the person's own time zone and quiet hours. Dates a person says ("today", "yesterday")
become Pakistan dates and are read back as dates. A caretaker's drafts need a mandate the owner
approved ([agent-limits](agent-limits.md)).

### Letterheads (decision 2)

A receipt sent in the chat is the letterheaded receipt the app stored when the payment was
confirmed.

### Analytics and AI providers (decision 3)

Linking asks for explicit consent to send messages and voice notes to the named speech-to-text
and model providers, recorded in `consents` with its text version; withdrawing it unlinks the
number. The providers are processors with no retention and no training on the data, named in the
privacy notice with their regions. No message, transcript, amount or name reaches PostHog; usage
figures come from server aggregates. Human support stays on Intercom, behind support-chat
consent; Munshi tells people how to reach it and hands nothing over.

## Work

1. **S:** spike: holding a token for the linked person; the state of Supabase's OAuth server;
   reply buttons and Flows in Urdu.
2. **S:** number linking and unlinking: `whatsapp_links`, single-use codes, RLS, audit, the app
   screen in both languages.
3. **M:** inbound router in `whatsapp-webhook`: person lookup by number, limits, fixed replies for
   unlinked numbers and tenants, the off-topic refusal; Deno tests at 100%.
4. **M:** read tools over the [mcp-read](mcp-read.md) functions, with untrusted text marked.
5. **M:** draft tools and confirmation: payment and reminder drafts, Confirm and Cancel, expiry,
   idempotent commit, audit marking.
6. **M:** model integration behind a provider interface, and the evaluation set in three
   languages.
7. **S:** speech-to-text spike on Urdu and Roman Urdu numbers.
8. **M:** voice integration: download, transcribe, read back, delete.
9. **S:** privacy notice, processor agreements, the consent screen, a runbook and a decision
   entry.

## Depends on / Unblocks

- **Depends on:** [whatsapp-reminders](whatsapp-reminders.md) (account, number and webhook),
  [agent-limits](agent-limits.md), [amount-parser](amount-parser.md),
  [draft-payments](draft-payments.md), [mcp-read](mcp-read.md), [audit-screen](audit-screen.md),
  [legal-review](legal-review.md) (the providers in the notice), [urdu-review](urdu-review.md),
  and the owner's choice of providers.
- **Unblocks:** [agent-coordination](agent-coordination.md). Related:
  [overseas-oversight](overseas-oversight.md) (findings phrased by Munshi later) and
  [push-notifications](push-notifications.md).

## Risks

- **Meta reads "primary function" more widely.** Mitigation: the narrow scope and fixed refusals;
  the app remains the full path; Munshi can be switched off per account.
- **Transcription mishears Urdu numbers.** Mitigation: the deterministic parser, the read-back and
  the tap; refusing beats guessing.
- **Planted instructions in tenant notes or forwarded messages.** Mitigation: text marked as
  data, no write without a draft, and the mandate's limits.
- **A spoofed link or a lost phone.** Mitigation: linking only from the signed-in app, single-use
  codes, unlinking in the app, and the audit screen.
- **Personal data at Meta and the model vendors.** Mitigation: consent, the least context that
  answers, no retention.
- **Model cost.** Mitigation: a monthly cap per account and a small model for routing.

## Done when

- [ ] No ledger write happens without a Confirm tap from the linked number of a person whose role
      and mandate allow it.
- [ ] Unlinked numbers and tenants never receive portfolio data, tested over fixtures.
- [ ] Off-topic requests get the fixed refusal.
- [ ] Every amount comes from the deterministic parser and is read back in words; the evaluation
      set meets the owner's target in all three languages, by text and by voice.
- [ ] Audio is deleted after transcription, and transcripts with their draft.
- [ ] Every confirmed draft appears on the audit screen as made through Munshi and confirmed by
      the person.
- [ ] No request reaches a model or speech provider before the person's consent is recorded.

## Questions for the owner

1. Which model and speech-to-text providers, and may data leave Pakistan for them?
2. May caretakers use Munshi, and with which default limits?
3. Should tenants ever talk to Munshi, or only use the portal?
4. A separate WhatsApp number from the reminders, to keep their quality ratings apart?
5. Which plans include Munshi, and what monthly cap on model cost?
6. What accuracy on the evaluation set is good enough to launch?
