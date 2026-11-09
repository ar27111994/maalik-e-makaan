-- ============================================================================
-- Rate limits for Edge Functions.
--
-- Functions run in many isolates and regions, so in-memory counters cannot
-- enforce a limit. This exposes the database's fixed-window limiter to the
-- secret key only (the functions' admin client). Keys are namespaced with
-- `fn:` so they never collide with the pre-request and RPC limits. Windows
-- are capped at one hour because the cleanup job drops buckets older than
-- two hours.
-- ============================================================================

create or replace function public.admin_hit_rate_limit(
  p_key text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_key is null
     or char_length(p_key) not between 1 and 200
     or not app.is_clean_text(p_key)
     or p_limit is null or p_limit not between 1 and 100000
     or p_window_seconds is null or p_window_seconds not between 1 and 3600 then
    perform app.fail('invalid_rate_limit');
  end if;
  return private.hit_rate_limit('fn:' || p_key, p_limit, make_interval(secs => p_window_seconds));
end
$$;

comment on function public.admin_hit_rate_limit(text, integer, integer) is
  'Counts one hit for an Edge Function rate limit; true while within p_limit per window. Secret key only.';

revoke all on function public.admin_hit_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.admin_hit_rate_limit(text, integer, integer) to service_role;
