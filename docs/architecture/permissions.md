# Permissions

Who can do what in a portfolio. Every rule below is enforced by the database,
not by the app; the app hides what a role cannot do, but a hand-made request
gets the same answer. The matrix was read from the hosted project's policies,
grants and function bodies on 2026-11-05, checked again on 2026-11-12 against
the policies, grants and role checks of a fresh local build of all 24
migrations, and is checked by the pgTAP suites
(`supabase/tests/database/03_rls_matrix.test.sql` and the per-area suites).

## Roles

A person can belong to many portfolios, with one role in each.

| Role       | Meant for                                         |
| ---------- | ------------------------------------------------- |
| Owner      | The landlord. Full control, including the team.   |
| Manager    | A caretaker or relative who runs the property.    |
| Accountant | Someone who records money but does not run units. |
| Viewer     | Family or an adviser who only looks.              |

## How it is enforced

1. **Row-level security** on every table limits rows to portfolios the caller
   belongs to, and limits writes by role. Policies call
   `app.my_portfolio_ids(roles)` once per statement. Write policies call
   `app.lock_my_portfolio_ids(roles)` instead: it locks the caller's
   portfolios (key share, id order) before the statement locks any row, so
   client writes keep the global lock order. A client write therefore costs
   more the more portfolios the caller belongs to, and waits while any of
   them is being deleted or its members changed (see
   [Concurrency](#concurrency)).
2. **Column grants** limit which columns a client may insert or update. Columns
   the system owns (balances, receipt numbers, `created_by`, voids) are never
   writable from the app, and secrets such as an invitation's `verifier_hash`
   are not readable.
3. **Functions** perform every money and membership change. They run as the
   table owner (`SECURITY DEFINER`), check the caller's role themselves, and take
   locks in the global order (account, portfolio, lease, other rows). Their
   names (23 today) are on a pgTAP allowlist in
   `supabase/tests/database/01_schema_security.test.sql`.
4. **Triggers** keep invariants a policy cannot express: voided rows are
   frozen, a document's file must exist, a file a document refers to cannot be
   deleted (whoever deletes it), a deleted account cannot write, and a
   portfolio's caretaker is always one of its managers (checked for every
   writer, cleared when that stops being true).
5. **Storage policies** scope files to `<portfolio_id>/…` folders.
6. **Edge Functions** handle what needs the service key: deleting an account and
   sending invitation e-mails. Each one verifies the caller's token first.
7. **CHECK constraints** hold every stored value to the form the app reads
   back, whoever writes it. Text must be clean (`app.is_clean_text`) and
   within its limit in code points (`char_length`). Phone numbers, CNICs,
   IBANs and Raast IDs must be exactly what mm_core's `PhoneNumber.fromE164`,
   `Cnic.parse` and `Iban.parse` accept (`app.is_valid_phone`,
   `app.is_valid_cnic`, `app.is_valid_iban`). Dart and SQL are tested against
   the same vectors in `contracts/identity_vectors.json`. A declared country
   and time zone must be one mm_core's `CountryCode` and `TimeZoneId` know
   (`app.is_valid_country_code`, `app.is_valid_time_zone`; the vectors are
   `contracts/residence_vectors.json`). Any other value is refused with
   SQLSTATE 23514.

## The matrix

O = owner, M = manager, A = accountant, V = viewer. "Members" means all four.

### Portfolio and team

| Action                                                   | Who                          | Through                                                             |
| -------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------- |
| See the portfolio, its members and their names           | Members                      | RLS                                                                 |
| Create a portfolio (you become its owner)                | Any signed-in account        | `create_portfolio`, with a per-account limit                        |
| Rename it, set defaults, receipt prefix, payment details | O                            | RLS and column grants                                               |
| Delete it, typing its name to confirm                    | O                            | `delete_portfolio`                                                  |
| Invite someone, list and revoke pending invitations      | O                            | `invite-member` function (`create_invitation`), `revoke_invitation` |
| Accept an invitation                                     | The invited, verified e-mail | `accept_invitation`                                                 |
| Change a member's role, remove a member                  | O                            | `update_member_role`, `remove_member`                               |
| Leave a portfolio                                        | Members                      | `remove_member` on yourself                                         |
| Sync billing for the whole portfolio                     | O, M, A                      | `sync_portfolio_billing`                                            |
| Answer "Does the owner live abroad?" while unanswered    | O, M                         | `create_portfolio` (at creation), `set_owner_abroad`                |
| Change that answer once given                            | O                            | `set_owner_abroad`                                                  |
| Name or clear the caretaker (always a manager)           | O                            | `set_caretaker`                                                     |
| See the answer and the caretaker                         | Members                      | RLS                                                                 |

Rules:

- A portfolio always keeps at least one owner. The last owner cannot leave,
  be removed or be demoted (`last_owner`).
- An invitation carries its inviter's authority. If the inviter stops being an
  owner before it is accepted (demoted, removed, left, or their account
  deleted, also directly in Auth), the invitation is revoked; accepting it
  answers `revoked`.
- An invitation expires after 7 days, works once, and only for the e-mail it
  was sent to, once that e-mail is verified.
- A portfolio has at most one pending invitation per e-mail. Inviting an
  e-mail again replaces its pending invitation (the old link answers
  `revoked`), also when two owners do it at the same moment: the second
  waits for the first and then replaces it.
- Opening an accepted invitation again (a retry) answers `accepted` with the
  role the member holds now, which may differ from the invitation's role if
  they joined another way or their role was changed since. If they are no
  longer a member (removed, or left), it answers `revoked`.
- `owner_abroad` NULL means not yet answered: every portfolio made before
  `20261112092618_residence.sql`, and those made by app versions that do not
  ask. It is never a default and never filled in from anyone's residence. The
  app asks the first owner or manager who opens such a portfolio; a manager
  only answers an unanswered question (`owner_abroad_answered` afterwards), and
  the "ask on next open" call (`p_if_unanswered`) returns an answer someone
  gave first instead of overwriting it. An answer cannot go back to NULL. The
  overseas-owner rules run only when it is true.
- A caretaker is always a manager of the portfolio, and there is no caretaker
  who is only a name and a phone number. It is cleared when that membership is
  demoted, promoted, removed, left or deleted with the account (also directly
  in Auth); every change is audited with its actor. A caretaker does not
  depend on the answer: a portfolio whose owner lives in Pakistan may have one.

### Properties, units, tenants and tenancies

| Action                                                   | Who                               |
| -------------------------------------------------------- | --------------------------------- |
| See properties, units, tenants, leases and occupants     | Members                           |
| Add or edit properties, units, tenants, utility accounts | O, M                              |
| Archive any of them                                      | O, M                              |
| Delete a property, unit, tenant or utility account       | O                                 |
| Start or edit a lease; add, edit or remove occupants     | O, M                              |
| Delete a lease                                           | O                                 |
| Change the rent, end a lease                             | O, M (`change_rent`, `end_lease`) |

Deletes are for mistakes:

- a property, unit or tenant can be deleted only while no tenancy or expense
  refers to it;
- a tenancy can be deleted only while every charge on it comes from its own
  terms (rent, late fees, the deposit) and none has been paid, waived or voided
  (`lease_has_records`). Those generated dues go with it. Any other tenancy is
  ended instead, which keeps its history.

Archive what is no longer in use.

### Money

| Action                                                     | Who                                             | Through                                       |
| ---------------------------------------------------------- | ----------------------------------------------- | --------------------------------------------- |
| See charges, payments, allocations, deposits, handovers    | Members                                         | RLS                                           |
| Record a payment and print its receipt                     | O, M, A                                         | `record_payment`                              |
| Void a payment                                             | O, M                                            | `void_payment`                                |
| Add a manual charge                                        | O, M, A                                         | RLS and column grants                         |
| Edit a charge's due date or note, a manual charge's amount | O, M, A                                         | `update_charge`                               |
| Void or waive a charge                                     | O, M                                            | `void_charge`, `waive_charge`                 |
| Bill a utility bill to the tenant                          | O, M, A                                         | `bill_utility_to_tenant`                      |
| Apply or refund a security deposit                         | O, M                                            | `apply_deposit`, `refund_deposit`             |
| Void a deposit refund                                      | O                                               | `void_deposit_refund`                         |
| Record handing cash to someone                             | O, M, A (as the giver; an owner may record any) | RLS                                           |
| Confirm or void a cash handover                            | O                                               | `confirm_cash_handover`, `void_cash_handover` |
| Log a reminder that was sent                               | O, M, A                                         | RLS                                           |

Financial rows are never deleted, only voided with a reason, and a voided row
cannot change. System charges (rent, late fees) cannot change amount; only
manual charges can, and never below what was paid or waived. Clients cannot
`UPDATE` charges directly: `update_charge` locks the lease first, as every
other writer of a lease's money does, and applies the lease's unused credit
when an amount goes up. A retried payment with the same idempotency key returns
the original receipt instead of charging twice. A payment and the tax withheld
with it may not add up to more than 999,999,999,999.99.

A payment dated within a rent's grace period that settles that rent in full
voids the rent's automatic late fee, even when it is recorded after the daily
job posted the fee, unless other money already paid part of the fee.

Ending a tenancy (`end_lease`) bills through the move-out month and voids the
rent of every later month and those months' automatic late fees, paid or not.
Money that had paid them is released and applied to the tenancy's other open
dues; what is left stays on the tenancy as credit, to refund or to void.

### Operations

| Action                                              | Who     |
| --------------------------------------------------- | ------- |
| See maintenance, expenses, utility bills, readings  | Members |
| Add or edit expenses, utility bills, meter readings | O, M, A |
| Delete expenses, utility bills, meter readings      | O, M    |
| Add, edit or delete maintenance requests            | O, M    |

### Documents and files

| Action                                          | Who                                        |
| ----------------------------------------------- | ------------------------------------------ |
| See and download documents                      | Members                                    |
| Upload a file and record its document           | O, M, A                                    |
| Rename a document or change its kind            | O, M, A                                    |
| Delete a document (its file is then cleaned up) | O, M                                       |
| Delete a file directly from storage             | O, M, and only if no document refers to it |

A document row can only point at a file that exists and is not queued for
deletion. Deleting the row queues the file; the `storage-cleanup` function
deletes it through the Storage API. No delete removes a file a document refers
to, whether it comes from a member, the Storage API's own superuser step, the
service role or SQL: a trigger on `storage.objects` keeps it.

A file is uploaded before its document row is written (see "Uploading a
document" in `docs/architecture/app.md`), so a file can be left without a row
when an upload is given up or its row is refused. Owners and managers delete
such a file themselves. Accountants can upload but not delete files, so a file
an accountant leaves behind stays in storage, and keeps counting against the
project's storage, until the daily sweep (`private.sweep_orphaned_files`,
from `private.run_daily_jobs`) queues every file of the bucket that is more
than a day old and has no document row. The `storage-cleanup` function then
deletes it. Until it is queued, the file can still be recorded: a document
row written for it within that day is accepted. Once it is queued, a row for
that path is refused (`document_file_pending_deletion`), and the app uploads
the file again under a new name. If the sweep cannot take its lock because
document inserts keep it busy, a later run of the daily job (every ten
minutes) tries again, so a stranded file waits a day and a little longer.

### Reports, search, notifications and audit

| Action                                                                                                | Who                         |
| ----------------------------------------------------------------------------------------------------- | --------------------------- |
| Dashboard, receivables, cash flow, property performance, tax-year statement, deposit position, search | Members                     |
| Cash positions (who holds collected cash) and the payment facts behind payment scores                 | Members                     |
| See your own notifications, mark them read (`mark_notifications_read`), delete them                   | Each member, for themselves |
| Read the audit trail                                                                                  | O, M                        |
| Change or delete audit entries                                                                        | Nobody                      |

### Your account

| Action                                                 | Who                                                        |
| ------------------------------------------------------ | ---------------------------------------------------------- |
| See your profile and your teammates' names             | You                                                        |
| Edit your name, phone and language                     | You                                                        |
| Declare the country you live in and your own time zone | You (`profile_residences`: RLS on your row, column grants) |
| Delete your account                                    | You, after a recent sign-in (`delete-account`)             |

Your country and time zone are yours alone: not shown to teammates (the
caretaker included) or tenants, not in the audit trail, never sent to analytics
or e-mail tools, and never read from a phone number, the store, an IP address,
the app's language or a currency. A client may write only the two values; the
server stamps `stated_at`. Nationality and immigration status are never stored.

Deleting an account removes every portfolio where you are the only owner and
your memberships elsewhere, clears your declared country and time zone, and
clears you as caretaker wherever you were one. From the moment deletion
starts, the account can no longer write (`account_deleted`). Operators delete
accounts the same way (`admin_delete_account_data` before the user is deleted
in Auth); see "Deleting a user account" in `docs/operations.md`.

## Concurrency

The database takes locks in one order: the account, then the portfolio, then
the lease, then other rows. Deleting a portfolio or an account, and changing a
portfolio's members, lock the portfolio `FOR UPDATE` and then work through its
rows. To keep that order, every client write first locks, `FOR KEY SHARE` and
in id order, every portfolio where the caller has the role the write needs
(`app.lock_my_portfolio_ids`), before it locks any row. Clients never wait for
each other on these locks; they wait only for deletions and membership changes.

`set_owner_abroad` and `set_caretaker` lock the portfolio `FOR NO KEY UPDATE`
between two role checks: members' key-share writes go on, while membership
changes and deletions (`FOR UPDATE`) wait, and a second answer waits and then
reads the first. The caretaker trigger then reads the caretaker's membership
`FOR SHARE`, after the portfolio, so a role change in flight is waited for and
read again. Two paths reach the portfolio row after a membership (the reverse
order) and can end in a deadlock, which PostgreSQL detects and aborts one side
of, never in a caretaker who is not a manager: deleting a caretaker directly in
Auth (as the existing `ON DELETE SET NULL` of `portfolios.created_by` does; run
`admin_delete_account_data` first) and service-role SQL that changes a role
directly (use `update_member_role`). `admin_delete_account_data` clears the
person's residence row last and without a filter on its values, so a person's
`UPDATE` in flight is waited for and cleared, and one that arrives later waits
and is refused. Scenario 31 of `tool/db/concurrency_test.sh` races each of
these paths, in both orders where both exist, and fails without the trigger's
`FOR SHARE` read, either second role check, the answer's lock or the
unfiltered clear.

A document and its file are serialised on the file's `storage.objects` row: a
document insert locks it, and every delete of the file must lock it too and
then passes a trigger that keeps a file a document refers to. Neither side
takes an entry in PostgreSQL's shared lock table per file.

### What it costs

Measured on PostgreSQL 16 on a 4-CPU machine, before and after
`20261105170557_concurrency_findings.sql` (ranges are repeated runs):

| Measure                                                                                                       | Before                       | After                        |
| ------------------------------------------------------------------------------------------------------------- | ---------------------------- | ---------------------------- |
| WAL per one-row client update, caller in 1 portfolio                                                          | 0.79 kB                      | 0.85–1.22 kB                 |
| The same, caller in 20 portfolios                                                                             | 0.79–0.89 kB                 | 1.91–2.02 kB                 |
| The same, caller in 200 portfolios                                                                            | 0.82–0.92 kB                 | 12.07–12.14 kB               |
| Time per one-row update (one `psql` transaction), caller in 200 portfolios                                    | 2.5–2.7 ms                   | 3.6–3.9 ms                   |
| Unit updates by 200 managers of one shared portfolio, 8 clients (`tool/db/stress_test.sh`)                    | 1,461–1,600 a second         | 933–1,273 a second           |
| Multixacts created in those 10 s                                                                              | 0–2                          | 9,243–12,577                 |
| Unit updates by 8 managers of the same 30 portfolios, 8 clients                                               | 1,449–1,715 a second         | 738–986 a second             |
| Multixacts created in those 10 s                                                                              | 0–47                         | 8,960–13,041                 |
| A write in another portfolio while one of the caller's portfolios is held `FOR UPDATE` for 1.5 s              | 63–67 ms                     | 1,248–1,251 ms               |
| `update_member_role` (30 calls) while 8 clients write the portfolio's units                                   | median 79–86 ms, max 138     | median 213–219 ms, max 1,227 |
| Deleting the stress harness's Plaza portfolio (7,800 charges, 7,631 payments, 32,716 audit rows, 201 members) | 1.2–1.7 s                    | 1.3–1.7 s                    |
| A user deleting 1,000 unattached files at once: advisory locks held until commit                              | 0 (1,001 with the first fix) | 0                            |

What follows from it:

- A write costs about 56 bytes of WAL more for each portfolio where the caller
  has the role, and writers sharing a portfolio create multixacts. Watch
  `mxid_age(datminmxid)` ([operations](../operations.md#health-checks)) and the
  largest number of portfolios one person belongs to:
  `select max(n) from (select count(*) n from public.portfolio_members group by user_id) m;`.
  Revisit the design before people hold hundreds of portfolios each.
- Deleting a portfolio or changing its members holds up its members' writes in
  every portfolio they belong to, for as long as it runs; a deletion holds its
  lock for its whole cascade (the Plaza: about 1.5 s). Signed-in requests on
  Supabase time out after 8 s, so while a portfolio about five times the
  Plaza's size is deleted, its members' writes would fail.
- A waiting `FOR UPDATE` does not stop new key-share requests. A write that
  arrived while a role change waited took 11 ms, and the role change finished
  only after it (1.57 s, against about 1 s without it). Under steady writes by
  members, a membership change or deletion waits for a moment when none is in
  flight, and a member can delay their own removal by keeping writes going.
- The membership functions and `delete_portfolio` wait rather than give up: a
  `lock_timeout` with a bounded retry would fail where waiting succeeds. With a
  1 s or 0.2 s `lock_timeout` and three tries, a role change behind one 4 s
  request (within the 8 s timeout) failed with `portfolio_busy` after 3.4 s or
  1.0 s, where waiting succeeded after 3.8 s; under the load above the tries
  did not lower the latency (median 121–295 ms, max 1.3–2.5 s).
- A delete of many files is about 2.5 times slower than before (1,000 files:
  225–268 ms before, 598–661 ms after), as the delete policy and the trigger
  run for each file.

### Rate limits and failing requests

Write limits (`app.check_request`, 120 writes a minute per user, and the
per-function limits such as `record_payment`'s) count a hit inside the
request's own transaction. A request that the limiter admits and that then
fails (a validation error, a constraint or row-security violation) rolls its
hit back with everything else, so failing requests never use up a quota
(`formal/tla/RateLimit`, finding F4). This is accepted:

- committing the hit on its own needs an autonomous transaction; `dblink` back
  into the same database would open a second connection, with stored
  credentials, for every write, against the connection pool, and PostgREST's
  pre-request hook shares the request's transaction;
- a failing request still needs a signed-in member of the portfolio, fails
  early (validation runs before the expensive work), and the platform's API
  gateway limits still apply to it.

Revisit this if failing writes show up as load. Edge Functions are not
affected: they count a hit through `admin_rate_limit_hit`, which commits on
its own, and they send the database's `Retry-After` for the window the hit
was counted in.

## Changing a rule

1. Write a migration that changes the policy, grant or function.
2. Update this page and the RLS matrix suite in the same pull request.
3. Run `make test-db` and `make test-db-concurrency`.
