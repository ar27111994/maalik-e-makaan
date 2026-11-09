--------------------------- MODULE LedgerPayments ---------------------------
(***************************************************************************)
(* Payments, receipts, allocations, voids, credit and the billing jobs of  *)
(* the leases of ONE portfolio, under PostgreSQL READ COMMITTED.           *)
(*                                                                         *)
(* Code followed (supabase/migrations, last definition of each object):    *)
(*  public.record_payment, private.replayed_payment,                      *)
(*    private.payment_request_hash, private.next_receipt_number,           *)
(*    public.void_payment, private.sync_lease_billing,                     *)
(*    private.maintain_lease                                               *)
(*      20261104143928_ledger_jobs_hardening.sql ("hardening")             *)
(*  private.lock_lease_for_write, public.sync_portfolio_billing            *)
(*      20261105072426_membership_deletion_storage.sql ("membership")      *)
(*  private.run_daily_jobs, private.before_manual_charge_insert           *)
(*      20261105170557_concurrency_findings.sql ("findings")               *)
(*  public.update_charge, public.end_lease, public.record_payment (the     *)
(*    amount + tax check, which changes nothing modelled here); the        *)
(*    client UPDATE grant and the charges_update policy are dropped        *)
(*      20261107181820_ledger_findings.sql ("ledger findings")             *)
(*  private.allocate_payment, private.apply_lease_credit,                  *)
(*    public.change_rent, private.before_charge_update, tables charges /   *)
(*    payments / payment_allocations, the unique indexes                   *)
(*    charges_rent_period_key, payments_receipt_number_key,                *)
(*    payments_idempotency_key                                             *)
(*      20261103193658_ledger.sql ("ledger")                               *)
(*  private.after_manual_charge_insert (membership).                       *)
(*                                                                         *)
(* Semantics. One TLA+ step is one SQL statement, or one row lock of a     *)
(* statement that locks rows one by one. Committed rows are chC/pyC/ctC/   *)
(* lsC. A transaction's own uncommitted writes are in chU/pyU/ctU/lsU, on  *)
(* rows whose lock it holds (an UPDATE, a FOR UPDATE and an INSERT all     *)
(* lock the row until COMMIT), so a statement sees committed rows plus its *)
(* own writes. Row locks are waited for (the step is disabled); after the  *)
(* wait FOR UPDATE and UPDATE see the newest committed version             *)
(* (EvalPlanQual). Lease rows have the modes FOR UPDATE and FOR KEY SHARE  *)
(* (foreign-key checks) with PostgreSQL's conflict rule; every other row   *)
(* lock taken here (FOR UPDATE, FOR NO KEY UPDATE of an UPDATE) conflicts  *)
(* with every other one taken here, so it is one exclusive holder. An      *)
(* INSERT that meets an uncommitted conflicting index entry waits for its  *)
(* writer; then a plain INSERT raises unique_violation and ON CONFLICT     *)
(* takes its conflict path. Any error rolls the whole transaction back.    *)
(* SpontAbort aborts any started transaction (client gone, timeout, 429    *)
(* from a rate limit), at most MAX_ABORTS times per behaviour. PostgREST   *)
(* answers after COMMIT; a lost answer is retried with the SAME request.   *)
(*                                                                         *)
(* Abstractions (each argued in README.md, "Bounds and abstractions"):     *)
(*  - one portfolio, one receipt year, leases L1 < L2 (id order), the      *)
(*    current month is month 2; amounts are small integers;                *)
(*  - the portfolio key (FOR KEY SHARE in lock_lease_for_write,            *)
(*    sync_portfolio_billing, run_daily_jobs, the client policies and      *)
(*    triggers) is never contended here: only deletions and membership     *)
(*    changes take it FOR UPDATE (formal/tla/Membership);                  *)
(*  - rate-limit bucket rows (enforce_rate_limit, app.check_request) are   *)
(*    not locks here: a bucket is one row per (key, window), so requests   *)
(*    in different windows never share it, and leaving a lock out only    *)
(*    adds interleavings; a bucket cannot close a wait cycle (each         *)
(*    transaction takes at most one per action, before the counter, and    *)
(*    no bucket holder waits for a later bucket taker). A 429 is a         *)
(*    SpontAbort;                                                          *)
(*  - authorisation, amount, date and method checks always pass;          *)
(*  - late fees (assess_late_fees, formal/tla/LateFees), deposits,         *)
(*    waivers and void_charge are not modelled (waived_amount stays 0);    *)
(*  - every payment is paid on the same day, so apply_lease_credit's       *)
(*    ORDER BY paid_on, id is PayRank (ids are time-ordered);              *)
(*  - the request fingerprint (payment_request_hash) is the intent: two    *)
(*    deliveries of one intent hash alike, different intents differ.       *)
(*                                                                         *)
(* Deadlock: TLC's deadlock check stays on. Inv8_NoWaitCycle checks the    *)
(* wait-for graph in every state, because a blocked transaction may abort  *)
(* while MAX_ABORTS lasts, which would hide a cycle from TLC's own check.  *)
(***************************************************************************)
EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS
    SCENARIO,      \* which transactions run (Reqs, Syncs, Jobs, ...)
    MUTANT,        \* "none", or one protection removed (see Mut* below)
    RECEIPT_WIDTH, \* lpad width of the OLD next_receipt_number (mutant lpad_truncate)
    COUNTER_START, \* receipts already issued this year in the portfolio
    MAX_ABORTS     \* bound on spontaneous aborts in one behaviour

NoP == "none"
Min(a, b) == IF a < b THEN a ELSE b
Range(s) == {s[i] : i \in 1..Len(s)}

(***************************************************************************)
(* Mutants: each removes one protection of today's code.                   *)
(***************************************************************************)
\* lock_lease_for_write without FOR UPDATE (record_payment and void_payment only)
MutNoLeaseLock == MUTANT \in {"no_lease_lock", "no_lease_idem_lock"}
\* replayed_payment without pg_advisory_xact_lock (the code before hardening)
MutNoIdemLock == MUTANT \in {"no_idem_lock", "no_idem_lock_unique", "no_lease_idem_lock"}
\* payments_idempotency_key dropped
MutNoIdemUnique == MUTANT \in {"no_idem_unique", "no_idem_lock_unique"}
\* replayed_payment compares lease and amount only (no request fingerprint)
MutNoRequestHash == MUTANT = "no_request_hash"
\* a fingerprint that differs between deliveries of one request (e.g. one
\* that hashed now() or a per-attempt value)
MutHashPerDelivery == MUTANT = "hash_per_delivery"
\* receipt counter outside the transaction (sequence semantics)
MutSeqCounter == MUTANT = "seq_counter"
\* next_receipt_number with lpad(v, RECEIPT_WIDTH) (truncates, the ledger.sql code)
MutLpadTruncate == MUTANT = "lpad_truncate"
\* sync_lease_billing without SELECT .. FOR UPDATE
MutNoSyncLock == MUTANT \in {"no_sync_lock", "no_sync_lock_rent_unique"}
\* charges_rent_period_key dropped (the max(period_month) read is the only guard)
MutNoRentUnique == MUTANT \in {"no_rent_unique", "no_sync_lock_rent_unique"}
\* sync_lease_billing trusts the caller's loop snapshot (no status re-check)
MutNoStatusRecheck == MUTANT = "no_status_recheck"
\* sync_portfolio_billing loop without ORDER BY l.id (S2 walks L2, L1)
MutSyncUnordered == MUTANT = "sync_unordered"
\* void_payment without DELETE FROM payment_allocations
MutVoidKeepsAllocs == MUTANT = "void_keeps_allocs"
\* void_payment without apply_lease_credit
MutVoidNoCredit == MUTANT = "void_no_credit"
\* void_payment fails on a voided payment (the ledger.sql code: 'already_voided')
MutVoidRejectsVoided == MUTANT = "void_rejects_voided"
\* sync_lease_billing without apply_lease_credit
MutSyncNoCredit == MUTANT = "sync_no_credit"
\* after_manual_charge_insert without apply_lease_credit
MutMcNoCredit == MUTANT = "mc_no_credit"
\* manual charge: insert, FK key share on the lease, then FOR UPDATE in the
\* AFTER trigger (the ledger.sql code, fixed in membership)
MutMcLockAfterFk == MUTANT = "mc_lock_after_fk"
\* run_daily_jobs waits for a busy lease (no SKIP LOCKED) / walks leases in
\* reverse id order / both
MutJobWait == MUTANT \in {"job_wait", "job_wait_unordered"}
MutJobUnordered == MUTANT \in {"job_unordered", "job_wait_unordered"}
\* run_daily_jobs without pg_try_advisory_xact_lock (two coordinators at once)
MutJobNoTryLock == MUTANT = "job_no_try_lock"
\* allocate_payment's cursor without ORDER BY due_date, id (latest due first)
MutAllocUnordered == MUTANT = "alloc_unordered"
\* change_rent without the re-pricing UPDATE of untouched rent
MutCrNoReprice == MUTANT = "cr_no_reprice"
\* update_charge without lock_lease_for_write: the edit locks its rows in scan
\* order with no lease lock (the client UPDATE of charges before ledger
\* findings, finding F1)
MutCuNoLeaseLock == MUTANT = "cu_no_lease_lock"
\* update_charge without apply_lease_credit after an amount change (finding F2)
MutCuNoCredit == MUTANT = "cu_no_credit"
\* end_lease voids only unpaid later rent, releasing nothing (finding F3)
MutElNoRelease == MUTANT = "el_no_release"

(***************************************************************************)
(* The fixes of findings F1-F3 (ledger findings), now today's code.        *)
(***************************************************************************)
\* F1: charge edits go through update_charge, which locks the lease first
CuLocksLease == ~MutCuNoLeaseLock
\* F2: update_charge applies the lease's credit after an amount change
CuAppliesCredit == ~MutCuNoCredit
\* F3: end_lease releases the allocations of later rent, voids it and
\* re-applies the credit
ElReleases == ~MutElNoRelease

(***************************************************************************)
(* Scenario data                                                           *)
(***************************************************************************)
Leases == {"L1", "L2"}
LeaseOrder == <<"L1", "L2">>                   \* ORDER BY l.id
LeaseRank(l) == IF l = "L1" THEN 1 ELSE 2
CurMonth == 2                                  \* month of app.today_pkt()
RentAmt == 2                                   \* rent in force at the start
CrRent == 3                                    \* change_rent's new rent

Reqs == CASE SCENARIO = "retry"         -> {"R1a", "R1b", "RY"}
          [] SCENARIO = "keys"          -> {"R1a", "RX", "R2"}
          [] SCENARIO = "core"          -> {"R1a", "R1b", "R2", "R3"}
          [] SCENARIO = "receipts"      -> {"R1a", "R2"}
          [] SCENARIO = "voids"         -> {"R1a", "R3", "R5"}
          [] SCENARIO = "syncs"         -> {"R2"}
          [] SCENARIO = "jobs"          -> {"R1a", "R2"}
          [] SCENARIO = "lifecycle"     -> {"R2"}
          [] SCENARIO = "manual"        -> {"R5"}
          [] SCENARIO = "client_edit"   -> {"R1a"}
          [] SCENARIO = "client_amount" -> {"R5"}
          [] OTHER                      -> {}
Syncs == CASE SCENARIO = "core"      -> {"S1", "S2"}
           [] SCENARIO = "syncs"     -> {"S1", "S2"}
           [] SCENARIO = "jobs"      -> {"S1"}
           [] SCENARIO = "lifecycle" -> {"S1"}
           [] OTHER                  -> {}
Jobs == CASE SCENARIO = "jobs"      -> {"J1", "J2"}
          [] SCENARIO = "syncs"     -> {"J1"}
          [] SCENARIO = "lifecycle" -> {"J1"}
          [] OTHER                  -> {}
Voids == CASE SCENARIO = "retry"       -> {"V1", "V2"}
           [] SCENARIO = "core"        -> {"V1"}
           [] SCENARIO = "voids"       -> {"V1"}
           [] SCENARIO = "client_edit" -> {"V1"}
           [] OTHER                    -> {}
Ends == IF SCENARIO = "lifecycle" THEN {"EL"} ELSE {}
RentChanges == IF SCENARIO = "lifecycle" THEN {"CR"} ELSE {}
Manuals == IF SCENARIO = "manual" THEN {"MC1", "MC2"} ELSE {}
Edits == IF SCENARIO \in {"client_edit", "client_amount"} THEN {"CU"} ELSE {}

Procs == Reqs \cup Syncs \cup Jobs \cup Voids \cup Ends \cup RentChanges \cup Manuals \cup Edits
RentWriters == Syncs \cup Jobs \cup Ends      \* transactions that run sync_lease_billing

\* end_lease(L2, moved out in month 1); change_rent(L1, from month 2, rent 3)
ElLease == "L2"
ElMonth == 1
CrLease == "L1"
\* client UPDATE of charges: the rows in the statement's scan order, and what it sets
CuRows == IF SCENARIO = "client_edit" THEN <<"c13", "c11">> ELSE <<"c13">>
CuEdit == IF SCENARIO = "client_edit" THEN "description" ELSE "amount"
CuLease == "L1"

\* Requests: R1a/R1b are two deliveries of intent I1 (a retry). RY reuses
\* I1's key on the same lease with the same amount but another request
\* (other charge_ids); RX reuses it on the other lease.
Intent(r) == CASE r \in {"R1a", "R1b"} -> "I1"
               [] r = "R2" -> "I2"
               [] r = "R3" -> "I3"
               [] r = "R5" -> "I5"
               [] r = "RX" -> "IX"
               [] r = "RY" -> "IY"
\* key, lease, amount, tax withheld (s.155) and p_charge_ids
IInfo(i) == CASE i = "I1" -> [key |-> "K1", lease |-> "L1", amt |-> 2, tax |-> 0, sel |-> <<>>]
              [] i = "IY" -> [key |-> "K1", lease |-> "L1", amt |-> 2, tax |-> 0, sel |-> <<"c13">>]
              [] i = "IX" -> [key |-> "K1", lease |-> "L2", amt |-> 1, tax |-> 0, sel |-> <<>>]
              [] i = "I2" -> [key |-> "K2", lease |-> "L2", amt |-> 2, tax |-> 1, sel |-> <<>>]
              [] i = "I3" -> [key |-> "K3", lease |-> "L1", amt |-> 1, tax |-> 0, sel |-> <<"c13">>]
              [] i = "I5" -> [key |-> "K5", lease |-> "L1", amt |-> 3, tax |-> 0, sel |-> <<>>]
PInfo(q) == IInfo(Intent(q))
PayIds == Reqs                    \* a request inserts at most one payment row: its own
PayRank(q) == CASE q = "R1a" -> 1 [] q = "R1b" -> 2 [] q = "R2" -> 3 [] q = "R3" -> 4
                [] q = "R5" -> 5 [] q = "RX" -> 6 [] q = "RY" -> 7
\* the payment a void request names (one the user saw, so committed)
VoidIntent == "I1"

\* Pre-existing charges: c11/c21 are the auto rent of month 1, c13 a manual
\* charge due later than the month-2 rent, so FIFO order is sensitive to
\* rent created concurrently.
PreCharges == {"c11", "c13", "c21"}
PreInfo(c) ==
    CASE c = "c11" -> [lease |-> "L1", kind |-> "rent", period |-> 1, due |-> 1, rank |-> 1, amt |-> 1]
      [] c = "c13" -> [lease |-> "L1", kind |-> "manual", period |-> 0, due |-> 3, rank |-> 2, amt |-> 1]
      [] c = "c21" -> [lease |-> "L2", kind |-> "rent", period |-> 1, due |-> 1, rank |-> 3, amt |-> 1]
WriterRank(s) == CASE s = "S1" -> 1 [] s = "S2" -> 2 [] s = "J1" -> 3 [] s = "J2" -> 4 [] OTHER -> 5
RentLeases(s) == IF s \in Ends THEN {ElLease} ELSE Leases
\* the month-2 rent row that rent writer s inserts for lease l
RentId(s, l) == s \o l
RentIds == UNION {{RentId(s, l) : l \in RentLeases(s)} : s \in RentWriters}
RentRowsOf(l) == {RentId(s, l) : s \in {x \in RentWriters : l \in RentLeases(x)}}
ManualId(m) == "m" \o m
ManualIds == {ManualId(m) : m \in Manuals}
ChargeIds == PreCharges \cup RentIds \cup ManualIds
ChInfo == [c \in ChargeIds |->
             IF c \in PreCharges THEN PreInfo(c)
             ELSE IF c \in ManualIds
             THEN [lease |-> "L1", kind |-> "manual", period |-> 0, due |-> 1,
                   rank |-> IF c = "mMC1" THEN 21 ELSE 22, amt |-> 1]
             ELSE LET s == CHOOSE x \in RentWriters : \E l \in RentLeases(x) : RentId(x, l) = c
                      l == CHOOSE y \in RentLeases(s) : RentId(s, y) = c
                  IN [lease |-> l, kind |-> "rent", period |-> CurMonth, due |-> CurMonth,
                      rank |-> 10 + 2 * WriterRank(s) + LeaseRank(l), amt |-> 0]]

Keys == {PInfo(q).key : q \in PayIds}
LockObjs == {"ch" \o c : c \in ChargeIds} \cup {"py" \o q : q \in PayIds} \cup {"ct", "job"}
              \cup {"ad" \o k : k \in Keys}

\* Receipt digits. Today: lpad(v, greatest(5, char_length(v)), '0') never
\* truncates, so the number is v. Mutant: lpad(v, W) keeps the left W digits.
RECURSIVE LeftDigits(_)
LeftDigits(v) == IF v < 10 ^ RECEIPT_WIDTH THEN v ELSE LeftDigits(v \div 10)
Fmt(v) == IF MutLpadTruncate THEN LeftDigits(v) ELSE v
OldReceipts == {Fmt(v) : v \in 1..COUNTER_START}

ZeroAl == [c \in ChargeIds |-> 0]
NoPay == [ex |-> FALSE, rc |-> 0, al |-> ZeroAl, alloc |-> 0, voided |-> FALSE]
Applied(q) == PInfo(q).amt + PInfo(q).tax          \* payments.applied_amount
NoCh == [ex |-> FALSE, paid |-> 0, amt |-> 0, vd |-> FALSE]

(***************************************************************************)
(* State                                                                   *)
(***************************************************************************)
VARIABLES
    pc,       \* [Procs -> label]
    lv,       \* [Procs -> PL/pgSQL locals]
    chC, chU, \* charges [ex, paid, amt, vd]: committed / writer's version
    pyC, pyU, \* payment row and its payment_allocations rows [ex, rc, al, alloc, voided]
    ctC, ctU, \* private.receipt_counters row of (portfolio, year) [ex, val]
    lsC, lsU, \* lease rows [st, mo (moved-out month), rent (rent in force, month 2)]
    lkL,      \* lease row locks [x: FOR UPDATE holder, ks: KEY SHARE holders]
    lk,       \* other row locks and advisory locks: [LockObjs -> holder]
    maint,    \* private.lease_maintenance: leases maintained today (committed)
    resp,     \* answer delivered to each caller (after COMMIT, or the error)
    aborts,   \* spontaneous aborts used so far
    fifoBad   \* ghost: a commit made a FIFO allocation past an open earlier due

vars == <<pc, lv, chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, lk, maint, resp, aborts, fifoBad>>
dataVars == <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU>>

Labels == {"init", "rp_idem", "rp_counter", "rp_insert", "rp_fk", "al_open", "al_fetch",
           "al_lockpay", "cr_list", "sy_lock", "jb_lock", "sy_ins", "sy_fk", "vo_pay",
           "vo_rev", "el_void", "cr_upd", "mc_ins", "mc_fk", "mc_lock", "cu_lease",
           "cu_row", "tx_commit", "done"}

LV0 == [pay |-> NoP, rem |-> 0, cur |-> <<>>, fet |-> <<>>, fifo |-> {}, sel |-> <<>>,
        cl |-> <<>>, ll |-> <<>>, lease |-> NoP, ret |-> NoP, cret |-> NoP, sret |-> NoP,
        rv |-> <<>>, rc |-> 0, month |-> 0, mt |-> {}, busy |-> 0, sk |-> 0, rows |-> <<>>]
Resp0 == [k |-> "none", rc |-> 0, pay |-> NoP, code |-> "none", busy |-> 0]
FreeLease == [x |-> NoP, ks |-> {}]

Init ==
    /\ pc = [p \in Procs |-> "init"]
    /\ lv = [p \in Procs |-> LV0]
    /\ chC = [c \in ChargeIds |->
                IF c \in PreCharges THEN [ex |-> TRUE, paid |-> 0, amt |-> PreInfo(c).amt, vd |-> FALSE]
                ELSE NoCh]
    /\ chU = chC
    /\ pyC = [q \in PayIds |-> NoPay]
    /\ pyU = pyC
    /\ ctC = [ex |-> COUNTER_START > 0, val |-> COUNTER_START]
    /\ ctU = ctC
    /\ lsC = [l \in Leases |-> [st |-> "active", mo |-> 0, rent |-> RentAmt]]
    /\ lsU = lsC
    /\ lkL = [l \in Leases |-> FreeLease]
    /\ lk = [o \in LockObjs |-> NoP]
    /\ maint = {}
    /\ resp = [p \in Procs |-> Resp0]
    /\ aborts = 0
    /\ fifoBad = FALSE

(***************************************************************************)
(* Views, ordering and locks                                               *)
(***************************************************************************)
\* What a statement of p sees: committed rows plus p's own writes. When p
\* holds a row's lock and has not written it, the U copy equals the C copy.
ChV(p, c) == IF lk["ch" \o c] = p THEN chU[c] ELSE chC[c]
PyV(p, q) == IF lk["py" \o q] = p THEN pyU[q] ELSE pyC[q]
LeaseV(p, l) == IF lkL[l].x = p THEN lsU[l] ELSE lsC[l]
Out(row) == row.amt - row.paid                     \* charges.outstanding (waived = 0)
OpenRow(row) == row.ex /\ ~row.vd /\ Out(row) > 0
OpenV(p, c, l) == ChInfo[c].lease = l /\ OpenRow(ChV(p, c))

\* ORDER BY c.due_date, c.id
Before(c, d) == \/ ChInfo[c].due < ChInfo[d].due
                \/ (ChInfo[c].due = ChInfo[d].due /\ ChInfo[c].rank < ChInfo[d].rank)
\* allocate_payment: ORDER BY coalesce(array_position(p_charge_ids, c.id), max), due_date, id
SelPos(sel, c) == IF c \in Range(sel) THEN CHOOSE i \in 1..Len(sel) : sel[i] = c ELSE 1000
CurLt(sel, c, d) == \/ SelPos(sel, c) < SelPos(sel, d)
                    \/ /\ SelPos(sel, c) = SelPos(sel, d)
                       /\ IF MutAllocUnordered THEN Before(d, c) ELSE Before(c, d)
RECURSIVE SortCh(_, _)
SortCh(S, sel) == IF S = {} THEN <<>>
                  ELSE LET m == CHOOSE x \in S : \A y \in S \ {x} : CurLt(sel, x, y)
                       IN <<m>> \o SortCh(S \ {m}, sel)
RECURSIVE SortPy(_)
SortPy(S) == IF S = {} THEN <<>>
             ELSE LET m == CHOOSE x \in S : \A y \in S \ {x} : PayRank(x) < PayRank(y)
                  IN <<m>> \o SortPy(S \ {m})

RECURSIVE SumF(_, _)
SumF(f, S) == IF S = {} THEN 0
              ELSE LET x == CHOOSE y \in S : TRUE IN f[x] + SumF(f, S \ {x})

FreeFor(p, o) == lk[o] \in {NoP, p}
Grab(p, o) == [lk EXCEPT ![o] = p]
GrabAll(p, os) == [o \in LockObjs |-> IF o \in os THEN p ELSE lk[o]]
Holders(p, os) == {lk[o] : o \in os} \ {NoP, p}
\* PostgreSQL row-lock conflicts on lease rows: FOR UPDATE conflicts with
\* every lock, FOR KEY SHARE only with FOR UPDATE.
UpdBlk(p, l) == ({lkL[l].x} \ {NoP, p}) \cup (lkL[l].ks \ {p})
KsBlk(p, l) == {lkL[l].x} \ {NoP, p}
GrantUpd(p, l) == [lkL EXCEPT ![l] = [x |-> p, ks |-> @.ks \ {p}]]
GrantKs(p, l) == IF lkL[l].x = p THEN lkL ELSE [lkL EXCEPT ![l].ks = @ \cup {p}]
ReleaseL(p) == [l \in Leases |-> [x |-> IF lkL[l].x = p THEN NoP ELSE lkL[l].x,
                                  ks |-> lkL[l].ks \ {p}]]
ReleaseLk(p) == [o \in LockObjs |-> IF lk[o] = p THEN NoP ELSE lk[o]]

(***************************************************************************)
(* Commit and abort                                                        *)
(***************************************************************************)
NewChC(p) == [c \in ChargeIds |-> IF lk["ch" \o c] = p THEN chU[c] ELSE chC[c]]
NewPyC(p) == [q \in PayIds |-> IF lk["py" \o q] = p THEN pyU[q] ELSE pyC[q]]
NewLsC(p) == [l \in Leases |-> IF lkL[l].x = p THEN lsU[l] ELSE lsC[l]]

\* Inv7 (FIFO), on the state p commits: a charge p paid in FIFO order (not
\* explicitly chosen) is not preceded, in (due_date, id) order, by an open
\* charge of the same lease.
FifoBroken(p, newC) ==
    \E pr \in lv[p].fifo :
       \E d \in ChargeIds : /\ ChInfo[d].lease = ChInfo[pr[2]].lease
                            /\ OpenRow(newC[d])
                            /\ Before(d, pr[2])

\* COMMIT, then the HTTP response r.
Finish(p, r) ==
    LET newC == NewChC(p) IN
    /\ chC' = newC
    /\ pyC' = NewPyC(p)
    /\ ctC' = IF lk["ct"] = p THEN ctU ELSE ctC
    /\ lsC' = NewLsC(p)
    /\ maint' = IF p \in Jobs THEN maint \cup lv[p].mt ELSE maint
    /\ lk' = ReleaseLk(p)
    /\ lkL' = ReleaseL(p)
    /\ fifoBad' = (fifoBad \/ FifoBroken(p, newC))
    /\ resp' = [resp EXCEPT ![p] = r]
    /\ pc' = [pc EXCEPT ![p] = "done"]
    /\ lv' = [lv EXCEPT ![p] = LV0]
    /\ UNCHANGED <<chU, pyU, ctU, lsU, aborts>>

\* Any error (or a lost connection) rolls back every write of the transaction.
FailBase(p, code) ==
    /\ chU' = [c \in ChargeIds |-> IF lk["ch" \o c] = p THEN chC[c] ELSE chU[c]]
    /\ pyU' = [q \in PayIds |-> IF lk["py" \o q] = p THEN pyC[q] ELSE pyU[q]]
    /\ ctU' = IF lk["ct"] = p THEN ctC ELSE ctU
    /\ lsU' = [l \in Leases |-> IF lkL[l].x = p THEN lsC[l] ELSE lsU[l]]
    /\ lk' = ReleaseLk(p)
    /\ lkL' = ReleaseL(p)
    /\ resp' = [resp EXCEPT ![p] = [k |-> "err", rc |-> 0, pay |-> NoP, code |-> code, busy |-> 0]]
    /\ pc' = [pc EXCEPT ![p] = "done"]
    /\ lv' = [lv EXCEPT ![p] = LV0]
    /\ UNCHANGED <<chC, pyC, ctC, lsC, maint, fifoBad>>
Fail(p, code) == FailBase(p, code) /\ UNCHANGED aborts

OkResp == [k |-> "ok", rc |-> 0, pay |-> NoP, code |-> "none", busy |-> 0]

Goto(p, l, r) == /\ pc' = [pc EXCEPT ![p] = l]
                 /\ lv' = [lv EXCEPT ![p] = r]

\* Control flow without an SQL statement: the apply_lease_credit loop
\* ("cr_next") and the per-lease loop of the billing sync and the job ("sy_done").
RECURSIVE Resolve(_, _, _)
Resolve(p, l, r) ==
    CASE l = "cr_next" ->
           IF r.cl = <<>> THEN Resolve(p, r.cret, r)
           ELSE [pc |-> "al_lockpay",
                 lv |-> [r EXCEPT !.pay = Head(r.cl), !.cl = Tail(r.cl), !.ret = "cr_next",
                                  !.sel = <<>>]]
      [] l = "sy_done" ->
           IF r.ll = <<>> THEN [pc |-> "tx_commit", lv |-> r]
           ELSE [pc |-> IF p \in Jobs THEN "jb_lock" ELSE "sy_lock",
                 lv |-> [r EXCEPT !.lease = Head(r.ll), !.ll = Tail(r.ll)]]
      [] OTHER -> [pc |-> l, lv |-> r]
GotoR(p, l, r) == LET x == Resolve(p, l, r) IN Goto(p, x.pc, x.lv)

\* lock_lease_for_write (membership): portfolio key (never contended here),
\* then SELECT .. FOR UPDATE on the lease. Mutant: no FOR UPDATE.
LeaseLockFree(p, l, mutable) == (mutable /\ MutNoLeaseLock) \/ UpdBlk(p, l) = {}
LeaseLockGrant(p, l, mutable) == IF mutable /\ MutNoLeaseLock THEN lkL ELSE GrantUpd(p, l)

(***************************************************************************)
(* private.allocate_payment(p_payment_id, p_charge_ids) (ledger)           *)
(*   select .. from payments where id = $1 for update;      -> AlLockPay   *)
(*   for v_charge in select .. order by .. for update of c  -> AlOpen/Fetch*)
(*     insert allocation on conflict do update; update charges paid += ..  *)
(*   update payments set allocated_amount = amount + tax - v_remaining     *)
(* The loop body and the final UPDATE only write rows the caller locked,   *)
(* so they are one step (Apply) after the cursor's last row is locked.     *)
(* The PL/pgSQL FOR loop fetches (and locks) up to 10 rows before the      *)
(* first iteration; every cursor here has at most 5 rows.                  *)
(***************************************************************************)
RECURSIVE ApplyLoop(_, _, _, _, _, _, _)
ApplyLoop(q, sel, fet, rem, al, chu, fifo) ==
    IF fet = <<>> \/ rem <= 0 THEN [rem |-> rem, al |-> al, chu |-> chu, fifo |-> fifo]
    ELSE LET c == Head(fet)[1]
             a == Min(rem, Head(fet)[2])         \* least(v_remaining, v_charge.outstanding)
         IN ApplyLoop(q, sel, Tail(fet), rem - a,
                      [al EXCEPT ![c] = @ + a],
                      [chu EXCEPT ![c] = [@ EXCEPT !.paid = @ + a]],
                      IF c \in Range(sel) THEN fifo ELSE fifo \cup {<<q, c>>})

ApplyAndReturn(p, r, newLk) ==
    LET q == r.pay
        res == ApplyLoop(q, r.sel, r.fet, r.rem, pyU[q].al, chU, r.fifo)
        r2 == [r EXCEPT !.cur = <<>>, !.fet = <<>>, !.rem = 0, !.fifo = res.fifo, !.sel = <<>>]
        x == Resolve(p, r.ret, r2)
    IN /\ chU' = res.chu
       /\ pyU' = [pyU EXCEPT ![q] = [@ EXCEPT !.al = res.al, !.alloc = Applied(q) - res.rem]]
       /\ lk' = newLk
       /\ pc' = [pc EXCEPT ![p] = x.pc]
       /\ lv' = [lv EXCEPT ![p] = x.lv]
       /\ UNCHANGED <<chC, pyC, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

\* Opens the cursor (open charges of the payment's lease, snapshot).
OpenCursor(p, r, newLk) ==
    LET cursor == SortCh({c \in ChargeIds : OpenV(p, c, PInfo(r.pay).lease)}, r.sel)
    IN IF cursor = <<>>
       THEN ApplyAndReturn(p, [r EXCEPT !.cur = <<>>, !.fet = <<>>], newLk)
       ELSE /\ lk' = newLk
            /\ Goto(p, "al_fetch", [r EXCEPT !.cur = cursor, !.fet = <<>>])
            /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

\* record_payment -> allocate_payment(own payment, p_charge_ids): the FOR
\* UPDATE is on the caller's own uncommitted row.
AlOpen(p) ==
    /\ pc[p] = "al_open"
    /\ OpenCursor(p, lv[p], lk)

\* apply_lease_credit -> allocate_payment(v_payment_id)
AlLockPay(p) ==
    /\ pc[p] = "al_lockpay"
    /\ LET r == lv[p]
           q == r.pay
           o == "py" \o q
       IN /\ FreeFor(p, o)
          /\ LET row == pyU[q]                  \* newest version once locked
                 rem == Applied(q) - row.alloc  \* unallocated_amount
             IN IF ~row.ex \/ row.voided \/ rem <= 0
                THEN /\ lk' = Grab(p, o)
                     /\ GotoR(p, r.ret, r)
                     /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp,
                                    aborts, fifoBad>>
                ELSE OpenCursor(p, [r EXCEPT !.rem = rem, !.sel = <<>>], Grab(p, o))

\* FOR UPDATE OF c on the next cursor row: wait for its holder, then
\* EvalPlanQual re-checks "voided_at is null and outstanding > 0" on the
\* newest version and returns that version's outstanding.
AlFetch(p) ==
    /\ pc[p] = "al_fetch"
    /\ LET r == lv[p]
           c == Head(r.cur)
           o == "ch" \o c
       IN /\ FreeFor(p, o)
          /\ LET row == chU[c]
                 r2 == [r EXCEPT !.cur = Tail(r.cur),
                                 !.fet = IF OpenRow(row) THEN Append(r.fet, <<c, Out(row)>>)
                                         ELSE r.fet]
             IN IF r2.cur = <<>>
                THEN ApplyAndReturn(p, r2, Grab(p, o))
                ELSE /\ lk' = Grab(p, o)
                     /\ Goto(p, "al_fetch", r2)
                     /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp,
                                    aborts, fifoBad>>

\* private.apply_lease_credit(lease) (ledger): for v_payment_id in select id
\* from payments where lease_id = $1 and voided_at is null and
\* unallocated_amount > 0 order by paid_on, id loop allocate_payment(..)
CrList(p) ==
    /\ pc[p] = "cr_list"
    /\ LET r == lv[p]
           list == SortPy({q \in PayIds : /\ PInfo(q).lease = r.lease
                                          /\ PyV(p, q).ex
                                          /\ ~PyV(p, q).voided
                                          /\ PyV(p, q).alloc < Applied(q)})
       IN GotoR(p, "cr_next", [r EXCEPT !.cl = list])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, lk, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* public.record_payment (hardening)                                       *)
(***************************************************************************)
\* v_lease := lock_lease_for_write(p_lease_id, ...)
RpStart(p) ==
    /\ pc[p] = "init"
    /\ LET l == PInfo(p).lease IN
       /\ LeaseLockFree(p, l, TRUE)
       /\ lkL' = LeaseLockGrant(p, l, TRUE)
       /\ Goto(p, "rp_idem", [LV0 EXCEPT !.sel = PInfo(p).sel, !.lease = l])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

\* private.replayed_payment: pg_advisory_xact_lock(portfolio, key), then the
\* payment with the key (committed snapshot): a different request
\* fingerprint -> fail('idempotency_key_reused'); the same -> return
\* payment_result(original) (COMMIT and answer). Not found: then (merged
\* into this step, a read of rows only lease holders write; a client charge
\* edit can only raise an amount, which keeps a charge open) enforce_rate_limit
\* (a 429 is a SpontAbort), the checks, and p_charge_ids: each chosen charge
\* of this lease, not voided, outstanding > 0, else 'invalid_charge_selection'.
SameRequest(q, p) ==
    CASE MutNoRequestHash -> PInfo(q).lease = PInfo(p).lease /\ PInfo(q).amt = PInfo(p).amt
      [] MutHashPerDelivery -> q = p
      [] OTHER -> Intent(q) = Intent(p)
RpIdem(p) ==
    /\ pc[p] = "rp_idem"
    /\ LET k == PInfo(p).key
           ao == "ad" \o k
           found == {q \in PayIds \ {p} : pyC[q].ex /\ PInfo(q).key = k}
           sel == PInfo(p).sel
           valid == \A i \in 1..Len(sel) : OpenV(p, sel[i], PInfo(p).lease)
       IN /\ MutNoIdemLock \/ FreeFor(p, ao)
          /\ IF found = {}
             THEN IF valid
                  THEN /\ lk' = IF MutNoIdemLock THEN lk ELSE Grab(p, ao)
                       /\ Goto(p, "rp_counter", lv[p])
                       /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp,
                                      aborts, fifoBad>>
                  ELSE Fail(p, "invalid_selection")
             ELSE \E q \in found :
                    IF ~SameRequest(q, p)
                    THEN Fail(p, "idem_reused")
                    ELSE Finish(p, [OkResp EXCEPT !.rc = pyC[q].rc, !.pay = q])

\* next_receipt_number (hardening): insert into receipt_counters .. values
\* (.., 1) on conflict (portfolio_id, year) do update set last_value =
\* last_value + 1: the row lock (or the uncommitted first insert) is held
\* until COMMIT. It runs while the payments INSERT evaluates its VALUES.
RpCounter(p) ==
    /\ pc[p] = "rp_counter"
    /\ IF MutSeqCounter
       THEN LET v == ctC.val + 1 IN
            /\ ctC' = [ex |-> TRUE, val |-> v]
            /\ ctU' = [ex |-> TRUE, val |-> v]
            /\ Goto(p, "rp_insert", [lv[p] EXCEPT !.rc = v])
            /\ UNCHANGED <<chC, chU, pyC, pyU, lsC, lsU, lkL, lk, maint, resp, aborts, fifoBad>>
       ELSE /\ FreeFor(p, "ct")
            /\ LET v == IF ctU.ex THEN ctU.val + 1 ELSE 1 IN
               /\ lk' = Grab(p, "ct")
               /\ ctU' = [ex |-> TRUE, val |-> v]
               /\ Goto(p, "rp_insert", [lv[p] EXCEPT !.rc = v])
               /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

\* Unique checks of the payments INSERT, in index-OID order:
\* payments_receipt_number_key, then payments_idempotency_key. A conflicting
\* entry of a transaction in progress makes the inserter wait for it.
PendIns(p) == {q \in PayIds \ {p} : ~pyC[q].ex /\ pyU[q].ex}
RcWait(p, f) == {q \in PendIns(p) : Fmt(pyU[q].rc) = f}
RcDup(p, f) == f \in OldReceipts \/ \E q \in PayIds \ {p} : pyC[q].ex /\ Fmt(pyC[q].rc) = f
KeyWait(p, k) == {q \in PendIns(p) : PInfo(q).key = k}
KeyDup(p, k) == \E q \in PayIds \ {p} : pyC[q].ex /\ PInfo(q).key = k
InsBlk(p) == LET f == Fmt(lv[p].rc)
                 k == PInfo(p).key
             IN IF RcWait(p, f) # {} THEN RcWait(p, f)
                ELSE IF RcDup(p, f) THEN {}
                ELSE IF ~MutNoIdemUnique THEN KeyWait(p, k)
                ELSE {}

\* insert into payments (.., receipt_number, .., idempotency_key); then
\* insert into private.payment_requests (own new row: no wait).
RpInsert(p) ==
    /\ pc[p] = "rp_insert"
    /\ InsBlk(p) = {}
    /\ LET f == Fmt(lv[p].rc)
           k == PInfo(p).key
           l == PInfo(p).lease
       IN IF RcDup(p, f) THEN Fail(p, "unique_receipt")
          ELSE IF ~MutNoIdemUnique /\ KeyDup(p, k) THEN Fail(p, "unique_idem")
          ELSE /\ pyU' = [pyU EXCEPT ![p] = [ex |-> TRUE, rc |-> lv[p].rc, al |-> ZeroAl,
                                             alloc |-> 0, voided |-> FALSE]]
               /\ lk' = Grab(p, "py" \o p)
               \* FK payments_lease_fkey: KEY SHARE on the lease (no-op under FOR UPDATE)
               /\ Goto(p, IF lkL[l].x = p THEN "al_open" ELSE "rp_fk",
                       [lv[p] EXCEPT !.pay = p, !.rem = Applied(p), !.ret = "tx_commit"])
               /\ UNCHANGED <<chC, chU, pyC, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

RpFk(p) ==
    /\ pc[p] = "rp_fk"
    /\ KsBlk(p, PInfo(p).lease) = {}
    /\ lkL' = GrantKs(p, PInfo(p).lease)
    /\ Goto(p, "al_open", lv[p])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* public.sync_portfolio_billing (membership) and private.run_daily_jobs   *)
(* (findings): both walk leases and call sync_lease_billing (hardening).  *)
(***************************************************************************)
SyOrder(s) == IF MutSyncUnordered /\ s = "S2" THEN <<"L2", "L1">> ELSE LeaseOrder
\* the loop's query: leases active in its snapshot, in its order
IsActiveC(l) == lsC[l].st = "active"

\* require role; enforce_rate_limit; portfolio key share; require role;
\* for v_lease_id in select id from leases where .. status = 'active'
\* order by l.id loop .. (cursor snapshot taken here)
SyStart(s) ==
    /\ pc[s] = "init"
    /\ GotoR(s, "sy_done", [LV0 EXCEPT !.ll = SelectSeq(SyOrder(s), IsActiveC)])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, lk, maint, resp, aborts, fifoBad>>

\* sync_lease_billing: select l.* from leases where id = .. FOR UPDATE; if
\* not found or status <> 'active' then return 0 (the newest version: a
\* lease ended while the loop ran is skipped).
SyLock(s) ==
    /\ pc[s] = "sy_lock"
    /\ LET l == lv[s].lease
           r == [lv[s] EXCEPT !.month = CurMonth, !.sret = "sy_done"]
       IN /\ MutNoSyncLock \/ UpdBlk(s, l) = {}
          /\ lkL' = IF MutNoSyncLock THEN lkL ELSE GrantUpd(s, l)
          /\ IF LeaseV(s, l).st = "active" \/ MutNoStatusRecheck
             THEN Goto(s, "sy_ins", r)
             ELSE GotoR(s, "sy_done", [r EXCEPT !.sk = @ + 1])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

\* run_daily_jobs: pg_try_advisory_xact_lock (one coordinator; another run
\* returns 'skipped'), then for v_lease in select .. where status = 'active'
\* and not maintained for the day order by l.id limit p_batch_size loop ..
JbStart(j) ==
    /\ pc[j] = "init"
    /\ IF ~MutJobNoTryLock /\ ~FreeFor(j, "job")
       THEN Finish(j, [OkResp EXCEPT !.code = "skipped"])
       ELSE LET order == IF MutJobUnordered THEN <<"L2", "L1">> ELSE LeaseOrder
                pend(l) == IsActiveC(l) /\ l \notin maint
            IN /\ lk' = IF MutJobNoTryLock THEN lk ELSE Grab(j, "job")
               /\ GotoR(j, "sy_done", [LV0 EXCEPT !.ll = SelectSeq(order, pend)])
               /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts,
                              fifoBad>>

\* The loop body, in a subtransaction: portfolio key share skip locked
\* (never contended here), then perform 1 from leases where id = .. for
\* update skip locked: a lease locked by a user is skipped (busy). Then
\* maintain_lease: FOR UPDATE again (held), status check, the monthly_rent
\* UPDATE (writes the rent in force, already in lsU here), sync_lease_billing
\* (FOR UPDATE again, status), then the lease_maintenance upsert (only the
\* job writes it; committed with the job in maint). A lease whose
\* subtransaction fails is rolled back alone; the model's job writes only
\* rows of that lease there, so that is the state of a skipped lease.
JbLock(j) ==
    /\ pc[j] = "jb_lock"
    /\ LET l == lv[j].lease
           r == [lv[j] EXCEPT !.month = CurMonth, !.sret = "sy_done"]
       IN IF UpdBlk(j, l) # {}
          THEN /\ ~MutJobWait
               /\ GotoR(j, "sy_done", [r EXCEPT !.busy = @ + 1])
               /\ UNCHANGED lkL
          ELSE /\ lkL' = GrantUpd(j, l)
               /\ IF LeaseV(j, l).st = "active"
                  THEN Goto(j, "sy_ins", [r EXCEPT !.mt = @ \cup {l}])
                  ELSE GotoR(j, "sy_done", [r EXCEPT !.mt = @ \cup {l}, !.sk = @ + 1])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

\* sync_lease_billing (hardening), after the lease lock: v_latest = max
\* period_month of the lease's auto rent; months after it up to the target
\* month (CurMonth for syncs and the job, the move-out month for end_lease):
\* only month 2 can be missing here. insert into charges (.. 'rent', month,
\* amount from rent_changes ..) on conflict (lease_id, period_month) where
\* kind = 'rent' do nothing; if v_created > 0 then apply_lease_credit.
\* Mutant no_rent_unique: no index, the v_latest read is the only guard.
NeedRent(s) == LET r == lv[s] IN
               r.month >= CurMonth /\ ~\E x \in RentRowsOf(r.lease) : ChV(s, x).ex
RentPend(s, l) == {x \in RentRowsOf(l) \ {RentId(s, l)} : ~chC[x].ex /\ chU[x].ex}
RentBlk(s) == IF ~NeedRent(s) \/ MutNoRentUnique THEN {}
              ELSE {lk["ch" \o x] : x \in RentPend(s, lv[s].lease)}
SyIns(s) ==
    /\ pc[s] = "sy_ins"
    /\ RentBlk(s) = {}
    /\ LET r == lv[s]
           l == r.lease
           own == RentId(s, l)
           conflict == ~MutNoRentUnique /\ \E x \in RentRowsOf(l) \ {own} : chC[x].ex
       IN IF ~NeedRent(s) \/ conflict
          THEN /\ GotoR(s, r.sret, r)
               /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, lk, maint, resp,
                              aborts, fifoBad>>
          ELSE /\ chU' = [chU EXCEPT ![own] = [ex |-> TRUE, paid |-> 0,
                                               amt |-> LeaseV(s, l).rent, vd |-> FALSE]]
               /\ lk' = Grab(s, "ch" \o own)
               \* FK charges_lease_fkey: KEY SHARE on the lease (no-op under FOR UPDATE)
               /\ IF lkL[l].x = s THEN GotoR(s, IF MutSyncNoCredit THEN r.sret ELSE "cr_list",
                                              [r EXCEPT !.cret = r.sret])
                  ELSE Goto(s, "sy_fk", [r EXCEPT !.cret = r.sret])
               /\ UNCHANGED <<chC, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

SyFk(s) ==
    /\ pc[s] = "sy_fk"
    /\ KsBlk(s, lv[s].lease) = {}
    /\ lkL' = GrantKs(s, lv[s].lease)
    /\ GotoR(s, IF MutSyncNoCredit THEN lv[s].sret ELSE "cr_list", lv[s])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* public.void_payment (hardening)                                         *)
(***************************************************************************)
\* select p.lease_id from payments where id = $1 (a payment the user saw:
\* committed; lease_id never changes); lock_lease_for_write.
VoTargets == {q \in PayIds : Intent(q) = VoidIntent}
VoStart(v) ==
    /\ pc[v] = "init"
    /\ \E q \in VoTargets :
         /\ pyC[q].ex
         /\ LET l == PInfo(q).lease IN
            /\ LeaseLockFree(v, l, TRUE)
            /\ lkL' = LeaseLockGrant(v, l, TRUE)
            /\ Goto(v, "vo_pay", [LV0 EXCEPT !.pay = q, !.lease = l])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

\* No void is sent: the payment it names never committed.
VoSkip(v) ==
    /\ pc[v] = "init"
    /\ \A r \in VoTargets : pc[r] = "done"
    /\ \A q \in VoTargets : ~pyC[q].ex
    /\ pc' = [pc EXCEPT ![v] = "done"]
    /\ UNCHANGED <<lv, chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, lk, maint, resp, aborts, fifoBad>>

\* the allocations to reverse, ORDER BY c.due_date, c.id
RevList(row) == LET s == SortCh({c \in ChargeIds : row.al[c] > 0}, <<>>)
                IN [i \in 1..Len(s) |-> <<s[i], row.al[s[i]]>>]
\* delete from payment_allocations where payment_id = ..; update payments
\* set voided_at = now(), .., allocated_amount = 0 (rows the caller locked)
Voided(row) == IF MutVoidKeepsAllocs THEN [row EXCEPT !.alloc = 0, !.voided = TRUE]
               ELSE [row EXCEPT !.al = ZeroAl, !.alloc = 0, !.voided = TRUE]
AfterVoid(v, r) == GotoR(v, IF MutVoidNoCredit THEN "tx_commit" ELSE "cr_list",
                         [r EXCEPT !.rv = <<>>, !.cret = "tx_commit"])

\* select p.* from payments where id = $1 for update; voided already (a
\* retried void): return payment_result (COMMIT, success).
VoPay(v) ==
    /\ pc[v] = "vo_pay"
    /\ LET r == lv[v]
           q == r.pay
           o == "py" \o q
       IN /\ FreeFor(v, o)
          /\ LET row == pyU[q] IN
             IF row.voided
             THEN IF MutVoidRejectsVoided THEN Fail(v, "already_voided")
                  ELSE Finish(v, [OkResp EXCEPT !.pay = q, !.rc = row.rc, !.code = "replayed"])
             ELSE IF RevList(row) = <<>>
                  THEN /\ lk' = Grab(v, o)
                       /\ pyU' = [pyU EXCEPT ![q] = Voided(row)]
                       /\ AfterVoid(v, r)
                       /\ UNCHANGED <<chC, chU, pyC, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts,
                                      fifoBad>>
                  ELSE /\ lk' = Grab(v, o)
                       /\ Goto(v, "vo_rev", [r EXCEPT !.rv = RevList(row)])
                       /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp,
                                      aborts, fifoBad>>

\* for each allocation: update charges set paid_amount = paid_amount - a
VoRev(v) ==
    /\ pc[v] = "vo_rev"
    /\ LET r == lv[v]
           c == Head(r.rv)[1]
           a == Head(r.rv)[2]
           o == "ch" \o c
           q == r.pay
       IN /\ FreeFor(v, o)
          /\ lk' = Grab(v, o)
          /\ chU' = [chU EXCEPT ![c] = [@ EXCEPT !.paid = @ - a]]
          /\ IF Tail(r.rv) = <<>>
             THEN /\ pyU' = [pyU EXCEPT ![q] = Voided(@)]
                  /\ AfterVoid(v, r)
             ELSE /\ UNCHANGED pyU
                  /\ Goto(v, "vo_rev", [r EXCEPT !.rv = Tail(r.rv)])
    /\ UNCHANGED <<chC, pyC, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* public.end_lease (ledger findings), public.change_rent (ledger)        *)
(***************************************************************************)
\* end_lease: lock_lease_for_write; status <> 'active' -> 'lease_not_active';
\* sync_lease_billing(lease, p_moved_out_on) (lock held; status active).
ElStart(e) ==
    /\ pc[e] = "init"
    /\ UpdBlk(e, ElLease) = {}
    /\ IF lsC[ElLease].st # "active"
       THEN Fail(e, "lease_not_active")
       ELSE /\ lkL' = GrantUpd(e, ElLease)
            /\ Goto(e, "sy_ins", [LV0 EXCEPT !.lease = ElLease, !.month = ElMonth,
                                             !.sret = "el_void"])
            /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts,
                           fifoBad>>

\* The later live rent locked in due order, its allocations reversed
\* (paid_amount, the allocations, payments.allocated_amount), update charges
\* set voided_at = now() .. where id = any (later rent); apply_lease_credit;
\* update leases set status = 'ended', moved_out_on .. (rows the caller
\* locks; one step: every other writer of them holds the lease first). Its
\* late fees are voided too, but there are none here (../LateFees).
\* Mutant el_no_release (the code before ledger findings): only later rent
\* with paid_amount = 0 is voided, nothing is released, no credit applied.
ElLater(e) == {x \in RentRowsOf(ElLease) : LET row == ChV(e, x) IN
                 row.ex /\ ~row.vd /\ ChInfo[x].period > ElMonth}
ElVoidRows(e) == {x \in ElLater(e) : ElReleases \/ ChV(e, x).paid = 0}
ElPays(e) == {q \in PayIds : \E x \in ElVoidRows(e) : PyV(e, q).al[x] > 0}
ElObjs(e) == {"ch" \o x : x \in ElVoidRows(e)} \cup {"py" \o q : q \in ElPays(e)}
ElVoid(e) ==
    /\ pc[e] = "el_void"
    /\ Holders(e, ElObjs(e)) = {}
    /\ LET rows == ElVoidRows(e)
           pays == ElPays(e)
       IN /\ chU' = [c \in ChargeIds |->
                       IF c \in rows THEN [ChV(e, c) EXCEPT !.paid = 0, !.vd = TRUE] ELSE chU[c]]
          /\ pyU' = [q \in PayIds |->
                       IF q \in pays
                       THEN LET row == PyV(e, q)
                                freed == SumF(row.al, rows)
                            IN [row EXCEPT !.al = [c \in ChargeIds |-> IF c \in rows THEN 0 ELSE row.al[c]],
                                           !.alloc = @ - freed]
                       ELSE pyU[q]]
          /\ lk' = GrabAll(e, ElObjs(e))
          /\ lsU' = [lsU EXCEPT ![ElLease] = [@ EXCEPT !.st = "ended", !.mo = ElMonth]]
          /\ GotoR(e, IF ElReleases THEN "cr_list" ELSE "tx_commit",
                   [lv[e] EXCEPT !.cret = "tx_commit"])
    /\ UNCHANGED <<chC, pyC, ctC, ctU, lsC, lkL, maint, resp, aborts, fifoBad>>

