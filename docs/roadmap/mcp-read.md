# A read-only MCP server, so a landlord's own AI can read their ledger

Milestone **Launch and listen** (`launch`), due 28 February 2027. Issue `mcp-read` in
[`.github/roadmap.toml`](../../.github/roadmap.toml). It may move to **The assistant** (due 30
November 2027) if Supabase's OAuth server is not ready; it should not hold the launch.

Part of the [roadmap](README.md). "Decision 1", "decision 2" and "decision 3" below are the
owner's decisions of 11 November 2026, and the index describes each one and its foundation work:
[residence](README.md#decision-1-residence-per-person-and-per-portfolio-d-16),
[letterheads](README.md#decision-2-letterheads-on-every-generated-document-d-17) and
[privacy-first analytics, support and e-mail](README.md#decision-3-privacy-first-analytics-support-and-e-mail-d-18).

## Why it matters

Many landlords already ask a general AI assistant for help. With this server they can ask it
"who still owes rent this month?" and get the answer from their own ledger, without copying
figures by hand. The assistant can only read, only the portfolios the landlord chose, and only
until the landlord revokes it. The grants built here are also the base on which assistants that
write will later rest.

## What is true now

Checked on 11 November 2026. External facts marked _(summary)_ were read only through
search-engine summaries; the MCP release post was read in full.

- **The MCP revision is 2026-07-28.** It is stateless over Streamable HTTP, prefers Client ID
  Metadata Documents (CIMD), formally deprecates Dynamic Client Registration (DCR) while keeping
  it working, and requires clients to validate `iss`
  ([MCP blog](https://blog.modelcontextprotocol.io/posts/2026-07-28/)).
- **Servers must publish Protected Resource Metadata**, answer 401 with a pointer to it, and
  check that a token was issued for them _(summary)_
  ([MCP authorisation](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization)).
- **Tool annotations such as `readOnlyHint` are hints, not enforcement** _(summary)_
  ([MCP blog](https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/)).
- **Clients:** the Claude apps support DCR and CIMD _(summary)_
  ([Claude connectors](https://claude.com/docs/connectors/building/authentication)); ChatGPT
  connects remote servers in developer mode _(summary)_
  ([OpenAI](https://developers.openai.com/api/docs/guides/developer-mode)).
- **Supabase** documents MCP servers on Edge Functions _(summary)_
  ([Supabase](https://supabase.com/docs/guides/ai-tools/byo-mcp)). Its OAuth 2.1 server has been
  in public beta since 26 November 2025, with no general release found _(summary)_
  ([Supabase OAuth](https://supabase.com/docs/guides/auth/oauth-server),
  [changelog](https://supabase.com/changelog/38022-oauth-2-1-server-capabilities-for-supabase-auth)).
  Its access tokens are ordinary Supabase JWTs that carry `client_id`, which RLS can read;
  scope-aware RLS is only "under consideration" _(summary)_
  ([token security](https://supabase.com/docs/guides/auth/oauth-server/token-security)).
- **Read RPCs exist and run as the caller:** `get_receivables`, `get_dashboard`,
  `get_tax_year_statement` and `get_cash_positions` are `SECURITY INVOKER`
  ([reports migration](../../supabase/migrations/20261103194625_reports.sql)).
  `get_receivables` returns the tenant's phone number.
- **The tenant statement is built in the app** from paged reads, not by an RPC
  ([ledger_repository.dart](../../app/lib/src/features/ledger/data/ledger_repository.dart)).
- **Edge Functions accept only user tokens with audience `authenticated`**, and auth modes
  `user`, `secret` and `none` ([handler.ts](../../supabase/functions/_shared/handler.ts)). There
  are no OAuth client, token or grant tables.
- **Apple** requires apps to disclose, and get explicit permission for, personal data shared
  with third-party AI (guideline 5.1.2(i),
  [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).

## Design

**Server.** One `mcp` Edge Function, built with Hono and the MCP TypeScript SDK (or `mcp-lite`
if the SDK lags on Deno). Supabase Auth is the authorisation server, with PKCE and short-lived
tokens. The function serves the Protected Resource Metadata and validates each token's issuer,
expiry, audience and `client_id`. Clients register by DCR now and by CIMD once Supabase supports
it. The user's token is never passed on to any other service.

**Grants in our own tables.** `agent_grants` (portfolio, granting user, `client_id`, allowed
tools, expiry, revocation), shared with [agent-limits](agent-limits.md) and built once, here.
When a token carries a `client_id`, `app.agent_portfolio_ids()` returns the user's role-based
portfolios that also have a live grant for that client, and the RLS helpers use it. Tenant
identity data, documents and storage stay readable only by direct sessions (`client_id is
null`).

**Read-only by construction, not by annotation.** Because an OAuth token is an ordinary user JWT,
an AI client could call the Data API directly. So the client-write lock helper and every definer
write RPC refuse a token that carries a `client_id`, and pgTAP proves it for every RPC pinned in
[`01_schema_security.test.sql`](../../supabase/tests/database/01_schema_security.test.sql) and for
direct table writes.

**Four tools:** `list_portfolios`; `who_owes` (portfolio, as-of date); `tenant_statement`
(lease, period); `overdue_list` (portfolio, minimum days overdue). Each is a `STABLE` SQL function
run in a read-only transaction, annotated `readOnlyHint: true` and given an output schema. A new
`get_lease_statement` RPC serves `tenant_statement`, and the app switches to it.

**Minimised output.** Amounts as exact paisa plus formatted text. Never a CNIC, phone number or
storage URL; `who_owes` drops the phone that `get_receivables` returns.

**Untrusted text.** Names and notes are typed by tenants and caretakers, who could plant
instructions for the landlord's AI. They are returned in fields marked as untrusted data, passed
through the clean-text rules and capped in length.

**Logging and limits.** Every call is written to `agent_access_log` (user, client, tool,
portfolio, row count, time) and shown on the [audit-screen](audit-screen.md). Calls are rate
limited per client through `admin_rate_limit_hit`.

**Release.** Behind a flag, after the pilot.

### Residence (decision 1)

A caretaker can grant only portfolios they manage, if caretakers may connect at all. The owner
sees, and can revoke, every grant on their portfolio, whoever made it. Grant expiry is shown in
the viewer's own time zone.

### Consent and analytics (decision 3)

The grant screen says plainly that tenant data will go to the AI vendor the landlord chose, and
records the grant with its consent text version, as Apple's guideline 5.1.2(i) requires.
Nothing a tool returns is sent to analytics.

## Work

1. **S:** spike on the local stack: does Supabase OAuth honour `resource` and set `aud`; CIMD
   status; Deno SDK support for 2026-07-28.
2. **Owner:** turn on asymmetric JWT signing keys and the OAuth server on the hosted project.
3. **M:** migration: `agent_grants`, `agent_access_log`, `app.agent_portfolio_ids()`, write
   refusal for `client_id` tokens, RLS matrix rows (a token for portfolio A cannot read B;
   expired or revoked grants read nothing).
4. **M:** read-only SQL functions for the four tools and `get_lease_statement`, checked against
   the ledger contract vectors; the app switches to `get_lease_statement`.
5. **M:** `mcp` function transport: metadata endpoint, token validation, grant lookup on every
   call, rate limit.
6. **M:** the four tools with output schemas, annotations and minimised output; Deno tests at
   100%.
7. **M:** "Connected assistants" screens to grant, list and revoke, in both languages.
8. **S:** interoperability runs (MCP Inspector, Claude, ChatGPT); threat model with planted
   instructions in tenant notes; a runbook entry in [`operations.md`](../operations.md).

## Depends on / Unblocks

- **Depends on:** [audit-screen](audit-screen.md), [legal-review](legal-review.md) (the privacy
  notice names AI vendors as recipients chosen by the landlord), the consent records of decision
  3, and Supabase's OAuth server on the hosted project.
- **Unblocks:** [agent-limits](agent-limits.md), which reuses `agent_grants`. Related:
  [whatsapp-assistant](whatsapp-assistant.md) and
  [agent-coordination](agent-coordination.md).

## Risks

- **A token minted for another client is replayed** if `aud` is not bound. Mitigation: check
  `client_id` against `agent_grants` on every call.
- **The beta OAuth server changes or stalls.** Mitigation: ship behind a flag; let the item slip
  to the assistant milestone.
- **Tenant data leaves Pakistan** for the AI vendor. Mitigation: explicit consent, minimised
  output, a line in the privacy notice.
- **Other tools in the landlord's AI client exfiltrate what these tools return.** Mitigation:
  return the least that answers the question; no identifiers.
- **Narrowing the RLS helper slows every read.** Mitigation: measure it as the existing helper
  costs are measured in [`permissions.md`](../architecture/permissions.md).
- **Chatty agents add load.** Mitigation: per-client rate limits and output caps.

## Done when

- [ ] Two AI assistant apps from different vendors connect with OAuth and PKCE and call all four
      tools.
- [ ] A request without a token gets a 401 that points to the metadata.
- [ ] pgTAP proves isolation between portfolios, revocation and expiry.
- [ ] A `client_id` token cannot write through any RPC or table, and every tool runs read-only.
- [ ] No tool output contains a CNIC, phone number or URL, checked over fixtures.
- [ ] Every call appears in `agent_access_log` and on the audit screen.

## Questions for the owner

1. Free or a paid-plan feature?
2. Full tenant names in tool output, or unit labels only?
3. May caretakers connect their own AI?
4. Default grant expiry: 30 or 90 days?
5. A listing in the Claude or ChatGPT directories, or custom connectors only?
