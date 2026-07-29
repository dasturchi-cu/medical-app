-- Migration 027: Masked phone number fallback for user ranking names if full_name is empty/null.

create or replace function public.get_daily_ranking(
  limit_count int default 10,
  current_user_id uuid default null,
  local_date_param date default null
)
returns table (
  rank bigint,
  user_id uuid,
  full_name text,
  total_seconds bigint,
  completed_lessons bigint,
  is_current_user boolean,
  row_type text
)
language sql
stable
security definer
set search_path = public
as $$
  with today_local as (
    select coalesce(local_date_param, (now() at time zone 'Asia/Tashkent')::date) as d
  ),
  watch_today as (
    select
      rdlw.user_id,
      sum(rdlw.watched_seconds)::bigint as watched_seconds
    from public.rank_daily_lesson_watch rdlw
    cross join today_local t
    where rdlw.local_date = t.d
    group by rdlw.user_id
  ),
  completed_today as (
    select
      vp.user_id,
      count(*)::bigint as completed_lessons
    from public.video_progress vp
    cross join today_local t
    where vp.completed = true
      and (vp.updated_at at time zone 'Asia/Tashkent')::date = t.d
    group by vp.user_id
  ),
  merged as (
    select
      u.id as user_id,
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ) as full_name,
      coalesce(w.watched_seconds, 0) as total_seconds,
      coalesce(c.completed_lessons, 0) as completed_lessons
    from public.users u
    left join watch_today w on w.user_id = u.id
    left join completed_today c on c.user_id = u.id
    where coalesce(w.watched_seconds, 0) > 0 or coalesce(c.completed_lessons, 0) > 0
  ),
  ranked as (
    select
      row_number() over (
        order by total_seconds desc, completed_lessons desc, user_id asc
      )::bigint as rank,
      user_id,
      full_name,
      total_seconds,
      completed_lessons
    from merged
  ),
  top_users as (
    select *, 'top'::text as row_type from ranked where rank <= limit_count
  ),
  current_user_row as (
    select r.rank, r.user_id, r.full_name, r.total_seconds, r.completed_lessons, 'current_user'::text as row_type
    from ranked r
    where r.user_id = current_user_id
    union all
    select
      coalesce((select max(r2.rank) from ranked r2), 0) + 1,
      u.id,
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ),
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
    r.completed_lessons,
    (r.user_id = current_user_id) as is_current_user,
    r.row_type
  from (
    select * from top_users
    union all
    select * from current_user_row
  ) r
  order by r.rank;
$$;


create or replace function public.get_overall_ranking(
  limit_count int default 10,
  current_user_id uuid default null
)
returns table (
  rank bigint,
  user_id uuid,
  full_name text,
  total_seconds bigint,
  completed_lessons bigint,
  is_current_user boolean,
  row_type text
)
language sql
stable
security definer
set search_path = public
as $$
  with watch_totals as (
    select
      rdlw.user_id,
      sum(rdlw.watched_seconds)::bigint as lesson_watch_seconds
    from public.rank_daily_lesson_watch rdlw
    group by rdlw.user_id
  ),
  video_totals as (
    select
      vp.user_id,
      sum(greatest(vp.watched_sec, 0))::bigint as video_max_seconds,
      count(*) filter (where vp.completed = true)::bigint as completed_lessons
    from public.video_progress vp
    group by vp.user_id
  ),
  per_user as (
    select
      coalesce(w.user_id, v.user_id) as user_id,
      greatest(
        coalesce(w.lesson_watch_seconds, 0),
        coalesce(v.video_max_seconds, 0)
      )::bigint as total_seconds,
      coalesce(v.completed_lessons, 0)::bigint as completed_lessons
    from watch_totals w
    full outer join video_totals v on v.user_id = w.user_id
    where greatest(
            coalesce(w.lesson_watch_seconds, 0),
            coalesce(v.video_max_seconds, 0)
          ) > 0
       or coalesce(v.completed_lessons, 0) > 0
  ),
  merged as (
    select
      u.id as user_id,
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ) as full_name,
      p.total_seconds,
      p.completed_lessons
    from per_user p
    join public.users u on u.id = p.user_id
  ),
  ranked as (
    select
      row_number() over (
        order by total_seconds desc, completed_lessons desc, user_id asc
      )::bigint as rank,
      user_id,
      full_name,
      total_seconds,
      completed_lessons
    from merged
  ),
  top_users as (
    select *, 'top'::text as row_type from ranked where rank <= limit_count
  ),
  current_user_row as (
    select r.rank, r.user_id, r.full_name, r.total_seconds, r.completed_lessons, 'current_user'::text as row_type
    from ranked r
    where r.user_id = current_user_id
    union all
    select
      coalesce((select max(r2.rank) from ranked r2), 0) + 1,
      u.id,
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ),
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
    r.completed_lessons,
    (r.user_id = current_user_id) as is_current_user,
    r.row_type
  from (
    select * from top_users
    union all
    select * from current_user_row
  ) r
  order by r.rank;
$$;


create or replace function public.get_pomodoro_ranking(
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
  with per_user as (
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
    where ps.status = 'completed'
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
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ) as full_name,
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
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ),
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


create or replace function public.get_pomodoro_daily_ranking(
  limit_count int default 10,
  current_user_id uuid default null,
  local_date_param date default null
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
    select coalesce(local_date_param, (now() at time zone 'Asia/Tashkent')::date) as d
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
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ) as full_name,
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
      coalesce(
        nullif(trim(u.full_name), ''),
        coalesce(
          nullif(concat('+', substr(u.phone, 1, 5), '*****', substr(u.phone, greatest(1, length(u.phone) - 3))), '+*****'),
          'Foydalanuvchi'
        )
      ),
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


grant execute on function public.get_daily_ranking(int, uuid, date) to anon, authenticated, service_role;
grant execute on function public.get_overall_ranking(int, uuid) to anon, authenticated, service_role;
grant execute on function public.get_pomodoro_ranking(int, uuid) to anon, authenticated, service_role;
grant execute on function public.get_pomodoro_daily_ranking(int, uuid, date) to anon, authenticated, service_role;
