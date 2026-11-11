# An agent role that writes only within set limits

Milestone **The assistant** (`assistant`), due 30 November 2027. Issue `agent-limits` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). It should be built in the first half of
2027, after [audit-screen](audit-screen.md) and [mcp-read](mcp-read.md), because every assistant
that writes depends on it.

## Why it matters

An assistant that records rent saves time only if the landlord can trust it not to record the
wrong amount, against the wrong tenant, or more than they meant. Limits the landlord sets (which
tenancies, the largest amount, a monthly total and an end date), enforced by the database and not
by the assistant's good behaviour, make that trust reasonable. Each write still waits for the
landlord's tap unless they decide otherwise, and voids, waivers, deletions and team changes are
never open to an assistant.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries.

- **Four member roles:** owner, manager (the caretaker), accountant and viewer
  ([identity migration](../../supabase/migrations/20261103192722_identity_portfolios.sql)).
- **Writes are checked in the database.** Payments, memberships and invitations are written only
  through `SECURITY DEFINER` RPCs that check the caller's role; the 21 are pinned by a pgTAP
  allowlist ([`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql);
  D-15 in [PROJECT.md](../../.planning/PROJECT.md)). Locks follow one order: account, portfolio,
  lease, then other rows ([permissions.md](../architecture/permissions.md)).
- **`record_payment`** is idempotent per key, fingerprints the request, takes the lease lock,
  allows owners, managers and accountants, and is limited to 60 calls a minute
  ([ledger_findings.sql](../../supabase/migrations/20261107181820_ledger_findings.sql)).
- **The audit trail names only the person** (`actor_id`), with nothing to mark a write made
  through an assistant ([notifications_audit.sql](../../supabase/migrations/20261103194402_notifications_audit.sql)).
  [audit-screen](audit-screen.md) plans `source`, `via_client_id` and `mandate_id` columns.
- **[mcp-read](mcp-read.md) plans `agent_grants`** (portfolio, granting person, `client_id`,
  allowed tools, expiry, revocation) and makes every write refuse a token that carries a
  `client_id`. Until this item ships, assistants can only read.
- **Supabase OAuth access tokens are ordinary user JWTs carrying `client_id`**, readable in RLS
  and functions through `auth.jwt()` _(summary)_
  ([Supabase](https://supabase.com/docs/guides/auth/oauth-server/token-security)).
- **The deck promises** "the model drafts, a person confirms, and the database decides what is
  allowed" ([agents slide](../../website/deck/slides/agents.html)), with limits borrowed from AP2
  and every agent write above a set amount waiting for the landlord's tap
  ([agentsafe slide](../../website/deck/slides/agentsafe.html)).
- **Formal models** of ledger payments and rate limits exist in TLA+, and Z3 checks for overflow
  in `numeric(14,2)` ([formal/README.md](../../formal/README.md)).
- **Agent payment protocols are early** and none operates in Pakistan: AP2 has been a pre-1.0
  FIDO Alliance work item since April 2026 _(summary)_
  ([FIDO Alliance](https://fidoalliance.org/building-the-trust-layer-for-agentic-payments-with-ap2-and-verifiable-intent/)),
  and x402 has small real volume _(summary)_
  ([Decrypt](https://decrypt.co/382551/what-is-x402-how-ai-agents-pay-with-crypto)).
- **Practitioners agree** that per-transaction caps, rolling caps, allow-lists and expiry belong
  in a gate the agent must pass, not in its prompt _(summary, vendor sources)_
  ([Meow](https://www.meow.com/blog/spend-controls-ai-agents-caps-mcc-locks-approval-ladders)).

## Design

**An agent is a delegate, not a member.** No fifth `member_role`: it would be an identity with no
person behind it, and every consumer of the enum (the app's role enum, cash positions,
notification fan-out) would change. An assistant is an OAuth client acting for one human member.
Its rights are that member's role intersected with a mandate. Munshi on WhatsApp is registered as
a first-party client in the same way ([whatsapp-assistant](whatsapp-assistant.md)).

**Mandates.** `agent_mandates` holds the write limits of one grant in `agent_grants`:

- the grant, and so the portfolio, the person and the `client_id`;
- allowed actions, from `draft_payment` and `draft_reminder`;
- the leases it covers (none listed means every lease the person may manage);
- `max_amount`, `monthly_budget` and `confirm_above`, each `numeric(14,2)`;
- `valid_from`, a required `expires_at` no later than a cap the owner sets, and revocation;
- who approved it.

A grant without a mandate is read-only, which is the default. Whichever of this item and
[mcp-read](mcp-read.md) ships first creates `agent_grants`.

**Drafts, then a person's tap.** An agent's write is a draft: a payment becomes a
`payment_drafts` row ([draft-payments](draft-payments.md)) that names the mandate; a reminder
becomes a `pending_actions` row. The person confirms in the app or with a button on WhatsApp, and
confirmation calls `record_payment` with the draft's idempotency key. Only when the owner sets
`confirm_above` may an amount at or below it be recorded without the tap. That is off by default.

**One check wherever an agent may write.** `app.assert_agent_mandate(action, lease, amount)`
runs in the draft RPCs whenever `auth.jwt() ->> 'client_id'` is present, in `record_payment` when
an agent calls it under `confirm_above`, and again when any draft that names a mandate is
confirmed, whoever confirms it. Revoking a mandate discards its open drafts. The check:

- locks the mandate row last, after account, portfolio and lease, keeping the lock order;
- sums month-to-date use from the ledger: non-voided payments carrying the mandate's ID, recorded
  in the current Pakistan calendar month (a nullable `payments.mandate_id`, set from a
  transaction-local setting);
- raises distinct errors: `mandate_missing`, `mandate_expired`, `mandate_revoked`,
  `action_not_allowed`, `lease_not_allowed`, `over_max_amount` and `over_budget`.

**Never for an agent.** Every other definer RPC (`void_payment`, `waive_charge`,
`delete_portfolio`, `remove_member`, `create_invitation` and the rest of the 21) and every direct
table write refuse a token with a `client_id`, whatever the mandate. The allowlist test is split
into "an agent may call" and "an agent never calls", so a new definer RPC must say which it is.

**Who may grant.** Owners create mandates. A manager's mandate for their own assistant needs an
owner's approval. Renewal after expiry is a new approval.

**Formal.** The TLA+ payment model gains an agent that retries, reorders and duplicates calls,
with three invariants: month-to-date agent total within the budget, no forbidden action by an
agent, and nothing committed under a revoked mandate. Z3 shows that the month-to-date sum and the
comparison cannot overflow `numeric(14,2)`.

### Residence (decision 1)

A caretaker's write mandate needs the owner's approval. On a portfolio marked `owner_abroad`, the
owner gets a digest of writes made through assistants and by the caretaker, at their own local
time. The budget month stays the Pakistan calendar month whoever looks at it. Expiry is stored as
a timestamp and shown in the viewer's time zone, with Pakistan time beside it for an owner
abroad.

### Consent and analytics (decision 3)

Creating a mandate records consent in the same shape as `consents`: who, what, the text version,
when and how. The screen names the assistant and its vendor and lists what it may do, as Apple's
guideline 5.1.2(i) requires for data shared with third-party AI
([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). Analytics
never record prompts, tool output, amounts or leases; counts of mandates come from server
aggregates.

## Work

1. **M:** migration: `agent_mandates`, `pending_actions`, `payments.mandate_id`,
   `assert_agent_mandate`, RLS; pgTAP for each error path and for the lock order.
2. **M:** the check wired into the draft RPCs and `record_payment`; the allowlist split; pgTAP
   proving every other RPC and direct table write refuses agents with any mandate.
3. **S:** a concurrency scenario in [`concurrency_test.sh`](../../tool/db/concurrency_test.sh):
   parallel agent confirmations never exceed the budget.
4. **M:** mandate screens per portfolio and person (create, review, approve, revoke) in both
   languages, with goldens.
5. **S:** pending-actions inbox: drafts waiting for a tap, confirmed through `record_payment`.
6. **S:** owner notifications and the owner-abroad digest of assistant writes.
7. **M:** TLA+ agent and invariants in the payment model.
8. **S:** Z3 bounds for the budget sum.
9. **S:** decision entry (a delegate, not a fifth role) and the agent section in
   [`permissions.md`](../architecture/permissions.md).

## Depends on / Unblocks

- **Depends on:** [audit-screen](audit-screen.md) (attribution columns), [mcp-read](mcp-read.md)
  (client identity and `agent_grants`), [amount-parser](amount-parser.md) (amounts in drafts) and
  [draft-payments](draft-payments.md) (the drafts table).
- **Unblocks:** [whatsapp-assistant](whatsapp-assistant.md),
  [overseas-oversight](overseas-oversight.md) and [agent-coordination](agent-coordination.md).
  Related: [push-notifications](push-notifications.md) (drafts waiting for a tap).

## Risks

- **A caretaker grants more than the owner would.** Mitigation: the owner approves every
  caretaker mandate.
- **Two agent writes race the budget.** Mitigation: the mandate lock and the ledger sum in one
  transaction; the concurrency scenario and the TLA+ invariant.
- **An injected SMS or voice note aims a payment at the wrong lease.** Mitigation: lease limits,
  the read-back on the draft, and the tap.
- **A new write RPC forgets the check.** Mitigation: the split allowlist fails until the RPC is
  classified.
- **A slower write path.** Mitigation: the check returns at once when there is no `client_id`;
  measure as the existing helpers are measured in [`permissions.md`](../architecture/permissions.md).

## Done when

- [ ] With no mandate, an agent token can call no write function (pgTAP).
- [ ] Each limit (lease, largest amount, monthly budget, expiry, revocation) has a passing and a
      failing test.
- [ ] Void, waive, delete and team functions always refuse an agent.
- [ ] Parallel agent confirmations never exceed the monthly budget, in the concurrency scenario
      and in TLA+.
- [ ] Revoking a mandate discards its open drafts, and none of them can be confirmed.
- [ ] Every agent write shows on the audit screen as "via the assistant, for the person".

## Questions for the owner

1. Do voided payments return their amount to the budget?
2. The longest mandate: 30 or 90 days?
3. May caretakers hold write mandates at all, even with approval?
4. Should recording without a tap below a set amount ever be offered?
