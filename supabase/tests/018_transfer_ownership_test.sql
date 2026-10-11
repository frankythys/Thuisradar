-- Tests voor migratie 018: beheer overdragen.

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

create function pg_temp.role_of(id text) returns text language sql as $$
  select role from family_members where user_id = id::uuid;
$$;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-0000000018a1'), ('00000000-0000-0000-0000-0000000018b2'),
  ('00000000-0000-0000-0000-0000000018c3');
insert into profiles (id, display_name) values
  ('00000000-0000-0000-0000-0000000018a1', 'Papa'), ('00000000-0000-0000-0000-0000000018b2', 'Mama'),
  ('00000000-0000-0000-0000-0000000018c3', 'Buitenstaander');

select pg_temp.as_user('00000000-0000-0000-0000-0000000018a1');
create temp table gezin18 as select * from create_family('Gezin 018');
select pg_temp.as_user('00000000-0000-0000-0000-0000000018b2');
select join_family((select invite_code from gezin18));

-- ─── Weigeringen ────────────────────────────────────────────────────────────

select pg_temp.check(
  pg_temp.error_of(format('select transfer_ownership(%L, %L)', (select id from gezin18),
    '00000000-0000-0000-0000-0000000018b2')) like '%Enkel de beheerder%',
  'een gewoon lid kan het beheer niet naar zichzelf halen'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000018a1');
select pg_temp.check(
  pg_temp.error_of(format('select transfer_ownership(%L, %L)', (select id from gezin18),
    '00000000-0000-0000-0000-0000000018c3')) like '%geen lid%',
  'beheer gaat niet naar iemand buiten het gezin'
);
select pg_temp.check(
  pg_temp.error_of(format('select transfer_ownership(%L, %L)', (select id from gezin18),
    '00000000-0000-0000-0000-0000000018a1')) like '%al beheerder%',
  'overdragen aan jezelf kan niet'
);
select pg_temp.check(pg_temp.role_of('00000000-0000-0000-0000-0000000018a1') = 'owner', 'papa is nog beheerder');

-- ─── Overdragen ─────────────────────────────────────────────────────────────

select transfer_ownership((select id from gezin18), '00000000-0000-0000-0000-0000000018b2');
select pg_temp.check(pg_temp.role_of('00000000-0000-0000-0000-0000000018b2') = 'owner', 'mama is nu beheerder');
select pg_temp.check(pg_temp.role_of('00000000-0000-0000-0000-0000000018a1') = 'member', 'papa is nu gezinslid');
select pg_temp.check(
  (select count(*) = 1 from family_members where family_id = (select id from gezin18) and role = 'owner'),
  'er is precies één beheerder'
);
select pg_temp.check(
  pg_temp.error_of(format('select rotate_invite_code(%L)', (select id from gezin18))) like '%beheerder%',
  'de vorige beheerder kan de code niet meer vernieuwen'
);
select pg_temp.as_user('00000000-0000-0000-0000-0000000018b2');
select pg_temp.check(
  pg_temp.error_of(format('select rotate_invite_code(%L)', (select id from gezin18))) is null,
  'de nieuwe beheerder kan de code vernieuwen'
);
