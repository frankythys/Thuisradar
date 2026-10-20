-- 024: zelf het gezin verlaten via een beveiligde functie. Idempotent.
-- Uitvoeren in de Supabase SQL Editor, ná 017 (gebruikt invite_expires_at) en
-- samen met de app-versie die leave_family aanroept. Een oudere app verwijderde
-- het lidmaatschap rechtstreeks; na deze migratie lukt dat niet meer (de
-- delete raakt dan 0 rijen) en blijft die gebruiker gewoon lid.
--
-- Waarom: met een rechtstreekse delete op family_members
-- 1. kon de beheerder vertrekken en het gezin zonder beheerder achterlaten
--    (niemand kon daarna nog de code vernieuwen of leden verwijderen);
-- 2. bleef de laatste locatie (member_locations) en de aanwezigheid
--    (place_presence) van wie vertrok leesbaar voor de achterblijvers.
--
-- leave_family(fid):
-- - de beheerder vertrekt pas als er niemand anders meer in het gezin zit;
--   anders eerst het beheer overdragen (transfer_ownership, migratie 018);
-- - ruimt de laatste locatie en de aanwezigheid van wie vertrekt op, net als
--   remove_member (017). De locatiegeschiedenis blijft (beslispunt
--   "Bewaartermijn");
-- - vertrekt de laatste persoon, dan vervalt de code meteen: niemand kan nog
--   in een leeg gezin zonder beheerder binnenkomen.

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

  if not exists (select 1 from family_members where family_id = fid) then
    update families set invite_expires_at = now() where id = fid;
  end if;
end;
$$;

revoke execute on function public.leave_family(uuid) from public, anon;
grant execute on function public.leave_family(uuid) to authenticated;

-- Vertrekken kan enkel nog via leave_family.
drop policy if exists "leden: zelf verlaten" on public.family_members;
