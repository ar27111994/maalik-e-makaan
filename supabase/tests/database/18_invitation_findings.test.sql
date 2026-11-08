-- Invitation findings (20261108082804_invitation_findings.sql;
-- formal/tla/Invitations F1-F4):
--   F1  create_invitation serialises re-invites of one (portfolio, e-mail)
--       with an advisory lock after the portfolio key; a re-invite replaces
--       the pending invitation (the concurrent case is scenario 30 of
--       tool/db/concurrency_test.sh);
--   F2  a retried accept_invitation reports the role the caller holds, and
--       answers revoked to a caller who is no longer a member;
--   F3  the documented order (admin_delete_account_data, then the Auth
--       delete) leaves nothing pending; no trigger was added to auth.users;
--   F4  deleting an inviter directly in Auth revokes their pending
--       invitations, and the membership trigger revokes pending invitations
--       without an inviter.
begin;
\ir _helpers.psql
select plan(36);

select tests.create_user('owner1@example.com') as owner1 \gset
select tests.create_user('owner2@example.com') as owner2 \gset
select tests.create_user('guest@example.com') as guest \gset
select tests.create_portfolio(:'owner1') as pid \gset
select tests.add_member(:'pid', :'owner2', 'owner');

-- ---------------------------------------------------------------------------
-- The shape of the fixes
-- ---------------------------------------------------------------------------

select ok(
  (select p.prosecdef and coalesce(p.proconfig @> array['search_path=""'], false)
   from pg_proc p where p.oid = 'public.create_invitation(uuid, text, public.member_role)'::regprocedure)
  and (select p.prosecdef and coalesce(p.proconfig @> array['search_path=""'], false)
       from pg_proc p where p.oid = 'public.accept_invitation(text)'::regprocedure)
  and (select p.prosecdef and coalesce(p.proconfig @> array['search_path=""'], false)
       from pg_proc p where p.oid = 'private.after_owner_membership_ends()'::regprocedure),
  'create_invitation, accept_invitation and after_owner_membership_ends are SECURITY DEFINER with an empty search_path'
);
select ok(
  has_function_privilege('authenticated', 'public.create_invitation(uuid, text, public.member_role)', 'execute')
  and has_function_privilege('authenticated', 'public.accept_invitation(text)', 'execute')
  and not has_function_privilege('anon', 'public.create_invitation(uuid, text, public.member_role)', 'execute')
  and not has_function_privilege('anon', 'public.accept_invitation(text)', 'execute')
  and not has_function_privilege('authenticated', 'private.after_owner_membership_ends()', 'execute')
  and not exists (
    select 1 from pg_proc p cross join lateral aclexplode(p.proacl) a
    where p.oid in ('public.create_invitation(uuid, text, public.member_role)'::regprocedure,
                    'public.accept_invitation(text)'::regprocedure,
                    'private.after_owner_membership_ends()'::regprocedure)
      and a.grantee = 0
  ),
  'the invitation RPCs are executable by authenticated only; the trigger function by nobody'
);
select ok(
  obj_description('public.create_invitation(uuid, text, public.member_role)'::regprocedure, 'pg_proc') is not null
  and obj_description('public.accept_invitation(text)'::regprocedure, 'pg_proc') is not null
  and obj_description('private.after_owner_membership_ends()'::regprocedure, 'pg_proc') is not null,
  'the three functions are documented'
);
select ok(
  (select position('pg_advisory_xact_lock(' in p.prosrc) > position('private.lock_portfolio_for_change(' in p.prosrc)
      and position('private.lock_portfolio_for_change(' in p.prosrc) > 0
      and position('pg_advisory_xact_lock(' in p.prosrc) < position('update public.portfolio_invitations' in p.prosrc)
   from pg_proc p where p.oid = 'public.create_invitation(uuid, text, public.member_role)'::regprocedure),
  'F1: create_invitation takes the advisory lock after the portfolio key and before it revokes or inserts'
);
select ok(
  (select position('i.invited_by is null' in p.prosrc) > 0
   from pg_proc p where p.oid = 'private.after_owner_membership_ends()'::regprocedure),
  'F4: the membership trigger also matches invitations without an inviter'
);
select is(
  (select count(*)::integer from pg_trigger t
   where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
     and (t.tgtype & 8) <> 0  -- a DELETE trigger
     and (t.tgtype & 2) <> 0),  -- BEFORE
  0,
  'F3: no BEFORE DELETE trigger on auth.users (it would lock the portfolio after the auth row)'
);

