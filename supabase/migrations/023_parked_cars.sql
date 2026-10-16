-- Bewaart de laatst handmatig opgeslagen parkeerplek per gezinslid.
-- Uitvoeren in Supabase > SQL Editor > New query > Run.

create table if not exists public.parked_cars (
  user_id   uuid not null references public.profiles (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  lat       double precision not null check (lat between -90 and 90),
  lng       double precision not null check (lng between -180 and 180),
  parked_at timestamptz not null default now(),
  primary key (user_id, family_id),
  foreign key (family_id, user_id)
    references public.family_members (family_id, user_id) on delete cascade
);

create index if not exists parked_cars_family_idx on public.parked_cars (family_id);

alter table public.parked_cars enable row level security;

drop policy if exists "parkeerplekken: familie lezen" on public.parked_cars;
create policy "parkeerplekken: familie lezen" on public.parked_cars
  for select using (public.is_family_member(family_id));

drop policy if exists "parkeerplekken: eigen plek opslaan" on public.parked_cars;
create policy "parkeerplekken: eigen plek opslaan" on public.parked_cars
  for insert with check (user_id = auth.uid() and public.is_family_member(family_id));

drop policy if exists "parkeerplekken: eigen plek wijzigen" on public.parked_cars;
create policy "parkeerplekken: eigen plek wijzigen" on public.parked_cars
  for update using (user_id = auth.uid() and public.is_family_member(family_id))
  with check (user_id = auth.uid() and public.is_family_member(family_id));

drop policy if exists "parkeerplekken: eigen plek verwijderen" on public.parked_cars;
create policy "parkeerplekken: eigen plek verwijderen" on public.parked_cars
  for delete using (user_id = auth.uid() and public.is_family_member(family_id));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'parked_cars'
  ) then
    alter publication supabase_realtime add table public.parked_cars;
  end if;
end;
$$;