\* change_rent: lock_lease_for_write; status check -> 'lease_not_active'.
CrStart(c) ==
    /\ pc[c] = "init"
    /\ UpdBlk(c, CrLease) = {}
    /\ IF lsC[CrLease].st # "active"
       THEN Fail(c, "lease_not_active")
       ELSE /\ lkL' = GrantUpd(c, CrLease)
            /\ Goto(c, "cr_upd", [LV0 EXCEPT !.lease = CrLease])
            /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts,
                           fifoBad>>

\* insert into rent_changes .. on conflict do update (from month 2, under
\* the lease lock); update charges set amount = new rent where lease, kind
\* 'rent', source 'auto_rent', period_month >= month, not voided,
\* paid_amount = 0 and waived_amount = 0; update leases set monthly_rent.
CrRows(c) == {x \in RentRowsOf(CrLease) : LET row == ChV(c, x) IN
                row.ex /\ ~row.vd /\ row.paid = 0 /\ ~MutCrNoReprice}
CrUpd(c) ==
    /\ pc[c] = "cr_upd"
    /\ Holders(c, {"ch" \o x : x \in CrRows(c)}) = {}
    /\ chU' = [x \in ChargeIds |-> IF x \in CrRows(c) THEN [ChV(c, x) EXCEPT !.amt = CrRent]
                                   ELSE chU[x]]
    /\ lk' = GrabAll(c, {"ch" \o x : x \in CrRows(c)})
    /\ lsU' = [lsU EXCEPT ![CrLease] = [@ EXCEPT !.rent = CrRent]]
    /\ Goto(c, "tx_commit", lv[c])
    /\ UNCHANGED <<chC, pyC, pyU, ctC, ctU, lsC, lkL, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* A client's manual charge: insert into charges (source 'manual') through *)
