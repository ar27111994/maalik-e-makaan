----------------------------- MODULE QueueFairness -----------------------------
(***************************************************************************)
(* How cleaners take turns on private.storage_cleanup_queue (latest:       *)
(* supabase/migrations/20261105072426_membership_deletion_storage.sql).    *)
(*                                                                         *)
(* public.admin_claim_storage_cleanup(p_limit):                            *)
(*   update queue q set claimed_until = now() + lease, attempts = +1       *)
(*   where q.id in (                                                       *)
(*     select l.id from queue l                                            *)
(*     where l.id in (select r.id from (select c.id, c.not_before,         *)
(*                      row_number() over (partition by c.folder           *)
(*                        order by c.not_before, c.id) as turn             *)
(*                    from queue c where <due and unclaimed>) r            *)
(*                    order by r.turn, r.not_before, r.id limit p_limit)   *)
(*       and <due and unclaimed>          -- the recheck at lock time       *)
(*     for update skip locked)                                             *)
(* public.admin_complete_storage_cleanup(item, finished, error): an error  *)
(* backs off (attempts kept); otherwise attempts := 0 and the item is done *)
(* (finished) or due again now (not_before = now(): to the back).          *)
(* supabase/functions/_shared/storage.ts drainStorageCleanup claims,       *)
(* cleans and completes each item, then claims again.                      *)
(*                                                                         *)
(* Time: not_before is represented by the ORDER of due items (sequence     *)
(* nb): a new or rescheduled item has not_before = now(), later than every *)
(* item already due, so it goes to the back; an item waiting after an      *)
(* error joins the back when its backoff ends (Tick).  A claim does not    *)
(* change not_before, so a lapsed claim keeps its place.  Identity ids are *)
(* the order of enqueueing (sequence ids).                                 *)
(*                                                                         *)
(* The claim statement is split where READ COMMITTED splits it: Snap reads *)
(* the candidates with the statement's snapshot; Lock then locks them one  *)
(* by one (SKIP LOCKED) on their newest committed versions, re-checking    *)
(* the due conditions; Commit makes the claims visible.                    *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS
    CLEANERS,   \* concurrent cleaner runs, e.g. {"c1", "c2"}
    LIMIT,      \* p_limit (CLAIM_LIMIT = 20 in storage.ts; small here)
    MUTANT,     \* "none" = current code
    CRASHES,    \* how many cleaner crashes may happen (claims then lapse)
    PRODUCER    \* folder Y keeps receiving new items (TRUE) or not

ASSUME LIMIT \in 1..3 /\ CRASHES \in Nat /\ PRODUCER \in BOOLEAN
ASSUME MUTANT \in {"none",
                   "no_lock_recheck",    \* lock without re-checking the due conditions
                   "no_turn",            \* order by not_before, id (no row_number turns)
                   "order_by_id",        \* order by id only
                   "no_attempts_reset"}  \* attempts kept on an error-free completion
Mut(m) == MUTANT = m

Items == {"x1", "y1", "y2"}
Folder(i) == IF i = "x1" THEN "X" ELSE "Y"
Folders == {"X", "Y"}
NoC == "-"
CAP == 2          \* attempts are compared up to CAP (both sides capped alike)
Cap(n) == IF n > CAP THEN CAP ELSE n

VARIABLES
    nb,      \* due items in not_before order (claimed ones keep their place)
    ids,     \* present items in id order
    wait,    \* wait[i]: "later" while backing off after an error, else "none"
    cl,      \* cl[i]: committed claim holder (claimed_until in the future)
    lk,      \* lk[i]: cleaner whose claim of i is locked but not committed
    att,     \* att[i]: the attempts column
    pc, snap, mine,
    gh       \* ghosts: claims since the last error-free completion, flags, crashes

vars == <<nb, ids, wait, cl, lk, att, pc, snap, mine, gh>>

Present(i) == \E k \in 1..Len(ids) : ids[k] = i
InNb(i)    == \E k \in 1..Len(nb) : nb[k] = i
Pos(i)     == CHOOSE k \in 1..Len(nb) : nb[k] = i
IdPos(i)   == CHOOSE k \in 1..Len(ids) : ids[k] = i
Remove(s, i) == SelectSeq(s, LAMBDA x : x # i)

\* "c.not_before <= now() and (c.claimed_until is null or c.claimed_until < now())"
Due(i) == InNb(i) /\ cl[i] = NoC

\* row_number() over (partition by folder order by not_before, id)
Turn(C, i) == 1 + Cardinality({j \in C : Folder(j) = Folder(i) /\ Pos(j) < Pos(i)})
Before(C, j, i) ==
    CASE Mut("order_by_id") -> IdPos(j) < IdPos(i)
      [] Mut("no_turn")     -> Pos(j) < Pos(i)
      [] OTHER              -> \/ Turn(C, j) < Turn(C, i)
                               \/ Turn(C, j) = Turn(C, i) /\ Pos(j) < Pos(i)
\* "order by r.turn, r.not_before, r.id limit p_limit"
Select(C) == {i \in C : Cardinality({j \in C : Before(C, j, i)}) < LIMIT}

\* A folder gets a second item in one claim while another folder with due
\* items gets none.
Unfair(C, S) ==
    \E f, g \in Folders :
        /\ f # g
        /\ Cardinality({i \in S : Folder(i) = f}) >= 2
        /\ \E i \in C \ S : Folder(i) = g
        /\ ~\E i \in S : Folder(i) = g

Init ==
    \* folder Y's backlog was queued before x1
    /\ nb = <<"y1", "y2", "x1">>
    /\ ids = <<"y1", "y2", "x1">>
    /\ wait = [i \in Items |-> "none"]
    /\ cl = [i \in Items |-> NoC]
    /\ lk = [i \in Items |-> NoC]
    /\ att = [i \in Items |-> 0]
    /\ pc = [c \in CLEANERS |-> "snap"]
    /\ snap = [c \in CLEANERS |-> {}]
    /\ mine = [c \in CLEANERS |-> {}]
    /\ gh = [since |-> [i \in Items |-> 0], double |-> FALSE, unfair |-> FALSE, crashes |-> 0]

(* The claim's inner query: candidates from the statement's snapshot. *)
Snap(c) ==
    /\ pc[c] = "snap"
    /\ LET C == {i \in Items : Due(i)}
           S == Select(C)
       IN /\ snap' = [snap EXCEPT ![c] = S]
          /\ gh' = [gh EXCEPT !.unfair = @ \/ Unfair(C, S)]
    /\ pc' = [pc EXCEPT ![c] = "lock"]
    /\ UNCHANGED <<nb, ids, wait, cl, lk, att, mine>>

(* "for update skip locked" with the recheck: a row another claim has      *)
(* locked is skipped; a row is locked only if its newest committed version *)
(* is still due and unclaimed.                                             *)
Lock(c) ==
    /\ pc[c] = "lock"
    /\ LET L == {i \in snap[c] : lk[i] = NoC /\ Present(i)
                                 /\ (Mut("no_lock_recheck") \/ Due(i))}
       IN lk' = [i \in Items |-> IF i \in L THEN c ELSE lk[i]]
    /\ pc' = [pc EXCEPT ![c] = "commit"]
    /\ snap' = [snap EXCEPT ![c] = {}]
    /\ UNCHANGED <<nb, ids, wait, cl, att, mine, gh>>

(* COMMIT: claimed_until and attempts become visible. *)
Commit(c) ==
    /\ pc[c] = "commit"
    /\ LET M == {i \in Items : lk[i] = c} IN
       /\ cl' = [i \in Items |-> IF i \in M THEN c ELSE cl[i]]
       /\ att' = [i \in Items |-> IF i \in M THEN Cap(att[i] + 1) ELSE att[i]]
       /\ lk' = [i \in Items |-> IF i \in M THEN NoC ELSE lk[i]]
       /\ mine' = [mine EXCEPT ![c] = M]
       /\ gh' = [gh EXCEPT !.since = [i \in Items |-> IF i \in M THEN Cap(@[i] + 1) ELSE @[i]],
                           !.double = @ \/ \E i \in M : cl[i] \notin {NoC, c}]
       /\ pc' = [pc EXCEPT ![c] = IF M = {} THEN "snap" ELSE "work"]
    /\ UNCHANGED <<nb, ids, wait, snap>>

(* admin_complete_storage_cleanup for one claimed item, with the outcome   *)
(* of cleanItem: finished, unfinished (time ran out), or an error.         *)
Complete(c) ==
    /\ pc[c] = "work"
    /\ \E i \in mine[c], o \in {"finished", "unfinished", "error"} :
         /\ IF ~Present(i) \/ cl[i] # c
            THEN UNCHANGED <<nb, ids, wait, cl, att, gh>>        \* 'missing' / lapsed
            ELSE CASE o = "error" ->
                        /\ nb' = Remove(nb, i) /\ wait' = [wait EXCEPT ![i] = "later"]
                        /\ cl' = [cl EXCEPT ![i] = NoC]
                        /\ UNCHANGED <<ids, att, gh>>
                   [] o = "finished" ->
                        /\ nb' = Remove(nb, i) /\ ids' = Remove(ids, i)
                        /\ cl' = [cl EXCEPT ![i] = NoC] /\ att' = [att EXCEPT ![i] = 0]
                        /\ gh' = [gh EXCEPT !.since[i] = 0]
                        /\ UNCHANGED wait
                   [] o = "unfinished" ->
                        /\ nb' = Append(Remove(nb, i), i)
                        /\ cl' = [cl EXCEPT ![i] = NoC]
                        /\ att' = IF Mut("no_attempts_reset") THEN att ELSE [att EXCEPT ![i] = 0]
                        /\ gh' = [gh EXCEPT !.since[i] = 0]
                        /\ UNCHANGED <<ids, wait>>
         /\ mine' = [mine EXCEPT ![c] = @ \ {i}]
         /\ pc' = [pc EXCEPT ![c] = IF mine[c] = {i} THEN "snap" ELSE "work"]
    /\ UNCHANGED <<lk, snap>>

(* The Edge Function dies holding claims (or an RPC fails): they lapse later. *)
Crash(c) ==
    /\ pc[c] \in {"lock", "commit", "work"}
    /\ gh.crashes < CRASHES
    /\ lk' = [i \in Items |-> IF lk[i] = c THEN NoC ELSE lk[i]]     \* rollback
    /\ mine' = [mine EXCEPT ![c] = {}]
    /\ snap' = [snap EXCEPT ![c] = {}]
    /\ pc' = [pc EXCEPT ![c] = "snap"]
    /\ gh' = [gh EXCEPT !.crashes = @ + 1]
    /\ UNCHANGED <<nb, ids, wait, cl, att>>

(* claimed_until passes for a claim its holder no longer works on. *)
Lapse(i) ==
    /\ cl[i] # NoC /\ i \notin mine[cl[i]]
    /\ cl' = [cl EXCEPT ![i] = NoC]
    /\ UNCHANGED <<nb, ids, wait, lk, att, pc, snap, mine, gh>>

(* The backoff ends: not_before <= now(), behind everything due earlier. *)
Tick(i) ==
    /\ wait[i] = "later"
    /\ wait' = [wait EXCEPT ![i] = "none"]
    /\ nb' = Append(nb, i)
    /\ UNCHANGED <<ids, cl, lk, att, pc, snap, mine, gh>>

(* Folder Y keeps receiving work: a new item (new id, not_before = now()). *)
Produce(i) ==
    /\ PRODUCER /\ Folder(i) = "Y" /\ ~Present(i) /\ lk[i] = NoC
    /\ nb' = Append(nb, i) /\ ids' = Append(ids, i)
    /\ att' = [att EXCEPT ![i] = 0] /\ cl' = [cl EXCEPT ![i] = NoC]
    /\ wait' = [wait EXCEPT ![i] = "none"]
    /\ gh' = [gh EXCEPT !.since[i] = 0]
    /\ UNCHANGED <<lk, pc, snap, mine>>

Next ==
    \/ \E c \in CLEANERS : Snap(c) \/ Lock(c) \/ Commit(c) \/ Complete(c) \/ Crash(c)
    \/ \E i \in Items : Lapse(i) \/ Tick(i) \/ Produce(i)

Spec == Init /\ [][Next]_vars

(* Cleaners keep running (pg_cron), backoffs end, abandoned claims lapse;  *)
(* the producer and the outcomes (errors, unfinished) are unconstrained.   *)
LiveSpec ==
    /\ Spec
    /\ \A c \in CLEANERS : WF_vars(Snap(c) \/ Lock(c) \/ Commit(c) \/ Complete(c))
    /\ \A i \in Items : WF_vars(Lapse(i)) /\ WF_vars(Tick(i))

-----------------------------------------------------------------------------
TypeOK ==
    /\ cl \in [Items -> CLEANERS \cup {NoC}] /\ lk \in [Items -> CLEANERS \cup {NoC}]
    /\ att \in [Items -> 0..CAP]

(* No item is claimed by two cleaners at once. *)
ExclusiveClaims == ~gh.double

(* Folders take turns within a claim. *)
TurnsWithinClaim == ~gh.unfair

(* "attempts" counts the claims since the last error-free completion, so an *)
(* item handed back unfinished never inherits a long backoff.              *)
AttemptsCountFailures == \A i \in Items : Present(i) => att[i] = gh.since[i]

(* No starvation: an item that is due is eventually claimed. *)
NoStarvation == \A i \in Items : [](Due(i) => <>(cl[i] # NoC \/ ~InNb(i)))

=============================================================================
