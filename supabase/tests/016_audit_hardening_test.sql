-- Tests voor migratie 016: een te laat aangekomen, ouder locatiepunt zet de
-- huidige plek niet terug, maar komt wel in de geschiedenis.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.upload(lat double precision, at timestamptz) returns void language sql as $$
  insert into member_locations (user_id, family_id, lat, lng, accuracy_m, updated_at)
  values ('00000000-0000-0000-0000-0000000016a1', '00000000-0000-0000-0000-0000000016f1', lat, 4.0, 10, at)
  on conflict (user_id) do update
    set lat = excluded.lat, lng = excluded.lng, accuracy_m = excluded.accuracy_m, updated_at = excluded.updated_at;
$$;

create function pg_temp.current_lat() returns double precision language sql as $$
  select lat from member_locations where user_id = '00000000-0000-0000-0000-0000000016a1';
$$;

create function pg_temp.history() returns bigint language sql as $$
  select count(*) from location_history where user_id = '00000000-0000-0000-0000-0000000016a1';
$$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000016a1');
insert into profiles (id, display_name) values ('00000000-0000-0000-0000-0000000016a1', 'Liam');
insert into families (id, name, invite_code, created_by)
  values ('00000000-0000-0000-0000-0000000016f1', 'Gezin 016', 'AUD016', '00000000-0000-0000-0000-0000000016a1');
insert into family_members (family_id, user_id)
  values ('00000000-0000-0000-0000-0000000016f1', '00000000-0000-0000-0000-0000000016a1');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000016a1', false);

-- ─── Volgorde ───────────────────────────────────────────────────────────────

select pg_temp.upload(51.10, now() - interval '10 seconds');
select pg_temp.upload(51.20, now() - interval '5 seconds');
select pg_temp.check(pg_temp.current_lat() = 51.20, 'nieuwer punt wordt de huidige plek');
select pg_temp.check(pg_temp.history() = 2, 'beide punten in de geschiedenis');

select pg_temp.upload(51.15, now() - interval '8 seconds');
select pg_temp.check(pg_temp.current_lat() = 51.20, 'ouder punt zet de kaart niet terug');
select pg_temp.check(pg_temp.history() = 3, 'ouder punt staat wel in de geschiedenis');

select pg_temp.upload(51.20, (select updated_at from member_locations
  where user_id = '00000000-0000-0000-0000-0000000016a1'));
select pg_temp.check(pg_temp.history() = 3, 'dubbele upload geeft geen dubbele geschiedenisrij');

-- Een toestelklok die voorliep: het oude tijdstip ligt in de toekomst.
update member_locations set updated_at = now() + interval '1 hour'
  where user_id = '00000000-0000-0000-0000-0000000016a1';
select pg_temp.upload(51.30, now());
select pg_temp.check(pg_temp.current_lat() = 51.30, 'na een voorlopende klok bevriest de kaart niet');

-- ─── SOS-policy en functies ─────────────────────────────────────────────────

select pg_temp.check(
  (select with_check like '%resolved%' from pg_policies
   where tablename = 'sos_alerts' and policyname = 'sos: zelf oplossen'),
  'SOS kan enkel naar opgelost'
);
select pg_temp.check(
  (select proconfig is not null from pg_proc where proname = 'geo_distance_m'),
  'geo_distance_m heeft een vaste search_path'
);
select pg_temp.check(
  abs(geo_distance_m(51.0, 4.0, 51.001, 4.0) - 111.2) < 1,
  'geo_distance_m rekent nog correct'
);
insert into places (family_id, name, lat, lng, radius_m, created_by) values
  ('00000000-0000-0000-0000-0000000016f1', 'School', 51.0, 4.0, 80, '00000000-0000-0000-0000-0000000016a1');
select pg_temp.check(true, 'plaatslimiet-trigger werkt nog met vaste search_path');
