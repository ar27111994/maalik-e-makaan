# The fixed-window rate limiter (TLA+)

A TLC-checked model of the database's fixed-window rate limiter, as the
code implements it now, with several concurrent requests per key across
window boundaries. Two callers share it: RPCs and PostgREST's pre-request
hook count a hit inside the request's own transaction, and Edge Functions
count one through an RPC of its own.

Code followed (always the last definition):

- `supabase/migrations/20261103192528_foundation.sql`:
  `private.rate_limit_buckets` (primary key `(bucket_key, window_start)`)
  and `private.hit_rate_limit` (the upsert).
- `20261104143928_ledger_jobs_hardening.sql` ("hardening"):
  `private.enforce_rate_limit`, `app.check_request`,
  `private.rate_limit_retry_after`, `private.raise_rate_limited` and
  `private.cleanup`.
- `20261107181820_ledger_findings.sql`: `public.admin_rate_limit_hit` (the
  `fn:` prefix, windows of 1 to 3600 seconds; returns the verdict and
  `private.rate_limit_retry_after` from the same `now()`), which replaced
  `public.admin_hit_rate_limit` (`20261104080502_function_rate_limits.sql`,
  kept for Edge Functions deployed before it) in the Edge Functions.
- `supabase/functions/_shared/rate_limit.ts` (`hitRateLimit`,
  `rateLimitedError`), as used by `delete-account/handler.ts`
  (`enforceLimit`) and `invite-member/handler.ts` (`withinEmailLimits`), and
  `_shared/errors.ts` (`retryAfterFromHint`).
- `20261103194829_jobs_and_api_guards.sql` (the first `check_request`, with
  its per-IP bucket) was read; hardening replaced it.

## What is modelled

One step per statement. A hit's row lock makes another hit on the same row
wait until the holder ends; the waiter then sees the committed row. A
rollback undoes the hit.

