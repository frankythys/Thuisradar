-- Tests voor migratie 017: uitnodigingscode vervalt en is te vernieuwen, en de
-- beheerder kan een lid verwijderen.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.as_user(id text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', id, false);
$$;

-- Geeft de foutmelding terug, of null als de opdracht lukte.
create function pg_temp.error_of(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return null;
exception when others then
  return sqlerrm;
end;
$$;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000017a1'), ('00000000-0000-0000-0000-0000000017b2'),
  ('00000000-0000-0000-0000-0000000017c3');
insert into profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000017a1', 'Beheerder'), ('00000000-0000-0000-0000-0000000017b2', 'Lid'),
  ('00000000-0000-0000-0000-0000000017c3', 'Indringer');

-- ─── Aanmaken en joinen ─────────────────────────────────────────────────────

select pg_temp.as_user('00000000-0000-0000-0000-0000000017a1');
create temp table gezin as select * from create_family('Gezin 017');
select pg_temp.check(
  (select invite_expires_at between now() + interval '6 days' and now() + interval '8 days' from gezin),
  'een nieuwe code is 7 dagen geldig'
);

select pg_temp.as_user('00000000-0000-0000-0000-0000000017b2');
select join_family((select invite_code from gezin));
select pg_temp.check(
  exists (select 1 from family_members where user_id = '00000000-0000-0000-0000-0000000017b2'
          and family_id = (select id from gezin)),
  'joinen met een geldige code lukt'
);

-- ─── Verlopen code ──────────────────────────────────────────────────────────

update families set invite_expires_at = now() - interval '1 minute' where id = (select id from gezin);
select pg_temp.as_user('00000000-0000-0000-0000-0000000017c3');
select pg_temp.check(
  pg_temp.error_of(format('select join_family(%L)', (select invite_code from gezin))) like '%verlopen%',
  'een verlopen code wordt geweigerd'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000017b2');
select pg_temp.check(
  pg_temp.error_of(format('select join_family(%L)', (select invite_code from gezin))) is null,
  'wie al lid is, mag de verlopen code nog eens invullen'
);

-- ─── Nieuwe code ────────────────────────────────────────────────────────────

select pg_temp.check(
  pg_temp.error_of(format('select rotate_invite_code(%L)', (select id from gezin))) like '%beheerder%',
  'een gewoon lid kan de code niet vernieuwen'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000017a1');
create temp table nieuw as select * from rotate_invite_code((select id from gezin));
select pg_temp.check((select invite_code from nieuw) <> (select invite_code from gezin), 'nieuwe code verschilt');
select pg_temp.check((select invite_expires_at > now() + interval '6 days' from nieuw), 'nieuwe code weer 7 dagen');
select pg_temp.as_user('00000000-0000-0000-0000-0000000017c3');
select pg_temp.check(
  pg_temp.error_of(format('select join_family(%L)', (select invite_code from gezin))) like '%Onbekende%',
  'de oude code werkt niet meer'
);
select join_family((select invite_code from nieuw));
select pg_temp.check(
  exists (select 1 from family_members where user_id = '00000000-0000-0000-0000-0000000017c3'),
  'met de nieuwe code lukt joinen'
);

-- ─── Lid verwijderen ────────────────────────────────────────────────────────

insert into member_locations (user_id, family_id, lat, lng, updated_at)
  values ('00000000-0000-0000-0000-0000000017c3', (select id from gezin), 51.0, 4.0, now());

select pg_temp.as_user('00000000-0000-0000-0000-0000000017b2');
select pg_temp.check(
  pg_temp.error_of(format('select remove_member(%L, %L)', (select id from gezin),
    '00000000-0000-0000-0000-0000000017c3')) like '%beheerder%',
  'een gewoon lid kan niemand verwijderen'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000017a1');
select pg_temp.check(
  pg_temp.error_of(format('select remove_member(%L, %L)', (select id from gezin),
    '00000000-0000-0000-0000-0000000017a1')) like '%jezelf%',
  'de beheerder kan zichzelf niet verwijderen'
);
select remove_member((select id from gezin), '00000000-0000-0000-0000-0000000017c3');
select pg_temp.check(
  not exists (select 1 from family_members where user_id = '00000000-0000-0000-0000-0000000017c3'),
  'het lid is uit het gezin'
);
select pg_temp.check(
  not exists (select 1 from member_locations where user_id = '00000000-0000-0000-0000-0000000017c3'),
  'het lid staat niet meer op de kaart'
);
select pg_temp.check(
  (select invite_code from families where id = (select id from gezin)) <> (select invite_code from nieuw),
  'verwijderen maakt meteen een nieuwe code'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000017c3');
select pg_temp.check(
  pg_temp.error_of(format('select join_family(%L)', (select invite_code from nieuw))) like '%Onbekende%',
  'de verwijderde persoon kan niet terug met de code die hij kende'
);
