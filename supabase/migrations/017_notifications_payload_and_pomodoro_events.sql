-- Rich notification payload for targeted actions (e.g., book_granted).
alter table public.notifications
  add column if not exists type text not null default 'generic',
  add column if not exists route text not null default '/notifications',
  add column if not exists data jsonb not null default '{}'::jsonb;

-- Lightweight pomodoro lifecycle event log (start/pause/resume/finish).
create table if not exists public.pomodoro_session_events (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  user_id uuid not null references public.users(id) on delete cascade,
  event_type text not null check (event_type in ('start', 'pause', 'resume', 'finish')),
  event_at timestamptz not null default now(),
  duration_sec int not null default 0,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists pomodoro_session_events_user_idx
  on public.pomodoro_session_events (user_id, created_at desc);

create index if not exists pomodoro_session_events_session_idx
  on public.pomodoro_session_events (session_id, created_at asc);
