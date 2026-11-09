-- Profiles, portfolios, memberships and invitations.
begin;
\ir _helpers.psql
select plan(49);

-- Arrange ------------------------------------------------------------------
select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('second.owner@example.com') as owner2 \gset
select tests.create_user('manager@example.com') as manager \gset
select tests.create_user('outsider@example.com') as outsider \gset
select tests.create_user('unverified@example.com', false) as unverified \gset

-- Profiles -----------------------------------------------------------------
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values ('11111111-1111-4111-8111-000000000001', 'MixedCase@Example.COM', now(),
        jsonb_build_object('full_name', '  Ayesha   ' || chr(9) || 'Siddiqui  ', 'locale', 'ur'));
select results_eq(
  $$select email, full_name, locale from public.profiles where id = '11111111-1111-4111-8111-000000000001'$$,
  $$values ('mixedcase@example.com'::text, 'Ayesha Siddiqui'::text, 'ur'::text)$$,
  'profiles are created from auth users with a normalised e-mail and cleaned name'
);

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values ('11111111-1111-4111-8111-000000000002', 'spoof@example.com', now(),
        jsonb_build_object('full_name', 'Ali' || chr(8238) || 'nahK'));
select is(
  (select full_name from public.profiles where id = '11111111-1111-4111-8111-000000000002'),
  '',
  'names carrying bidi overrides are dropped instead of failing sign-up'
);

update auth.users set email = 'renamed@example.com' where id = '11111111-1111-4111-8111-000000000001';
select is(
  (select email from public.profiles where id = '11111111-1111-4111-8111-000000000001'),
  'renamed@example.com',
  'e-mail changes propagate to the profile'
);

-- Portfolios ---------------------------------------------------------------
select tests.authenticate_as(:'owner');
select lives_ok(
  $$select public.create_portfolio('Gulberg Homes', '01a1a2c0-0000-7000-8000-000000000001')$$,
  'a signed-in user can create a portfolio'
);
select is(
  (select role::text from public.portfolio_members where portfolio_id = '01a1a2c0-0000-7000-8000-000000000001'),
  'owner',
  'the creator becomes the owner'
);
select is(
  (public.create_portfolio('Gulberg Homes', '01a1a2c0-0000-7000-8000-000000000001')).name,
  'Gulberg Homes',
  'create_portfolio is idempotent for a client-supplied id'
);
select is((select count(*)::integer from public.portfolios), 1, 'retries did not create duplicates');
select throws_ok(
  $$select public.create_portfolio('   ')$$, '23514', null,
  'blank portfolio names are rejected'
);
select throws_ok(
  $$select public.create_portfolio('Bad' || chr(8238) || 'Name')$$, '23514', null,
  'portfolio names with bidi overrides are rejected'
);

\set pid '01a1a2c0-0000-7000-8000-000000000001'

select tests.authenticate_as(:'outsider');
select is((select count(*)::integer from public.portfolios), 0, 'outsiders cannot see the portfolio');
select throws_ok(
  $$select public.create_portfolio('Hijack', '01a1a2c0-0000-7000-8000-000000000001')$$, '42501', 'forbidden',
  'a client-supplied id owned by someone else is rejected'
);
select is_empty(
  $$update public.portfolios set name = 'Hacked' where id = '01a1a2c0-0000-7000-8000-000000000001' returning id$$,
  'outsiders cannot update the portfolio'
);

-- Owner settings and column-level grants.
select tests.authenticate_as(:'owner');
select lives_ok(
  $$update public.portfolios set raast_id = '+923001234567', bank_iban = 'PK36SCBL0000001123456702'
    where id = '01a1a2c0-0000-7000-8000-000000000001'$$,
  'owners update payment details'
);
select throws_ok(
  $$update public.portfolios set bank_iban = 'PK24MEZN0001234567890123'
    where id = '01a1a2c0-0000-7000-8000-000000000001'$$,
  '23514', null,
  'IBANs with a bad checksum are rejected by the database'
);
select throws_ok(
  $$update public.portfolios set created_by = '00000000-0000-0000-0000-000000000000'
    where id = '01a1a2c0-0000-7000-8000-000000000001'$$,
  '42501', null,
  'created_by is not updatable by clients'
);

