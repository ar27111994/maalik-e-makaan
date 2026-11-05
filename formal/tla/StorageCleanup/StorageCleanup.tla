---------------------------- MODULE StorageCleanup ----------------------------
(***************************************************************************)
(* Documents, uploaded files and the durable storage cleanup queue in      *)
(* Maalik-e-Makaan, as the CURRENT code implements them.  "latest" means   *)
(* supabase/migrations/20261105072426_membership_deletion_storage.sql;     *)
(* "findings" means 20261105170557_concurrency_findings.sql: the file's   *)
(* storage.objects row, locked FOR KEY SHARE by the document insert's      *)
(* check (waiting) and FOR UPDATE by every delete (the policy's helper     *)
(* without waiting, the Storage API's own lock and every DELETE's row lock *)
(* waiting); the BEFORE DELETE trigger documents_objects_keep_referenced, *)
(* which, once the DELETE holds the row, re-reads documents and keeps a    *)
(* referenced file whoever deletes it; and one sweep gate, taken shared   *)
(* by the insert's check (waiting) and exclusively by the daily sweep      *)
(* (trying); each re-reads after its lock (findings S1, S2).               *)
(*                                                                         *)
(* Modelled (each action cites its code):                                  *)
(*  * an upload (Storage API INSERT into storage.objects as the user,      *)
(*    policy documents_objects_insert, 20261103194240);                    *)
(*  * a document INSERT: private.before_document_insert (authorise,        *)
(*    portfolio KEY SHARE, entity KEY SHARE), the row and its unique       *)
(*    storage_path, private.after_document_insert_check_file               *)
(*    (document_file_missing, document_file_pending_deletion), COMMIT;     *)
(*  * a document DELETE and its statement trigger                          *)
(*    private.after_documents_delete_queue_files;                          *)
(*  * a user's Storage delete in each way the Storage API has made it     *)
(*    (supabase/storage src/storage/object.ts): up to v1.80 a DELETE as   *)
(*    the user (a batch), or the row FOR UPDATE as superuser and then the  *)
(*    DELETE as the user (one object); from v1.81 the row FOR UPDATE, a    *)
(*    probe DELETE as the user in a savepoint that is always rolled back,  *)
(*    then the DELETE as superuser.  Policy documents_objects_delete       *)
(*    refuses an object a document row references; findings: or whose row *)
(*    a document insert holds.  Two deletes no policy sees: the probe flow *)
(*    without its row lock (no Storage API version does this: the window *)
(*    between the probe and the delete with nothing held), and a service-  *)
(*    role DELETE (an admin; the cleaner is modelled below);               *)
(*  * an entity DELETE and private.after_entity_delete_documents;          *)
(*  * a portfolio deletion (delete_locked_portfolios: cascade, then        *)
(*    private.after_portfolios_delete: retire the id, queue the folder);   *)
(*  * create_portfolio with a deleted portfolio's id (registry checks);    *)
(*  * the cleaner: supabase/functions/_shared/storage.ts                   *)
(*    drainStorageCleanup / cleanItem, driving admin_claim_storage_cleanup,*)
(*    admin_storage_cleanup_objects, the Storage API remove, and           *)
(*    admin_complete_storage_cleanup; pg_cron and request_storage_cleanup  *)
(*    start a run while something is due;                                  *)
(*  * the daily sweep private.enqueue_orphaned_storage (run by             *)
(*    private.cleanup), with private.delete_orphaned_documents.            *)
(*                                                                         *)
(* Granularity and isolation as in ../Membership/Membership.tla: one step  *)
(* per statement (a trigger runs inside its statement), READ COMMITTED     *)
(* snapshots, row locks as disabled steps, Need(t) the wait-for edges.     *)
(*                                                                         *)
(* Abstractions:                                                           *)
(*  * membership is reduced to "the portfolio exists": the uploader and    *)
(*    the client are members with the needed role while it exists (the    *)
(*    role rules are checked in ../Membership);                            *)
(*  * one entity (a tenant) per portfolio, files f1, f2 in P1 and f3 in P2;*)
(*  * time: not_before / claimed_until / created_at are not clocks.  A     *)
(*    queued item is "due" or waiting; Tick makes a waiting item due.  A   *)
(*    folder item is "ripe" once enqueued_at + 15 minutes has passed;      *)
(*    under UPLOAD_BOUND that moment comes only after every upload into    *)
(*    the folder that was authorised before has finished (the assumption   *)
(*    the 15-minute final sweep relies on).  A file "older than a day" is  *)
(*    given per scenario (OldFiles);                                       *)
(*  * a cleaner claims one item at a time here; the claim's ordering and   *)
(*    its exclusion of concurrent cleaners are checked in QueueFairness;   *)
(*  * a cleaner's claim lease (120 s) outlasts its time budget (25 s), so  *)
(*    only a crashed cleaner's claim lapses.                               *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANTS
    SCENARIO,        \* processes and initial data
    MUTANT,          \* "none" = current code; otherwise one mechanism removed
    UPLOAD_BOUND,    \* uploads in flight finish before a folder's 15-minute mark
    SWEEP,           \* the daily sweep runs (pg_cron -> run_daily_jobs -> cleanup)
    FAILURES         \* how many failure events may happen: a Storage API error, a
                     \* spent time budget, a cleaner crash (finite: failures are transient)

Mutants == {"none",
            "no_entity_lock",               \* before_document_insert: exists check, no lock
            "no_file_check",                \* no document_file_missing check
            "no_pending_check",             \* no document_file_pending_deletion check
            "no_delete_doc_check",          \* documents_objects_delete without "not exists documents"
            "listing_includes_referenced",  \* admin_storage_cleanup_objects lists referenced objects
            "no_prefix_queue",              \* after_portfolios_delete queues no folder
            "no_final_sweep",               \* a finished folder item is done at once
            "no_id_registry",               \* create_portfolio accepts a deleted id
            "entity_lock_first",            \* before_document_insert locks the entity, then the portfolio
            \* findings (each removes one use of a lock; S1 was found in the code
            \* without either row lock, S2 in the code without the gate)
            "no_insert_row_lock",           \* the document check reads storage.objects without
                                            \* locking (also what the advisory path lock of the
                                            \* first fix amounts to under the v1.81 probe, whose
                                            \* rollback releases the delete side's lock)
            "no_delete_row_lock",           \* the delete policy reads documents without locking
                                            \* the row (the statement's snapshot)
            "no_delete_trigger",            \* no BEFORE DELETE trigger on storage.objects
            "no_insert_gate",               \* the document check reads without the sweep gate
            "no_sweep_gate",                \* the sweep queues files without the gate
            \* a mechanism removed together with the trigger, which would
            \* otherwise keep the file the mechanism alone protects
            "no_delete_doc_check+no_trigger",
            "listing_includes_referenced+no_trigger",
            "no_delete_row_lock+no_trigger",
            "no_pending_check+no_trigger",
            "no_sweep_gate+no_trigger"}
ASSUME MUTANT \in Mutants
ASSUME {UPLOAD_BOUND, SWEEP} \subseteq BOOLEAN
ASSUME FAILURES \in Nat

NoTrigger == {"no_delete_trigger", "no_delete_doc_check+no_trigger",
              "listing_includes_referenced+no_trigger", "no_delete_row_lock+no_trigger",
              "no_pending_check+no_trigger", "no_sweep_gate+no_trigger"}
BaseMutant == CASE MUTANT = "no_delete_doc_check+no_trigger"         -> "no_delete_doc_check"
                [] MUTANT = "listing_includes_referenced+no_trigger" -> "listing_includes_referenced"
                [] MUTANT = "no_delete_row_lock+no_trigger"          -> "no_delete_row_lock"
                [] MUTANT = "no_pending_check+no_trigger"            -> "no_pending_check"
                [] MUTANT = "no_sweep_gate+no_trigger"               -> "no_sweep_gate"
                [] OTHER                                             -> MUTANT
Mut(m) == BaseMutant = m
Trigger   == MUTANT \notin NoTrigger
InsLock   == ~Mut("no_insert_row_lock")
DelLock   == ~Mut("no_delete_row_lock")
InsGate   == ~Mut("no_insert_gate")
SweepGate == ~Mut("no_sweep_gate")

Ports == {"P1", "P2"}
Ents  == {"T1", "T2"}
Files == {"f1", "f2", "f3"}
\* storage path <portfolio>/<entity type>/<entity id>/<file>
FolderOf(f) == IF f \in {"f1", "f2"} THEN "P1" ELSE "P2"
EntOf(f)    == IF FolderOf(f) = "P1" THEN "T1" ELSE "T2"
PortOfEnt(e) == IF e = "T1" THEN "P1" ELSE "P2"
\* queue items: a file path, or a folder prefix "<portfolio>/" (named by the portfolio)
Items == Files \cup Ports
IsPrefix(i) == i \in Ports
Covers(i, f) == IF IsPrefix(i) THEN FolderOf(f) = i ELSE f = i
NoP == "-"

-----------------------------------------------------------------------------
Pr(k, x) == [k |-> k, x |-> x]
Script(t) ==
    CASE t = "up2"    -> Pr("upload",   "f2")
      [] t = "att1"   -> Pr("attach",   "f1")
      [] t = "att2"   -> Pr("attach",   "f2")
      [] t = "det1"   -> Pr("detach",   "f1")
      [] t = "rm1"    -> Pr("rmfile",   "f1")     \* Storage API <= v1.80, a batch
      [] t = "rms1"   -> Pr("rmsingle", "f1")     \* Storage API <= v1.80, one object
      [] t = "rmp1"   -> Pr("rmprobe",  "f1")     \* Storage API >= v1.81
      [] t = "rmn1"   -> Pr("rmnolock", "f1")     \* the probe flow without its row lock
      [] t = "rmsv1"  -> Pr("rmservice", "f1")    \* a service-role DELETE
      [] t = "delT1"  -> Pr("delent",   "T1")
      [] t = "dpP1"   -> Pr("delport",  "P1")
      [] t = "rcP1"   -> Pr("recreate", "P1")
      [] t = "clean"  -> Pr("cleaner",  NoP)
      [] t = "clean2" -> Pr("cleaner",  NoP)
      [] t = "sweep"  -> Pr("sweep",    NoP)

\* <<processes, committed files, committed document rows, files older than a day, queued items>>
Scn(s) ==
    CASE s = "attach_vs_rmfile"    -> <<{"att1", "rm1"},                   {"f1"}, {},     {},     {}>>
      [] s = "attach_vs_rmsingle"  -> <<{"att1", "rms1"},                  {"f1"}, {},     {},     {}>>
      [] s = "attach_vs_rmprobe"   -> <<{"att1", "rmp1"},                  {"f1"}, {},     {},     {}>>
      [] s = "attach_vs_rm_clean"  -> <<{"att1", "rmp1", "clean"},         {"f1"}, {},     {"f1"}, {}>>
      [] s = "attach_vs_rmnolock"  -> <<{"att1", "rmn1"},                  {"f1"}, {},     {},     {}>>
      [] s = "attach_vs_rmservice" -> <<{"att1", "rmsv1"},                 {"f1"}, {},     {},     {}>>
      [] s = "service_guard"       -> <<{"rmsv1"},                         {"f1"}, {"f1"}, {},     {}>>
      [] s = "attach_vs_sweep"     -> <<{"att1", "clean"},                 {"f1"}, {},     {"f1"}, {}>>
      [] s = "reattach"            -> <<{"det1", "att1", "clean"},         {"f1"}, {"f1"}, {},     {}>>
      [] s = "entity_race"         -> <<{"att1", "delT1", "clean"},        {"f1"}, {},     {},     {}>>
      [] s = "attach_vs_delport"   -> <<{"att1", "dpP1"},                  {"f1"}, {},     {},     {}>>
      [] s = "port_delete"         -> <<{"dpP1", "up2", "att1", "clean"},  {"f1"}, {},     {},     {}>>
      [] s = "reuse"               -> <<{"dpP1", "rcP1", "up2", "clean"},  {"f1"}, {"f1"}, {},     {}>>
      [] s = "late_upload"         -> <<{"dpP1", "up2", "clean"},          {"f1"}, {"f1"}, {},     {}>>
      [] s = "file_missing"        -> <<{"att2"},                          {},     {},     {},     {}>>
      [] s = "delete_policy_guard" -> <<{"rm1"},                           {"f1"}, {"f1"}, {},     {}>>
      \* starts in a state the code before the findings migration reached
      \* (mut_no_sweep_gate): a document row and an 'orphaned' item for
      \* the same file
      [] s = "listing_guard"       -> <<{"clean"},                         {"f1"}, {"f1"}, {},     {"f1"}>>
      [] s = "two_cleaners"        -> <<{"dpP1", "clean", "clean2"},       {"f1", "f2"}, {"f1"}, {}, {}>>
      [] s = "mixed"               -> <<{"att2", "det1", "dpP1", "clean"}, {"f1", "f2"}, {"f1"}, {"f2"}, {}>>

Procs == Scn(SCENARIO)[1] \cup (IF SWEEP THEN {"sweep"} ELSE {})
OldFiles == Scn(SCENARIO)[4]
ProcsOrNo == Procs \cup {NoP}

VARIABLES db, pc, lv, gh
vars == <<db, pc, lv, gh>>

Kind(t) == Script(t).k
Arg(t)  == Script(t).x
Goto(t, l) == pc' = [pc EXCEPT ![t] = l]

-----------------------------------------------------------------------------
(* Views: committed rows plus t's own writes *)
PortV(t, q)  == IF db.pDel[q] = t THEN FALSE ELSE q \in db.port
EntV(t, e)   == IF db.eDel[e] = t THEN FALSE ELSE e \in db.ent
FileV(t, f)  == IF db.fDel[f] = t THEN FALSE ELSE IF db.fNew[f] = t THEN TRUE ELSE f \in db.files
DocV(t, f)   == IF db.dDel[f] = t THEN FALSE ELSE IF db.dNew[f] = t THEN TRUE ELSE f \in db.docs
QueuedV(t, i) == db.qp[i] \/ db.qNew[i] = t

(* Blockers *)
BX(t, q)   == ({db.pX[q]} \cup db.pKS[q]) \ {t, NoP}
BKS(t, q)  == {db.pX[q]} \ {t, NoP}
BPK(t, q)  == {db.pDel[q]} \ {t, NoP}
BEX(t, e)  == ({db.eX[e]} \cup db.eKS[e]) \ {t, NoP}
BEKS(t, e) == {db.eX[e]} \ {t, NoP}
BD(t, f)   == {db.dNew[f], db.dDel[f]} \ {t, NoP}     \* documents_storage_path_key / row lock
\* findings: the storage.objects row of a file.  KEY SHARE (the document
\* check) waits for FOR UPDATE or DELETE; FOR UPDATE and DELETE wait for
\* every other holder
BFKS(t, f) == {db.fX[f], db.fDel[f]} \ {t, NoP}
BFX(t, f)  == ({db.fX[f], db.fDel[f]} \cup db.fKS[f]) \ {t, NoP}
BQ(t, i)   == {db.qNew[i]} \ {t, NoP}                \* storage_cleanup_queue_item_key
BGS(t)     == {db.gx} \ {t, NoP}                     \* findings: the sweep gate, shared request

-----------------------------------------------------------------------------
Rel(f, t)  == [x \in DOMAIN f |-> IF f[x] = t THEN NoP ELSE f[x]]
RelS(f, t) == [x \in DOMAIN f |-> f[x] \ {t}]

ReleaseAll(d, t) ==
    [d EXCEPT !.pX = Rel(@, t), !.pKS = RelS(@, t), !.pDel = Rel(@, t),
              !.eX = Rel(@, t), !.eKS = RelS(@, t), !.eDel = Rel(@, t),
              !.fNew = Rel(@, t), !.fDel = Rel(@, t), !.fX = Rel(@, t), !.fKS = RelS(@, t),
              !.dNew = Rel(@, t), !.dDel = Rel(@, t),
              !.qNew = Rel(@, t), !.retire = Rel(@, t), !.pNew = Rel(@, t),
              !.gx = IF @ = t THEN NoP ELSE @, !.gs = @ \ {t}]

\* a newly queued item is due at once (not_before = now()); a folder item
\* becomes ripe 15 minutes after enqueued_at
Enqueue(d, i) == [d EXCEPT !.qp[i] = TRUE, !.qc[i] = NoP, !.qwait[i] = "none",
                           !.qripe[i] = ~IsPrefix(i)]

CommitDB(d, t) ==
    LET newQ == {i \in Items : d.qNew[i] = t /\ ~d.qp[i]}
        d1 == [d EXCEPT
                !.port  = ((@ \ {q \in Ports : d.pDel[q] = t}) \cup {q \in Ports : d.pNew[q] = t}),
                !.reg   = [q \in Ports |-> IF d.retire[q] = t THEN "retired"
                                           ELSE IF d.pNew[q] = t THEN "live" ELSE @[q]],
                !.ent   = @ \ {e \in Ents : d.eDel[e] = t},
                !.files = (@ \ {f \in Files : d.fDel[f] = t}) \cup {f \in Files : d.fNew[f] = t},
                !.docs  = (@ \ {f \in Files : d.dDel[f] = t}) \cup {f \in Files : d.dNew[f] = t}]
        d2 == [d1 EXCEPT !.qp    = [i \in Items |-> IF i \in newQ THEN TRUE ELSE @[i]],
                         !.qc    = [i \in Items |-> IF i \in newQ THEN NoP ELSE @[i]],
                         !.qwait = [i \in Items |-> IF i \in newQ THEN "none" ELSE @[i]],
                         !.qripe = [i \in Items |-> IF i \in newQ THEN ~IsPrefix(i) ELSE @[i]]]
    IN ReleaseAll(d2, t)

\* ghost bookkeeping at the COMMIT of t (d: the state with t's writes)
GhostCommit(d, t) ==
    [gh EXCEPT
        \* a file deleted while a committed document row referenced it
        !.liveDeleted = @ \/ \E f \in Files : d.fDel[f] = t /\ f \in d.docs /\ d.dDel[f] # t,
        !.everDeleted = @ \cup {q \in Ports : d.pDel[q] = t},
        !.reused = @ \/ \E q \in Ports : d.pNew[q] = t /\ q \in gh.everDeleted]

Commit(t, d, next) ==
    /\ db' = CommitDB(d, t)
    /\ gh' = GhostCommit(d, t)
    /\ Goto(t, next)

Abort(t, next) ==
    /\ db' = ReleaseAll(db, t)
    /\ Goto(t, next)
    /\ UNCHANGED gh

-----------------------------------------------------------------------------
(* Upload: the Storage API inserts storage.objects as the user; policy      *)
(* documents_objects_insert (statement snapshot) needs a role in the       *)
(* folder's portfolio.  Nothing locks the portfolio: an upload authorised   *)
(* before a deletion commits after it ("in flight").                       *)
U_Ins(t) ==
    /\ Kind(t) = "upload" /\ pc[t] = "u_ins"
    /\ LET f == Arg(t) IN
       IF PortV(t, FolderOf(f))
       THEN /\ db' = [db EXCEPT !.fNew[f] = t]
            /\ Goto(t, "u_commit")
            /\ UNCHANGED gh
       ELSE Abort(t, "done")                          \* new row violates row-level security
    /\ UNCHANGED lv

U_Commit(t) ==
    /\ Kind(t) = "upload" /\ pc[t] = "u_commit"
    /\ Commit(t, db, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* Document INSERT (latest).  BEFORE: authorise (has_portfolio_role), then *)
(* "perform 1 from portfolios ... for key share", then the entity "for key *)
(* share" (document_entity_not_found).  The row (unique storage_path).     *)
(* AFTER: the file exists (document_file_missing) and is not queued as a   *)
(* file or under its folder (document_file_pending_deletion).  COMMIT.     *)
\* (mutant "entity_lock_first": the entity is locked first, then the portfolio)
AfterPKS == IF Mut("entity_lock_first") THEN "a_ins" ELSE "a_eks"
AfterEKS == IF Mut("entity_lock_first") THEN "a_pks" ELSE "a_ins"
A_PKS(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_pks"
    /\ LET q == FolderOf(Arg(t)) IN
       IF ~PortV(t, q)
       THEN Abort(t, "done")                          \* forbidden
       ELSE /\ BKS(t, q) = {}
            /\ db' = [db EXCEPT !.pKS[q] = @ \cup {t}]
            /\ Goto(t, AfterPKS)
            /\ UNCHANGED gh
    /\ UNCHANGED lv

A_EKS(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_eks"
    /\ LET e == EntOf(Arg(t)) IN
       IF Mut("no_entity_lock")
       THEN IF EntV(t, e) THEN /\ Goto(t, "a_ins") /\ UNCHANGED <<db, gh>>
            ELSE Abort(t, "done")
       ELSE /\ IF EntV(t, e) THEN BEKS(t, e) = {} ELSE TRUE
            /\ IF EntV(t, e)
               THEN /\ db' = [db EXCEPT !.eKS[e] = @ \cup {t}]
                    /\ Goto(t, AfterEKS)
                    /\ UNCHANGED gh
               ELSE Abort(t, "done")                  \* document_entity_not_found
    /\ UNCHANGED lv

AfterIns == IF InsGate THEN "a_gate" ELSE IF InsLock THEN "a_fks" ELSE "a_after"
A_Ins(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_ins"
    /\ LET f == Arg(t) IN
       /\ BD(t, f) = {}
       /\ IF f \in db.docs
          THEN Abort(t, "done")                       \* unique violation
          ELSE /\ db' = [db EXCEPT !.dNew[f] = t]
               /\ Goto(t, AfterIns)
               /\ UNCHANGED gh
    /\ UNCHANGED lv

\* findings: private.lock_document_sweep_gate(false), i.e.
\* pg_advisory_xact_lock_shared: waits while the sweep holds the gate
A_Gate(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_gate"
    /\ BGS(t) = {}
    /\ db' = [db EXCEPT !.gs = @ \cup {t}]
    /\ Goto(t, IF InsLock THEN "a_fks" ELSE "a_after")
    /\ UNCHANGED <<lv, gh>>

\* findings: "select ... from storage.objects ... for key share" in
\* after_document_insert_check_file.  A committed row (or this transaction's
\* own) is locked; while another transaction holds it FOR UPDATE or is
\* deleting it, the statement waits, then reads the row's latest version:
\* once the delete has committed the row is not found.  An uncommitted
\* upload is invisible (not found).  document_file_missing (a_after) is then
\* this result: the file stays as it was found while the lock is held.
FileLockable(t, f) == f \in db.files \/ db.fNew[f] = t
A_FKS(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_fks"
    /\ LET f == Arg(t) IN
       /\ IF FileLockable(t, f) THEN BFKS(t, f) = {} ELSE TRUE
       /\ db' = IF FileLockable(t, f) THEN [db EXCEPT !.fKS[f] = @ \cup {t}] ELSE db
    /\ Goto(t, "a_after")
    /\ UNCHANGED <<lv, gh>>

PendingV(t, f) == QueuedV(t, f) \/ QueuedV(t, FolderOf(f))
A_After(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_after"
    /\ LET f == Arg(t) IN
       IF \/ ~FileV(t, f) /\ ~Mut("no_file_check")           \* document_file_missing
          \/ PendingV(t, f) /\ ~Mut("no_pending_check")      \* document_file_pending_deletion
       THEN Abort(t, "done")
       ELSE /\ Goto(t, "a_commit") /\ UNCHANGED <<db, gh>>
    /\ UNCHANGED lv

A_Commit(t) ==
    /\ Kind(t) = "attach" /\ pc[t] = "a_commit"
    /\ Commit(t, db, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* Document DELETE (row policy: owner or manager), then the statement      *)
(* trigger after_documents_delete_queue_files: queue the file if it exists *)
(* ("on conflict (bucket_id, path) do nothing"); COMMIT.                   *)
DetNeed(t) ==
    LET f == Arg(t) IN
    IF PortV(t, FolderOf(f)) /\ f \in db.docs
    THEN BD(t, f) \cup (IF f \in db.files /\ ~db.qp[f] THEN BQ(t, f) ELSE {})
    ELSE {}
X_Del(t) ==
    /\ Kind(t) = "detach" /\ pc[t] = "x_del"
    /\ DetNeed(t) = {}
    /\ LET f == Arg(t) IN
       IF ~(PortV(t, FolderOf(f)) /\ f \in db.docs)
       THEN Commit(t, db, "done")                     \* 0 rows
       ELSE /\ db' = [db EXCEPT !.dDel[f] = t,
                                !.qNew[f] = IF FileV(t, f) /\ ~db.qp[f] THEN t ELSE @]
            /\ Goto(t, "x_commit")
            /\ UNCHANGED gh
    /\ UNCHANGED lv

X_Commit(t) ==
    /\ Kind(t) = "detach" /\ pc[t] = "x_commit"
    /\ Commit(t, db, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* A user deletes an uploaded file through the Storage API, in each way it *)
(* has done so (supabase/storage src/storage/object.ts):                   *)
(*   rmfile   (<= v1.80, a batch remove) DELETE FROM storage.objects as the *)
(*            user under documents_objects_delete: r_lock, r_del;          *)
(*   rmsingle (<= v1.80, one object) the row FOR UPDATE as superuser       *)
(*            (r1_lock), then the same DELETE as the user;                 *)
(*   rmprobe  (>= v1.81) the row FOR UPDATE as superuser (rp_lock), the     *)
(*            user's DELETE in a savepoint that is always rolled back      *)
(*            (rp_probe: AccessDenied unless the policy lets it delete),   *)
(*            then the DELETE as superuser (rp_del); the rollback keeps     *)
(*            only the lock taken before the savepoint.                    *)
(* The policy: owner/manager of the folder's portfolio, and (findings)      *)
(* app.document_object_deletable: the row FOR UPDATE SKIP LOCKED (a row    *)
(* held by another transaction, e.g. a document insert's KEY SHARE, is     *)
(* refused; this transaction's own lock is returned at once), then no      *)
(* document row references the object, read with a fresh snapshot.        *)
(* Mutant "no_delete_row_lock": no lock; documents read with the           *)
(* statement's snapshot, and the DELETE's own row lock waits for a KEY     *)
(* SHARE holder and then deletes without asking the policy again (the code *)
(* S1 was found in).  A refused object is simply not deleted.              *)
RmAuth(t) == PortV(t, FolderOf(Arg(t)))
NoDocRef(t) == ~DocV(t, Arg(t)) \/ Mut("no_delete_doc_check")
\* findings: private.before_document_object_delete, the BEFORE DELETE row
\* trigger.  It runs in every DELETE of the row, after the DELETE holds the
\* row (each deleting step below first waits until no other transaction
\* holds it), and reads documents with a fresh snapshot: a referenced row is
\* skipped (kept, neither deleted nor returned).
Kept(t, f) == Trigger /\ DocV(t, f)

\* rmfile / rmsingle: the policy's row lock (r_lock), with DelLock
R_Lock(t) ==
    /\ Kind(t) \in {"rmfile", "rmsingle"} /\ pc[t] = "r_lock"
    /\ LET f == Arg(t) IN
       IF RmAuth(t) /\ f \in db.files /\ BFX(t, f) = {}
       THEN /\ db' = [db EXCEPT !.fX[f] = IF @ = NoP THEN t ELSE @]
            /\ Goto(t, "r_del")
            /\ UNCHANGED gh
       ELSE Commit(t, db, "done")                  \* not authorised, gone, or held: refused
    /\ UNCHANGED lv

\* rmfile / rmsingle: the documents check and the delete
R_Del(t) ==
    /\ Kind(t) \in {"rmfile", "rmsingle"} /\ pc[t] = "r_del"
    /\ LET f == Arg(t) IN
       IF RmAuth(t) /\ NoDocRef(t) /\ f \in db.files /\ ~Kept(t, f)
       THEN /\ db' = [db EXCEPT !.fDel[f] = t]
            /\ Goto(t, "r_commit")
            /\ UNCHANGED gh
       ELSE Commit(t, db, "done")                     \* nothing deleted
    /\ UNCHANGED lv

\* mutant no_delete_row_lock (rmfile): the policy with the statement snapshot ...
R_Pol(t) ==
    /\ Kind(t) = "rmfile" /\ pc[t] = "r_pol"
    /\ IF RmAuth(t) /\ NoDocRef(t) /\ Arg(t) \in db.files
       THEN /\ Goto(t, "r_rowdel") /\ UNCHANGED <<db, gh>>
       ELSE Commit(t, db, "done")
    /\ UNCHANGED lv

\* ... then the row lock of the DELETE, which waits for other holders and
\* deletes the row if it is still there, without asking the policy again
\* (only the trigger looks again)
R_RowDel(t) ==
    /\ Kind(t) = "rmfile" /\ pc[t] = "r_rowdel"
    /\ LET f == Arg(t) IN
       IF f \in db.files
       THEN /\ BFX(t, f) = {}
            /\ IF Kept(t, f)
               THEN Commit(t, db, "done")
               ELSE /\ db' = [db EXCEPT !.fDel[f] = t]
                    /\ Goto(t, "r_commit")
                    /\ UNCHANGED gh
       ELSE Commit(t, db, "done")
    /\ UNCHANGED lv

\* rmsingle: lockObjectForDelete-style row lock as superuser (waits)
R1_Lock(t) ==
    /\ Kind(t) = "rmsingle" /\ pc[t] = "r1_lock"
    /\ LET f == Arg(t) IN
       IF f \in db.files
       THEN /\ BFX(t, f) = {}
            /\ db' = [db EXCEPT !.fX[f] = t]
            /\ Goto(t, IF DelLock THEN "r_lock" ELSE "r_del")
            /\ UNCHANGED gh
       ELSE Commit(t, db, "done")                  \* NoSuchKey
    /\ UNCHANGED lv

\* rmprobe: the row lock as superuser (waits) ...
RP_Lock(t) ==
    /\ Kind(t) = "rmprobe" /\ pc[t] = "rp_lock"
    /\ LET f == Arg(t) IN
       IF f \in db.files
       THEN /\ BFX(t, f) = {}
            /\ db' = [db EXCEPT !.fX[f] = t]
            /\ Goto(t, "rp_probe")
            /\ UNCHANGED gh
       ELSE Commit(t, db, "done")                  \* NoSuchKey
    /\ UNCHANGED lv

\* ... the probe: the policy as the user, in a savepoint that is rolled back
\* (its lock is this transaction's own, so it adds nothing to keep) ...
RP_Probe(t) ==
    /\ Kind(t) = "rmprobe" /\ pc[t] = "rp_probe"
    /\ IF RmAuth(t) /\ NoDocRef(t)
       THEN /\ Goto(t, "rp_del") /\ UNCHANGED <<db, gh>>
       ELSE Abort(t, "done")                       \* AccessDenied: rolled back
    /\ UNCHANGED lv

\* ... and the DELETE as superuser (row security does not apply; the
\* trigger does: a kept row is not returned, and the Storage API answers
\* AccessDenied and rolls back)
RP_Del(t) ==
    /\ Kind(t) = "rmprobe" /\ pc[t] = "rp_del"
    /\ IF Kept(t, Arg(t))
       THEN Abort(t, "done")
       ELSE /\ db' = [db EXCEPT !.fDel[Arg(t)] = t]
            /\ Goto(t, "r_commit")
            /\ UNCHANGED gh
    /\ UNCHANGED lv

\* rmnolock: the probe as in rmprobe but without the row lock first: the
\* policy's own lock (SKIP LOCKED: refused while another transaction holds
\* the row) ends with the savepoint, so nothing is held afterwards ...
RN_Probe(t) ==
    /\ Kind(t) = "rmnolock" /\ pc[t] = "rn_probe"
    /\ LET f == Arg(t) IN
       IF RmAuth(t) /\ NoDocRef(t) /\ f \in db.files /\ (DelLock => BFX(t, f) = {})
       THEN /\ Goto(t, "rn_del") /\ UNCHANGED <<db, gh>>
       ELSE Abort(t, "done")                       \* AccessDenied (or NoSuchKey)
    /\ UNCHANGED lv

\* ... then the DELETE as superuser: its row lock waits for any holder (a
\* document insert's KEY SHARE), then the trigger looks again
RN_Del(t) ==
    /\ Kind(t) = "rmnolock" /\ pc[t] = "rn_del"
    /\ LET f == Arg(t) IN
       IF f \in db.files
       THEN /\ BFX(t, f) = {}
            /\ IF Kept(t, f)
               THEN Abort(t, "done")
               ELSE /\ db' = [db EXCEPT !.fDel[f] = t]
                    /\ Goto(t, "r_commit")
                    /\ UNCHANGED gh
       ELSE Abort(t, "done")                       \* nothing deleted: AccessDenied
    /\ UNCHANGED lv

\* rmservice: one DELETE as the service role (row security bypassed): its
\* row lock waits for any holder, then the trigger looks
SV_Del(t) ==
    /\ Kind(t) = "rmservice" /\ pc[t] = "sv_del"
    /\ LET f == Arg(t) IN
       IF f \in db.files
       THEN /\ BFX(t, f) = {}
            /\ IF Kept(t, f)
               THEN Commit(t, db, "done")
               ELSE /\ db' = [db EXCEPT !.fDel[f] = t]
                    /\ Goto(t, "r_commit")
                    /\ UNCHANGED gh
       ELSE Commit(t, db, "done")
    /\ UNCHANGED lv

R_Commit(t) ==
    /\ Kind(t) \in {"rmfile", "rmsingle", "rmprobe", "rmnolock", "rmservice"} /\ pc[t] = "r_commit"
    /\ Commit(t, db, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* Entity DELETE (a tenant): row lock X, then the statement trigger        *)
(* private.after_entity_delete_documents deletes its document rows, whose  *)
(* statement trigger queues their existing files; COMMIT.                  *)
E_Del(t) ==
    /\ Kind(t) = "delent" /\ pc[t] = "e_del"
    /\ LET e == Arg(t) IN
       IF ~(PortV(t, PortOfEnt(e)) /\ e \in db.ent)
       THEN Commit(t, db, "done")                     \* 0 rows
       ELSE /\ BEX(t, e) = {}
            /\ db' = [db EXCEPT !.eX[e] = t, !.eDel[e] = t]
            /\ Goto(t, "e_docs")
            /\ UNCHANGED gh
    /\ UNCHANGED lv

EntDocs(t) == {f \in db.docs : EntOf(f) = Arg(t)}
EDocsNeed(t) == UNION {BD(t, f) : f \in EntDocs(t)}
                \cup UNION {BQ(t, f) : f \in {g \in EntDocs(t) : g \in db.files /\ ~db.qp[g]}}
E_Docs(t) ==
    /\ Kind(t) = "delent" /\ pc[t] = "e_docs"
    /\ EDocsNeed(t) = {}
    /\ LET D == EntDocs(t) IN
       db' = [db EXCEPT !.dDel = [f \in Files |-> IF f \in D THEN t ELSE @[f]],
                        !.qNew = [i \in Items |-> IF i \in D /\ FileV(t, i) /\ ~db.qp[i] THEN t ELSE @[i]]]
    /\ Goto(t, "e_commit")
    /\ UNCHANGED <<lv, gh>>

E_Commit(t) ==
    /\ Kind(t) = "delent" /\ pc[t] = "e_commit"
    /\ Commit(t, db, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* Portfolio deletion (delete_portfolio / admin_delete_account_data, the   *)
(* lock-and-delete step; its deadlock retry is in ../Membership):          *)
(* lock_portfolios_for_deletion, then delete_locked_portfolios: ON DELETE  *)
(* CASCADE removes the entity and the document rows (their trigger queues  *)
(* existing files); private.after_portfolios_delete retires the id and     *)
(* queues "<id>/"; COMMIT.                                                 *)
P_Lock(t) ==
    /\ Kind(t) = "delport" /\ pc[t] = "p_lock"
    /\ LET q == Arg(t) IN
       IF q \notin db.port
       THEN Commit(t, db, "done")
       ELSE /\ BX(t, q) = {}
            /\ db' = [db EXCEPT !.pX[q] = t]
            /\ Goto(t, "p_del")
            /\ UNCHANGED gh
    /\ UNCHANGED lv

PDocs(t) == {f \in db.docs : FolderOf(f) = Arg(t)}
PNeed(t) ==
    LET q == Arg(t) e == IF q = "P1" THEN "T1" ELSE "T2" IN
    (IF e \in db.ent THEN BEX(t, e) ELSE {})
    \cup UNION {BD(t, f) : f \in PDocs(t)}
    \cup UNION {BQ(t, f) : f \in {g \in PDocs(t) : g \in db.files /\ ~db.qp[g]}}
    \cup (IF ~Mut("no_prefix_queue") /\ ~db.qp[q] THEN BQ(t, q) ELSE {})
P_Del(t) ==
    /\ Kind(t) = "delport" /\ pc[t] = "p_del"
    /\ PNeed(t) = {}
    /\ LET q == Arg(t)
           e == IF q = "P1" THEN "T1" ELSE "T2"
           D == PDocs(t)
           d1 == [db EXCEPT
                    !.pDel[q] = t, !.retire[q] = t,
                    !.eX[e] = IF e \in db.ent THEN t ELSE @, !.eDel[e] = IF e \in db.ent THEN t ELSE @,
                    !.dDel = [f \in Files |-> IF f \in D THEN t ELSE @[f]],
                    !.qNew = [i \in Items |->
                                IF \/ i \in D /\ FileV(t, i) /\ ~db.qp[i]
                                   \/ i = q /\ ~Mut("no_prefix_queue") /\ ~db.qp[i]
                                THEN t ELSE @[i]]]
       IN Commit(t, d1, "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* create_portfolio(name, p_id = q) by another user (latest): an existing   *)
(* id is refused; "exists (select 1 from private.portfolio_ids where id =  *)
(* p_id)" -> forbid; the insert (unique id) and its registry trigger.      *)
K_Check(t) ==
    /\ Kind(t) = "recreate" /\ pc[t] = "k_check"
    /\ LET q == Arg(t) IN
       IF PortV(t, q) \/ (db.reg[q] # "none" /\ ~Mut("no_id_registry"))
       THEN Abort(t, "done")
       ELSE /\ Goto(t, "k_ins") /\ UNCHANGED <<db, gh>>
    /\ UNCHANGED lv

K_Ins(t) ==
    /\ Kind(t) = "recreate" /\ pc[t] = "k_ins"
    /\ LET q == Arg(t) IN
       /\ BPK(t, q) = {}
       /\ IF q \in db.port \/ (db.reg[q] # "none" /\ ~Mut("no_id_registry"))
          THEN Abort(t, "done")
          ELSE Commit(t, [db EXCEPT !.pNew[q] = t], "done")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
(* The cleaner (storage.ts drainStorageCleanup).  c_idle: pg_cron runs     *)
(* request_storage_cleanup every 10 minutes, which starts a run only when  *)
(* an item is due and unclaimed.  A run claims, lists, removes, completes  *)
(* and claims again until nothing is due or its time budget is spent.      *)
Claimable(i) == db.qp[i] /\ db.qc[i] = NoP /\ db.qwait[i] = "none"
IsCleaner(t) == Kind(t) = "cleaner"

C_Idle(t) ==
    /\ IsCleaner(t) /\ pc[t] = "c_idle"
    /\ \E i \in Items : Claimable(i)
    /\ Goto(t, "c_claim")
    /\ UNCHANGED <<db, lv, gh>>

\* admin_claim_storage_cleanup (one item per claim in this model)
C_Claim(t) ==
    /\ IsCleaner(t) /\ pc[t] = "c_claim"
    /\ IF \E i \in Items : Claimable(i)
       THEN \E i \in {j \in Items : Claimable(j)} :
              /\ db' = [db EXCEPT !.qc[i] = t]
              /\ lv' = [lv EXCEPT ![t] = [cur |-> i, listed |-> {}, outcome |-> "none"]]
              /\ Goto(t, "c_list")
       ELSE /\ Goto(t, "c_idle")                       \* "items.length === 0: break"
            /\ UNCHANGED <<db, lv>>
    /\ UNCHANGED gh

\* admin_storage_cleanup_objects(item): committed objects of the item that no
\* committed document row references (one statement snapshot); an item that
\* is gone lists nothing
Listing(i) == IF ~db.qp[i] THEN {}
              ELSE {f \in db.files : Covers(i, f) /\ (f \notin db.docs \/ Mut("listing_includes_referenced"))}
C_List(t) ==
    /\ IsCleaner(t) /\ pc[t] = "c_list"
    /\ LET L == Listing(lv[t].cur) IN
       IF L = {}
       THEN /\ lv' = [lv EXCEPT ![t].outcome = "finished"]
            /\ Goto(t, "c_complete")
       ELSE /\ lv' = [lv EXCEPT ![t].listed = L]
            /\ Goto(t, "c_remove")
    /\ UNCHANGED <<db, gh>>

\* admin.storage.from(bucket).remove(names): the service role deletes the rows
\* (row policies do not apply to it; the rows' locks still do: it waits for a
\* document insert's KEY SHARE; and so does the trigger, which keeps a file
\* a document references) and the files; COMMIT.
C_RemoveOk(t) ==
    /\ IsCleaner(t) /\ pc[t] = "c_remove"
    /\ UNION {BFX(t, f) : f \in lv[t].listed} = {}
    /\ LET gone == {f \in lv[t].listed \cap db.files : ~Kept(t, f)} IN
       /\ db' = [db EXCEPT !.files = @ \ gone]
       /\ gh' = [gh EXCEPT !.liveDeleted = @ \/ gone \cap db.docs # {}]
    /\ lv' = [lv EXCEPT ![t].listed = {}]
    /\ Goto(t, "c_list")

\* the Storage API fails: the item is reported with an error
Fail == /\ gh.failures < FAILURES
        /\ gh' = [gh EXCEPT !.failures = @ + 1]
C_RemoveErr(t) ==
    /\ IsCleaner(t) /\ pc[t] = "c_remove"
    /\ Fail
    /\ lv' = [lv EXCEPT ![t].outcome = "error"]
    /\ Goto(t, "c_complete")
    /\ UNCHANGED db

\* the time budget runs out mid-item ("finished: false, error: null")
C_Deadline(t) ==
    /\ IsCleaner(t) /\ pc[t] \in {"c_list", "c_remove"}
    /\ Fail
    /\ lv' = [lv EXCEPT ![t].outcome = "unfinished"]
    /\ Goto(t, "c_complete")
    /\ UNCHANGED db

\* admin_complete_storage_cleanup(item, finished, error) (latest)
C_Complete(t) ==
    /\ IsCleaner(t) /\ pc[t] = "c_complete"
    /\ LET i == lv[t].cur  o == lv[t].outcome IN
       db' = IF ~db.qp[i] THEN db                              \* 'missing'
             ELSE CASE o = "error" ->                          \* backoff, 'retry'
                         [db EXCEPT !.qc[i] = NoP, !.qwait[i] = "later"]
                    [] o = "finished" /\ (~IsPrefix(i) \/ db.qripe[i] \/ Mut("no_final_sweep")) ->
                         [db EXCEPT !.qp[i] = FALSE, !.qc[i] = NoP]   \* 'done'
                    [] o = "finished" ->                       \* swept again at enqueued_at + 15 min
                         [db EXCEPT !.qc[i] = NoP, !.qwait[i] = "ripe"]
                    [] OTHER ->                                \* due again at once
                         [db EXCEPT !.qc[i] = NoP, !.qwait[i] = "none"]
    \* the run claims again, or its budget is spent
    /\ \E nxt \in {"c_claim", "c_idle"} : Goto(t, nxt)
    /\ lv' = [lv EXCEPT ![t] = [cur |-> NoP, listed |-> {}, outcome |-> "none"]]
    /\ UNCHANGED gh

\* the Edge Function dies (or an RPC fails and the run stops): its claim stays
C_Crash(t) ==
    /\ IsCleaner(t) /\ pc[t] \in {"c_list", "c_remove", "c_complete"}
    /\ Fail
    /\ Goto(t, "c_idle")
    /\ lv' = [lv EXCEPT ![t] = [cur |-> NoP, listed |-> {}, outcome |-> "none"]]
    /\ UNCHANGED db

\* claimed_until passes for a claim nobody works on: claimable again
Lapse(i) ==
    /\ db.qp[i] /\ db.qc[i] # NoP
    /\ LET h == db.qc[i] IN pc[h] \notin {"c_list", "c_remove", "c_complete"} \/ lv[h].cur # i
    /\ db' = [db EXCEPT !.qc[i] = NoP]
    /\ UNCHANGED <<pc, lv, gh>>

-----------------------------------------------------------------------------
(* Time.  Ripen(q): enqueued_at + 15 minutes has passed for the folder     *)
(* item q.  admin_complete_storage_cleanup compares the time of the        *)
(* COMPLETION with that mark, while the cleaner's last (empty) listing     *)
(* came a moment (delta: one RPC round trip) earlier.  UPLOAD_BOUND is the *)
(* assumption the 15-minute final sweep relies on: an upload authorised   *)
(* before the folder was queued commits at least delta before the mark.   *)
(* So the mark never passes while such an upload is in flight, nor between *)
(* a finished listing that a late upload made stale and its completion.   *)
(* Due(i): an item waiting after an error becomes due.                    *)
InFlightInto(q) == \E t \in Procs : Kind(t) = "upload" /\ pc[t] = "u_commit" /\ FolderOf(Arg(t)) = q
StaleListing(q) ==
    \E t \in Procs : IsCleaner(t) /\ pc[t] = "c_complete" /\ lv[t].cur = q
                     /\ lv[t].outcome = "finished" /\ Listing(q) # {}
Ripen(q) ==
    /\ db.qp[q] /\ ~db.qripe[q]
    /\ UPLOAD_BOUND => ~InFlightInto(q) /\ ~StaleListing(q)
    /\ db' = [db EXCEPT !.qripe[q] = TRUE, !.qwait[q] = IF @ = "ripe" THEN "none" ELSE @]
    /\ UNCHANGED <<pc, lv, gh>>
Due(i) ==
    /\ db.qp[i] /\ db.qwait[i] = "later"
    /\ db' = [db EXCEPT !.qwait[i] = "none"]
    /\ UNCHANGED <<pc, lv, gh>>

-----------------------------------------------------------------------------
(* The daily sweep (private.cleanup -> enqueue_orphaned_storage), one      *)
(* transaction, run again every day:                                       *)
(*  s_docs:    delete_orphaned_documents (rows whose entity is gone; their *)
(*             trigger queues existing files);                             *)
(*  s_folders: folders whose portfolio does not exist are retired and      *)
(*             queued ('orphaned');                                        *)
(*  s_files:   files older than a day with no document row are queued.    *)
(*  findings: s_gate tries the sweep gate exclusively                      *)
(*  (pg_try_advisory_xact_lock, up to 20 times): while a document insert   *)
(*  holds it shared the sweep cannot take it, and leaves the files for the *)
(*  next sweep (the failed tries change nothing, so one step stands for    *)
(*  them: a later success is the same step taken later); s_files then      *)
(*  re-reads documents with a fresh snapshot.  One lock, however many      *)
(*  files.  Mutant "no_sweep_gate": no gate (the code S2 was found in).    *)
OrphanDocs == {f \in db.docs : EntOf(f) \notin db.ent}
SDocsNeed(t) == UNION {BD(t, f) : f \in OrphanDocs}
                \cup UNION {BQ(t, f) : f \in {g \in OrphanDocs : g \in db.files /\ ~db.qp[g]}}
S_Idle(t) ==
    /\ Kind(t) = "sweep" /\ pc[t] = "s_idle"
    /\ Goto(t, "s_docs")
    /\ UNCHANGED <<db, lv, gh>>

S_Docs(t) ==
    /\ Kind(t) = "sweep" /\ pc[t] = "s_docs"
    /\ SDocsNeed(t) = {}
    /\ LET D == OrphanDocs IN
       db' = [db EXCEPT !.dDel = [f \in Files |-> IF f \in D THEN t ELSE @[f]],
                        !.qNew = [i \in Items |-> IF i \in D /\ FileV(t, i) /\ ~db.qp[i] THEN t ELSE @[i]]]
    /\ Goto(t, "s_folders")
    /\ UNCHANGED <<lv, gh>>

OrphanFolders(t) == {FolderOf(f) : f \in {g \in Files : FileV(t, g)}} \ {q \in Ports : PortV(t, q)}
S_Folders(t) ==
    /\ Kind(t) = "sweep" /\ pc[t] = "s_folders"
    /\ UNION {BQ(t, q) : q \in {p \in OrphanFolders(t) : ~db.qp[p]}} = {}
    /\ LET F == OrphanFolders(t) IN
       db' = [db EXCEPT !.retire = [q \in Ports |-> IF q \in F /\ db.reg[q] = "none" THEN t ELSE @[q]],
                        !.qNew = [i \in Items |-> IF i \in F /\ ~db.qp[i] THEN t ELSE @[i]]]
    /\ Goto(t, IF SweepGate THEN "s_gate" ELSE "s_files")
    /\ UNCHANGED <<lv, gh>>

S_Gate(t) ==
    /\ Kind(t) = "sweep" /\ pc[t] = "s_gate"
    /\ IF db.gs \ {t} = {} /\ db.gx \in {NoP, t}
       THEN /\ db' = [db EXCEPT !.gx = t]
            /\ Goto(t, "s_files")
       ELSE /\ Goto(t, "s_commit")                   \* busy: the files wait a day
            /\ UNCHANGED db
    /\ UNCHANGED <<lv, gh>>

OrphanFiles(t) == {f \in OldFiles : FileV(t, f) /\ ~DocV(t, f)}
S_Files(t) ==
    /\ Kind(t) = "sweep" /\ pc[t] = "s_files"
    /\ LET F == OrphanFiles(t) IN
       /\ UNION {BQ(t, f) : f \in {g \in F : ~db.qp[g]}} = {}
       /\ db' = [db EXCEPT !.qNew = [i \in Items |-> IF i \in F /\ ~db.qp[i] THEN t ELSE @[i]]]
    /\ Goto(t, "s_commit")
    /\ UNCHANGED <<lv, gh>>

S_Commit(t) ==
    /\ Kind(t) = "sweep" /\ pc[t] = "s_commit"
    /\ Commit(t, db, "s_idle")
    /\ UNCHANGED lv

-----------------------------------------------------------------------------
Need(t) ==
    LET x == Arg(t) IN
    CASE pc[t] = "a_pks" -> IF PortV(t, FolderOf(x)) THEN BKS(t, FolderOf(x)) ELSE {}
      [] pc[t] = "a_eks" -> IF ~Mut("no_entity_lock") /\ EntV(t, EntOf(x)) THEN BEKS(t, EntOf(x)) ELSE {}
      [] pc[t] = "a_ins" -> BD(t, x)
      [] pc[t] = "a_gate" -> BGS(t)                \* the only wait for the gate
      [] pc[t] = "a_fks" -> IF FileLockable(t, x) THEN BFKS(t, x) ELSE {}
      [] pc[t] = "x_del" -> DetNeed(t)
      [] pc[t] = "r_rowdel" -> IF x \in db.files THEN BFX(t, x) ELSE {}
      [] pc[t] \in {"r1_lock", "rp_lock", "rn_del", "sv_del"} -> IF x \in db.files THEN BFX(t, x) ELSE {}
      [] pc[t] = "e_del" -> IF PortV(t, PortOfEnt(x)) /\ x \in db.ent THEN BEX(t, x) ELSE {}
      [] pc[t] = "e_docs" -> EDocsNeed(t)
      [] pc[t] = "p_lock" -> IF x \in db.port THEN BX(t, x) ELSE {}
      [] pc[t] = "p_del" -> PNeed(t)
      [] pc[t] = "k_ins" -> BPK(t, x)
      [] pc[t] = "c_remove" -> UNION {BFX(t, f) : f \in lv[t].listed}
      [] pc[t] = "s_docs" -> SDocsNeed(t)
      [] pc[t] = "s_folders" -> UNION {BQ(t, q) : q \in {p \in OrphanFolders(t) : ~db.qp[p]}}
      [] pc[t] = "s_files" -> UNION {BQ(t, f) : f \in {g \in OrphanFiles(t) : ~db.qp[g]}}
      [] OTHER -> {}

RECURSIVE ReachN(_, _)
ReachN(S, n) == IF n = 0 THEN S ELSE ReachN(S \cup UNION {Need(s) : s \in S}, n - 1)
OnCycle(t) == t \in ReachN(Need(t), Cardinality(Procs))

-----------------------------------------------------------------------------
StartPC(t) ==
    CASE Kind(t) = "upload"   -> "u_ins"
      [] Kind(t) = "attach"   -> IF Mut("entity_lock_first") THEN "a_eks" ELSE "a_pks"
      [] Kind(t) = "detach"   -> "x_del"
      [] Kind(t) = "rmfile"   -> IF DelLock THEN "r_lock" ELSE "r_pol"
      [] Kind(t) = "rmsingle" -> "r1_lock"
      [] Kind(t) = "rmprobe"  -> "rp_lock"
      [] Kind(t) = "rmnolock" -> "rn_probe"
      [] Kind(t) = "rmservice" -> "sv_del"
      [] Kind(t) = "delent"   -> "e_del"
      [] Kind(t) = "delport"  -> "p_lock"
      [] Kind(t) = "recreate" -> "k_check"
      [] Kind(t) = "cleaner"  -> "c_idle"
      [] Kind(t) = "sweep"    -> "s_idle"

InitQueue == Scn(SCENARIO)[5]
Init ==
    /\ db = [port |-> Ports, reg |-> [q \in Ports |-> "live"], ent |-> Ents,
             files |-> Scn(SCENARIO)[2], docs |-> Scn(SCENARIO)[3],
             pX |-> [q \in Ports |-> NoP], pKS |-> [q \in Ports |-> {}],
             pDel |-> [q \in Ports |-> NoP], pNew |-> [q \in Ports |-> NoP],
             retire |-> [q \in Ports |-> NoP],
             eX |-> [e \in Ents |-> NoP], eKS |-> [e \in Ents |-> {}], eDel |-> [e \in Ents |-> NoP],
             fNew |-> [f \in Files |-> NoP], fDel |-> [f \in Files |-> NoP],
             dNew |-> [f \in Files |-> NoP], dDel |-> [f \in Files |-> NoP],
             fX |-> [f \in Files |-> NoP], fKS |-> [f \in Files |-> {}], gx |-> NoP, gs |-> {},
             qp |-> [i \in Items |-> i \in InitQueue], qNew |-> [i \in Items |-> NoP],
             qc |-> [i \in Items |-> NoP], qwait |-> [i \in Items |-> "none"],
             qripe |-> [i \in Items |-> ~IsPrefix(i)]]
    /\ pc = [t \in Procs |-> StartPC(t)]
    /\ lv = [t \in Procs |-> [cur |-> NoP, listed |-> {}, outcome |-> "none"]]
    /\ gh = [liveDeleted |-> FALSE, everDeleted |-> {}, reused |-> FALSE, failures |-> 0]

Step(t) ==
    \/ U_Ins(t) \/ U_Commit(t)
    \/ A_PKS(t) \/ A_EKS(t) \/ A_Ins(t) \/ A_Gate(t) \/ A_FKS(t) \/ A_After(t) \/ A_Commit(t)
    \/ X_Del(t) \/ X_Commit(t)
    \/ R_Lock(t) \/ R_Del(t) \/ R_Pol(t) \/ R_RowDel(t) \/ R1_Lock(t)
    \/ RP_Lock(t) \/ RP_Probe(t) \/ RP_Del(t) \/ RN_Probe(t) \/ RN_Del(t) \/ SV_Del(t)
    \/ R_Commit(t)
    \/ E_Del(t) \/ E_Docs(t) \/ E_Commit(t)
    \/ P_Lock(t) \/ P_Del(t)
    \/ K_Check(t) \/ K_Ins(t)
    \/ C_Idle(t) \/ C_Claim(t) \/ C_List(t) \/ C_RemoveOk(t) \/ C_Complete(t)
    \/ S_Idle(t) \/ S_Docs(t) \/ S_Folders(t) \/ S_Gate(t) \/ S_Files(t) \/ S_Commit(t)

Failure(t) == C_RemoveErr(t) \/ C_Deadline(t) \/ C_Crash(t)
Env == (\E q \in Ports : Ripen(q)) \/ (\E i \in Items : Due(i) \/ Lapse(i))

\* Every request finished and the background jobs idle: nothing to do.
Quiescent == \A t \in Procs : pc[t] \in {"done", "c_idle", "s_idle"}

Next == (\E t \in Procs : Step(t) \/ Failure(t)) \/ Env \/ (Quiescent /\ UNCHANGED vars)

Spec == Init /\ [][Next]_vars

\* The cleaner and the sweep run again and again (pg_cron), time passes, and
\* every request runs; failures are finitely many (FAILURES).
LiveSpec ==
    /\ Spec
    /\ \A t \in Procs : WF_vars(Step(t))
    /\ \A q \in Ports : WF_vars(Ripen(q))
    /\ \A i \in Items : WF_vars(Due(i)) /\ WF_vars(Lapse(i))

-----------------------------------------------------------------------------
(* PROPERTIES *)
TypeOK ==
    /\ db.port \subseteq Ports /\ db.files \subseteq Files /\ db.docs \subseteq Files
    /\ db.qp \in [Items -> BOOLEAN] /\ db.qc \in [Items -> ProcsOrNo]
    /\ db.qwait \in [Items -> {"none", "later", "ripe"}]
    /\ db.gx \in ProcsOrNo /\ db.gs \subseteq Procs
    /\ db.fX \in [Files -> ProcsOrNo] /\ \A f \in Files : db.fKS[f] \subseteq Procs

(* No document row references a file that does not exist. *)
NoDanglingDocument == \A f \in db.docs : f \in db.files

(* No document row references a file queued for deletion (as a file or    *)
(* under its folder): the intent of document_file_pending_deletion.        *)
NoDocForQueuedFile == \A f \in db.docs : ~db.qp[f] /\ ~db.qp[FolderOf(f)]

(* No file is deleted while a committed document row references it. *)
NoLiveFileDeleted == ~gh.liveDeleted

(* No document row outlives its entity. *)
NoOrphanDocument == \A f \in db.docs : EntOf(f) \in db.ent

(* Every file of a portfolio that no longer exists waits in the queue      *)
(* under its folder (relies on UPLOAD_BOUND; see the late_upload configs). *)
DeletedFoldersQueued == \A f \in db.files : FolderOf(f) \in db.port \/ db.qp[FolderOf(f)]

(* A folder queued for deletion never belongs to a live portfolio, and a   *)
(* deleted portfolio's id never comes back (single-use ids).               *)
NoLiveFolderQueued ==
    /\ \A q \in Ports : db.qp[q] => q \notin db.port
    /\ ~gh.reused

(* No wait-for cycle. *)
NoWaitCycle == \A t \in Procs : ~OnCycle(t)

(* Sanity of the model: a finished or idle process holds no lock and no   *)
(* uncommitted write.                                                      *)
NoLeakedLocks ==
    \A t \in Procs : pc[t] \in {"done", "c_idle", "s_idle"} =>
        /\ \A q \in Ports : db.pX[q] # t /\ t \notin db.pKS[q] /\ db.pDel[q] # t
                           /\ db.pNew[q] # t /\ db.retire[q] # t
        /\ \A e \in Ents : db.eX[e] # t /\ t \notin db.eKS[e] /\ db.eDel[e] # t
        /\ \A f \in Files : db.fNew[f] # t /\ db.fDel[f] # t /\ db.dNew[f] # t
                           /\ db.dDel[f] # t /\ db.fX[f] # t /\ t \notin db.fKS[f]
        /\ \A i \in Items : db.qNew[i] # t
        /\ db.gx # t /\ t \notin db.gs

(* Liveness: once the deletions are done and the queue drains, no file is  *)
(* left in a deleted portfolio's folder, and the queue stays empty.        *)
EventuallyClean == <>[](\A f \in db.files : FolderOf(f) \in db.port)
EventuallyDrained == <>[](\A i \in Items : ~db.qp[i])
(* ... and no document row outlives its entity for ever (the daily sweep's *)
(* delete_orphaned_documents repairs rows written before inserts locked    *)
(* their entity).                                                          *)
EventuallyNoOrphanDocument == <>[](\A f \in db.docs : EntOf(f) \in db.ent)

=============================================================================
