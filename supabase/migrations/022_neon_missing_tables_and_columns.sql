-- Neon: kod ishlatadigan, lekin 001-021 da yaratilmagan jadval/ustunlar.

-- ---------------------------------------------------------------------------
-- 1) Kurslar: instructor + cover
-- ---------------------------------------------------------------------------
alter table public.courses
  add column if not exists instructor_name text not null default 'Umidjon Mukarramov',
  add column if not exists cover_image_url text not null default '';

update public.courses
set cover_image_url = image_url
where cover_image_url = '' and coalesce(image_url, '') <> '';

-- ---------------------------------------------------------------------------
-- 2) Kitoblar: narx va sotib olish havolasi
-- ---------------------------------------------------------------------------
alter table public.book_items
  add column if not exists price_uzs numeric(12, 2) not null default 0,
  add column if not exists purchase_contact_url text not null default '';

-- ---------------------------------------------------------------------------
-- 3) Bannerlar: tartib
-- ---------------------------------------------------------------------------
alter table public.course_banners
  add column if not exists sort_order int not null default 0;

create index if not exists course_banners_sort_idx
  on public.course_banners (sort_order asc, created_at desc);

-- ---------------------------------------------------------------------------
-- 4) Pomodoro sessiyalari (leaderboard)
-- ---------------------------------------------------------------------------
create table if not exists public.pomodoro_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  focus_minutes int not null default 25,
  break_minutes int not null default 5,
  break_seconds int not null default 0,
  completed_cycles int not null default 0,
  actual_focus_seconds int not null default 0,
  duration_seconds int not null default 0,
  status text not null default 'completed',
  completed_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pomodoro_sessions_user_completed_idx
  on public.pomodoro_sessions (user_id, completed_at desc);

-- ---------------------------------------------------------------------------
-- 5) Kunlik video reyting jadvallari
-- ---------------------------------------------------------------------------
create table if not exists public.rank_daily_lesson_watch (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  local_date date not null,
  watched_seconds int not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, lesson_id, local_date)
);

create index if not exists rank_daily_lesson_watch_user_date_idx
  on public.rank_daily_lesson_watch (user_id, local_date desc);

create table if not exists public.rank_daily_watch (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  local_date date not null,
  watched_seconds int not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, local_date)
);

create index if not exists rank_daily_watch_user_date_idx
  on public.rank_daily_watch (user_id, local_date desc);

-- ---------------------------------------------------------------------------
-- 6) RLS
-- ---------------------------------------------------------------------------
alter table public.pomodoro_sessions enable row level security;
alter table public.rank_daily_lesson_watch enable row level security;
alter table public.rank_daily_watch enable row level security;

drop policy if exists pomodoro_sessions_service_all on public.pomodoro_sessions;
create policy pomodoro_sessions_service_all on public.pomodoro_sessions
for all to service_role using (true) with check (true);

drop policy if exists pomodoro_sessions_public_read on public.pomodoro_sessions;
create policy pomodoro_sessions_public_read on public.pomodoro_sessions
for select to anon, authenticated using (true);

drop policy if exists rank_daily_lesson_watch_service_all on public.rank_daily_lesson_watch;
create policy rank_daily_lesson_watch_service_all on public.rank_daily_lesson_watch
for all to service_role using (true) with check (true);

drop policy if exists rank_daily_lesson_watch_self_rw on public.rank_daily_lesson_watch;
create policy rank_daily_lesson_watch_self_rw on public.rank_daily_lesson_watch
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists rank_daily_watch_service_all on public.rank_daily_watch;
create policy rank_daily_watch_service_all on public.rank_daily_watch
for all to service_role using (true) with check (true);

drop policy if exists rank_daily_watch_self_rw on public.rank_daily_watch;
create policy rank_daily_watch_self_rw on public.rank_daily_watch
for all to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
