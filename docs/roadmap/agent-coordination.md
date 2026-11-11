# Landlord, tenant and caretaker assistants that work together

Milestone **Money that moves** (`money`), due 30 November 2028. Issue `agent-coordination` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). It is the last item on the roadmap. Phase 1
needs [agent-limits](agent-limits.md), [tenant-portal](tenant-portal.md) and
[whatsapp-assistant](whatsapp-assistant.md) first; phase 2 waits for an outside party that wants
it.

## Why it matters

Rent involves three people who rarely look at the same record at the same time: the tenant says
they paid, the caretaker holds the cash, and the owner wants to know. If each one's assistant can
hand the others a structured item that can be checked ("paid Rs 25,000 by Raast, reference X",
"handed over Rs 60,000 today"), the landlord confirms with one tap instead of chasing screenshots
and calls. Each assistant can do only what its person may do, and nothing reaches the ledger
without the person who owns that decision.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries, because the primary pages could not be fetched.

- **Four roles and no agents.** Members are owners, managers (the caretaker), accountants or
  viewers ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
  Tenants have no accounts: [tenant-portal](tenant-portal.md) plans a read-only link per tenancy
  whose request form writes `tenant_requests` rows.
- **One cross-role flow already exists.** A caretaker records a cash handover and an owner
  confirms it (`cash_handovers`, `confirm_cash_handover` in
  [operations.sql](../../supabase/migrations/20261103194151_operations.sql)).
- **Assistants are planned as delegates of a person.** [mcp-read](mcp-read.md) plans
  `agent_grants` for OAuth clients acting for one member; [agent-limits](agent-limits.md) plans
  `agent_mandates`, `pending_actions` and drafts confirmed by a tap; and
  [whatsapp-assistant](whatsapp-assistant.md) gives a tenant who writes a fixed reply, never a
  model's.
- **The deck promises it:** "Landlord, tenant and caretaker agents that coordinate", using the
  A2A protocol ([roadmap slide](../../website/deck/slides/roadmap.html)).
