-- Pomodoro kunlik reyting: faqat bugun (00:00 Asia/Tashkent dan keyin yangi kun).

create or replace function public.get_pomodoro_daily_ranking(
  limit_count int default 10,
  current_user_id uuid default null
)
returns table (
  rank bigint,
  user_id uuid,
  full_name text,
  total_seconds bigint,
  completed_sessions bigint,
  is_current_user boolean,
  row_type text
)
language sql
stable
security definer
set search_path = public
as $$
  with today_local as (
    select (now() at time zone 'Asia/Tashkent')::date as d
  ),
  per_user as (
    select
      ps.user_id,
      sum(
        greatest(
          coalesce(ps.duration_seconds, 0),
          coalesce(ps.actual_focus_seconds, 0),
          coalesce(ps.focus_minutes, 0) * 60
        )
      )::bigint as total_seconds,
      count(*)::bigint as completed_sessions
    from public.pomodoro_sessions ps
    cross join today_local t
    where ps.status = 'completed'
      and (
        (coalesce(ps.ended_at, ps.completed_at, ps.created_at) at time zone 'Asia/Tashkent')::date = t.d
      )
      and greatest(
        coalesce(ps.duration_seconds, 0),
        coalesce(ps.actual_focus_seconds, 0),
        coalesce(ps.focus_minutes, 0) * 60
      ) > 0
    group by ps.user_id
  ),
  merged as (
    select
      u.id as user_id,
      coalesce(nullif(trim(u.full_name), ''), 'Foydalanuvchi') as full_name,
      p.total_seconds,
      p.completed_sessions
    from per_user p
    join public.users u on u.id = p.user_id
  ),
  ranked as (
    select
      row_number() over (
        order by total_seconds desc, completed_sessions desc, user_id asc
      )::bigint as rank,
      user_id,
      full_name,
      total_seconds,
      completed_sessions
    from merged
  ),
  top_users as (
    select *, 'top'::text as row_type from ranked where rank <= limit_count
  ),
  current_user_row as (
    select r.rank, r.user_id, r.full_name, r.total_seconds, r.completed_sessions, 'current_user'::text as row_type
    from ranked r
    where r.user_id = current_user_id
    union all
    select
      coalesce((select max(r2.rank) from ranked r2), 0) + 1,
      u.id,
      coalesce(nullif(trim(u.full_name), ''), 'Foydalanuvchi'),
      0::bigint,
      0::bigint,
      'current_user'::text
    from public.users u
    where current_user_id is not null
      and u.id = current_user_id
      and not exists (select 1 from ranked r3 where r3.user_id = current_user_id)
  )
  select
    r.rank,
    r.user_id,
    r.full_name,
    r.total_seconds,
    r.completed_sessions,
    (r.user_id = current_user_id) as is_current_user,
    r.row_type
  from (
    select * from top_users
    union all
    select * from current_user_row
  ) r
  order by r.rank;
$$;

grant execute on function public.get_pomodoro_daily_ranking(int, uuid) to anon, authenticated, service_role;
