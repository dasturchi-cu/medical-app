-- Storage: content-assets bucket (Neon: fayllar R2 da; bu policylar ixtiyoriy).
-- Xato "role anon does not exist" bo'lsa: avval 000_neon_platform.sql yoki scripts/neon-preflight.sql

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end;
$$;

create schema if not exists storage;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text,
  name text
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'content-assets',
  'content-assets',
  true,
  52428800,
  null
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = coalesce(storage.buckets.file_size_limit, excluded.file_size_limit);

drop policy if exists "content_assets_public_read" on storage.objects;
drop policy if exists "content_assets_insert_anon_auth" on storage.objects;
drop policy if exists "content_assets_update_anon_auth" on storage.objects;
drop policy if exists "content_assets_delete_anon_auth" on storage.objects;

create policy "content_assets_public_read"
on storage.objects
for select
to public
using (bucket_id = 'content-assets');

create policy "content_assets_insert_anon_auth"
on storage.objects
for insert
to anon, authenticated
with check (bucket_id = 'content-assets');

create policy "content_assets_update_anon_auth"
on storage.objects
for update
to anon, authenticated
using (bucket_id = 'content-assets')
with check (bucket_id = 'content-assets');

create policy "content_assets_delete_anon_auth"
on storage.objects
for delete
to anon, authenticated
using (bucket_id = 'content-assets');
