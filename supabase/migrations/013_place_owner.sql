-- Van wie is een plaats? (bv. "Werk" hoort bij Franky). Los van "voor wie
-- meldingen" (watched_members). null = van niemand in het bijzonder.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
alter table public.places
  add column if not exists owner_user_id uuid references public.profiles (id) on delete set null;