-- Invitations --------------------------------------------------------------
select public.create_invitation(:'pid', '  Manager@Example.com ', 'manager') as invite \gset
select ok((:'invite')::jsonb ->> 'token' ~ '^[0-9a-f-]{36}\.[A-Za-z0-9_-]{43}$', 'tokens are selector.verifier');
select is((:'invite')::jsonb ->> 'email', 'manager@example.com', 'invitation e-mails are normalised');
select throws_ok(
  $$select verifier_hash from public.portfolio_invitations$$, '42501', null,
  'owners cannot read verifier hashes either'
);

select public.create_invitation(:'pid', 'manager@example.com', 'viewer') as reinvite \gset
select is(
  (select count(*)::integer from public.portfolio_invitations where email = 'manager@example.com' and revoked_at is null),
  1,
  're-inviting the same e-mail replaces the pending invitation'
);

select tests.authenticate_as(:'manager');
select is(
  public.accept_invitation((:'invite')::jsonb ->> 'token') ->> 'status', 'revoked',
  'a replaced invitation can no longer be used'
);
select is(public.accept_invitation('not-a-token') ->> 'status', 'invalid', 'malformed tokens are invalid');
select is(
  public.accept_invitation(
    split_part((:'reinvite')::jsonb ->> 'token', '.', 1) || '.' || repeat('A', 43)
  ) ->> 'status',
  'invalid',
  'a wrong verifier for a real selector is invalid'
);

select tests.authenticate_as(:'outsider');
select is(
  public.accept_invitation((:'reinvite')::jsonb ->> 'token') ->> 'status', 'email_mismatch',
  'only the invited e-mail can accept'
);

select tests.authenticate_as(:'manager');
select is(
  public.accept_invitation((:'reinvite')::jsonb ->> 'token') ->> 'status', 'accepted',
  'the invited user accepts'
);
select is(
  (select role::text from public.portfolio_members where user_id = :'manager'),
  'viewer',
  'membership uses the role from the invitation'
);
select is(
  public.accept_invitation((:'reinvite')::jsonb ->> 'token') ->> 'status', 'accepted',
  'accepting twice is idempotent for the same user'
);
select is((select count(*)::integer from public.profiles), 2, 'members see their own and teammates'' profiles only');

select tests.authenticate_as(:'outsider');
select is(
  public.accept_invitation((:'reinvite')::jsonb ->> 'token') ->> 'status', 'already_used',
  'a used invitation cannot be reused by someone else'
);

-- Unverified e-mail and expiry.
select tests.authenticate_as(:'owner');
select public.create_invitation(:'pid', 'unverified@example.com', 'viewer') as inv_unverified \gset
select tests.authenticate_as(:'unverified');
select is(
  public.accept_invitation((:'inv_unverified')::jsonb ->> 'token') ->> 'status', 'email_not_verified',
  'unverified e-mail addresses cannot accept'
);

select tests.authenticate_as(:'owner');
select public.create_invitation(:'pid', 'outsider@example.com', 'accountant') as inv_expired \gset
select tests.clear_authentication();
update public.portfolio_invitations set expires_at = now() - interval '1 minute'
where id = split_part((:'inv_expired')::jsonb ->> 'token', '.', 1)::uuid;
select tests.authenticate_as(:'outsider');
select is(
  public.accept_invitation((:'inv_expired')::jsonb ->> 'token') ->> 'status', 'expired',
  'expired invitations are refused'
);

-- Only owners invite or revoke.
select tests.authenticate_as(:'manager');
select throws_ok(
  $$select public.create_invitation('01a1a2c0-0000-7000-8000-000000000001', 'x@example.com', 'viewer')$$,
  '42501', 'forbidden', 'non-owners cannot invite'
);
select tests.authenticate_as(:'owner');
select throws_ok(
  $$select public.create_invitation('01a1a2c0-0000-7000-8000-000000000001', 'not-an-email', 'viewer')$$,
  '22023', 'invalid_email', 'invalid e-mail addresses are rejected'
);
select throws_ok(
  $$select public.create_invitation('01a1a2c0-0000-7000-8000-000000000001', 'manager@example.com', 'viewer')$$,
  '22023', 'already_member', 'existing members cannot be invited again'
);

-- Rate limiting of accept attempts (10 per 10 minutes per user).
select tests.authenticate_as(:'outsider');
select public.accept_invitation('x') from generate_series(1, 7);
select throws_ok(
  $$select public.accept_invitation('x')$$, 'PGRST', null,
  'brute-forcing invitation tokens is rate limited (HTTP 429)'
);

