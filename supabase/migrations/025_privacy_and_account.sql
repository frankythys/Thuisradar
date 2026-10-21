-- 025: privacy en accountverwijdering voor Google Play. Idempotent.
-- Uitvoeren in de Supabase SQL Editor, ná 024, en samen met de app-versie
-- die delete_my_account aanroept en een null-antwoord van join_family
-- begrijpt (een oudere app crasht op een foute code; een goede code werkt).
--
-- 1. Wie het gezin verlaat of verwijderd wordt, neemt zijn
--    locatiegeschiedenis mee: de achterblijvers zien die niet meer.
-- 2. Bewaartermijn: geschiedenis ouder dan 31 dagen wordt elke nacht gewist
--    (de app toont 30 dagen). Vraagt pg_cron (Database > Extensions; deze
--    migratie zet het zelf aan).
-- 3. Uitnodigingscodes: 8 tekens uit 32 (geen 0/O/1/I), 40 bits in plaats
--    van 32, en hoogstens 5 foute pogingen per kwartier per gebruiker.
--    Bestaande codes blijven geldig tot ze vernieuwd worden.
-- 4. delete_my_account(): wist het eigen account met alles wat eraan hangt.
--    De beheerder moet eerst het beheer overdragen zolang er nog anderen in
--    het gezin zitten (zelfde regel als leave_family). Foto's en
--    spraakberichten in Storage wist de app zelf (Storage API) vóór deze
--    aanroep; Supabase laat Storage niet rechtstreeks via SQL wissen.

-- ─── 1. Geschiedenis mee bij vertrekken en verwijderen ──────────────────────

