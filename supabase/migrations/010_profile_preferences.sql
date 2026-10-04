-- Persoonlijke kaartkleur en meldingskeuzes uit scherm 19.
alter table public.profiles add column if not exists color_index integer check (color_index between 0 and 5);
create table if not exists public.notification_preferences (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 arrival boolean not null default true,
 departure boolean not null default true,
 sos boolean not null default true
);
alter table public.notification_preferences enable row level security;
drop policy if exists "eigen voorkeuren" on public.notification_preferences;
create policy "eigen voorkeuren" on public.notification_preferences for all to authenticated
 using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select,insert,update,delete on public.notification_preferences to authenticated;
