-- Minimale nabootsing van wat Supabase levert (auth, vault, pg_net, storage),
-- zodat schema.sql + alle migraties in een gewone lokale Postgres laden.
-- Enkel voor tests; nooit in Supabase uitvoeren.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
    create role authenticated nologin;
    create role service_role nologin;
  end if;
end;
$$;

create schema auth;
create schema extensions;
create schema vault;
create schema net;
create schema storage;

create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create function auth.role() returns text language sql stable as $$ select 'authenticated' $$;
create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;

create publication supabase_realtime;

-- Een webhook-geheim zodat call_push effectief "verstuurt" (in net.calls).
create view vault.decrypted_secrets as
  select 'webhook_secret'::text as name, 'test'::text as decrypted_secret;

-- pg_net: elke push komt als rij in net.calls terecht.
create table net.calls (url text, body jsonb, at timestamptz default now());
create function net.http_post(
  url text, headers jsonb default '{}', body jsonb default '{}',
  params jsonb default '{}', timeout_milliseconds int default 1000
) returns bigint language sql as $$
  insert into net.calls (url, body) values (url, body);
  select 1::bigint;
$$;

create table storage.buckets (
  id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid default gen_random_uuid(), bucket_id text, name text, owner uuid, owner_id text
);
create function storage.foldername(name text) returns text[] language sql as $$
  select string_to_array(name, '/')
$$;
alter table storage.objects enable row level security;
