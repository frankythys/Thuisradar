-- Tests voor migratie 022: taal per profiel.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.error_of(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return null;
exception when others then
  return sqlerrm;
end;
$$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000022a1');
insert into profiles (id, display_name) values ('00000000-0000-0000-0000-0000000022a1', 'Mama');

select pg_temp.check(
  (select language from profiles where id = '00000000-0000-0000-0000-0000000022a1') is null,
  'nieuw profiel: nog geen taal'
);
update profiles set language = 'fr' where id = '00000000-0000-0000-0000-0000000022a1';
select pg_temp.check(
  (select language from profiles where id = '00000000-0000-0000-0000-0000000022a1') = 'fr',
  'een ondersteunde taal wordt bewaard'
);
select pg_temp.check(
  pg_temp.error_of($q$update profiles set language = 'xx' where id = '00000000-0000-0000-0000-0000000022a1'$q$)
    like '%profiles_language_check%',
  'een onbekende taal wordt geweigerd'
);
