-- 026: de beheerder kan de gezinsnaam wijzigen. Idempotent. Uitvoeren in de
-- Supabase SQL Editor, ná 017 (gebruikt is_family_owner). Zonder deze
-- migratie geeft "Gezinsnaam wijzigen" in de app een foutmelding; de rest
-- blijft werken.
--
-- Leden hebben geen schrijfrecht op families; enkel via deze functie, en
-- enkel de naam.

create or replace function public.rename_family(fid uuid, new_name text)
returns families
language plpgsql
security definer
set search_path = public
as $$
declare
  clean text := trim(new_name);
  renamed families;
begin
  if not public.is_family_owner(fid) then
    raise exception 'Enkel de beheerder kan de gezinsnaam wijzigen';
  end if;
  if clean is null or clean = '' then
    raise exception 'De gezinsnaam mag niet leeg zijn';
  end if;
  if char_length(clean) > 50 then
    raise exception 'De gezinsnaam is te lang (max. 50 tekens)';
  end if;

  update families set name = clean where id = fid returning * into renamed;
  return renamed;
end;
$$;

revoke execute on function public.rename_family(uuid, text) from public, anon;
grant execute on function public.rename_family(uuid, text) to authenticated;
