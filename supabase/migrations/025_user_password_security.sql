-- Parol xavfsizligi va login himoyasi (Neon).

alter table public.users
  add column if not exists password_hash text,
  add column if not exists failed_login_count int not null default 0,
  add column if not exists login_locked_until timestamptz;

comment on column public.users.password_hash is 'bcrypt hash — mobil login uchun';
comment on column public.users.failed_login_count is 'Ketma-ket noto''g''ri parol urinishlari';
comment on column public.users.login_locked_until is 'Vaqtinchalik blok (brute-force)';

create index if not exists users_login_locked_idx
  on public.users (login_locked_until)
  where login_locked_until is not null;
