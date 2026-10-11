-- 018: de beheerder kan het beheer overdragen aan een ander gezinslid.
-- Idempotent. Uitvoeren in de Supabase SQL Editor, ná 017 (gebruikt
-- is_family_owner). Zonder deze migratie geeft "Beheerder maken" in de app
-- een foutmelding; de rest blijft werken.
--
-- Er blijft altijd precies één beheerder: het gekozen lid wordt 'owner', de
-- huidige beheerder wordt 'member'. Beide in één transactie, zodat het gezin
-- nooit zonder of met twee beheerders zit.

create or replace function public.transfer_ownership(fid uuid, new_owner uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_family_owner(fid) then
    raise exception 'Enkel de beheerder kan het beheer overdragen';
  end if;
  if new_owner = auth.uid() then
    raise exception 'Je bent al beheerder';
  end if;
  if not exists (select 1 from family_members where family_id = fid and user_id = new_owner) then
    raise exception 'Deze persoon is geen lid van het gezin';
  end if;

  update family_members set role = 'owner' where family_id = fid and user_id = new_owner;
  update family_members set role = 'member' where family_id = fid and user_id = auth.uid();
end;
$$;

revoke execute on function public.transfer_ownership(uuid, uuid) from public, anon;
grant execute on function public.transfer_ownership(uuid, uuid) to authenticated;
