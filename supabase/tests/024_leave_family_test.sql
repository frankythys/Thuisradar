-- Tests voor migratie 024: zelf het gezin verlaten.

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

create function pg_temp.is_member(id text) returns boolean language sql as $$
  select exists (select 1 from family_members where user_id = id::uuid);
$$;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000024a1'), ('00000000-0000-0000-0000-0000000024b2'),
  ('00000000-0000-0000-0000-0000000024c3');
insert into profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000024a1', 'Papa'), ('00000000-0000-0000-0000-0000000024b2', 'Mama'),
  ('00000000-0000-0000-0000-0000000024c3', 'Buitenstaander');

select pg_temp.as_user('00000000-0000-0000-0000-0000000024a1');
create temp table gezin24 as select * from create_family('Gezin 024');
select pg_temp.as_user('00000000-0000-0000-0000-0000000024b2');
select join_family((select invite_code from gezin24));
insert into member_locations (user_id, family_id, lat, lng)
values ('00000000-0000-0000-0000-0000000024b2', (select id from gezin24), 51, 4);

-- ─── Weigeringen ────────────────────────────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000024c3');
select pg_temp.check(
  pg_temp.error_of(format('select leave_family(%L)', (select id from gezin24))) like '%geen lid%',
  'wie geen lid is, kan niet vertrekken'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000024a1');
select pg_temp.check(
  pg_temp.error_of(format('select leave_family(%L)', (select id from gezin24))) like '%beheer over%',
  'de beheerder vertrekt niet zolang er nog iemand in het gezin zit'
);
select pg_temp.check(pg_temp.is_member('00000000-0000-0000-0000-0000000024a1'), 'papa is nog lid');

-- ─── Een gewoon lid vertrekt ────────────────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000024b2');
select leave_family((select id from gezin24));
select pg_temp.check(not pg_temp.is_member('00000000-0000-0000-0000-0000000024b2'), 'mama is geen lid meer');
select pg_temp.check(
  not exists (select 1 from member_locations where user_id = '00000000-0000-0000-0000-0000000024b2'),
  'de laatste locatie van mama is weg'
);
select pg_temp.check(
  (select invite_expires_at > now() from families where id = (select id from gezin24)),
  'de code blijft geldig zolang er nog iemand in het gezin zit'
);

-- ─── De beheerder vertrekt als laatste ──────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000024a1');
select leave_family((select id from gezin24));
select pg_temp.check(not pg_temp.is_member('00000000-0000-0000-0000-0000000024a1'), 'papa is als laatste vertrokken');
select pg_temp.check(
  (select invite_expires_at <= now() from families where id = (select id from gezin24)),
  'een leeg gezin heeft geen geldige code meer'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000024c3');
select pg_temp.check(
  pg_temp.error_of(format('select join_family(%L)', (select invite_code from gezin24))) like '%verlopen%',
  'niemand komt nog binnen in een leeg gezin'
);

-- ─── Rechtstreeks verwijderen kan niet meer ─────────────────────────────────

select pg_temp.check(
  not exists (
    select 1 from pg_policies
    where tablename = 'family_members' and policyname = 'leden: zelf verlaten'
  ),
  'de policy voor een rechtstreekse delete is weg'
);
