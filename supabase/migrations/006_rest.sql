-- Fase D3–D5: alle resterende databasewijzigingen in één migratie.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
-- schema.sql blijft ongewijzigd.

-- ─── D4 Chat: berichten ─────────────────────────────────────────────────────

create table if not exists public.messages (
  id         bigint generated always as identity primary key,
  family_id  uuid not null references public.families (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists messages_family_time_idx on public.messages (family_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "chat: familie lezen" on public.messages;
create policy "chat: familie lezen" on public.messages
  for select using (public.is_family_member(family_id));

drop policy if exists "chat: zelf sturen" on public.messages;
create policy "chat: zelf sturen" on public.messages
  for insert with check (user_id = auth.uid() and public.is_family_member(family_id));

-- ─── D3 Meldingen: ongelezen-badge via één last_seen per gebruiker ──────────

create table if not exists public.event_reads (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  family_id    uuid not null references public.families (id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  primary key (user_id, family_id)
);

alter table public.event_reads enable row level security;

drop policy if exists "meldingen: eigen leesstatus" on public.event_reads;
create policy "meldingen: eigen leesstatus" on public.event_reads
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─── Realtime ────────────────────────────────────────────────────────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
