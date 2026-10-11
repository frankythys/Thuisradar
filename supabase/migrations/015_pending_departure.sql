-- Vertrek vanop het toestel pas na bevestiging (geen valse meldingen meer).
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
-- schema.sql en eerdere migraties blijven ongewijzigd.
--
-- Waarom: op 10/10 om 10:12 stond Franky thuis (app-GPS op 6 m), maar Android
-- meldde één keer vertrek op 147 m en 6 s later aankomst op 132 m. Het toestel
-- telde dat meteen als vertrek, terwijl de server zelf twee metingen voorbij
-- straal + 50 m vraagt, of 3 minuten (evaluate_geofences, migratie 009).
--
-- Nu: een vertrek van het toestel zet de aanwezigheid op "wacht"
-- (outside_since). Komt er binnen 3 minuten een teken dat je nog thuis bent
-- (aankomst van het toestel, of een upload binnen straal + 50 m), dan vervalt
-- het. Een upload voorbij straal + 50 m bevestigt meteen (bestaande serverregel).
-- Anders bevestigt confirm_pending_departures() het na 3 minuten (pg_cron, elke
-- minuut). Een echt vertrek met slapende app komt zo hoogstens ±4 min later.

-- ─── 1. Vertrek van het toestel = wachtend ─────────────────────────────────

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
      -- Nog/weer binnen: een wachtend vertrek vervalt.
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
    -- Wachten op bevestiging, zoals de eerste meting buiten bij de server.
    if pres.outside_since is null then
      update place_presence set outside_since = v_at, outside_count = 1, updated_at = now()
        where user_id = v_user and place_id = pl.id;
    end if;
    return 'pending';
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

revoke execute on function public.record_geofence_event(text, uuid, text, double precision, double precision, timestamptz)
  from public;
grant execute on function public.record_geofence_event(text, uuid, text, double precision, double precision, timestamptz)
  to anon, authenticated;

-- ─── 2. Wachtende vertrekken na 3 minuten bevestigen ───────────────────────
-- Een upload ná het wachtende vertrek binnen straal + 50 m = toch thuis.

create or replace function public.confirm_pending_departures()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  r          record;
  v_count    integer := 0;
  still_home boolean;
  watched    boolean;
begin
  for r in
    select pp.user_id, pp.place_id, pp.family_id, pp.outside_since,
           pl.lat, pl.lng, pl.radius_m, pl.watched_members, pl.notify_departure
    from place_presence pp
    join places pl on pl.id = pp.place_id
    where pp.is_inside
      and pp.outside_since is not null
      and pp.outside_since <= now() - interval '3 minutes'
    for update of pp
  loop
    select exists (
      select 1 from member_locations ml
      where ml.user_id = r.user_id
        and ml.updated_at > r.outside_since
        and (ml.accuracy_m is null or ml.accuracy_m <= 100)
        and geo_distance_m(ml.lat, ml.lng, r.lat, r.lng) <= r.radius_m + 50
    ) into still_home;

    if still_home then
      update place_presence set outside_since = null, outside_count = 0, updated_at = now()
        where user_id = r.user_id and place_id = r.place_id;
      continue;
    end if;

    update place_presence
      set is_inside = false, since = null, outside_since = null, outside_count = 0, updated_at = now()
      where user_id = r.user_id and place_id = r.place_id;

    watched := r.watched_members is null
      or array_length(r.watched_members, 1) is null
      or r.user_id = any (r.watched_members);
    if watched and r.notify_departure then
      insert into family_events (family_id, actor_user_id, type, place_id, created_at, source)
      values (r.family_id, r.user_id, 'departure', r.place_id, r.outside_since, 'device');
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke execute on function public.confirm_pending_departures() from public, anon, authenticated;

-- ─── 3. Elke minuut laten lopen (pg_cron, gratis in Supabase) ──────────────

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule('confirm-pending-departures', '* * * * *',
                          'select public.confirm_pending_departures()');
  else
    raise notice 'pg_cron niet beschikbaar: wachtende vertrekken worden enkel door uploads bevestigd';
  end if;
end;
$$;