-- ---------------------------------------------------------------------------
-- F1: re-invites of one e-mail are serialised and replace each other
-- ---------------------------------------------------------------------------

select tests.authenticate_as(:'owner1');
select public.create_invitation(:'pid', '  Guest@Example.com ', 'manager') as inv1 \gset
select tests.clear_authentication();

select ok(
  exists (
    select 1
    from pg_locks l,
         lateral (select ('x' || encode(substr(sha256(convert_to(
                            'invitation:' || :'pid' || ':guest@example.com', 'UTF8')), 1, 8), 'hex'))::bit(64)::bigint as k) h
    where l.locktype = 'advisory' and l.pid = pg_backend_pid() and l.granted
      and l.mode = 'ExclusiveLock' and l.objsubid = 1
      and l.classid::bigint = ((h.k >> 32) & 4294967295)
      and l.objid::bigint = (h.k & 4294967295)
  ),
  'F1: create_invitation holds the advisory lock of (portfolio, normalised e-mail) until the transaction ends'
);
select ok(
  (select position('hashtext' in p.prosrc) = 0 and position('sha256(convert_to(''invitation:''' in p.prosrc) > 0
   from pg_proc p where p.oid = 'public.create_invitation(uuid, text, public.member_role)'::regprocedure),
  'F1: the advisory-lock key comes from SHA-256, not from PostgreSQL''s text hash (no chosen collisions)'
);

select tests.authenticate_as(:'owner2');
select public.create_invitation(:'pid', 'guest@example.com', 'viewer') as inv2 \gset
select tests.clear_authentication();

select is(
  (select array_agg(i.role::text order by i.created_at, i.id) from public.portfolio_invitations i
   where i.portfolio_id = :'pid' and i.accepted_at is null and i.revoked_at is null),
  array['viewer'],
  'F1: a second owner''s re-invite replaces the pending invitation (one pending, the later one)'
);
select ok(
  (select revoked_at is not null from public.portfolio_invitations
   where id = ((:'inv1')::jsonb ->> 'invitation_id')::uuid),
  'F1: the replaced invitation is revoked'
);

select tests.authenticate_as(:'guest');
select is(
  public.accept_invitation((:'inv1')::jsonb ->> 'token') ->> 'status', 'revoked',
  'F1: the replaced token is refused as revoked'
);
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- F2: a retried acceptance reports the member's role
-- ---------------------------------------------------------------------------

-- The guest joins as a manager another way (the state a re-invite racing an
-- acceptance leaves) while the viewer invitation is still pending.
select tests.add_member(:'pid', :'guest', 'manager');

select tests.authenticate_as(:'guest');
select public.accept_invitation((:'inv2')::jsonb ->> 'token') as acc1 \gset
select is((:'acc1')::jsonb ->> 'status', 'accepted', 'F2: the invitation is accepted');
select is((:'acc1')::jsonb ->> 'role', 'manager', 'F2: the first answer reports the existing role');
select is(
  public.accept_invitation((:'inv2')::jsonb ->> 'token') - 'portfolio_id',
  jsonb_build_object('status', 'accepted', 'role', 'manager'),
  'F2: a retry reports the role the member has (manager), not the invitation''s (viewer)'
);
select is(
  public.accept_invitation((:'inv2')::jsonb ->> 'token') ->> 'portfolio_id', :'pid',
  'F2: a retry still names the portfolio'
);
select tests.clear_authentication();
select is(
  (select role::text from public.portfolio_members where portfolio_id = :'pid' and user_id = :'guest'),
  'manager',
  'F2: accepting never changed the member''s role'
);

