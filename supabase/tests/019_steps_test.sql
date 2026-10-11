-- Tests voor migratie 019: de stappen gaan mee naar de geschiedenis, ook
-- voor een te laat aangekomen punt, en een negatieve teller wordt geweigerd.

create function pg_temp.check(ok boolean, msg text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'MISLUKT: %', msg; end if;
  raise notice 'ok: %', msg;
end;
$$;

create function pg_temp.upload(steps integer, at timestamptz) returns void language sql as $$
  insert into member_locations (user_id, family_id, lat, lng, accuracy_m, steps, updated_at)
  values ('00000000-0000-0000-0000-0000000019a1', '00000000-0000-0000-0000-0000000019f1', 51, 4.0, 10, steps, at)
  on conflict (user_id) do update
    set steps = excluded.steps, updated_at = excluded.updated_at;
$$;

insert into auth.users (id) values ('00000000-0000-0000-0000-0000000019a1');
insert into profiles (id, display_name) values ('00000000-0000-0000-0000-0000000019a1', 'Liam');
insert into families (id, name, invite_code, created_by)
  values ('00000000-0000-0000-0000-0000000019f1', 'Gezin 019', 'STP019', '00000000-0000-0000-0000-0000000019a1');
insert into family_members (family_id, user_id)
  values ('00000000-0000-0000-0000-0000000019f1', '00000000-0000-0000-0000-0000000019a1');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000019a1', false);

select pg_temp.upload(1200, now() - interval '10 seconds');
select pg_temp.upload(1210, now() - interval '5 seconds');
-- Te laat aangekomen: niet de huidige plek, wel in de geschiedenis.
select pg_temp.upload(1205, now() - interval '7 seconds');
-- Een oudere app stuurt geen stappen mee.
insert into member_locations (user_id, family_id, lat, lng, updated_at)
  values ('00000000-0000-0000-0000-0000000019a1', '00000000-0000-0000-0000-0000000019f1', 51, 4.0, now())
  on conflict (user_id) do update set steps = null, updated_at = excluded.updated_at;

select pg_temp.check(
  (select array_agg(steps order by recorded_at) from location_history
     where user_id = '00000000-0000-0000-0000-0000000019a1')
    is not distinct from array[1200, 1205, 1210, null]::integer[],
  'stappen in de geschiedenis, ook voor een te laat punt en zonder stappen');

do $$
begin
  perform pg_temp.upload(-1, now() + interval '1 second');
  raise exception 'MISLUKT: negatieve stappen aanvaard';
exception when check_violation then
  raise notice 'ok: negatieve stappen geweigerd';
end;
$$;
