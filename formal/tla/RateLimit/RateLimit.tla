------------------------------- MODULE RateLimit -------------------------------
(***************************************************************************)
(* The fixed-window rate limiter of Maalik-e-Makaan, as the CURRENT code   *)
(* implements it, with N concurrent requests per key across window         *)
(* boundaries.                                                             *)
(*                                                                         *)
(* Code followed (last definitions):                                       *)
(*  * private.rate_limit_buckets (primary key (bucket_key, window_start))  *)
(*    and private.hit_rate_limit (20261103192528_foundation.sql):          *)
(*      v_window := date_bin(p_window, now(), '2000-01-01');               *)
(*      insert ... values (p_key, v_window, 1) on conflict (bucket_key,    *)
(*        window_start) do update set hits = b.hits + 1 returning hits;    *)
(*      return v_hits <= p_limit;                                          *)
(*  * private.enforce_rate_limit, app.check_request (PostgREST's pre-      *)
(*    request hook), private.rate_limit_retry_after and                    *)
(*    private.raise_rate_limited (20261104143928_ledger_jobs_hardening.sql):*)
(*    the hit runs INSIDE the request's transaction; a refusal raises      *)
(*    SQLSTATE PGRST with Retry-After = greatest(1, ceil(date_bin(window,  *)
(*    now()) + window - now())), which rolls the transaction back;         *)
(*  * public.admin_hit_rate_limit (20261104080502_function_rate_limits.sql)*)
(*    called by supabase/functions/_shared/rate_limit.ts hitRateLimit (its *)
(*    own RPC, so its own transaction, committed when it returns), and     *)
(*    rateLimitedError/retryAfterSeconds (the Edge Function computes       *)
(*    Retry-After from its own clock, ctx.now(), after the RPC returned),  *)
(*    used by delete-account (enforceLimit) and invite-member              *)
(*    (withinEmailLimits);                                                 *)
(*  * private.cleanup (hardening): delete buckets whose window_start <     *)
(*    now() - 2 hours (run by the daily job).                              *)
(*                                                                         *)
(* Granularity: one step per statement.  now() is the transaction's start  *)
(* (tx path: when the request's transaction began, which can be long       *)
(* before the hit runs, e.g. after record_payment waited for its lease;    *)
(* Edge path: when the RPC ran).  A row lock held by an uncommitted hit    *)
(* makes another hit on the same row wait (the upsert); a waiting hit then *)
(* sees the committed row.  Time is in ticks; a window is WIN ticks and    *)
(* the cleanup age CLEAN ticks (CLEAN = 2 x the longest window, as 2 hours *)
(* is to the 1-hour cap of admin_hit_rate_limit).                          *)
(***************************************************************************)
EXTENDS Naturals, Integers, FiniteSets, Sequences, TLC

CONSTANTS
    SCENARIO,  \* requests and keys (Script, ScenarioProcs)
    MUTANT,    \* "none" = current code; otherwise one mechanism removed
    FIX,       \* "none" = current code; otherwise a proposed fix applied
    MAX_TIME,  \* last tick the clock reaches
    LIMIT,     \* p_limit
    EDGE_LAG   \* ticks the Edge Function's clock is behind the database's

Mutants == {"none",
            "no_row_lock",        \* read hits, then write hits + 1 (no atomic upsert)
            "no_unique",          \* no primary key: UPDATE ... if not found INSERT
            "no_limit_check",     \* return true (no "v_hits <= p_limit")
            "no_window",          \* one bucket per key (no window_start in the key)
            "no_namespace",       \* keys not namespaced ('fn:' / action prefixes dropped)
            "long_window",        \* admin_hit_rate_limit without the 3600 s cap: window > cleanup age
            "fixed_retry_after",  \* Retry-After = the window length (the code before hardening)
            "ra_now_no_floor"}    \* Retry-After from the clock at the refusal, without greatest(1, ...)
Fixes == {"none",
          "autonomous_hit",       \* F4: the tx path's hit commits on its own (as the Edge path's does)
          "db_retry_after"}       \* F5: admin_hit_rate_limit returns the database's Retry-After
ASSUME MUTANT \in Mutants /\ FIX \in Fixes /\ MAX_TIME \in Nat /\ LIMIT \in 1..3 /\ EDGE_LAG \in 0..1

Mut(m) == MUTANT = m
Fix(f) == FIX = f
NoP == "-"
CLEAN == 4                                   \* cleanup age (2 hours, scaled)

-----------------------------------------------------------------------------
(* Requests: logical key k, path ("tx": the hit in the request's own       *)
(* transaction; "edge": admin_hit_rate_limit from an Edge Function),       *)
(* whether the request can fail after it was admitted (a validation error, *)
(* a constraint or RLS violation: its transaction rolls back), earliest    *)
(* start tick.                                                             *)
Rq(k, path, fail, e) == [k |-> k, path |-> path, fail |-> fail, e |-> e]
Script(t) ==
    CASE t \in {"q1", "q2", "q3", "q4"} -> Rq("a", "tx", FALSE, 0)
      [] t \in {"f1", "f2"}       -> Rq("a", "tx", TRUE, 0)
      [] t \in {"e1", "e2", "e3"} -> Rq("a", "edge", FALSE, 0)
      [] t \in {"b1", "b2"}       -> Rq("b", "edge", FALSE, 0)
      [] t = "cl"                 -> Rq(NoP, "cleanup", FALSE, 0)

ScenarioProcs(s) ==
    CASE s = "burst"      -> {"q1", "q2", "q3"}
      [] s = "burst4"     -> {"q1", "q2", "q3", "q4"}
      [] s = "burst_fail" -> {"f1", "f2", "q1"}
      [] s = "edge"       -> {"e1", "e2", "e3"}
      [] s = "two_keys"   -> {"q1", "q2", "b1", "b2"}
      [] s = "cleanup"    -> {"e1", "e2", "cl"}
Procs == ScenarioProcs(SCENARIO)
Reqs == Procs \ {"cl"}
Keys == {"a", "b"}

\* Bucket key: "<namespace>:<id>".  Key a is an RPC limit
\* ('record_payment:<uid>'), key b an Edge Function limit with the same
\* caller ('fn:delete_account:user:<uid>' after admin_hit_rate_limit's prefix).
Bucket(k) == IF Mut("no_namespace") THEN "uid" ELSE IF k = "a" THEN "rpc:uid" ELSE "fn:uid"
Buckets == {Bucket(k) : k \in Keys}
\* Window length; long_window: key a's window exceeds the cleanup age.
\* (a window longer than CLEAN + 1 ticks is still current when cleanup deletes it)
Win(k) == IF Mut("long_window") /\ k = "a" THEN CLEAN + 2 ELSE 2
\* date_bin(p_window, now(), '2000-01-01'): the start of the window holding s.
WStart(k, s) == (s \div Win(k)) * Win(k)
RowW(k, s) == IF Mut("no_window") THEN 0 ELSE WStart(k, s)
Slots == IF Mut("no_unique") THEN 1..Cardinality(Reqs) ELSE 1..1
Rows == Buckets \X (0..MAX_TIME) \X Slots
NoRow == [ex |-> FALSE, hits |-> 0]

-----------------------------------------------------------------------------
VARIABLES
    now,   \* the clock
    val, dirty, pre, lk,   \* rows: newest version, uncommitted writer, its pre-image, lock holder
    pc, lv, gh

vars == <<now, val, dirty, pre, lk, pc, lv, gh>>
Committed(r) == IF dirty[r] # NoP THEN pre[r] ELSE val[r]
Goto(t, l) == pc' = [pc EXCEPT ![t] = l]
Blk(t, r) == {lk[r]} \ {t, NoP}
K(t) == Script(t).k

\* Write v to row r in t, locking it; commit or roll back all of t.
Wr(t, r, v) ==
    /\ val' = [val EXCEPT ![r] = v]
    /\ pre' = IF dirty[r] = t THEN pre ELSE [pre EXCEPT ![r] = val[r]]
    /\ dirty' = [dirty EXCEPT ![r] = t]
    /\ lk' = [lk EXCEPT ![r] = t]
CommitV(t) ==
    /\ dirty' = [r \in Rows |-> IF dirty[r] = t THEN NoP ELSE dirty[r]]
    /\ lk' = [r \in Rows |-> IF lk[r] = t THEN NoP ELSE lk[r]]
    /\ UNCHANGED <<val, pre>>
RollbackV(t) ==
    /\ val' = [r \in Rows |-> IF dirty[r] = t THEN pre[r] ELSE val[r]]
    /\ dirty' = [r \in Rows |-> IF dirty[r] = t THEN NoP ELSE dirty[r]]
    /\ lk' = [r \in Rows |-> IF lk[r] = t THEN NoP ELSE lk[r]]
    /\ UNCHANGED pre
Max(a, b) == IF a > b THEN a ELSE b

-----------------------------------------------------------------------------
(* Ghost bookkeeping.  gh.adm[k][w] counts admission decisions of key k in *)
(* window w (by the request's now()), gh.admC those whose request          *)
(* committed, gh.hitsC committed hits (admitted or not), gh.cnt[r] the     *)
(* committed hits applied to row r, gh.keys[r] the logical keys that hit r.*)

\* The bookkeeping when t's hit (on row r, result h) becomes durable.
HitCommitted(g, t) ==
    LET k == K(t) w == WStart(k, lv[t].s) r == lv[t].row IN
    [g EXCEPT !.hitsC[k][w] = @ + 1,
              !.cnt[r] = @ + 1,
              !.admC[k][w] = IF lv[t].adm THEN @ + 1 ELSE @]

-----------------------------------------------------------------------------
(* A request.  tx path: q_start (BEGIN, now() fixed) ... q_hit (the        *)
(* upsert; a refusal raises and rolls back, with Retry-After from the same *)
(* now()) ... q_end (COMMIT, or a later error: ROLLBACK).                   *)
(* Edge path: q_start is the RPC (now() fixed), q_hit its upsert, committed *)
(* when the RPC returns; on a refusal q_ra is rateLimitedError(ctx.now()).  *)
-----------------------------------------------------------------------------
IsReq(t) == t \in Reqs
Edge(t) == Script(t).path = "edge"
Durable(t) == Edge(t) \/ Fix("autonomous_hit")      \* the hit commits at once

Q_Start(t) ==
    /\ IsReq(t) /\ pc[t] = "q_start"
    /\ now >= Script(t).e
    /\ lv' = [lv EXCEPT ![t].s = now]
    /\ Goto(t, IF Mut("no_row_lock") THEN "q_read" ELSE "q_hit")
    /\ UNCHANGED <<now, val, dirty, pre, lk, gh>>

\* The row the upsert targets, and whether it exists for t: an existing row
\* (or an uncommitted insert of the same key) is locked first, so t sees the
\* committed version after the holder ends, or its own.
Target(t) == <<Bucket(K(t)), RowW(K(t), lv[t].s), 1>>

\* Decide: admitted iff hits <= p_limit (no_limit_check: always).
Admit(h) == h <= LIMIT \/ Mut("no_limit_check")

\* Retry-After of the tx path: private.rate_limit_retry_after(p_window) with
\* the transaction's now(); mutants: the window length, or the clock at the
\* refusal without the floor of 1.
RaTx(t) ==
    LET k == K(t) w == WStart(k, lv[t].s) IN
    CASE Mut("fixed_retry_after") -> Win(k)
      [] Mut("ra_now_no_floor")   -> w + Win(k) - now
      [] OTHER                    -> Max(1, w + Win(k) - lv[t].s)

\* Record a refusal: the window it was counted in (by now()), Retry-After,
\* the clock reading Retry-After was computed from, and when the client got it.
Refused(g, t, ra, ref) ==
    LET k == K(t) w == WStart(k, lv[t].s) IN
    [g EXCEPT !.refusals = @ \cup {[k |-> k, w |-> w, wEnd |-> w + Win(k), ra |-> ra,
                                    ref |-> ref, resp |-> now,
                                    seen |-> g.hitsC[k][w]]}]

\* The current code's hit (and no_window, no_namespace, long_window, ...).
Q_Hit(t) ==
    /\ IsReq(t) /\ pc[t] = "q_hit"
    /\ ~Mut("no_unique")
    /\ LET r == Target(t)
           cur == val[r]                          \* committed, or t's own (none here)
           h == IF cur.ex THEN cur.hits + 1 ELSE 1
           adm == Admit(h)
       IN /\ Blk(t, r) = {}
          /\ Wr(t, r, [ex |-> TRUE, hits |-> h])
          /\ lv' = [lv EXCEPT ![t].row = r, ![t].adm = adm]
          /\ gh' = [gh EXCEPT !.keys[r] = @ \cup {K(t)},
                              !.adm[K(t)][WStart(K(t), lv[t].s)] = IF adm THEN @ + 1 ELSE @]
          /\ Goto(t, "q_after")
    /\ UNCHANGED now

\* no_unique: "update ... set hits = hits + 1 returning hits; if not found,
\* insert": the UPDATE waits for and locks every committed row of the key;
\* without a row it INSERTs a new one (nothing to wait for: no unique index).
Q_HitNoUnique(t) ==
    /\ IsReq(t) /\ pc[t] = "q_hit"
    /\ Mut("no_unique")
    /\ LET b == Bucket(K(t)) w == RowW(K(t), lv[t].s)
           mine == {j \in Slots : Committed(<<b, w, j>>).ex}
       IN IF mine # {}
          THEN LET j == CHOOSE j \in mine : \A i \in mine : j <= i
                   r == <<b, w, j>>
                   h == val[r].hits + 1
               IN /\ Blk(t, r) = {}
                  /\ Wr(t, r, [ex |-> TRUE, hits |-> h])
                  /\ lv' = [lv EXCEPT ![t].row = r, ![t].adm = Admit(h)]
                  /\ gh' = [gh EXCEPT !.keys[r] = @ \cup {K(t)},
                                      !.adm[K(t)][WStart(K(t), lv[t].s)] = IF Admit(h) THEN @ + 1 ELSE @]
          ELSE \E j \in Slots :
                  LET r == <<b, w, j>> IN
                  /\ ~val[r].ex /\ dirty[r] = NoP
                  /\ Wr(t, r, [ex |-> TRUE, hits |-> 1])
                  /\ lv' = [lv EXCEPT ![t].row = r, ![t].adm = Admit(1)]
                  /\ gh' = [gh EXCEPT !.keys[r] = @ \cup {K(t)},
                                      !.adm[K(t)][WStart(K(t), lv[t].s)] = IF Admit(1) THEN @ + 1 ELSE @]
    /\ Goto(t, "q_after")
    /\ UNCHANGED now

\* no_row_lock: read the committed counter (no lock), then write it + 1.
Q_Read(t) ==
    /\ IsReq(t) /\ pc[t] = "q_read"
    /\ lv' = [lv EXCEPT ![t].read = Committed(Target(t)).hits]
    /\ Goto(t, "q_write")
    /\ UNCHANGED <<now, val, dirty, pre, lk, gh>>
Q_Write(t) ==
    /\ IsReq(t) /\ pc[t] = "q_write"
    /\ LET r == Target(t) h == lv[t].read + 1 IN
       /\ Blk(t, r) = {}                           \* the UPDATE still waits, then overwrites
       /\ Wr(t, r, [ex |-> TRUE, hits |-> h])
       /\ lv' = [lv EXCEPT ![t].row = r, ![t].adm = Admit(h)]
       /\ gh' = [gh EXCEPT !.keys[r] = @ \cup {K(t)},
                           !.adm[K(t)][WStart(K(t), lv[t].s)] = IF Admit(h) THEN @ + 1 ELSE @]
    /\ Goto(t, "q_after")
    /\ UNCHANGED now

\* After the hit.  Edge path, or a durable hit (fix): the hit commits now.
\* tx path, refused: raise_rate_limited, ROLLBACK (the hit is undone).
Q_After(t) ==
    /\ IsReq(t) /\ pc[t] = "q_after"
    /\ IF Durable(t)
       THEN /\ CommitV(t)
            /\ LET g == HitCommitted(gh, t) IN
               IF lv[t].adm THEN gh' = g /\ Goto(t, IF Edge(t) THEN "done" ELSE "q_end")
               ELSE IF Edge(t) THEN gh' = g /\ Goto(t, "q_ra")
               ELSE gh' = Refused(g, t, RaTx(t), lv[t].s) /\ Goto(t, "done")
       ELSE IF lv[t].adm
            THEN /\ Goto(t, "q_end") /\ UNCHANGED <<val, dirty, pre, lk, gh>>
            ELSE /\ RollbackV(t)
                 /\ gh' = Refused(gh, t, RaTx(t), lv[t].s)
                 /\ Goto(t, "done")
    /\ UNCHANGED <<now, lv>>

\* The rest of the request: COMMIT, or an error after the limiter (ROLLBACK,
\* which also undoes the hit unless it was durable).
Q_End(t) ==
    /\ IsReq(t) /\ pc[t] = "q_end"
    /\ \/ /\ IF Durable(t) THEN UNCHANGED <<val, dirty, pre, lk, gh>>
             ELSE CommitV(t) /\ gh' = HitCommitted(gh, t)
       \/ /\ Script(t).fail
          /\ IF Durable(t) THEN UNCHANGED <<val, dirty, pre, lk>> ELSE RollbackV(t)
          /\ gh' = [gh EXCEPT !.failed = TRUE]
    /\ Goto(t, "done")
    /\ UNCHANGED <<now, lv>>

\* rateLimitedError(ctx.now(), rule): Retry-After from the Edge Function's
\* clock (retryAfterSeconds), or (fix) the database's value.
Q_Ra(t) ==
    /\ IsReq(t) /\ pc[t] = "q_ra"
    /\ LET k == K(t)
           e == now - EDGE_LAG
           raEdge == Max(1, Win(k) - (e % Win(k)))
           raDb == Max(1, WStart(k, lv[t].s) + Win(k) - lv[t].s)
       IN gh' = IF Fix("db_retry_after") THEN Refused(gh, t, raDb, lv[t].s)
                ELSE Refused(gh, t, raEdge, e)
    /\ Goto(t, "done")
    /\ UNCHANGED <<now, val, dirty, pre, lk, lv>>

-----------------------------------------------------------------------------
(* private.cleanup: "delete from private.rate_limit_buckets where          *)
(* window_start < p_now - interval '2 hours'"; it waits for a row an       *)
(* uncommitted hit holds (merged into one step with its commit).           *)
Old(r) == val[r].ex /\ r[2] + CLEAN < now
Cl_Run ==
    /\ "cl" \in Procs /\ pc["cl"] = "c_run"
    /\ \A r \in Rows : Old(r) => lk[r] = NoP
    /\ val' = [r \in Rows |-> IF Old(r) THEN NoRow ELSE val[r]]
    /\ gh' = [gh EXCEPT !.cnt = [r \in Rows |-> IF Old(r) THEN 0 ELSE @[r]]]
    /\ \/ pc' = [pc EXCEPT !["cl"] = "c_run"]          \* runs again later
       \/ now = MAX_TIME /\ pc' = [pc EXCEPT !["cl"] = "done"]
    /\ UNCHANGED <<now, dirty, pre, lk, lv>>

\* A transaction ends within MAX_WAIT ticks of its now() (statement_timeout
\* is seconds; windows are a minute or more): the clock does not move on
\* while a request older than that is unfinished.
MAX_WAIT == 1
Tick ==
    /\ now < MAX_TIME
    /\ \A t \in Reqs : pc[t] \in {"q_start", "done"} \/ now + 1 <= lv[t].s + MAX_WAIT
    /\ now' = now + 1
    /\ UNCHANGED <<val, dirty, pre, lk, pc, lv, gh>>

-----------------------------------------------------------------------------
Init ==
    /\ now = 0
    /\ val = [r \in Rows |-> NoRow]
    /\ dirty = [r \in Rows |-> NoP]
    /\ pre = [r \in Rows |-> NoRow]
    /\ lk = [r \in Rows |-> NoP]
    /\ pc = [t \in Procs |-> IF t = "cl" THEN "c_run" ELSE "q_start"]
    /\ lv = [t \in Procs |-> [s |-> 0, row |-> <<NoP, 0, 1>>, adm |-> FALSE, read |-> 0]]
    /\ gh = [adm |-> [k \in Keys |-> [w \in 0..MAX_TIME |-> 0]],
             admC |-> [k \in Keys |-> [w \in 0..MAX_TIME |-> 0]],
             hitsC |-> [k \in Keys |-> [w \in 0..MAX_TIME |-> 0]],
             cnt |-> [r \in Rows |-> 0],
             keys |-> [r \in Rows |-> {}],
             refusals |-> {}, failed |-> FALSE]

Step(t) ==
    \/ Q_Start(t) \/ Q_Hit(t) \/ Q_HitNoUnique(t) \/ Q_Read(t) \/ Q_Write(t)
    \/ Q_After(t) \/ Q_End(t) \/ Q_Ra(t)

Terminated == \A t \in Procs : pc[t] = "done"

Next ==
    \/ \E t \in Reqs : Step(t)
    \/ Cl_Run
    \/ Tick
    \/ Terminated /\ now = MAX_TIME /\ UNCHANGED vars

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* PROPERTIES *)

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ \A r \in Rows : val[r].hits \in 0..10 /\ lk[r] \in Procs \cup {NoP}

(* Admitted requests per key per window (by now()) that took effect never  *)
(* exceed the limit.                                                       *)
AdmittedWithinLimit == \A k \in Keys, w \in 0..MAX_TIME : gh.admC[k][w] <= LIMIT

(* Requests that passed the limiter per key per window, counting those     *)
(* that failed afterwards, never exceed the limit.                         *)
AdmissionsWithinLimit == \A k \in Keys, w \in 0..MAX_TIME : gh.adm[k][w] <= LIMIT

(* No lost update: every committed counter equals the committed hits that  *)
(* were applied to it.                                                     *)
NoLostUpdate == \A r \in Rows : Committed(r).ex => Committed(r).hits = gh.cnt[r]

(* Keys do not interfere: a bucket row only ever counts one logical key.   *)
KeysIndependent == \A r \in Rows : Cardinality(gh.keys[r]) <= 1

(* Window rollover: a refusal happens only when the key's own window       *)
(* already holds LIMIT committed hits (no refusal carried over from an     *)
(* earlier window or another key).                                         *)
NoFalseRefusal == \A x \in gh.refusals : x.seen >= LIMIT

(* Retry-After is at least one second ...                                  *)
RetryAfterPositive == \A x \in gh.refusals : x.ra >= 1

(* ... and is the time from the clock reading it was computed from to the  *)
(* end of the window the refusal was counted in.                           *)
RetryAtWindowEnd == \A x \in gh.refusals : x.ref + x.ra = x.wEnd

(* A client that waits Retry-After after it received the refusal comes     *)
(* back in a later window, never into the same one.                        *)
RetryNotEarly == \A x \in gh.refusals : x.resp + x.ra >= x.wEnd

(* Witnesses (each EXPECTED to be violated): the scenarios reach refusals, *)
(* a window rollover with a refusal, a refusal counted in one window and   *)
(* reported in the next, and requests that fail after their admission.     *)
W_NoRefusal == gh.refusals = {}
W_NoRolloverRefusal == \A x \in gh.refusals : x.w = 0
W_NoLateReport == \A x \in gh.refusals : x.resp < x.wEnd
W_NoFailAfterAdmit == ~gh.failed

=============================================================================