select tests.authenticate_as(:'owner1');
select public.update_member_role(:'pid', :'guest', 'accountant');
select tests.authenticate_as(:'guest');
select is(
  public.accept_invitation((:'inv2')::jsonb ->> 'token') ->> 'role', 'accountant',
  'F2: a retry after a role change reports the new role'
);
select tests.authenticate_as(:'owner1');
select public.remove_member(:'pid', :'guest');
select tests.authenticate_as(:'guest');
select is(
  public.accept_invitation((:'inv2')::jsonb ->> 'token'),
  jsonb_build_object('status', 'revoked'),
  'F2: a retry by a member removed since answers revoked (no role they do not hold, no portfolio)'
);
select tests.clear_authentication();
select is(
  (select count(*)::integer from public.portfolio_members where portfolio_id = :'pid' and user_id = :'guest'),
  0,
  'F2: the refused retry did not add the former member back'
);
select ok(
  (select accepted_at is not null and accepted_by = :'guest'::uuid and revoked_at is null
   from public.portfolio_invitations where id = ((:'inv2')::jsonb ->> 'invitation_id')::uuid),
  'F2: and the invitation stays accepted (nothing is written)'
);

-- Someone who left on their own is a former member too; once they are a
-- member again (another way), a retry reports their role once more.
select tests.add_member(:'pid', :'guest', 'viewer');
select tests.authenticate_as(:'guest');
select public.remove_member(:'pid', :'guest');
select is(
  public.accept_invitation((:'inv2')::jsonb ->> 'token') ->> 'status', 'revoked',
  'F2: a retry by a member who left answers revoked'
);
select tests.clear_authentication();
select tests.add_member(:'pid', :'guest', 'accountant');
select tests.authenticate_as(:'guest');
select is(
  public.accept_invitation((:'inv2')::jsonb ->> 'token') - 'portfolio_id',
  jsonb_build_object('status', 'accepted', 'role', 'accountant'),
  'F2: a retry by a member who has rejoined reports the role they hold now'
);
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- F4: an inviter deleted directly in Auth leaves nothing pending
-- ---------------------------------------------------------------------------

select tests.create_user('inviter@example.com') as inviter \gset
select tests.create_user('cohost@example.com') as cohost \gset
select tests.create_user('visitor@example.com') as visitor \gset
select tests.create_portfolio(:'cohost', 'Direct deletion') as pid4 \gset
select tests.add_member(:'pid4', :'inviter', 'owner');
select tests.create_portfolio(:'cohost', 'Untouched') as other4 \gset

select tests.authenticate_as(:'inviter');
select public.create_invitation(:'pid4', 'visitor@example.com', 'viewer') as inv4 \gset
select tests.clear_authentication();

-- What GoTrue's admin delete (dashboard, Auth admin API) does.
delete from auth.users where id = :'inviter';

select is(
  (select invited_by from public.portfolio_invitations
   where id = ((:'inv4')::jsonb ->> 'invitation_id')::uuid),
  null::uuid,
  'F4: the deletion cleared invited_by (ON DELETE SET NULL)'
);
select ok(
  (select revoked_at is not null and accepted_at is null from public.portfolio_invitations
   where id = ((:'inv4')::jsonb ->> 'invitation_id')::uuid),
  'F4: and the deleted inviter''s invitation is revoked, not left pending'
);
select tests.authenticate_as(:'visitor');
select is(
  public.accept_invitation((:'inv4')::jsonb ->> 'token') ->> 'status', 'revoked',
  'F4: accept_invitation answers revoked'
);
select tests.clear_authentication();
select is(
  (select count(*)::integer from public.portfolio_members where portfolio_id = :'pid4' and user_id = :'visitor'),
  0,
  'F4: the visitor did not join'
);

-- Pending invitations without an inviter (left by a direct deletion before
-- this fix) are revoked when any owner's ownership in that portfolio ends;
-- other owners' invitations and other portfolios are untouched.
select tests.create_user('third@example.com') as third \gset
select tests.add_member(:'pid4', :'third', 'owner');
insert into public.portfolio_invitations (portfolio_id, email, role, verifier_hash, invited_by, expires_at)
values (:'pid4', 'orphan@example.com', 'viewer', sha256('orphan'::bytea), null, now() + interval '7 days')
returning id as orphan \gset
insert into public.portfolio_invitations (portfolio_id, email, role, verifier_hash, invited_by, expires_at)
values (:'other4', 'orphan@example.com', 'viewer', sha256('other'::bytea), null, now() + interval '7 days')
returning id as orphan_other \gset
select tests.authenticate_as(:'cohost');
select public.create_invitation(:'pid4', 'kept@example.com', 'viewer') as kept \gset
select tests.authenticate_as(:'third');
select public.create_invitation(:'pid4', 'third-guest@example.com', 'viewer') as third_inv \gset
select tests.authenticate_as(:'cohost');
select public.update_member_role(:'pid4', :'third', 'viewer');
select tests.clear_authentication();

