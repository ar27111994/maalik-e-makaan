-- Deleting a lease must not delete money records with it (PROJECT.md D-06:
-- financial rows are voided with a reason, never deleted).
--
-- charges.lease_id cascades, so until now a client deleting a lease also
-- deleted its charges, manual ones included, as long as nothing had been
-- paid (payments and deposit refunds block the delete through their foreign
-- keys). A lease entered by mistake should still be removable, so the rule
-- is: a client may delete a lease only while every charge on it follows from
-- the lease's own terms (rent, late fees, the security deposit) and none has
-- been paid, waived or voided. Otherwise the tenancy is ended instead.
--
-- System functions (portfolio and account deletion) run as the table owner
-- and are exempt, like the other client guards on the ledger.
--
-- Concurrency: the row lock the DELETE takes before this trigger runs
-- conflicts with the KEY SHARE lock a concurrent charge insert holds on the
-- lease through its foreign key, so the delete waits for that insert to
-- commit and the check below (a new snapshot, READ COMMITTED) then sees the
-- charge; an insert that comes second fails its foreign-key check.

create or replace function private.before_lease_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and exists (
    select 1
    from public.charges c
    where c.lease_id = old.id
      and (
        c.source not in ('auto_rent', 'auto_late_fee', 'deposit')
        or c.voided_at is not null
        or c.waived_amount > 0
        or c.paid_amount > 0
      )
  ) then
    perform app.fail('lease_has_records');
  end if;
  return old;
end
$$;

create trigger leases_before_delete
  before delete on public.leases
  for each row execute function private.before_lease_delete();
