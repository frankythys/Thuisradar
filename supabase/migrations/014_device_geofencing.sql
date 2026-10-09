-- Spoor A: aankomst/vertrek ook vanop het toestel (native geofencing).
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
-- schema.sql en eerdere migraties blijven ongewijzigd.
--
-- Twee detectoren, één melding:
--   * de server (evaluate_geofences, migratie 005/009) blijft detecteren;
--   * het toestel meldt via record_geofence_event (deze migratie).
-- Beide schrijven in family_events. Een BEFORE INSERT-trigger laat per
-- (gebruiker, plaats, type) maar één rij door binnen 5 minuten. Een geweigerde
-- rij geeft ook geen push, want send-place-push hangt aan AFTER INSERT.

-- ─── 1. Bron van een gebeurtenis ────────────────────────────────────────────

alter table public.family_events
  add column if not exists source text not null default 'server';

alter table public.family_events
  drop constraint if exists family_events_source_check;
alter table public.family_events
  add constraint family_events_source_check check (source in ('server', 'device'));

create index if not exists family_events_dedup_idx
  on public.family_events (actor_user_id, place_id, type, created_at desc);

-- ─── 2. Ontdubbelen: één aankomst/vertrek = één rij = één push ───────────────

create or replace function public.dedupe_place_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type not in ('arrival', 'departure') or new.place_id is null then
    return new;
  end if;

  -- Toestel en server kunnen tegelijk schrijven: één tegelijk per sleutel.
  perform pg_advisory_xact_lock(
    hashtext('place_event:' || new.actor_user_id::text || ':' || new.place_id::text || ':' || new.type)
  );

  if exists (
    select 1 from family_events e
    where e.actor_user_id = new.actor_user_id
      and e.place_id = new.place_id
      and e.type = new.type
      and e.created_at between new.created_at - interval '5 minutes'
                           and new.created_at + interval '5 minutes'
  ) then
    return null; -- dubbel: niet bewaren, geen push
  end if;

  return new;
end;
$$;

drop trigger if exists family_events_dedupe on public.family_events;
create trigger family_events_dedupe
  before insert on public.family_events
  for each row execute function public.dedupe_place_event();

revoke execute on function public.dedupe_place_event() from public, anon, authenticated;

-- ─── 3. Toestelsleutels ─────────────────────────────────────────────────────
-- De achtergrond-callback van de app heeft geen ingelogde sessie. Daarom
-- registreert de app (ingelogd) een willekeurige sleutel per toestel; de
-- callback stuurt die sleutel mee. We bewaren enkel de SHA-256 ervan.

create table if not exists public.geofence_devices (
  key_hash     text primary key,
  user_id      uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  last_used_at timestamptz
);

create index if not exists geofence_devices_user_idx on public.geofence_devices (user_id);

-- Geen policies: enkel bereikbaar via de functies hieronder.
alter table public.geofence_devices enable row level security;

create or replace function public.geofence_key_hash(p_key text)
returns text
language sql
immutable
as $$
  select encode(sha256(convert_to(coalesce(p_key, ''), 'UTF8')), 'hex');
$$;

create or replace function public.register_geofence_device(p_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Niet ingelogd';
  end if;
  if p_key is null or char_length(p_key) < 32 then
    raise exception 'Ongeldige toestelsleutel';
  end if;
  insert into geofence_devices (key_hash, user_id)
  values (geofence_key_hash(p_key), auth.uid())
  on conflict (key_hash) do update set user_id = excluded.user_id;
end;
$$;

create or replace function public.unregister_geofence_device(p_key text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from geofence_devices
  where key_hash = geofence_key_hash(p_key) and user_id = auth.uid();
$$;

-- ─── 4. Gebeurtenis vanop het toestel ───────────────────────────────────────
-- Zelfde regels als de server: watched_members en notify_arrival/departure.
-- Werkt place_presence bij, zodat de server daarna niet nog eens meldt
-- (bv. de upload van 18:16 terwijl het toestel 17:40 al "binnen" meldde).
-- Antwoord: recorded | duplicate | already_inside | already_outside |
--           not_watched | stale | unknown_device | unknown_place | not_member | invalid_type

create or replace function public.record_geofence_event(
  p_key      text,
  p_place_id uuid,
  p_type     text,
  p_lat      double precision default null,
  p_lng      double precision default null,
  p_at       timestamptz default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    uuid;
  v_at      timestamptz;
  v_rows    integer;
  pl        places%rowtype;
  pres      place_presence%rowtype;
  watched   boolean;
  notify    boolean;
begin
  if p_type not in ('arrival', 'departure') then
    return 'invalid_type';
  end if;

  select user_id into v_user from geofence_devices where key_hash = geofence_key_hash(p_key);
  if v_user is null then
    return 'unknown_device';
  end if;
  update geofence_devices set last_used_at = now() where key_hash = geofence_key_hash(p_key);

  select * into pl from places where id = p_place_id;
  if pl.id is null then
    return 'unknown_place';
  end if;
  if not exists (select 1 from family_members where family_id = pl.family_id and user_id = v_user) then
    return 'not_member';
  end if;

  -- Tijdstip van het toestel, maar nooit in de toekomst; te oud = verouderd.
  v_at := least(coalesce(p_at, now()), now());
  if v_at < now() - interval '30 minutes' then
    return 'stale';
  end if;

  select * into pres from place_presence
    where user_id = v_user and place_id = pl.id
    for update;

  watched := pl.watched_members is null
    or array_length(pl.watched_members, 1) is null
    or v_user = any (pl.watched_members);

  if p_type = 'arrival' then
    if pres.user_id is not null and pres.is_inside then
      update place_presence set outside_since = null, outside_count = 0, updated_at = now()
        where user_id = v_user and place_id = pl.id;
      return 'already_inside';
    end if;
    insert into place_presence (user_id, place_id, family_id, is_inside, since, outside_since, outside_count, updated_at)
    values (v_user, pl.id, pl.family_id, true, v_at, null, 0, now())
    on conflict (user_id, place_id) do update
      set is_inside = true, since = excluded.since, outside_since = null, outside_count = 0, updated_at = now();
    notify := pl.notify_arrival;
  else
    if pres.user_id is null or not pres.is_inside then
      return 'already_outside';
    end if;
    -- Vertrek van vóór de huidige aankomst = verouderd.
    if pres.since is not null and pres.since > v_at then
      return 'stale';
    end if;
    update place_presence
      set is_inside = false, since = null, outside_since = null, outside_count = 0, updated_at = now()
      where user_id = v_user and place_id = pl.id;
    notify := pl.notify_departure;
  end if;

  if not (watched and notify) then
    return 'not_watched';
  end if;

  insert into family_events (family_id, actor_user_id, type, place_id, lat, lng, created_at, source)
  values (pl.family_id, v_user, p_type, pl.id, p_lat, p_lng, v_at, 'device');
  get diagnostics v_rows = row_count;
  return case when v_rows = 0 then 'duplicate' else 'recorded' end;
end;
$$;

revoke execute on function public.register_geofence_device(text) from public, anon;
revoke execute on function public.unregister_geofence_device(text) from public, anon;
grant execute on function public.register_geofence_device(text) to authenticated;
grant execute on function public.unregister_geofence_device(text) to authenticated;

-- De callback gebruikt de publieke sleutel (anon); de toestelsleutel is het bewijs.
revoke execute on function public.record_geofence_event(text, uuid, text, double precision, double precision, timestamptz)
  from public;
grant execute on function public.record_geofence_event(text, uuid, text, double precision, double precision, timestamptz)
  to anon, authenticated;
