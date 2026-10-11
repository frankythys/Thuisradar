-- 017: uitnodigingscode vervalt, is te vernieuwen, en de beheerder kan een
-- lid verwijderen. Idempotent. Uitvoeren in de Supabase SQL Editor, ná 016
-- en vóór de app-versie met de knoppen "Nieuwe code" en "Verwijderen" (die
-- roepen rotate_invite_code / remove_member aan; zonder deze migratie geven
-- ze een foutmelding, de rest van de app blijft werken).
--
-- Waarom: een code die ooit in een groepschat of op een screenshot stond, gaf
-- voorgoed toegang tot live locaties, geschiedenis en chat, en de beheerder
-- kon die persoon niet meer verwijderen.
--
-- 1. families.invite_expires_at: een code is 7 dagen geldig. Bestaande codes
--    krijgen bij het uitvoeren nog 7 dagen, zodat een net verstuurde
--    uitnodiging blijft werken.
-- 2. join_family weigert een verlopen code (wie al lid is, blijft lid).
-- 3. rotate_invite_code(fid): enkel de beheerder; nieuwe code, weer 7 dagen.
-- 4. remove_member(fid, member): enkel de beheerder, nooit de beheerder zelf.
--    Haalt het lid uit het gezin, van de kaart (laatste locatie) en uit de
--    aanwezigheid, en maakt meteen een nieuwe code zodat die persoon niet met
--    de oude code kan terugkeren. De locatiegeschiedenis van dat lid blijft
--    (zie het beslispunt "Bewaartermijn" in docs/AUDIT_VOLLEDIG_2026-10-11.md).

-- ─── 1. Vervaldatum ─────────────────────────────────────────────────────────

alter table public.families add column if not exists invite_expires_at timestamptz;
alter table public.families alter column invite_expires_at set default now() + interval '7 days';
update public.families set invite_expires_at = now() + interval '7 days' where invite_expires_at is null;

-- ─── 2. Joinen met een geldige code ─────────────────────────────────────────

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

  select * into target from families where invite_code = upper(trim(code));
  if target.id is null then
    raise exception 'Onbekende uitnodigingscode';
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

-- ─── 3. Nieuwe code (beheerder) ─────────────────────────────────────────────

create or replace function public.is_family_owner(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from family_members
    where family_id = fid and user_id = auth.uid() and role = 'owner'
  );
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
         set invite_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
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

-- ─── 4. Lid verwijderen (beheerder) ─────────────────────────────────────────

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

  -- De oude code mag die persoon niet terugbrengen.
  perform public.rotate_invite_code(fid);
end;
$$;

revoke execute on function public.is_family_owner(uuid) from public, anon;
revoke execute on function public.rotate_invite_code(uuid) from public, anon;
revoke execute on function public.remove_member(uuid, uuid) from public, anon;
grant execute on function public.is_family_owner(uuid) to authenticated;
grant execute on function public.rotate_invite_code(uuid) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