-- Roles ---------------------------------------------------------------------
select tests.authenticate_as(:'owner');
select lives_ok(
  format('select public.update_member_role(%L, %L, %L)', :'pid', :'manager', 'manager'),
  'owners change roles'
);
select throws_ok(
  format('select public.update_member_role(%L, %L, %L)', :'pid', :'owner', 'viewer'),
  '22023', 'last_owner', 'the last owner cannot be demoted'
);
select throws_ok(
  format('select public.remove_member(%L, %L)', :'pid', :'owner'),
  '22023', 'last_owner', 'the last owner cannot leave'
);

select tests.clear_authentication();
select tests.add_member(:'pid', :'owner2', 'owner');
select tests.authenticate_as(:'owner');
select (public.create_invitation(:'pid', 'stepdown@example.com', 'viewer')) ->> 'invitation_id' as inv_stepdown \gset
select lives_ok(
  format('select public.update_member_role(%L, %L, %L)', :'pid', :'owner', 'manager'),
  'an owner can step down when another owner exists'
);
select tests.clear_authentication();
select ok(
  (select revoked_at is not null from public.portfolio_invitations where id = :'inv_stepdown'),
  'invitations carry their inviter''s authority: a demoted owner''s pending ones are revoked'
);
select tests.authenticate_as(:'owner');
select is(
  (public.create_portfolio('Gulberg Homes', :'pid')).id, :'pid'::uuid,
  'the creator''s offline retry still works while they belong to the portfolio'
);

-- A removed owner's pending invitations go with them, and an invitation whose
-- inviter is no longer an owner is void even if it escaped revocation.
select tests.authenticate_as(:'owner2');
select public.update_member_role(:'pid', :'owner', 'owner');
select tests.authenticate_as(:'owner');
select (public.create_invitation(:'pid', 'removed.inviter@example.com', 'viewer')) ->> 'invitation_id' as inv_removed \gset
select tests.authenticate_as(:'owner2');
select public.remove_member(:'pid', :'owner');
select tests.clear_authentication();
select ok(
  (select revoked_at is not null from public.portfolio_invitations where id = :'inv_removed'),
  'a removed owner''s pending invitations are revoked'
);
select tests.authenticate_as(:'owner');
select throws_ok(
  format($f$select public.create_portfolio('Gulberg Homes', %L)$f$, :'pid'),
  '42501', 'forbidden', 'a removed creator''s retry no longer returns the portfolio'
);
select tests.clear_authentication();
select tests.create_user('late.joiner@example.com') as late \gset
select tests.authenticate_as(:'owner2');
select public.create_invitation(:'pid', 'late.joiner@example.com', 'viewer') as inv_late \gset
-- The membership trigger that revokes invitations is bypassed here, to show
-- that acceptance checks the inviter's authority on its own.
select tests.clear_authentication();
alter table public.portfolio_members disable trigger portfolio_members_after_owner_ends;
update public.portfolio_members set role = 'manager' where portfolio_id = :'pid' and user_id = :'owner2';
alter table public.portfolio_members enable trigger portfolio_members_after_owner_ends;
select tests.authenticate_as(:'late');
select is(
  public.accept_invitation((:'inv_late')::jsonb ->> 'token') ->> 'status', 'revoked',
  'an invitation is void once its inviter is no longer an owner'
);
select tests.clear_authentication();
select ok(
  (select revoked_at is not null from public.portfolio_invitations where id = ((:'inv_late')::jsonb ->> 'invitation_id')::uuid),
  'and the revocation is recorded, so the invitation stays void if the inviter becomes an owner again'
);
update public.portfolio_members set role = 'owner' where portfolio_id = :'pid' and user_id = :'owner2';

select tests.authenticate_as(:'manager');
select throws_ok(
  format('select public.remove_member(%L, %L)', :'pid', :'owner2'),
  '42501', 'forbidden', 'non-owners cannot remove others'
);
select lives_ok(
  format('select public.remove_member(%L, %L)', :'pid', :'manager'),
  'members can leave'
);
select is((select count(*)::integer from public.portfolios), 0, 'after leaving, the portfolio is no longer visible');

-- Deleting a portfolio requires typing its name.
select tests.authenticate_as(:'owner2');
select throws_ok(
  format('select public.delete_portfolio(%L, %L)', :'pid', 'wrong name'),
  '22023', 'confirmation_mismatch', 'deletion requires the exact portfolio name'
);
select lives_ok(
  format('select public.delete_portfolio(%L, %L)', :'pid', '  gulberg HOMES '),
  'owners delete a portfolio by confirming its name (case-insensitive)'
);

select * from finish();
rollback;
