-- Neon preflight: har safar migrationdan OLDIN ishga tushiring.
-- R2 fayllar uchun; Supabase Storage ishlatilmaydi (policylar ixtiyoriy).

create extension if not exists pgcrypto;

do $$
begin
  create publication supabase_realtime;
exception when duplicate_object then null;
end;
$$;

create schema if not exists auth;
create schema if not exists storage;

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

create or replace function auth.uid()
returns uuid language sql stable as $$ select null::uuid $$;

create or replace function auth.role()
returns text language sql stable as $$ select 'service_role'::text $$;

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
  name text,
  owner uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_accessed_at timestamptz,
  metadata jsonb,
  path_tokens text[],
  version text,
  owner_id uuid
);
