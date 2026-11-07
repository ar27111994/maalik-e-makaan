------------------------- MODULE LedgerPaymentsProbes -------------------------
(***************************************************************************)
(* Non-vacuity probes and structural facts for LedgerPayments.             *)
(*                                                                         *)
(* Reach_* : each says an interesting situation NEVER happens. TLC must    *)
(*           report it violated: the model reaches that situation, so the  *)
(*           passing configurations are not vacuous there.                 *)
(* Fact_*  : facts about today's code that must hold in every state.       *)
(* Expected outcomes are in the headers of cfg/probe_*.cfg.                *)
(***************************************************************************)
EXTENDS LedgerPayments

\* A retry (R1b) returns the payment the original request (R1a) created.
Reach_RetryReturnsOriginal == ~(resp["R1b"].k = "ok" /\ resp["R1b"].pay = "R1a")
\* The original aborted after its writes; the retry creates the one payment.
Reach_RetryAfterAbortCreates ==
    ~(resp["R1a"].code = "transient" /\ resp["R1b"].k = "ok" /\ resp["R1b"].pay = "R1b")
\* A reused key is refused with 'idempotency_key_reused'.
Reach_IdemReused == ~\E r \in Reqs : resp[r].code = "idem_reused"
\* A request waits for the advisory lock of its key (replayed_payment).
Reach_SameKeyWaits == ~\E r \in Reqs : pc[r] = "rp_idem" /\ Blockers(r) # {}
\* A payment waits for the receipt counter row (next_receipt_number).
Reach_CounterWait == ~\E r \in Reqs : pc[r] = "rp_counter" /\ Blockers(r) # {}
\* A retried void finds the payment voided and reports it.
Reach_VoidReplay == ~\E v \in Voids : resp[v].code = "replayed"
\* void_payment's apply_lease_credit re-allocates another payment's credit.
Reach_VoidReallocates == ~\E v \in Voids : pc[v] = "al_fetch"
\* R3's chosen charge c13 is paid while the earlier c11 is open (FIFO exemption).
Reach_SelectionPaysLater ==
    ~(pyC["R3"].ex /\ pyC["R3"].al["c13"] > 0 /\ OpenRow(chC["c11"]))
\* A chosen charge that is no longer open is refused.
Reach_InvalidSelection == ~\E r \in Reqs : resp[r].code = "invalid_selection"
\* New rent picks up existing credit (sync_lease_billing -> apply_lease_credit).
Reach_SyncAppliesCredit == ~\E s \in RentWriters : pc[s] = "al_fetch"
\* A rent insert waits on charges_rent_period_key.
Reach_RentInsertWaits == ~\E s \in RentWriters : pc[s] = "sy_ins" /\ Blockers(s) # {}
\* The job skips a lease a user's transaction holds (SKIP LOCKED).
Reach_JobSkipsBusy == ~\E j \in Jobs : lv[j].busy > 0
\* A second coordinator finds the job lock taken and skips the run.
Reach_JobSkippedRun == ~\E j \in Jobs : resp[j].code = "skipped"
\* The job creates rent.
Reach_JobCreatesRent == ~\E j \in Jobs : \E l \in Leases : chC[RentId(j, l)].ex
\* A sync or the job finds, after its lock, that the lease has ended.
Reach_SyncSeesEnded == ~\E s \in Syncs \cup Jobs : lv[s].sk > 0
\* end_lease voids unpaid rent of a later month.
Reach_EndLeaseVoidsRent == ~\E r \in RentIds : chC[r].vd
\* change_rent re-prices rent created before it.
Reach_RentRepriced == ~\E r \in RentIds : chC[r].ex /\ chC[r].amt = CrRent
\* A manual charge picks up credit (after_manual_charge_insert).
Reach_ManualAppliesCredit == ~\E m \in Manuals : chC[ManualId(m)].paid > 0
\* A user's write waits for a lease the daily job maintained earlier in the
\* same run (row locks of committed subtransactions last until the run commits).
Reach_UserWaitsForJob ==
    ~\E r \in Reqs : \E j \in Jobs : /\ pc[r] = "init"
                                    /\ lkL[PInfo(r).lease].x = j
                                    /\ lv[j].lease # PInfo(r).lease
\* A client's update_charge waits for the lease a ledger function holds.
Reach_ClientEditWaits == ~\E u \in Edits : pc[u] = "cu_lease" /\ Blockers(u) # {}
\* end_lease is about to release later rent that has been paid.
Reach_EndLeaseReleasesPaidRent ==
    ~\E e \in Ends : pc[e] = "el_void" /\ \E x \in ElVoidRows(e) : ChV(e, x).paid > 0

\* Every ledger writer, client charge edits included (update_charge), serialises
\* on the lease row first, so payment-row, charge-row, unique-index and FK
\* key-share waits never happen (the EvalPlanQual re-checks are a second layer).
Fact_NoRowLockContention ==
    \A p \in Procs :
        pc[p] \in {"al_fetch", "vo_rev", "al_lockpay", "vo_pay", "rp_fk", "sy_fk",
                   "rp_insert", "sy_ins", "el_void", "cr_upd", "cu_row"} => Blockers(p) = {}
\* The advisory key lock comes before the INSERT, so no INSERT waits on
\* payments_idempotency_key.
Fact_NoIdemIndexWait == \A r \in Reqs : pc[r] = "rp_insert" => KeyWait(r, Key(r)) = {}
=============================================================================
