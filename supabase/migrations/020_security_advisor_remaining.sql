-- Security Advisor qolganlari (get_pomodoro_ranking + rank_events/ratings/user_ranks RLS).
-- 019 dan keyin SQL Editor da ishga tushiring.

-- ---------------------------------------------------------------------------
-- 1) Barcha ranking SECURITY DEFINER funksiyalar: faqat service_role
-- ---------------------------------------------------------------------------
do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef = true
      and (
        p.proname ilike '%ranking%'
        or p.proname in ('rls_auto_enable')
      )
  loop
    execute format('revoke all on function %s from public', fn.sig);
    execute format('revoke all on function %s from anon, authenticated', fn.sig);
    execute format('grant execute on function %s to service_role', fn.sig);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) RLS: rank_events, ratings, user_ranks (Info: enabled no policy)
-- ---------------------------------------------------------------------------
do $$
declare
  tbl text;
begin
  foreach tbl in array array['rank_events', 'ratings', 'user_ranks']
  loop
    if to_regclass(format('public.%I', tbl)) is not null then
      execute format('alter table public.%I enable row level security', tbl);

      execute format('drop policy if exists %I on public.%I', tbl || '_service_all', tbl);
      execute format(
        'create policy %I on public.%I for all to service_role using (true) with check (true)',
        tbl || '_service_all',
        tbl
      );

      -- Reyting jadvali ommaviy ko''rinsin (backend API + realtime ixtiyoriy)
      if tbl = 'user_ranks' then
        execute format('drop policy if exists %I on public.%I', tbl || '_public_read', tbl);
        execute format(
          'create policy %I on public.%I for select to anon, authenticated using (true)',
          tbl || '_public_read',
          tbl
        );
      end if;

      if tbl = 'ratings' then
        execute format('drop policy if exists %I on public.%I', tbl || '_public_read', tbl);
        execute format(
          'create policy %I on public.%I for select to anon, authenticated using (true)',
          tbl || '_public_read',
          tbl
        );
      end if;
    end if;
  end loop;
end;
$$;
