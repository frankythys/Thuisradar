-- 021: noodcontacten. Twee mensen (ook buiten de app) die bij een SOS een
-- sms met de locatie krijgen; contact 1 wordt daarna ook gebeld. Het sms'en
-- en bellen gebeurt op de gsm zelf, de database bewaart enkel de contacten.
-- Idempotent: veilig om opnieuw uit te voeren. Uitvoeren in de Supabase SQL
-- Editor; vóór je de app met het scherm Noodcontacten installeert.
--
-- Privé: enkel de eigenaar leest en schrijft zijn eigen contacten, ook
-- gezinsleden zien ze niet.

create table if not exists public.emergency_contacts (
  user_id uuid not null references public.profiles(id) on delete cascade,
  position smallint not null check (position in (1, 2)),
  name text not null check (char_length(btrim(name)) between 1 and 60),
  phone text not null check (phone ~ '^\+?[0-9 ()-]{6,24}$'),
  updated_at timestamptz not null default now(),
  primary key (user_id, position)
);

alter table public.emergency_contacts enable row level security;

drop policy if exists "eigen noodcontacten" on public.emergency_contacts;
create policy "eigen noodcontacten" on public.emergency_contacts for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.emergency_contacts from anon;
grant select, insert, update, delete on public.emergency_contacts to authenticated;

notify pgrst, 'reload schema';
