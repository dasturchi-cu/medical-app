-- Security Advisor: errors/warnings/info (2026-06).
-- Muhim: content-assets / course-covers "public listing" ni yopadi (egress kamayishi mumkin).
-- Supabase SQL Editor da ishga tushiring (xizmat ochilgandan keyin).

-- ---------------------------------------------------------------------------
-- 1) Functions: fixed search_path
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
      and p.proname in (
        'touch_updated_at',
        'invalidate_user_sessions',
        'app_comments_sync_counters'
      )
  loop
    execute format(
      'alter function %s set search_path = public, pg_temp',
      fn.sig
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) SECURITY DEFINER RPC: faqat service_role
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
-- 3) View: security_invoker (Security Definer View xatosi)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1
    from pg_views
    where schemaname = 'public'
      and viewname = 'daily_pomodoro_leaderboard'
  ) then
    execute 'alter view public.daily_pomodoro_leaderboard set (security_invoker = true)';
  end if;
exception
  when others then
    raise notice 'daily_pomodoro_leaderboard security_invoker: %', sqlerrm;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) Storage: public listing yopish (to''g''ri URL orqali o''qish qoladi)
-- Botlar butun bucketni ro''yxatlab, 352MB+ yuklab olishi mumkin edi (egress).
-- ---------------------------------------------------------------------------
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and (
        policyname ilike '%public_read%'
        or policyname ilike '%content_assets%select%'
        or policyname ilike '%course_covers%read%'
      )
      and cmd in ('SELECT', 'ALL')
  loop
    execute format('drop policy if exists %I on storage.objects', pol.policyname);
  end loop;
end;
$$;

drop policy if exists "content_assets_public_read" on storage.objects;
drop policy if exists "course_covers_public_read" on storage.objects;

-- Admin upload (anon JWT) — faqat INSERT/UPDATE/DELETE; SELECT listing yo''q.
drop policy if exists "content_assets_insert_anon_auth" on storage.objects;
drop policy if exists "content_assets_update_anon_auth" on storage.objects;
drop policy if exists "content_assets_delete_anon_auth" on storage.objects;

create policy "content_assets_insert_anon_auth"
on storage.objects
for insert
to anon, authenticated, service_role
with check (bucket_id = 'content-assets');

create policy "content_assets_update_anon_auth"
on storage.objects
for update
to anon, authenticated, service_role
using (bucket_id = 'content-assets')
with check (bucket_id = 'content-assets');

create policy "content_assets_delete_anon_auth"
on storage.objects
for delete
to anon, authenticated, service_role
using (bucket_id = 'content-assets');

-- service_role to''liq boshqaruvi (backend)
drop policy if exists "content_assets_service_all" on storage.objects;
create policy "content_assets_service_all"
on storage.objects
for all
to service_role
using (bucket_id in ('content-assets', 'course-covers'))
with check (bucket_id in ('content-assets', 'course-covers'));

-- course-covers bucket (agar mavjud bo''lsa)
insert into storage.buckets (id, name, public, file_size_limit)
values ('course-covers', 'course-covers', true, 10485760)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "course_covers_insert_anon_auth" on storage.objects;
drop policy if exists "course_covers_update_anon_auth" on storage.objects;
drop policy if exists "course_covers_delete_anon_auth" on storage.objects;

create policy "course_covers_insert_anon_auth"
on storage.objects
for insert
to anon, authenticated, service_role
with check (bucket_id = 'course-covers');

create policy "course_covers_update_anon_auth"
on storage.objects
for update
to anon, authenticated, service_role
using (bucket_id = 'course-covers')
with check (bucket_id = 'course-covers');

create policy "course_covers_delete_anon_auth"
on storage.objects
for delete
to anon, authenticated, service_role
using (bucket_id = 'course-covers');

