-- Tests voor migratie 025: geschiedenis mee bij vertrek, bewaartermijn,
-- sterkere uitnodigingscodes met poginglimiet en account verwijderen.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.as_user(id text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', id, false);
$$;

create function pg_temp.error_of(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return null;
exception when others then
  return sqlerrm;
end;
$$;

create function pg_temp.history_of(id text) returns bigint language sql as $$
  select count(*) from location_history where user_id = id::uuid;
$$;

-- a1 = beheerder, b2 = lid dat vertrekt, c3 = lid dat verwijderd wordt,
-- d4 = probeert codes te raden, e5 = verwijdert zijn account.
insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000025a1'), ('00000000-0000-0000-0000-0000000025b2'),
  ('00000000-0000-0000-0000-0000000025c3'), ('00000000-0000-0000-0000-0000000025d4'),
  ('00000000-0000-0000-0000-0000000025e5');
insert into profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000025a1', 'Papa'), ('00000000-0000-0000-0000-0000000025b2', 'Mama'),
  ('00000000-0000-0000-0000-0000000025c3', 'Liam'), ('00000000-0000-0000-0000-0000000025d4', 'Rader'),
  ('00000000-0000-0000-0000-0000000025e5', 'Oma');

select pg_temp.as_user('00000000-0000-0000-0000-0000000025a1');
create temp table gezin25 as select * from create_family('Gezin 025');

select pg_temp.check(
  (select invite_code from gezin25) ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$',
  'nieuwe code: 8 tekens zonder 0/O/1/I'
);

do $$
begin
  for i in 1..200 loop
    if public.new_invite_code() !~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$' then
      raise exception 'MISLUKT: ongeldige code';
    end if;
  end loop;
end;
$$;
select pg_temp.check(true, '200 willekeurige codes hebben het juiste formaat');

-- Iedereen behalve de rader joint.
select pg_temp.as_user('00000000-0000-0000-0000-0000000025b2');
select join_family((select invite_code from gezin25));
select pg_temp.as_user('00000000-0000-0000-0000-0000000025c3');
select join_family((select invite_code from gezin25));
select pg_temp.as_user('00000000-0000-0000-0000-0000000025e5');
select join_family((select invite_code from gezin25));

-- Locaties uploaden: de trigger schrijft de geschiedenis.
insert into member_locations (user_id, family_id, lat, lng, updated_at)
select u::uuid, (select id from gezin25), 51, 4, now()
from unnest(array[
  '00000000-0000-0000-0000-0000000025a1', '00000000-0000-0000-0000-0000000025b2',
  '00000000-0000-0000-0000-0000000025c3', '00000000-0000-0000-0000-0000000025e5'
]) as u;
select pg_temp.check(pg_temp.history_of('00000000-0000-0000-0000-0000000025b2') > 0, 'geschiedenis geschreven');

-- ─── 1. Vertrekken en verwijderen ───────────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000025b2');
select leave_family((select id from gezin25));
select pg_temp.check(pg_temp.history_of('00000000-0000-0000-0000-0000000025b2') = 0, 'vertrek wist eigen geschiedenis');
select pg_temp.check(pg_temp.history_of('00000000-0000-0000-0000-0000000025a1') > 0, 'geschiedenis van anderen blijft');

select pg_temp.as_user('00000000-0000-0000-0000-0000000025a1');
select remove_member((select id from gezin25), '00000000-0000-0000-0000-0000000025c3');
select pg_temp.check(pg_temp.history_of('00000000-0000-0000-0000-0000000025c3') = 0, 'verwijderen wist geschiedenis');

-- ─── 2. Bewaartermijn ───────────────────────────────────────────────────────

select pg_temp.check(
  exists (select 1 from cron.jobs where name = 'thuisradar-history-cleanup' and command like '%31 days%'),
  'nachtelijke opruimtaak gepland (31 dagen)'
);
select pg_temp.check(
  exists (select 1 from cron.jobs where name = 'thuisradar-join-attempts-cleanup'),
  'opruimtaak voor codepogingen gepland'
);

-- ─── 3. Poginglimiet ────────────────────────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000025d4');
select pg_temp.check((join_family('ZZZZZZZZ')).id is null, 'foute code geeft null');
select join_family('ZZZZZZZY');
select join_family('ZZZZZZZX');
select join_family('ZZZZZZZW');
select join_family('ZZZZZZZV');
select pg_temp.check(
  pg_temp.error_of($q$select join_family('ZZZZZZZU')$q$) like 'Te veel foute codes%',
  'zesde poging binnen het kwartier geweigerd'
);
select pg_temp.check(
  pg_temp.error_of(format($q$select join_family(%L)$q$, (select invite_code from families where id = (select id from gezin25))))
    like 'Te veel foute codes%',
  'ook een goede code wacht tot het kwartier voorbij is'
);
update join_attempts set attempted_at = now() - interval '16 minutes'
where user_id = '00000000-0000-0000-0000-0000000025d4';
select pg_temp.check((join_family('ZZZZZZZT')).id is null, 'na een kwartier weer proberen');

-- ─── 4. Account verwijderen ─────────────────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000025a1');
select pg_temp.check(
  pg_temp.error_of('select delete_my_account()') like 'Draag eerst het beheer over%',
  'beheerder met andere leden moet eerst overdragen'
);

insert into places (family_id, name, lat, lng, radius_m, created_by)
values ((select id from gezin25), 'Bij oma', 51, 4, 100, '00000000-0000-0000-0000-0000000025e5');

select pg_temp.as_user('00000000-0000-0000-0000-0000000025e5');
select delete_my_account();
select pg_temp.check(
  not exists (select 1 from auth.users where id = '00000000-0000-0000-0000-0000000025e5'),
  'account is weg'
);
select pg_temp.check(
  not exists (select 1 from family_members where user_id = '00000000-0000-0000-0000-0000000025e5'),
  'lidmaatschap is weg'
);
select pg_temp.check(pg_temp.history_of('00000000-0000-0000-0000-0000000025e5') = 0, 'geschiedenis is weg');
select pg_temp.check(
  not exists (select 1 from member_locations where user_id = '00000000-0000-0000-0000-0000000025e5'),
  'laatste locatie is weg'
);
select pg_temp.check(
  exists (select 1 from places where name = 'Bij oma' and created_by is null),
  'gedeelde plaats blijft, zonder maker'
);
select pg_temp.check(exists (select 1 from families where id = (select id from gezin25)), 'gezin blijft bestaan');

-- De beheerder is nu alleen: dan mag hij weg, en zijn gezin verdwijnt mee.
select pg_temp.as_user('00000000-0000-0000-0000-0000000025a1');
select delete_my_account();
select pg_temp.check(not exists (select 1 from families where id = (select id from gezin25)), 'laatste lid weg: gezin weg');
select pg_temp.check(not exists (select 1 from places where name = 'Bij oma'), 'plaatsen van het gezin weg');

select pg_temp.as_user('');
select pg_temp.check(pg_temp.error_of('select delete_my_account()') like 'Niet ingelogd%', 'zonder login geweigerd');
