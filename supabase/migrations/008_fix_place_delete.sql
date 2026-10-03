-- Fix: een plaats verwijderen werkt niet betrouwbaar.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
-- schema.sql en eerdere migraties blijven ongewijzigd.

-- 1. Realtime: DELETE-events moeten alle kolommen meesturen (o.a. family_id),
--    anders matcht de .stream().eq('family_id', ...)-filter niet en verdwijnt
--    de plaats niet uit de lijst/kaart na verwijderen.
alter table public.places         replica identity full;
alter table public.place_presence replica identity full;

-- 2. family_events.place_id verwijst nu naar places met ON DELETE SET NULL,
--    zodat een plaats verwijderd kan worden en de geschiedenis bewaard blijft.
--    (place_presence.place_id cascadeert al, zie migratie 005.)
alter table public.family_events
  drop constraint if exists family_events_place_id_fkey;

-- Verweesde verwijzingen (naar reeds verwijderde plaatsen) opschonen, anders
-- weigert de nieuwe foreign key. De gebeurtenis zelf blijft bewaard.
update public.family_events
set place_id = null
where place_id is not null
  and place_id not in (select id from public.places);

alter table public.family_events
  add constraint family_events_place_id_fkey
    foreign key (place_id) references public.places (id) on delete set null;
