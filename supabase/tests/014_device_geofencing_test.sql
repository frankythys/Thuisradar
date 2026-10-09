-- Tests voor migratie 014: toestel + server detecteren, maar één aankomst of
-- vertrek = één family_events-rij = één push.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.upload(u uuid, f uuid, lat double precision, lng double precision, at timestamptz)
returns void language sql as $$
  insert into member_locations (user_id, family_id, lat, lng, accuracy_m, updated_at)
  values (u, f, lat, lng, 10, at)
  on conflict (user_id) do update
    set lat = excluded.lat, lng = excluded.lng, accuracy_m = excluded.accuracy_m, updated_at = excluded.updated_at;
$$;

create function pg_temp.events(p uuid, t text) returns bigint language sql as $$
  select count(*) from family_events where place_id = p and type = t;
$$;

create function pg_temp.pushes() returns bigint language sql as $$
  select count(*) from net.calls where url like '%send-place-push';
$$;

-- ─── Opzet: Papa, gezin, Thuis en Werk ──────────────────────────────────────

insert into auth.users (id) values ('00000000-0000-0000-0000-00000000000a'), ('00000000-0000-0000-0000-00000000000b');
insert into profiles (id, display_name) values
  ('00000000-0000-0000-0000-00000000000a', 'Papa'),
  ('00000000-0000-0000-0000-00000000000b', 'Vreemde');
insert into families (id, name, invite_code, created_by)
  values ('00000000-0000-0000-0000-0000000000f1', 'Gezin', 'ABC123', '00000000-0000-0000-0000-00000000000a');
insert into family_members (family_id, user_id)
  values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into places (id, family_id, name, lat, lng, radius_m, created_by) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 'Thuis', 51.0, 4.0, 150,
   '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000f1', 'Werk', 51.2, 4.4, 150,
   '00000000-0000-0000-0000-00000000000a');

select register_geofence_device('papa-toestel-sleutel-0123456789abcdef');
select pg_temp.check(
  (select count(*) = 1 and bool_and(key_hash <> 'papa-toestel-sleutel-0123456789abcdef') from geofence_devices),
  'toestelsleutel bewaard als hash'
);

-- ─── Echte situatie: thuis om 17:40, servermelding pas om 18:16 ─────────────
-- Papa rijdt naar huis (laatste upload ver weg), de app slaapt. Het toestel
-- meldt de aankomst om "17:40" (nu). Pas om "18:16" (36 min later) komt de
-- eerste upload binnen de zone: die mag géén tweede melding geven.

select pg_temp.upload('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
  51.1, 4.2, now() - interval '50 minutes');

select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'arrival', 51.0, 4.0, now()) = 'recorded',
  'toestel meldt aankomst om 17:40'
);
select pg_temp.upload('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
  51.0, 4.0, now() + interval '36 minutes');

select pg_temp.check(pg_temp.events('00000000-0000-0000-0000-0000000000c1', 'arrival') = 1,
  'één aankomst-rij voor Thuis');
select pg_temp.check(
  (select source = 'device' and created_at <= now() from family_events
   where place_id = '00000000-0000-0000-0000-0000000000c1' and type = 'arrival'),
  'aankomst draagt het tijdstip van 17:40 en bron device'
);
select pg_temp.check(pg_temp.pushes() = 1, 'één push voor de aankomst');

-- Toestel meldt dezelfde aankomst nog eens (bv. herstart na reboot).
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'arrival', 51.0, 4.0, now()) = 'already_inside',
  'tweede aankomst van het toestel wordt genegeerd'
);

-- ─── Vertrek: toestel eerst, daarna bevestigt de server ─────────────────────

select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'departure', 51.003, 4.0, now()) = 'recorded',
  'toestel meldt vertrek'
);
select pg_temp.upload('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
  51.01, 4.0, now() + interval '37 minutes');
select pg_temp.upload('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
  51.02, 4.0, now() + interval '38 minutes');
select pg_temp.check(pg_temp.events('00000000-0000-0000-0000-0000000000c1', 'departure') = 1,
  'één vertrek-rij voor Thuis');
select pg_temp.check(pg_temp.pushes() = 2, 'één push voor het vertrek');

-- ─── Server eerst, toestel daarna ───────────────────────────────────────────

select pg_temp.upload('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
  51.2, 4.4, now());
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c2',
    'arrival', 51.2, 4.4, now()) = 'already_inside',
  'toestel na server: geen tweede aankomst op Werk'
);
select pg_temp.check(pg_temp.events('00000000-0000-0000-0000-0000000000c2', 'arrival') = 1,
  'één aankomst-rij voor Werk');
select pg_temp.check(pg_temp.pushes() = 3, 'één push voor Werk');

-- ─── Wedloop: beide schrijven tegelijk een rij → dedup-venster ──────────────

insert into family_events (family_id, actor_user_id, type, place_id, created_at, source)
values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a', 'arrival',
        '00000000-0000-0000-0000-0000000000c2', now() + interval '2 minutes', 'device');
select pg_temp.check(pg_temp.events('00000000-0000-0000-0000-0000000000c2', 'arrival') = 1,
  'rij binnen 5 minuten wordt geweigerd');
select pg_temp.check(pg_temp.pushes() = 3, 'geweigerde rij geeft geen push');

insert into family_events (family_id, actor_user_id, type, place_id, created_at)
values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a', 'arrival',
        '00000000-0000-0000-0000-0000000000c2', now() + interval '6 minutes');
select pg_temp.check(pg_temp.events('00000000-0000-0000-0000-0000000000c2', 'arrival') = 2,
  'rij na 6 minuten mag wel');

insert into family_events (family_id, actor_user_id, type, created_at)
values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a', 'sos', now());
insert into family_events (family_id, actor_user_id, type, created_at)
values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a', 'sos', now());
select pg_temp.check((select count(*) = 2 from family_events where type = 'sos'), 'SOS wordt nooit ontdubbeld');

-- ─── Beveiliging en randgevallen ────────────────────────────────────────────

select pg_temp.check(
  record_geofence_event('verkeerde-sleutel', '00000000-0000-0000-0000-0000000000c1', 'arrival') = 'unknown_device',
  'onbekende sleutel wordt geweigerd'
);
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'arrival', null, null, now() - interval '2 hours') = 'stale',
  'te oude gebeurtenis wordt geweigerd'
);
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'dwell') = 'invalid_type',
  'onbekend type wordt geweigerd'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select register_geofence_device('vreemde-toestel-sleutel-0123456789abcdef');
select pg_temp.check(
  record_geofence_event('vreemde-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'arrival') = 'not_member',
  'geen lid van het gezin = geweigerd'
);

-- Vertrek dat ouder is dan de huidige aankomst = verouderd.
select pg_temp.upload('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
  51.0, 4.0, now());
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'departure', null, null, now() - interval '10 minutes') = 'stale',
  'oud vertrek na een nieuwere aankomst wordt geweigerd'
);

-- Meldingen uit voor aankomst: aanwezigheid klopt, maar geen rij.
update places set notify_arrival = false where id = '00000000-0000-0000-0000-0000000000c1';
update place_presence set is_inside = false where place_id = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'arrival') = 'not_watched',
  'aankomstmeldingen uit = geen melding'
);

-- Afmelden: de sleutel werkt niet meer.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select unregister_geofence_device('papa-toestel-sleutel-0123456789abcdef');
select pg_temp.check(
  record_geofence_event('papa-toestel-sleutel-0123456789abcdef', '00000000-0000-0000-0000-0000000000c1',
    'departure') = 'unknown_device',
  'na afmelden is de sleutel ongeldig'
);