select ok(
  (select revoked_at is not null from public.portfolio_invitations where id = :'orphan'),
  'F4: an ownership ending revokes the portfolio''s pending invitations without an inviter'
);
select ok(
  (select revoked_at is not null from public.portfolio_invitations
   where id = ((:'third_inv')::jsonb ->> 'invitation_id')::uuid),
  'the demoted owner''s own invitation is revoked (as before)'
);
select ok(
  (select revoked_at is null from public.portfolio_invitations
   where id = ((:'kept')::jsonb ->> 'invitation_id')::uuid),
  'another owner''s invitation stays pending'
);
select ok(
  (select revoked_at is null from public.portfolio_invitations where id = :'orphan_other'),
  'invitations of other portfolios are untouched'
);

-- Promoting someone to owner is not an ownership ending.
insert into public.portfolio_invitations (portfolio_id, email, role, verifier_hash, invited_by, expires_at)
values (:'pid4', 'orphan2@example.com', 'viewer', sha256('orphan2'::bytea), null, now() + interval '7 days')
returning id as orphan2 \gset
select tests.authenticate_as(:'cohost');
select public.update_member_role(:'pid4', :'third', 'owner');
select tests.clear_authentication();
select ok(
  (select revoked_at is null from public.portfolio_invitations where id = :'orphan2'),
  'a promotion to owner revokes nothing'
);

-- An accepted invitation whose inviter is gone keeps its acceptance.
select tests.create_user('kept-member@example.com') as kept_member \gset
select tests.create_user('leaving@example.com') as leaving \gset
select tests.add_member(:'pid4', :'leaving', 'owner');
select tests.authenticate_as(:'leaving');
select public.create_invitation(:'pid4', 'kept-member@example.com', 'accountant') as inv_kept \gset
select tests.authenticate_as(:'kept_member');
select is(
  public.accept_invitation((:'inv_kept')::jsonb ->> 'token') ->> 'status', 'accepted',
  'an invitation accepted before its inviter is deleted ...'
);
select tests.clear_authentication();
delete from auth.users where id = :'leaving';
select ok(
  (select accepted_at is not null and revoked_at is null from public.portfolio_invitations
   where id = ((:'inv_kept')::jsonb ->> 'invitation_id')::uuid)
  and exists (select 1 from public.portfolio_members
              where portfolio_id = :'pid4' and user_id = :'kept_member' and role = 'accountant'),
  '... stays accepted, and the member stays'
);

-- ---------------------------------------------------------------------------
-- F3: the documented order (delete-account) leaves nothing pending either
-- ---------------------------------------------------------------------------

select tests.create_user('documented@example.com') as documented \gset
select tests.add_member(:'pid4', :'documented', 'owner');
select tests.authenticate_as(:'documented');
select public.create_invitation(:'pid4', 'late@example.com', 'manager') as inv3 \gset
select tests.authenticate_as_service_role();
select public.admin_delete_account_data(:'documented') as deleted3 \gset
select tests.clear_authentication();
select ok(
  (select revoked_at is not null and invited_by = :'documented'::uuid from public.portfolio_invitations
   where id = ((:'inv3')::jsonb ->> 'invitation_id')::uuid),
  'F3: admin_delete_account_data revokes the inviter''s pending invitation before the Auth delete'
);
delete from auth.users where id = :'documented';
select ok(
  (select revoked_at is not null and invited_by is null from public.portfolio_invitations
   where id = ((:'inv3')::jsonb ->> 'invitation_id')::uuid),
  'F3: the Auth delete afterwards only clears invited_by'
);
select is(
  (select count(*)::integer from public.portfolio_invitations i
   where i.accepted_at is null and i.revoked_at is null
     and (i.invited_by is null or not exists (
       select 1 from public.portfolio_members m
       where m.portfolio_id = i.portfolio_id and m.user_id = i.invited_by and m.role = 'owner'))
     and i.id <> all (array[:'orphan_other', :'orphan2']::uuid[])),
  0,
  'no pending invitation is left whose inviter is gone or no longer an owner (apart from the two inserted by hand)'
);

select * from finish();
rollback;
