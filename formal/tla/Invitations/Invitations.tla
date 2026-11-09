------------------------------ MODULE Invitations ------------------------------
(***************************************************************************)
(* Concurrency model of portfolio invitations (Maalik-e-Makaan).           *)
(*                                                                         *)
(* GROUND TRUTH: the LAST definition of each object across                 *)
(* supabase/migrations/*.sql in filename order.  "M5" below means          *)
(* supabase/migrations/20261105072426_membership_deletion_storage.sql,     *)
(* "M6" means 20261108082804_invitation_findings.sql (the fixes of F1, F2  *)
(* and F4), "M1" means 20261103192722_identity_portfolios.sql and "M4"     *)
(* means 20261103194402_notifications_audit.sql.                          *)
(*                                                                         *)
(*  M1  public.portfolio_members   PRIMARY KEY (portfolio_id, user_id),    *)
(*                                 portfolio_id FK ON DELETE CASCADE       *)
(*  M1  public.portfolio_invitations portfolio_id FK ON DELETE CASCADE,    *)
(*        invited_by FK auth.users ON DELETE SET NULL,                     *)
(*        CHECK portfolio_invitations_terminal_state_check                 *)
(*              (accepted_at IS NULL OR revoked_at IS NULL),               *)
(*        UNIQUE INDEX portfolio_invitations_pending_email_key             *)
(*              ON (portfolio_id, email)                                   *)
(*              WHERE accepted_at IS NULL AND revoked_at IS NULL           *)
(*  M5  private.require_active_account          (AAcct)                    *)
(*  M5  private.lock_portfolio_for_change       (CLockP, RLockP, MChange)  *)
(*  M6  private.after_owner_membership_ends +                              *)
(*      trigger portfolio_members_after_owner_ends (MChange, XLockP,       *)
(*                                                  MTRevoke)              *)
(*  M5  public.update_member_role, public.remove_member  (M* actions)      *)
(*  M6  public.create_invitation                         (C* actions)      *)
(*  M5  public.revoke_invitation                         (R* actions)      *)
(*  M6  public.accept_invitation                         (A* actions)      *)
(*  M5  public.delete_portfolio, private.lock_portfolios_for_deletion,     *)
(*      private.delete_locked_portfolios, private.require_portfolio_name   *)
(*                                                       (D* actions)      *)
(*  M5  public.admin_delete_account_data                 (X* actions)      *)
(*  M4  private.after_invitation_accepted +                                *)
(*      trigger portfolio_invitations_after_accept       (ATrigger)        *)
(*  supabase/functions/invite-member/handler.ts inviteMember: calls        *)
(*      create_invitation AS THE CALLER (user client) and returns the      *)
(*      token only after the RPC committed; e-mail delivery is best        *)
(*      effort and has no database effect besides rate-limit buckets.      *)
(*      So a C* process is one invite-member request, and a token is in    *)
(*      `issued` only once its create committed.                           *)
(*  supabase/functions/delete-account/handler.ts deleteAccount: calls      *)
(*      admin_delete_account_data (X* actions), THEN auth.admin.deleteUser *)
(*      (GoTrue deletes the auth.users row: G* actions, process GA).       *)
(*                                                                         *)
(* SCOPE: ONE PORTFOLIO P and ONE INVITED E-MAIL "e".  Every invitation    *)
(* row is for (P, "e"); other (portfolio, e-mail) pairs use disjoint rows, *)
(* unique-index keys and membership keys, so they interact only through    *)
(* the portfolio and profile row locks, which are modelled.                *)
(*                                                                         *)
(* USERS: o1, o2 = owners of P at start (with SoleOwner = TRUE, o2 is a    *)
(* manager instead); u = the rightful invitee (verified e-mail "e");       *)
(* x = verified, different e-mail; y = claims "e" but is NOT verified.     *)
(* Attackers x and y are given a valid token (worst case: the verifier     *)
(* check private.timing_safe_equal passes for them).                       *)
(*                                                                         *)
(* PROCESSES (each one RPC call = one PostgreSQL transaction; PostgREST    *)
(* runs every RPC in its own transaction):                                 *)
(*   C1 (o1, role manager), C2 (o2, role viewer): invite-member ->          *)
(*      create_invitation(P, 'e', role)                                    *)
(*   R1 (o1), R2 (o2): revoke_invitation(token's id)                       *)
(*   D1 (o2), D2 (o1): delete_portfolio(P, <correct name>)                 *)
(*   AU1, AU2, AU3 (u), AX (x), AY (y): accept_invitation(token).  A       *)
(*      retry after a lost response is another process of the same user.   *)
(*   MD: o2 calls update_member_role(P, o1, 'viewer')   (demote inviter)   *)
(*   MP: o2 calls update_member_role(P, o1, 'owner')    (promote back)     *)
(*   MR: o2 calls remove_member(P, o1)                  (remove inviter)   *)
(*   ML: o1 calls remove_member(P, o1)                  (inviter leaves)   *)
(*   ADU: admin_delete_account_data(u)   (the invitee deletes the account) *)
(*   ADO: admin_delete_account_data(o1)  (the inviter deletes the account) *)
(*   GA: GoTrue deletes o1's auth user after ADO succeeded (delete-account)*)
(*   GO: GoTrue deletes o1's auth user directly (dashboard / admin API)    *)
(*                                                                         *)
(* POSTGRESQL SEMANTICS (READ COMMITTED, one snapshot per statement):      *)
(*  - The database is the committed state plus, per row, the uncommitted   *)
(*    version written by the single in-progress transaction that holds the *)
(*    row lock (invLock/invDirty, memW/memDirty, acctW, pDel).  A          *)
(*    statement of t sees committed data plus t's own writes (InvSeen,     *)
(*    MemSeen, PLive).                                                     *)
(*  - Row locks are held until commit/abort.  Invitation rows: FOR UPDATE  *)
(*    and the UPDATE/DELETE locks conflict pairwise, so one exclusive      *)
(*    holder per row is exact.  Portfolio row P and profile rows: modes    *)
(*    KS (FOR KEY SHARE; also what an FK check of an INSERT takes), NKU    *)
(*    (FOR NO KEY UPDATE) and U (FOR UPDATE / DELETE).  KS conflicts only  *)
(*    with U; NKU with NKU and U; U with everything.  "E" is the advisory  *)
(*    lock of create_invitation (M6; mode X, conflicts with X).           *)
(*  - A blocked statement waits for the blocking transaction to end and    *)
(*    then re-evaluates its WHERE clause on the newest committed version   *)
(*    (EvalPlanQual): the step is disabled while Blockers(p) # {} and      *)
(*    reads the newest version when it runs.  The rows an UPDATE/DELETE    *)
(*    scans are fixed by the statement snapshot (cand): rows committed     *)
(*    later are not seen by that statement.                                *)
(*  - Unique checks (btree _bt_check_unique, SnapshotDirty): a committed   *)
(*    live entry -> 23505 at once; an entry inserted/updated/deleted by an *)
(*    in-progress transaction -> wait, then re-check.                      *)
(*  - The FK check of an INSERT (RI_FKey_check_ins) runs at the end of the *)
(*    statement and takes KS on the portfolio row (23503 if it is gone).   *)
(*  - A raised error aborts the whole transaction (Fail).  app.fail,       *)
(*    app.forbid and require_portfolio_role raise; accept_invitation       *)
(*    RETURNs its statuses, so those transactions COMMIT.                  *)
(*  - now() is the transaction start (time), taken at the first step,      *)
(*    which is separate from the first lock so that time may pass while a  *)
(*    transaction waits.  Expiry: created at t, expires at t + TTL         *)
(*    (code: now() + interval '7 days'); refused when expires_at <= now(). *)
(*  - Deadlocks: the detector aborts one member of a wait-for cycle with   *)
(*    40P01 (DeadlockVictim; any member may be chosen).                    *)
(*  - The environment may abort any in-progress transaction (disconnect,   *)
(*    statement_timeout, HTTP 429): EnvAbort, at most MaxEnvAborts times.  *)
(*                                                                         *)
(* ABSTRACTIONS (and why they are sound for the properties checked):       *)
(*  - Rate limits (private.enforce_rate_limit, app.check_request, the      *)
(*    Edge Function's e-mail quotas) only serialise or refuse requests;    *)
(*    dropping the serialisation over-approximates the interleavings and a *)
(*    refusal (429) is an environmental abort or a process never running.  *)
(*  - Token format and verifier checks: tokens are assumed well formed and *)
(*    correct ('invalid' arises only from a row that no longer exists).    *)
(*  - E-mails and verification flags are static (no concurrent change in   *)
(*    auth.users).  y sharing u's e-mail is a worst case for the checks.   *)
(*  - Steps that run back-to-back while the process holds a lock that      *)
(*    excludes every interfering writer are merged into one step; each     *)
(*    merge is justified in the action's comment.                          *)
(*  - Notifications and audit rows are not stored.  after_invitation_     *)
(*    accepted is modelled by its lock (FK KS on P when it inserts) and by *)
(*    counting committed firings.  The audit trigger (M4                   *)
(*    private.audit_row_change) no longer locks the portfolio (M5 dropped  *)
(*    audit_logs_portfolio_id_fkey); its FK on actor_id locks the actor's  *)
(*    auth.users row, which matters only against GoTrue's deletion of o1,  *)
(*    and no configuration with GO/GA runs an audited write by o1 at the   *)
(*    same time (invitations are not audited; ADO runs as service role).   *)
(*  - delete_portfolio and admin_delete_account_data retry their lock-and- *)
(*    delete step on deadlock_detected.  The model has no retry: it checks *)
(*    that no deadlock happens at all among the modelled calls.            *)
(*  - Tuple-lock queue order is not modelled: when a lock is released any  *)
(*    waiter may proceed (a superset of PostgreSQL's behaviour).           *)
(*                                                                         *)
(* NOT MODELLED: GoTrue's deletion of the invitee's or o2's auth user, the *)
(* daily cleanup's deletion of old invitations, plain client UPDATEs of    *)
(* the portfolio row, and other portfolios.  See README.md.                *)
(*                                                                         *)
(* MODEL-CHECKING REDUCTIONS (sound for the invariants checked):           *)
(*  - The locals of a finished transaction are reset (dead values).        *)
(*  - EnvAbort only aborts transactions holding a lock or a write.         *)
(*  - Terminating stutters only once nothing is left to run, so TLC's      *)
(*    deadlock check stays ON and would report a process stuck forever.    *)
(*                                                                         *)
(* THE FIXES OF M6 (the code; each has a mutant that restores the code   *)
(* before M6):                                                             *)
(*  F1: in create_invitation, after lock_portfolio_for_change and the      *)
(*      input checks, a transaction advisory lock on (portfolio, e-mail):  *)
(*        perform pg_advisory_xact_lock(<first 64 bits of the SHA-256 of   *)
(*          'invitation:' || p_portfolio_id::text || ':' || v_email>);     *)
(*      so re-invites of one e-mail are serialised and the second one      *)
(*      replaces the first instead of failing with 23505 (CLockE).         *)
(*      Mutant no_create_serialise.                                        *)
(*  F2: the "already accepted by me" branch of accept_invitation returns   *)
(*      the member's current role, and 'revoked' to a caller who is no     *)
(*      longer a member (removed or left since accepting):                 *)
(*        select m.role into v_existing_role from portfolio_members m      *)
(*          where m.portfolio_id = v_invitation.portfolio_id               *)
(*            and m.user_id = v_uid;                                       *)
(*        if v_existing_role is null then return 'revoked'; end if;        *)
(*        return 'accepted', v_existing_role                               *)
(*      Mutants stale_response_role (the code before M6) and               *)
(*      removed_response_role (the invitation's role as a fallback).       *)
(*  F4: private.after_owner_membership_ends also revokes pending           *)
(*      invitations whose inviter is already NULL:                         *)
(*        ... and (i.invited_by = old.user_id or i.invited_by is null) ... *)
(*      (accept_invitation refuses such invitations anyway), so a direct   *)
(*      deletion of an inviter's auth user leaves none pending (GTrig).    *)
(*      Mutant no_null_inviter_revoke.                                     *)
(*  F3 (a direct deletion in Auth can deadlock with an accept) is not      *)
(*      changed in code: docs/operations.md requires deleting accounts     *)
(*      through delete-account (process GA after ADO).                     *)
(* MUTANT: removes one mechanism of the current code (see Mutants).        *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Procs,                \* processes (RPC calls) taking part in this configuration
    InitInv,              \* 1: invitation 1 (role manager, by o1, created at time 0) is pending at start
    MaxInv,               \* number of invitation ids (rows) available
    MaxClock,             \* the clock ranges over 0..MaxClock
    TTL,                  \* lifetime of an invitation in ticks
    MaxEnvAborts,         \* bound on environmental aborts per behaviour
    SoleOwner,            \* TRUE: o1 is the only owner at start (o2 is a manager)
    PCreatedBy,           \* portfolios.created_by of P: "o1" or "o2"
    MUTANT                \* "none" or one removed mechanism (see Mutants)

AllProcs == {"C1", "C2", "R1", "R2", "D1", "D2", "AU1", "AU2", "AU3", "AX", "AY",
             "MD", "MP", "MR", "ML", "MU", "ADU", "ADO", "GO", "GA"}

Mutants == {"none",
  \* --- public.accept_invitation (M5, M6) ---
  "no_for_update",            \* plain SELECT instead of SELECT ... FOR UPDATE
  "no_used_check",            \* no accepted_at IS NOT NULL check
  "no_expiry_check",          \* no expires_at <= now() check
  "no_revoked_check",         \* no revoked_at check (the CHECK constraint remains)
  "no_revoked_protection",    \* no revoked_at check AND no terminal-state CHECK
  "no_verified_check",        \* no email_confirmed_at check
  "no_email_check",           \* no e-mail equality check
  "upsert_role",              \* INSERT ... ON CONFLICT DO UPDATE SET role = excluded.role
  "wrong_role",               \* membership inserted with role 'owner' whatever the invitation says
  "no_accept_portfolio_lock", \* no "perform 1 from portfolios ... for key share" (the code before M5)
  "no_inviter_check",         \* no "invited_by is null or not exists (owner membership)" check
  "no_account_freeze",        \* no "perform private.require_active_account(v_uid)"
  "stale_response_role",      \* the retry branch reports the invitation's role (the code before M6, F2)
  "removed_response_role",    \* the retry branch falls back to the invitation's role for a former member (F2)
  \* --- schema / triggers ---
  "no_pending_index",         \* no portfolio_invitations_pending_email_key
  "no_notify_trigger",        \* no portfolio_invitations_after_accept (M4)
  "no_owner_trigger",         \* no portfolio_members_after_owner_ends (M5)
  "no_null_inviter_revoke",   \* the trigger matches only invited_by = old.user_id (before M6, F4)
  "no_portfolio_guard",       \* no explicit portfolio key in create/revoke/accept AND no FKs to portfolios
  \* --- create/revoke/membership RPCs ---
  "no_create_portfolio_lock", \* create_invitation without the key share of lock_portfolio_for_change
  "no_create_serialise",      \* create_invitation without the advisory lock (before M6, F1)
  "no_recheck",               \* lock_portfolio_for_change does not authorise again after the lock
  "member_change_key_share",  \* membership changes take key share instead of FOR UPDATE
  \* --- two mechanisms at once (each alone is backed up by the other) ---
  "no_inviter_protection",    \* no_owner_trigger + no_inviter_check
  "no_trigger_no_record",     \* no_owner_trigger + the accept-time revocation is not recorded
  "no_pending_index_no_serialise",   \* no_pending_index + no_create_serialise
  "no_inviter_check_no_null_revoke"} \* no_inviter_check + no_null_inviter_revoke

\* Mutants that remove the trigger portfolio_members_after_owner_ends.
TriggerOff == {"no_owner_trigger", "no_inviter_protection", "no_trigger_no_record"}
\* Mutants that remove portfolio_invitations_pending_email_key.
PendingIndexOff == {"no_pending_index", "no_pending_index_no_serialise"}
\* Mutants that remove create_invitation's advisory lock (F1).
SerialiseOff == {"no_create_serialise", "no_pending_index_no_serialise"}
\* Mutants that remove accept_invitation's inviter check.
InviterCheckOff == {"no_inviter_check", "no_inviter_protection", "no_inviter_check_no_null_revoke"}
\* Mutants whose membership trigger matches only invited_by = old.user_id (F4).
NullRevokeOff == {"no_null_inviter_revoke", "no_inviter_check_no_null_revoke"}

ASSUME /\ Procs \subseteq AllProcs
       /\ InitInv \in {0, 1}
       /\ MaxInv \in Nat
       /\ MaxInv >= InitInv + Cardinality(Procs \cap {"C1", "C2"})
       /\ MaxClock \in Nat
       /\ TTL \in Nat \ {0}
       /\ MaxEnvAborts \in Nat
       /\ SoleOwner \in BOOLEAN
       /\ PCreatedBy \in {"o1", "o2"}
       /\ "GA" \in Procs => "ADO" \in Procs
       /\ ~({"GO", "GA"} \subseteq Procs)
       /\ MUTANT \in Mutants

-----------------------------------------------------------------------------
(* Static data *)

NoP    == "-"           \* no transaction
NoUser == "-"           \* NULL user id
NoRole == "none"        \* no membership row / NULL role
Users  == {"o1", "o2", "u", "x", "y"}
\* public.member_role (M1)
Roles  == {"owner", "manager", "accountant", "viewer"}
InvEmail == "e"         \* the e-mail every modelled invitation is addressed to

\* lower(auth.users.email) (= profiles.email, kept in step by M1
\* private.handle_auth_user_change) and email_confirmed_at IS NOT NULL
Email(w) == CASE w = "u" -> "e" [] w = "y" -> "e" [] w = "x" -> "x"
              [] w = "o1" -> "o1" [] w = "o2" -> "o2"
Verified(w) == w # "y"

Kind(p) == CASE p \in {"C1", "C2"}             -> "create"
             [] p \in {"R1", "R2"}             -> "revoke"
             [] p \in {"D1", "D2"}             -> "delete"
             [] p \in {"MD", "MP", "MR", "ML", "MU"} -> "member"
             [] p \in {"ADU", "ADO"}           -> "account"
             [] p \in {"GO", "GA"}             -> "gotrue"
             [] OTHER                          -> "accept"

\* auth.uid() of the caller (for ADU/ADO: the account being deleted; the
\* caller is the service role)
Actor(p) == CASE p \in {"C1", "R1", "D2", "ML", "ADO", "GO", "GA"} -> "o1"
              [] p \in {"C2", "R2", "D1", "MD", "MP", "MR", "MU"} -> "o2"
              [] p \in {"AU1", "AU2", "AU3", "ADU"}          -> "u"
              [] p = "AX"                                    -> "x"
              [] p = "AY"                                    -> "y"

\* The user whose membership a membership change or account deletion targets.
Target(p) == IF p \in {"ADU", "MU"} THEN "u" ELSE "o1"

\* The role a membership change sets (NoRole = the row is deleted).
NewRole(p) == CASE p = "MD" -> "viewer" [] p = "MP" -> "owner" [] OTHER -> NoRole

\* p_role passed by invite-member to create_invitation
CreateRole(p) == IF p = "C1" THEN "manager" ELSE "viewer"

\* What a member holding role r may grant by invitation: create_invitation
\* requires the owner role (M5 lock_portfolio_for_change(..., ['owner'], ..))
\* and accepts every role (invite-member INVITE_ROLES includes 'owner').
Grantable(r) == IF r = "owner" THEN Roles ELSE {}

Inv == 1..MaxInv

\* One version of a portfolio_invitations row (portfolio_id = P, email = 'e').
Absent == [ex |-> FALSE, role |-> NoRole, by |-> NoUser, exp |-> 0,
           acc |-> FALSE, accBy |-> NoUser, rev |-> FALSE]
Fresh(r, b, e) == [ex |-> TRUE, role |-> r, by |-> b, exp |-> e,
                   acc |-> FALSE, accBy |-> NoUser, rev |-> FALSE]
\* "pending" = in the partial unique index (accepted_at IS NULL AND revoked_at IS NULL)
Pending(v) == v.ex /\ ~v.acc /\ ~v.rev

Unexpected == {"unique_violation", "fk_violation", "check_violation", "deadlock"}

MinOf(S) == CHOOSE m \in S : \A k \in S : m <= k

\* Lockable rows other than invitations and memberships: the portfolio row,
\* the advisory lock of create_invitation (M6), each user's profiles row, and
\* "A" = o1's auth.users row (only GO/GA delete it; the FK checks that
\* reference it take key share, which is recorded only when GO or GA runs:
\* with no conflicting holder a key-share lock on it is unobservable).
Res == {"P", "E", "A"} \cup Users

GoModelled == ({"GO", "GA"} \cap Procs) # {}

-----------------------------------------------------------------------------
VARIABLES
    \* ---- database: committed state + uncommitted writes ----
    pStatus,   \* committed state of the portfolio row P: "live" | "deleted"
    pDel,      \* in-progress transaction that deleted P, or NoP
    locks,     \* row locks held by in-progress transactions: set of [t, r, m]
    inv,       \* [Inv -> version]: committed version of each invitation row
    invLock,   \* [Inv -> Procs \cup {NoP}]: in-progress row-lock holder
    invDirty,  \* [Inv -> version]: the version written by invLock[j] (= inv[j] if none)
    mem,       \* [Users -> role]: committed portfolio_members row (P, user), NoRole if none
    memW,      \* [Users -> Procs \cup {NoP}]: in-progress writer of that row
    memDirty,  \* [Users -> role]: the row as written by memW (= mem if none)
    acct,      \* [Users -> BOOLEAN]: committed private.account_deletions row
    acctW,     \* [Users -> Procs \cup {NoP}]: in-progress inserter of that row
    gone,      \* o1's auth.users row is deleted (committed)
    nextInv,   \* next invitation id (uuid generation is never rolled back)
    clock,     \* wall clock
    \* ---- transactions: one record of locals per process ----
    tx,
    \* ---- history variables (only read by invariants) ----
    issued,    \* ids of invitations whose create committed (tokens handed out)
    hist,      \* [Inv -> record]: per-invitation history, see Commit
    flags,     \* record of booleans: bad events seen so far, see Commit
    envAborts  \* environmental aborts used so far

dbVars   == <<pStatus, pDel, locks, inv, invLock, invDirty, mem, memW, memDirty,
              acct, acctW, gone, nextInv>>
histVars == <<issued, hist, flags, envAborts>>
vars     == <<dbVars, clock, tx, histVars>>

Labels == {"idle", "done",
           "c_lockp", "c_locke", "c_member", "c_snap", "c_revoke", "c_insert", "c_fk", "c_commit",
           "r_lockp", "r_update", "r_commit",
           "d_lock", "d_delete", "d_cascade", "d_commit",
           "m_lockp", "m_trevoke", "m_commit",
           "x_lockp", "x_commit",
           "g_ptf", "g_mem", "g_invsnap", "g_inv", "g_trig", "g_commit",
           "a_acct", "a_lockp", "a_lock", "a_void", "a_member", "a_insert", "a_fk",
           "a_update", "a_trigger", "a_commit"}

\* Locals of a transaction: pc, now() (time), token (tok), invitation role
\* (role), existing member role (ex), rows its current UPDATE/DELETE still has
\* to visit (cand), invitation it accepted (acc), a flag (has: for an account
\* deletion "v_memberships # {}", for a GoTrue deletion "the queued membership
\* trigger will fire"), and the outcome/reported role the caller receives.
Idle == [pc |-> "idle", time |-> 0, tok |-> 0, role |-> NoRole, ex |-> NoRole,
         cand |-> {}, acc |-> 0, has |-> FALSE, out |-> "none", resp |-> NoRole]
Done(res, rr) == [Idle EXCEPT !.pc = "done", !.out = res, !.resp = rr]

-----------------------------------------------------------------------------
(* What a statement of transaction p sees: committed data + its own writes *)

InvSeen(p, j) == IF invLock[j] = p THEN invDirty[j] ELSE inv[j]
MemSeen(p, w) == IF memW[w] = p THEN memDirty[w] ELSE mem[w]
PLive(p)      == pDel # p /\ pStatus = "live"

\* M1 app.has_portfolio_role(P, array['owner']) for user w
IsOwner(p, w) == MemSeen(p, w) = "owner"

\* PostgreSQL row-lock conflict table restricted to the modes used here.
Conflicts(m1, m2) == \/ m1 = "U" \/ m2 = "U"
                     \/ m1 = "NKU" /\ m2 = "NKU"
                     \/ m1 = "X" /\ m2 = "X"
LBlockers(p, r, m) == {l.t : l \in {l \in locks : l.r = r /\ l.t # p /\ Conflicts(l.m, m)}}
Hold(p, r, m) == locks \cup {[t |-> p, r |-> r, m |-> m]}

InvBlocker(p, j) == IF invLock[j] \notin {NoP, p} THEN {invLock[j]} ELSE {}
MemBlocker(p, w) == IF memW[w] \notin {NoP, p} THEN {memW[w]} ELSE {}

\* INSERT into portfolio_invitations: portfolio_invitations_pending_email_key.
\* A committed pending row conflicts unless an in-progress transaction has
\* updated/deleted it (a FOR UPDATE lock alone does not hide it).
UniqConflict(p) ==
    \E k \in Inv :
        \/ invLock[k] = p /\ Pending(invDirty[k])
        \/ /\ invLock[k] # p
           /\ Pending(inv[k])
           /\ (invLock[k] = NoP \/ invDirty[k] = inv[k])
UniqWaitOn(p) ==
    {invLock[k] : k \in {k \in Inv :
        /\ invLock[k] \notin {NoP, p}
        /\ \/ Pending(inv[k]) /\ invDirty[k] # inv[k]      \* being revoked/accepted/deleted
           \/ ~inv[k].ex /\ Pending(invDirty[k])}}          \* being inserted

\* M4 private.after_invitation_accepted inserts one notification per other
\* owner; each insert's FK check takes KS on P.
TriggerInserts(p) == \E o \in Users : o # Actor(p) /\ MemSeen(p, o) = "owner"

\* Rows of portfolio_members the ON DELETE CASCADE of P must wait for.
MemCascadeBlockers(p) ==
    {memW[w] : w \in {w \in Users : mem[w] # NoRole /\ memW[w] \notin {NoP, p}}}

NoKeyMutants == {"no_accept_portfolio_lock", "no_portfolio_guard"}

\* The rows private.after_owner_membership_ends revokes for a membership of
\* user w that ended: "where i.portfolio_id = old.portfolio_id and
\* i.invited_by = old.user_id and accepted_at is null and revoked_at is null"
\* (M6 adds "or i.invited_by is null"; not in mutant no_null_inviter_revoke).
TrigRow(v, w) == Pending(v) /\ (v.by = w \/ (MUTANT \notin NullRevokeOff /\ v.by = NoUser))

\* An FK check referencing o1's auth.users row waits for GoTrue's deletion.
AuthBlock(p, c) == IF GoModelled /\ c THEN LBlockers(p, "A", "KS") ELSE {}
AuthHold(p, c, ls) == IF GoModelled /\ c THEN ls \cup {[t |-> p, r |-> "A", m |-> "KS"]} ELSE ls
\* Which FK checks reference o1's auth.users row:
CFkNeedsA(p) == Actor(p) = "o1"                          \* invitations.invited_by
AFkNeedsA(p) == InvSeen(p, tx[p].tok).by = "o1"          \* portfolio_members.invited_by
ATrNeedsA(p) == Actor(p) # "o1" /\ MemSeen(p, "o1") = "owner"  \* notifications.user_id

\* Transactions p is currently waiting for.
Blockers(p) ==
    LET lbl   == tx[p].pc
        PK(m) == IF MUTANT = "no_portfolio_guard" THEN {} ELSE LBlockers(p, "P", m)
    IN
    CASE lbl = "c_lockp"   -> IF MUTANT = "no_create_portfolio_lock" THEN {} ELSE PK("KS")
      [] lbl = "c_locke"   -> LBlockers(p, "E", "X")
      [] lbl = "c_revoke"  -> InvBlocker(p, MinOf(tx[p].cand))
      [] lbl = "c_insert"  -> IF MUTANT \in PendingIndexOff \/ UniqConflict(p)
                            THEN {} ELSE UniqWaitOn(p)
      [] lbl = "c_fk"      -> PK("KS") \cup AuthBlock(p, CFkNeedsA(p))
      [] lbl = "r_lockp"   -> PK("KS")
      [] lbl = "r_update"  -> InvBlocker(p, tx[p].tok)
      [] lbl = "d_lock"    -> LBlockers(p, "P", "U")
      [] lbl = "d_delete"  -> MemCascadeBlockers(p)
      [] lbl = "d_cascade" -> InvBlocker(p, MinOf(tx[p].cand))
      [] lbl = "m_lockp"   -> LBlockers(p, "P", IF MUTANT = "member_change_key_share" THEN "KS" ELSE "U")
                            \cup MemBlocker(p, Target(p))
      [] lbl = "m_trevoke" -> InvBlocker(p, MinOf(tx[p].cand))
      [] lbl = "x_lockp"   -> LBlockers(p, "P", "U") \cup MemBlocker(p, Target(p))
      [] lbl = "a_acct"    -> LBlockers(p, Actor(p), "KS")
      [] lbl = "a_lockp"   -> IF InvSeen(p, tx[p].tok).ex /\ MUTANT \notin NoKeyMutants
                            THEN LBlockers(p, "P", "KS") ELSE {}
      [] lbl = "a_lock"    -> IF MUTANT = "no_for_update" THEN {} ELSE InvBlocker(p, tx[p].tok)
      [] lbl = "a_insert"  -> MemBlocker(p, Actor(p))
      [] lbl = "a_fk"      -> PK("KS") \cup AuthBlock(p, AFkNeedsA(p))
      [] lbl = "a_update"  -> InvBlocker(p, tx[p].tok)
      [] lbl = "a_trigger" -> IF TriggerInserts(p) THEN PK("KS") \cup AuthBlock(p, ATrNeedsA(p)) ELSE {}
      [] lbl = "g_ptf"     -> IF PCreatedBy = "o1" /\ pStatus = "live" THEN LBlockers(p, "P", "NKU") ELSE {}
      [] lbl = "g_mem"     -> IF mem["o1"] # NoRole THEN MemBlocker(p, "o1") ELSE {}
      [] lbl = "g_inv"     -> InvBlocker(p, MinOf(tx[p].cand))
      [] OTHER           -> {}

\* Wait-for graph and PostgreSQL's deadlock detector.
WaitsFor(p) == IF tx[p].pc \in {"idle", "done"} THEN {} ELSE Blockers(p)
RECURSIVE Closure(_, _)
Closure(frontier, seen) ==
    LET nxt == (UNION {WaitsFor(q) : q \in frontier}) \ seen
    IN IF nxt = {} THEN seen ELSE Closure(nxt, seen \cup nxt)
InCycle(p) == p \in Closure({p}, {})

-----------------------------------------------------------------------------
(* Frames: each step changes the listed variables, the rest stay unchanged *)

SetTx(p, r) == tx' = [tx EXCEPT ![p] = r]
Go(p, l)    == [tx[p] EXCEPT !.pc = l]

\* Only the locals of p change (reads, local decisions).
OnlyTx(p, r) == SetTx(p, r) /\ UNCHANGED <<dbVars, clock, histVars>>

\* p takes row locks (ls = the new lock set).
LockTx(p, ls, r) ==
    /\ locks' = ls
    /\ SetTx(p, r)
    /\ UNCHANGED <<pStatus, pDel, inv, invLock, invDirty, mem, memW, memDirty,
                   acct, acctW, gone, nextInv, clock, histVars>>

\* p locks invitation row j and writes version v into it.
InvTx(p, j, v, r) ==
    /\ invLock'  = [invLock EXCEPT ![j] = p]
    /\ invDirty' = [invDirty EXCEPT ![j] = v]
    /\ SetTx(p, r)
    /\ UNCHANGED <<pStatus, pDel, locks, inv, mem, memW, memDirty, acct, acctW, gone,
                   nextInv, clock, histVars>>

\* p takes row locks ls and writes role nr into membership row w.
MemTx(p, ls, w, nr, r) ==
    /\ locks'    = ls
    /\ memW'     = [memW EXCEPT ![w] = p]
    /\ memDirty' = [memDirty EXCEPT ![w] = nr]
    /\ SetTx(p, r)
    /\ UNCHANGED <<pStatus, pDel, inv, invLock, invDirty, mem, acct, acctW, gone,
                   nextInv, clock, histVars>>

-----------------------------------------------------------------------------
(* Transaction end *)

\* ROLLBACK: discard p's writes, release its locks.
Rollback(p) ==
    /\ invLock'  = [j \in Inv |-> IF invLock[j] = p THEN NoP ELSE invLock[j]]
    /\ invDirty' = [j \in Inv |-> IF invLock[j] = p THEN inv[j] ELSE invDirty[j]]
    /\ memW'     = [w \in Users |-> IF memW[w] = p THEN NoP ELSE memW[w]]
    /\ memDirty' = [w \in Users |-> IF memW[w] = p THEN mem[w] ELSE memDirty[w]]
    /\ acctW'    = [w \in Users |-> IF acctW[w] = p THEN NoP ELSE acctW[w]]
    /\ pDel'     = IF pDel = p THEN NoP ELSE pDel
    /\ locks'    = {l \in locks : l.t # p}
    /\ UNCHANGED <<pStatus, inv, mem, acct, gone, nextInv>>

\* A statement raised: PostgreSQL aborts the whole transaction.
Abort(p, err) ==
    /\ Rollback(p)
    /\ SetTx(p, Done(err, NoRole))
    /\ UNCHANGED <<clock, issued, hist, flags>>
Fail(p, err) == Abort(p, err) /\ UNCHANGED envAborts

\* COMMIT with result res (rr = role reported by accept_invitation).
\* The history it records, per invitation j:
\*   role, by: role and inviter of j, recorded when its create commits
\*             (columns never updated by the modelled code);
\*   accN:     committed transactions that set accepted_at on j;
\*   late:     some committed acceptance of j had now() >= expires_at;
\*   rev:      some committed transaction set revoked_at on j;
\*   notify:   committed firings of portfolio_invitations_after_accept on j;
\*   voided:   some commit ended the inviter's ownership of P while j existed
\*             and was not accepted;
\*   revResp:  some committed accept_invitation of j returned 'revoked' while
\*             j was not accepted (a retry of j by the invitee who accepted
\*             it and is no longer a member is answered 'revoked' too, F2;
\*             that answer concerns the membership, not j);
\* and, as flags:
\*   badGrant:    an acceptance committed while the invitation's role was
\*                not grantable by the inviter's role at that commit;
\*   roleChanged: an accept_invitation changed an existing member's role;
\*   wrongGrant:  an accept_invitation created a membership whose role is
\*                not the accepted invitation's role;
\*   respBad:     an accept_invitation reported 'accepted' with a role the
\*                caller does not have after its commit.
Commit(p, res, rr) ==
    LET newRows  == {j \in Inv : invLock[j] = p /\ ~inv[j].ex /\ invDirty[j].ex}
        invAfter == [j \in Inv |-> IF invLock[j] = p THEN invDirty[j] ELSE inv[j]]
        memAfter == [w \in Users |-> IF memW[w] = p THEN memDirty[w] ELSE mem[w]]
        ja       == tx[p].acc
        \* the inviter recorded when the invitation was created (invited_by
        \* may since have been set to NULL by GoTrue's user deletion)
        byOf(j)  == IF j \in newRows THEN invDirty[j].by ELSE hist[j].by
        Lost(w)  == w \in Users /\ mem[w] = "owner" /\ memAfter[w] # "owner"
        RoleAfter(w) == IF w \in Users THEN memAfter[w] ELSE NoRole
    IN
    /\ inv'      = invAfter
    /\ invLock'  = [j \in Inv |-> IF invLock[j] = p THEN NoP ELSE invLock[j]]
    /\ mem'      = memAfter
    /\ memW'     = [w \in Users |-> IF memW[w] = p THEN NoP ELSE memW[w]]
    /\ acct'     = [w \in Users |-> acct[w] \/ acctW[w] = p]
    /\ acctW'    = [w \in Users |-> IF acctW[w] = p THEN NoP ELSE acctW[w]]
    /\ gone'     = (gone \/ Kind(p) = "gotrue")
    /\ pStatus'  = IF pDel = p THEN "deleted" ELSE pStatus
    /\ pDel'     = IF pDel = p THEN NoP ELSE pDel
    /\ locks'    = {l \in locks : l.t # p}
    /\ UNCHANGED <<invDirty, memDirty, nextInv, clock, envAborts>>
    /\ SetTx(p, Done(res, rr))
    /\ issued'   = issued \cup newRows
    /\ hist'     = [j \in Inv |-> [
          role    |-> IF j \in newRows THEN invDirty[j].role ELSE hist[j].role,
          by      |-> IF j \in newRows THEN invDirty[j].by ELSE hist[j].by,
          accN    |-> IF ja = j THEN hist[j].accN + 1 ELSE hist[j].accN,
          late    |-> hist[j].late \/ (ja = j /\ tx[p].time >= invDirty[j].exp),
          rev     |-> hist[j].rev \/ (invLock[j] = p /\ invDirty[j].rev /\ ~inv[j].rev),
          notify  |-> IF ja = j /\ ~inv[j].acc /\ MUTANT # "no_notify_trigger"
                      THEN hist[j].notify + 1 ELSE hist[j].notify,
          voided  |-> hist[j].voided \/ (invAfter[j].ex /\ ~invAfter[j].acc /\ Lost(byOf(j))),
          revResp |-> hist[j].revResp \/
                      (Kind(p) = "accept" /\ res = "revoked" /\ tx[p].tok = j /\ ~invAfter[j].acc)]]
    /\ flags'    = [
          badGrant    |-> flags.badGrant \/
                          (ja # 0 /\ invDirty[ja].role \notin Grantable(RoleAfter(hist[ja].by))),
          roleChanged |-> flags.roleChanged \/
                          (Kind(p) = "accept" /\
                           \E w \in Users : memW[w] = p /\ mem[w] # NoRole /\ memDirty[w] # mem[w]),
          wrongGrant  |-> flags.wrongGrant \/
                          (Kind(p) = "accept" /\ ja # 0 /\
                           \E w \in Users : memW[w] = p /\ mem[w] = NoRole /\ memDirty[w] # invDirty[ja].role),
          respBad     |-> flags.respBad \/ (res = "accepted" /\ rr # memAfter[Actor(p)])]

-----------------------------------------------------------------------------
(* public.create_invitation(p_portfolio_id, p_email, p_role)  [M6]         *)
(* called by supabase/functions/invite-member/handler.ts inviteMember      *)

\* Transaction start (now()); first statement of lock_portfolio_for_change:
\* app.require_portfolio_role(P, ['owner']) (raises 42501 -> abort).
\* The Edge Function's input validation, private.enforce_rate_limit and the
\* e-mail regex are abstracted (valid input, no 429 except EnvAbort).
CBegin(p) ==
    /\ Kind(p) = "create" /\ tx[p].pc = "idle"
    /\ IF IsOwner(p, Actor(p))
         THEN OnlyTx(p, [Go(p, "c_lockp") EXCEPT !.time = clock])
         ELSE OnlyTx(p, Done("forbidden", NoRole))

\* lock_portfolio_for_change(P, ['owner'], false):
\*   perform 1 from portfolios where id = P for key share;   (nothing if gone)
\*   perform app.require_portfolio_role(P, ['owner']);       (again, 42501)
\* Merged into one step: once p holds KS on P, no membership change (they
\* need FOR UPDATE on P) can commit before p ends; if P is gone, so are its
\* memberships, so the re-check fails either way.
CLockP(p) ==
    /\ tx[p].pc = "c_lockp" /\ Blockers(p) = {}
    /\ LET keyed == PLive(p) /\ MUTANT \notin {"no_create_portfolio_lock", "no_portfolio_guard"}
       IN IF MUTANT # "no_recheck" /\ ~IsOwner(p, Actor(p))
            THEN Fail(p, "forbidden")
            ELSE LockTx(p, IF keyed THEN Hold(p, "P", "KS") ELSE locks,
                        Go(p, IF MUTANT \notin SerialiseOff THEN "c_locke" ELSE "c_member"))

\* perform pg_advisory_xact_lock(<first 64 bits of sha256('invitation:' || P
\*   || ':' || v_email)>)  (M6, F1; after the rate limit and the input checks, which
\* are abstracted).  Skipped in mutant no_create_serialise.
CLockE(p) ==
    /\ tx[p].pc = "c_locke" /\ Blockers(p) = {}
    /\ LockTx(p, Hold(p, "E", "X"), Go(p, "c_member"))

\* if exists (members of P whose profiles.email = v_email) then
\*   app.fail('already_member')  (22023 -> abort).  Users with e-mail 'e': u, y.
CMember(p) ==
    /\ tx[p].pc = "c_member"
    /\ IF \E w \in Users : Email(w) = InvEmail /\ MemSeen(p, w) # NoRole
         THEN Fail(p, "already_member")
         ELSE OnlyTx(p, Go(p, "c_snap"))

\* update portfolio_invitations set revoked_at = now() where portfolio_id = P
\*   and email = v_email and accepted_at is null and revoked_at is null
\* Statement start: the rows it will consider are those of its snapshot.
CSnap(p) ==
    /\ tx[p].pc = "c_snap"
    /\ LET c == {j \in Inv : Pending(InvSeen(p, j))}
       IN OnlyTx(p, [Go(p, IF c = {} THEN "c_insert" ELSE "c_revoke") EXCEPT !.cand = c])

\* ... for each candidate: lock it (waiting for its holder), re-check the WHERE
\* clause on the newest committed version (EvalPlanQual), set revoked_at.
CRevoke(p) ==
    /\ tx[p].pc = "c_revoke" /\ Blockers(p) = {}
    /\ LET j    == MinOf(tx[p].cand)
           v    == InvSeen(p, j)
           rest == tx[p].cand \ {j}
           r    == [Go(p, IF rest = {} THEN "c_insert" ELSE "c_revoke") EXCEPT !.cand = rest]
       IN IF Pending(v) THEN InvTx(p, j, [v EXCEPT !.rev = TRUE], r) ELSE OnlyTx(p, r)

\* insert into portfolio_invitations (portfolio_id, email, role, verifier_hash,
\*   invited_by, expires_at) values (P, v_email, p_role, ..., auth.uid(),
\*   now() + interval '7 days')
\* Heap insert + check of portfolio_invitations_pending_email_key.
CInsert(p) ==
    /\ tx[p].pc = "c_insert" /\ Blockers(p) = {}
    /\ IF MUTANT \notin PendingIndexOff /\ UniqConflict(p)
         THEN Fail(p, "unique_violation")
         ELSE /\ invLock'  = [invLock EXCEPT ![nextInv] = p]
              /\ invDirty' = [invDirty EXCEPT ![nextInv] =
                                Fresh(CreateRole(p), Actor(p), tx[p].time + TTL)]
              /\ nextInv'  = nextInv + 1
              /\ SetTx(p, Go(p, "c_fk"))
              /\ UNCHANGED <<pStatus, pDel, locks, inv, mem, memW, memDirty, acct, acctW,
                             gone, clock, histVars>>

\* ... end of the INSERT statement: RI_FKey_check_ins on portfolio_id takes
\* FOR KEY SHARE on P, and the one on invited_by takes FOR KEY SHARE on the
\* inviter's auth.users row (23503 if either row is gone).
CFk(p) ==
    /\ tx[p].pc = "c_fk" /\ Blockers(p) = {}
    /\ IF MUTANT = "no_portfolio_guard" THEN OnlyTx(p, Go(p, "c_commit"))
       ELSE IF ~PLive(p) \/ (CFkNeedsA(p) /\ gone) THEN Fail(p, "fk_violation")
       ELSE LockTx(p, AuthHold(p, CFkNeedsA(p), Hold(p, "P", "KS")), Go(p, "c_commit"))

\* return jsonb_build_object(... 'token' ...) and COMMIT; invite-member then
\* hands the token to the owner (and maybe e-mails it).
CCommit(p) == tx[p].pc = "c_commit" /\ Commit(p, "ok", NoRole)

-----------------------------------------------------------------------------
(* public.revoke_invitation(p_invitation_id)  [M5]                         *)

\* select i.portfolio_id ... where i.id = p_invitation_id; if not found then
\* app.forbid(); then lock_portfolio_for_change's first
\* app.require_portfolio_role(P, ['owner']).
RBegin(p) ==
    /\ Kind(p) = "revoke" /\ tx[p].pc = "idle" /\ issued # {}
    /\ \E j \in issued :
          IF ~InvSeen(p, j).ex \/ ~IsOwner(p, Actor(p))
            THEN OnlyTx(p, Done("forbidden", NoRole))
            ELSE OnlyTx(p, [Go(p, "r_lockp") EXCEPT !.tok = j])

\* lock_portfolio_for_change(P, ['owner'], false): key share, authorise again.
\* Merged into one step for the reason given at CLockP.
RLockP(p) ==
    /\ tx[p].pc = "r_lockp" /\ Blockers(p) = {}
    /\ LET keyed == PLive(p) /\ MUTANT # "no_portfolio_guard"
       IN IF MUTANT # "no_recheck" /\ ~IsOwner(p, Actor(p))
            THEN Fail(p, "forbidden")
            ELSE LockTx(p, IF keyed THEN Hold(p, "P", "KS") ELSE locks, Go(p, "r_update"))

\* update portfolio_invitations set revoked_at = now() where id = p_invitation_id
\*   and accepted_at is null and revoked_at is null
\* Waits for the row lock, then EvalPlanQual on the newest version.  When no
\* row qualifies the function returns and commits at once (no writes).
RUpdate(p) ==
    /\ tx[p].pc = "r_update" /\ Blockers(p) = {}
    /\ LET j == tx[p].tok
           v == InvSeen(p, j)
       IN IF Pending(v)
            THEN InvTx(p, j, [v EXCEPT !.rev = TRUE], Go(p, "r_commit"))
            ELSE Commit(p, "ok", NoRole)

RCommit(p) == tx[p].pc = "r_commit" /\ Commit(p, "ok", NoRole)

-----------------------------------------------------------------------------
(* public.delete_portfolio(p_portfolio_id, p_confirmation)  [M5]           *)

\* app.require_portfolio_role(P, ['owner']); private.require_portfolio_name
\* (the confirmation is assumed to match; a missing row -> forbidden).
DBegin(p) ==
    /\ Kind(p) = "delete" /\ tx[p].pc = "idle"
    /\ IF IsOwner(p, Actor(p))
         THEN OnlyTx(p, Go(p, "d_lock"))
         ELSE OnlyTx(p, Done("forbidden", NoRole))

\* In the retry loop's subtransaction:
\*   private.lock_portfolios_for_deletion([P])   (FOR UPDATE; nothing if gone)
\*   app.require_portfolio_role(P, ['owner'])     (again; 42501 is not caught)
\*   private.require_portfolio_name(P, ...)       (again)
\* Merged: while p holds FOR UPDATE on P nobody else can change P's
\* memberships; if P is gone so is p's membership, so the re-check raises.
DLock(p) ==
    /\ tx[p].pc = "d_lock" /\ Blockers(p) = {}
    /\ IF ~PLive(p) \/ ~IsOwner(p, Actor(p))
         THEN Fail(p, "forbidden")
         ELSE LockTx(p, Hold(p, "P", "U"), Go(p, "d_delete"))

\* private.delete_locked_portfolios([P]): delete from portfolios where id = P
\* + the AFTER-row RI cascade triggers in trigger-name (= creation) order:
\* portfolio_members first, then portfolio_invitations.  Each cascade query
\* uses a fresh snapshot: uncommitted rows of other transactions are
\* invisible.  The member trigger after_owner_membership_ends fired by the
\* cascade returns at once ("if not exists (select 1 from portfolios ...)":
\* the portfolio row is deleted by this transaction).  The audit trigger
\* skips rows of a deleted portfolio.  Also reached from admin_delete_account_data.
DDelete(p) ==
    /\ tx[p].pc = "d_delete" /\ Blockers(p) = {}
    /\ pDel' = p
    /\ memW'     = [w \in Users |-> IF mem[w] # NoRole /\ memW[w] = NoP THEN p ELSE memW[w]]
    /\ memDirty' = [w \in Users |-> IF mem[w] # NoRole /\ memW[w] = NoP THEN NoRole ELSE memDirty[w]]
    /\ LET c == {j \in Inv : inv[j].ex}
       IN SetTx(p, [Go(p, IF c = {} THEN "d_commit" ELSE "d_cascade") EXCEPT !.cand = c])
    /\ UNCHANGED <<pStatus, locks, inv, invLock, invDirty, mem, acct, acctW, gone, nextInv,
                   clock, histVars>>

\* delete from only portfolio_invitations where portfolio_id = P (cascade),
\* row by row (in id order), waiting for each row's lock holder.
DCascade(p) ==
    /\ tx[p].pc = "d_cascade" /\ Blockers(p) = {}
    /\ LET j    == MinOf(tx[p].cand)
           rest == tx[p].cand \ {j}
           r    == [Go(p, IF rest = {} THEN "d_commit" ELSE "d_cascade") EXCEPT !.cand = rest]
       IN IF inv[j].ex THEN InvTx(p, j, Absent, r) ELSE OnlyTx(p, r)

DCommit(p) == tx[p].pc = "d_commit" /\ Commit(p, "ok", NoRole)

-----------------------------------------------------------------------------
(* public.update_member_role / public.remove_member  [M5]                   *)
(*   MD: update_member_role(P, o1, 'viewer') by o2                         *)
(*   MP: update_member_role(P, o1, 'owner')  by o2                         *)
(*   MR: remove_member(P, o1) by o2;  ML: remove_member(P, o1) by o1       *)
(*   MU: remove_member(P, u) by o2 (the invitee, after accepting: F2)       *)

\* lock_portfolio_for_change's first require_portfolio_role: ['owner'], or
\* any role (null) when removing oneself.
MayChange(p) == IF p = "ML" THEN MemSeen(p, Actor(p)) # NoRole ELSE IsOwner(p, Actor(p))

MBegin(p) ==
    /\ Kind(p) = "member" /\ tx[p].pc = "idle"
    /\ IF MayChange(p)
         THEN OnlyTx(p, Go(p, "m_lockp"))
         ELSE OnlyTx(p, Done("forbidden", NoRole))

\* lock_portfolio_for_change(P, roles, true): FOR UPDATE on P (nothing if
\* gone), authorise again; then the RPC's own statements: select the
\* target's role (member_not_found), the last-owner check (last_owner), the
\* UPDATE ... set role / DELETE, and the AFTER ROW trigger
\* portfolio_members_after_owner_ends -> private.after_owner_membership_ends,
\* which fires when old.role = 'owner' and the row is deleted or its new role
\* is not 'owner': if P exists, update portfolio_invitations set revoked_at =
\* now() where portfolio_id = P and invited_by = old.user_id and pending.
\* Merged into one step: p holds FOR UPDATE on P from its first statement,
\* and every other writer of memberships or invitations of P holds a lock
\* on P that conflicts with it (create/revoke/accept: key share; deletions:
\* FOR UPDATE), so nothing else can commit in between.  The trigger's rows
\* are then visited one by one (MTRevoke).
MChange(p) ==
    /\ tx[p].pc = "m_lockp" /\ Blockers(p) = {}
    /\ LET tgt    == Target(p)
           r      == MemSeen(p, tgt)
           nr     == NewRole(p)
           owners == {w \in Users : MemSeen(p, w) = "owner"}
           mode   == IF MUTANT = "member_change_key_share" THEN "KS" ELSE "U"
           ls     == IF PLive(p) THEN Hold(p, "P", mode) ELSE locks
           fires  == r = "owner" /\ nr # "owner" /\ MUTANT \notin TriggerOff
           c      == {j \in Inv : TrigRow(InvSeen(p, j), tgt)}
           cnd    == IF fires /\ PLive(p) THEN c ELSE {}
       IN IF MUTANT # "no_recheck" /\ ~MayChange(p) THEN Fail(p, "forbidden")
          ELSE IF r = NoRole THEN Fail(p, "member_not_found")
          ELSE IF r = "owner" /\ nr # "owner" /\ Cardinality(owners) = 1 THEN Fail(p, "last_owner")
          ELSE MemTx(p, ls, tgt, nr,
                     [Go(p, IF cnd = {} THEN "m_commit" ELSE "m_trevoke") EXCEPT !.cand = cnd])

\* The trigger's UPDATE, row by row: lock, EvalPlanQual, set revoked_at.
\* Also used by admin_delete_account_data (XLockP).
MTRevoke(p) ==
    /\ tx[p].pc = "m_trevoke" /\ Blockers(p) = {}
    /\ LET j    == MinOf(tx[p].cand)
           v    == InvSeen(p, j)
           rest == tx[p].cand \ {j}
           after == IF Kind(p) = "gotrue" THEN "g_commit" ELSE "m_commit"
           r    == [Go(p, IF rest = {} THEN after ELSE "m_trevoke") EXCEPT !.cand = rest]
       IN IF TrigRow(v, Target(p))
            THEN InvTx(p, j, [v EXCEPT !.rev = TRUE], r)
            ELSE OnlyTx(p, r)

MCommit(p) == tx[p].pc = "m_commit" /\ Commit(p, "ok", NoRole)

-----------------------------------------------------------------------------
(* public.admin_delete_account_data(p_user_id)  [M5]                       *)
(*   ADU: for u (the invitee); ADO: for o1 (an inviter).  Called by        *)
(*   supabase/functions/delete-account/handler.ts with the secret key.     *)

\* perform 1 from profiles where id = p_user_id for update;
\* insert into private.account_deletions ... on conflict do nothing;
\* (loop) select array_agg(portfolio_id) into v_memberships from portfolio_members
\*        where user_id = p_user_id;
\* Merged into one step: the profile lock and the insert touch rows nobody
\* else writes, so an interleaving with them in between is equivalent to
\* one where they come after the membership snapshot.  It waits (it holds
\* nothing yet) while an accept_invitation of that user holds key share on
\* the profile.
XBegin(p) ==
    /\ Kind(p) = "account" /\ tx[p].pc = "idle"
    /\ LBlockers(p, Target(p), "U") = {}
    /\ locks' = Hold(p, Target(p), "U")
    /\ acctW' = [acctW EXCEPT ![Target(p)] = p]
    /\ LET has == MemSeen(p, Target(p)) # NoRole
       IN SetTx(p, [Go(p, IF has THEN "x_lockp" ELSE "x_commit") EXCEPT !.has = has])
    /\ UNCHANGED <<pStatus, pDel, inv, invLock, invDirty, mem, memW, memDirty, acct,
                   gone, nextInv, clock, histVars>>

\* private.lock_portfolios_for_deletion(v_memberships) (FOR UPDATE; nothing if
\* gone); v_deleted := admin_account_deletion_scope (portfolios where the
\* user is the only owner); private.delete_locked_portfolios(v_deleted)
\* (-> DDelete); delete from portfolio_members where user_id = p_user_id and
\* portfolio_id = any(v_memberships) (fires after_owner_membership_ends ->
\* MTRevoke when the user was an owner).  Merged for the reason given at
\* MChange (p holds FOR UPDATE on P).
XLockP(p) ==
    /\ tx[p].pc = "x_lockp" /\ Blockers(p) = {}
    /\ LET w      == Target(p)
           r      == MemSeen(p, w)
           owners == {o \in Users : MemSeen(p, o) = "owner"}
           fires  == r = "owner" /\ MUTANT \notin TriggerOff
           c      == {j \in Inv : TrigRow(InvSeen(p, j), w)}
           cnd    == IF fires THEN c ELSE {}
       IN IF ~PLive(p) THEN OnlyTx(p, Go(p, "x_commit"))
          ELSE IF r = "owner" /\ owners = {w}
            THEN LockTx(p, Hold(p, "P", "U"), Go(p, "d_delete"))
          ELSE IF r = NoRole
            THEN LockTx(p, Hold(p, "P", "U"), Go(p, "x_commit"))
          ELSE MemTx(p, Hold(p, "P", "U"), w, NoRole,
                     [Go(p, IF cnd = {} THEN "m_commit" ELSE "m_trevoke") EXCEPT !.cand = cnd])

\* delete from notifications where user_id = ...; return; COMMIT.
XCommit(p) == tx[p].pc = "x_commit" /\ Commit(p, "ok", NoRole)

-----------------------------------------------------------------------------
(* GoTrue deletes the auth user o1: delete from auth.users where id = o1,  *)
(* with the ON DELETE actions of the FKs that reference auth.users (M1),   *)
(* run as RI triggers at the end of the statement in trigger-name order    *)
(* (RI_ConstraintTrigger_a_<oid>; on the test database that is creation    *)
(* order): profiles CASCADE, portfolios.created_by SET NULL,               *)
(* portfolio_members.user_id CASCADE, portfolio_members.invited_by SET     *)
(* NULL, portfolio_invitations.invited_by SET NULL, ... .  The triggers    *)
(* that the CASCADE of the membership row queues (M5                       *)
(* portfolio_members_after_owner_ends) fire only AFTER all of these RI     *)
(* actions, i.e. after invited_by was already set to NULL (observed on    *)
(* PostgreSQL 16.15 by replay_findings.sh, F4: after the deletion the      *)
(* invitation has invited_by NULL and no revoked_at).                      *)
(*   GO: directly (Supabase dashboard / Auth admin API), without           *)
(*       admin_delete_account_data first;                                  *)
(*   GA: as supabase/functions/delete-account/handler.ts deleteAccount     *)
(*       does it: auth.admin.deleteUser only after                         *)
(*       admin_delete_account_data(o1) (ADO) returned successfully.        *)
(* Not modelled: the profiles CASCADE (no modelled transaction locks o1's  *)
(* profile at the same time: GA follows ADO, and accepts lock only their   *)
(* caller's profile), portfolio_members.invited_by SET NULL (it only       *)
(* updates invited_by of members, read by no modelled check), the SET NULL *)
(* of accepted_by (o1 accepts nothing) and the notifications CASCADE.      *)

\* The DELETE locks the auth.users row first (waits for key-share holders:
\* transactions whose FK checks referenced o1).
GBegin(p) ==
    /\ Kind(p) = "gotrue" /\ tx[p].pc = "idle"
    /\ p = "GA" => tx["ADO"].pc = "done" /\ tx["ADO"].out = "ok"
    /\ LBlockers(p, "A", "U") = {}
    /\ LockTx(p, Hold(p, "A", "U"), Go(p, "g_ptf"))

\* portfolios.created_by ON DELETE SET NULL: an UPDATE of a non-key column
\* takes FOR NO KEY UPDATE on P (only if o1 created P; skipped if P is gone).
GPtf(p) ==
    /\ tx[p].pc = "g_ptf" /\ Blockers(p) = {}
    /\ IF PCreatedBy = "o1" /\ pStatus = "live"
         THEN LockTx(p, Hold(p, "P", "NKU"), Go(p, "g_mem"))
         ELSE OnlyTx(p, Go(p, "g_mem"))

\* portfolio_members.user_id ON DELETE CASCADE: o1's membership row is
\* deleted (newest committed version, after waiting for its writer).  When
\* o1 was an owner this queues portfolio_members_after_owner_ends (M5),
\* which fires later (GTrig); has records that it will fire.  No portfolio
\* lock is taken on this path.
GMem(p) ==
    /\ tx[p].pc = "g_mem" /\ Blockers(p) = {}
    /\ LET r == mem["o1"]
       IN IF r = NoRole
            THEN OnlyTx(p, Go(p, "g_invsnap"))
            ELSE MemTx(p, locks, "o1", NoRole,
                       [Go(p, "g_invsnap") EXCEPT !.has = (r = "owner" /\ MUTANT \notin TriggerOff)])

\* portfolio_invitations.invited_by ON DELETE SET NULL: the RI query's rows
\* (fresh snapshot), then row by row with EvalPlanQual.
GInvSnap(p) ==
    /\ tx[p].pc = "g_invsnap"
    /\ LET c == {j \in Inv : InvSeen(p, j).ex /\ InvSeen(p, j).by = "o1"}
       IN OnlyTx(p, [Go(p, IF c = {} THEN "g_trig" ELSE "g_inv") EXCEPT !.cand = c])

GInv(p) ==
    /\ tx[p].pc = "g_inv" /\ Blockers(p) = {}
    /\ LET j    == MinOf(tx[p].cand)
           v    == InvSeen(p, j)
           rest == tx[p].cand \ {j}
           r    == [Go(p, IF rest = {} THEN "g_trig" ELSE "g_inv") EXCEPT !.cand = rest]
       IN IF v.ex /\ v.by = "o1" THEN InvTx(p, j, [v EXCEPT !.by = NoUser], r) ELSE OnlyTx(p, r)

\* The queued portfolio_members_after_owner_ends fires now: if P exists, its
\* UPDATE (fresh snapshot) revokes the pending invitations whose invited_by
\* is o1 or NULL (M6, F4) -- after the SET NULL above, o1's own rows are NULL
\* now; in mutant no_null_inviter_revoke only rows still naming o1 (those
\* that committed in the meantime) -- then row by row (MTRevoke, then
\* g_commit).
GTrig(p) ==
    /\ tx[p].pc = "g_trig"
    /\ LET c   == {j \in Inv : TrigRow(InvSeen(p, j), "o1")}
           cnd == IF tx[p].has /\ PLive(p) THEN c ELSE {}
       IN OnlyTx(p, [Go(p, IF cnd = {} THEN "g_commit" ELSE "m_trevoke") EXCEPT !.cand = cnd])

GCommit(p) == tx[p].pc = "g_commit" /\ Commit(p, "ok", NoRole)

-----------------------------------------------------------------------------
(* public.accept_invitation(p_token)  [M6]                                 *)

\* Transaction start (now()); the token is one handed out by a committed
\* create.  auth.uid() check, private.enforce_rate_limit and the token
\* format checks are abstracted.
ABegin(p) ==
    /\ Kind(p) = "accept" /\ tx[p].pc = "idle" /\ issued # {}
    /\ \E j \in issued :
          OnlyTx(p, [Go(p, IF MUTANT = "no_account_freeze" THEN "a_lockp" ELSE "a_acct")
                     EXCEPT !.tok = j, !.time = clock])

\* perform private.require_active_account(v_uid):
\*   perform 1 from profiles where id = v_uid for key share;
\*   if exists (select 1 from private.account_deletions where user_id = v_uid)
\*     then app.fail('account_deleted')   (raise -> abort)
\* Merged into one step: the only writer of account_deletions
\* (admin_delete_account_data) takes FOR UPDATE on the profile first, so
\* while p holds key share no new row for v_uid can commit.
AAcct(p) ==
    /\ tx[p].pc = "a_acct" /\ Blockers(p) = {}
    /\ IF acct[Actor(p)]
         THEN Fail(p, "account_deleted")
         ELSE LockTx(p, Hold(p, Actor(p), "KS"), Go(p, "a_lockp"))

\* select i.portfolio_id into v_portfolio_id from portfolio_invitations i
\*   where i.id = v_selector;
\* if found then perform 1 from portfolios where id = v_portfolio_id for key share;
\* Merged: if the row was found but P was deleted before the lock, the lock
\* takes nothing and the row is gone too (cascade), exactly as if it had not
\* been found.
ALockP(p) ==
    /\ tx[p].pc = "a_lockp" /\ Blockers(p) = {}
    /\ LET keyed == InvSeen(p, tx[p].tok).ex /\ PLive(p) /\ MUTANT \notin NoKeyMutants
       IN LockTx(p, IF keyed THEN Hold(p, "P", "KS") ELSE locks, Go(p, "a_lock"))

\* select i.* into v_invitation from portfolio_invitations i
\*   where i.id = v_selector for update;
\* then the status checks in the code's order (each RETURNs, so the
\* transaction commits): invalid, revoked, accepted (idempotent for the
\* same user, reporting the member's current role, or 'revoked' when the
\* caller is no longer a member: M6, F2) / already_used, expired, the
\* inviter check, then the
\* auth.users read: email_not_verified, email_mismatch.
\* The inviter check: if v_invitation.invited_by is null or not exists
\*   (owner membership of invited_by in P) then
\*   update portfolio_invitations set revoked_at = now() where id = ...;
\*   return 'revoked'  (-> a_void).
\* Merged: the checks read the row p has just locked and memberships of P,
\* which nobody can change while p holds key share on P (if p holds none,
\* the row is gone and the result is 'invalid' anyway).
ALock(p) ==
    /\ tx[p].pc = "a_lock" /\ Blockers(p) = {}
    /\ LET j == tx[p].tok
           v == InvSeen(p, j)
           w == Actor(p)
           idemRole  == IF MUTANT # "stale_response_role" /\ MemSeen(p, w) # NoRole
                        THEN MemSeen(p, w) ELSE v.role
           \* the retry of a former member (F2): 'revoked' since M6
           exMember  == MemSeen(p, w) = NoRole
                        /\ MUTANT \notin {"stale_response_role", "removed_response_role"}
           inviterOk == \/ MUTANT \in InviterCheckOff
                        \/ v.by # NoUser /\ IsOwner(p, v.by)
       IN IF ~v.ex THEN Commit(p, "invalid", NoRole)
          ELSE IF v.rev /\ MUTANT \notin {"no_revoked_check", "no_revoked_protection"}
               THEN Commit(p, "revoked", NoRole)
          ELSE IF v.acc /\ MUTANT # "no_used_check"
               THEN IF v.accBy # w THEN Commit(p, "already_used", NoRole)
                    ELSE IF exMember THEN Commit(p, "revoked", NoRole)
                    ELSE Commit(p, "accepted", idemRole)
          ELSE IF v.exp <= tx[p].time /\ MUTANT # "no_expiry_check"
               THEN Commit(p, "expired", NoRole)
          ELSE IF ~inviterOk
               THEN IF MUTANT = "no_trigger_no_record"
                      THEN Commit(p, "revoked", NoRole)
                      ELSE InvTx(p, j, [v EXCEPT !.rev = TRUE], Go(p, "a_void"))
          ELSE IF ~Verified(w) /\ MUTANT # "no_verified_check"
               THEN Commit(p, "email_not_verified", NoRole)
          ELSE IF Email(w) # InvEmail /\ MUTANT # "no_email_check"
               THEN Commit(p, "email_mismatch", NoRole)
          ELSE IF MUTANT = "no_for_update"
               THEN OnlyTx(p, [Go(p, "a_member") EXCEPT !.role = v.role])
               ELSE InvTx(p, j, v, [Go(p, "a_member") EXCEPT !.role = v.role])

\* return jsonb_build_object('status', 'revoked') after recording revoked_at.
AVoid(p) == tx[p].pc = "a_void" /\ Commit(p, "revoked", NoRole)

\* select m.role into v_existing_role from portfolio_members m
\*   where m.portfolio_id = P and m.user_id = v_uid;  if not found then INSERT
AMember(p) ==
    /\ tx[p].pc = "a_member"
    /\ LET r == MemSeen(p, Actor(p))
       IN OnlyTx(p, [Go(p, IF r = NoRole \/ MUTANT = "upsert_role" THEN "a_insert" ELSE "a_update")
                     EXCEPT !.ex = r])

\* insert into portfolio_members (portfolio_id, user_id, role, invited_by)
\*   values (P, v_uid, v_invitation.role, v_invitation.invited_by)
\* Heap insert + portfolio_members_pkey check (wait for an in-progress
\* writer of the same key; 23505 if a committed row exists).
AInsert(p) ==
    /\ tx[p].pc = "a_insert" /\ Blockers(p) = {}
    /\ LET w    == Actor(p)
           role == IF MUTANT = "wrong_role" THEN "owner" ELSE tx[p].role
       IN IF MemSeen(p, w) # NoRole /\ MUTANT # "upsert_role"
            THEN Fail(p, "unique_violation")
            ELSE MemTx(p, locks, w, role, Go(p, "a_fk"))

\* ... end of the INSERT statement: RI_FKey_check_ins on portfolio_id takes
\* FOR KEY SHARE on P, the one on invited_by FOR KEY SHARE on the inviter's
\* auth.users row (23503 if either row is gone).  The FK check on user_id
\* (the caller's own auth row) and the audit trigger take no lock that a
\* modelled transaction contends for.
AFk(p) ==
    /\ tx[p].pc = "a_fk" /\ Blockers(p) = {}
    /\ IF MUTANT = "no_portfolio_guard" THEN OnlyTx(p, Go(p, "a_update"))
       ELSE IF ~PLive(p) \/ (AFkNeedsA(p) /\ gone) THEN Fail(p, "fk_violation")
       ELSE LockTx(p, AuthHold(p, AFkNeedsA(p), Hold(p, "P", "KS")), Go(p, "a_update"))

\* update portfolio_invitations set accepted_at = now(), accepted_by = v_uid
\*   where id = v_invitation.id
\* The row is already locked by our FOR UPDATE (except in mutant
\* no_for_update).  portfolio_invitations_terminal_state_check is evaluated on
\* the new version.  The AFTER UPDATE OF accepted_at trigger (M4) fires iff
\* OLD.accepted_at IS NULL.
AUpdate(p) ==
    /\ tx[p].pc = "a_update" /\ Blockers(p) = {}
    /\ LET j  == tx[p].tok
           v  == InvSeen(p, j)
           nv == [v EXCEPT !.acc = TRUE, !.accBy = Actor(p)]
       IN IF ~v.ex
            THEN \* only without FOR UPDATE: the row vanished, the UPDATE hits 0 rows
                 OnlyTx(p, Go(p, "a_commit"))
          ELSE IF nv.rev /\ MUTANT # "no_revoked_protection"
            THEN Fail(p, "check_violation")
          ELSE InvTx(p, j, nv,
                     [Go(p, IF ~v.acc /\ MUTANT # "no_notify_trigger" THEN "a_trigger" ELSE "a_commit")
                      EXCEPT !.acc = j])

\* M4 private.after_invitation_accepted: insert into notifications ... select
\* from portfolio_members where role = 'owner' and user_id <> accepted_by
\* on conflict (user_id, dedupe_key) do nothing.  Each inserted row's FK
\* checks take FOR KEY SHARE on P and on the notified owner's auth.users row.
ATrigger(p) ==
    /\ tx[p].pc = "a_trigger" /\ Blockers(p) = {}
    /\ IF ~TriggerInserts(p) \/ MUTANT = "no_portfolio_guard"
         THEN OnlyTx(p, Go(p, "a_commit"))
       ELSE IF ~PLive(p) \/ (ATrNeedsA(p) /\ gone) THEN Fail(p, "fk_violation")
       ELSE LockTx(p, AuthHold(p, ATrNeedsA(p), Hold(p, "P", "KS")), Go(p, "a_commit"))

\* return {'status': 'accepted', 'role': coalesce(v_existing_role, v_invitation.role)}
ACommit(p) ==
    /\ tx[p].pc = "a_commit"
    /\ Commit(p, "accepted", IF tx[p].ex # NoRole THEN tx[p].ex ELSE tx[p].role)

-----------------------------------------------------------------------------
(* Environment *)

HoldsSomething(p) ==
    \/ \E j \in Inv : invLock[j] = p
    \/ \E w \in Users : memW[w] = p \/ acctW[w] = p
    \/ pDel = p
    \/ \E l \in locks : l.t = p

\* Client disconnect / statement_timeout / 429: the transaction is rolled back.
\* Reduction: only transactions that hold a lock or an uncommitted write are
\* aborted; aborting one that holds nothing is indistinguishable from it
\* never being scheduled again.
EnvAbort(p) ==
    /\ tx[p].pc \notin {"idle", "done"}
    /\ HoldsSomething(p)
    /\ envAborts < MaxEnvAborts
    /\ Abort(p, "env_abort")
    /\ envAborts' = envAborts + 1

\* PostgreSQL deadlock detector: ERROR 40P01, the victim is rolled back.
DeadlockVictim(p) ==
    /\ tx[p].pc \notin {"idle", "done"}
    /\ InCycle(p)
    /\ Fail(p, "deadlock")

Tick ==
    /\ clock < MaxClock
    /\ clock' = clock + 1
    /\ UNCHANGED <<dbVars, tx, histVars>>

\* Nothing left to do (accept/revoke callers never received a token if no
\* create committed).  Stuttering only here keeps TLC's deadlock check
\* meaningful.
Quiescent ==
    \A p \in Procs : \/ tx[p].pc = "done"
                     \/ /\ tx[p].pc = "idle" /\ Kind(p) \in {"accept", "revoke"} /\ issued = {}
                        /\ \A c \in Procs : Kind(c) = "create" => tx[c].pc = "done"
                     \/ /\ p = "GA" /\ tx[p].pc = "idle"
                        /\ tx["ADO"].pc = "done" /\ tx["ADO"].out # "ok"
Terminating == Quiescent /\ UNCHANGED vars

-----------------------------------------------------------------------------
NoHist == [role |-> NoRole, by |-> NoUser, accN |-> 0, late |-> FALSE, rev |-> FALSE,
           notify |-> 0, voided |-> FALSE, revResp |-> FALSE]

Init ==
    /\ pStatus = "live"
    /\ pDel = NoP
    /\ locks = {}
    /\ inv = [j \in Inv |-> IF InitInv = 1 /\ j = 1 THEN Fresh("manager", "o1", TTL) ELSE Absent]
    /\ invLock = [j \in Inv |-> NoP]
    /\ invDirty = inv
    /\ mem = [w \in Users |-> CASE w = "o1" -> "owner"
                               [] w = "o2" -> IF SoleOwner THEN "manager" ELSE "owner"
                               [] OTHER    -> NoRole]
    /\ memW = [w \in Users |-> NoP]
    /\ memDirty = mem
    /\ acct = [w \in Users |-> FALSE]
    /\ acctW = [w \in Users |-> NoP]
    /\ gone = FALSE
    /\ nextInv = InitInv + 1
    /\ clock = 0
    /\ tx = [p \in Procs |-> Idle]
    /\ issued = IF InitInv = 1 THEN {1} ELSE {}
    /\ hist = [j \in Inv |-> IF InitInv = 1 /\ j = 1
                             THEN [NoHist EXCEPT !.role = "manager", !.by = "o1"]
                             ELSE NoHist]
    /\ flags = [badGrant |-> FALSE, roleChanged |-> FALSE, wrongGrant |-> FALSE,
                respBad |-> FALSE]
    /\ envAborts = 0

Step(p) ==
    \/ CBegin(p) \/ CLockP(p) \/ CLockE(p) \/ CMember(p) \/ CSnap(p) \/ CRevoke(p)
    \/ CInsert(p) \/ CFk(p) \/ CCommit(p)
    \/ RBegin(p) \/ RLockP(p) \/ RUpdate(p) \/ RCommit(p)
    \/ DBegin(p) \/ DLock(p) \/ DDelete(p) \/ DCascade(p) \/ DCommit(p)
    \/ MBegin(p) \/ MChange(p) \/ MTRevoke(p) \/ MCommit(p)
    \/ XBegin(p) \/ XLockP(p) \/ XCommit(p)
    \/ GBegin(p) \/ GPtf(p) \/ GMem(p) \/ GInvSnap(p) \/ GInv(p) \/ GTrig(p) \/ GCommit(p)
    \/ ABegin(p) \/ AAcct(p) \/ ALockP(p) \/ ALock(p) \/ AVoid(p) \/ AMember(p)
    \/ AInsert(p) \/ AFk(p) \/ AUpdate(p) \/ ATrigger(p) \/ ACommit(p)
    \/ EnvAbort(p) \/ DeadlockVictim(p)

Next == (\E p \in Procs : Step(p)) \/ Tick \/ Terminating

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Invariants *)

Version == [ex : BOOLEAN, role : Roles \cup {NoRole}, by : Users \cup {NoUser},
            exp : 0..(MaxClock + TTL), acc : BOOLEAN, accBy : Users \cup {NoUser},
            rev : BOOLEAN]

TypeOK ==
    /\ pStatus \in {"live", "deleted"}
    /\ pDel \in Procs \cup {NoP}
    /\ locks \subseteq [t : Procs, r : Res, m : {"KS", "NKU", "U", "X"}]
    /\ inv \in [Inv -> Version]
    /\ invDirty \in [Inv -> Version]
    /\ invLock \in [Inv -> Procs \cup {NoP}]
    /\ \A j \in Inv : invLock[j] = NoP => invDirty[j] = inv[j]
    /\ mem \in [Users -> Roles \cup {NoRole}]
    /\ memDirty \in [Users -> Roles \cup {NoRole}]
    /\ memW \in [Users -> Procs \cup {NoP}]
    /\ \A w \in Users : memW[w] = NoP => memDirty[w] = mem[w]
    /\ acct \in [Users -> BOOLEAN]
    /\ acctW \in [Users -> Procs \cup {NoP}]
    /\ gone \in BOOLEAN
    /\ nextInv \in 1..(MaxInv + 1)
    /\ clock \in 0..MaxClock
    /\ \A p \in Procs : tx[p].pc \in Labels
    /\ \A p \in Procs : tx[p].pc \in {"idle", "done"} =>
          /\ [tx[p] EXCEPT !.out = "none", !.resp = NoRole, !.pc = "idle"] = Idle
          /\ ~HoldsSomething(p)

\* (1) An invitation is accepted at most once.
AcceptedAtMostOnce == \A j \in Inv : hist[j].accN <= 1

\* (2) ... only by a user whose VERIFIED e-mail equals the invitation e-mail,
\*     and nobody else ever joins.
AcceptedOnlyByInvitee ==
    \A j \in Inv : inv[j].ex /\ inv[j].acc =>
        Verified(inv[j].accBy) /\ Email(inv[j].accBy) = InvEmail
OnlyInviteesJoin ==
    \A w \in {"u", "x", "y"} : mem[w] # NoRole => Verified(w) /\ Email(w) = InvEmail

\* (3) ... while unrevoked and unexpired (as of the accepting transaction's now()).
NeverAcceptedAfterRevoke == \A j \in Inv : ~(hist[j].rev /\ hist[j].accN > 0)
NeverAcceptedAfterExpiry == \A j \in Inv : ~hist[j].late

\* (4) The role granted never exceeds what the inviter could grant at the
\*     moment of acceptance (the accepting transaction's commit).
RoleWithinInviterAuthority == ~flags.badGrant

\* (5) Once the inviter stops being an owner, none of their invitations that
\*     were not accepted by then is ever accepted (even if they become an
\*     owner again) ...
InviterLossVoidsInvitations == \A j \in Inv : hist[j].voided => hist[j].accN = 0
\*     ... no pending invitation of a non-owner is left behind ...
NoPendingInvitationFromNonOwner ==
    \A j \in Inv : Pending(inv[j]) => inv[j].by # NoUser /\ mem[inv[j].by] = "owner"
\*     ... and once accept_invitation has answered 'revoked', the invitation
\*     can never be accepted afterwards (the revocation is recorded).
RevokedResponseIsFinal == \A j \in Inv : hist[j].revResp => hist[j].accN = 0

\* (6) At most one pending invitation per (portfolio, e-mail): what the
\*     partial unique index enforces (expired-but-pending rows count), and
\*     its weaker user-visible form (live = pending and unexpired).
AtMostOnePendingInvitation == Cardinality({j \in Inv : Pending(inv[j])}) <= 1
Live(j) == Pending(inv[j]) /\ inv[j].exp > clock
AtMostOneLiveInvitation == Cardinality({j \in Inv : Live(j)}) <= 1

\* (7) No membership exists for an account whose deletion has committed.
NoMembershipForDeletedAccount == \A w \in Users : acct[w] => mem[w] = NoRole

\* (8) A deleted portfolio leaves no invitations and no memberships.
DeletedPortfolioIsEmpty ==
    pStatus = "deleted" => /\ \A j \in Inv : ~inv[j].ex
                           /\ \A w \in Users : mem[w] = NoRole

\* (9) Accepting never changes an existing member's role, and a membership
\*     it creates has exactly the invitation's role.
AcceptNeverChangesRole == ~flags.roleChanged
GrantedRoleIsInvitationRole == ~flags.wrongGrant

\* (10) Owners are notified exactly once per accepted invitation.
OwnersNotifiedOncePerAcceptance ==
    \A j \in Inv : /\ hist[j].notify <= 1
                   /\ inv[j].ex /\ inv[j].acc => hist[j].notify = 1

\* (11) No unexpected database error (23505, 23503, 23514, 40P01) reaches a
\*      caller of accept_invitation / create_invitation / any modelled RPC.
\*      Environmental aborts and the app's own errors are expected.
AcceptNeverFailsUnexpectedly ==
    \A p \in Procs : Kind(p) = "accept" => tx[p].out \notin Unexpected
CreateNeverFailsUnexpectedly ==
    \A p \in Procs : Kind(p) = "create" => tx[p].out \notin Unexpected
NoRpcFailsUnexpectedly == \A p \in Procs : tx[p].out \notin Unexpected

\* (12) The role reported by a successful accept is the caller's actual role.
AcceptReportsActualRole == ~flags.respBad

\* Cross-checks with the executable tool/db/concurrency_test.sh (which passes
\* on the current code): the outcomes it asserts are the only ones the model
\* allows in the same situation.
\*   Scenario 10: an accept racing delete_portfolio either lands first or
\*   finds the invitation invalid (and no error).
AcceptOutcomesVsDeletion ==
    \A p \in Procs : Kind(p) = "accept" => tx[p].out \in {"none", "accepted", "invalid"}
\*   Scenario 14: an accept by an account whose deletion runs either lands
\*   before the deletion locks the profile or fails with account_deleted.
AcceptOutcomesVsAccountDeletion ==
    \A p \in Procs : Kind(p) = "accept" => tx[p].out \in {"none", "accepted", "account_deleted"}

=============================================================================
