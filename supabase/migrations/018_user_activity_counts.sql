-- Har bir login va ilova ochilishini alohida hisoblash (admin panel: login soni / app open soni).

alter table public.users
  add column if not exists login_count int not null default 0,
  add column if not exists app_open_count int not null default 0,
  add column if not exists last_app_open_at timestamptz;

comment on column public.users.login_count is 'Muvaffaqiyatli mobile-login soni.';
comment on column public.users.app_open_count is 'Ilova ochilish (cold start / resume) soni.';
comment on column public.users.last_app_open_at is 'Oxirgi app-open qayd vaqti (dedup uchun).';

-- Mavjud foydalanuvchilar uchun taxminiy boshlang‘ich (keyingi login/open dan aniq hisoblanadi).
update public.users u
set login_count = 1
where login_count = 0
  and exists (select 1 from public.auth_sessions s where s.user_id = u.id);

update public.users u
set app_open_count = greatest(login_count, 1)
where app_open_count = 0
  and exists (select 1 from public.user_devices d where d.user_id = u.id);