| Model element           | Code                                                                                                                                                                                                             |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Q_Start`               | the transaction begins; `now()` is fixed here. For the tx path that is the request's start (the hit may come later, e.g. after `record_payment` waited for its lease); for the Edge path it is the RPC's start   |
| `Q_Hit`                 | `hit_rate_limit`: `date_bin(p_window, now(), '2000-01-01')`, then `insert ... on conflict (bucket_key, window_start) do update set hits = hits + 1 returning hits`; admitted iff `hits <= p_limit`               |
| `Q_After` (tx, refused) | `raise_rate_limited(rate_limit_retry_after(p_window), ...)`: Retry-After `greatest(1, ceil(window end - now()))`, SQLSTATE `PGRST`, so the transaction (and the hit) rolls back                                  |
| `Q_After` (Edge)        | `admin_rate_limit_hit` returns: its transaction, and the hit, commit                                                                                                                                             |
| `Q_End`                 | the rest of the request: `COMMIT`, or an error after the limiter (a validation error such as `invalid_amount`, a constraint or RLS violation): `ROLLBACK`                                                        |
| `Q_Ra`                  | `rateLimitedError(verdict.retryAfterSeconds)`: the database's Retry-After for the window of the hit. Mutant `edge_clock_retry_after`: from the Edge Function's clock, read after the RPC returned (the old code) |
| `Cl_Run`                | `private.cleanup`: delete buckets with `window_start < now() - 2 hours`                                                                                                                                          |
| `Tick`                  | the clock; a transaction ends within one tick of its `now()`                                                                                                                                                     |
| `Bucket`, `WStart`      | bucket keys: `<action>:<uid>` (RPCs), `api_write:user:<sub>` (pre-request), `fn:<key>` (Edge); windows anchored at 2000-01-01                                                                                    |

## Properties

| Property                | Plain language                                                                                                                              | Broken by                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `AdmittedWithinLimit`   | Per key and window (by `now()`), the admitted requests that took effect never exceed the limit.                                             | `mut_no_row_lock_limit`, `mut_no_unique`, `mut_no_limit_check`, `mut_long_window` |
| `AdmissionsWithinLimit` | Per key and window, the requests that passed the limiter never exceed the limit, counting those that failed afterwards.                     | the current code: finding F4 (`burst_fail`)                                       |
| `NoLostUpdate`          | Every counter equals the hits committed to it.                                                                                              | `mut_no_row_lock`                                                                 |
| `KeysIndependent`       | A bucket row only ever counts one logical key.                                                                                              | `mut_no_namespace`                                                                |
| `NoFalseRefusal`        | A refusal happens only when the key's own window already holds the limit (window rollover resets the count; no key counts against another). | `mut_no_window`                                                                   |
| `RetryAfterPositive`    | Retry-After is at least one second.                                                                                                         | `mut_ra_now_no_floor`                                                             |
| `RetryAtWindowEnd`      | Retry-After is the time from the clock reading it was computed from to the end of the window the refusal was counted in.                    | `mut_fixed_retry_after`, `mut_edge_clock_retry_after` (finding F5)                |
| `RetryNotEarly`         | A client that waits Retry-After from when it got the refusal comes back in a later window.                                                  | `mut_edge_clock_retry_after_skew` (F5 with the Edge clock behind the database's)  |
| `TypeOK`                | Sanity of the model.                                                                                                                        | none: model sanity                                                                |

Witnesses (each expected to be violated) show the scenarios reach
refusals (`w_refusal`), a refusal after a window rollover (`w_rollover`),
a refusal reported after its window ended (`w_late_report`) and, with F4's
fix, an admitted request that fails afterwards (`w_fail_after_admit`).

## Finding F4: requests that fail after the limiter are never limited

Severity: low (it needs a signed-in member, and each failing request still
costs the database work). Current code, accepted (see "Decision" below);
`burst_fail` reproduces it, `burst_fail_fix` passes with the proposed fix,
which was not adopted.

`enforce_rate_limit` and `app.check_request` count the hit in the
request's own transaction. A request refused by the limiter rolls back, and
its hit with it, which is intended. But so does a request that the limiter
admitted and that then fails: a validation error raised after
`enforce_rate_limit` (`record_payment` with an invalid amount, date or
method), a constraint or RLS violation of a Data API write. Its hit is
undone, so failing requests never use up the quota and are never refused.
Counterexample (limit 1, 7 states):

1. `f1` and `f2` start in the same window.
2. `f1` hits: 1, admitted (uncommitted; `f2`'s hit would wait for it).
3. `f1` fails after the limiter: `ROLLBACK`, and the counter is gone.
4. `f2` hits: 1, admitted. `AdmissionsWithinLimit` is violated (two
   admissions in one window with a limit of 1).

Replayed on PostgreSQL by `replay/run.sh`: 150 Data API writes in 7 to 30
seconds (two runs), each `record_payment` with amount -1 behind `app.check_request`
(120 a minute) and `enforce_rate_limit` (60 a minute). All 150 fail with
`invalid_amount`, none with `rate_limited`, and no bucket row is left. 35
valid `sync_portfolio_billing` calls in the same way are admitted 30 times
and refused 5 times.

`accept_invitation` avoids this by design: it returns
`{"status": "invalid"}` instead of raising, so a wrong token commits its
hit.

Proposed fix (`FIX = "autonomous_hit"`): commit the hit on its own, as
`admin_rate_limit_hit` does for Edge Functions. Inside PostgreSQL that
needs an autonomous transaction (for example `dblink` to the same
database). Where that is not wanted: make RPC validation failures return a
status after the hit, as `accept_invitation` does, and rely on the
platform's API gateway limits for failing Data API writes.

Decision (with `20261107181820_ledger_findings.sql`): accepted, not fixed.
An autonomous hit inside PostgreSQL needs `dblink` back into the same
database: a second connection, with credentials stored in the database, for
every write (the pre-request hook runs on all of them), against the
connection pool, and a failure mode of its own. PostgREST's pre-request hook
runs in the request's transaction, so it cannot commit a hit separately.
Returning a status instead of raising would change every RPC's contract and
leave Data API writes (constraint and row-security errors) uncounted anyway.
The residual risk, recorded in `docs/architecture/permissions.md` ("Rate
limits and failing requests"): a signed-in member can repeat failing writes
without these counters refusing them; each one fails at validation, before
the expensive work, and the platform's gateway limits still apply.

## Finding F5 (fixed): an Edge Function's Retry-After could point to the wrong window

Severity: low (a client waited up to one window longer than needed, or, if
the Edge clock was behind the database's, retried too early and was refused
again). Fixed by `20261107181820_ledger_findings.sql`; the old code is the
mutant `edge_clock_retry_after`: `mut_edge_clock_retry_after` reproduces the
first, `mut_edge_clock_retry_after_skew` the second; `edge` and `edge_skew`
pass.

The database counts the hit in the window of its `now()`. The Edge
Function computes Retry-After from `ctx.now()`, read after the RPC
returned. When a window boundary falls between the two readings, the
reported wait runs to the end of the next window. Counterexample (window 2
ticks, limit 1, 10 states):

1. `e1` hits at time 0: admitted.
2. `e2`'s RPC runs at time 1: refused, counted in window [0, 2).
3. `Tick`: time 2. `e2`'s Edge Function computes Retry-After 2, so the
   client waits until 4, a whole window longer. `RetryAtWindowEnd` is
   violated.

With the Edge clock one tick behind the database's (`edge_skew`, 8
states): `e1` is admitted and `e2` refused at time 0, in window [0, 2).
The Edge Function reads its clock as -1, in the window before, and reports
a wait of 1. The client comes back at 1, still in [0, 2), and is refused
again. `RetryNotEarly` is violated. Real clock skew is milliseconds, so
this needs a refusal within milliseconds of a boundary; the effect is the
same at that scale.

Fix: `public.admin_rate_limit_hit` returns the verdict with the database's
Retry-After (`private.rate_limit_retry_after`, from the same `now()`), and
`hitRateLimit` passes it to `rateLimitedError`, which sends it. It is exact
and no longer depends on the Edge clock. `17_ledger_findings.test.sql`
checks the function's answer against `rate_limit_retry_after` for the same
transaction; `supabase/functions/tests` check that `delete-account` sends
the database's wait whatever the Edge clock reads.

## Observation: one user's writes queue behind each other

Not a property violation. `app.check_request` takes the row lock of the
user's `api_write` bucket in every write transaction and holds it until
the transaction ends. A user's concurrent writes therefore run one after
another: `replay/run.sh` measures a second write waiting about 1.4 s
behind a first that sleeps 2 s. A slow write (a long billing sync)
delays the same user's other writes on every device. It cannot deadlock:
every write takes this row first, before any portfolio, lease or other
bucket.

## Bounds, abstractions and why they are adequate

- Up to four requests on one key, or two on each of two keys; limits of 1
  and 2; windows of 2 ticks over 3 to 6 ticks, so every run crosses one or
  two window boundaries. The limiter's state is one counter per key and
  window; a request's fate depends only on the hits before it in its own
  window, so these sizes cover each order of commit, rollback, wait and
  rollover.
- Time is in ticks, and a transaction lasts at most one tick past its
  `now()`: real transactions end within the statement timeout (seconds),
  and windows are a minute or longer. Without this bound the model would
  let a transaction outlive the two-hour cleanup age.
- The cleanup age is 4 ticks, twice the window, as two hours is to the
  one-hour cap on Edge windows. `mut_long_window` gives one key a window of
  6 ticks (a window the cap would refuse).
- The Edge clock is the database's clock, or one tick behind
  (`EDGE_LAG`).
- `invite-member` checks two rules one after the other, and a hit on the
  first rule counts even when the second refuses. Each rule is a key here;
  the pair adds no new interleaving.

## How to run

```sh
formal/tla/RateLimit/run.sh ci         # 22 configurations
formal/tla/RateLimit/run.sh all        # 24 configurations
formal/tla/RateLimit/replay/run.sh     # F4 on PostgreSQL (tool/db/env.sh)
```

The runner is the same file as `../LateFees/run.sh`. The replay builds
the disposable database `mm_fv_ratelimit` with `tool/db/reset.sh` and drops
it. It exits non-zero unless F4 shows.

## Expected results

Measured on this machine (4 CPUs shared with other work; 1 job x 1
worker):

- `run.sh ci`: 22/22 as expected in 48 s wall (2 jobs x 1 worker, after
  `20261107181820_ledger_findings.sql`).
- `run.sh all`: 24/24 as expected in 44 s wall. The largest is
  `burst4` (37,282 distinct states).
- `replay/run.sh`: F4 "yes" (exit 0) in 13 s and in 46 s (two runs,
  different load), and again after the ledger findings migration: 150
  failing writes, none refused, no bucket row left.
- Expected violations: `burst_fail` (F4, accepted), every `mut_*` (among
  them `mut_edge_clock_retry_after` and `mut_edge_clock_retry_after_skew`,
  the code before F5 was fixed) and every `w_*` witness.

## Cross-check with the executable tests

| Test                                                                                                         | Here                                  |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------- |
| `09_jobs_guards.test.sql`: three hits admitted, the fourth refused; limits are per key                       | `burst`, `burst_one`, `two_keys`      |
| `09_jobs_guards.test.sql`: the 121st write in a minute gets 429, with the wait in the hint; no per-IP bucket | `Q_After` (tx, refused), `RaTx`       |
| `09_jobs_guards.test.sql`: `admin_hit_rate_limit` refuses windows over an hour; keys are prefixed `fn:`      | `mut_long_window`, `mut_no_namespace` |
| `supabase/functions/tests`: the database's wait sent as Retry-After, `retryAfterFromHint`                    | `Q_Ra`, `RetryAfterPositive`          |
| `17_ledger_findings.test.sql`: `admin_rate_limit_hit` returns `rate_limit_retry_after` of its own `now()`    | `Q_Ra`, `RetryAtWindowEnd`            |

None of these counts the hits of requests that fail after the limiter (F4,
accepted).

## Not covered

- PostgREST's mapping of `PGRST` errors to HTTP and supabase-js's handling
  of the hint (unit-tested in `supabase/functions/tests`).
- Lock waits between the bucket rows and other rows: every write takes its
  `api_write` row first and at most one action bucket after it, so no cycle
  through them is possible; the model has no other rows.
- The platform's own API gateway limits.
