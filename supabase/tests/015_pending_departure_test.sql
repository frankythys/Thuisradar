-- Tests voor migratie 015: een vertrek vanop het toestel telt pas als er binnen
-- 3 minuten geen teken komt dat je toch nog thuis bent.
-- Echte situatie 10/10 10:12: Thuis (straal 60 m), app-GPS op 6 m, maar Android
-- meldde vertrek op 147 m en 6 s later aankomst op 132 m: twee valse meldingen.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.upload(lat double precision, at timestamptz) returns void language sql as $$
  insert into member_locations (user_id, family_id, lat, lng, accuracy_m, updated_at)
  values ('00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-0000000000f5', lat, 4.0, 10, at)
  on conflict (user_id) do update
    set lat = excluded.lat, lng = excluded.lng, accuracy_m = excluded.accuracy_m, updated_at = excluded.updated_at;
$$;

create function pg_temp.device(t text, lat double precision, at timestamptz) returns text language sql as $$
  select record_geofence_event('franky-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c5',
    t, lat, 4.0, at);
$$;

create function pg_temp.departures() returns bigint language sql as $$
  select count(*) from family_events where place_id = '00000000-0000-0000-0000-0000000000c5' and type = 'departure';
$$;

create function pg_temp.inside() returns boolean language sql as $$
  select is_inside from place_presence
  where user_id = '00000000-0000-0000-0000-0000000000a5' and place_id = '00000000-0000-0000-0000-0000000000c5';
$$;

-- ─── Opzet: Franky, eigen gezin, Thuis met straal 60 m ──────────────────────

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000000a5');
insert into profiles (id, display_name) values ('00000000-0000-0000-0000-0000000000a5', 'Franky');
insert into families (id, name, invite_code, created_by)
  values ('00000000-0000-0000-0000-0000000000f5', 'Gezin Franky', 'FRK015', '00000000-0000-0000-0000-0000000000a5');
insert into family_members (family_id, user_id)
  values ('00000000-0000-0000-0000-0000000000f5', '00000000-0000-0000-0000-0000000000a5');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a5', false);
insert into places (id, family_id, name, lat, lng, radius_m, created_by) values
  ('00000000-0000-0000-0000-0000000000c5', '00000000-0000-0000-0000-0000000000f5', 'Thuis', 51.0, 4.0, 60,
   '00000000-0000-0000-0000-0000000000a5');
select register_geofence_device('franky-toestel-sleutel-0123456789abcdef');

-- Franky is al een tijd thuis.
select pg_temp.upload(51.0, now() - interval '20 minutes');
select pg_temp.check(pg_temp.inside(), 'Franky staat thuis');
delete from net.calls;

-- ─── 10:12:38 vertrek op 147 m, 10:12:44 aankomst op 132 m, 10:12:48 app op 6 m

select pg_temp.check(pg_temp.device('departure', 51.0 + 147 / 111320.0, now() - interval '10 seconds') = 'pending',
  'vertrek op 147 m wacht op bevestiging');
select pg_temp.check(pg_temp.departures() = 0, 'nog geen vertrek-rij');
select pg_temp.check(pg_temp.inside(), 'nog steeds thuis');
select pg_temp.check(pg_temp.device('arrival', 51.0 + 132 / 111320.0, now() - interval '4 seconds') = 'already_inside',
  'aankomst 6 s later: was nooit weg');
select pg_temp.upload(51.0 + 6 / 111320.0, now());
select confirm_pending_departures();
select pg_temp.check(pg_temp.departures() = 0, 'geen vals vertrek');
select pg_temp.check((select count(*) = 0 from net.calls), 'geen enkele push');
select pg_temp.check(pg_temp.inside(), 'Franky blijft thuis');

-- ─── Vertrek, daarna nog een upload in de buurt van het huis ────────────────

select pg_temp.check(pg_temp.device('departure', 51.0 + 147 / 111320.0, now() - interval '5 minutes') = 'pending',
  'tweede vals vertrek wacht');
select pg_temp.upload(51.0 + 80 / 111320.0, now() - interval '1 minute');
select confirm_pending_departures();
select pg_temp.check(pg_temp.departures() = 0 and pg_temp.inside(), 'upload op 80 m (binnen straal + 50) houdt je thuis');

-- ─── Echt vertrek met slapende app: na 3 minuten toch gemeld ────────────────
-- Laatste upload van vóór het vertrek; daarna slaapt de app.
select pg_temp.upload(51.0, now() - interval '10 minutes');

select pg_temp.check(pg_temp.device('departure', 51.0 + 400 / 111320.0, now() - interval '2 minutes') = 'pending',
  'echt vertrek wacht eerst');
select confirm_pending_departures();
select pg_temp.check(pg_temp.departures() = 0, 'na 2 minuten nog niets');
update place_presence set outside_since = now() - interval '4 minutes'
  where user_id = '00000000-0000-0000-0000-0000000000a5' and place_id = '00000000-0000-0000-0000-0000000000c5';
select confirm_pending_departures();
select pg_temp.check(pg_temp.departures() = 1, 'na 3 minuten zonder thuis-teken: één vertrek');
select pg_temp.check(not pg_temp.inside(), 'Franky staat buiten');
select pg_temp.check(
  (select abs(extract(epoch from created_at - (now() - interval '4 minutes'))) < 5 from family_events
   where place_id = '00000000-0000-0000-0000-0000000000c5' and type = 'departure'),
  'vertrek draagt het tijdstip van het toestel'
);
select pg_temp.check((select count(*) = 1 from net.calls where url like '%send-place-push'), 'één push');
select confirm_pending_departures();
select pg_temp.check(pg_temp.departures() = 1, 'nogmaals bevestigen geeft geen tweede vertrek');