-- ---------------------------------------------------------------------------
-- 5) RLS: jadvallar uchun policy (Info: RLS enabled no policy)
-- ---------------------------------------------------------------------------
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'apk_download_events',
    'comment_reactions',
    'comments',
    'course_banners',
    'course_catalog_views',
    'course_sections',
    'courses',
    'home_slides',
    'lesson_slides',
    'lessons',
    'payments',
    'pomodoro_session_events',
    'quiz_attempts',
    'quiz_questions',
    'quizzes',
    'rank_events',
    'ratings',
    'user_ranks'
  ]
  loop
    if to_regclass(format('public.%I', tbl)) is not null then
      execute format('alter table public.%I enable row level security', tbl);

      execute format('drop policy if exists %I on public.%I', tbl || '_service_all', tbl);
      execute format(
        'create policy %I on public.%I for all to service_role using (true) with check (true)',
        tbl || '_service_all',
        tbl
      );
    end if;
  end loop;
end;
$$;

-- Realtime / katalog o''qish (faol yozuvlar; is_active bo''lmagan jadvalda true)
do $$
declare
  spec record;
  pred text;
begin
  for spec in
    select *
    from (values
      ('courses', 'is_active = true'),
      ('lessons', 'is_active = true'),
      ('course_sections', 'is_active = true'),
      ('home_slides', 'is_active = true'),
      ('lesson_slides', 'is_active = true'),
      ('course_banners', 'is_active = true'),
      ('quizzes', 'is_active = true'),
      ('quiz_questions', 'true')
    ) as t(table_name, predicate_active)
  loop
    if to_regclass(format('public.%I', spec.table_name)) is not null then
      if spec.predicate_active = 'true' then
        pred := 'true';
      elsif exists (
        select 1
        from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = spec.table_name
          and c.column_name = 'is_active'
      ) then
        pred := 'is_active = true';
      else
        pred := 'true';
      end if;

      execute format(
        'drop policy if exists %I on public.%I',
        spec.table_name || '_public_read',
        spec.table_name
      );
      execute format(
        'create policy %I on public.%I for select to anon, authenticated using (%s)',
        spec.table_name || '_public_read',
        spec.table_name,
        pred
      );
    end if;
  end loop;
end;
$$;

-- quiz_attempts: faqat o''z yozuvi
do $$
begin
  if to_regclass('public.quiz_attempts') is not null then
    drop policy if exists quiz_attempts_self_read on public.quiz_attempts;
    create policy quiz_attempts_self_read on public.quiz_attempts
    for select to authenticated
    using (auth.uid() = user_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) media_assets / pomodoro_sessions: USING(true) policylarni qattiqroq qilish
-- ---------------------------------------------------------------------------
do $$
declare
  pol record;
begin
  if to_regclass('public.media_assets') is not null then
    for pol in
      select policyname
      from pg_policies
      where schemaname = 'public' and tablename = 'media_assets'
    loop
      execute format('drop policy if exists %I on public.media_assets', pol.policyname);
    end loop;

    if exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = 'media_assets'
        and c.column_name = 'is_active'
    ) then
      execute $pol$
        create policy media_assets_public_read on public.media_assets
        for select to anon, authenticated
        using (coalesce(is_active, true) = true)
      $pol$;
    else
      execute $pol$
        create policy media_assets_public_read on public.media_assets
        for select to anon, authenticated
        using (true)
      $pol$;
    end if;

    create policy media_assets_service_write on public.media_assets
    for all to service_role
    using (true) with check (true);
  end if;

  if to_regclass('public.pomodoro_sessions') is not null then
    for pol in
      select policyname
      from pg_policies
      where schemaname = 'public' and tablename = 'pomodoro_sessions'
    loop
      execute format('drop policy if exists %I on public.pomodoro_sessions', pol.policyname);
    end loop;

    create policy pomodoro_sessions_service_all on public.pomodoro_sessions
    for all to service_role
    using (true) with check (true);
  end if;
end;
$$;

-- Qolgan jadvallar: faqat service_role yozadi, o''qish backend orqali
do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'apk_download_events',
    'comment_reactions',
    'comments',
    'course_catalog_views',
    'payments',
    'pomodoro_session_events'
  ]
  loop
    if to_regclass(format('public.%I', tbl)) is not null then
      execute format('alter table public.%I enable row level security', tbl);
      execute format('drop policy if exists %I on public.%I', tbl || '_service_all', tbl);
      execute format(
        'create policy %I on public.%I for all to service_role using (true) with check (true)',
        tbl || '_service_all',
        tbl
      );
    end if;
  end loop;
end;
$$;
