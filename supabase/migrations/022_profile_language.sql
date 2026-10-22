-- 022: taal van elk gezinslid, zodat pushmeldingen van de server (SOS) in
-- de taal van de ontvanger komen (docs/TALEN.md, fase 4). Idempotent.
-- Uitvoeren in de Supabase SQL Editor (het nummer was hiervoor vrijgehouden;
-- 023-025 mogen al gedraaid hebben). Samen met de app-versie die de taal
-- wegschrijft en de nieuwe send-sos-push; zonder die app blijft de kolom
-- leeg en blijft de push Nederlands.
--
-- Bijwerken mag enkel voor het eigen profiel: dat regelt de bestaande
-- policy "profiel: zelf wijzigen".

alter table public.profiles add column if not exists language text;

alter table public.profiles drop constraint if exists profiles_language_check;
alter table public.profiles
  add constraint profiles_language_check
  check (language is null or language in ('nl', 'en', 'fr', 'de', 'es', 'pt', 'it', 'tr'));