(* the Data API (findings: statement trigger charges_before_insert_lock_   *)
(* portfolios takes the portfolio keys; row trigger                        *)
(* before_manual_charge_insert locks the lease FOR UPDATE; the insert; its *)
(* FK checks (lease KEY SHARE: held); after_manual_charge_insert           *)
(* (membership) applies the lease's credit.)                               *)
(* Mutant mc_lock_after_fk (ledger.sql): insert, FK KEY SHARE on the       *)
(* lease, then FOR UPDATE in the AFTER trigger: a lock upgrade.            *)
(***************************************************************************)
McAfter(m, r) == GotoR(m, IF MutMcNoCredit THEN "tx_commit" ELSE "cr_list",
                       [r EXCEPT !.cret = "tx_commit"])
McStart(m) ==
    /\ pc[m] = "init"
    /\ IF MutMcLockAfterFk
       THEN /\ chU' = [chU EXCEPT ![ManualId(m)] = [ex |-> TRUE, paid |-> 0, amt |-> 1, vd |-> FALSE]]
            /\ lk' = Grab(m, "ch" \o ManualId(m))
            /\ Goto(m, "mc_fk", [LV0 EXCEPT !.lease = "L1"])
            /\ UNCHANGED lkL
       ELSE /\ UpdBlk(m, "L1") = {}
            /\ lkL' = GrantUpd(m, "L1")
            /\ Goto(m, "mc_ins", [LV0 EXCEPT !.lease = "L1"])
            /\ UNCHANGED <<chU, lk>>
    /\ UNCHANGED <<chC, pyC, pyU, ctC, ctU, lsC, lsU, maint, resp, aborts, fifoBad>>

McIns(m) ==
    /\ pc[m] = "mc_ins"
    /\ chU' = [chU EXCEPT ![ManualId(m)] = [ex |-> TRUE, paid |-> 0, amt |-> 1, vd |-> FALSE]]
    /\ lk' = Grab(m, "ch" \o ManualId(m))
    /\ McAfter(m, lv[m])
    /\ UNCHANGED <<chC, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

McFk(m) ==
    /\ pc[m] = "mc_fk"
    /\ KsBlk(m, "L1") = {}
    /\ lkL' = GrantKs(m, "L1")
    /\ Goto(m, "mc_lock", lv[m])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

McLock(m) ==
    /\ pc[m] = "mc_lock"
    /\ UpdBlk(m, "L1") = {}
    /\ lkL' = GrantUpd(m, "L1")
    /\ McAfter(m, lv[m])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* A client's charge edits through public.update_charge (ledger           *)
(* findings): lock_lease_for_write (portfolio key, then the lease FOR      *)
(* UPDATE), then each charge FOR UPDATE, the rules ('charge_voided'; an    *)
(* amount change of a non-manual charge -> 'charge_not_editable'), the     *)
(* write, and apply_lease_credit after an amount change. CU edits two      *)
(* charges in one transaction (two calls; PostgREST runs each call in its  *)
(* own transaction, which only releases the lease in between).             *)
(* Mutant cu_no_lease_lock is the client UPDATE of charges before ledger   *)
(* findings (grant update (due_date, amount, description); policy          *)
(* charges_update took the portfolio keys only): rows locked in scan       *)
(* order, no lease lock. Mutant cu_no_credit applies no credit.            *)
(***************************************************************************)
CuStart(u) ==
    /\ pc[u] = "init"
    /\ Goto(u, IF CuLocksLease THEN "cu_lease" ELSE "cu_row",
            [LV0 EXCEPT !.rows = CuRows, !.lease = CuLease])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lkL, lk, maint, resp, aborts, fifoBad>>

CuLeaseLock(u) ==
    /\ pc[u] = "cu_lease"
    /\ UpdBlk(u, CuLease) = {}
    /\ lkL' = GrantUpd(u, CuLease)
    /\ Goto(u, "cu_row", lv[u])
    /\ UNCHANGED <<chC, chU, pyC, pyU, ctC, ctU, lsC, lsU, lk, maint, resp, aborts, fifoBad>>

CuRow(u) ==
    /\ pc[u] = "cu_row"
    /\ LET r == lv[u]
           c == Head(r.rows)
           o == "ch" \o c
           row == chU[c]
       IN /\ FreeFor(u, o)
          /\ IF row.vd THEN Fail(u, "charge_voided")
             ELSE IF CuEdit = "amount" /\ ChInfo[c].kind # "manual" THEN Fail(u, "charge_not_editable")
             ELSE /\ lk' = Grab(u, o)
                  /\ chU' = [chU EXCEPT ![c] = IF CuEdit = "amount" THEN [@ EXCEPT !.amt = @ + 1] ELSE @]
                  /\ IF Tail(r.rows) # <<>>
                     THEN Goto(u, "cu_row", [r EXCEPT !.rows = Tail(r.rows)])
                     ELSE GotoR(u, IF CuAppliesCredit /\ CuEdit = "amount" THEN "cr_list" ELSE "tx_commit",
                                [r EXCEPT !.rows = <<>>, !.cret = "tx_commit"])
                  /\ UNCHANGED <<chC, pyC, pyU, ctC, ctU, lsC, lsU, lkL, maint, resp, aborts, fifoBad>>

(***************************************************************************)
(* Commit, spontaneous abort, termination                                  *)
(***************************************************************************)
TxCommit(p) ==
    /\ pc[p] = "tx_commit"
    /\ Finish(p, IF p \in Reqs THEN [OkResp EXCEPT !.rc = lv[p].rc, !.pay = p]
                 ELSE [OkResp EXCEPT !.busy = lv[p].busy])

\* client gone, timeout, statement timeout or a 429, before COMMIT
SpontAbort(p) ==
    /\ pc[p] \notin {"init", "done"}
    /\ aborts < MAX_ABORTS
    /\ aborts' = aborts + 1
    /\ FailBase(p, "transient")

Terminated == /\ \A p \in Procs : pc[p] = "done"
              /\ UNCHANGED vars

Next ==
    \/ \E p \in Reqs : RpStart(p) \/ RpIdem(p) \/ RpCounter(p) \/ RpInsert(p) \/ RpFk(p)
    \/ \E s \in Syncs : SyStart(s) \/ SyLock(s)
    \/ \E j \in Jobs : JbStart(j) \/ JbLock(j)
    \/ \E s \in RentWriters : SyIns(s) \/ SyFk(s)
    \/ \E v \in Voids : VoStart(v) \/ VoSkip(v) \/ VoPay(v) \/ VoRev(v)
    \/ \E e \in Ends : ElStart(e) \/ ElVoid(e)
    \/ \E c \in RentChanges : CrStart(c) \/ CrUpd(c)
    \/ \E m \in Manuals : McStart(m) \/ McIns(m) \/ McFk(m) \/ McLock(m)
    \/ \E u \in Edits : CuStart(u) \/ CuLeaseLock(u) \/ CuRow(u)
    \/ \E p \in Procs : AlOpen(p) \/ AlLockPay(p) \/ AlFetch(p) \/ CrList(p)
                          \/ TxCommit(p) \/ SpontAbort(p)
    \/ Terminated

Spec == Init /\ [][Next]_vars

(***************************************************************************)
(* Wait-for graph: the transactions p waits for in its current step        *)
(***************************************************************************)
InitLease(p) == CASE p \in Reqs -> IF MutNoLeaseLock THEN NoP ELSE PInfo(p).lease
                  [] p \in Voids -> IF MutNoLeaseLock THEN NoP ELSE PInfo(CHOOSE q \in VoTargets : TRUE).lease
                  [] p \in Ends -> ElLease
                  [] p \in RentChanges -> CrLease
                  [] p \in Manuals -> IF MutMcLockAfterFk THEN NoP ELSE "L1"
                  [] OTHER -> NoP
Blockers(p) ==
    CASE pc[p] = "init" -> IF InitLease(p) = NoP THEN {} ELSE UpdBlk(p, InitLease(p))
      [] pc[p] = "rp_idem" /\ ~MutNoIdemLock -> Holders(p, {"ad" \o PInfo(p).key})
      [] pc[p] = "rp_counter" /\ ~MutSeqCounter -> Holders(p, {"ct"})
      [] pc[p] = "rp_insert" -> InsBlk(p)
      [] pc[p] = "rp_fk" -> KsBlk(p, PInfo(p).lease)
      [] pc[p] = "al_lockpay" -> Holders(p, {"py" \o lv[p].pay})
      [] pc[p] = "al_fetch" -> Holders(p, {"ch" \o Head(lv[p].cur)})
      [] pc[p] = "sy_lock" /\ ~MutNoSyncLock -> UpdBlk(p, lv[p].lease)
      [] pc[p] = "jb_lock" /\ MutJobWait -> UpdBlk(p, lv[p].lease)
      [] pc[p] = "sy_ins" -> RentBlk(p)
      [] pc[p] = "sy_fk" -> KsBlk(p, lv[p].lease)
      [] pc[p] = "vo_pay" -> Holders(p, {"py" \o lv[p].pay})
      [] pc[p] = "vo_rev" -> Holders(p, {"ch" \o Head(lv[p].rv)[1]})
      [] pc[p] = "el_void" -> Holders(p, ElObjs(p))
      [] pc[p] = "cr_upd" -> Holders(p, {"ch" \o x : x \in CrRows(p)})
      [] pc[p] = "mc_fk" -> KsBlk(p, "L1")
      [] pc[p] = "mc_lock" -> UpdBlk(p, "L1")
      [] pc[p] = "cu_lease" -> UpdBlk(p, CuLease)
      [] pc[p] = "cu_row" -> Holders(p, {"ch" \o Head(lv[p].rows)})
      [] OTHER -> {}

RECURSIVE Reach(_, _)
Reach(S, n) == IF n = 0 THEN S ELSE Reach(S \cup UNION {Blockers(x) : x \in S}, n - 1)

(***************************************************************************)
(* Properties                                                              *)
(***************************************************************************)
CPays == {q \in PayIds : pyC[q].ex}
Key(q) == PInfo(q).key
SumAl(c) == SumF([q \in CPays |-> pyC[q].al[c]], CPays)

TypeOK ==
    /\ pc \in [Procs -> Labels]
    /\ chC \in [ChargeIds -> [ex : BOOLEAN, paid : Int, amt : Int, vd : BOOLEAN]]
    /\ chU \in [ChargeIds -> [ex : BOOLEAN, paid : Int, amt : Int, vd : BOOLEAN]]
    /\ \A q \in PayIds : pyC[q].ex \in BOOLEAN /\ pyC[q].alloc \in Int /\ pyC[q].rc \in Int
    /\ ctC \in [ex : BOOLEAN, val : Int] /\ ctU \in [ex : BOOLEAN, val : Int]
    /\ lsC \in [Leases -> [st : {"active", "ended"}, mo : 0..CurMonth, rent : Int]]
    /\ lk \in [LockObjs -> Procs \cup {NoP}]
    /\ \A l \in Leases : lkL[l].x \in Procs \cup {NoP} /\ lkL[l].ks \subseteq Procs
    /\ maint \subseteq Leases
    /\ aborts \in 0..MAX_ABORTS
    /\ fifoBad \in BOOLEAN

\* (1) at most one committed payment per idempotency key, and never two
\*     payments for one intent
Inv1_IdemUnique ==
    /\ \A q1, q2 \in CPays : q1 # q2 => Key(q1) # Key(q2)
    /\ \A q1, q2 \in CPays : q1 # q2 => Intent(q1) # Intent(q2)

\* (2) a success names THE committed payment of its key, created by the
\*     same request (fingerprint), with the receipt that was committed
Inv2_ClientContract ==
    \A r \in Reqs : resp[r].k = "ok" =>
        /\ Cardinality({q \in CPays : Key(q) = Key(r)}) = 1
        /\ \A q \in CPays : Key(q) = Key(r) =>
              /\ q = resp[r].pay
              /\ pyC[q].rc = resp[r].rc
              /\ Intent(q) = Intent(r)

\* (2) a retry is never refused for its key: a request is refused for its
\*     key ('idempotency_key_reused' or a raw unique_violation) only when a
\*     committed payment with the key came from a different request
Inv2_RetryNeverRejected ==
    \A r \in Reqs : resp[r].k = "err" /\ resp[r].code \in {"idem_reused", "unique_idem"} =>
        \E q \in CPays : Key(q) = Key(r) /\ Intent(q) # Intent(r)

\* (2) 'idempotency_key_reused' only when a committed payment with the key
\*     came from a different request
Inv2_RejectOnlyOnConflict ==
    \A r \in Reqs : resp[r].k = "err" /\ resp[r].code = "idem_reused" =>
        \E q \in CPays : Key(q) = Key(r) /\ Intent(q) # Intent(r)

\* (2) clients only see documented errors (app.fail keys, or a transient
\*     failure: timeout, lost connection, 429)
DocumentedCodes == {"transient", "idem_reused", "invalid_selection", "lease_not_active",
                    "charge_voided", "charge_not_editable"}
Inv2_DocumentedErrorsOnly ==
    \A p \in Procs : resp[p].k = "err" => resp[p].code \in DocumentedCodes

\* (2) a void (and its retry) never fails except transiently
Inv2_VoidRetrySucceeds ==
    \A v \in Voids : resp[v].k = "err" => resp[v].code = "transient"

\* (3) committed receipt numbers are exactly 1..N, unique and gapless at
\*     every instant, whatever aborted or is still running
Inv3_ReceiptsGapless ==
    /\ {pyC[q].rc : q \in CPays} \cup (1..COUNTER_START) = 1..(COUNTER_START + Cardinality(CPays))
    /\ \A q1, q2 \in CPays : q1 # q2 => Fmt(pyC[q1].rc) # Fmt(pyC[q2].rc)
    /\ \A q \in CPays : Fmt(pyC[q].rc) \notin OldReceipts
\* (3) the committed counter (last_value) is exactly N
CounterVal == IF ctC.ex THEN ctC.val ELSE 0
Inv3_CounterMatches == CounterVal = COUNTER_START + Cardinality(CPays)
\* (3) issuing a receipt never collides with an existing one
Inv3_NoReceiptCollision == \A p \in Reqs : resp[p].code # "unique_receipt"

\* (4) per charge: paid = sum of its allocations; 0 <= paid <= amount
\*     (never overpaid); a voided charge has nothing paid
Inv4_ChargePaid ==
    \A c \in ChargeIds :
        /\ chC[c].paid = SumAl(c)
        /\ 0 <= chC[c].paid /\ chC[c].paid <= chC[c].amt
        /\ ~chC[c].ex => chC[c].paid = 0
        /\ chC[c].vd => chC[c].paid = 0

\* (5) per payment: allocated = sum of its allocations <= amount + tax;
\*     a voided payment has no allocations; nothing goes to a voided charge
Inv5_PaymentAlloc ==
    \A q \in CPays :
        /\ pyC[q].alloc = SumF(pyC[q].al, ChargeIds)
        /\ \A c \in ChargeIds : pyC[q].al[c] >= 0
        /\ 0 <= pyC[q].alloc /\ pyC[q].alloc <= Applied(q)
        /\ pyC[q].voided => \A c \in ChargeIds : pyC[q].al[c] = 0

\* (6) at most one rent charge per (lease, month)
Inv6_OneRentPerMonth ==
    \A l \in Leases : Cardinality({r \in RentRowsOf(l) : chC[r].ex}) <= 1

\* (7) allocation is FIFO (checked at every commit, see FifoBroken)
Inv7_FIFO == ~fifoBad

\* (8) no cycle in the wait-for graph (PostgreSQL would abort a victim)
Inv8_NoWaitCycle == \A p \in Procs : p \notin Reach(Blockers(p), Cardinality(Procs))

\* (9) the daily job never waits for a lock
Inv9_JobNeverWaits == \A j \in Jobs : Blockers(j) = {}

\* (10) credit is applied: unallocated credit never coexists with an open
\*      due of the same lease (committed state)
InvCreditApplied ==
    \A l \in Leases :
        (\E q \in CPays : PInfo(q).lease = l /\ ~pyC[q].voided /\ pyC[q].alloc < Applied(q))
          => ~\E c \in ChargeIds : ChInfo[c].lease = l /\ OpenRow(chC[c])

\* (11) an ended lease has no unpaid rent for a month after the move-out
\*      (none is created after it ended, end_lease voided the rest)
InvEndedNoUnpaidLaterRent ==
    \A l \in Leases : lsC[l].st = "ended" =>
        \A r \in RentRowsOf(l) : (chC[r].ex /\ ~chC[r].vd /\ ChInfo[r].period > lsC[l].mo)
                                    => chC[r].paid > 0
\* (11) strict: an ended lease has no live rent after the move-out month
InvEndedNoLaterRent ==
    \A l \in Leases : lsC[l].st = "ended" =>
        \A r \in RentRowsOf(l) : ~(chC[r].ex /\ ~chC[r].vd /\ ChInfo[r].period > lsC[l].mo)

\* (12) untouched rent is priced at the rent in force for its month
InvRentPriced ==
    \A l \in Leases : \A r \in RentRowsOf(l) :
        (chC[r].ex /\ ~chC[r].vd /\ chC[r].paid = 0) => chC[r].amt = lsC[l].rent
=============================================================================
