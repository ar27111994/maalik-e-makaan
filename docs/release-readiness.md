# Release readiness: v1.0

The release-readiness audit of milestone v1.0 (Phase 12), after its engineering issues and the
UAT defects were fixed. Every result below comes from a command run on 2026-11-08 in the agent
container, on branch `claude/exciting-cray-2wue0f` (working tree on top of `e853378`), unless it
says otherwise. The one hosted change, the new migration, was applied on 2026-11-09 (owner
action 1).

## Verdict

**Engineering: ready for a release candidate** (pushed; CI green on `a7f5c1a`).
**Launch: not ready.** What is left is the owner's: the backup key, merging to `main`, e-mail,
monitoring, the first Deploy and the reviews listed in [Owner actions](#owner-actions).

- The blocker is fixed. The Supabase CLI now applies the whole chain from the repository's own
  `supabase/` directory: `supabase db reset` applied all 23 migrations and the seed, and the
  `supabase-stack` steps and the browser UAT pass locally.
- All eight UAT defects are fixed. Each now has a test that fails on the old code, and the UAT
  journey that found it asserts the fix.
- The other engineering findings are fixed or documented: the rollback and restore runbook (with
  a rehearsal), monitoring, releasing, the stale docs, CI log steps, the release version and the
  privacy disclosure. One finding was partly wrong, and the evidence is below.
- CI on GitHub: run 34 on `a7f5c1a` passed every job, `supabase-stack` and `uat` included,
  and "CI passed"; the Security run passed too.
- Not verified here: the Deploy workflow (it targets production), iOS builds and real phones.

> **Database change for the coordinator.** One new migration,
> `supabase/migrations/20261109081109_uat_display_fixes.sql` (D5 and D6), must be applied to the
> hosted project by the process in `docs/operations.md`, After every migration. It was applied on
> 2026-11-09 as version 20261109081109; the fingerprints match (1,185 objects, `fa5a29f9…`).
> One applied migration, `20261108200216_identity_checks.sql`, was edited (wrapped in
> `begin; … commit;`, D1). The schema it builds is identical, and the hosted project will not
> apply it again (see D1).

## Checklist

| #   | Check                                                      | Status | Evidence                                                                                                                                                  |
| --- | ---------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | The migration chain applies with the Supabase CLI          | Pass   | `UAT_RESET=1 make test-uat`: "Applying migration 20261108200216_identity_checks.sql… 20261109081109_uat_display_fixes.sql… Seeding data… Finished"        |
| 2   | Migration lint catches what the CLI cannot apply           | Pass   | `make lint`: "migration transactions: 23 files checked", squawk "Found 0 issues in 7 files"; the unwrapped D1 file is refused in a unit test              |
| 3   | pgTAP on PostgreSQL 16 (`make test-db`)                    | Pass   | "Files=21, Tests=912 … Result: PASS"; upgrade checks of 20261108082804, 20261108200216 (with refusal and race) and 20261109081109 "ok"                    |
| 4   | pgTAP on the real stack (`supabase test db`)               | Pass   | After `supabase db reset`: "Files=21, Tests=912 … Result: PASS"                                                                                           |
| 5   | plpgsql_check (`supabase db lint --level error`)           | Pass   | `{"results":[],"message":"db lint"}`                                                                                                                      |
| 6   | Concurrency scenarios (`make test-db-concurrency`)         | Pass   | "✓ concurrency invariants hold" (76 payments, 0 receipt gaps, cash in = cash accounted 153,659.30)                                                        |
| 7   | Edge Functions (`make test-functions`, e2e)                | Pass   | 100% lines (1536/1536), branches (702/702), functions (130/130); e2e "4 passed, 0 failed"                                                                 |
| 8   | App tests (`make test-app`)                                | Pass   | "+1743: All tests passed!"; "Line coverage: 18089/18341 = 98.63% (minimum 90.0%)"                                                                         |
| 9   | Design system, gallery, core, format, analyze, website     | Pass   | `mm_ui` 2,628 tests at 100%; `mm_core` 354 at 100%; gallery 84; analyze clean; website 480 unit, 685 e2e, Lighthouse budgets met ([Gates](#gates))        |
| 10  | Browser UAT (`make test-uat`)                              | Pass   | 14 of 14 journeys pass, each asserting its defect's fix: "14 passed (59.7s)"; the whole run took 3 min 9 s with reset and build                           |
| 11  | Rollback and restore documented and rehearsed              | Pass   | `docs/operations.md`, Rollback and restore; [rehearsal](#rollback-and-restore-rehearsal): schemas match (1185 objects), row counts equal                  |
| 12  | Monitoring and alerting documented                         | Pass   | `docs/operations.md`, Monitoring and alerts (uptime monitor on deep health, daily SQL check)                                                              |
| 13  | Release mechanics: first release is v1.0.0, and it deploys | Pass   | `release-please-config.json` `"release-as": "1.0.0"`, `website/package.json` tracked; Release calls Deploy (`actionlint` clean)                           |
| 14  | Docs discoverable and current                              | Pass   | `docs/uat.md` and this file linked from README, `docs/README.md`, `llms.txt`, `AGENTS.md`, `docs/agents/commands.md`; REQUIREMENTS, STATE, NFR-07 updated |
| 15  | CI green on the pushed branch                              | Open   | The last pushed run, 42518890202, failed only "Supabase stack" and "CI passed" (D1). These changes are not pushed yet                                     |
| 16  | `main` protected, tag and changelog                        | Open   | `gh api …/branches/main/protection`: "Branch not protected"; `git tag --list` is empty; no `CHANGELOG.md` (owner actions 2 and 9)                         |
| 17  | Production deploy run once                                 | Open   | Deploy has never run (owner action 8)                                                                                                                     |
| 18  | Owner-only prerequisites                                   | Open   | [Owner actions](#owner-actions)                                                                                                                           |

## Engineering issues

### Blocker: a migration the CLI cannot apply (D1)

- **Verified.** Run 42518890202 shows that only "Supabase stack" failed, and "CI passed" with it.
  Locally, a probe migration with `create table …; lock table … in share row exclusive mode;`
  run with `supabase migration up --local` fails with "LOCK TABLE can only be used in transaction
  blocks (SQLSTATE 25P01)", and the table it created is rolled back.
- **Partly wrong.** The audit said the `set local` timeouts of five migrations "silently do
  nothing under the CLI". They do work. A probe `set local lock_timeout = '5s'; create table
public.mm_probe as select current_setting('lock_timeout')` applied by the CLI stored `5s`. The
  CLI sends a file as one pipelined batch: one implicit transaction, atomic, in which `SET LOCAL`
  holds. That transaction is not a _block_, though, so `LOCK TABLE` and savepoints fail. The
  earlier check used psql in autocommit mode, which is not what the CLI does. The five files are
  unchanged.
- **Fix.** `20261108200216_identity_checks.sql` is wrapped in `begin; … commit;` (with
  `squawk-ignore transaction-nesting` and the reason).
  - **Schema unchanged.** Two databases built with the old and the new file have byte-identical
    fingerprints (md5 `301c7be3…` both, 1,185 objects).
  - **Hosted project.** With the edited file, `supabase db push --local --dry-run` against a
    history that already records the version says `"upToDate":true`: the CLI compares versions,
    not contents. So the hosted project, which records 20261108200216, will not apply the file
    again.
  - **Comments.** The note in `docs/operations.md`, Phone and CNIC checks, records this.
- **Local harness.** The audit asked for `tool/db/reset.sh` to drop `--single-transaction` "as
  the CLI does". It now keeps one transaction per file, because the CLI's implicit transaction is
  atomic too (dropping it would make `SET LOCAL` a no-op and the upgrade refusal checks
  non-atomic). Its wrong comment is corrected. The shared helper `migration_tx_flag` in
  `tool/db/env.sh` runs a file that opens its own transaction without psql's, so the two do not
  nest. `upgrade_test.sh` uses the same helper.
- **Test.** `tool/db/check_migration_transactions.py`, in `make lint` through
  `tool/db/lint_migrations.sh`, splits each migration into top-level statements (skipping
  comments, strings and dollar-quoted bodies). It refuses `LOCK TABLE`, `SAVEPOINT`, `RELEASE`
  and `ROLLBACK TO` outside an explicit `begin; … commit;`, and an unbalanced or nested
  transaction. Its 11 unit tests (`make test-tools`, now covering `tool/db`) include the D1 file
  without its wrap, which the check refuses.
- **CI.** The `supabase-stack` and `uat` jobs are expected to pass once pushed, because their
  commands pass locally with the same CLI version: `supabase start`/`db reset`, `db lint`,
  `test db`, `test-functions-e2e` and `test-uat`.

### High: no rollback or restore procedure

- **Verified.** `docs/operations.md` had no section on backups, restore or rollback.
- **Fixed.** `docs/operations.md` now has three new sections:
  - **Rollback and restore:**
    - the forward-fix policy for migrations;
    - Vercel promote or rollback for the app and the site;
    - redeploying the functions from the previous tag with Deploy run by hand;
    - backups on the free plan: a weekly encrypted data dump, with Supabase's own advice and
      the warning that Storage is not in it;
    - a restore procedure into a new project.
  - **Releasing**, and **Monitoring and alerts**.
- **Rehearsed** (below). The rehearsal changed the procedure: Supabase's generic
  "roles, schema, data" restore is unsafe for this project.

### Rollback and restore rehearsal

On the local stack (CLI 2.122.1, Postgres 17.11), from a database holding the seed and the
data left by a UAT run:

1. Counts were recorded: 4 users, 1 portfolio, 3 properties, 7 units, 5 tenants, 5 leases,
   41 charges, 34 payments, `sum(outstanding)` 440,000, 23 migrations, 3 cron jobs. The schema
   fingerprint was taken too.
2. The data was dumped with `supabase db dump` (roles, schema, data, history) as Supabase
   documents.
3. **Supabase's recipe**: a database reset with no migrations (an empty new project), then
   `psql --single-transaction … roles.sql schema.sql` with `session_replication_role = replica`
   and `data.sql`. It loaded without error and the row counts were equal, but
   `fingerprint_diff.py` showed:
   - five objects missing: the three policies on `storage.objects`, the trigger on `auth.users`
     and the trigger on `storage.objects`;
   - no cron jobs (0 instead of 3);
   - 73 definitions changed:
     - in 8 CHECK constraints only the parentheses differ;
     - 65 functions were executable by `anon` and `service_role`, where the chain grants only
       `authenticated` (for example `create_portfolio`: `anon=EXECUTE,authenticated=EXECUTE,service_role=EXECUTE`
       instead of `authenticated=EXECUTE`).

   **Unsafe:** it widens the API surface (decision D-15).

4. **The procedure now in the runbook**: the chain applied by the CLI (`supabase db reset
--no-seed` on a copy of `supabase/migrations`), then the data only, with
   `session_replication_role = replica`. The `storage.buckets` row the chain creates was left out
   of the data; the first try failed on its duplicate key. The load succeeded (exit 0). The row
   counts equal the originals line for line, including 3 cron jobs and 23 migrations, and
   `fingerprint_diff.py` says "schemas match (1185 objects)".
5. Afterwards `supabase db reset` restored the chain for the remaining gates.

Still to rehearse (owner action 5): the same on a scratch hosted project, with the dump taken
from the hosted one.

### Medium: dashboard "Collected this month" (D2)

- **Verified.** On the UAT day the tile read "Rs 0" although Rs 120,000 came in: it shows
  `month.paid` (this month's dues paid), and `cash_received` was read but never shown.
- **Fix.** The tile is now "This month's dues paid" (its caption still "of Rs 52,000 due, 0%
  collected"). A new tile, "Received this month", shows `cash_received` with the caption "Every
  payment recorded this month, for any month's dues". Both are in English and Urdu.
- **Tests.**
  - The widget test "money received this month is shown apart from dues paid" feeds a month with
    Rs 120,000 received and nothing of the month's Rs 52,000 paid.
  - UAT J9 compares "Received this month 120000 rupees" with `sum(payments.amount)` for the month.
  - The dashboard and shell goldens (6 variants each, and the wide shell) were re-recorded on
    Linux and reviewed.

### Medium: accessibility (D3, D7)

- **D3, verified and fixed.** The invitation link (`invite_member_screen.dart`) is now a semantics
  container labelled "Invitation link" whose value is the URL, read left to right. The
  `SelectableText` stays for sighted users and is excluded from semantics.
  - **Widget test:** the node's label, value and direction, and that the value equals the copied
    link.
  - **UAT J7:** it finds `Invitation link <url>` by its accessible name on the web.
- **D7, verified, with the root cause found.** Flutter 3.47's web engine renders an adjustable node
  as `<input type="range">`. It leaves the value out of the node's name (`_computeLabel` skips
  the value when `isIncrementable`) and means to set `aria-valuetext`. The UAT probe found
  neither `aria-valuetext` nor `aria-valuenow` on either stepper, so a screen reader heard
  "Grace days, slider".
- **D7 fix.** In `mm_ui`'s `MmStepperField`, on the web only (`nameCarriesValue = kIsWeb`, overridable
  in tests), the name carries the value. The final UAT run read `"Grace days, 5 days"` and
  `"Increase every (months), 12 months"`. TalkBack and VoiceOver keep the name and the value
  apart.
  - **Test:** "on the web the name carries the value too" in `mm_ui`.
  - **UAT J4** asserts both names.

### Medium: docs discoverability and drift

- **Verified.** `docs/uat.md` and `make test-uat` were linked from nowhere else. REQUIREMENTS said
  "Nothing has had browser UAT", NFR-07 said there were no end-to-end tests, and STATE said
  `supabase start` only runs in CI.
- **Partly wrong.** "docs/uat.md says the uat job follows supabase-stack": the file did not say
  so; its one mention of `supabase-stack` is about the services it switches off. It now says
  that the job runs alongside `supabase-stack` with no `needs:`, so a failing database suite does
  not hide the journeys.
- **Fixed.**
  - **Links:** `docs/uat.md` and this report are linked from README (Status, the per-area table,
    Quality gates), `docs/README.md` (Quality), `llms.txt`, `AGENTS.md`,
    `docs/agents/commands.md` (gates, tests, CI jobs) and `app/AGENTS.md` (Known gaps).
  - **REQUIREMENTS** has a new status paragraph. NFR-07 stays ◐: the UAT is done, but the
    operations, reports and search screens and the native integration tests are not covered.
  - **STATE** has its environment notes corrected, the migration to apply and the new follow-ups.
  - **README:**
    - the "audit trail" bullet now says the changes are recorded in the database's audit log
      and that a screen to read it is still to come (TEAM-05 ◐);
    - the pgTAP count is now 21 suites, 912 tests.

### Low: D4, D5, D6, D8

- **D4: Team screen stale.**
  - **Verified:** the More branch keeps the screen alive offstage.
  - **Fix:** a new `RefreshWhenShown` (`app/lib/src/shell/`) reloads the team when the screen's
    `TickerMode` turns back on (another tab was shown, or a page covered it).
  - **Test:** a widget test hides the screen, changes the server's team, shows it again, and
    expects the accepted invitation gone and the member listed.
  - **UAT J12** now asserts the fresh list on return instead of recording the stale one.
- **D5: "Vacant since" was a UTC date.**
  - **Verified:** `u.created_at::date` in `public.unit_occupancy` and `get_dashboard`.
  - **Fix:** the new migration uses `(u.created_at at time zone 'Asia/Karachi')::date` in both
    current definitions (copied from their latest migrations, nothing else changed).
  - **Test:** pgTAP suite 21. A unit created 20:30 UTC on 8 Nov is vacant since 9 Nov with 0
    vacant days; 23:30 UTC on 9 Nov gives 10 Nov.
  - **UAT J2** asserts "Vacant since" with today's date.
- **D6: English "Late fee" note.**
  - **Verified:** `private.assess_late_fees` wrote `'Late fee'`.
  - **Fix:** the same migration writes no note. It also clears the literal from automatic fees
    that are not voided, keeping voided rows, notes members changed and manual charges.
  - **Tests:**
    - pgTAP suite 21: 7 of its 8 assertions fail on the pre-fix schema;
    - an upgrade check, `tool/db/upgrade/20261109081109.*`, covers the five cases;
    - UAT J6 checks the database and the screen.
- **D8: Urdu receipt on two pages.**
  - **Verified:** the receipt from the UAT (two dues and a reference) was 2 A5 pages in Urdu.
  - **Fix:** the receipt PDF now has:
    - a vertical margin of 20 pt (was 32);
    - gaps of 8 pt (were 12);
    - the footer and "Made with …" lines as one paragraph.
  - **Measured:** the usual Urdu receipt now has 44 pt to spare, and one with three dues 16 pt.
  - **Test:** "a usual receipt is one A5 page in Urdu too" (2 and 3 dues, both languages).
  - **UAT J12** asserts one page.
  - **Still two pages:** a voided receipt with tax, a certificate and a note, which flows on
    rather than being cut off (STATE, Follow-ups).

### Low: CI hygiene

- **Verified.** When the stack fails to start, `docker logs "$(docker ps -q …)"` fails on an empty
  id, which hides the real error.
- **Fixed.** Both jobs look the container up with `docker ps -aq … | head -n 1`, print its logs
  when there is one, and otherwise say "No … container: the stack did not start". The snippet was
  run locally against a missing and an existing container (exit 0 both), and `actionlint` passes.

### Engineering parts of the owner-action issues

- **Release version.** `release-please-config.json` now has `"release-as": "1.0.0"`. It also bumps
  `website/package.json`; `npm ci --dry-run --offline` accepts a lockfile whose root version
  differs. The runbook says to remove `release-as` right after v1.0.0.
- **Deploy trigger.** Deploy is now a reusable workflow: Release calls it for the tag it created
  (job `deploy`, passing the three repository secrets explicitly), so the first release deploys
  even with the default `GITHUB_TOKEN`. The `release: published` trigger is removed, so that a
  token-created release does not deploy twice; Deploy still runs by hand. `RELEASE_PLEASE_TOKEN`
  is now "recommended", so that release pull requests run CI. `actionlint` passes. Not run: it
  needs `main`.
- **Observability.** `docs/operations.md`, Monitoring and alerts:
  - an external uptime monitor on `health?deep=1` with `HEALTH_CHECK_TOKEN`, and one on the web
    app;
  - a daily saved query listing failing leases, a missing daily run, stuck storage cleanups and
    failed pg_cron runs.
- **Privacy.** The privacy page (English and Urdu) now names Google Fonts (`fonts.gstatic.com`) as
  the source of fallback fonts for the web app, and says what Google receives. Self-hosting the
  fallback fonts was not done: the Noto set is large, and the engine's `fontFallbackBaseUrl`
  would need it all.

## Gates

Run on 2026-11-08 after the fixes. "Exit" is `make`'s exit status.

| Gate                                  | Exit | Tail                                                                                                                             |
| ------------------------------------- | ---- | -------------------------------------------------------------------------------------------------------------------------------- |
| `make format-check-repo`              | 0    | black, shfmt and Prettier clean                                                                                                  |
| `make lint`                           | 0    | "migration transactions: 23 files checked"; "Found 0 issues in 7 files"; markdownlint "0 issues"; "design-lint: 272 files clean" |
| `make test-tools`                     | 0    | six `unittest` runs "OK" (3, 9, 11, 13, 24 and 48 tests)                                                                         |
| `make test-db`                        | 0    | "Files=21, Tests=912 … Result: PASS"; upgrade, refusal and race checks ok                                                        |
| `make test-db-concurrency`            | 0    | "✓ concurrency invariants hold" (278 s)                                                                                          |
| `make test-functions`                 | 0    | 100.00% lines, branches and functions                                                                                            |
| `make test-app`                       | 0    | "+1743: All tests passed!"; 98.63% line coverage                                                                                 |
| `supabase db lint --level error`      | 0    | no results                                                                                                                       |
| `supabase test db` (after `db reset`) | 0    | "Files=21, Tests=912 … Result: PASS"                                                                                             |
| `make test-functions-e2e`             | 0    | "4 passed, 0 failed"                                                                                                             |
| `UAT_RESET=1 make test-uat`           | 0    | "14 passed (59.7s)"; 189 s with reset and build                                                                                  |
| `make format-check`                   | 0    | after `dart format` of one test file and Prettier on this file (the first runs failed on exactly those two)                      |
| `make analyze`                        | 0    | "No issues found!" for each package, the gallery and the functions                                                               |
| `make test-core`                      | 0    | "+354: All tests passed!"; 899/899 = 100.00%                                                                                     |
| `make test-ui`                        | 0    | "+2628: All tests passed!"; 6139/6139 = 100.00%                                                                                  |
| `make test-gallery`                   | 0    | "+84: All tests passed!"                                                                                                         |
| `make test-web`                       | 0    | unit "480 passed", e2e "685 passed (2.5m)", Lighthouse on 8 URLs, 24 runs, "All results processed!" (after one fix, below)       |
| `make verify` (formal, ci mode)       | 0    | "8/8 tracks as expected, 283s wall": the six TLA+ models, Lean ("7/7 steps") and Bend ("ALL PROOFS CHECK")                       |

`supabase test db` failed three assertions of suite 11 when run on the database the UAT had just
used ("nothing is queued while files are in use"). The account deletion in J14 leaves one
`portfolio_deleted` item in `private.storage_cleanup_queue`, which the local stack never drains
because it has no Vault secrets. After `supabase db reset` the suite passes; in CI each job has
its own fresh stack.

The first `make test-web` failed one unit test: the Urdu privacy page had the Latin
`fonts.gstatic.com` outside a link, which the site's rule against Latin letters in Urdu copy
refuses. The domain is now in a `<kbd lang="en" dir="ltr">`, as the rule allows, and the run
passed.

Not run here: iOS, Android on a phone, the Deploy workflow.

## Owner actions

Updated 2026-11-09 after the owner's answers: the repository secrets, variables and the
`release` and `production` environments exist (seen in the owner's screenshots), the operator's
name on the privacy page is right, the owner is a native Urdu speaker, and e-mail goes through
Resend's free plan. Done by the agent the same day: the migration applied (fingerprints equal,
1,185 objects), CI green, and the Backup workflow (the first backup taken and restored, below).

In order. Record each in `.planning/STATE.md` when it is done.

1. **Make the backup key** (`docs/operations.md`, Backups). Backups are encrypted only to the
   keys in `BACKUP_AGE_RECIPIENTS`, which is empty, so the Backup workflow refuses to run.
   1. `winget install FiloSottile.age`, then `age-keygen -o maalik-e-makaan-backup.key`.
   2. Keep the `.key` file in a password manager and one offline copy.
   3. Add the printed `age1...` line as the repository variable `BACKUP_AGE_RECIPIENTS`.
2. **Merge to `main` and protect it.**
   1. Open a pull request from `claude/exciting-cray-2wue0f` to `main` with a Conventional Commit
      title, wait for "CI passed", and squash-merge.
   2. Settings, Rules: protect `main`. Require a pull request and the status check "CI passed",
      block force pushes and deletion, no bypass. Allow squash merges only (Settings, General).
3. **`RELEASE_PLEASE_TOKEN`** (`docs/operations.md`, Releasing): a fine-grained token on this
   repository only, Contents and Pull requests "Read and write", saved as a repository secret.
   With `main` requiring "CI passed" and no bypass, treat it as required: without it the release
   pull request's checks run only if GitHub offers "Approve workflows to run" on it (a feature
   still rolling out), and otherwise never, so it could not be merged.
4. **Run Backup once** (Actions, Backup, Run workflow, `main`), then download the artefact and
   open it with your key (`docs/operations.md`, Backups, Opening a backup). This checks the key end
   to end; the agent's network could not download artefacts.
5. **E-mail** (`docs/operations.md`, E-mail). Already set on 2026-11-05: `RESEND_API_KEY` and
   `MAIL_FROM` for invitations, and Auth's Site URL and redirect. Still to do: make sure
   `MAIL_FROM`'s domain is verified in Resend (a `resend.dev` sender reaches only your own
   address); turn on custom SMTP in Supabase Auth with a second sending-only key for that domain;
   check the "Email sent" rate limit; paste the three bilingual templates from
   `supabase/templates/` with their subjects from `supabase/config.toml`. Then sign up in each
   language, reset a password and send an invitation to someone outside the team.
6. **Monitoring** (`docs/operations.md`, Monitoring and alerts): `HEALTH_CHECK_TOKEN` as an Edge
   Function secret (not a GitHub secret), checked with curl, and an uptime monitor whose free
   plan sends a custom header (Better Stack, or StatusCake), plus one on the web app. Save the
   daily SQL check in the dashboard's SQL editor.
7. **Run Deploy once by hand on `main`** (Actions, Deploy, Run workflow), approve `production`
   (check that the environment requires you as reviewer), and check the smoke tests, that
   `db push` finds nothing to apply, and that you can sign in. This also redeploys the functions
   with `admin_rate_limit_hit` (STATE, Blockers).
8. **Cut v1.0.0.** Merge the release pull request (`chore(release): release 1.0.0`), approve the
   Deploy it calls, check the release carries the AAB, the APKs, the web zip and `SHA256SUMS`,
   then commit the removal of `"release-as": "1.0.0"` from `release-please-config.json`.
9. **Google Play**, when the D-U-N-S number arrives: upload the AAB, add the Play app-signing
   key's SHA-256 to `app/web/.well-known/assetlinks.json` beside the upload key's, redeploy, check
   with the Digital Asset Links API, and link the listing from the website.
10. **Urdu review** by the owner: `app/lib/l10n/arb/app_ur.arb`, the website's Urdu pages, the
    three e-mail templates, and the privacy page's new paragraphs (account e-mails through Resend,
    weekly encrypted backups kept 90 days).
11. **Legal**: a lawyer's review of the privacy policy and terms; a contact e-mail address for the
    privacy page (it says there is none yet); a check of the official `.gov.pk` texts behind the
    guides.
12. **After the first deploy**, re-run the gates (CI on `main`, the Deploy smoke tests, the first
    scheduled Backup run, the daily check) and update this file's verdict.

Optional hardening: move the `ANDROID_*` secrets into the `release` environment and limit that
environment to tags `v*`; only the Release workflow reads them. Keep the Supabase and Vercel
secrets at repository level: the weekly Backup reads them without an environment, so it needs no
approval.

### The first backup and restore (2026-11-09)

- The live database had no users and no records; the dump held 11 operational rows in 64 tables,
  and the `documents` bucket was empty.
- Run 42592961582 (Backup, from this branch with a temporary trigger) dumped it, rebuilt the
  schema from the chain on a local stack, restored the dump with triggers off, and checked:
  "schemas match (1185 objects)" against the hosted fingerprint, and "data match: 64 tables, 11
  rows" against a fresh dump. After an independent review, the revised workflow (errors kept off
  the log, unchecked backups kept, unapplied migrations left out of the check) ran again as run
  42598388632 with the same result and "Restore checked: true". Both artefacts were encrypted to
  throwaway keys, shredded afterwards, so neither can be opened; the first real backup is owner
  action 4.
- The rehearsal is local, not a hosted scratch project: the repository's `SUPABASE_ACCESS_TOKEN`
  is scoped and refused to create a project ("Forbidden"), which is the safer setting. The one
  hosted-only question, whether `postgres` may set `session_replication_role = replica` for the
  load, was checked on the hosted project in a rolled-back transaction: it may.

## Follow-ups (not blocking)

- TEAM-05: no screen reads the audit trail.
- NFR-07: the UAT does not reach the operations screens, reports or search.
- NFR-04: cold start and frame rates are not measured on a mid-range Android phone.
- A voided Urdu receipt with tax withheld, a certificate and a note takes two A5 pages.
- Self-hosting Flutter's fallback fonts would remove the Google Fonts request.