- **A2A reached version 1.0 under the Linux Foundation in 2026**, with signed Agent Cards and an
  AP2 extension; sources disagree on the date _(summary)_ ([Tyk](https://tyk.io/blog/a2a-protocol/)).
- **Signed agent requests are still a draft.** The IETF working-group draft "HTTP Message
  Signatures for Bots" (October 2026, expiring May 2027) defines signed requests with a key
  directory at a well-known address, and says the signature "says nothing about who operates the
  agent or whether it is benign"
  ([IETF draft-01](https://www.ietf.org/ietf-ftp/internet-drafts/draft-ietf-webbotauth-httpsig-protocol-01.html)).
- **Banks reach third parties through licensed providers** under the State Bank's open-banking
  draft, not through agent protocols _(summary)_
  ([SBP press release](https://www.sbp.org.pk/assets/documents/press-release/PR-30-October-2026.pdf)).
- **No counterpart is in view.** Nothing found suggests that Pakistani tenants, banks or property
  managers will run agents by 2028.

## Design

**Phase 1 (2028): coordinate through rows, not messages.** The landlord's, caretaker's and
tenant's assistants are Munshi acting for different people, each under that person's grant and
mandate. They never message one another. One role's assistant writes a typed row; the other
role's person, or their assistant as a draft, sees it under RLS; a person confirms it.

- **Tenant to landlord: payment claims.** `payment_claims`: lease, amount (`numeric(14,2)`), paid
  on, method, reference (up to 80 characters), source (`tenant_link`, later `tenant_agent`),
  status (`open`, `matched`, `rejected`, `expired`) and the payment it became. A tenant files one
  from their portal link, limited per link. The landlord's assistant matches it against incoming
  credits with the [reconciliation](reconciliation.md) engine and offers the match as a draft.
  The landlord's tap records it through `record_payment` with the key derived from the
  reference, so a claim and a statement line for the same transfer make one payment. A claim
  never writes the ledger.
- **Caretaker to owner: handovers.** The caretaker's assistant drafts a handover from a voice note
  (a new `draft_handover` mandate action); the caretaker confirms it, which records the
  `cash_handovers` row; the owner's queue shows it beside the cash position and any
  [overseas-oversight](overseas-oversight.md) finding; an owner confirms it.
- **Landlord to tenant: reminders and requests.** The landlord's assistant drafts a reminder, or
  a request through [raast-request-to-pay](raast-request-to-pay.md); the landlord confirms it;
  the tenant sees it on their link.

**Only structured fields cross roles.** A row from one role reaches another role's assistant as
typed fields (amount, date, method, reference, row IDs) checked by constraints. Free text that a
tenant or caretaker writes is shown only to people, labelled with who wrote it, and never passed
to the other side's model. One party's words then cannot steer another party's assistant.

**Identity for outsiders, when there are any.** Outbound webhooks to the first outside subscriber
(a landlord's own automation, a partner or a property manager's system) are signed with HTTP
Message Signatures ([RFC 9421](https://www.rfc-editor.org/rfc/rfc9421)), with the keys published
in a key directory, as the IETF draft does. A signature identifies a caller and never authorises
one: authority comes only from OAuth grants and mandates.

**Phase 2: an A2A interface only when someone is on the other end.** A signed Agent Card with one
read-only skill, a tenant's own balance and dues (the same view as the portal link), published
when a real outside agent asks for it. A2A tasks map onto the same `pending_actions`, claims and
mandates, so an outside agent gains no power a person has not granted. Bank data stays with
[open-banking](open-banking.md).

**When phase 2 starts.** The decision entry names the conditions: a named counterpart with a use
case, A2A stable on one major version for six months, and a legal review of what the Agent Card
exposes.

### Residence (decision 1)

The caretaker-to-owner handover is decision 1 in motion. On a portfolio marked `owner_abroad`,
drafts that wait for an owner sit in their queue and in their digest at their local time. The
caretaker named in `caretaker_user_id`, like any manager, drafts handovers through an assistant
only under a mandate an owner approved. Claims and handovers keep Pakistan dates.

### Letterheads (decision 2)

No new document. A claim that becomes a payment produces the ordinary receipt, on the portfolio's
letterhead.

### Consent and analytics (decision 3)

A claim is information the tenant chooses to send, and the link says who will see it. Wherever an
assistant acts, its mandate is the consent record, in the shared shape. No content of these
exchanges reaches analytics: no amounts, references, names or text. Counts come from server
aggregates.

## Work

1. **S:** decision entry: coordination through rows, the structured-fields rule and the
   conditions for phase 2; the coordination section in
   [`permissions.md`](../architecture/permissions.md).
2. **M:** `payment_claims` migration with RLS for owners, managers and the tenant link's
   function, and limits per link; pgTAP that a claim never writes the ledger.
3. **M:** claims on the tenant's link and in the landlord's matching inbox, in English and Urdu,
   with goldens.
4. **S:** the `draft_handover` mandate action and the owner's confirmation queue; pgTAP for the
   caretaker and owner roles.
5. **S:** the structured-fields guard: injection fixtures in claim and handover text never reach
   an assistant's prompt.
6. **M:** signed outbound webhooks, key directory and key rotation, built with the first
   subscriber.
7. **M (phase 2):** the signed Agent Card and the read-only balance skill, behind OAuth.
8. **M (phase 2):** A2A tasks mapped onto `pending_actions` and mandates, with tests that an
   outside agent cannot exceed its grant.

## Depends on / Unblocks

- **Depends on:** [agent-limits](agent-limits.md) (mandates and drafts),
  [mcp-read](mcp-read.md) (grants and OAuth clients), [tenant-portal](tenant-portal.md) (the
  tenant's side), [whatsapp-assistant](whatsapp-assistant.md) (Munshi),
  [reconciliation](reconciliation.md) (the matcher), [overseas-oversight](overseas-oversight.md)
  (the owner's queue), [raast-request-to-pay](raast-request-to-pay.md) (requests) and
  [open-banking](open-banking.md) (bank data).
- **Unblocks:** nothing on the roadmap; it is the last item.

## Risks

- **Persuasive text passed between assistants.** Mitigation: only structured fields cross roles;
  another party's text reaches people, never a model; injection fixtures run in CI.
- **A signature proves a key, not a person.** Mitigation: signatures identify; grants and
  mandates authorise.
- **Building to standards that are still moving.** Mitigation: phase 1 uses no external
  protocol, and phase 2 waits for its conditions.
- **A tenant cannot hold a mandate without an account.** Mitigation: in phase 1 the tenant's side
  is a form on the link; tenant accounts are the owner's decision.
- **Claims used to pester or to fake a payment.** Mitigation: limits per link; a claim is a
  suggestion, never a receipt.

## Done when

- [ ] A tenant's claim and a caretaker's handover each reach an owner as a draft to confirm,
      never as a ledger write (pgTAP for each role).
- [ ] A claim and a statement line for the same transfer record one payment.
- [ ] Injection fixtures in a claim's or a handover's text never reach the other side's
      assistant.
- [ ] Outbound webhooks verify against the published key directory, including after a key
      rotation.
- [ ] If an A2A interface is built, an outside agent can do nothing beyond its grant (tests).
- [ ] Every string exists in English and Urdu, and the design lint passes.

## Questions for the owner

1. Will tenants have accounts, which a tenant's own assistant needs, or only links?
2. Is an outside A2A partner, such as a bank, wallet or property manager, in view before 2028?
3. Who sees a tenant's claim: owners only, or the caretaker too?
4. May a tenant attach a screenshot to a claim, given that it may show other transactions?