create or replace function public.leave_family(fid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  my_role text;
begin
  if auth.uid() is null then
    raise exception 'Niet ingelogd';
  end if;

  select role into my_role from family_members where family_id = fid and user_id = auth.uid();
  if my_role is null then
    raise exception 'Je bent geen lid van dit gezin';
  end if;

  if my_role = 'owner' and exists (
    select 1 from family_members where family_id = fid and user_id <> auth.uid()
  ) then
    raise exception 'Draag eerst het beheer over aan een ander gezinslid';
  end if;

  delete from family_members where family_id = fid and user_id = auth.uid();
  delete from member_locations where family_id = fid and user_id = auth.uid();
  delete from place_presence where family_id = fid and user_id = auth.uid();
  delete from location_history where family_id = fid and user_id = auth.uid();

  if not exists (select 1 from family_members where family_id = fid) then
    update families set invite_expires_at = now() where id = fid;
  end if;
end;
$$;

create or replace function public.remove_member(fid uuid, member uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_family_owner(fid) then
    raise exception 'Enkel de beheerder kan iemand verwijderen';
  end if;
  if member = auth.uid() then
    raise exception 'Je kan jezelf niet verwijderen; gebruik "Familie verlaten"';
  end if;
  if exists (select 1 from family_members where family_id = fid and user_id = member and role = 'owner') then
    raise exception 'De beheerder kan niet verwijderd worden';
  end if;

  delete from family_members where family_id = fid and user_id = member;
  if not found then
    raise exception 'Deze persoon is geen lid van het gezin';
  end if;
  delete from member_locations where family_id = fid and user_id = member;
  delete from place_presence where family_id = fid and user_id = member;
  delete from location_history where family_id = fid and user_id = member;

  -- De oude code mag die persoon niet terugbrengen.
  perform public.rotate_invite_code(fid);
end;
$$;

-- Geschiedenis van wie vroeger al vertrok (vóór deze migratie) opruimen.
delete from location_history h
where not exists (
  select 1 from family_members m where m.family_id = h.family_id and m.user_id = h.user_id
);

-- ─── 2. Bewaartermijn ───────────────────────────────────────────────────────

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'thuisradar-history-cleanup',
  '15 3 * * *',
  $$delete from public.location_history where recorded_at < now() - interval '31 days'$$
);

-- Tellers van foute codepogingen (hieronder) niet laten aangroeien.
select cron.schedule(
  'thuisradar-join-attempts-cleanup',
  '25 3 * * *',
  $$delete from public.join_attempts where attempted_at < now() - interval '1 day'$$
);

-- ─── 3. Sterkere uitnodigingscodes ──────────────────────────────────────────

-- 8 tekens uit 32: elke byte % 32 is zonder voorkeur (256 = 8 x 32). Bytes 6
-- en 8 van een UUID zijn deels vast (versie/variant) en worden overgeslagen.
create or replace function public.new_invite_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  raw bytea := uuid_send(gen_random_uuid());
  code text := '';
  i int;
begin
  foreach i in array array[0, 1, 2, 3, 4, 5, 10, 11] loop
    code := code || substr(alphabet, (get_byte(raw, i) % 32) + 1, 1);
  end loop;
  return code;
end;
$$;

revoke execute on function public.new_invite_code() from public, anon, authenticated;

create or replace function public.create_family(family_name text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  new_family families;
begin
  if auth.uid() is null then
    raise exception 'Niet ingelogd';
  end if;

  for attempt in 1..5 loop
    begin
      insert into families (name, invite_code, created_by)
      values (trim(family_name), public.new_invite_code(), auth.uid())
      returning * into new_family;
      exit;
    exception when unique_violation then
      null; -- zelfde code als een ander gezin (zeldzaam): opnieuw
    end;
  end loop;
  if new_family.id is null then
    raise exception 'Geen uitnodigingscode gevonden; probeer opnieuw';
  end if;

  insert into family_members (family_id, user_id, role)
  values (new_family.id, auth.uid(), 'owner');

  return new_family;
end;
$$;

create or replace function public.rotate_invite_code(fid uuid)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  updated families;
begin
  if not public.is_family_owner(fid) then
    raise exception 'Enkel de beheerder kan de uitnodigingscode vernieuwen';
  end if;

  for attempt in 1..5 loop
    begin
      update families
         set invite_code = public.new_invite_code(),
             invite_expires_at = now() + interval '7 days'
       where id = fid
      returning * into updated;
      return updated;
    exception when unique_violation then
      -- Zelfde code als een ander gezin (zeldzaam): opnieuw proberen.
      null;
    end;
  end loop;
  raise exception 'Geen nieuwe uitnodigingscode gevonden; probeer opnieuw';
end;
$$;

-- Foute pogingen per gebruiker. Geen policies: enkel join_family (security
-- definer) leest en schrijft hier.
create table if not exists public.join_attempts (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index if not exists join_attempts_user_time_idx on public.join_attempts (user_id, attempted_at desc);
alter table public.join_attempts enable row level security;

-- Een foute code geeft null terug in plaats van een fout: een fout zou ook de
-- geregistreerde poging terugdraaien (alles zit in één transactie).
create or replace function public.join_family(code text)
returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  target families;
begin
  if auth.uid() is null then
    raise exception 'Niet ingelogd';
  end if;

  if (
    select count(*) from join_attempts
    where user_id = auth.uid() and attempted_at > now() - interval '15 minutes'
  ) >= 5 then
    raise exception 'Te veel foute codes. Probeer het over een kwartier opnieuw.';
  end if;

  select * into target from families where invite_code = upper(trim(code));
  if target.id is null then
    insert into join_attempts (user_id) values (auth.uid());
    return null;
  end if;

  if exists (select 1 from family_members where family_id = target.id and user_id = auth.uid()) then
    return target;
  end if;

  if target.invite_expires_at is not null and target.invite_expires_at < now() then
    raise exception 'Deze uitnodigingscode is verlopen. Vraag een nieuwe code.';
  end if;

  insert into family_members (family_id, user_id)
  values (target.id, auth.uid())
  on conflict do nothing;

  return target;
end;
$$;

revoke execute on function public.join_family(text) from public, anon;
grant execute on function public.join_family(text) to authenticated;

-- ─── 4. Account verwijderen ─────────────────────────────────────────────────

-- Wie een gezin of plaats maakte, mag verdwijnen zonder dat die verdwijnen.
alter table public.families alter column created_by drop not null;
alter table public.families drop constraint if exists families_created_by_fkey;
alter table public.families
  add constraint families_created_by_fkey foreign key (created_by) references auth.users (id) on delete set null;

alter table public.places alter column created_by drop not null;
alter table public.places drop constraint if exists places_created_by_fkey;
alter table public.places
  add constraint places_created_by_fkey foreign key (created_by) references public.profiles (id) on delete set null;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Niet ingelogd';
  end if;

  if exists (
    select 1 from family_members mine
    where mine.user_id = me and mine.role = 'owner'
      and exists (select 1 from family_members other where other.family_id = mine.family_id and other.user_id <> me)
  ) then
    raise exception 'Draag eerst het beheer over aan een ander gezinslid';
  end if;

  -- Gezinnen waar je de laatste bent, verdwijnen helemaal (plaatsen, chat, ...).
  delete from families f
  where exists (select 1 from family_members m where m.family_id = f.id and m.user_id = me)
    and not exists (select 1 from family_members m where m.family_id = f.id and m.user_id <> me);

  -- Al de rest hangt aan het profiel (on delete cascade): lidmaatschap,
  -- locaties, geschiedenis, berichten, SOS, tokens, noodcontacten, ...
  delete from auth.users where id = me;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
