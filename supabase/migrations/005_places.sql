-- Fase D2: Plaatsen (geofences) + aankomst/vertrek.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
-- schema.sql blijft ongewijzigd. family_events (type arrival/departure, place_id)
-- komt uit migratie 003.

-- ─── Tabellen ────────────────────────────────────────────────────────────────

create table if not exists public.places (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references public.families (id) on delete cascade,
  name            text not null check (char_length(name) between 1 and 60),
  lat             double precision not null check (lat between -90 and 90),
  lng             double precision not null check (lng between -180 and 180),
  radius_m        integer not null default 150 check (radius_m between 50 and 500),
  icon            text not null default 'home',
  -- Over wie wil je meldingen? null/leeg = iedereen.
  watched_members uuid[],
  created_by      uuid not null default auth.uid() references public.profiles (id),
  created_at      timestamptz not null default now()
);

create index if not exists places_family_idx on public.places (family_id);

-- Huidige aanwezigheid per (lid, plaats), met tellers voor anti-flapping.
create table if not exists public.place_presence (
  user_id       uuid not null references public.profiles (id) on delete cascade,
  place_id      uuid not null references public.places (id) on delete cascade,
  family_id     uuid not null references public.families (id) on delete cascade,
  is_inside     boolean not null default false,
  since         timestamptz,
  outside_since timestamptz,
  outside_count integer not null default 0,
  updated_at    timestamptz not null default now(),
  primary key (user_id, place_id)
);

create index if not exists place_presence_family_idx on public.place_presence (family_id);

-- ─── Hulpfunctie: afstand in meter (haversine) ──────────────────────────────

create or replace function public.geo_distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- ─── Max. 20 plaatsen per familie ───────────────────────────────────────────

create or replace function public.enforce_place_limit()
returns trigger
language plpgsql
as $$
begin
  if (select count(*) from places where family_id = new.family_id) >= 20 then
    raise exception 'Maximaal 20 plaatsen per familie';
  end if;
  return new;
end;
$$;

drop trigger if exists places_limit on public.places;
create trigger places_limit
  before insert on public.places
  for each row execute function public.enforce_place_limit();

-- ─── Geofence-evaluatie met anti-flapping ───────────────────────────────────
-- Draait bij elke nieuwe/gewijzigde locatie. Regels:
--   * accuracy > 100 m  → meting negeren;
--   * binnen            → afstand < straal;
--   * buiten (bevestigd)→ afstand > straal + 50 m (hysterese);
--   * vertrek telt pas na >= 2 metingen in de buitenzone OF 3 min.
--   * band (straal..straal+50): geen verandering.
-- Een event/melding ontstaat enkel als het lid in watched_members zit
-- (of watched_members leeg/null = iedereen).

create or replace function public.evaluate_geofences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pl             record;
  pres           place_presence%rowtype;
  dist           double precision;
  new_count      integer;
  new_outside    timestamptz;
  watched        boolean;
begin
  if new.accuracy_m is not null and new.accuracy_m > 100 then
    return new;
  end if;

  for pl in select * from places where family_id = new.family_id loop
    dist := geo_distance_m(new.lat, new.lng, pl.lat, pl.lng);
    select * into pres from place_presence where user_id = new.user_id and place_id = pl.id;
    watched := pl.watched_members is null
      or array_length(pl.watched_members, 1) is null
      or new.user_id = any (pl.watched_members);

    if dist < pl.radius_m then
      -- Binnenzone.
      if pres.user_id is null or not pres.is_inside then
        insert into place_presence (user_id, place_id, family_id, is_inside, since, outside_since, outside_count, updated_at)
        values (new.user_id, pl.id, new.family_id, true, new.updated_at, null, 0, now())
        on conflict (user_id, place_id) do update
          set is_inside = true, since = excluded.since, outside_since = null, outside_count = 0, updated_at = now();
        if watched then
          insert into family_events (family_id, actor_user_id, type, place_id, lat, lng, created_at)
          values (new.family_id, new.user_id, 'arrival', pl.id, new.lat, new.lng, new.updated_at);
        end if;
      else
        update place_presence set outside_since = null, outside_count = 0, updated_at = now()
          where user_id = new.user_id and place_id = pl.id;
      end if;

    elsif dist > pl.radius_m + 50 then
      -- Buitenzone (voorbij de hysterese).
      if pres.user_id is not null and pres.is_inside then
        if pres.outside_since is null then
          new_outside := new.updated_at;
          new_count := 1;
        else
          new_outside := pres.outside_since;
          new_count := pres.outside_count + 1;
        end if;

        if new_count >= 2 or (new.updated_at - new_outside) >= interval '3 minutes' then
          update place_presence set is_inside = false, since = null, outside_since = null, outside_count = 0, updated_at = now()
            where user_id = new.user_id and place_id = pl.id;
          if watched then
            insert into family_events (family_id, actor_user_id, type, place_id, lat, lng, created_at)
            values (new.family_id, new.user_id, 'departure', pl.id, new.lat, new.lng, new.updated_at);
          end if;
        else
          update place_presence set outside_since = new_outside, outside_count = new_count, updated_at = now()
            where user_id = new.user_id and place_id = pl.id;
        end if;
      end if;
    end if;
    -- Band (straal..straal+50): niets doen.
  end loop;

  return new;
end;
$$;

drop trigger if exists member_locations_geofence on public.member_locations;
create trigger member_locations_geofence
  after insert or update on public.member_locations
  for each row execute function public.evaluate_geofences();

revoke execute on function public.evaluate_geofences() from public, anon, authenticated;
revoke execute on function public.enforce_place_limit() from public, anon, authenticated;

-- ─── Row Level Security ──────────────────────────────────────────────────────

alter table public.places         enable row level security;
alter table public.place_presence enable row level security;

-- Iedereen in de familie mag plaatsen lezen, toevoegen, wijzigen en verwijderen.
drop policy if exists "plaatsen: familie lezen" on public.places;
create policy "plaatsen: familie lezen" on public.places
  for select using (public.is_family_member(family_id));

drop policy if exists "plaatsen: familie toevoegen" on public.places;
create policy "plaatsen: familie toevoegen" on public.places
  for insert with check (public.is_family_member(family_id) and created_by = auth.uid());

drop policy if exists "plaatsen: familie wijzigen" on public.places;
create policy "plaatsen: familie wijzigen" on public.places
  for update using (public.is_family_member(family_id)) with check (public.is_family_member(family_id));

drop policy if exists "plaatsen: familie verwijderen" on public.places;
create policy "plaatsen: familie verwijderen" on public.places
  for delete using (public.is_family_member(family_id));

-- place_presence wordt enkel door de trigger geschreven; leden lezen enkel.
drop policy if exists "aanwezigheid: familie lezen" on public.place_presence;
create policy "aanwezigheid: familie lezen" on public.place_presence
  for select using (public.is_family_member(family_id));

-- ─── Realtime ────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'places'
  ) then
    alter publication supabase_realtime add table public.places;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'place_presence'
  ) then
    alter publication supabase_realtime add table public.place_presence;
  end if;
end;
$$;
