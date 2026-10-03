-- Fase D2.5: FCM-tokens voor push-meldingen (SOS).
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
-- schema.sql blijft ongewijzigd.

create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  platform   text not null default 'android' check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Een gebruiker beheert enkel zijn eigen tokens. De Edge Function leest ze met
-- de service-role sleutel (omzeilt RLS) om pushes te versturen.
drop policy if exists "token: zelf beheren" on public.device_tokens;
create policy "token: zelf beheren" on public.device_tokens
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
