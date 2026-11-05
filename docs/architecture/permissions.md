# Permissions

Who can do what in a portfolio. Every rule below is enforced by the database,
not by the app; the app hides what a role cannot do, but a hand-made request
gets the same answer. The matrix was read from the hosted project's policies,
grants and function bodies on 2026-11-05 and is checked by the pgTAP suites
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
   `app.my_portfolio_ids(roles)` once per statement.
2. **Column grants** limit which columns a client may insert or update. Columns
   the system owns (balances, receipt numbers, `created_by`, voids) are never
   writable from the app, and secrets such as an invitation's `verifier_hash`
   are not readable.
3. **Functions** perform every money and membership change. They run as the
   table owner (`SECURITY DEFINER`), check the caller's role themselves, and take
   locks in the global order (account, portfolio, lease, other rows). Their
   names are on a pgTAP allowlist.
4. **Triggers** keep invariants a policy cannot express: only manual charges
   can change amount, voided rows are frozen, a document's file must exist, and
   a deleted account cannot write.
5. **Storage policies** scope files to `<portfolio_id>/…` folders.
6. **Edge Functions** handle what needs the service key: deleting an account and
   sending invitation e-mails. Each one verifies the caller's token first.

## The matrix

O = owner, M = manager, A = accountant, V = viewer. "Members" means all four.

### Portfolio and team

| Action                                                   | Who                          | Through                                       |
| -------------------------------------------------------- | ---------------------------- | --------------------------------------------- |
| See the portfolio, its members and their names           | Members                      | RLS                                           |
| Create a portfolio (you become its owner)                | Any signed-in account        | `create_portfolio`, with a per-account limit  |
| Rename it, set defaults, receipt prefix, payment details | O                            | RLS and column grants                         |
| Delete it, typing its name to confirm                    | O                            | `delete_portfolio`                            |
| Invite someone, list and revoke pending invitations      | O                            | `invite-member` function, `revoke_invitation` |
| Accept an invitation                                     | The invited, verified e-mail | `accept_invitation`                           |
| Change a member's role, remove a member                  | O                            | `update_member_role`, `remove_member`         |
| Leave a portfolio                                        | Members                      | `remove_member` on yourself                   |
| Sync billing for the whole portfolio                     | O, M, A                      | `sync_portfolio_billing`                      |

Rules:

- A portfolio always keeps at least one owner. The last owner cannot leave,
  be removed or be demoted (`last_owner`).
- An invitation carries its inviter's authority. If the inviter stops being an
  owner before it is accepted, accepting fails and the invitation is revoked.
- An invitation expires after 7 days, works once, and only for the e-mail it
  was sent to, once that e-mail is verified.

### Properties, units, tenants and tenancies

| Action                                                   | Who                               |
| -------------------------------------------------------- | --------------------------------- |
| See properties, units, tenants, leases and occupants     | Members                           |
| Add or edit properties, units, tenants, utility accounts | O, M                              |
| Archive any of them                                      | O, M                              |
| Delete a property, unit, tenant or utility account       | O                                 |
| Start or edit a lease, add or edit occupants             | O, M                              |
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

| Action                                                  | Who                                             | Through                                       |
| ------------------------------------------------------- | ----------------------------------------------- | --------------------------------------------- |
| See charges, payments, allocations, deposits, handovers | Members                                         | RLS                                           |
| Record a payment and print its receipt                  | O, M, A                                         | `record_payment`                              |
| Void a payment                                          | O, M                                            | `void_payment`                                |
| Add a manual charge; edit its amount, due date, note    | O, M, A                                         | RLS and column grants                         |
| Void or waive a charge                                  | O, M                                            | `void_charge`, `waive_charge`                 |
| Bill a utility bill to the tenant                       | O, M, A                                         | `bill_utility_to_tenant`                      |
| Apply or refund a security deposit                      | O, M                                            | `apply_deposit`, `refund_deposit`             |
| Void a deposit refund                                   | O                                               | `void_deposit_refund`                         |
| Record handing cash to someone                          | O, M, A (as the giver; an owner may record any) | RLS                                           |
| Confirm or void a cash handover                         | O                                               | `confirm_cash_handover`, `void_cash_handover` |
| Log a reminder that was sent                            | O, M, A                                         | RLS                                           |

Financial rows are never deleted, only voided with a reason, and a voided row
cannot change. System charges (rent, late fees) cannot change amount; only
manual charges can. A retried payment with the same idempotency key returns the
original receipt instead of charging twice.

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
deletes it through the Storage API.

### Reports, search, notifications and audit

| Action                                                                                                | Who                         |
| ----------------------------------------------------------------------------------------------------- | --------------------------- |
| Dashboard, receivables, cash flow, property performance, tax-year statement, deposit position, search | Members                     |
| See your own notifications, mark them read, delete them                                               | Each member, for themselves |
| Read the audit trail                                                                                  | O, M                        |
| Change or delete audit entries                                                                        | Nobody                      |

### Your account

| Action                                     | Who                                            |
| ------------------------------------------ | ---------------------------------------------- |
| See your profile and your teammates' names | You                                            |
| Edit your name, phone and language         | You                                            |
| Delete your account                        | You, after a recent sign-in (`delete-account`) |

Deleting an account removes every portfolio where you are the only owner and
your memberships elsewhere. From the moment deletion starts, the account can no
longer write (`account_deleted`).

## Changing a rule

1. Write a migration that changes the policy, grant or function.
2. Update this page and the RLS matrix suite in the same pull request.
3. Run `make test-db` and `make test-db-concurrency`.
