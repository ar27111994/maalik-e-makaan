# Terms of use: draft clauses for decisions 1 to 3 (English)

> **Draft for the lawyer's review. Not live.** These clauses add to the live
> [terms](../../website/src/content/pages/en/terms.md) what decisions 1 (residence and caretakers),
> 2 (letterheads) and 3 (the messages we send, and the opt-in services) need. None of them has
> shipped, and the live terms stay as they are until the lawyer approves the text and the features
> ship. This is not legal advice.

Part of the [legal review pack](README.md). Square brackets mark a point still open, with the
question number from [questions.md](questions.md).

## What this file covers, and what it does not

It covers only:

- a caretaker's authority, whether under a power of attorney or as the "manager" that provincial
  laws name, and that AR LABS does not verify it (LR:93-96);
- the owner-abroad answer and declared residence, as far as the terms need them (decision 1);
- the owner's warranty that they may use what they put on a letterhead and that it is accurate
  (LR:101-102; RM:247-248);
- the messages AR LABS sends as part of the service, including the notice at least 60 days before
  anything is charged, and that tips and news, analytics and support chat are opt-in (decision 3;
  LR:116-118).

The full rewrite of the terms is work item 3 of [legal-review](../roadmap/legal-review.md)
(LR:127-128): governing law and forum, the roles of AR LABS, owner, caretaker and tenant, liability,
paid-plan clauses and the prevailing language. The "for and on behalf of the owner, through
attorney" block for documents a caretaker signs is one of the lawyer's own deliverables (LR:84;
RM:243-245) and is not drafted here; [question C3](questions.md#residence-and-caretakers) asks for
it.

Short names: **PJ**, **RM** and **LR** are [`.planning/PROJECT.md`](../../.planning/PROJECT.md),
[`docs/roadmap/README.md`](../roadmap/README.md) and
[`docs/roadmap/legal-review.md`](../roadmap/legal-review.md) at commit `ae0112c` on `main`, with LR
as this pack's pull request leaves it ([README](README.md#sources-and-conventions)); **TEN**
is the live [terms](../../website/src/content/pages/en/terms.md); **RES** is
`supabase/migrations/20261112092618_residence.sql` in pull request
[#61](https://github.com/ar27111994/maalik-e-makaan/pull/61) at commit `6608f1e` (not merged).

## Where the clauses go

The live terms have, under "The app", a short list introduced by "For now:" (TEN:20-25), then "The
code" (TEN:27). The clauses below go in three new subsections between them, after TEN:25 and before
TEN:27, and two existing lines change.

| Place in `terms.md`                | Change                                                                           | Clauses    |
| ---------------------------------- | -------------------------------------------------------------------------------- | ---------- |
| TEN:22                             | Add that the duties the law puts on you stay yours when a caretaker acts for you | 1.1        |
| TEN:23                             | Add the people you invite and what you put on a letterhead                       | 1.2        |
| New, after TEN:25                  | `### Caretakers and other people you invite`                                     | 2.1 to 2.5 |
| New, after the subsection above    | `### Letterheads`                                                                | 3.1 to 3.5 |
| New, after the Letterheads clauses | `### Messages from us`                                                           | 4.1 to 4.3 |

## 1. Changes to existing lines

### 1.1 TEN:22

Live text:

> **It is a record-keeping tool.** It records rent and payments; it does not collect, hold or
> transfer money. You remain responsible for your tenancies, your records, your tax returns and
> what the law requires of you, such as registering tenants with the police.

Proposed:

> **It is a record-keeping tool.** It records rent and payments; it does not collect, hold or
> transfer money. You remain responsible for your tenancies, your records, your tax returns and
> what the law requires of you, such as registering tenants with the police. That stays so when a
> caretaker or anyone else you invite does that work for you.

Why: decision 1 makes the caretaker always an app user with the manager role (PJ:102-103). The
police guide puts the duty to give the tenant's details to the police on the property dealer, the
landlord and the tenant in Sindh, and the duty to check the tenant's CNIC on "a landlord, manager
or property dealer" there
([`police-registration.md`](../../website/src/content/guides/en/police-registration.md):80). In
Khyber Pakhtunkhwa and Balochistan, "the landlord, lessee or manager" gives the information (:90,
:109). LR:94-95 names only Khyber Pakhtunkhwa and Balochistan. [Lawyer: C4, who is responsible.]

### 1.2 TEN:23

Live text:

> **You are responsible for what you enter**, including your tenants' personal details: collect
> only what you need, with their consent, and keep it accurate.

Proposed:

> **You are responsible for what you enter**, including your tenants' personal details: collect
> only what you need, with their consent, and keep it accurate. That includes what the people you
> invite enter in your portfolios, and what you put on a letterhead.

## 2. New subsection: Caretakers and other people you invite

> ### Caretakers and other people you invite
>
> **2.1 You choose who helps you.** An owner can invite people to a portfolio, each with a role:
> owner, manager, accountant or viewer. Each role allows only certain things, as the app shows when
> you invite someone. An owner can name one of the portfolio's managers as its caretaker. A
> caretaker always uses the app with an account of their own.
>
> **2.2 A caretaker's authority is between you and them.** A caretaker may act for you under a
> power of attorney, or as the "manager" of a building whom some provincial laws make responsible,
> with the landlord, for giving a tenant's details to the police. The app records who the caretaker
> is and what they do in the app. It does not record, check or verify a power of attorney or any
> other authority, and AR LABS does not verify it. Make sure that anyone who acts for you has the
> authority they need. [Lawyer: C3, whether to name the provinces and how.]
>
> **2.3 What the people you invite do in your portfolio is part of your records.** The payments a
> caretaker or other member records, the receipts they issue and the tenants they add are records
> of your portfolio, and the audit trail shows who made each change. As between you and AR LABS,
> you are responsible for choosing the people you invite and the roles you give them. [Lawyer: C4,
> whether the owner, the caretaker or both answer for what a caretaker records.]
>
> **2.4 The owner-abroad question.** The app asks whether the owner of a portfolio's properties
> lives abroad, when the portfolio is set up or, for an older portfolio, the next time an owner or
> manager opens it. An owner or a manager may answer it. Answer it truthfully: the answer decides
> which features the portfolio offers to an owner abroad, and every member of the portfolio can see
> it. Once it is answered, only an owner can change it. [Lawyer: C2.]
>
> **2.5 Where you live.** You may tell the app the country you live in and your time zone. If you
> do, give them accurately. Your time zone sets when your own alerts and summaries reach you. Your
> country may suggest a plan, but it never changes a price: the app store you use sets the price.
> No other user can see them. [Lawyer: C1, C5.]

Why and sources:

- **2.1:** PJ:102-103 (the caretaker is a manager member who uses the app); RES:25-31 and
  :590-625 (only an owner names the caretaker; it must be a manager); the roles in
  [`docs/architecture/permissions.md`](../architecture/permissions.md).
- **2.2:** LR:93-96 ("The terms describe a caretaker's authority, whether under a power of
  attorney or as the 'manager' … and say AR LABS does not verify it"); the police guide lines
  above. Whether a power of attorney to let property must be registered, and what authority a
  caretaker has without one, are open (local research note `tenancy_law_and_data.md` §6, not
  tracked).
- **2.3:** the audit trail records the actor of every change
  (`supabase/migrations/20261103194402_notifications_audit.sql`); only owners confirm or void cash
  handovers (`supabase/migrations/20261103194151_operations.sql`).
- **2.4:** PJ:109-112 (asked with no answer chosen, never filled in from the creator's residence);
  RES:15-24 (every portfolio that exists when the change ships starts unanswered, and "the app asks
  on the next open by an owner or manager"); RES:546-588 (owners or managers answer while it is
  empty; then only owners change it); every member can read it (identity migration :664-666 with
  RES:353-371).
- **2.5:** PJ:96-99; RES:261-269 (own row only; the time zone serves only the person's own
  alerts); operators reach the row through the service role (RES:347), which the privacy notice
  covers, so the clause speaks of other users; RM:164 and [`billing.md`](../roadmap/billing.md):111
  ("declared residence only suggests a plan and never changes a price"); the pricing page
  ([`pricing/en.yaml`](../../website/src/content/pricing/en.yaml):121: the store account's country
  decides the currency, "not … where you live").

## 3. New subsection: Letterheads

> ### Letterheads
>
> **3.1 What a letterhead is.** You can upload a letterhead for a portfolio, or make one in the
> app, and add an Urdu version if you like. The app prints it on the receipts, statements and other
> documents it makes for that portfolio. It prints receipts on the paper size you choose, A5 or A4.
> An owner can copy a letterhead to their other portfolios. [Owner: which roles may upload or change
> a letterhead.]
>
> **3.2 What you promise.** When you upload or make a letterhead, you promise that:
>
> - you have the right to use everything on it, including any logo, name, mark, address or phone
>   number, on documents for that portfolio;
> - what it says is accurate and not misleading, and it names the person or business that issues
>   the portfolio's receipts, in its Urdu version as much as in the main one;
> - where it names or shows another person or business, such as a caretaker or a company, you have
>   their permission.
>
> [Lawyer: L1, whether to add an indemnity; L2, the issuer.]
>
> **3.3 What is checked, and what is not.** When you upload an image, the app makes a new copy of
> it on your device, without its hidden details, such as where it was taken. [Owner: when PDF
> uploads ship:] When you upload a PDF, AR LABS checks it for safety: it refuses some files,
> rebuilds the PDF without active content and deletes the file you uploaded. AR LABS does not check
> what a letterhead says, or whether you may use it.
>
> **3.4 Removal.** AR LABS may remove a letterhead that is unlawful, or that someone shows us they
> have the right to stop you using, and will tell you if it does. [Lawyer: L1, the route for a
> complaint about a name or logo.]
>
> **3.5 Your documents.** A document printed on your letterhead is your document. You are
> responsible for what it says and for giving it to your tenants, as you are for any receipt or
> statement the app makes for you.

Why and sources:

- **3.1:** PJ:119-134 (per portfolio; copied to the owner's other portfolios; an optional Urdu
  letterhead; A5 or A4 receipts; on every plan); RM:213-221. Who may write a letterhead is not
  decided; the research proposes owners and managers (local note `analytics_support_letterheads.md`
  §5).
- **3.2:** LR:101-102 ("the owner's warranty that they may use what they upload (logos, names,
  addresses) and that it is accurate"); RM:247-248. The portfolio is the issuer on its receipts
  (PJ:126-127), hence the second promise.
- **3.3:** RM:205-208 (images are re-encoded on the device, "which drops location and other
  metadata"; `letterhead-ingest` refuses encrypted files, more than two pages, unusual page sizes
  and active content, rebuilds a clean PDF and deletes the original). PDF uploads come after the
  builder and image letterheads (RM:226), and the owner is advised to ship images at launch
  (RM:450), so the PDF sentence waits for them.
- **3.4:** no takedown route exists in the design; [L1](questions.md#letterheads) asks whether one
  is needed.
- **3.5:** TEN:22-23 already make the user responsible for their records; this applies it to
  letterheaded documents.

## 4. New subsection: Messages from us

> ### Messages from us
>
> **4.1 Service messages.** While you have an account, we send you the messages the service needs,
> by email and in the app: invitations you ask us to send, receipts you choose to email, security
> notices, and notices about your account and the service, including at least 60 days' notice
> before anything is charged. They are part of the service, so they are sent whatever you choose
> about tips and news.
>
> **4.2 Tips and news** come only if you switch them on, and you can switch them off at any time.
>
> **4.3 Your privacy choices.** Analytics and support chat in the app stay off until you switch them
> on. The privacy page says what each sends. [Lawyer: E1, N3.]

Why and sources:

- **4.1:** RM:294-298 (account, invitation, receipt, security and contractual messages as service
  e-mail; "The 60-day notice before billing starts is a contractual message, sent to every
  early-access user whatever their marketing consent"); the pricing page promises "at least 60
  days' notice by email and in the app"
  ([`pricing/en.yaml`](../../website/src/content/pricing/en.yaml):13). The live terms say nothing
  about messages (TEN:20-33), so the lawyer's answer to [E1](questions.md#e-mail) (LR:116-118) has
  no text to attach to without this clause.
- **4.2, 4.3:** PJ:143-144 (nothing to PostHog or Intercom until the person opts in; lifecycle
  e-mail only with consent); RM:289-290 (three switches, all off at first). The privacy notice
  describes each ([privacy-notice.en.md](privacy-notice.en.md), "Your privacy choices" and
  "Emails").
