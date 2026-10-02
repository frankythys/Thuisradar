-- Thuisradar: databaseschema voor Supabase
-- Uitvoeren in Supabase > SQL Editor > New query > Run.
-- Het script mag opnieuw uitgevoerd worden (idempotent waar mogelijk).

-- ─── Tabellen ────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  created_at   timestamptz not null default now()
);

create table if not exists public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 60),
  invite_code text not null unique,
  created_by  uuid not null references auth.users (id),
  created_at  timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

-- Laatste bekende locatie per gebruiker (één rij per persoon, realtime).
create table if not exists public.member_locations (
  user_id     uuid primary key references public.profiles (id) on delete cascade,
  family_id   uuid not null references public.families (id) on delete cascade,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  accuracy_m  real,
  speed_mps   real,
  battery     smallint check (battery between 0 and 100),
  is_charging boolean,
  updated_at  timestamptz not null default now()
);

-- Volledige geschiedenis, gevuld door een trigger op member_locations.
create table if not exists public.location_history (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  family_id   uuid not null references public.families (id) on delete cascade,
  lat         double precision not null,
  lng         double precision not null,
  accuracy_m  real,
  speed_mps   real,
  battery     smallint,
  recorded_at timestamptz not null
);

create index if not exists location_history_user_time_idx
  on public.location_history (user_id, recorded_at desc);
create index if not exists family_members_user_idx
  on public.family_members (user_id);

-- ─── Hulpfuncties ────────────────────────────────────────────────────────────

-- security definer: voorkomt oneindige RLS-recursie op family_members.
create or replace function public.is_family_member(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from family_members
    where family_id = fid and user_id = auth.uid()
  );
$$;

create or replace function public.shares_family_with(other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from family_members me
    join family_members them on them.family_id = me.family_id
    where me.user_id = auth.uid() and them.user_id = other
  );
$$;

-- Familie aanmaken: maakt de familie + eigenaar-lidmaatschap in één transactie.
create or replace function public.create_family(family_name text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family families;
begin
  if auth.uid() is null then
    raise exception 'Niet ingelogd';
  end if;

  insert into families (name, invite_code, created_by)
  values (
    trim(family_name),
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    auth.uid()
  )
  returning * into new_family;

  insert into family_members (family_id, user_id, role)
  values (new_family.id, auth.uid(), 'owner');

  return new_family;
end;
$$;

-- Familie joinen met een uitnodigingscode.
create or replace function public.join_family(code text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  target families;
begin
  if auth.uid() is null then
    raise exception 'Niet ingelogd';
  end if;

  select * into target from families where invite_code = upper(trim(code));
  if target.id is null then
    raise exception 'Onbekende uitnodigingscode';
  end if;

  insert into family_members (family_id, user_id)
  values (target.id, auth.uid())
  on conflict do nothing;

  return target;
end;
$$;

-- Geschiedenis bijhouden bij elke nieuwe of gewijzigde locatie.
create or replace function public.record_location_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into location_history
    (user_id, family_id, lat, lng, accuracy_m, speed_mps, battery, recorded_at)
  values
    (new.user_id, new.family_id, new.lat, new.lng, new.accuracy_m,
     new.speed_mps, new.battery, new.updated_at);
  return new;
end;
$$;

drop trigger if exists member_locations_history on public.member_locations;
create trigger member_locations_history
  after insert or update on public.member_locations
  for each row execute function public.record_location_history();

-- ─── Row Level Security ──────────────────────────────────────────────────────

alter table public.profiles         enable row level security;
alter table public.families         enable row level security;
alter table public.family_members   enable row level security;
alter table public.member_locations enable row level security;
alter table public.location_history enable row level security;

drop policy if exists "profiel: zelf of familie lezen" on public.profiles;
create policy "profiel: zelf of familie lezen" on public.profiles
  for select using (id = auth.uid() or public.shares_family_with(id));

drop policy if exists "profiel: zelf aanmaken" on public.profiles;
create policy "profiel: zelf aanmaken" on public.profiles
  for insert with check (id = auth.uid());

drop policy if exists "profiel: zelf wijzigen" on public.profiles;
create policy "profiel: zelf wijzigen" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "familie: leden lezen" on public.families;
create policy "familie: leden lezen" on public.families
  for select using (public.is_family_member(id));

drop policy if exists "leden: familie lezen" on public.family_members;
create policy "leden: familie lezen" on public.family_members
  for select using (public.is_family_member(family_id));

drop policy if exists "leden: zelf verlaten" on public.family_members;
create policy "leden: zelf verlaten" on public.family_members
  for delete using (user_id = auth.uid());

drop policy if exists "locatie: familie lezen" on public.member_locations;
create policy "locatie: familie lezen" on public.member_locations
  for select using (public.is_family_member(family_id));

drop policy if exists "locatie: zelf schrijven" on public.member_locations;
create policy "locatie: zelf schrijven" on public.member_locations
  for insert with check (user_id = auth.uid() and public.is_family_member(family_id));

drop policy if exists "locatie: zelf bijwerken" on public.member_locations;
create policy "locatie: zelf bijwerken" on public.member_locations
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_family_member(family_id));

drop policy if exists "geschiedenis: familie lezen" on public.location_history;
create policy "geschiedenis: familie lezen" on public.location_history
  for select using (public.is_family_member(family_id));

-- Rechtstreekse aanroep van interne functies afschermen.
revoke execute on function public.record_location_history() from public, anon, authenticated;
revoke execute on function public.create_family(text) from public, anon;
revoke execute on function public.join_family(text) from public, anon;
grant execute on function public.create_family(text) to authenticated;
grant execute on function public.join_family(text) to authenticated;

-- ─── Realtime ────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'member_locations'
  ) then
    alter publication supabase_realtime add table public.member_locations;
  end if;
end;
$$;

-- ─── Optioneel: geschiedenis ouder dan 30 dagen opruimen ────────────────────
-- Zet eerst de extensie pg_cron aan (Database > Extensions), en voer dan uit:
-- select cron.schedule('thuisradar-history-cleanup', '15 3 * * *',
--   $$delete from public.location_history where recorded_at < now() - interval '30 days'$$);
