------------------------------ MODULE Membership ------------------------------
(***************************************************************************)
(* Account deletion, membership changes, portfolio deletion, invitations   *)
(* and single-use portfolio ids in Maalik-e-Makaan, as the CURRENT code    *)
(* implements them.  Every action names the SQL or TypeScript it follows;  *)
(* "latest" means supabase/migrations/20261105072426_membership_deletion_  *)
(* storage.sql, which redefines the functions of earlier migrations;       *)
(* "findings" means 20261105170557_concurrency_findings.sql, whose client  *)
(* UPDATE/DELETE row policies and INSERT WITH CHECKs take the portfolio    *)
(* key first (finding M1, and client inserts).  "residence" means          *)
(* 20261112092618_residence.sql: the caretaker (set_caretaker, its two     *)
(* triggers and the foreign key's SET NULL), the owner-abroad answer       *)
(* (set_owner_abroad), a person's declared residence, and the latest       *)
(* admin_delete_account_data, which clears that residence last.            *)
(*                                                                         *)
(* Granularity.  One TLA+ step is one SQL statement, or one row lock taken *)
(* by a statement that locks rows one by one (lock_portfolios_for_         *)
(* deletion in id order; GoTrue's foreign-key actions and the deletions'   *)
(* audit-trail DELETE, whose row order follows the plan and the heap, in   *)
(* any order: RowStep).  A statement sees the committed state plus its own *)
(* transaction's writes (READ COMMITTED: a fresh snapshot per statement of *)
(* a VOLATILE plpgsql function).  Row locks follow PostgreSQL:             *)
(*   FOR KEY SHARE (KS)        conflicts with FOR UPDATE / DELETE (X);     *)
(*   FOR NO KEY UPDATE (NKU)   conflicts with NKU and X;                   *)
(*   FOR UPDATE / DELETE (X)   conflicts with everything.                  *)
(* A step that needs a lock held by another transaction is disabled: the   *)
(* process WAITS, and Need(t) is the set of transactions it waits for.     *)
(* The wait-for graph is therefore explicit, and Detect models PostgreSQL's *)
(* deadlock detector: it aborts any one transaction on a cycle with        *)
(* 40P01 deadlock_detected.  Where several statements run under a lock     *)
(* that keeps every other writer of the same rows out, they are merged     *)
(* into one step (each such merge is noted at the action).                 *)
(*                                                                         *)
(* Abstractions (why they are safe is argued in README.md):                *)
(*  * users, portfolios and invitations are small fixed sets; e-mail,      *)
(*    verification, rate limits, the 20-portfolio limit, names and         *)
(*    confirmation texts always pass (they only refuse more);              *)
(*  * a portfolio's child rows are one lease row; documents and files are  *)
(*    in ../StorageCleanup; a user's audit rows in a portfolio are one row *)
(*    (public.audit_logs, actor_id), given where a deletion can meet them; *)
(*  * waiters for an exclusive row lock are not queued among themselves    *)
(*    (a waiter waits for holders only).  With one global lock order a     *)
(*    queue cannot close a cycle, and the out-of-order writers modelled    *)
(*    here wait for a holder.                                              *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, Sequences, TLC

CONSTANTS
    SCENARIO,      \* processes and initial data (ScenarioProcs, Members, Inv)
    MUTANT,        \* "none" = current code; otherwise one mechanism removed
    MAX_POSTS,     \* delete-account POSTs per account-deletion process (client retries)
    CAN_ABORT,     \* any open transaction may fail (timeout, lost connection)
    GOTRUE_ORDER,  \* GoTrue's FK actions on DELETE FROM auth.users (GSeq):
                   \* "portfolios_first" (FK creation order, a migrated
                   \* database; scenario 17 of tool/db/concurrency_test.sh),
                   \* "leases_first" (leases before portfolios: assumption flip),
                   \* "caretaker_first" (the caretaker's SET NULL first; its
                   \* trigger name can sort anywhere once the OIDs gain a
                   \* digit, and every position before the membership cascade
                   \* acts like this one, every position after it like the
                   \* last: README.md), or
                   \* "restored" (a pg_dump restore: by constraint name)
    WAKE_FIRST     \* scheduling assumption: after a deletion's savepoint rollback,
                   \* each transaction it was blocking runs one statement before
                   \* the deletion locks again (FALSE: any interleaving)

Mutants == {"none",
            "no_freeze",          \* no account_deletions / require_active_account
            "scope_before_lock",  \* deletion scope read before the portfolio locks
            "unordered_locks",    \* lock_portfolios_for_deletion without "order by p.id"
            "no_member_lock",     \* lock_portfolio_for_change takes no row lock
            "no_last_owner",      \* remove_member / update_member_role skip last_owner
            "no_recheck",         \* lock_portfolio_for_change does not authorise again
            "no_id_registry",     \* no private.portfolio_ids at all
            "no_id_precheck",     \* create_portfolio skips the registry lookup
            "no_id_trigger",      \* no portfolios_after_insert_register_id trigger
            "no_deadlock_retry",  \* lock-and-delete step not retried on 40P01
            "unbounded_retry",    \* ... retried for ever (no "v_attempt >= 3" bound)
            "no_inviter_check",   \* accept_invitation skips the inviter-is-owner check
            "no_revoke_trigger",  \* no portfolio_members_after_owner_ends trigger
            "no_inviter_auth",    \* both of the previous two
            "no_client_key",      \* findings: the lease UPDATE policy takes no portfolio key
                                  \* (the code M1 was found in)
            "no_insert_key",      \* findings: an INSERT's WITH CHECK takes no portfolio key
                                  \* (its foreign-key checks lock in trigger order)
            "no_note_account_key",\* findings: the notification helper skips the account key
            \* residence (20261112092618_residence.sql)
            "no_care_share",      \* before_portfolio_caretaker_change reads the membership without FOR SHARE
            "no_care_trigger",    \* no portfolio_members_after_caretaker_ends trigger
            "no_care_recheck",    \* set_caretaker without the second require_portfolio_role
            "care_member_first",  \* set_caretaker reads the membership FOR SHARE before the portfolio
            "no_abroad_recheck",  \* set_owner_abroad without the second require_portfolio_role
            "abroad_unlocked_read",\* set_owner_abroad reads the answer without FOR NO KEY UPDATE
            "residence_filtered", \* the residence clear filtered on its values
            "no_residence_refusal",\* the client trigger does not refuse a deleted account
            "no_care_lock",       \* set_caretaker takes no portfolio lock (its UPDATE locks it later)
            "no_care_rpc_role_check", \* set_caretaker skips its own role read (the trigger still checks)
            "no_care_before_trigger", \* no portfolios_before_caretaker_change at all
            "no_answered_guard",  \* set_owner_abroad without owner_abroad_answered
            "abroad_answered_overwritten", \* set_owner_abroad ignores p_if_unanswered
            "residence_check_before_lock", \* account_deleted read before the row lock
            "residence_first"}    \* the residence cleared before the loop, not last
ASSUME MUTANT \in Mutants
ASSUME MAX_POSTS \in 1..2
ASSUME CAN_ABORT \in BOOLEAN
ASSUME GOTRUE_ORDER \in {"portfolios_first", "leases_first", "caretaker_first", "restored"}
ASSUME WAKE_FIRST \in BOOLEAN

Mut(m) == MUTANT = m

Users == {"A", "B", "C"}
Ports == {"P1", "P2", "P3"}
PortOrder == <<"P1", "P2", "P3">>          \* uuid order of the portfolio ids
NoP == "-"                                 \* no process / no user / no value
Roles == {"owner", "manager", "viewer", "none"}
\* v_attempt >= 3 -> raise (delete_portfolio, admin_delete_account_data, latest)
DeleteAttempts == 3

-----------------------------------------------------------------------------
(* Processes.  k = kind, u = caller, q = portfolio, v = target member,     *)
(* r = new role.                                                           *)
Pr(k, u, q, v, r) == [k |-> k, u |-> u, q |-> q, v |-> v, r |-> r]
Script(t) ==
    CASE t = "delA"      -> Pr("acct",   "A", NoP,  NoP, "none")
      [] t = "delA2"     -> Pr("acct",   "A", NoP,  NoP, "none")   \* a second device's POST
      [] t = "delB"      -> Pr("acct",   "B", NoP,  NoP, "none")
      [] t = "leaveA"    -> Pr("remove", "A", "P1", "A", "none")
      [] t = "leaveB"    -> Pr("remove", "B", "P1", "B", "none")
      [] t = "rmB"       -> Pr("remove", "A", "P1", "B", "none")   \* A removes B
      [] t = "roleC"     -> Pr("role",   "B", "P1", "C", "viewer") \* B changes C's role
      [] t = "demoteB"   -> Pr("role",   "A", "P1", "B", "manager")\* A demotes B
      [] t = "acceptA"   -> Pr("accept", "A", NoP,  NoP, "none")
      [] t = "acceptB"   -> Pr("accept", "B", NoP,  NoP, "none")
      [] t = "acceptC"   -> Pr("accept", "C", NoP,  NoP, "none")
      [] t = "createA"   -> Pr("create", "A", "P3", NoP, "none")   \* a fresh client id
      [] t = "claimC"    -> Pr("create", "C", "P1", NoP, "none")   \* someone else's id
      [] t = "recreateA" -> Pr("create", "A", "P1", NoP, "none")   \* the creator's replay
      [] t = "dportA"    -> Pr("dport",  "A", "P1", NoP, "none")
      [] t = "depoB"     -> Pr("depo",   "B", "P1", NoP, "none")
      [] t = "depoB2"    -> Pr("depo",   "B", "P2", NoP, "none")
      [] t = "payA"      -> Pr("pay",    "A", "P1", NoP, "none")
      [] t = "occB"      -> Pr("ins",    "B", "P1", NoP, "none")   \* migration order
      [] t = "occBr"     -> Pr("ins",    "B", "P1", NoP, "none")   \* restored order
      [] t = "tenB"      -> Pr("ins",    "B", "P2", NoP, "none")   \* rows of P2, then P1
      [] t = "goB"       -> Pr("gotrue", "B", NoP,  NoP, "none")
      [] t = "noteB"     -> Pr("note",   "B", "P1", NoP, "none")   \* marks n2, then n1 read
      \* residence (20261112092618_residence.sql)
      [] t = "careAC"    -> Pr("care",   "A", "P1", "C", "none")   \* set_caretaker(P1, C) by A
      [] t = "careBC"    -> Pr("care",   "B", "P1", "C", "none")   \* set_caretaker(P1, C) by B
      [] t = "demoteC"   -> Pr("role",   "B", "P1", "C", "viewer") \* B demotes manager C
      [] t = "demoteCA"  -> Pr("role",   "A", "P1", "C", "viewer") \* A demotes manager C
      [] t = "rmAbyB"    -> Pr("remove", "B", "P1", "A", "none")   \* B removes A (the namer)
      [] t = "rmC"       -> Pr("remove", "A", "P1", "C", "none")   \* A removes manager C
      [] t = "rmCbyB"    -> Pr("remove", "B", "P1", "C", "none")   \* B removes manager C
      [] t = "leaveC"    -> Pr("remove", "C", "P1", "C", "none")   \* manager C leaves
      [] t = "svcDemC"   -> Pr("svc",    NoP, "P1", "C", "viewer") \* service role: C's role
      [] t = "svcRmC"    -> Pr("svc",    NoP, "P1", "C", "none")   \* service role: C removed
      \* the operator's rule: P1 FOR UPDATE first, then C's role
      [] t = "svcLockDemC" -> Pr("svcl", NoP, "P1", "C", "viewer")
      [] t = "delC"      -> Pr("acct",   "C", NoP,  NoP, "none")
      [] t = "goC"       -> Pr("gotrue", "C", NoP,  NoP, "none")   \* a direct Auth delete of C
      \* set_owner_abroad: v = NoP is p_if_unanswered => true, "change" false
      [] t = "ansA"      -> Pr("abroad", "A", "P1", NoP, "yes")
      [] t = "ansC"      -> Pr("abroad", "C", "P1", NoP, "no")
      [] t = "chgA"      -> Pr("abroad", "A", "P1", "change", "no")
      [] t = "chgC"      -> Pr("abroad", "C", "P1", "change", "no")
      [] t = "resA"      -> Pr("res",    "A", NoP,  NoP, "none")   \* A states a residence
      [] t = "resC"      -> Pr("res",    "C", NoP,  NoP, "none")   \* C states a residence

ScenarioProcs(s) ==
    CASE s = "two_deletions"   -> {"delA", "delB"}
      [] s = "double_post"     -> {"delA", "delA2"}
      [] s = "leave_pair"      -> {"leaveA", "leaveB"}
      [] s = "stale_owner"     -> {"rmB", "roleC"}
      [] s = "freeze"          -> {"delA", "acceptA", "createA"}
      [] s = "freeze_orphan"   -> {"delA", "acceptA", "leaveB"}
      [] s = "accept_delete"   -> {"acceptC", "dportA"}
      [] s = "accept_owner_delete" -> {"delA", "acceptC"}
      [] s = "inviter_demoted" -> {"demoteB", "acceptC"}
      [] s = "id_reuse"        -> {"dportA", "claimC", "recreateA"}
      [] s = "acct_reuse"      -> {"delA", "claimC"}
      [] s = "deposit"         -> {"dportA", "depoB"}
      [] s = "deposit_acct"    -> {"delA", "depoB", "depoB2"}
      [] s = "insert"          -> {"dportA", "occBr"}
      [] s = "insert_mig"      -> {"dportA", "occB"}
      [] s = "insert_rows"     -> {"delA", "tenB"}
      [] s = "gotrue_setnull"  -> {"dportA", "goB", "payA"}
      [] s = "gotrue_acct"     -> {"delA", "goB"}
      [] s = "mixed"           -> {"delA", "leaveB", "acceptB"}
      [] s = "team"            -> {"delA", "delB", "acceptC", "demoteB"}
      [] s = "notes"           -> {"noteB", "goB"}
      [] s = "caretaker"       -> {"careAC", "demoteC", "rmAbyB"}
      [] s = "caretaker_remove" -> {"careAC", "rmCbyB"}
      [] s = "caretaker_svc"   -> {"careAC", "svcDemC", "svcRmC"}
      [] s = "caretaker_svc_rpc" -> {"svcDemC", "demoteCA"}
      [] s = "caretaker_svc_rule" -> {"svcLockDemC", "demoteCA"}
      [] s = "caretaker_acct"  -> {"delC", "careAC", "demoteC"}
      [] s = "caretaker_direct" -> {"careAC", "goC"}
      [] s = "caretaker_direct_rpc" -> {"rmC", "goC"}
      [] s = "caretaker_direct_dport" -> {"dportA", "goC"}
      [] s \in {"direct_leave", "caretaker_direct_leave"} -> {"leaveC", "goC"}
      [] s \in {"direct_demote", "caretaker_direct_demote"} -> {"demoteCA", "goC"}
      [] s = "direct_dport"    -> {"dportA", "goC"}
      [] s = "dport_former"    -> {"dportA", "delC"}
      [] s = "answer"          -> {"ansA", "ansC", "demoteCA"}
      [] s = "answer_change"   -> {"ansA", "chgC", "chgA", "demoteCA"}
      [] s = "residence"       -> {"delA", "resA"}
      [] s = "residence_team"  -> {"careAC", "demoteC", "delC", "ansA", "resC"}
      [] s = "inviter"         -> {"delA", "careBC", "demoteC"}

Procs == ScenarioProcs(SCENARIO)

(* Initial memberships <<portfolio, user, role>>. *)
Members(s) ==
    CASE s \in {"two_deletions"} ->
            {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>, <<"P2", "A", "owner">>, <<"P2", "B", "owner">>}
      [] s = "double_post"     -> {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>, <<"P2", "A", "owner">>}
      [] s = "leave_pair"      -> {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>}
      [] s = "stale_owner"     -> {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>, <<"P1", "C", "manager">>}
      [] s = "freeze"          -> {<<"P1", "B", "owner">>, <<"P2", "A", "owner">>}
      [] s = "freeze_orphan"   -> {<<"P1", "B", "owner">>}
      [] s \in {"accept_delete", "accept_owner_delete"} -> {<<"P1", "A", "owner">>}
      [] s = "inviter_demoted" -> {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>}
      [] s \in {"id_reuse", "acct_reuse"} -> {<<"P1", "A", "owner">>}
      [] s \in {"deposit", "insert", "insert_mig"} -> {<<"P1", "A", "owner">>, <<"P1", "B", "manager">>}
      [] s \in {"deposit_acct", "insert_rows"} ->
            {<<"P1", "A", "owner">>, <<"P1", "B", "manager">>, <<"P2", "A", "owner">>, <<"P2", "B", "manager">>}
      [] s \in {"gotrue_setnull", "gotrue_acct"} -> {<<"P1", "A", "owner">>}
      [] s = "notes"           -> {<<"P1", "A", "owner">>, <<"P1", "B", "manager">>}
      [] s = "mixed"           ->
            {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>, <<"P1", "C", "manager">>, <<"P2", "A", "owner">>}
      [] s = "team"            ->
            {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>, <<"P1", "C", "manager">>,
             <<"P2", "A", "owner">>, <<"P2", "B", "owner">>}
      [] s \in {"caretaker", "caretaker_remove", "caretaker_acct", "residence_team", "inviter"} ->
            {<<"P1", "A", "owner">>, <<"P1", "B", "owner">>, <<"P1", "C", "manager">>}
      [] s \in {"caretaker_svc", "caretaker_svc_rpc", "caretaker_svc_rule", "caretaker_direct",
                "caretaker_direct_rpc", "caretaker_direct_dport", "direct_leave",
                "caretaker_direct_leave", "direct_demote", "caretaker_direct_demote",
                "direct_dport", "answer", "answer_change"} ->
            {<<"P1", "A", "owner">>, <<"P1", "C", "manager">>}
      \* C, a former manager of P1, created its lease (finding M2)
      [] s = "dport_former"    -> {<<"P1", "A", "owner">>}
      [] s = "residence"       -> {}

InitPorts == {m[1] : m \in Members(SCENARIO)}
\* portfolios.caretaker_user_id: C already named in the scenarios where it ends
InitCare(q) == IF q = "P1" /\ SCENARIO \in {"caretaker_svc_rpc", "caretaker_svc_rule",
                                            "caretaker_direct_rpc", "caretaker_direct_dport",
                                            "caretaker_direct_leave", "caretaker_direct_demote"}
               THEN "C" ELSE NoP
\* portfolio_members.invited_by of the initial rows: in "inviter", A created P1
\* and invited C (InvitedBy below adds the rows accept_invitation inserts)
InitInvitedBy(q, v) == IF SCENARIO = "inviter" /\ q = "P1" /\ v = "C" THEN "A" ELSE NoP
InitRole(q, v) ==
    IF \E m \in Members(SCENARIO) : m[1] = q /\ m[2] = v
    THEN (CHOOSE m \in Members(SCENARIO) : m[1] = q /\ m[2] = v)[3]
    ELSE "none"
\* portfolios.created_by (scenario 17 hands the portfolio to another creator)
InitCreatedBy(q) ==
    CASE q \notin InitPorts                -> NoP
      [] SCENARIO \in {"gotrue_setnull", "gotrue_acct"} -> "B"
      [] InitRole(q, "A") = "owner"        -> "A"
      [] OTHER                             -> "B"
\* one lease per portfolio in the deposit and GoTrue scenarios; leases.created_by
HasLease(q) == q \in InitPorts /\ SCENARIO \in {"deposit", "deposit_acct", "gotrue_setnull", "gotrue_acct",
                                                  "insert", "insert_mig", "dport_former"}
LeaseBy(q) == CASE SCENARIO \in {"gotrue_setnull", "gotrue_acct"} -> "B"
                [] SCENARIO = "dport_former"                    -> "C"
                [] OTHER                                        -> "A"

(* The one invitation of a scenario (public.portfolio_invitations). *)
Inv == CASE SCENARIO \in {"freeze", "freeze_orphan"} ->
                [p |-> "P1", by |-> "B", for |-> "A", role |-> "owner"]
         [] SCENARIO = "accept_delete"   -> [p |-> "P1", by |-> "A", for |-> "C", role |-> "viewer"]
         [] SCENARIO = "accept_owner_delete" -> [p |-> "P1", by |-> "A", for |-> "C", role |-> "owner"]
         [] SCENARIO = "inviter_demoted" -> [p |-> "P1", by |-> "B", for |-> "C", role |-> "manager"]
         [] SCENARIO = "mixed"           -> [p |-> "P2", by |-> "A", for |-> "B", role |-> "manager"]
         [] SCENARIO = "team"            -> [p |-> "P2", by |-> "B", for |-> "C", role |-> "owner"]
         [] OTHER                        -> [p |-> "P3", by |-> NoP, for |-> NoP, role |-> "none"]
InvP == Inv.p
InvBy == Inv.by

(* B's two notifications in P1 (public.notifications, "notes" only).  Their *)
(* user_id references auth.users ON DELETE CASCADE; GoTrue's cascade       *)
(* deletes them after the profile and the other rows (the constraint was   *)
(* created last), n1 before n2 (its scan order).                           *)
Notes == {"n1", "n2"}
NoteOwner == "B"
InitNotes == IF SCENARIO = "notes" THEN Notes ELSE {}

-----------------------------------------------------------------------------
VARIABLES
    db,   \* committed rows, uncommitted writes and row locks (record, see Init)
    pc,   \* pc[t]: the next statement of process t
    lv,   \* lv[t]: locals of t (attempts, v_memberships, lock order, v_deleted)
    gh    \* history (ghost) values used only by the properties

vars == <<db, pc, lv, gh>>

\* Each process's script, computed once: TLC evaluates a constant definition
\* without arguments once, but Script(t) again on every call.
Scr == [t \in Procs |-> Script(t)]
Kind(t) == Scr[t].k
Usr(t)  == Scr[t].u
Prt(t)  == Scr[t].q
Tgt(t)  == Scr[t].v
Rl(t)   == Scr[t].r

(* public.audit_logs, one row per (portfolio, actor): every member of a    *)
(* portfolio has one with themselves as actor (create_portfolio,          *)
(* accept_invitation and every audited write record auth.uid()), and so    *)
(* do the former members of FormerAud.  A row's only writers are GoTrue's  *)
(* SET NULL of actor_id (for that user) and a deletion of its portfolio    *)
(* (delete_locked_portfolios deletes the trail first); two deletions of    *)
(* one portfolio are serialised by its row lock, and the rows other        *)
(* transactions insert are invisible until they commit.  So a row matters  *)
(* only where a GoTrue delete of its actor can meet a deletion of its      *)
(* portfolio, and InitAud leaves the others out.                           *)
GUsers == {Usr(s) : s \in {g \in Procs : Kind(g) \in {"acct", "gotrue"}}}
Deletable(q, v) ==
    \E s \in Procs : \/ Kind(s) = "dport" /\ Prt(s) = q
                     \/ Kind(s) = "acct" /\ Usr(s) # v /\ InitRole(q, Usr(s)) = "owner"
FormerAud == CASE SCENARIO \in {"gotrue_setnull", "gotrue_acct"} -> {<<"P1", "B">>} \* B created P1
               [] SCENARIO = "dport_former"                    -> {<<"P1", "C">>}
               [] OTHER                                        -> {}
InitAud == {r \in Ports \X GUsers :
               (InitRole(r[1], r[2]) # "none" \/ r \in FormerAud) /\ Deletable(r[1], r[2])}
\* No audit row is added during a run: no user whose GoTrue delete runs
\* joins (accept_invitation, create_portfolio) a portfolio a deletion can
\* meet; every other audited write is by a member, who has the row already.
ASSUME \A s \in Procs :
           Kind(s) \in {"accept", "create"} /\ Usr(s) \in GUsers =>
               ~Deletable(IF Kind(s) = "accept" THEN InvP ELSE Prt(s), Usr(s))
\* Merges of set_caretaker and set_owner_abroad (C_Do, O_Do) rely on this:
\* no service-role or GoTrue write changes the caller's own membership.
ASSUME \A s, g \in Procs :
           Kind(s) \in {"care", "abroad"} /\ Kind(g) \in {"svc", "svcl", "gotrue", "acct"} =>
               Usr(s) \notin {Usr(g), Tgt(g)}
\* A deletion's own audit rows are not written by anyone else meanwhile:
\* no direct Auth delete of a user who deletes a portfolio or an account.
ASSUME \A s, g \in Procs :
           Kind(s) \in {"dport", "acct"} /\ Kind(g) = "gotrue" => Usr(s) # Usr(g)

(* portfolio_members.invited_by, derived rather than stored: a row of the  *)
(* invitation's portfolio and invitee that was not there at the start was  *)
(* inserted by accept_invitation (X_Ins) with the inviter, and no other     *)
(* process inserts that row (the ASSUME).  GoTrue's SET NULL is not        *)
(* written back: once an inviter's deletion has committed, no step of that *)
(* user runs again (G_User answers 404), so the value is never read.       *)
InvitedBy(q, v) ==
    IF q = InvP /\ v = Inv.for /\ InitRole(q, v) = "none" THEN InvBy ELSE InitInvitedBy(q, v)
ASSUME \A s \in Procs : Kind(s) = "create" => ~(Prt(s) = InvP /\ Usr(s) = Inv.for)

ProcsOrNo == Procs \cup {NoP}

(* What a statement of transaction t sees: committed rows plus t's writes. *)
MemV(t, q, v) == IF db.mDirty[q][v] = t THEN db.mNew[q][v] ELSE db.mem[q][v]
PortV(t, q)   == IF db.pDel[q] = t THEN FALSE ELSE IF db.pNew[q] = t THEN TRUE ELSE q \in db.port
OwnersV(t, q) == {v \in Users : MemV(t, q, v) = "owner"}
OwnersC(q)    == {v \in Users : db.mem[q][v] = "owner"}
InvV(t)       == IF db.invX = t /\ db.invNew # NoP THEN db.invNew ELSE db.inv
InvExists     == db.inv \in {"pending", "revoked", "accepted"}
CareV(t, q)   == IF db.cBy[q] = t THEN db.cNew[q] ELSE db.care[q]
AbroadV(t, q) == IF db.aBy[q] = t THEN db.aNew[q] ELSE db.abroad[q]
ResV(t, u)    == IF db.resX[u] = t THEN db.resNew[u] ELSE db.res[u]

(* Blockers: the other transactions holding a conflicting lock. *)
BX(t, q)      == ({db.pX[q], db.pNKU[q]} \cup db.pKS[q]) \ {t, NoP}
BNKU(t, q)    == {db.pX[q], db.pNKU[q]} \ {t, NoP}
BKS(t, q)     == {db.pX[q]} \ {t, NoP}
BPK(t, q)     == {db.pNew[q], db.pDel[q]} \ {t, NoP}     \* unique-index wait on portfolios.id
BProfX(t, u)  == ({db.profX[u]} \cup db.profKS[u]) \ {t, NoP}
BProfKS(t, u) == {db.profX[u]} \ {t, NoP}
BUX(t, u)     == ({db.uX[u]} \cup db.uKS[u]) \ {t, NoP}
BUKS(t, u)    == {db.uX[u]} \ {t, NoP}
BL(t, q)      == {db.lX[q]} \ {t, NoP}                   \* lease row: NKU and X conflict
BLX(t, q)     == BL(t, q) \cup (db.lKS[q] \ {t})         \* lease FOR UPDATE / DELETE: also KS
BLKS(t, q)    == {db.lDel[q]} \ {t, NoP}                 \* lease KS: only a DELETE holds X
BM(t, q, v)   == {db.mDirty[q][v]} \ {t, NoP}            \* member row / its primary key
\* an UPDATE or DELETE of a member row also waits for FOR SHARE holders
BMW(t, q, v)  == BM(t, q, v) \cup (db.mSh[q][v] \ {t})
BRes(t, u)    == {db.resX[u]} \ {t, NoP}                 \* profile_residences row
BAud(t, q, v) == {db.audX[q][v]} \ {t, NoP}              \* audit row: SET NULL and DELETE conflict
BInv(t)       == {db.invX} \ {t, NoP}
BN(t, n)      == {db.nX[n]} \ {t, NoP}                   \* notification row: NKU and X conflict

-----------------------------------------------------------------------------
(* Releasing, committing *)
Rel(f, t)  == [x \in DOMAIN f |-> IF f[x] = t THEN NoP ELSE f[x]]
RelS(f, t) == [x \in DOMAIN f |-> f[x] \ {t}]

(* ReleaseAll and CommitDB take the state as a bound variable (Once): TLC  *)
(* evaluates an operator's argument again at each use, and these refer to  *)
(* it dozens of times, while a bound variable holds a value.  Same result, *)
(* a fraction of the time.                                                 *)
Once(Op(_, _), d0, t) == CHOOSE r \in {Op(d, t) : d \in {d0}} : TRUE

ReleaseBody(d, t) ==
    [d EXCEPT !.frz = Rel(@, t), !.profX = Rel(@, t), !.profKS = RelS(@, t),
              !.uX = Rel(@, t), !.uKS = RelS(@, t),
              !.pX = Rel(@, t), !.pNKU = Rel(@, t), !.pKS = RelS(@, t),
              !.pNew = Rel(@, t), !.pDel = Rel(@, t), !.cbNull = Rel(@, t),
              !.mDirty = [q \in Ports |-> Rel(@[q], t)],
              !.mNew = [q \in Ports |-> [v \in Users |->
                           IF d.mDirty[q][v] = t THEN "none" ELSE @[q][v]]],
              !.lX = Rel(@, t), !.lDel = Rel(@, t), !.lKS = RelS(@, t),
              !.invX = IF @ = t THEN NoP ELSE @,
              !.invNew = IF d.invX = t THEN NoP ELSE @,
              !.nX = Rel(@, t), !.nDel = Rel(@, t),
              \* residence: the caretaker's and the answer's uncommitted values,
              \* FOR SHARE on member rows, the residence row
              !.cBy = Rel(@, t), !.cNew = [q \in Ports |-> IF d.cBy[q] = t THEN NoP ELSE @[q]],
              !.mSh = [q \in Ports |-> RelS(@[q], t)],
              !.aBy = Rel(@, t), !.aNew = [q \in Ports |-> IF d.aBy[q] = t THEN "null" ELSE @[q]],
              !.resX = Rel(@, t), !.resNew = [u \in Users |-> IF d.resX[u] = t THEN "none" ELSE @[u]],
              !.audX = [q \in Ports |-> Rel(@[q], t)]]
ReleaseAll(d, t) == Once(ReleaseBody, d, t)

(* ROLLBACK TO the savepoint of the lock-and-delete loop (latest:          *)
(* delete_portfolio and admin_delete_account_data, "exception when         *)
(* deadlock_detected"): drops what the loop body did; the profile lock and *)
(* the account_deletions row written before the loop stay, with the KEY   *)
(* SHARE lock that row's foreign-key check took on auth.users (and, in     *)
(* mutant "residence_first", the residence row written before the loop).   *)
SubRelease(d, t) == [ReleaseAll(d, t) EXCEPT !.frz = d.frz, !.profX = d.profX, !.uKS = d.uKS,
                        !.resX = IF Mut("residence_first") THEN d.resX ELSE @,
                        !.resNew = IF Mut("residence_first") THEN d.resNew ELSE @]

CommitBody(d, t) ==
    LET deleted == {q \in Ports : d.pDel[q] = t}
        created == {q \in Ports : d.pNew[q] = t}
        goneU   == {u \in Users : d.uX[u] = t}    \* only GoTrue's DELETE takes uX
    IN ReleaseAll(
        [d EXCEPT
            !.port      = (@ \ deleted) \cup created,
            !.createdBy = [q \in Ports |-> IF q \in created THEN Usr(t)
                                           ELSE IF d.cbNull[q] = t THEN NoP ELSE @[q]],
            \* portfolios_after_delete retires the id; the insert trigger registers it
            !.reg       = [q \in Ports |-> IF q \in deleted THEN "retired"
                                           ELSE IF q \in created THEN "live" ELSE @[q]],
            !.mem       = [q \in Ports |-> [v \in Users |->
                              IF d.mDirty[q][v] = t THEN d.mNew[q][v] ELSE @[q][v]]],
            !.users     = @ \ goneU,
            \* account_deletions.user_id references auth.users on delete cascade
            !.frozen    = (@ \cup {u \in Users : d.frz[u] = t}) \ goneU,
            !.lease     = [q \in Ports |-> @[q] /\ d.lDel[q] # t],
            !.notes     = @ \ {n \in Notes : d.nDel[n] = t},
            \* residence: the caretaker goes with its portfolio
            !.care      = [q \in Ports |-> IF q \in deleted THEN NoP
                                           ELSE IF d.cBy[q] = t THEN d.cNew[q] ELSE @[q]],
            !.abroad    = [q \in Ports |-> IF d.aBy[q] = t THEN d.aNew[q] ELSE @[q]],
            !.res       = [u \in Users |-> IF d.resX[u] = t THEN d.resNew[u] ELSE @[u]],
            \* the audit trail goes with its portfolio; GoTrue's SET NULL of
            \* actor_id leaves the row without a user
            !.aud       = {r \in @ : r[1] \notin deleted /\ r[2] \notin goneU},
            \* portfolio_invitations.portfolio_id on delete cascade
            !.inv       = IF d.inv # "none" /\ InvP \in deleted THEN "gone"
                          ELSE IF d.invX = t /\ d.invNew # NoP THEN d.invNew ELSE @],
        t)
CommitDB(d, t) == Once(CommitBody, d, t)

(* Ghost bookkeeping shared by every commit of t (from the state before it). *)
(* d is the state with t's writes, just before its COMMIT.                  *)
LateWrite(d, t) ==
    \/ \E q \in Ports, v \in Users :
          d.mDirty[q][v] = t /\ d.mNew[q][v] # "none" /\ v \in gh.frozenEver
    \/ \E q \in Ports : d.pNew[q] = t /\ Usr(t) \in gh.frozenEver
GhostCommit(d, t) ==
    [gh EXCEPT !.late = @ \/ LateWrite(d, t),
               !.everDeleted = @ \cup {q \in Ports : d.pDel[q] = t},
               !.reused = @ \/ \E q \in Ports : d.pNew[q] = t /\ q \in gh.everDeleted]

-----------------------------------------------------------------------------
(* Shared statement shapes *)

(* private.after_owner_membership_ends (latest), AFTER UPDATE OF role OR    *)
(* DELETE ON portfolio_members WHEN old.role = 'owner': when v stops being  *)
(* an owner of q and q still exists, v's pending invitations to q are       *)
(* revoked (an UPDATE of the invitation row: it waits for the row lock).    *)
RevokeFires(t, q, v) ==
    /\ ~Mut("no_revoke_trigger") /\ ~Mut("no_inviter_auth")
    /\ q = InvP /\ v = InvBy /\ PortV(t, q)
    /\ db.inv = "pending"
\* with the row lock held, the UPDATE re-checks "revoked_at is null and accepted_at is null"
Revoke(d, t) == IF InvV(t) = "pending" THEN [d EXCEPT !.invX = t, !.invNew = "revoked"]
                ELSE [d EXCEPT !.invX = t]

(* require_portfolio_role(q, roles) for the caller u (STABLE, statement     *)
(* snapshot).  roles = {} means "any role" (remove_member on oneself).     *)
HasRole(t, q, u, roles) ==
    IF roles = {} THEN MemV(t, q, u) # "none" ELSE MemV(t, q, u) \in roles

-----------------------------------------------------------------------------
(* Account deletion: delete-account/handler.ts deleteAccount(), POST.      *)
(*   liveAccount -> admin_delete_account_data (latest) -> auth.admin.      *)
(*   deleteUser (GoTrue: DELETE FROM auth.users and its FK actions) ->     *)
(*   drainStorageCleanup (in ../StorageCleanup).                           *)
(* admin_delete_account_data:                                              *)
(*   select 1 from profiles where id = u for update;                       *)
(*   insert into private.account_deletions ... on conflict do nothing;     *)
(*   loop (subtransaction, retried on deadlock_detected, 3 attempts):      *)
(*     v_memberships := portfolios u belongs to;                           *)
(*     lock_portfolios_for_deletion(v_memberships)   -- id order;          *)
(*     v_deleted := admin_account_deletion_scope(u) within v_memberships;  *)
(*     delete_locked_portfolios(v_deleted);                                *)
(*     delete u's memberships in v_memberships;                            *)
(*   delete notifications; return.                                         *)
-----------------------------------------------------------------------------
IsAcct(t) == Kind(t) = "acct"
Goto(t, l) == pc' = [pc EXCEPT ![t] = l]

SortedSeq(M) == SelectSeq(PortOrder, LAMBDA x : x \in M)
Perms(M) == {s \in [1..Cardinality(M) -> M] : \A i, j \in 1..Cardinality(M) : i # j => s[i] # s[j]}
LockOrders(M) == IF Mut("unordered_locks") THEN Perms(M) ELSE {SortedSeq(M)}

\* public.admin_account_deletion_scope(u) (20261103194829): u is an owner and no other owner
ScopeV(t, u, M) == {q \in M : PortV(t, q) /\ OwnersV(t, q) = {u}}

\* liveAccount(): an account that is already gone counts as deleted (success)
A_Live(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_live"
    /\ IF Usr(t) \notin db.users
       THEN /\ Goto(t, "a_ok")
            /\ gh' = [gh EXCEPT !.succ[Usr(t)] = TRUE]
       ELSE /\ Goto(t, "a_prof")
            /\ UNCHANGED gh
    /\ UNCHANGED <<db, lv>>

\* "perform 1 from public.profiles p where p.id = p_user_id for update"
A_Prof(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_prof"
    /\ LET u == Usr(t) IN
       IF Mut("no_freeze") \/ u \notin db.users
       THEN UNCHANGED db
       ELSE /\ BProfX(t, u) = {}
            /\ db' = [db EXCEPT !.profX[u] = t]
    /\ Goto(t, "a_frz")
    /\ UNCHANGED <<lv, gh>>

\* "insert into private.account_deletions (user_id) select u where exists
\*  (auth user) on conflict (user_id) do nothing": a new row's FK check takes
\*  KEY SHARE on the auth.users row.
FreezeInserts(t) ==
    /\ ~Mut("no_freeze")
    /\ Usr(t) \in db.users /\ Usr(t) \notin db.frozen /\ db.frz[Usr(t)] # t
\* Mutant "residence_first": the residence row is cleared here, before the
\* loop, instead of last.
ResFirst(t) == Mut("residence_first") /\ Usr(t) \in db.users /\ db.resX[Usr(t)] # t
FrzNeed(t) == (IF FreezeInserts(t) THEN BUKS(t, Usr(t)) \cup ({db.frz[Usr(t)]} \ {t, NoP}) ELSE {})
              \cup (IF ResFirst(t) THEN BRes(t, Usr(t)) ELSE {})
A_Frz(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_frz"
    /\ FrzNeed(t) = {}
    /\ LET u == Usr(t)
           d1 == IF FreezeInserts(t) THEN [db EXCEPT !.frz[u] = t, !.uKS[u] = @ \cup {t}] ELSE db
       IN db' = IF ResFirst(t) THEN [d1 EXCEPT !.resX[u] = t, !.resNew[u] = "none"] ELSE d1
    /\ Goto(t, "a_mem")
    /\ UNCHANGED <<lv, gh>>

\* loop body: v_memberships (a fresh statement); the lock order is fixed here
\* WAKE_FIRST: the transactions woken by the rollback have moved on
Yielded(t) == \A y \in lv[t].yield : pc[y[1]] # y[2]

A_Mem(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_mem"
    /\ Yielded(t)
    /\ LET u == Usr(t)
           M == {q \in Ports : MemV(t, q, u) # "none"}
       IN \E o \in LockOrders(M) :
            lv' = [lv EXCEPT ![t].vids = M, ![t].order = o, ![t].yield = {}, ![t].gset = FALSE,
                             ![t].vdel = IF Mut("scope_before_lock") THEN ScopeV(t, u, M) ELSE {}]
    /\ Goto(t, "a_lock")
    /\ UNCHANGED <<db, gh>>

\* the rows of the deletions' audit-trail DELETE that another transaction can
\* hold: those of other users (a deleting user's own rows are written by no
\* one else meanwhile: the ASSUME on direct Auth deletes, and their own
\* delete-account runs GoTrue after this transaction)
AudOf(t, D) == {r \in db.aud : r[1] \in D /\ r[2] # Usr(t)}

\* private.lock_portfolios_for_deletion: "... where p.id = any (ids) order by
\* p.id for update", one row per step.  A row deleted meanwhile is skipped.
\* When every row is locked, v_deleted is read (a new statement; nobody else
\* can change these portfolios' members while the rows are locked, so the
\* read is merged into this step).
A_Lock(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_lock"
    /\ IF lv[t].order = <<>>
       THEN LET V == IF Mut("scope_before_lock") THEN lv[t].vdel ELSE ScopeV(t, Usr(t), lv[t].vids)
            IN /\ lv' = [lv EXCEPT ![t].vdel = V]
               /\ Goto(t, IF AudOf(t, {q \in V : PortV(t, q)}) = {} THEN "a_purge" ELSE "a_aud")
               /\ UNCHANGED db
       ELSE LET q == Head(lv[t].order) IN
            /\ IF q \in db.port
               THEN /\ BX(t, q) = {}
                    /\ db' = [db EXCEPT !.pX[q] = t]
               ELSE UNCHANGED db
            /\ lv' = [lv EXCEPT ![t].order = Tail(@)]
            /\ UNCHANGED pc
    /\ UNCHANGED gh

(* delete_locked_portfolios(v_deleted) (latest): the audit trail first    *)
(* (a_aud, RowStep; merged here when no other transaction can hold one of *)
(* its rows), then the portfolios with their ON DELETE CASCADE (members,   *)
(* invitations, the lease), and "delete from portfolio_members where       *)
(* user_id = u and portfolio_id = any (v_memberships)", whose owner rows   *)
(* fire after_owner_membership_ends; then the transaction commits.         *)
PurgeD(t) == {q \in lv[t].vdel : PortV(t, q)}
PurgeRows(t) ==
    LET D == PurgeD(t) IN
    {<<q, v>> \in D \X Users : MemV(t, q, v) # "none"}
    \cup {<<q, Usr(t)>> : q \in {q2 \in lv[t].vids \ D : MemV(t, q2, Usr(t)) # "none"}}
PurgeRevokes(t) ==
    \E q \in lv[t].vids \ PurgeD(t) :
        MemV(t, q, Usr(t)) = "owner" /\ RevokeFires(t, q, Usr(t))
CascadeInv(t, D) == InvP \in D /\ InvExists
PurgeNeed(t) ==
    LET D == PurgeD(t) IN
    UNION {BX(t, q) : q \in D}
    \cup UNION {BLX(t, q) : q \in {q2 \in D : db.lease[q2]}}
    \cup UNION {BMW(t, r[1], r[2]) : r \in PurgeRows(t)}
    \cup (IF PurgeRevokes(t) \/ CascadeInv(t, D) THEN BInv(t) ELSE {})
PurgeWrite(t, D, R) ==
    [db EXCEPT
        !.pX     = [q \in Ports |-> IF q \in D THEN t ELSE @[q]],
        !.pDel   = [q \in Ports |-> IF q \in D THEN t ELSE @[q]],
        !.mDirty = [q \in Ports |-> [v \in Users |-> IF <<q, v>> \in R THEN t ELSE @[q][v]]],
        !.mNew   = [q \in Ports |-> [v \in Users |-> IF <<q, v>> \in R THEN "none" ELSE @[q][v]]],
        !.lX     = [q \in Ports |-> IF q \in D /\ db.lease[q] THEN t ELSE @[q]],
        !.lDel   = [q \in Ports |-> IF q \in D /\ db.lease[q] THEN t ELSE @[q]]]

\* residence: portfolio_members_after_caretaker_ends on u's manager rows of the
\* portfolios that survive clears u as their caretaker (under the portfolio
\* lock A_Lock took)
PurgeCare(t) ==
    IF Mut("no_care_trigger") THEN {}
    ELSE {q \in lv[t].vids \ PurgeD(t) : MemV(t, q, Usr(t)) = "manager" /\ CareV(t, q) = Usr(t)}
ClearCare(d, t, Q) == [d EXCEPT !.cBy  = [q \in Ports |-> IF q \in Q THEN t ELSE @[q]],
                                !.cNew = [q \in Ports |-> IF q \in Q THEN NoP ELSE @[q]]]
\* residence: is there a client that writes the residence row?  Without one,
\* the row's UPDATE is uncontended and merged into the deletion's last step.
ResStep == \E s \in Procs : Kind(s) = "res"
\* the ghost bookkeeping of the deletion's COMMIT (d: its writes)
AcctGhost(d, t) ==
    LET u == Usr(t)
        D == {q \in Ports : d.pDel[q] = t}
    IN [GhostCommit(d, t) EXCEPT
           !.frozenEver = @ \cup {u},
           !.delBy[u] = @ \cup D,
           !.sole = @ \/ \E q \in D : OwnersC(q) # {u}]
\* residence (latest): "update public.profile_residences set ... = null where
\* user_id = u", unfiltered: it takes the row lock (NO KEY UPDATE)
ResWrite(d, t) ==
    IF Usr(t) \in db.users THEN [d EXCEPT !.resX[Usr(t)] = t, !.resNew[Usr(t)] = "none"] ELSE d

A_Purge(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_purge"
    /\ PurgeNeed(t) = {}
    /\ LET D  == PurgeD(t)
           d1 == PurgeWrite(t, D, PurgeRows(t))
           d2 == IF PurgeRevokes(t) THEN Revoke(d1, t) ELSE d1
           d3 == ClearCare(d2, t, PurgeCare(t))
       IN IF ResStep
          THEN /\ db' = d3
               /\ Goto(t, "a_res")
               /\ UNCHANGED gh
          ELSE LET d4 == IF Mut("residence_first") THEN d3 ELSE ResWrite(d3, t) IN
               /\ db' = CommitDB(d4, t)
               /\ gh' = AcctGhost(d4, t)
               \* the response can be lost: the client then sees a failure
               /\ \E nxt \in {"g_user", "a_failed"} : Goto(t, nxt)
    /\ UNCHANGED lv

\* residence: the profile_residences UPDATE, after the loop and the
\* notifications (outside the subtransaction), then COMMIT.  Mutant
\* "residence_filtered": "... and (residence_country is not null or ...)":
\* the row it reads is NULL, so it skips it without waiting.
ResSkips(t) == (Mut("residence_filtered") /\ ResV(t, Usr(t)) = "none") \/ Mut("residence_first")
ResNeed(t) == IF Usr(t) \in db.users /\ ~ResSkips(t) THEN BRes(t, Usr(t)) ELSE {}
A_Res(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_res"
    /\ ResNeed(t) = {}
    /\ LET d == IF ResSkips(t) THEN db ELSE ResWrite(db, t) IN
       /\ db' = CommitDB(d, t)
       /\ gh' = AcctGhost(d, t)
    /\ \E nxt \in {"g_user", "a_failed"} : Goto(t, nxt)
    /\ UNCHANGED lv

(* GoTrue auth.admin.deleteUser(u): DELETE FROM auth.users (row lock X),   *)
(* then its FK actions (AFTER triggers RI_ConstraintTrigger_a_<oid>, run   *)
(* in name order).  On a migrated database that is the constraints'       *)
(* creation order (pg_trigger on tool/db/reset.sh's database): profiles    *)
(* (cascade), portfolios.created_by (set null), portfolio_members.user_id  *)
(* (cascade) and .invited_by (set null), portfolio_invitations.*, the      *)
(* child tables' created_by and the like (set null; here the lease's),     *)
(* notifications (cascade: n1, then n2), audit_logs.actor_id (set null),   *)
(* account_deletions (cascade), and last residence's portfolios.           *)
(* caretaker_user_id (set null), whose name can sort elsewhere once the    *)
(* OIDs gain a digit ("caretaker_first").  A restored database re-creates  *)
(* them by name (pg_dump --section=post-data; pg_trigger on a pg_dump |    *)
(* psql copy, replay/residence.sh): account_deletions, audit_logs, the     *)
(* child tables (leases), notifications, portfolio_members.invited_by and  *)
(* .user_id, portfolios.caretaker_user_id and .created_by, profiles.       *)
(* account_deletions' cascade has nothing to wait for and is merged into   *)
(* g_commit.  portfolio_invitations' SET NULLs are not modelled: by the    *)
(* time GoTrue runs, admin_delete_account_data has revoked the user's      *)
(* invitations (../Invitations models them).  The same steps serve a       *)
(* direct Auth delete outside the Edge Function ("goB", "goC").            *)
GOrder == CASE GOTRUE_ORDER = "portfolios_first" ->
               <<"g_prof", "g_port", "g_mem", "g_inv", "g_lease", "g_note1", "g_note2", "g_audit",
                 "g_care">>
          [] GOTRUE_ORDER = "leases_first" ->
               <<"g_prof", "g_lease", "g_port", "g_mem", "g_inv", "g_note1", "g_note2", "g_audit",
                 "g_care">>
          [] GOTRUE_ORDER = "caretaker_first" ->
               <<"g_care", "g_prof", "g_port", "g_mem", "g_inv", "g_lease", "g_note1", "g_note2",
                 "g_audit">>
          [] GOTRUE_ORDER = "restored" ->
               <<"g_audit", "g_lease", "g_note1", "g_note2", "g_inv", "g_mem", "g_care", "g_port",
                 "g_prof">>
\* An action on a column no process of the scenario can set (no caretaker is
\* ever named; no row is invited by anyone; no audit row a deletion can
\* meet) has no row to act on in any reachable state and takes no lock: it
\* is left out, so the scenarios without one keep their state space.
GUsed(l) ==
    CASE l = "g_care"  -> (\E s \in Procs : Kind(s) = "care") \/ (\E q \in Ports : InitCare(q) # NoP)
      [] l = "g_inv"   -> (\E s \in Procs : Kind(s) = "accept")
                          \/ (\E q \in Ports, v \in Users : InitInvitedBy(q, v) # NoP)
      [] l = "g_audit" -> InitAud # {}
      [] OTHER         -> TRUE
GSeq == SelectSeq(GOrder, GUsed)
GNext(l) == LET i == CHOOSE j \in 1..Len(GSeq) : GSeq[j] = l IN
            IF i = Len(GSeq) THEN "g_commit" ELSE GSeq[i + 1]
IsG(t) == Kind(t) \in {"acct", "gotrue"}
GDone(t) == IF Kind(t) = "acct" THEN "a_ok" ELSE "done"

G_User(t) ==
    /\ IsG(t) /\ pc[t] = "g_user"
    /\ LET u == Usr(t) IN
       IF u \notin db.users
       THEN \* 404: "already gone counts as success"
            /\ Goto(t, GDone(t))
            /\ gh' = IF Kind(t) = "acct" THEN [gh EXCEPT !.succ[u] = TRUE] ELSE gh
            /\ UNCHANGED db
       ELSE /\ BUX(t, u) = {}
            /\ db' = [db EXCEPT !.uX[u] = t]
            /\ Goto(t, Head(GSeq))
            /\ UNCHANGED gh
    /\ UNCHANGED lv

G_Prof(t) ==
    /\ IsG(t) /\ pc[t] = "g_prof"
    /\ BProfX(t, Usr(t)) = {}
    /\ db' = [db EXCEPT !.profX[Usr(t)] = t]
    /\ Goto(t, GNext("g_prof"))
    /\ UNCHANGED <<lv, gh>>

\* "update portfolio_members set invited_by = null where invited_by = u": a
\* row lock (NO KEY UPDATE) on each row u invited, the role unchanged.  No
\* trigger of these rows fires (portfolio_members_after_caretaker_ends is
\* "after update of role, portfolio_id, user_id"; the audit row takes no
\* portfolio lock).
GInvRows(t) == {<<q, v>> \in Ports \X (Users \ {Usr(t)}) :
                    MemV(t, q, v) # "none" /\ InvitedBy(q, v) = Usr(t) /\ db.mDirty[q][v] # t}

(* RowStep: a statement that locks several rows one by one, in an order    *)
(* the plan and the heap decide (an index on the foreign-key column, whose *)
(* duplicates are in heap order, or a scan): any order.  The rows are the  *)
(* statement's snapshot; a row is waited for, then re-checked              *)
(* (EvalPlanQual) and skipped if it no longer matches.  With two or more   *)
(* rows the order is chosen first (a step without a lock); with one the    *)
(* step locks it at once.                                                  *)
(*   g_port   portfolios.created_by SET NULL (NO KEY UPDATE)               *)
(*   g_mem    portfolio_members.user_id CASCADE (DELETE); an owner row     *)
(*            queues after_owner_membership_ends, which fires at g_commit  *)
(*   g_inv    portfolio_members.invited_by SET NULL (NO KEY UPDATE)        *)
(*   g_lease  leases.created_by SET NULL (NO KEY UPDATE)                   *)
(*   g_audit  audit_logs.actor_id SET NULL                                 *)
(*   g_care   residence: portfolios.caretaker_user_id SET NULL (NO KEY     *)
(*            UPDATE; its BEFORE trigger takes no lock for NULL), merged   *)
(*            with portfolio_members_after_caretaker_ends of the cascaded  *)
(*            manager rows, which runs after every first-level action and  *)
(*            finds the column already NULL: between the two, nobody can   *)
(*            name u again, because set_caretaker's foreign-key check      *)
(*            needs KEY SHARE on u's auth.users row, which this DELETE     *)
(*            holds until it commits                                       *)
(*   a_aud, d_aud  delete_locked_portfolios' "delete from audit_logs where *)
(*            portfolio_id = any (...)", before the portfolios' DELETE     *)
RowLabels == {"g_port", "g_mem", "g_inv", "g_lease", "g_audit", "g_care", "a_aud", "d_aud"}
RowSet(l, t) ==
    LET u == Usr(t) IN
    CASE l = "g_port"  -> {q \in db.port : db.createdBy[q] = u /\ db.cbNull[q] # t}
      [] l = "g_mem"   -> {q \in Ports : MemV(t, q, u) # "none"}
      [] l = "g_inv"   -> GInvRows(t)
      [] l = "g_lease" -> {q \in Ports : db.lease[q] /\ LeaseBy(q) = u /\ db.lX[q] # t}
      [] l = "g_audit" -> {r \in db.aud : r[2] = u /\ db.audX[r[1]][u] # t}
      [] l = "g_care"  -> {q \in db.port : CareV(t, q) = u}
      [] l = "a_aud"   -> {r \in AudOf(t, {q \in lv[t].vdel : PortV(t, q)}) : db.audX[r[1]][r[2]] # t}
      [] l = "d_aud"   -> {r \in AudOf(t, {Prt(t)}) : db.audX[r[1]][r[2]] # t}
RowBlock(l, t, r) ==
    CASE l \in {"g_port", "g_care"} -> BNKU(t, r)
      [] l = "g_mem"   -> BMW(t, r, Usr(t))
      [] l = "g_inv"   -> BMW(t, r[1], r[2])
      [] l = "g_lease" -> BL(t, r)
      [] OTHER         -> BAud(t, r[1], r[2])
RowTake(l, t, r) ==
    LET u == Usr(t) IN
    CASE l = "g_port"  -> IF r \in db.port /\ db.createdBy[r] = u
                          THEN [db EXCEPT !.pNKU[r] = t, !.cbNull[r] = t] ELSE db
      [] l = "g_mem"   -> IF MemV(t, r, u) # "none"
                          THEN [db EXCEPT !.mDirty[r][u] = t, !.mNew[r][u] = "none"] ELSE db
      [] l = "g_inv"   -> IF MemV(t, r[1], r[2]) # "none"
                          THEN [db EXCEPT !.mDirty[r[1]][r[2]] = t,
                                          !.mNew[r[1]][r[2]] = db.mem[r[1]][r[2]]]
                          ELSE db
      [] l = "g_lease" -> IF db.lease[r] THEN [db EXCEPT !.lX[r] = t] ELSE db
      [] l = "g_care"  -> IF r \in db.port /\ CareV(t, r) = u
                          THEN ClearCare([db EXCEPT !.pNKU[r] = t], t, {r}) ELSE db
      [] OTHER         -> IF r \in db.aud THEN [db EXCEPT !.audX[r[1]][r[2]] = t] ELSE db
\* the cascaded owner rows, for after_owner_membership_ends at g_commit
RowRev(l, t, r) == IF l = "g_mem" /\ MemV(t, r, Usr(t)) = "owner" THEN lv[t].rev \cup {r} ELSE lv[t].rev
RowNext(l) == CASE l = "a_aud" -> "a_purge"
                [] l = "d_aud" -> "d_purge"
                [] OTHER       -> GNext(l)

RowStep(t) ==
    /\ pc[t] \in RowLabels
    /\ LET l == pc[t] IN
       IF ~lv[t].gset
       THEN LET S == RowSet(l, t) IN
            IF Cardinality(S) <= 1
            THEN /\ \A r \in S : RowBlock(l, t, r) = {}
                 /\ IF S = {} THEN UNCHANGED <<db, lv>>
                    ELSE LET r == CHOOSE x \in S : TRUE IN
                         /\ db' = RowTake(l, t, r)
                         /\ lv' = [lv EXCEPT ![t].rev = RowRev(l, t, r)]
                 /\ Goto(t, RowNext(l))
            ELSE /\ \E o \in Perms(S) : lv' = [lv EXCEPT ![t].order = o, ![t].gset = TRUE]
                 /\ UNCHANGED <<db, pc>>
       ELSE LET r == Head(lv[t].order) IN
            /\ RowBlock(l, t, r) = {}
            /\ db' = RowTake(l, t, r)
            /\ IF Len(lv[t].order) = 1
               THEN /\ lv' = [lv EXCEPT ![t].order = <<>>, ![t].gset = FALSE,
                                        ![t].rev = RowRev(l, t, r)]
                    /\ Goto(t, RowNext(l))
               ELSE /\ lv' = [lv EXCEPT ![t].order = Tail(@), ![t].rev = RowRev(l, t, r)]
                    /\ UNCHANGED pc
    /\ UNCHANGED gh

RowNeed(t) ==
    LET l == pc[t] IN
    IF lv[t].gset THEN RowBlock(l, t, Head(lv[t].order))
    ELSE LET S == RowSet(l, t) IN
         IF Cardinality(S) = 1 THEN RowBlock(l, t, CHOOSE r \in S : TRUE) ELSE {}

\* the notifications cascade, one row per step (DELETE: row lock X)
GNote(t) == IF pc[t] = "g_note1" THEN "n1" ELSE "n2"
GNoteHit(t) == GNote(t) \in db.notes /\ NoteOwner = Usr(t) /\ db.nDel[GNote(t)] # t
G_Note(t) ==
    /\ IsG(t) /\ pc[t] \in {"g_note1", "g_note2"}
    /\ IF GNoteHit(t)
       THEN /\ BN(t, GNote(t)) = {}
            /\ db' = [db EXCEPT !.nX[GNote(t)] = t, !.nDel[GNote(t)] = t]
       ELSE UNCHANGED db
    /\ Goto(t, GNext(pc[t]))
    /\ UNCHANGED <<lv, gh>>

\* The second-level triggers, which fire after every first-level action:
\* after_owner_membership_ends of the cascaded owner rows (revokes the
\* user's pending invitations: the invitation row lock), and the profile's
\* cascade to its profile_residences row (its row lock; that row's other
\* writers hold nothing else, so waiting for both at once hides no cycle);
\* then the account_deletions cascade and the COMMIT.
GRevokes(t) == \E q \in lv[t].rev : RevokeFires(t, q, Usr(t))
GCommitNeed(t) == BRes(t, Usr(t)) \cup (IF GRevokes(t) THEN BInv(t) ELSE {})
G_Commit(t) ==
    /\ IsG(t) /\ pc[t] = "g_commit"
    /\ GCommitNeed(t) = {}
    /\ LET d == IF GRevokes(t) THEN Revoke(db, t) ELSE db IN
       /\ db' = CommitDB(d, t)
       /\ IF Kind(t) = "acct"
          THEN \E ok \in BOOLEAN :
                  /\ Goto(t, IF ok THEN "a_ok" ELSE "a_failed")
                  /\ gh' = [GhostCommit(d, t) EXCEPT !.succ[Usr(t)] = @ \/ ok]
          ELSE /\ Goto(t, "done")
               /\ gh' = GhostCommit(d, t)
    /\ UNCHANGED lv

\* the POST failed (error or lost response): the client retries or gives up
A_Failed(t) ==
    /\ IsAcct(t) /\ pc[t] = "a_failed"
    /\ \/ /\ lv[t].att < MAX_POSTS
          /\ lv' = [lv EXCEPT ![t] = [@ EXCEPT !.att = @ + 1, !.dl = 0, !.vids = {},
                                               !.order = <<>>, !.vdel = {}, !.yield = {},
                                               !.gset = FALSE, !.rev = {}]]
          /\ Goto(t, "a_live")
       \/ /\ Goto(t, "a_gaveup")
          /\ UNCHANGED lv
    /\ UNCHANGED <<db, gh>>

-----------------------------------------------------------------------------
(* Membership changes (latest): remove_member(q, v) (leave when v = u) and *)
(* update_member_role(q, v, r).  lock_portfolio_for_change: authorise      *)
(* (snapshot) -> "for update" on the portfolio -> authorise again.  Then   *)
(* the reads (member_not_found, last_owner: step m_do), then the UPDATE or *)
(* DELETE (firing after_owner_membership_ends) and COMMIT (step m_write).  *)
-----------------------------------------------------------------------------
IsMemberRpc(t) == Kind(t) \in {"remove", "role"}
AuthRoles(t) == IF Kind(t) = "remove" /\ Tgt(t) = Usr(t) THEN {} ELSE {"owner"}
Authorised(t) == HasRole(t, Prt(t), Usr(t), AuthRoles(t))
NewRole(t) == IF Kind(t) = "remove" THEN "none" ELSE Rl(t)
LastOwnerRefuses(t) ==
    /\ ~Mut("no_last_owner")
    /\ MemV(t, Prt(t), Tgt(t)) = "owner" /\ NewRole(t) # "owner"
    /\ Cardinality(OwnersV(t, Prt(t))) = 1
MemberOk(t) ==
    /\ Mut("no_recheck") \/ Authorised(t)
    /\ MemV(t, Prt(t), Tgt(t)) # "none"
    /\ ~LastOwnerRefuses(t)
MemberRevokes(t) ==
    /\ MemV(t, Prt(t), Tgt(t)) = "owner" /\ NewRole(t) # "owner"
    /\ RevokeFires(t, Prt(t), Tgt(t))
\* residence: portfolio_members_after_caretaker_ends (AFTER UPDATE OF role ...
\* OR DELETE, WHEN old.role = 'manager'): clears v as the caretaker of q, an
\* UPDATE of the portfolio row the RPC holds FOR UPDATE already
MemberClearsCare(t) ==
    /\ ~Mut("no_care_trigger")
    /\ MemV(t, Prt(t), Tgt(t)) = "manager" /\ NewRole(t) # "manager"
    /\ CareV(t, Prt(t)) = Tgt(t)
MemberNeed(t) == BMW(t, Prt(t), Tgt(t)) \cup (IF MemberRevokes(t) THEN BInv(t) ELSE {})
                 \cup (IF MemberClearsCare(t) THEN BNKU(t, Prt(t)) ELSE {})
\* authorisation of the caller in the committed state at commit time
AuthorisedC(t) ==
    IF AuthRoles(t) = {} THEN db.mem[Prt(t)][Usr(t)] # "none"
    ELSE db.mem[Prt(t)][Usr(t)] = "owner"

M_Auth(t) ==
    /\ IsMemberRpc(t) /\ pc[t] = "m_auth"
    /\ Goto(t, IF Authorised(t) THEN "m_lock" ELSE "done")   \* forbidden: nothing written
    /\ UNCHANGED <<db, lv, gh>>

M_Lock(t) ==
    /\ IsMemberRpc(t) /\ pc[t] = "m_lock"
    /\ IF Mut("no_member_lock") \/ Prt(t) \notin db.port
       THEN UNCHANGED db
       ELSE /\ BX(t, Prt(t)) = {}
            /\ db' = [db EXCEPT !.pX[Prt(t)] = t]
    /\ Goto(t, "m_do")
    /\ UNCHANGED <<lv, gh>>

\* the statements after the lock: authorise again, member_not_found, last_owner
M_Do(t) ==
    /\ IsMemberRpc(t) /\ pc[t] = "m_do"
    /\ IF MemberOk(t)
       THEN /\ Goto(t, "m_write") /\ UNCHANGED db
       ELSE /\ Goto(t, "done")              \* forbidden / member_not_found / last_owner
            /\ db' = ReleaseAll(db, t)
    /\ UNCHANGED <<lv, gh>>

\* "update public.portfolio_members set role = p_role where ..." or "delete
\* from public.portfolio_members where ...": waits for the row lock and acts
\* on the newest row version (a row deleted meanwhile: 0 rows); its AFTER
\* triggers, by name: portfolio_members_after_caretaker_ends,
\* _after_owner_ends (they see that version as OLD), then _audit, whose
\* insert checks actor_id (the caller): KEY SHARE on the caller's auth.users
\* row (AuditCommit); then COMMIT.
\* the audit row's actor check needs KEY SHARE on the caller's auth.users row,
\* which only a GoTrue delete of the caller holds (uX): a step of its own
\* where one runs, and nothing to wait for otherwise (merged into the write)
AuditFK(t) == \E g \in Procs : g # t /\ IsG(g) /\ Usr(g) = Usr(t)

\* AuthorisedAtCommit concerns a change: a write that found the row gone
\* (0 rows; a direct Auth delete removed it) changes nothing
MemberGhost(d, t) ==
    [GhostCommit(d, t) EXCEPT !.stale = @ \/ (d.mDirty[Prt(t)][Tgt(t)] = t /\ ~AuthorisedC(t))]
M_Write(t) ==
    /\ IsMemberRpc(t) /\ pc[t] = "m_write"
    /\ MemberNeed(t) = {}
    /\ LET q == Prt(t)  v == Tgt(t)
           d1 == IF MemV(t, q, v) = "none" THEN db
                 ELSE [db EXCEPT !.mDirty[q][v] = t, !.mNew[q][v] = NewRole(t)]
           d2 == IF MemberRevokes(t) THEN Revoke(d1, t) ELSE d1
           d3 == IF MemberClearsCare(t)
                 THEN ClearCare([d2 EXCEPT !.pNKU[q] = IF db.pX[q] = t THEN @ ELSE t], t, {q})
                 ELSE d2
       IN IF AuditFK(t) /\ MemV(t, q, v) # "none"
          THEN /\ db' = d3 /\ Goto(t, "m_audit") /\ UNCHANGED gh
          ELSE /\ db' = CommitDB(d3, t)
               /\ gh' = MemberGhost(d3, t)
               /\ Goto(t, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* accept_invitation(token) (latest), for the invitation Inv:              *)
(*   require_active_account(u) -> portfolio KS -> invitation FOR UPDATE -> *)
(*   invalid / revoked / accepted / expired / inviter no longer an owner   *)
(*   (revoke) -> existing member? -> insert member -> mark accepted.       *)
(* create_portfolio(name, p_id) (latest):                                  *)
(*   require_active_account(u) -> existing id? -> registry lookup ->       *)
(*   insert portfolio (registry trigger) and the owner membership.         *)
-----------------------------------------------------------------------------
(* private.require_active_account(u): "for key share" on the profile, then *)
(* (a new statement) account_deletions -> account_deleted.  No profile row *)
(* (the user is gone) means no lock and no account_deletions row.          *)
ActiveNeed(t) == IF Mut("no_freeze") \/ Usr(t) \notin db.users THEN {} ELSE BProfKS(t, Usr(t))
Active(t, next) ==
    LET u == Usr(t) IN
    /\ ActiveNeed(t) = {}
    /\ IF Mut("no_freeze") \/ u \notin db.users
       THEN /\ Goto(t, next) /\ UNCHANGED db
       ELSE IF u \in db.frozen
            THEN /\ Goto(t, "done") /\ db' = ReleaseAll(db, t)   \* account_deleted
            ELSE /\ Goto(t, next) /\ db' = [db EXCEPT !.profKS[u] = @ \cup {t}]

X_Act(t) ==
    /\ Kind(t) = "accept" /\ pc[t] = "x_act"
    /\ Active(t, "x_plock")
    /\ UNCHANGED <<lv, gh>>

\* select the invitation's portfolio (snapshot); if found, KEY SHARE on it
X_PLock(t) ==
    /\ Kind(t) = "accept" /\ pc[t] = "x_plock"
    /\ IF ~InvExists \/ Inv.for # Usr(t)
       THEN /\ db' = CommitDB(db, t)            \* status 'invalid' (committed)
            /\ Goto(t, "done")
       ELSE /\ IF InvP \in db.port
               THEN /\ BKS(t, InvP) = {}
                    /\ db' = [db EXCEPT !.pKS[InvP] = @ \cup {t}]
               ELSE UNCHANGED db
            /\ Goto(t, "x_inv")
    /\ UNCHANGED <<lv, gh>>

InviterGone(t) ==
    /\ ~Mut("no_inviter_check") /\ ~Mut("no_inviter_auth")
    /\ MemV(t, InvP, InvBy) # "owner"

\* "select ... from portfolio_invitations where id = selector for update"
\* and the checks after it (the row lock keeps other writers of the row out)
X_Inv(t) ==
    /\ Kind(t) = "accept" /\ pc[t] = "x_inv"
    /\ IF InvExists THEN BInv(t) = {} ELSE TRUE
    /\ LET st == InvV(t) IN
       CASE st \notin {"pending"} ->                          \* invalid / revoked / accepted
              /\ db' = CommitDB(db, t) /\ Goto(t, "done") /\ UNCHANGED gh
         [] InviterGone(t) ->                                 \* revoke, report 'revoked'
              /\ LET dw == [db EXCEPT !.invX = t, !.invNew = "revoked"] IN
                 /\ db' = CommitDB(dw, t) /\ gh' = GhostCommit(dw, t)
              /\ Goto(t, "done")
         [] MemV(t, InvP, Usr(t)) # "none" ->                 \* existing member keeps the role
              /\ LET dw == [db EXCEPT !.invX = t, !.invNew = "accepted"] IN
                 /\ db' = CommitDB(dw, t) /\ gh' = GhostCommit(dw, t)
              /\ Goto(t, "done")
         [] OTHER ->
              /\ db' = [db EXCEPT !.invX = t]
              /\ Goto(t, "x_ins") /\ UNCHANGED gh
    /\ UNCHANGED lv

\* insert into portfolio_members (portfolio_id, user_id, role, invited_by):
\* primary key, then FK checks (KEY SHARE on the portfolio, on the auth.users
\* rows of the invitee and of the inviter); then "accepted"; COMMIT.
X_Ins(t) ==
    /\ Kind(t) = "accept" /\ pc[t] = "x_ins"
    /\ LET u == Usr(t) IN
       /\ BM(t, InvP, u) \cup BKS(t, InvP) \cup BUKS(t, u) \cup BUKS(t, InvBy) = {}
       /\ IF InvP \notin db.port \/ u \notin db.users \/ InvBy \notin db.users
          THEN /\ db' = ReleaseAll(db, t)            \* foreign_key_violation
               /\ UNCHANGED gh
          ELSE LET dw == [db EXCEPT !.mDirty[InvP][u] = t, !.mNew[InvP][u] = Inv.role,
                                    !.invNew = "accepted"]
               IN /\ db' = CommitDB(dw, t)
                  /\ gh' = [GhostCommit(dw, t) EXCEPT !.inviter = @ \/ db.mem[InvP][InvBy] # "owner"]
    /\ Goto(t, "done")
    /\ UNCHANGED lv

K_Act(t) ==
    /\ Kind(t) = "create" /\ pc[t] = "k_act"
    /\ Active(t, "k_check")
    /\ UNCHANGED <<lv, gh>>

\* "select p.* from portfolios where id = p_id": found -> returned to its
\* creator while still a member, else forbid; not found -> "exists (select 1
\* from private.portfolio_ids where id = p_id)" -> forbid
K_Check(t) ==
    /\ Kind(t) = "create" /\ pc[t] = "k_check"
    /\ LET q == Prt(t)  u == Usr(t) IN
       IF PortV(t, q)
       THEN /\ db' = IF db.createdBy[q] = u /\ MemV(t, q, u) # "none"
                     THEN CommitDB(db, t) ELSE ReleaseAll(db, t)
            /\ Goto(t, "done")
       ELSE IF db.reg[q] # "none" /\ ~Mut("no_id_precheck") /\ ~Mut("no_id_registry")
            THEN /\ db' = ReleaseAll(db, t) /\ Goto(t, "done")     \* forbidden
            ELSE /\ Goto(t, "k_ins") /\ UNCHANGED db
    /\ UNCHANGED <<lv, gh>>

\* insert into portfolios (unique id; FK created_by -> KEY SHARE on auth.users)
\* -> AFTER INSERT private.after_portfolio_insert_register_id: "insert into
\* private.portfolio_ids ... on conflict (id) do nothing; if not found then
\* forbid" -> insert the owner membership -> COMMIT
K_Ins(t) ==
    /\ Kind(t) = "create" /\ pc[t] = "k_ins"
    /\ LET q == Prt(t)  u == Usr(t) IN
       /\ BPK(t, q) \cup BUKS(t, u) = {}
       /\ IF q \in db.port \/ u \notin db.users
             \/ (db.reg[q] # "none" /\ ~Mut("no_id_trigger") /\ ~Mut("no_id_registry"))
          THEN /\ db' = ReleaseAll(db, t)            \* unique / FK violation, forbidden
               /\ UNCHANGED gh
          ELSE LET dw == [db EXCEPT !.pNew[q] = t, !.pX[q] = t,
                                    !.mDirty[q][u] = t, !.mNew[q][u] = "owner"]
               IN /\ db' = CommitDB(dw, t)
                  /\ gh' = GhostCommit(dw, t)
    /\ Goto(t, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* delete_portfolio(q, name) (latest): require owner and name (snapshot);  *)
(* loop (subtransaction, retried on deadlock_detected, 3 attempts):        *)
(*   lock_portfolios_for_deletion([q]); require owner and name again;      *)
(*   delete_locked_portfolios([q]) (cascade); COMMIT.                      *)
-----------------------------------------------------------------------------
D_Auth(t) ==
    /\ Kind(t) = "dport" /\ pc[t] = "d_auth"
    /\ Goto(t, IF PortV(t, Prt(t)) /\ MemV(t, Prt(t), Usr(t)) = "owner" THEN "d_lock" ELSE "done")
    /\ UNCHANGED <<db, lv, gh>>

\* the owner and the name, checked again under the lock (no member of a
\* portfolio held FOR UPDATE changes meanwhile: the RPCs and deletions wait
\* for the lock, and no direct Auth delete or service-role write of the
\* deleting owner runs, the ASSUME above)
DPortOk(t) == PortV(t, Prt(t)) /\ MemV(t, Prt(t), Usr(t)) = "owner"
D_Lock(t) ==
    /\ Kind(t) = "dport" /\ pc[t] = "d_lock"
    /\ Yielded(t)
    /\ IF Prt(t) \in db.port
       THEN /\ BX(t, Prt(t)) = {}
            /\ db' = [db EXCEPT !.pX[Prt(t)] = t]
       ELSE UNCHANGED db
    \* delete_locked_portfolios: the audit trail first (d_aud) where another
    \* transaction can hold one of its rows
    /\ Goto(t, IF Prt(t) \in db.port /\ DPortOk(t) /\ AudOf(t, {Prt(t)}) # {} THEN "d_aud" ELSE "d_purge")
    /\ lv' = [lv EXCEPT ![t].yield = {}, ![t].gset = FALSE, ![t].order = <<>>]
    /\ UNCHANGED gh

DPortRows(t) == {<<Prt(t), v>> : v \in {w \in Users : MemV(t, Prt(t), w) # "none"}}
DPortNeed(t) ==
    LET q == Prt(t) IN
    BX(t, q) \cup (IF db.lease[q] THEN BLX(t, q) ELSE {})
    \cup UNION {BMW(t, r[1], r[2]) : r \in DPortRows(t)}
    \cup (IF CascadeInv(t, {q}) THEN BInv(t) ELSE {})

D_Purge(t) ==
    /\ Kind(t) = "dport" /\ pc[t] = "d_purge"
    /\ IF ~DPortOk(t)
       THEN /\ db' = ReleaseAll(db, t)            \* forbidden (not caught by the loop)
            /\ UNCHANGED gh
       ELSE LET dw == PurgeWrite(t, {Prt(t)}, DPortRows(t)) IN
            /\ DPortNeed(t) = {}
            /\ db' = CommitDB(dw, t)
            /\ gh' = GhostCommit(dw, t)
    /\ Goto(t, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* Lease writers.                                                          *)
(* "pay": record_payment via private.lock_lease_for_write (latest):        *)
(*   authorise -> portfolio KS -> lease FOR UPDATE -> authorise again ->   *)
(*   insert the payment -> COMMIT.  Follows the global order.              *)
(* "depo": a client's plain "update public.leases set security_deposit"    *)
(*   (grant in 20261103193403_leases.sql).  Its trigger                    *)
(*   private.after_lease_deposit_update (20261104143928) inserts a deposit *)
(*   charge whose FK check takes KEY SHARE on the portfolio.  findings:    *)
(*   the row policy leases_update gets its portfolios from                 *)
(*   app.lock_my_portfolio_ids, whose initplan runs before the statement   *)
(*   locks a row: it reads the caller's owner/manager portfolios, locks    *)
(*   them KEY SHARE in id order, authorises again, and lets through only   *)
(*   rows of portfolios both locked and still authorised.  Mutant          *)
(*   "no_client_key" is the code M1 was found in: the lease row first,     *)
(*   then the portfolio key, out of order.                                 *)
-----------------------------------------------------------------------------
LeaseRoles == {"owner", "manager"}

Y_Auth(t) ==
    /\ Kind(t) = "pay" /\ pc[t] = "y_auth"
    /\ Goto(t, IF db.lease[Prt(t)] /\ HasRole(t, Prt(t), Usr(t), LeaseRoles) THEN "y_pks" ELSE "done")
    /\ UNCHANGED <<db, lv, gh>>

Y_PKS(t) ==
    /\ Kind(t) = "pay" /\ pc[t] = "y_pks"
    /\ IF Prt(t) \in db.port
       THEN /\ BKS(t, Prt(t)) = {}
            /\ db' = [db EXCEPT !.pKS[Prt(t)] = @ \cup {t}]
       ELSE UNCHANGED db
    /\ Goto(t, "y_lease")
    /\ UNCHANGED <<lv, gh>>

Y_Lease(t) ==
    /\ Kind(t) = "pay" /\ pc[t] = "y_lease"
    /\ IF db.lease[Prt(t)] THEN BLX(t, Prt(t)) = {} ELSE TRUE
    /\ IF ~db.lease[Prt(t)] \/ ~HasRole(t, Prt(t), Usr(t), LeaseRoles)
       THEN db' = ReleaseAll(db, t)                \* forbidden
       ELSE db' = CommitDB([db EXCEPT !.lX[Prt(t)] = t], t)
    /\ Goto(t, "done")
    /\ UNCHANGED <<lv, gh>>

\* findings: app.lock_my_portfolio_ids, first query: the caller's portfolios
\* with a lease role (statement snapshot), to be locked in id order
L_Set(t) ==
    /\ Kind(t) = "depo" /\ pc[t] = "l_set"
    /\ lv' = [lv EXCEPT ![t].order =
                SortedSeq({q \in Ports : PortV(t, q) /\ HasRole(t, q, Usr(t), LeaseRoles)})]
    /\ Goto(t, "l_pks")
    /\ UNCHANGED <<db, gh>>

\* "... order by p.id for key share", one row per step; a row deleted
\* meanwhile is skipped
L_PKS(t) ==
    /\ Kind(t) = "depo" /\ pc[t] = "l_pks"
    /\ IF lv[t].order = <<>>
       THEN /\ Goto(t, "l_upd")
            /\ UNCHANGED <<db, lv>>
       ELSE LET q == Head(lv[t].order) IN
            /\ IF q \in db.port
               THEN /\ BKS(t, q) = {}
                    /\ db' = [db EXCEPT !.pKS[q] = @ \cup {t}]
               ELSE UNCHANGED db
            /\ lv' = [lv EXCEPT ![t].order = Tail(@)]
            /\ UNCHANGED pc
    /\ UNCHANGED gh

\* the UPDATE: the row policy and the lease row lock (NO KEY UPDATE); a lease
\* deleted while it waited is skipped (0 rows, nothing fires).  findings: the
\* policy's set is the portfolios locked above and authorised again now.
DepoAuth(t) ==
    /\ db.lease[Prt(t)] /\ HasRole(t, Prt(t), Usr(t), LeaseRoles)
    /\ Mut("no_client_key") \/ t \in db.pKS[Prt(t)]
L_Upd(t) ==
    /\ Kind(t) = "depo" /\ pc[t] = "l_upd"
    /\ IF DepoAuth(t)
       THEN /\ BL(t, Prt(t)) = {}
            /\ IF db.lease[Prt(t)]
               THEN /\ db' = [db EXCEPT !.lX[Prt(t)] = t]
                    /\ Goto(t, "l_fk")
               ELSE /\ db' = CommitDB(db, t) /\ Goto(t, "done")
       ELSE /\ db' = CommitDB(db, t) /\ Goto(t, "done")
    /\ UNCHANGED <<lv, gh>>

\* the trigger's charge INSERT: FK check, KEY SHARE on the portfolio; COMMIT
L_FK(t) ==
    /\ Kind(t) = "depo" /\ pc[t] = "l_fk"
    /\ IF Prt(t) \in db.port THEN BKS(t, Prt(t)) = {} ELSE TRUE
    /\ db' = IF Prt(t) \in db.port THEN CommitDB(db, t)
             ELSE ReleaseAll(db, t)                \* foreign_key_violation
    /\ Goto(t, "done")
    /\ UNCHANGED <<lv, gh>>

-----------------------------------------------------------------------------
(* "ins": a client INSERT of portfolio rows (granted INSERT under policies *)
(*   *_insert): "occB"/"occBr" a lease occupant of P1's lease, "tenB" two  *)
(*   tenants, the first in P2, the second in P1.  The rows' foreign keys   *)
(*   are checked after the rows are inserted, one AFTER ROW trigger after  *)
(*   another in trigger-name order, which is the constraints' creation     *)
(*   order: the migrations created every portfolio key first ("occB"), a   *)
(*   dump and restore re-creates them by name, so lease_occupants checks   *)
(*   its lease first ("occBr"); rows are checked in row order ("tenB").    *)
(*   findings: the WITH CHECK gets its portfolios from                     *)
(*   app.lock_my_portfolio_ids, whose initplan runs at the first row's     *)
(*   check, before any row is inserted: the caller's owner/manager         *)
(*   portfolios, KS in id order, authorised again.  Mutant "no_insert_key" *)
(*   is the code before: the WITH CHECK reads the memberships only.        *)
-----------------------------------------------------------------------------
InsRows(t)   == IF t = "tenB" THEN {"P1", "P2"} ELSE {"P1"}
InsChecks(t) ==
    CASE t = "occB"  -> <<<<"port", "P1">>, <<"lease", "P1">>>>
      [] t = "occBr" -> <<<<"lease", "P1">>, <<"port", "P1">>>>
      [] t = "tenB"  -> <<<<"port", "P2">>, <<"port", "P1">>>>

\* findings: app.lock_my_portfolio_ids, first query (as L_Set)
I_Set(t) ==
    /\ Kind(t) = "ins" /\ pc[t] = "i_set"
    /\ lv' = [lv EXCEPT ![t].order =
                SortedSeq({q \in Ports : PortV(t, q) /\ HasRole(t, q, Usr(t), LeaseRoles)})]
    /\ Goto(t, "i_pks")
    /\ UNCHANGED <<db, gh>>

\* "... order by p.id for key share", one row per step (as L_PKS)
I_PKS(t) ==
    /\ Kind(t) = "ins" /\ pc[t] = "i_pks"
    /\ IF lv[t].order = <<>>
       THEN /\ Goto(t, "i_chk")
            /\ UNCHANGED <<db, lv>>
       ELSE LET q == Head(lv[t].order) IN
            /\ IF q \in db.port
               THEN /\ BKS(t, q) = {}
                    /\ db' = [db EXCEPT !.pKS[q] = @ \cup {t}]
               ELSE UNCHANGED db
            /\ lv' = [lv EXCEPT ![t].order = Tail(@)]
            /\ UNCHANGED pc
    /\ UNCHANGED gh

\* the WITH CHECK of every row (findings: its portfolio is locked and the
\* caller still has the role), then the rows are inserted (invisible to the
\* others, nothing to lock); a refused row fails the statement
InsAuth(t) ==
    \A q \in InsRows(t) :
        /\ HasRole(t, q, Usr(t), LeaseRoles)
        /\ Mut("no_insert_key") \/ t \in db.pKS[q]
I_Chk(t) ==
    /\ Kind(t) = "ins" /\ pc[t] = "i_chk"
    /\ IF InsAuth(t)
       THEN /\ lv' = [lv EXCEPT ![t].chk = InsChecks(t)]
            /\ Goto(t, "i_fk")
            /\ UNCHANGED db
       ELSE /\ db' = ReleaseAll(db, t)                \* new row violates row-level security policy
            /\ Goto(t, "done")
            /\ UNCHANGED lv
    /\ UNCHANGED gh

\* one foreign-key check per step (KEY SHARE on the parent); a parent that
\* is gone fails the statement (foreign_key_violation); then COMMIT
InsParent(c) == IF c[1] = "port" THEN c[2] \in db.port ELSE db.lease[c[2]]
InsNeed(t) ==
    IF lv[t].chk = <<>> \/ ~InsParent(Head(lv[t].chk)) THEN {}
    ELSE LET c == Head(lv[t].chk) IN IF c[1] = "port" THEN BKS(t, c[2]) ELSE BLKS(t, c[2])
I_FK(t) ==
    /\ Kind(t) = "ins" /\ pc[t] = "i_fk"
    /\ InsNeed(t) = {}
    /\ IF lv[t].chk = <<>>
       THEN /\ db' = CommitDB(db, t)
            /\ Goto(t, "done")
            /\ UNCHANGED lv
       ELSE LET c == Head(lv[t].chk) IN
            IF ~InsParent(c)
            THEN /\ db' = ReleaseAll(db, t)
                 /\ Goto(t, "done")
                 /\ UNCHANGED lv
            ELSE /\ db' = IF c[1] = "port" THEN [db EXCEPT !.pKS[c[2]] = @ \cup {t}]
                                           ELSE [db EXCEPT !.lKS[c[2]] = @ \cup {t}]
                 /\ lv' = [lv EXCEPT ![t].chk = Tail(@)]
                 /\ UNCHANGED pc
    /\ UNCHANGED gh

-----------------------------------------------------------------------------
(* "note": B marks its notifications read, n2 then n1, two UPDATEs in one   *)
(* transaction (the opposite of the cascade's order).  findings: the row   *)
(* policies notifications_update_own get their portfolios from             *)
(* app.lock_my_notification_portfolios, an initplan run before the first   *)
(* row: the account key (profiles row, KEY SHARE), then the portfolios of  *)
(* the caller's notifications where they are a member (KEY SHARE, id       *)
(* order; here P1).  Mutant "no_note_account_key": no account key.          *)
(* The second UPDATE's initplan finds both keys held already.              *)
NoteVisible(t, n) == n \in db.notes /\ t \in db.pKS["P1"] /\ MemV(t, "P1", Usr(t)) # "none"
N_Prof(t) ==
    /\ Kind(t) = "note" /\ pc[t] = "n_prof"
    /\ IF ~Mut("no_note_account_key") /\ Usr(t) \in db.users
       THEN /\ BProfKS(t, Usr(t)) = {}
            /\ db' = [db EXCEPT !.profKS[Usr(t)] = @ \cup {t}]
       ELSE UNCHANGED db
    /\ Goto(t, "n_pks")
    /\ UNCHANGED <<lv, gh>>

N_PKS(t) ==
    /\ Kind(t) = "note" /\ pc[t] = "n_pks"
    /\ IF PortV(t, "P1") /\ MemV(t, "P1", Usr(t)) # "none"
       THEN /\ BKS(t, "P1") = {}
            /\ db' = [db EXCEPT !.pKS["P1"] = @ \cup {t}]
       ELSE UNCHANGED db
    /\ Goto(t, "n_upd1")
    /\ UNCHANGED <<lv, gh>>

\* each UPDATE: the row lock (NO KEY UPDATE) of a row its policy lets through;
\* a row deleted meanwhile is skipped (0 rows)
NoteOf(t) == IF pc[t] = "n_upd1" THEN "n2" ELSE "n1"
N_Upd(t) ==
    /\ Kind(t) = "note" /\ pc[t] \in {"n_upd1", "n_upd2"}
    /\ IF NoteVisible(t, NoteOf(t))
       THEN /\ BN(t, NoteOf(t)) = {}
            /\ db' = [db EXCEPT !.nX[NoteOf(t)] = t]
       ELSE UNCHANGED db
    /\ Goto(t, IF pc[t] = "n_upd1" THEN "n_upd2" ELSE "n_commit")
    /\ UNCHANGED <<lv, gh>>

N_Commit(t) ==
    /\ Kind(t) = "note" /\ pc[t] = "n_commit"
    /\ db' = CommitDB(db, t)
    /\ Goto(t, "done")
    /\ UNCHANGED <<lv, gh>>

-----------------------------------------------------------------------------
(* Residence (20261112092618_residence.sql).                               *)
(* "care": set_caretaker(q, x) by u: require_portfolio_role(owner)        *)
(*   (snapshot) -> the portfolio FOR NO KEY UPDATE -> authorise again ->   *)
(*   x's role (plain read: member_not_found, caretaker_not_manager) ->     *)
(*   "update portfolios set caretaker_user_id = x where ... is distinct    *)
(*   from x": BEFORE trigger private.before_portfolio_caretaker_change     *)
(*   reads x's manager membership FOR SHARE (caretaker_not_manager) ->     *)
(*   the AFTER triggers by name: the FK check of caretaker_user_id (KEY    *)
(*   SHARE on auth.users x), then portfolios_audit, whose insert checks    *)
(*   actor_id (KEY SHARE on the caller's auth.users row) -> COMMIT.        *)
-----------------------------------------------------------------------------
C_Auth(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_auth"
    /\ Goto(t, IF HasRole(t, Prt(t), Usr(t), {"owner"})
               THEN IF Mut("care_member_first") THEN "c_pre" ELSE "c_lock"
               ELSE "done")
    /\ UNCHANGED <<db, lv, gh>>

\* "... and m.role = 'manager' for share" locks only a row whose version in
\* the statement's snapshot (the committed one: t writes no member row)
\* passes the filter; for such a row it waits for a writer, then re-checks the
\* newest version (EvalPlanQual).  A row that is not a manager's is not
\* locked and not waited for.
ShareNeed(t) == IF db.mem[Prt(t)][Tgt(t)] = "manager" THEN BM(t, Prt(t), Tgt(t)) ELSE {}

\* mutant "care_member_first": x's membership FOR SHARE before the portfolio
C_Pre(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_pre"
    /\ ShareNeed(t) = {}
    /\ db' = IF MemV(t, Prt(t), Tgt(t)) = "manager"
             THEN [db EXCEPT !.mSh[Prt(t)][Tgt(t)] = @ \cup {t}] ELSE db
    /\ Goto(t, "c_lock")
    /\ UNCHANGED <<lv, gh>>

\* mutant "no_care_lock": no lock here; the UPDATE locks the row (C_Upd)
C_Lock(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_lock"
    /\ IF ~Mut("no_care_lock") /\ Prt(t) \in db.port
       THEN /\ BNKU(t, Prt(t)) = {}
            /\ db' = [db EXCEPT !.pNKU[Prt(t)] = t]
       ELSE UNCHANGED db
    /\ Goto(t, "c_do")
    /\ UNCHANGED <<lv, gh>>

\* The second require_portfolio_role and x's role read, merged: the first
\* reads the caller's membership, which no writer can change while t holds
\* the portfolio (the RPCs and deletions lock it FOR UPDATE first; the
\* ASSUME on service-role and GoTrue writes); the second is a plain read of
\* x's, which C_Trig reads again FOR SHARE before anything is written.
\* Mutant "no_care_rpc_role_check": no read of x's role here.
C_Do(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_do"
    /\ LET q == Prt(t)  x == Tgt(t) IN
       CASE ~(Mut("no_care_recheck") \/ HasRole(t, q, Usr(t), {"owner"})) ->
              /\ db' = ReleaseAll(db, t) /\ Goto(t, "done")         \* forbidden
         [] ~Mut("no_care_rpc_role_check") /\ MemV(t, q, x) # "manager" ->
              /\ db' = ReleaseAll(db, t) /\ Goto(t, "done")         \* member_not_found / caretaker_not_manager
         [] CareV(t, q) = x ->                                      \* already the caretaker: 0 rows
              /\ db' = CommitDB(db, t) /\ Goto(t, "done")
         [] OTHER ->
              /\ Goto(t, IF Mut("no_care_lock") THEN "c_upd" ELSE "c_trig") /\ UNCHANGED db
    /\ UNCHANGED <<lv, gh>>

\* mutant "no_care_lock": the UPDATE's row lock, before its BEFORE trigger;
\* "is distinct from x" is checked again on the newest version
C_Upd(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_upd"
    /\ IF Prt(t) \in db.port THEN BNKU(t, Prt(t)) = {} ELSE TRUE
    /\ IF Prt(t) \notin db.port \/ CareV(t, Prt(t)) = Tgt(t)
       THEN /\ db' = CommitDB(db, t) /\ Goto(t, "done")             \* 0 rows
       ELSE /\ db' = [db EXCEPT !.pNKU[Prt(t)] = t] /\ Goto(t, "c_trig")
    /\ UNCHANGED <<lv, gh>>

\* the trigger's FOR SHARE read (ShareNeed); mutant "no_care_share": a plain
\* read of the committed row, no lock; mutant "no_care_before_trigger": no
\* trigger at all
CTrigNeed(t) == IF Mut("no_care_share") \/ Mut("no_care_before_trigger") THEN {} ELSE ShareNeed(t)
C_Trig(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_trig"
    /\ CTrigNeed(t) = {}
    /\ LET q == Prt(t)  x == Tgt(t) IN
       IF ~Mut("no_care_before_trigger") /\ MemV(t, q, x) # "manager"
       THEN /\ db' = ReleaseAll(db, t) /\ Goto(t, "done")         \* caretaker_not_manager
       ELSE /\ db' = [db EXCEPT !.mSh[q][x] = IF Mut("no_care_share") \/ Mut("no_care_before_trigger")
                                                 THEN @ ELSE @ \cup {t},
                                !.cBy[q] = t, !.cNew[q] = x]
            /\ Goto(t, "c_fk")
    /\ UNCHANGED <<lv, gh>>

\* the FK check of caretaker_user_id: KEY SHARE on auth.users x; then the
\* audit row (AuditCommit) and COMMIT
CareGhost(d, t) == [GhostCommit(d, t) EXCEPT !.careStale = @ \/ db.mem[Prt(t)][Usr(t)] # "owner"]
C_FK(t) ==
    /\ Kind(t) = "care" /\ pc[t] = "c_fk"
    /\ BUKS(t, Tgt(t)) = {}
    /\ IF Tgt(t) \notin db.users
       THEN /\ db' = ReleaseAll(db, t) /\ UNCHANGED gh /\ Goto(t, "done")  \* foreign_key_violation
       ELSE LET dw == [db EXCEPT !.uKS[Tgt(t)] = @ \cup {t}] IN
            IF AuditFK(t)
            THEN /\ db' = dw /\ Goto(t, "c_audit") /\ UNCHANGED gh
            ELSE /\ db' = CommitDB(dw, t)
                 /\ gh' = CareGhost(dw, t)
                 /\ Goto(t, "done")
    /\ UNCHANGED lv

(* "abroad": set_owner_abroad(q, r, p_if_unanswered) by u (v = NoP: true,   *)
(*   as the app asks on the next open; v = "change": false, a change on    *)
(*   purpose): authorise (owner, manager) -> the portfolio FOR NO KEY      *)
(*   UPDATE and the answer (one statement) -> authorise again -> the same  *)
(*   answer, or with p_if_unanswered an answer already given, is returned  *)
(*   -> owner_abroad_answered unless an owner -> UPDATE -> the audit row   *)
(*   (AuditCommit) -> COMMIT.  The steps after the lock are merged: no     *)
(*   membership change by an RPC or deletion and no other answer can      *)
(*   commit while it is held, and no service-role or GoTrue write changes  *)
(*   the caller's membership (the ASSUME above).  Mutant                   *)
(*   "abroad_unlocked_read": the read takes no lock; the UPDATE then waits *)
(*   for the row and overwrites it (READ COMMITTED re-check of "where id = *)
(*   q" only).  Mutant "abroad_answered_overwritten": p_if_unanswered is   *)
(*   ignored.  Mutant "no_answered_guard": no owner_abroad_answered.       *)
AbroadRoles == {"owner", "manager"}
IfUnanswered(t) == Tgt(t) # "change"
O_Auth(t) ==
    /\ Kind(t) = "abroad" /\ pc[t] = "o_auth"
    /\ Goto(t, IF HasRole(t, Prt(t), Usr(t), AbroadRoles) THEN "o_lock" ELSE "done")
    /\ UNCHANGED <<db, lv, gh>>

O_Lock(t) ==
    /\ Kind(t) = "abroad" /\ pc[t] = "o_lock"
    /\ IF ~Mut("abroad_unlocked_read") /\ Prt(t) \in db.port
       THEN /\ BNKU(t, Prt(t)) = {}
            /\ db' = [db EXCEPT !.pNKU[Prt(t)] = t]
       ELSE UNCHANGED db
    /\ lv' = [lv EXCEPT ![t].cur = AbroadV(t, Prt(t))]
    /\ Goto(t, "o_do")
    /\ UNCHANGED gh

AbroadOk(t)     == Mut("no_abroad_recheck") \/ HasRole(t, Prt(t), Usr(t), AbroadRoles)
\* "if v_current is not distinct from p_owner_abroad or (v_current is not
\* null and p_if_unanswered) then return v_current"
AbroadKeeps(t)  == \/ lv[t].cur = Rl(t)
                   \/ lv[t].cur # "null" /\ IfUnanswered(t) /\ ~Mut("abroad_answered_overwritten")
\* "if v_current is not null and not <owner> then fail owner_abroad_answered"
AbroadRefuses(t) == /\ lv[t].cur # "null" /\ ~Mut("no_answered_guard")
                    /\ ~HasRole(t, Prt(t), Usr(t), {"owner"})
AbroadWrites(t) == AbroadOk(t) /\ ~AbroadKeeps(t) /\ ~AbroadRefuses(t) /\ Prt(t) \in db.port
AbroadNeed(t)   == IF AbroadWrites(t) THEN BNKU(t, Prt(t)) ELSE {}
\* d: t's writes; the answer and the role in the committed state at COMMIT
AbroadGhost(d, t) ==
    LET q == Prt(t) IN
    [GhostCommit(d, t) EXCEPT
        !.ansStale = @ \/ db.mem[q][Usr(t)] \notin
                              (IF db.abroad[q] = "null" THEN AbroadRoles ELSE {"owner"}),
        !.overwrote = @ \/ (IfUnanswered(t) /\ db.abroad[q] \notin {"null", Rl(t)})]
O_Do(t) ==
    /\ Kind(t) = "abroad" /\ pc[t] = "o_do"
    /\ AbroadNeed(t) = {}
    /\ LET q == Prt(t) IN
       CASE ~AbroadOk(t) ->
              /\ db' = ReleaseAll(db, t) /\ UNCHANGED gh /\ Goto(t, "done")   \* forbidden
         [] ~AbroadWrites(t) /\ AbroadRefuses(t) /\ ~AbroadKeeps(t) ->
              /\ db' = ReleaseAll(db, t) /\ UNCHANGED gh /\ Goto(t, "done")   \* owner_abroad_answered
         [] ~AbroadWrites(t) ->                                     \* the answer returned, kept
              /\ db' = CommitDB(db, t) /\ UNCHANGED gh /\ Goto(t, "done")
         [] OTHER ->
              LET dw == [db EXCEPT !.pNKU[q] = IF db.pX[q] = t THEN @ ELSE t,
                                   !.aBy[q] = t, !.aNew[q] = Rl(t)]
              IN IF AuditFK(t)
                 THEN /\ db' = dw /\ Goto(t, "o_audit") /\ UNCHANGED gh
                 ELSE /\ db' = CommitDB(dw, t)
                      /\ gh' = AbroadGhost(dw, t)
                      /\ Goto(t, "done")
    /\ UNCHANGED lv

\* The audit row's insert of an RPC (M_Write, C_FK, O_Do) where a GoTrue
\* delete of the caller runs: KEY SHARE on the caller's auth.users row (the
\* delete holds it FOR UPDATE until it commits; once it has, the insert
\* fails with foreign_key_violation and the RPC with it); then COMMIT.
AuditCommit(t) ==
    /\ pc[t] \in {"m_audit", "c_audit", "o_audit"}
    /\ BUKS(t, Usr(t)) = {}
    /\ IF Usr(t) \notin db.users
       THEN /\ db' = ReleaseAll(db, t) /\ UNCHANGED gh
       ELSE /\ db' = CommitDB(db, t)
            /\ gh' = CASE pc[t] = "m_audit" -> MemberGhost(db, t)
                       [] pc[t] = "c_audit" -> CareGhost(db, t)
                       [] OTHER             -> AbroadGhost(db, t)
    /\ Goto(t, "done")
    /\ UNCHANGED lv

(* "res": the person's own "update public.profile_residences set ..."     *)
(*   (column grants; policy profile_residences_update_own).  The row lock  *)
(*   (NO KEY UPDATE) is taken before the BEFORE trigger                    *)
(*   private.before_profile_residence_client_update runs, which reads      *)
(*   account_deletions with a fresh snapshot (account_deleted) and stamps  *)
(*   stated_at.  No other lock: user_id does not change (no FK check).     *)
(*   Mutant "no_residence_refusal": the trigger does not refuse.  Mutant   *)
(*   "residence_check_before_lock": account_deletions is read before the   *)
(*   row is locked (in the policy, say; R_Chk), and not again.             *)
R_Chk(t) ==
    /\ Kind(t) = "res" /\ pc[t] = "r_chk"
    /\ IF Usr(t) \in db.frozen
       THEN /\ db' = ReleaseAll(db, t) /\ Goto(t, "done")           \* account_deleted
       ELSE /\ Goto(t, "r_upd") /\ UNCHANGED db
    /\ UNCHANGED <<lv, gh>>

R_Upd(t) ==
    /\ Kind(t) = "res" /\ pc[t] = "r_upd"
    /\ LET u == Usr(t) IN
       IF u \notin db.users
       THEN /\ db' = CommitDB(db, t) /\ Goto(t, "done")           \* no row: 0 rows
       ELSE /\ BRes(t, u) = {}
            /\ IF u \in db.frozen /\ ~Mut("no_residence_refusal") /\ ~Mut("residence_check_before_lock")
               THEN /\ db' = ReleaseAll(db, t) /\ Goto(t, "done")  \* account_deleted
               ELSE /\ db' = [db EXCEPT !.resX[u] = t, !.resNew[u] = "set"]
                    /\ Goto(t, "r_commit")
    /\ UNCHANGED <<lv, gh>>

R_Commit(t) ==
    /\ Kind(t) = "res" /\ pc[t] = "r_commit"
    /\ db' = CommitDB(db, t)
    /\ Goto(t, "done")
    /\ UNCHANGED <<lv, gh>>

(* "svc": the service role's "update portfolio_members set role = r" or   *)
(*   "delete from portfolio_members" of (q, v), without a portfolio lock   *)
(*   (an operator in the SQL editor).  The row lock, then                  *)
(*   portfolio_members_after_caretaker_ends at the end of the statement:   *)
(*   "update portfolios set caretaker_user_id = null where id = q and      *)
(*   caretaker_user_id = v" (a portfolio row lock only when v is the       *)
(*   caretaker in the row it reads), then COMMIT.  The audit row's actor   *)
(*   is NULL (no check).  "svcl": the operator's rule of                   *)
(*   docs/operations.md, "select ... from portfolios where id = q for      *)
(*   update" first (S_Lock), then the same.                                *)
IsSvc(t) == Kind(t) \in {"svc", "svcl"}
S_Lock(t) ==
    /\ Kind(t) = "svcl" /\ pc[t] = "s_lock"
    /\ IF Prt(t) \in db.port
       THEN /\ BX(t, Prt(t)) = {}
            /\ db' = [db EXCEPT !.pX[Prt(t)] = t]
       ELSE UNCHANGED db
    /\ Goto(t, "s_row")
    /\ UNCHANGED <<lv, gh>>

S_Row(t) ==
    /\ IsSvc(t) /\ pc[t] = "s_row"
    /\ BMW(t, Prt(t), Tgt(t)) = {}
    /\ LET q == Prt(t)  v == Tgt(t) IN
       IF MemV(t, q, v) = "none"
       THEN /\ db' = CommitDB(db, t) /\ Goto(t, "done")           \* 0 rows
            /\ UNCHANGED lv
       ELSE /\ db' = [db EXCEPT !.mDirty[q][v] = t, !.mNew[q][v] = Rl(t)]
            /\ lv' = [lv EXCEPT ![t].cur = MemV(t, q, v)]          \* OLD.role
            /\ Goto(t, "s_trig")
    /\ UNCHANGED gh

SvcClears(t) ==
    /\ ~Mut("no_care_trigger")
    /\ lv[t].cur = "manager" /\ Rl(t) # "manager"
    /\ Prt(t) \in db.port /\ CareV(t, Prt(t)) = Tgt(t)
SvcNeed(t) == IF SvcClears(t) THEN BNKU(t, Prt(t)) ELSE {}
S_Trig(t) ==
    /\ IsSvc(t) /\ pc[t] = "s_trig"
    /\ SvcNeed(t) = {}
    /\ LET q == Prt(t)
           dw == IF SvcClears(t)
                 THEN ClearCare([db EXCEPT !.pNKU[q] = IF db.pX[q] = t THEN @ ELSE t], t, {q})
                 ELSE db
       IN /\ db' = CommitDB(dw, t)
          /\ gh' = GhostCommit(dw, t)
    /\ Goto(t, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* Waiting, deadlocks, failures *)

(* Need(t): the transactions t waits for at its current statement (empty  *)
(* when it can run).  Mirrors the enabling conditions above.               *)
Need(t) ==
    LET u == Usr(t) q == Prt(t) IN
    CASE pc[t] = "a_prof" ->
            IF Mut("no_freeze") \/ u \notin db.users THEN {} ELSE BProfX(t, u)
      [] pc[t] = "a_frz"   -> FrzNeed(t)
      [] pc[t] = "a_lock" ->
            IF lv[t].order = <<>> \/ Head(lv[t].order) \notin db.port THEN {}
            ELSE BX(t, Head(lv[t].order))
      [] pc[t] = "a_purge" -> PurgeNeed(t)
      [] pc[t] = "g_user"  -> IF u \in db.users THEN BUX(t, u) ELSE {}
      [] pc[t] = "g_prof"  -> BProfX(t, u)
      [] pc[t] \in RowLabels -> RowNeed(t)
      [] pc[t] = "g_commit" -> GCommitNeed(t)
      [] pc[t] = "a_res"   -> ResNeed(t)
      [] pc[t] = "c_pre"   -> ShareNeed(t)
      [] pc[t] = "c_lock"  -> IF ~Mut("no_care_lock") /\ q \in db.port THEN BNKU(t, q) ELSE {}
      [] pc[t] = "c_upd"   -> IF q \in db.port THEN BNKU(t, q) ELSE {}
      [] pc[t] = "c_trig"  -> CTrigNeed(t)
      [] pc[t] = "c_fk"    -> BUKS(t, Tgt(t))
      [] pc[t] \in {"m_audit", "c_audit", "o_audit"} -> BUKS(t, u)
      [] pc[t] = "s_lock"  -> IF q \in db.port THEN BX(t, q) ELSE {}
      [] pc[t] = "o_lock"  -> IF ~Mut("abroad_unlocked_read") /\ q \in db.port THEN BNKU(t, q) ELSE {}
      [] pc[t] = "o_do"    -> AbroadNeed(t)
      [] pc[t] = "r_upd"   -> IF u \in db.users THEN BRes(t, u) ELSE {}
      [] pc[t] = "s_row"   -> BMW(t, q, Tgt(t))
      [] pc[t] = "s_trig"  -> SvcNeed(t)
      [] pc[t] \in {"g_note1", "g_note2"} -> IF GNoteHit(t) THEN BN(t, GNote(t)) ELSE {}
      [] pc[t] = "n_prof"  ->
            IF ~Mut("no_note_account_key") /\ u \in db.users THEN BProfKS(t, u) ELSE {}
      [] pc[t] = "n_pks"   -> IF PortV(t, "P1") /\ MemV(t, "P1", u) # "none" THEN BKS(t, "P1") ELSE {}
      [] pc[t] \in {"n_upd1", "n_upd2"} -> IF NoteVisible(t, NoteOf(t)) THEN BN(t, NoteOf(t)) ELSE {}
      [] pc[t] = "m_lock"  -> IF Mut("no_member_lock") \/ q \notin db.port THEN {} ELSE BX(t, q)
      [] pc[t] = "m_write" -> MemberNeed(t)
      [] pc[t] \in {"x_act", "k_act"} -> ActiveNeed(t)
      [] pc[t] = "x_plock" ->
            IF InvExists /\ Inv.for = u /\ InvP \in db.port THEN BKS(t, InvP) ELSE {}
      [] pc[t] = "x_inv"   -> IF InvExists THEN BInv(t) ELSE {}
      [] pc[t] = "x_ins"   -> BM(t, InvP, u) \cup BKS(t, InvP) \cup BUKS(t, u) \cup BUKS(t, InvBy)
      [] pc[t] = "k_ins"   -> BPK(t, q) \cup BUKS(t, u)
      [] pc[t] = "d_lock"  -> IF q \in db.port THEN BX(t, q) ELSE {}
      [] pc[t] = "d_purge" -> IF DPortOk(t) THEN DPortNeed(t) ELSE {}
      [] pc[t] = "y_pks"   -> IF q \in db.port THEN BKS(t, q) ELSE {}
      [] pc[t] = "y_lease" -> IF db.lease[q] THEN BLX(t, q) ELSE {}
      [] pc[t] = "l_pks"   ->
            IF lv[t].order = <<>> \/ Head(lv[t].order) \notin db.port THEN {}
            ELSE BKS(t, Head(lv[t].order))
      [] pc[t] = "l_upd"   -> IF DepoAuth(t) THEN BL(t, q) ELSE {}
      [] pc[t] = "l_fk"    -> IF q \in db.port THEN BKS(t, q) ELSE {}
      [] pc[t] = "i_pks"   ->
            IF lv[t].order = <<>> \/ Head(lv[t].order) \notin db.port THEN {}
            ELSE BKS(t, Head(lv[t].order))
      [] pc[t] = "i_fk"    -> InsNeed(t)
      [] OTHER -> {}

RECURSIVE ReachN(_, _)
ReachN(S, n) == IF n = 0 THEN S ELSE ReachN(S \cup UNION {Need(s) : s \in S}, n - 1)
OnCycle(t) == t \in ReachN(Need(t), Cardinality(Procs))

InLoop(t) == \/ IsAcct(t) /\ pc[t] \in {"a_lock", "a_aud", "a_purge"}
             \/ Kind(t) = "dport" /\ pc[t] \in {"d_lock", "d_aud", "d_purge"}
IsDeletion(t) == \/ IsAcct(t) /\ pc[t] \in {"a_prof", "a_frz", "a_lock", "a_aud", "a_purge", "a_res"}
                 \/ Kind(t) = "dport"

(* PostgreSQL's deadlock detector aborts one transaction on the cycle.     *)
(* Inside the lock-and-delete loop the error is caught: ROLLBACK TO the     *)
(* savepoint and retry, until the third attempt re-raises it.              *)
Detect(t) ==
    /\ pc[t] \notin {"done", "a_ok", "a_gaveup"}
    /\ OnCycle(t)
    /\ IF InLoop(t) /\ ~Mut("no_deadlock_retry")
          /\ (Mut("unbounded_retry") \/ lv[t].dl + 1 < DeleteAttempts)
       THEN /\ db' = SubRelease(db, t)
            /\ lv' = [lv EXCEPT ![t].dl = IF Mut("unbounded_retry") THEN @ ELSE @ + 1,
                                ![t].gset = FALSE, ![t].order = <<>>,
                                ![t].yield = IF WAKE_FIRST
                                             THEN {<<s, pc[s]>> : s \in {w \in Procs \ {t} : t \in Need(w)}}
                                             ELSE {}]
            /\ Goto(t, IF IsAcct(t) THEN "a_mem" ELSE "d_lock")
            /\ UNCHANGED gh
       ELSE /\ db' = ReleaseAll(db, t)
            /\ gh' = [gh EXCEPT !.dlFail = @ \/ IsDeletion(t)]
            /\ Goto(t, IF IsAcct(t) THEN "a_failed" ELSE "done")
            /\ UNCHANGED lv

(* Any open transaction can fail (timeout, lost connection, crash).        *)
Holds(t) ==
    \/ \E u \in Users : db.frz[u] = t \/ db.profX[u] = t \/ t \in db.profKS[u]
                        \/ db.uX[u] = t \/ t \in db.uKS[u]
    \/ \E q \in Ports : db.pX[q] = t \/ db.pNKU[q] = t \/ t \in db.pKS[q] \/ db.lX[q] = t
                        \/ t \in db.lKS[q]
    \/ \E q \in Ports, v \in Users : db.mDirty[q][v] = t
    \/ db.invX = t
    \/ \E n \in Notes : db.nX[n] = t
    \/ \E q \in Ports, v \in Users : t \in db.mSh[q][v]
    \/ \E u \in Users : db.resX[u] = t
    \/ \E q \in Ports, v \in Users : db.audX[q][v] = t
AbortAny(t) ==
    /\ CAN_ABORT
    /\ pc[t] \notin {"done", "a_ok", "a_gaveup", "a_failed"}
    /\ Holds(t)
    /\ db' = ReleaseAll(db, t)
    /\ Goto(t, IF IsAcct(t) THEN "a_failed" ELSE "done")
    /\ UNCHANGED <<lv, gh>>

-----------------------------------------------------------------------------
StartPC(t) ==
    CASE Kind(t) = "acct"   -> "a_live"
      [] Kind(t) = "gotrue" -> "g_user"
      [] Kind(t) \in {"remove", "role"} -> "m_auth"
      [] Kind(t) = "accept" -> "x_act"
      [] Kind(t) = "create" -> "k_act"
      [] Kind(t) = "dport"  -> "d_auth"
      [] Kind(t) = "pay"    -> "y_auth"
      [] Kind(t) = "depo"   -> IF Mut("no_client_key") THEN "l_upd" ELSE "l_set"
      [] Kind(t) = "ins"    -> IF Mut("no_insert_key") THEN "i_chk" ELSE "i_set"
      [] Kind(t) = "note"   -> "n_prof"
      [] Kind(t) = "care"   -> "c_auth"
      [] Kind(t) = "abroad" -> "o_auth"
      [] Kind(t) = "res"    -> IF Mut("residence_check_before_lock") THEN "r_chk" ELSE "r_upd"
      [] Kind(t) = "svc"    -> "s_row"
      [] Kind(t) = "svcl"   -> "s_lock"

Init ==
    /\ db = [users |-> Users, frozen |-> {},
             frz |-> [u \in Users |-> NoP], profX |-> [u \in Users |-> NoP],
             profKS |-> [u \in Users |-> {}], uX |-> [u \in Users |-> NoP],
             uKS |-> [u \in Users |-> {}],
             port |-> InitPorts, createdBy |-> [q \in Ports |-> InitCreatedBy(q)],
             reg |-> [q \in Ports |-> IF q \in InitPorts THEN "live" ELSE "none"],
             pX |-> [q \in Ports |-> NoP], pNKU |-> [q \in Ports |-> NoP],
             pKS |-> [q \in Ports |-> {}], pNew |-> [q \in Ports |-> NoP],
             pDel |-> [q \in Ports |-> NoP], cbNull |-> [q \in Ports |-> NoP],
             mem |-> [q \in Ports |-> [v \in Users |-> InitRole(q, v)]],
             mDirty |-> [q \in Ports |-> [v \in Users |-> NoP]],
             mNew |-> [q \in Ports |-> [v \in Users |-> "none"]],
             lease |-> [q \in Ports |-> HasLease(q)], lX |-> [q \in Ports |-> NoP],
             lDel |-> [q \in Ports |-> NoP], lKS |-> [q \in Ports |-> {}],
             inv |-> IF InvBy = NoP THEN "none" ELSE "pending", invX |-> NoP, invNew |-> NoP,
             notes |-> InitNotes, nX |-> [n \in Notes |-> NoP], nDel |-> [n \in Notes |-> NoP],
             care |-> [q \in Ports |-> InitCare(q)], cBy |-> [q \in Ports |-> NoP],
             cNew |-> [q \in Ports |-> NoP], mSh |-> [q \in Ports |-> [v \in Users |-> {}]],
             abroad |-> [q \in Ports |-> "null"], aBy |-> [q \in Ports |-> NoP],
             aNew |-> [q \in Ports |-> "null"],
             res |-> [u \in Users |-> "none"], resX |-> [u \in Users |-> NoP],
             resNew |-> [u \in Users |-> "none"],
             aud |-> InitAud, audX |-> [q \in Ports |-> [v \in Users |-> NoP]]]
    /\ pc = [t \in Procs |-> StartPC(t)]
    /\ lv = [t \in Procs |-> [att |-> 1, dl |-> 0, vids |-> {}, order |-> <<>>, vdel |-> {},
                              yield |-> {}, chk |-> <<>>, cur |-> "null", gset |-> FALSE, rev |-> {}]]
    /\ gh = [frozenEver |-> {}, late |-> FALSE, everDeleted |-> {}, reused |-> FALSE,
             stale |-> FALSE, sole |-> FALSE, inviter |-> FALSE, dlFail |-> FALSE,
             delBy |-> [u \in Users |-> {}], succ |-> [u \in Users |-> FALSE],
             careStale |-> FALSE, ansStale |-> FALSE, overwrote |-> FALSE]

Step(t) ==
    \/ A_Live(t) \/ A_Prof(t) \/ A_Frz(t) \/ A_Mem(t) \/ A_Lock(t) \/ A_Purge(t) \/ A_Res(t)
    \/ G_User(t) \/ G_Prof(t) \/ G_Note(t) \/ G_Commit(t) \/ RowStep(t)
    \/ C_Auth(t) \/ C_Pre(t) \/ C_Lock(t) \/ C_Do(t) \/ C_Upd(t) \/ C_Trig(t) \/ C_FK(t)
    \/ O_Auth(t) \/ O_Lock(t) \/ O_Do(t) \/ AuditCommit(t)
    \/ R_Chk(t) \/ R_Upd(t) \/ R_Commit(t)
    \/ S_Lock(t) \/ S_Row(t) \/ S_Trig(t)
    \/ A_Failed(t)
    \/ M_Auth(t) \/ M_Lock(t) \/ M_Do(t) \/ M_Write(t)
    \/ X_Act(t) \/ X_PLock(t) \/ X_Inv(t) \/ X_Ins(t)
    \/ K_Act(t) \/ K_Check(t) \/ K_Ins(t)
    \/ D_Auth(t) \/ D_Lock(t) \/ D_Purge(t)
    \/ Y_Auth(t) \/ Y_PKS(t) \/ Y_Lease(t)
    \/ L_Set(t) \/ L_PKS(t) \/ L_Upd(t) \/ L_FK(t)
    \/ I_Set(t) \/ I_PKS(t) \/ I_Chk(t) \/ I_FK(t)
    \/ N_Prof(t) \/ N_PKS(t) \/ N_Upd(t) \/ N_Commit(t)

Terminated == \A t \in Procs : pc[t] \in {"done", "a_ok", "a_gaveup"}

Next ==
    \/ \E t \in Procs : Step(t) \/ Detect(t) \/ AbortAny(t)
    \/ Terminated /\ UNCHANGED vars

Spec == Init /\ [][Next]_vars

\* Every process step and the detector are weakly fair; failures are not.
LiveSpec == Spec /\ \A t \in Procs : WF_vars(Step(t)) /\ WF_vars(Detect(t))

-----------------------------------------------------------------------------
(* PROPERTIES *)

TypeOK ==
    /\ db.users \subseteq Users /\ db.frozen \subseteq Users /\ db.port \subseteq Ports
    /\ db.mem \in [Ports -> [Users -> Roles]]
    /\ db.reg \in [Ports -> {"none", "live", "retired"}]
    /\ db.pX \in [Ports -> ProcsOrNo] /\ db.pKS \in [Ports -> SUBSET Procs]
    /\ db.mDirty \in [Ports -> [Users -> ProcsOrNo]]
    /\ db.inv \in {"none", "pending", "revoked", "accepted", "gone"}
    /\ db.notes \subseteq Notes /\ db.nX \in [Notes -> ProcsOrNo]
    /\ db.care \in [Ports -> Users \cup {NoP}] /\ db.cBy \in [Ports -> ProcsOrNo]
    /\ db.mSh \in [Ports -> [Users -> SUBSET Procs]]
    /\ db.abroad \in [Ports -> {"null", "yes", "no"}]
    /\ db.res \in [Users -> {"none", "set"}] /\ db.resX \in [Users -> ProcsOrNo]
    /\ db.aud \subseteq Ports \X Users /\ db.audX \in [Ports -> [Users -> ProcsOrNo]]
    /\ pc \in [Procs -> STRING]

(* Sanity: foreign keys and ON DELETE CASCADE hold in committed rows. *)
RefIntegrity ==
    \A q \in Ports, v \in Users : db.mem[q][v] # "none" => q \in db.port /\ v \in db.users

(* TEAM-04: every portfolio that exists has an owner ... *)
AtLeastOneOwner == \A q \in db.port : \E v \in Users : db.mem[q][v] = "owner"
(* ... and therefore a member. *)
NoMemberless == \A q \in db.port : \E v \in Users : db.mem[q][v] # "none"

(* Once admin_delete_account_data(u) committed, u holds no membership and  *)
(* no transaction commits a membership or a portfolio for u.               *)
NoActivityAfterDeletion ==
    /\ \A u \in gh.frozenEver, q \in Ports : db.mem[q][u] = "none"
    /\ ~gh.late

(* A deleted portfolio's id never comes back. *)
IdsNeverReused == ~gh.reused /\ gh.everDeleted \cap db.port = {}

(* No transaction waits, directly or through others, for itself. *)
NoWaitCycle == \A t \in Procs : ~OnCycle(t)

(* A deletion transaction never fails with deadlock_detected. *)
DeletionNotDefeated == ~gh.dlFail

(* Every committed membership change was authorised at commit time. *)
AuthorisedAtCommit == ~gh.stale

(* An account deletion deletes a portfolio only while the user is its only owner. *)
DeletesOnlySoleOwned == ~gh.sole

(* A member joins through an invitation only while its inviter is an owner. *)
InviterAuthority == ~gh.inviter

(* After a delete-account POST reports success: the account is gone, with  *)
(* no membership, and every portfolio its deletion removed stays removed.  *)
CompletedDeletionsClean ==
    \A u \in Users : gh.succ[u] =>
        /\ u \notin db.users
        /\ \A q \in Ports : db.mem[q][u] = "none"
        /\ gh.delBy[u] \cap db.port = {}

(* Residence.  A portfolio's caretaker is, in committed state, a member  *)
(* of it with the manager role.                                            *)
CaretakerIsManager ==
    \A q \in db.port : db.care[q] # NoP => db.mem[q][db.care[q]] = "manager"

(* set_caretaker commits a caretaker only while its caller is an owner. *)
CaretakerAuthorisedAtCommit == ~gh.careStale

(* set_owner_abroad changes the answer only while its caller may: an owner *)
(* or a manager while it is unanswered, an owner once it is answered.      *)
AnswerAuthorisedAtCommit == ~gh.ansStale

(* The question asked on the next open never overwrites an answer given.  *)
FirstAnswerKept == ~gh.overwrote

(* Once admin_delete_account_data(u) has committed, u's declared residence *)
(* is cleared and stays so while the row exists.                           *)
ResidenceGoneAfterDeletion ==
    \A u \in gh.frozenEver : u \in db.users => db.res[u] = "none"

(* Liveness: every request finishes (waits end; deadlocks are resolved). *)
AllFinish == <>Terminated

=============================================================================
