-- 020: activiteitsherkenning van het toestel bij elke locatie (auto / fiets /
-- te voet / stil), voor een betere schatting van het vervoermiddel.
-- Idempotent: veilig om opnieuw uit te voeren. Uitvoeren in de Supabase SQL
-- Editor, ná 019 (vervangt record_location_history en guard_location_order).
-- Voer dit uit VÓÓR je een app bouwt met "USE_ACTIVITY_RECOGNITION": "true";
-- oudere apps en apps met de flag uit blijven gewoon werken (de kolom mag
-- leeg blijven).
--
-- `activity` is wat de bewegingssensoren van het toestel herkenden (Android
-- Activity Recognition, iPhone CoreMotion), enkel met voldoende zekerheid en
-- hooguit 30 s oud. 'vehicle' zegt niet welk voertuig: auto, bus en trein
-- zijn allemaal 'vehicle'.

alter table public.member_locations add column if not exists activity text;
alter table public.location_history add column if not exists activity text;

alter table public.member_locations drop constraint if exists member_locations_activity_check;
alter table public.member_locations
  add constraint member_locations_activity_check
  check (activity is null or activity in ('vehicle', 'bicycle', 'foot', 'still'));

-- ─── Geschiedenis neemt de activiteit mee ───────────────────────────────────

create or replace function public.record_location_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into location_history
    (user_id, family_id, lat, lng, accuracy_m, speed_mps, battery, steps, activity, recorded_at)
  values
    (new.user_id, new.family_id, new.lat, new.lng, new.accuracy_m,
     new.speed_mps, new.battery, new.steps, new.activity, new.updated_at);
  return new;
end;
$$;

revoke execute on function public.record_location_history() from public, anon, authenticated;

-- Zelfde functie als in 019, enkel met de activiteit erbij.
create or replace function public.guard_location_order()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Een toestelklok die eerder voorliep (oud tijdstip in de toekomst) mag
  -- de rij altijd overschrijven; anders bevroor de kaart tot die tijd.
  if new.updated_at <= old.updated_at and old.updated_at <= now() + interval '2 minutes' then
    if new.updated_at < old.updated_at then
      -- Wel in de geschiedenis: het is een echte meting, alleen te laat.
      insert into location_history
        (user_id, family_id, lat, lng, accuracy_m, speed_mps, battery, steps, activity, recorded_at)
      values
        (new.user_id, new.family_id, new.lat, new.lng, new.accuracy_m,
         new.speed_mps, new.battery, new.steps, new.activity, new.updated_at);
    end if;
    -- Huidige plek en zones ongemoeid; een gelijk tijdstip is een dubbele upload.
    return null;
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_location_order() from public, anon, authenticated;

-- PostgREST de nieuwe kolom laten zien zonder te wachten.
notify pgrst, 'reload schema';
