-- Kitob entitlement va book_categories tuzatish (Neon / Supabase migratsiyasi).

create table if not exists public.user_book_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  book_id uuid not null references public.book_items(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, book_id)
);

create index if not exists user_book_entitlements_user_idx
  on public.user_book_entitlements(user_id, is_active);

-- Eski skelet bo'lsa: name ustuni qo'shiladi.
create table if not exists public.book_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  slug text not null default '',
  created_at timestamptz not null default now()
);

alter table public.book_categories
  add column if not exists name text not null default '',
  add column if not exists slug text not null default '',
  add column if not exists created_at timestamptz not null default now();

alter table public.book_categories enable row level security;

drop policy if exists book_categories_public_read on public.book_categories;
create policy book_categories_public_read on public.book_categories
for select using (true);

drop policy if exists book_categories_service_write on public.book_categories;
create policy book_categories_service_write on public.book_categories
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

alter table public.user_book_entitlements enable row level security;

drop policy if exists user_book_entitlements_self_read on public.user_book_entitlements;
create policy user_book_entitlements_self_read on public.user_book_entitlements
for select using (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists user_book_entitlements_service_write on public.user_book_entitlements;
create policy user_book_entitlements_service_write on public.user_book_entitlements
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');
