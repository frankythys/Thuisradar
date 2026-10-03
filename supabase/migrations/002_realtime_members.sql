-- Fase C: maak de ledenlijst realtime.
-- Voegt family_members toe aan de realtime-publicatie, zodat nieuwe of
-- vertrokken gezinsleden meteen in de app verschijnen.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'family_members'
  ) then
    alter publication supabase_realtime add table public.family_members;
  end if;
end;
$$;
