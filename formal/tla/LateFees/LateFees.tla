------------------------------- MODULE LateFees -------------------------------
(***************************************************************************)
(* The automatic late-fee job of Maalik-e-Makaan, the payment path and the *)
(* other writers of a lease's dues, as the CURRENT code implements them.   *)
(* "hardening" is supabase/migrations/20261104143928_ledger_jobs_          *)
(* hardening.sql, "findings" is 20261105170557_concurrency_findings.sql,   *)
(* "ledger" is 20261103193658_ledger.sql, "latest" is                      *)
(* 20261105072426_membership_deletion_storage.sql and "ledger findings" is *)
(* 20261107181820_ledger_findings.sql (record_payment, end_lease,          *)
(* update_charge; the client UPDATE of charges is gone); each action names *)
(* the function it follows (always its last definition).                   *)
(*                                                                         *)
(* Granularity and locks follow ../Membership: one step per SQL statement, *)
(* or per row for a statement that locks rows one by one (the job's        *)
(* upsert, allocate_payment's cursor, a client's multi-row UPDATE).  Every *)
(* lock modelled here conflicts with every other one: the lease row is     *)
(* taken FOR UPDATE (job, RPCs) or FOR NO KEY UPDATE (a client's UPDATE of *)
(* leases), a charge row FOR UPDATE (allocate_payment) or FOR NO KEY       *)
(* UPDATE (an UPDATE, or ON CONFLICT DO UPDATE, which locks the existing   *)
(* row before it evaluates its WHERE).  A step that needs a lock another   *)
(* transaction holds is disabled; Need(t) lists the holders, and Detect is *)
(* PostgreSQL's deadlock detector (40P01 for one transaction on a cycle).  *)
(* Writes go to val at once with a pre-image (dirty/pre), so a rollback    *)
(* restores the rows and Committed(row) is what other snapshots see.       *)
(*                                                                         *)
(* Abstractions (argued in README.md):                                     *)
(*  * two leases of one portfolio; the portfolio key every writer takes    *)
(*    first is KEY SHARE, which conflicts with nothing modelled here       *)
(*    (deletions and membership changes are in ../Membership);             *)
(*  * rent dues exist from the start: sync_lease_billing's rent generation *)
(*    and credit application belong to ../LedgerPayments, and every path   *)
(*    that runs them holds the lease lock, as the job does;                *)
(*  * money is in paisa (numeric(14,2) x 100), with small values; the      *)
(*    numeric(14,2) bound 999999999999.99 rupees is scaled to MAX_RUPEES;  *)
(*  * days are integers; each rent is due on a fixed day.                  *)
(***************************************************************************)
EXTENDS Naturals, Integers, FiniteSets, Sequences, TLC

CONSTANTS
    SCENARIO,    \* processes and data (see Script, ScenarioProcs, InitData)
    MUTANT,      \* "none" = current code; otherwise one mechanism removed
    MAX_DAY      \* last day the clock reaches

Mutants == {"none",
            "no_unique_index",     \* charges_late_fee_key missing: a plain INSERT every day
            "index_live_only",     \* the unique index ignores voided fees (where voided_at is null)
            "no_cap",              \* app.late_fee_amount without least(..., cap)
            "round_after_cap",     \* the pre-hardening order: round(least(fee, cap))
            "no_clamp",            \* app.late_fee_amount without the numeric(14,2) clamp
            "no_grace_check",      \* no "p_days_late <= p_grace_days" and no WHERE grace test
            "no_outstanding_check",\* no "p_outstanding <= 0" and no WHERE outstanding > 0
            "no_growth_guard",     \* DO UPDATE without "excluded.amount > charges.amount"
            "no_paid_guard",       \* DO UPDATE without "paid_amount = 0 and waived_amount = 0"
            "no_void_guard",       \* DO UPDATE without "voided_at is null"
            "accumulate",          \* DO UPDATE SET amount = charges.amount + excluded.amount
            "no_maint_check",      \* the scan ignores lease_maintenance.maintained_on
            "rerun_accumulate",    \* both of the previous two
            "no_status_check",     \* maintain_lease/assess_late_fees trust the scan's status
            "stale_policy",        \* assess_late_fees uses the policy read by the scan
            "no_skip_locked",      \* run_daily_jobs waits for a busy lease (FOR UPDATE)
            "no_advisory_lock",    \* run_daily_jobs without pg_try_advisory_xact_lock
            "no_void_related",     \* void_charge voids the charge only, not its fee
            \* The fixes of findings F1-F3 (ledger findings), each removed:
            "no_backdated_void",   \* F1: record_payment keeps the fee of a rent it settles
                                   \* with a payment dated within grace
            "end_lease_keeps_fees",\* F3: end_lease voids later rent but not its fees
            "edit_no_lease_lock"}  \* F2: a client's charge edit is a multi-row UPDATE in scan
                                   \* order with no lease lock (policy charges_update)
ASSUME MUTANT \in Mutants /\ MAX_DAY \in Nat

Mut(m) == MUTANT = m \/ (MUTANT = "rerun_accumulate" /\ m \in {"no_maint_check", "accumulate"})
NoP == "-"

-----------------------------------------------------------------------------
(* Static data: leases, rent dues, payments.                               *)

Leases == {"L1", "L2"}
LeaseOrder == <<"L1", "L2">>                \* uuid order (run_daily_jobs: order by l.id)
Rents == {"r1", "r2", "r3"}
\* r1, r2: month 1 of L1, L2, due on day 0; r3: month 2 of L1, due on day 1
\* (end_lease scenario; a month is shorter than a real one to keep days few)
RentLease(c) == IF c = "r2" THEN "L2" ELSE "L1"
RentMonth(c) == IF c = "r3" THEN 2 ELSE 1
RentDue(c)   == IF c = "r3" THEN 1 ELSE 0
RentAmt      == 100000                      \* 1,000 rupees
RentIdOrder  == <<"r1", "r2", "r3">>        \* uuid v7 order (creation order)
MAXF == 2                                   \* fee rows per rent (a second: only in mutants)
FeeIdx == 1..MAXF
MAX_RUPEES == 999                           \* stands for 999999999999 (scaled)
MaxAmount == MAX_RUPEES * 100 + 99          \* numeric(14,2): 999999999999.99

\* Late-fee policies: type, value (paisa, or hundredths of a percent), cap
\* (paisa, daily only, 0 = null), grace days.  leases_late_fee_cap_type_check:
\* a cap only for 'daily'.
Pol(ty, v, cap, g) == [ty |-> ty, v |-> v, cap |-> cap, g |-> g]
Daily    == Pol("daily", 10000, 25000, 1)   \* 100 rupees a day, cap 250
DailyOdd == Pol("daily", 10000, 24950, 1)   \* cap 249.50 (the rounding case)
DailyBig == Pol("daily", 40000, 0, 1)       \* 400 a day, no cap (the clamp case)
Percent  == Pol("percent", 1000, 0, 1)      \* 10.00 %
Flat     == Pol("flat", 5000, 0, 1)         \* 50 rupees
NoFee    == Pol("none", 0, 0, 1)
LowCap   == Pol("daily", 10000, 15000, 1)   \* cap lowered to 150

Rows == {<<"L", l>> : l \in Leases} \cup {<<"M", l>> : l \in Leases} \cup {<<"R", c>> : c \in Rents}
        \cup {<<"F", c, i>> : c \in Rents, i \in FeeIdx} \cup {<<"P", p>> : p \in {"p1", "p2"}}
LR(l) == <<"L", l>>
MR(l) == <<"M", l>>                         \* private.lease_maintenance
RR(c) == <<"R", c>>
FR(c, i) == <<"F", c, i>>
PR(p) == <<"P", p>>
RowLease(r) == CASE r[1] \in {"L", "M"} -> r[2]
                 [] r[1] \in {"R", "F"} -> RentLease(r[2])
                 [] OTHER -> NoP

-----------------------------------------------------------------------------
(* Processes.  Script(t): kind k, lease l, target x, payment p, amount a,  *)
(* paid_on day d (-1 = the day it is recorded), earliest day e it runs,    *)
(* row sequence s (client UPDATE scan order), new policy n, month m.       *)
Pr(k, l, x, p, a, d, e, s, n, m) ==
    [k |-> k, l |-> l, x |-> x, p |-> p, a |-> a, d |-> d, e |-> e, s |-> s, n |-> n, m |-> m]
Script(t) ==
    CASE t = "J1"     -> Pr("job", NoP, NoP, NoP, 0, 0, 0, <<>>, NoFee, 0)
      [] t = "J2"     -> Pr("job", NoP, NoP, NoP, 0, 0, 0, <<>>, NoFee, 0)
      [] t = "J3"     -> Pr("job", NoP, NoP, NoP, 0, 0, 0, <<>>, NoFee, 0)
      \* record_payment on time, in full (rent first, then the fee)
      [] t = "pay1"   -> Pr("pay", "L1", NoP, "p1", 100000, -1, 0, <<>>, NoFee, 0)
      \* a part payment on time
      [] t = "part1"  -> Pr("pay", "L1", NoP, "p1", 40000, -1, 0, <<>>, NoFee, 0)
      \* paid within grace (day 1), recorded on day 2 or later (F1)
      [] t = "late1"  -> Pr("pay", "L1", NoP, "p1", 100000, 1, 2, <<>>, NoFee, 0)
      [] t = "pay2"   -> Pr("pay", "L2", NoP, "p2", 100000, -1, 0, <<>>, NoFee, 0)
      \* more than the rent, from day 2: the rest pays part of the fee
      [] t = "over1"  -> Pr("pay", "L1", NoP, "p1", 105000, -1, 2, <<>>, NoFee, 0)
      \* from day 2, part of the fee, chosen first (p_charge_ids = [the fee])
      [] t = "fee1"   -> Pr("pay", "L1", FR("r1", 1), "p1", 5000, -1, 2, <<>>, NoFee, 0)
      \* paid within grace (day 1), recorded from day 2, the fee chosen first:
      \* the fee is paid, then the rent; the fee is voided and its money released
      [] t = "gfee1"  -> Pr("pay", "L1", FR("r1", 1), "p1", 120000, 1, 2, <<>>, NoFee, 0)
      [] t = "vpay1"  -> Pr("voidpay", "L1", NoP, "p1", 0, 0, 0, <<>>, NoFee, 0)
      [] t = "vrent1" -> Pr("voidchg", "L1", RR("r1"), NoP, 0, 0, 0, <<>>, NoFee, 0)
      [] t = "vfee1"  -> Pr("voidchg", "L1", FR("r1", 1), NoP, 0, 0, 0, <<>>, NoFee, 0)
      [] t = "end1"   -> Pr("end", "L1", NoP, NoP, 0, 0, 0, <<>>, NoFee, 1)   \* moved out in month 1
      [] t = "polF"   -> Pr("policy", NoP, NoP, NoP, 0, 0, 0, <<LR("L1")>>, Flat, 0)
      [] t = "polLow" -> Pr("policy", NoP, NoP, NoP, 0, 0, 0, <<LR("L1")>>, LowCap, 0)
      [] t = "polOff" -> Pr("policy", NoP, NoP, NoP, 0, 0, 0, <<LR("L1")>>, NoFee, 0)
      \* a multi-row UPDATE of both leases, L2's row first in its scan order
      [] t = "polBulk"-> Pr("policy", NoP, NoP, NoP, 0, 0, 0, <<LR("L2"), LR("L1")>>, LowCap, 0)
      \* a client's multi-row UPDATE of charges (description), in scan order
      [] t = "editF"  -> Pr("edit", NoP, NoP, NoP, 0, 0, 0, <<FR("r2", 1), FR("r1", 1)>>, NoFee, 0)
      [] t = "editR"  -> Pr("edit", NoP, NoP, NoP, 0, 0, 0, <<FR("r1", 1), RR("r1")>>, NoFee, 0)

ScenarioProcs(s) ==
    CASE s = "rerun"       -> {"J1", "J2", "J3"}        \* overlapping and repeated runs
      [] s = "pay_mid_run" -> {"J1", "J2", "pay1", "vpay1"}
      [] s = "part_paid"   -> {"J1", "J2", "part1", "pay2"}
      [] s = "fee_paid"    -> {"J1", "J2", "fee1"}
      [] s = "backdated"   -> {"J1", "J2", "late1"}
      [] s = "backdated_fee" -> {"J1", "J2", "gfee1"}
      [] s = "end_lease"   -> {"J1", "J2", "end1"}
      [] s = "void_rent"   -> {"J1", "J2", "vrent1"}
      [] s = "void_fee"    -> {"J1", "J2", "vfee1"}
      [] s = "policy"      -> {"J1", "J2", "polF"}
      [] s = "policy_low"  -> {"J1", "J2", "polLow"}
      [] s = "policy_off"  -> {"J1", "polOff", "pay1"}
      [] s = "bulk_policy" -> {"J1", "polBulk", "pay2"}
      [] s = "edit_job"    -> {"J1", "editF"}
      [] s = "edit_pay"    -> {"over1", "editR"}
      [] s = "cap_round"   -> {"J1", "J2"}
      [] s = "clamp"       -> {"J1", "J2"}
      [] s = "percent"     -> {"J1", "J2", "part1"}
Procs == ScenarioProcs(SCENARIO)
ProcsOrNo == Procs \cup {NoP}
Kind(t) == Script(t).k

\* Each lease's initial policy, and the rents that exist.
InitPol(l) ==
    CASE SCENARIO = "cap_round" -> DailyOdd
      [] SCENARIO = "clamp"     -> DailyBig
      [] SCENARIO = "percent"   -> Percent
      [] SCENARIO = "policy"    -> IF l = "L1" THEN Daily ELSE Flat
      [] OTHER                  -> Daily
LiveRents == IF SCENARIO = "end_lease" THEN {"r1", "r2", "r3"} ELSE {"r1", "r2"}
\* edit_* scenarios start on day 2 with yesterday's fees posted (r2's at its cap)
StartDay == IF SCENARIO \in {"edit_job", "edit_pay"} THEN 2 ELSE 0
InitFee(c) ==
    IF SCENARIO \in {"edit_job", "edit_pay"} /\ c \in {"r1", "r2"}
    THEN [ex |-> TRUE, amt |-> IF c = "r2" THEN 25000 ELSE 10000, paid |-> 0, waived |-> 0,
          voided |-> FALSE, due |-> 1]
    ELSE [ex |-> FALSE, amt |-> 0, paid |-> 0, waived |-> 0, voided |-> FALSE, due |-> 0]
NoFeeRow == [ex |-> FALSE, amt |-> 0, paid |-> 0, waived |-> 0, voided |-> FALSE, due |-> 0]
NoPay == [ex |-> FALSE, voided |-> FALSE, amt |-> 0, on |-> 0, alloc |-> [r \in {} |-> 0]]

-----------------------------------------------------------------------------
VARIABLES
    today, \* app.today_pkt()
    val,   \* val[row]: the newest version of each row (committed or not)
    dirty, \* dirty[row]: the transaction with an uncommitted write of row
    pre,   \* pre[row]: the committed version under that write
    lk,    \* lk[row]: the holder of the row lock
    adv,   \* holder of pg_try_advisory_xact_lock(hashtext('...run_daily_jobs'))
    pc,    \* pc[t]: the next statement of t
    lv,    \* lv[t]: locals of t
    gh     \* ghost values for the properties

vars == <<today, val, dirty, pre, lk, adv, pc, lv, gh>>

Committed(r) == IF dirty[r] # NoP THEN pre[r] ELSE val[r]

\* Write v to row r in transaction t (keeping the committed pre-image once).
Wr(d, t, r, v) ==
    IF d.dirty[r] = t THEN [d EXCEPT !.val[r] = v]
    ELSE [d EXCEPT !.val[r] = v, !.pre[r] = d.val[r], !.dirty[r] = t]
Lock(d, t, r) == [d EXCEPT !.lk[r] = t]
DB == [val |-> val, dirty |-> dirty, pre |-> pre, lk |-> lk]
SetDB(d) == /\ val' = d.val /\ dirty' = d.dirty /\ pre' = d.pre /\ lk' = d.lk

\* Rollback of t's writes and locks on the rows in rs; commit of all of t.
Undo(d, t, rs) ==
    [d EXCEPT !.val   = [r \in Rows |-> IF r \in rs /\ d.dirty[r] = t THEN d.pre[r] ELSE d.val[r]],
              !.dirty = [r \in Rows |-> IF r \in rs /\ d.dirty[r] = t THEN NoP ELSE d.dirty[r]],
              !.lk    = [r \in Rows |-> IF r \in rs /\ d.lk[r] = t THEN NoP ELSE d.lk[r]]]
CommitAll(d, t) ==
    [d EXCEPT !.dirty = [r \in Rows |-> IF d.dirty[r] = t THEN NoP ELSE d.dirty[r]],
              !.lk    = [r \in Rows |-> IF d.lk[r] = t THEN NoP ELSE d.lk[r]]]

Blk(t, r) == {lk[r]} \ {t, NoP}            \* the other holder of r's lock, if any

Goto(t, l) == pc' = [pc EXCEPT ![t] = l]

-----------------------------------------------------------------------------
(* Ledger arithmetic.                                                       *)

Lse(l)     == val[LR(l)]
Rent(c)    == val[RR(c)]
Fee(c, i)  == val[FR(c, i)]
OutR(v)    == RentAmt - v.paid - v.waived
OutF(v)    == v.amt - v.paid - v.waived
LeaseRents(l) == {c \in LiveRents : RentLease(c) = l}

\* round(x, 0) of a positive numeric (half up) where x = num / den rupees.
RoundHalfUp(num, den) == (2 * num + den) \div (2 * den)
Min(a, b) == IF a < b THEN a ELSE b
Max(a, b) == IF a > b THEN a ELSE b

(* app.late_fee_amount (hardening), in paisa:                             *)
(*   case when type = 'none' or outstanding <= 0 or days_late <= grace     *)
(*        then 0                                                           *)
(*   else least(round(flat value | outstanding * value / 100 |            *)
(*                    value * days_late, 0),                               *)
(*              coalesce(case when type = 'daily' then cap end, 999999999999), *)
(*              999999999999) end                                          *)
LateFeeAmount(p, out, days) ==
    IF p.ty = "none"
       \/ (out <= 0 /\ ~Mut("no_outstanding_check"))
       \/ (days <= p.g /\ ~Mut("no_grace_check"))
    THEN 0
    ELSE LET \* the fee in rupees is num / den, exactly
             num == CASE p.ty = "flat"    -> p.v
                      [] p.ty = "percent" -> out * p.v       \* paisa x hundredths of a percent
                      [] OTHER            -> p.v * days
             den == IF p.ty = "percent" THEN 1000000 ELSE 100
             \* no_clamp: no bound at all (also no coalesce default), as before hardening
             clampP == IF Mut("no_clamp") THEN 1000000000 ELSE MAX_RUPEES * 100
             capP == IF p.ty = "daily" /\ p.cap > 0 /\ ~Mut("no_cap") THEN p.cap ELSE clampP
             rounded == RoundHalfUp(num, den) * 100
             \* round_after_cap: round(least(fee, cap), 0) (the code before hardening)
             early == IF num * 100 >= capP * den THEN RoundHalfUp(capP, 100) * 100 ELSE rounded
         IN IF Mut("round_after_cap") THEN Min(early, clampP)
            ELSE Min(Min(rounded, capP), clampP)

\* The amount the policy p defines (current code), for the properties.
TrueFee(p, out, days) ==
    IF p.ty = "none" \/ out <= 0 \/ days <= p.g THEN 0
    ELSE LET num == CASE p.ty = "flat" -> p.v [] p.ty = "percent" -> out * p.v
                      [] OTHER -> p.v * days
             den == IF p.ty = "percent" THEN 1000000 ELSE 100
             capP == IF p.ty = "daily" /\ p.cap > 0 THEN p.cap ELSE MAX_RUPEES * 100
         IN Min(Min(RoundHalfUp(num, den) * 100, capP), MAX_RUPEES * 100)

-----------------------------------------------------------------------------
(* private.run_daily_jobs (findings), private.maintain_lease and           *)
(* private.assess_late_fees (hardening), run by pg_cron every 10 minutes:  *)
(*   if not pg_try_advisory_xact_lock(...) then return skipped;            *)
(*   for each active lease not maintained for v_as_of, in id order:        *)
(*     begin (subtransaction)                                              *)
(*       portfolio for key share skip locked; lease for update skip locked *)
(*       (busy: next lease);                                               *)
(*       maintain_lease: lease for update, status = 'active' else return;  *)
(*         rent refresh and sync_lease_billing (abstracted, see header);   *)
(*         assess_late_fees: one INSERT ... SELECT ... ON CONFLICT         *)
(*           (related_charge_id) where kind = 'late_fee' and               *)
(*           related_charge_id is not null DO UPDATE SET amount =          *)
(*           excluded.amount WHERE voided_at is null and paid_amount = 0   *)
(*           and waived_amount = 0 and excluded.amount > amount;           *)
(*       insert into lease_maintenance (maintained_on = v_as_of)           *)
(*     exception when others: rollback to the subtransaction and record    *)
(*       the failure (maintained_on = v_as_of, failures + 1)               *)
(*   commit (every lease lock taken is held until here).                   *)
-----------------------------------------------------------------------------
IsJob(t) == Kind(t) = "job"

\* v_as_of := coalesce(p_as_of, app.today_pkt()); the advisory lock
J_Start(t) ==
    /\ IsJob(t) /\ pc[t] = "j_start"
    /\ lv' = [lv EXCEPT ![t].asof = today]
    /\ IF adv = NoP \/ Mut("no_advisory_lock")
       THEN /\ adv' = IF Mut("no_advisory_lock") THEN adv ELSE t
            /\ Goto(t, "j_scan")
       ELSE /\ UNCHANGED adv              \* an overlapping run: {"skipped": true}
            /\ Goto(t, "done")
    /\ UNCHANGED <<today, val, dirty, pre, lk, gh>>

\* The FOR loop's query (statement snapshot): committed rows only.
Pending(t, l) ==
    /\ Committed(LR(l)).st = "active"
    /\ (Mut("no_maint_check") \/ Committed(MR(l)).maint < lv[t].asof)
J_Scan(t) ==
    /\ IsJob(t) /\ pc[t] = "j_scan"
    /\ lv' = [lv EXCEPT ![t].todo = SelectSeq(LeaseOrder, LAMBDA l : Pending(t, l)),
                        ![t].snap = [l \in Leases |-> Committed(LR(l))]]
    /\ Goto(t, "j_lock")
    /\ UNCHANGED <<today, val, dirty, pre, lk, adv, gh>>

\* "perform 1 from public.leases l where l.id = ... for update skip locked"
J_Lock(t) ==
    /\ IsJob(t) /\ pc[t] = "j_lock"
    /\ IF lv[t].todo = <<>>
       THEN Goto(t, "j_commit") /\ UNCHANGED <<lv, val, dirty, pre, lk>>
       ELSE LET l == Head(lv[t].todo) IN
            IF Blk(t, LR(l)) = {}
            THEN /\ lk' = [lk EXCEPT ![LR(l)] = t]
                 /\ lv' = [lv EXCEPT ![t].cur = l]
                 /\ Goto(t, "j_maint")
                 /\ UNCHANGED <<val, dirty, pre>>
            ELSE /\ ~Mut("no_skip_locked")         \* not found: busy, next lease
                 /\ lv' = [lv EXCEPT ![t].todo = Tail(@)]
                 /\ UNCHANGED <<pc, val, dirty, pre, lk>>
    /\ UNCHANGED <<today, adv, gh>>

\* The rents assess_late_fees inserts or updates a fee for (WHERE clause and
\* f.fee > 0), in "order by c.due_date, c.id".
Candidates(t, l, p) ==
    LET ok(c) == /\ ~Rent(c).voided
                 /\ (OutR(Rent(c)) > 0 \/ Mut("no_outstanding_check"))
                 /\ (lv[t].asof - RentDue(c) > p.g \/ Mut("no_grace_check"))
                 /\ LateFeeAmount(p, OutR(Rent(c)), lv[t].asof - RentDue(c)) > 0
    IN SelectSeq(RentIdOrder, LAMBDA c : c \in LeaseRents(l) /\ ok(c))

\* private.maintain_lease: the lease again FOR UPDATE (held), "if not found or
\* v_lease.status <> 'active' then return"; then assess_late_fees reads the
\* lease (its policy) and starts its INSERT ... SELECT.
J_Maint(t) ==
    /\ IsJob(t) /\ pc[t] = "j_maint"
    /\ LET l == lv[t].cur
           st == IF Mut("no_status_check") THEN lv[t].snap[l].st ELSE Lse(l).st
           p == IF Mut("stale_policy") THEN lv[t].snap[l].pol ELSE Lse(l).pol
       IN IF st # "active" \/ p.ty = "none"
          THEN /\ lv' = [lv EXCEPT ![t].cs = <<>>, ![t].pol = p]
          ELSE /\ lv' = [lv EXCEPT ![t].cs = Candidates(t, l, p), ![t].pol = p]
    /\ Goto(t, "j_fee")
    /\ UNCHANGED <<today, val, dirty, pre, lk, adv, gh>>

\* The existing fee row the INSERT conflicts with (charges_late_fee_key).
Conflicting(c) ==
    IF Mut("no_unique_index") THEN {}
    ELSE {i \in FeeIdx : Fee(c, i).ex /\ (~Mut("index_live_only") \/ ~Fee(c, i).voided)}
FreeIdx(c) == {i \in FeeIdx : ~Fee(c, i).ex}

\* "exception when others" in the loop: ROLLBACK TO the lease's subtransaction
\* (its writes and the locks it took, the lease lock included), then the
\* failure row: maintained_on = v_as_of, failures + 1 (retried the next day).
LeaseRows(l) == {r \in Rows : RowLease(r) = l}
JobLeaseFailed(t, l) ==
    LET d == Undo(DB, t, LeaseRows(l) \ {MR(l)}) IN
    Lock(Wr(d, t, MR(l), [d.val[MR(l)] EXCEPT !.maint = lv[t].asof, !.fails = @ + 1]), t, MR(l))

\* The DO UPDATE's WHERE (mutants drop a part of it).
Guard(f, new) ==
    /\ (~f.voided \/ Mut("no_void_guard"))
    /\ ((f.paid = 0 /\ f.waived = 0) \/ Mut("no_paid_guard"))
    /\ (new > f.amt \/ Mut("no_growth_guard") \/ Mut("accumulate"))

\* Ghost record of one fee write by the job (f: the row before, nf: after).
FeeGhost(t, c, l, f, nf) ==
    LET days == lv[t].asof - RentDue(c)
        out == OutR(Rent(c))
        trueP == Lse(l).pol
        tf == TrueFee(trueP, out, days)
    IN [gh EXCEPT
          !.notOverdue = @ \/ ~(days > trueP.g /\ out > 0 /\ ~Rent(c).voided),
          !.overCap    = @ \/ (trueP.ty = "daily" /\ trueP.cap > 0 /\ nf.amt > trueP.cap),
          !.inactive   = @ \/ Lse(l).st # "active",
          !.stalePol   = @ \/ lv[t].pol # trueP,
          !.touched    = @ \/ (f.ex /\ (f.voided \/ f.paid > 0 \/ f.waived > 0)),
          !.lowered    = @ \/ (f.ex /\ nf.amt < f.amt),
          !.raised     = @ \/ (f.ex /\ nf.amt > f.amt),
          !.maxTrue[c] = Max(@, tf),
          !.aboveTrue  = @ \/ nf.amt > Max(gh.maxTrue[c], tf),
          \* a second assessment for the same day, with the same inputs, that
          \* finds the row as the first one left it
          !.notIdem    = @ \/ (gh.last[c] = <<lv[t].asof, out, trueP, f>> /\ nf # f),
          !.last[c]    = <<lv[t].asof, out, trueP, nf>>]

\* One row of the INSERT ... ON CONFLICT DO UPDATE.  The excluded row is built
\* first (a fee above numeric(14,2) fails there: numeric field overflow, and
\* the lease's subtransaction is rolled back and recorded as failed); then
\* the conflicting row is locked and the WHERE evaluated, or the row inserted.
J_Fee(t) ==
    /\ IsJob(t) /\ pc[t] = "j_fee"
    /\ LET l == lv[t].cur IN
       IF lv[t].cs = <<>>
       THEN \* insert into private.lease_maintenance (maintained_on = v_as_of)
            /\ SetDB(Lock(Wr(DB, t, MR(l), [val[MR(l)] EXCEPT !.maint = lv[t].asof]), t, MR(l)))
            /\ lv' = [lv EXCEPT ![t].todo = Tail(@)]
            /\ Goto(t, "j_lock")
            /\ UNCHANGED gh
       ELSE LET c == Head(lv[t].cs)
                new0 == LateFeeAmount(lv[t].pol, OutR(Rent(c)), lv[t].asof - RentDue(c))
            IN IF new0 > MaxAmount
               THEN /\ SetDB(JobLeaseFailed(t, l))
                    /\ gh' = [gh EXCEPT !.overflow = TRUE]
                    /\ lv' = [lv EXCEPT ![t].todo = Tail(@), ![t].cs = <<>>]
                    /\ Goto(t, "j_lock")
               ELSE IF Conflicting(c) # {}
               THEN LET i == CHOOSE i \in Conflicting(c) : TRUE
                        f == Fee(c, i)
                        new == IF Mut("accumulate") THEN f.amt + new0 ELSE new0
                        nf == [f EXCEPT !.amt = new]
                    IN /\ Blk(t, FR(c, i)) = {}       \* locks the row, then the WHERE
                       /\ IF Guard(f, new)
                          THEN /\ SetDB(Lock(Wr(DB, t, FR(c, i), nf), t, FR(c, i)))
                               /\ gh' = FeeGhost(t, c, l, f, nf)
                          ELSE /\ lk' = [lk EXCEPT ![FR(c, i)] = t]
                               /\ UNCHANGED <<val, dirty, pre, gh>>
                       /\ lv' = [lv EXCEPT ![t].cs = Tail(@)]
                       /\ UNCHANGED pc
               ELSE /\ FreeIdx(c) # {}
                    /\ LET i == CHOOSE i \in FreeIdx(c) : \A j \in FreeIdx(c) : i <= j
                           nf == [ex |-> TRUE, amt |-> new0, paid |-> 0, waived |-> 0,
                                  voided |-> FALSE, due |-> lv[t].asof]
                       IN /\ SetDB(Lock(Wr(DB, t, FR(c, i), nf), t, FR(c, i)))
                          /\ gh' = FeeGhost(t, c, l, Fee(c, i), nf)
                    /\ lv' = [lv EXCEPT ![t].cs = Tail(@)]
                    /\ UNCHANGED pc
    /\ UNCHANGED <<today, adv>>

J_Commit(t) ==
    /\ IsJob(t) /\ pc[t] = "j_commit"
    /\ SetDB(CommitAll(DB, t))
    /\ adv' = IF adv = t THEN NoP ELSE adv
    /\ Goto(t, "done")
    /\ UNCHANGED <<today, lv, gh>>

-----------------------------------------------------------------------------
(* public.record_payment (hardening): lock_lease_for_write (latest:        *)
(* portfolio key, lease FOR UPDATE), the payment row, then                 *)
(* private.allocate_payment (ledger): open charges of the lease "order by  *)
(* c.due_date, c.id for update of c", one row at a time.                   *)
-----------------------------------------------------------------------------
OpenRows(l) ==
    {RR(c) : c \in {c2 \in LeaseRents(l) : ~Rent(c2).voided /\ OutR(Rent(c2)) > 0}}
    \cup {FR(c, i) : <<c, i>> \in {x \in LeaseRents(l) \X FeeIdx :
                                     Fee(x[1], x[2]).ex /\ ~Fee(x[1], x[2]).voided
                                     /\ OutF(Fee(x[1], x[2])) > 0}}
DueOf(r) == IF r[1] = "R" THEN RentDue(r[2]) ELSE Fee(r[2], r[3]).due
RankOf(r) == IF r[1] = "R" THEN 0 ELSE r[3]          \* id order: a fee is newer than its rent
Before(a, b) == \/ DueOf(a) < DueOf(b)
                \/ DueOf(a) = DueOf(b) /\ RankOf(a) < RankOf(b)
                \/ DueOf(a) = DueOf(b) /\ RankOf(a) = RankOf(b) /\ a[2] # b[2]
                   /\ \E i, j \in 1..3 : i < j /\ RentIdOrder[i] = a[2] /\ RentIdOrder[j] = b[2]
RECURSIVE Sorted(_)
Sorted(S) == IF S = {} THEN <<>>
             ELSE LET m == CHOOSE m \in S : \A o \in S \ {m} : Before(m, o)
                  IN <<m>> \o Sorted(S \ {m})

IsPay(t) == Kind(t) = "pay"
PayL(t) == Script(t).l
P_Wait(t) ==
    /\ IsPay(t) /\ pc[t] = "p_wait"
    /\ today >= Script(t).e
    /\ Goto(t, "p_lock")
    /\ UNCHANGED <<today, val, dirty, pre, lk, adv, lv, gh>>
\* lock_lease_for_write, then the INSERT INTO payments and the cursor's query;
\* p_charge_ids (Script(t).x) must name open charges (invalid_charge_selection)
\* and come first ("order by coalesce(array_position(p_charge_ids, c.id), ...)").
P_Lock(t) ==
    /\ IsPay(t) /\ pc[t] = "p_lock"
    /\ Blk(t, LR(PayL(t))) = {}
    /\ LET on == IF Script(t).d < 0 THEN today ELSE Script(t).d
           x == Script(t).x
           d1 == Lock(DB, t, LR(PayL(t)))
           prow == [ex |-> TRUE, voided |-> FALSE, amt |-> Script(t).a, on |-> on,
                    alloc |-> [r \in {} |-> 0]]
       IN IF x # NoP /\ x \notin OpenRows(PayL(t))
          THEN /\ Goto(t, "done")                     \* refused: rolled back
               /\ UNCHANGED <<val, dirty, pre, lk, lv>>
          ELSE /\ SetDB(Wr(d1, t, PR(Script(t).p), prow))
               /\ lv' = [lv EXCEPT ![t].order = IF x = NoP THEN Sorted(OpenRows(PayL(t)))
                                                ELSE <<x>> \o Sorted(OpenRows(PayL(t)) \ {x}),
                                   ![t].rem = Script(t).a]
               /\ Goto(t, "p_alloc")
    /\ UNCHANGED <<today, adv, gh>>

AddAlloc(f, r, a) == IF r \in DOMAIN f THEN [f EXCEPT ![r] = @ + a] ELSE f @@ (r :> a)

\* F1's fix (ledger findings): a rent settled in full by a payment dated within
\* its grace period loses its automatic fee, unless other money paid part of
\* the fee. What this payment had put on the fee (it was chosen first) is
\* released and allocated further. The SQL does this after allocate_payment
\* and then allocates the payment again in the same order (chosen charges
\* first, then due order); the rows the cursor had passed are settled, so the
\* result is the same as voiding when the rent is settled, as here.
MyAlloc(d, t, r) ==
    LET al == d.val[PR(Script(t).p)].alloc IN IF r \in DOMAIN al THEN al[r] ELSE 0
FeeHit(d, t, c, on) ==
    IF ~Mut("no_backdated_void") /\ on <= RentDue(c) + d.val[LR(RentLease(c))].pol.g
    THEN {i \in FeeIdx : d.val[FR(c, i)].ex /\ ~d.val[FR(c, i)].voided
                         /\ d.val[FR(c, i)].paid = MyAlloc(d, t, FR(c, i))}
    ELSE {}
FeeFreed(d, t, c, on) ==
    IF FeeHit(d, t, c, on) = {} THEN 0
    ELSE MyAlloc(d, t, FR(c, CHOOSE i \in FeeHit(d, t, c, on) : TRUE))
VoidFees(d, t, c, on) ==
    IF FeeHit(d, t, c, on) = {} THEN d
    ELSE LET f == FR(c, CHOOSE i \in FeeHit(d, t, c, on) : TRUE)
             a == MyAlloc(d, t, f)
             p == PR(Script(t).p)
             d1 == Lock(Wr(d, t, f, [d.val[f] EXCEPT !.voided = TRUE, !.paid = @ - a]), t, f)
             al == d1.val[p].alloc
         IN IF a = 0 THEN d1
            ELSE Wr(d1, t, p, [d1.val[p] EXCEPT !.alloc = [x \in DOMAIN al \ {f} |-> al[x]]])
VoidFeeBlockers(t, c, on) ==
    IF ~Mut("no_backdated_void") THEN UNION {Blk(t, FR(c, i)) : i \in FeeIdx} ELSE {}

\* One row of allocate_payment's FOR UPDATE cursor (skips rows settled meanwhile)
P_Alloc(t) ==
    /\ IsPay(t) /\ pc[t] = "p_alloc"
    /\ IF lv[t].order = <<>> \/ lv[t].rem = 0
       THEN /\ Goto(t, "p_commit")
            /\ UNCHANGED <<val, dirty, pre, lk, lv>>
       ELSE LET r == Head(lv[t].order)
                cur == val[r]
                out == IF r[1] = "R" THEN OutR(cur) ELSE OutF(cur)
                live == IF r[1] = "R" THEN ~cur.voided ELSE cur.ex /\ ~cur.voided
                a == Min(lv[t].rem, out)
                p == PR(Script(t).p)
                on == val[p].on
            IN /\ Blk(t, r) = {}
               /\ IF live /\ out > 0
                  THEN LET d1 == Wr(Lock(DB, t, r), t, r, [cur EXCEPT !.paid = @ + a])
                           d2 == Wr(d1, t, p, [val[p] EXCEPT !.alloc = AddAlloc(@, r, a)])
                           settled == r[1] = "R" /\ out - a = 0
                           d3 == IF settled THEN VoidFees(d2, t, r[2], on) ELSE d2
                           freed == IF settled THEN FeeFreed(d2, t, r[2], on) ELSE 0
                       IN /\ settled => VoidFeeBlockers(t, r[2], on) = {}
                          /\ SetDB(d3)
                          /\ lv' = [lv EXCEPT ![t].order = Tail(@), ![t].rem = @ - a + freed]
                  ELSE /\ lk' = [lk EXCEPT ![r] = t]
                       /\ lv' = [lv EXCEPT ![t].order = Tail(@)]
                       /\ UNCHANGED <<val, dirty, pre>>
               /\ UNCHANGED pc
    /\ UNCHANGED <<today, adv, gh>>

P_Commit(t) ==
    /\ IsPay(t) /\ pc[t] = "p_commit"
    /\ SetDB(CommitAll(DB, t))
    /\ Goto(t, "done")
    /\ UNCHANGED <<today, adv, lv, gh>>

-----------------------------------------------------------------------------
(* public.void_payment (hardening), public.void_charge (hardening) and     *)
(* public.end_lease (ledger): lock_lease_for_write, then their UPDATEs.    *)
(* Every row they write belongs to the locked lease; each UPDATE locks its *)
(* rows (merged into one step: no other writer of these rows runs, except *)
(* a client's description edit, which the step waits for).                *)
-----------------------------------------------------------------------------
LockStep(t, nextPc) ==
    /\ Blk(t, LR(Script(t).l)) = {}
    /\ lk' = [lk EXCEPT ![LR(Script(t).l)] = t]
    /\ Goto(t, nextPc)
    /\ UNCHANGED <<today, val, dirty, pre, adv, lv, gh>>

\* Apply the writes in W (row -> new value): waits for every row's lock.
WriteRows(t, W) ==
    /\ \A r \in DOMAIN W : Blk(t, r) = {}
    /\ LET RECURSIVE Go(_, _)
           Go(d, S) == IF S = {} THEN d
                       ELSE LET r == CHOOSE r \in S : TRUE
                            IN Go(Lock(Wr(d, t, r, W[r]), t, r), S \ {r})
       IN SetDB(CommitAll(Go(DB, DOMAIN W), t))
FnOf(S, F(_)) == [r \in S |-> F(r)]

\* void_payment: reverse the allocations; apply_lease_credit (the scenarios
\* have no other payment on the lease, so it allocates nothing).
VoidPayRows(t) ==
    LET p == PR(Script(t).p) IN
    FnOf(DOMAIN val[p].alloc \cup {p},
         LAMBDA r : IF r = p THEN [val[p] EXCEPT !.voided = TRUE, !.alloc = [x \in {} |-> 0]]
                    ELSE [val[r] EXCEPT !.paid = @ - val[p].alloc[r]])
V_Wait(t) ==
    /\ Kind(t) = "voidpay" /\ pc[t] = "v_wait"
    /\ \/ Committed(PR(Script(t).p)).ex /\ Goto(t, "v_lock")
       \/ today = MAX_DAY /\ ~Committed(PR(Script(t).p)).ex /\ Goto(t, "done")   \* never paid
    /\ UNCHANGED <<today, val, dirty, pre, lk, adv, lv, gh>>
V_Lock(t) == Kind(t) = "voidpay" /\ pc[t] = "v_lock" /\ LockStep(t, "v_do")
V_Do(t) ==
    /\ Kind(t) = "voidpay" /\ pc[t] = "v_do"
    /\ IF ~val[PR(Script(t).p)].voided THEN WriteRows(t, VoidPayRows(t))
       ELSE SetDB(CommitAll(DB, t))                         \* hardening: a no-op
    /\ Goto(t, "done")
    /\ UNCHANGED <<today, adv, lv, gh>>

\* void_charge(x): "where (id = x or (related_charge_id = x and paid_amount = 0))
\* and voided_at is null", only when x has no payments.
VoidChargeRows(x) ==
    LET related == IF x[1] = "R" /\ ~Mut("no_void_related")
                   THEN {FR(x[2], i) : i \in {j \in FeeIdx : Fee(x[2], j).ex /\ Fee(x[2], j).paid = 0
                                                             /\ ~Fee(x[2], j).voided}}
                   ELSE {}
    IN FnOf({x} \cup related, LAMBDA r : [val[r] EXCEPT !.voided = TRUE])
Exists(x) == IF x[1] = "R" THEN TRUE ELSE Committed(x).ex
C_Wait(t) ==
    /\ Kind(t) = "voidchg" /\ pc[t] = "c_wait"
    /\ \/ Exists(Script(t).x) /\ Goto(t, "c_lock")
       \/ today = MAX_DAY /\ ~Exists(Script(t).x) /\ Goto(t, "done")   \* no fee to void
    /\ UNCHANGED <<today, val, dirty, pre, lk, adv, lv, gh>>
C_Lock(t) == Kind(t) = "voidchg" /\ pc[t] = "c_lock" /\ LockStep(t, "c_do")
C_Do(t) ==
    /\ Kind(t) = "voidchg" /\ pc[t] = "c_do"
    /\ LET x == Script(t).x IN
       IF val[x].voided \/ val[x].paid > 0      \* charge_voided / charge_has_payments
       THEN SetDB(CommitAll(DB, t))
       ELSE WriteRows(t, VoidChargeRows(x))
    /\ Goto(t, "done")
    /\ UNCHANGED <<today, adv, lv, gh>>

\* end_lease(l, moved out in month m) (ledger findings): sync (abstracted);
\* the live rent of later months and the live automatic fees of rent of
\* later months, paid or not, have their allocations released (paid 0, the
\* payments' allocations removed) and are voided; status 'ended'. The freed
\* money is applied as credit (apply_lease_credit), which allocates nothing
\* here: no scenario pays a lease it ends. Mutant end_lease_keeps_fees: the
\* fees stay (finding F3).
EndRows(t) ==
    LET l == Script(t).l
        laterAll == {c \in LeaseRents(l) : RentMonth(c) > Script(t).m}
        later == {c \in laterAll : ~Rent(c).voided}
        fees == IF Mut("end_lease_keeps_fees") THEN {}
                ELSE {FR(c, i) : <<c, i>> \in {x \in laterAll \X FeeIdx :
                          Fee(x[1], x[2]).ex /\ ~Fee(x[1], x[2]).voided}}
        rows == {RR(c) : c \in later} \cup fees
        pays == {PR(q) : q \in {q \in {"p1", "p2"} : val[PR(q)].ex /\ ~val[PR(q)].voided
                                                    /\ DOMAIN val[PR(q)].alloc \cap rows # {}}}
    IN FnOf(rows \cup pays \cup {LR(l)},
            LAMBDA r : CASE r = LR(l) -> [val[r] EXCEPT !.st = "ended"]
                         [] r \in pays -> [val[r] EXCEPT !.alloc = [x \in DOMAIN val[r].alloc \ rows |->
                                                                    val[r].alloc[x]]]
                         [] OTHER -> [val[r] EXCEPT !.voided = TRUE, !.paid = 0])
E_Lock(t) == Kind(t) = "end" /\ pc[t] = "e_lock" /\ LockStep(t, "e_do")
E_Do(t) ==
    /\ Kind(t) = "end" /\ pc[t] = "e_do"
    /\ IF Lse(Script(t).l).st # "active" THEN SetDB(CommitAll(DB, t))   \* lease_not_active
       ELSE WriteRows(t, EndRows(t))
    /\ Goto(t, "done")
    /\ UNCHANGED <<today, adv, lv, gh>>

-----------------------------------------------------------------------------
(* Client writes through the Data API (one statement each).                *)
(* UPDATE leases SET late_fee_type, late_fee_value, late_fee_cap: policy   *)
(* leases_update (findings) takes the caller's portfolio keys first, then  *)
(* locks each row in scan order (FOR NO KEY UPDATE) and writes it.         *)
(* A client's charge edits (ledger findings): public.update_charge, one     *)
(* call per charge (Cl_Fix). Mutant edit_no_lease_lock is the code before: *)
(* UPDATE charges SET description under policy charges_update (findings),  *)
(* the same way as the lease policy; before_charge_update (ledger) allowed *)
(* it on any live charge. No lease lock: the statement locked charge rows  *)
(* directly (Cl_Row).                                                      *)
-----------------------------------------------------------------------------
ClientRow(t) == Head(lv[t].rows)
Cl_Row(t) ==
    /\ Kind(t) \in {"policy", "edit"} /\ pc[t] = "u_row"
    /\ IF lv[t].rows = <<>>
       THEN /\ SetDB(CommitAll(DB, t))
            /\ Goto(t, "done")
            /\ UNCHANGED lv
       ELSE LET r == ClientRow(t) IN
            /\ Blk(t, r) = {}
            /\ IF Kind(t) = "policy"
               THEN SetDB(Lock(Wr(DB, t, r, [val[r] EXCEPT !.pol = Script(t).n]), t, r))
               ELSE IF r[1] = "F" /\ ~val[r].ex THEN UNCHANGED <<val, dirty, pre, lk>>
               ELSE /\ lk' = [lk EXCEPT ![r] = t]   \* a description change: value unchanged
                    /\ UNCHANGED <<val, dirty, pre>>
            /\ lv' = [lv EXCEPT ![t].rows = Tail(@)]
            /\ UNCHANGED pc
    /\ UNCHANGED <<today, adv, gh>>

\* public.update_charge (ledger findings, F2's fix): one call per charge,
\* each its own transaction: lock_lease_for_write (the lease first), then
\* the row, the write, commit. Its credit application allocates nothing
\* here (a description edit).
Cl_Fix(t) ==
    /\ Kind(t) = "edit" /\ pc[t] = "u_fix"
    /\ IF lv[t].rows = <<>>
       THEN Goto(t, "done") /\ UNCHANGED <<val, dirty, pre, lk, lv>>
       ELSE LET r == ClientRow(t) l == RowLease(r) IN
            /\ Blk(t, LR(l)) = {} /\ Blk(t, r) = {}
            /\ lv' = [lv EXCEPT ![t].rows = Tail(@)]
            /\ UNCHANGED <<pc, val, dirty, pre, lk>>   \* lock, write, commit: one step
    /\ UNCHANGED <<today, adv, gh>>

\* The clock: app.today_pkt() moves to the next day.
Tick ==
    /\ today < MAX_DAY
    /\ today' = today + 1
    /\ UNCHANGED <<val, dirty, pre, lk, adv, pc, lv, gh>>

-----------------------------------------------------------------------------
(* Waiting and deadlocks                                                   *)

Need(t) ==
    CASE pc[t] = "j_lock" ->
            IF lv[t].todo # <<>> /\ Mut("no_skip_locked") THEN Blk(t, LR(Head(lv[t].todo))) ELSE {}
      [] pc[t] = "j_fee" ->
            IF lv[t].cs = <<>> THEN {}
            ELSE LET c == Head(lv[t].cs) IN
                 IF Conflicting(c) = {} THEN {}
                 ELSE Blk(t, FR(c, CHOOSE i \in Conflicting(c) : TRUE))
      [] pc[t] = "p_lock" -> Blk(t, LR(PayL(t)))
      [] pc[t] = "p_alloc" ->
            IF lv[t].order = <<>> \/ lv[t].rem = 0 THEN {}
            ELSE LET r == Head(lv[t].order)
                     fix == IF r[1] = "R" /\ OutR(val[r]) <= lv[t].rem
                            THEN VoidFeeBlockers(t, r[2], val[PR(Script(t).p)].on) ELSE {}
                 IN Blk(t, r) \cup fix
      [] pc[t] \in {"v_lock", "c_lock", "e_lock"} -> Blk(t, LR(Script(t).l))
      [] pc[t] = "v_do" ->
            IF val[PR(Script(t).p)].voided THEN {} ELSE UNION {Blk(t, r) : r \in DOMAIN VoidPayRows(t)}
      [] pc[t] = "c_do" -> UNION {Blk(t, r) : r \in DOMAIN VoidChargeRows(Script(t).x)}
      [] pc[t] = "e_do" -> UNION {Blk(t, r) : r \in DOMAIN EndRows(t)}
      [] pc[t] = "u_row" -> IF lv[t].rows = <<>> THEN {} ELSE Blk(t, ClientRow(t))
      [] pc[t] = "u_fix" ->
            IF lv[t].rows = <<>> THEN {}
            ELSE Blk(t, LR(RowLease(ClientRow(t)))) \cup Blk(t, ClientRow(t))
      [] OTHER -> {}

RECURSIVE ReachN(_, _)
ReachN(S, n) == IF n = 0 THEN S ELSE ReachN(S \cup UNION {Need(s) : s \in S}, n - 1)
OnCycle(t) == t \in ReachN(Need(t), Cardinality(Procs))

(* The detector aborts t with 40P01.  In the job the error is caught by    *)
(* the lease's subtransaction: its writes and the locks it took are rolled *)
(* back, and the lease is recorded as failed for the day (maintained_on =  *)
(* v_as_of, failures + 1).  Any other transaction rolls back.              *)
Detect(t) ==
    /\ pc[t] # "done"
    /\ OnCycle(t)
    /\ gh' = [gh EXCEPT !.deadlock = TRUE]
    /\ IF IsJob(t) /\ pc[t] \in {"j_lock", "j_fee"}
       THEN LET l == IF pc[t] = "j_lock" THEN Head(lv[t].todo) ELSE lv[t].cur IN
            /\ SetDB(JobLeaseFailed(t, l))
            /\ lv' = [lv EXCEPT ![t].todo = Tail(@), ![t].cs = <<>>]
            /\ Goto(t, "j_lock")
            /\ UNCHANGED adv
       ELSE /\ SetDB(Undo(DB, t, Rows))
            /\ adv' = IF adv = t THEN NoP ELSE adv
            /\ Goto(t, "done")
            /\ UNCHANGED lv
    /\ UNCHANGED today

-----------------------------------------------------------------------------
StartPC(t) ==
    CASE Kind(t) = "job"     -> "j_start"
      [] Kind(t) = "pay"     -> "p_wait"
      [] Kind(t) = "voidpay" -> "v_wait"
      [] Kind(t) = "voidchg" -> "c_wait"
      [] Kind(t) = "end"     -> "e_lock"
      [] Kind(t) = "policy"  -> "u_row"
      [] Kind(t) = "edit"    -> IF Mut("edit_no_lease_lock") THEN "u_row" ELSE "u_fix"

InitVal(r) ==
    CASE r[1] = "L" -> [st |-> "active", pol |-> InitPol(r[2])]
      [] r[1] = "M" -> [maint |-> StartDay - 1, fails |-> 0]
      [] r[1] = "R" -> [paid |-> 0, waived |-> 0, voided |-> r[2] \notin LiveRents]
      [] r[1] = "F" -> IF r[3] = 1 THEN InitFee(r[2]) ELSE NoFeeRow
      [] OTHER      -> NoPay

Init ==
    /\ today = StartDay
    /\ val = [r \in Rows |-> InitVal(r)]
    /\ dirty = [r \in Rows |-> NoP]
    /\ pre = [r \in Rows |-> InitVal(r)]
    /\ lk = [r \in Rows |-> NoP]
    /\ adv = NoP
    /\ pc = [t \in Procs |-> StartPC(t)]
    /\ lv = [t \in Procs |-> [asof |-> 0, todo |-> <<>>, cur |-> NoP, cs |-> <<>>, pol |-> NoFee,
                              snap |-> [l \in Leases |-> InitVal(LR(l))],
                              order |-> <<>>, rem |-> 0, rows |-> Script(t).s]]
    /\ gh = [notOverdue |-> FALSE, overCap |-> FALSE, overflow |-> FALSE, inactive |-> FALSE,
             stalePol |-> FALSE, touched |-> FALSE, lowered |-> FALSE, aboveTrue |-> FALSE,
             notIdem |-> FALSE, deadlock |-> FALSE, raised |-> FALSE,
             maxTrue |-> [c \in Rents |-> IF InitFee(c).ex THEN InitFee(c).amt ELSE 0],
             last |-> [c \in Rents |-> <<>>]]

Step(t) ==
    \/ J_Start(t) \/ J_Scan(t) \/ J_Lock(t) \/ J_Maint(t) \/ J_Fee(t) \/ J_Commit(t)
    \/ P_Wait(t) \/ P_Lock(t) \/ P_Alloc(t) \/ P_Commit(t)
    \/ V_Wait(t) \/ V_Lock(t) \/ V_Do(t)
    \/ C_Wait(t) \/ C_Lock(t) \/ C_Do(t)
    \/ E_Lock(t) \/ E_Do(t)
    \/ Cl_Row(t) \/ Cl_Fix(t)

Terminated == \A t \in Procs : pc[t] = "done"

Next ==
    \/ \E t \in Procs : Step(t) \/ Detect(t)
    \/ Tick
    \/ Terminated /\ today = MAX_DAY /\ UNCHANGED vars

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* PROPERTIES (on committed rows, or ghosts recorded at the write)         *)

CF(c, i) == Committed(FR(c, i))
CR(c) == Committed(RR(c))

TypeOK ==
    /\ today \in 0..MAX_DAY
    /\ dirty \in [Rows -> ProcsOrNo] /\ lk \in [Rows -> ProcsOrNo] /\ adv \in ProcsOrNo
    /\ \A c \in Rents, i \in FeeIdx : val[FR(c, i)].amt >= 0 /\ val[FR(c, i)].paid >= 0
    /\ \A c \in Rents : val[RR(c)].paid \in 0..RentAmt

(* charges_not_overpaid_check holds for every row (sanity of the model). *)
NotOverpaid ==
    /\ \A c \in Rents : CR(c).paid + CR(c).waived <= RentAmt
    /\ \A c \in Rents, i \in FeeIdx : CF(c, i).paid + CF(c, i).waived <= CF(c, i).amt

(* At most one automatic late fee per rent due, ever (charges_late_fee_key): *)
(* the daily fee grows in place; flat and percentage fees are posted once.   *)
AtMostOneFee == \A c \in Rents : Cardinality({i \in FeeIdx : CF(c, i).ex}) <= 1

(* A fee never exceeds the daily cap of the policy it was computed with,   *)
(* nor what a charge can hold.                                             *)
FeeWithinCap == ~gh.overCap
FeeFitsCharge == ~gh.overflow

(* The job writes a fee only for a live rent due that is unpaid (in the     *)
(* ledger) and past its grace period on the day it assesses.               *)
FeeOnlyWhenOverdue == ~gh.notOverdue

(* No fee is left on a rent due that payments dated within its grace       *)
(* period settle in full (paid_on <= due_date + grace_days).               *)
PaidInGrace(c) ==
    LET l == RentLease(c)
        g == Committed(LR(l)).pol.g
        ps == {p \in {"p1", "p2"} : Committed(PR(p)).ex /\ ~Committed(PR(p)).voided
                                    /\ Committed(PR(p)).on <= RentDue(c) + g
                                    /\ RR(c) \in DOMAIN Committed(PR(p)).alloc}
        RECURSIVE Sum(_)
        Sum(S) == IF S = {} THEN 0
                  ELSE LET p == CHOOSE p \in S : TRUE IN Committed(PR(p)).alloc[RR(c)] + Sum(S \ {p})
    IN Sum(ps) >= RentAmt
NoFeeWhenPaidInGrace ==
    \A c \in LiveRents : PaidInGrace(c) => \A i \in FeeIdx : ~(CF(c, i).ex /\ ~CF(c, i).voided)

(* Re-running the job for a day with unchanged inputs changes no fee.      *)
IdempotentRerun == ~gh.notIdem

(* The job never sets a fee above what the policy defines for some day it  *)
(* assessed (a flat or percentage fee is never charged twice).             *)
FeeNotAboveFormula == ~gh.aboveTrue

(* The job only raises a fee, and never touches one that is voided, paid   *)
(* or waived (in part).                                                    *)
FeeOnlyGrows == ~gh.lowered /\ ~gh.touched

(* A voided fee is never re-created: its rent never gets a live fee again. *)
VoidedFeeStaysVoid ==
    \A c \in Rents : (\E i \in FeeIdx : CF(c, i).ex /\ CF(c, i).voided) =>
                     ~\E i \in FeeIdx : CF(c, i).ex /\ ~CF(c, i).voided

(* No live, unpaid late fee of a voided rent due.                          *)
NoFeeOnVoidedRent ==
    \A c \in Rents, i \in FeeIdx :
        (CF(c, i).ex /\ ~CF(c, i).voided /\ CF(c, i).paid = 0) => ~CR(c).voided

(* Fees are written only while the lease is active, with its policy in     *)
(* force at that moment (lease end and policy changes are respected).      *)
FeeOnlyOnActiveLease == ~gh.inactive
FeeUsesPolicyInForce == ~gh.stalePol

(* No transaction waits, directly or through others, for itself.          *)
NoWaitCycle == \A t \in Procs : ~OnCycle(t)

(* Witnesses: each is EXPECTED to be violated, which shows that the        *)
(* scenarios reach what the properties above speak about.                  *)
W_NoFeePosted == \A c \in Rents, i \in FeeIdx : ~CF(c, i).ex \/ InitFee(c).ex
W_NoFeeRaised == ~gh.raised
W_NoRentPaidInGrace == \A c \in LiveRents : ~PaidInGrace(c)
W_NoDeadlockDetected == ~gh.deadlock
\* No fee is ever voided (by record_payment within grace, or by end_lease).
W_NoFeeVoided == \A c \in Rents, i \in FeeIdx : ~CF(c, i).voided

(* Sanity: a finished process holds no lock and has no uncommitted write.  *)
NoLeakedLocks ==
    \A t \in Procs : pc[t] = "done" => /\ \A r \in Rows : lk[r] # t /\ dirty[r] # t
                                       /\ adv # t

=============================================================================
