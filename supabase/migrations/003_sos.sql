-- Fase D1: SOS.
-- Voegt een gedeelde gebeurtenissen-feed (family_events) en actieve SOS-alarmen
-- (sos_alerts) toe. Uitvoeren in Supabase > SQL Editor > New query > Run.
-- Mag opnieuw draaien (idempotent waar mogelijk). schema.sql blijft ongewijzigd.

-- ─── Tabellen ────────────────────────────────────────────────────────────────

-- Gedeelde feed voor de Meldingen-tab: SOS nu, aankomst/vertrek vanaf Fase D2.
create table if not exists public.family_events (
  id            bigint generated always as identity primary key,
  family_id     uuid not null references public.families (id) on delete cascade,
  actor_user_id uuid not null references public.profiles (id) on delete cascade,
  type          text not null check (type in ('sos', 'arrival', 'departure')),
  place_id      uuid,
  lat           double precision,
  lng           double precision,
  created_at    timestamptz not null default now()
);

create index if not exists family_events_family_time_idx
  on public.family_events (family_id, created_at desc);

-- Actieve en opgeloste noodoproepen.
create table if not exists public.sos_alerts (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  status      text not null default 'active' check (status in ('active', 'resolved')),
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists sos_alerts_family_time_idx
  on public.sos_alerts (family_id, created_at desc);

-- ─── Trigger: SOS schrijft meteen een feed-gebeurtenis ──────────────────────

create or replace function public.record_sos_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into family_events (family_id, actor_user_id, type, lat, lng, created_at)
  values (new.family_id, new.user_id, 'sos', new.lat, new.lng, new.created_at);
  return new;
end;
$$;

drop trigger if exists sos_alerts_event on public.sos_alerts;
create trigger sos_alerts_event
  after insert on public.sos_alerts
  for each row execute function public.record_sos_event();

-- ─── Row Level Security ──────────────────────────────────────────────────────

alter table public.family_events enable row level security;
alter table public.sos_alerts    enable row level security;

drop policy if exists "feed: familie lezen" on public.family_events;
create policy "feed: familie lezen" on public.family_events
  for select using (public.is_family_member(family_id));

drop policy if exists "sos: familie lezen" on public.sos_alerts;
create policy "sos: familie lezen" on public.sos_alerts
  for select using (public.is_family_member(family_id));

drop policy if exists "sos: zelf aanmaken" on public.sos_alerts;
create policy "sos: zelf aanmaken" on public.sos_alerts
  for insert with check (user_id = auth.uid() and public.is_family_member(family_id));

drop policy if exists "sos: zelf oplossen" on public.sos_alerts;
create policy "sos: zelf oplossen" on public.sos_alerts
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- family_events wordt enkel door de trigger geschreven; geen insert-policy nodig.
revoke execute on function public.record_sos_event() from public, anon, authenticated;

-- ─── Realtime ────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'sos_alerts'
  ) then
    alter publication supabase_realtime add table public.sos_alerts;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'family_events'
  ) then
    alter publication supabase_realtime add table public.family_events;
  end if;
end;
$$;
