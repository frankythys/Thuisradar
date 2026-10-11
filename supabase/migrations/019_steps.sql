-- 019: stappen bij elke locatie, voor de stappen per wandeling.
-- Idempotent: veilig om opnieuw uit te voeren. Uitvoeren in de Supabase SQL
-- Editor, ná 016 (vervangt guard_location_order). Voer dit uit VÓÓR je de
-- nieuwe app installeert; oudere apps blijven gewoon werken (de kolom mag
-- leeg blijven).
--
-- `steps` is de stappenteller van het toestel zoals die ze levert: op Android
-- het totaal sinds de laatste herstart, op iPhone sinds de app luistert. Enkel
-- het verschil tussen twee metingen tijdens een wandeling betekent iets; de
-- app telt die verschillen op en negeert een teller die terugvalt.

alter table public.member_locations add column if not exists steps integer;
alter table public.location_history add column if not exists steps integer;

alter table public.member_locations drop constraint if exists member_locations_steps_check;
alter table public.member_locations
  add constraint member_locations_steps_check check (steps is null or steps >= 0);

-- ─── Geschiedenis neemt de stappen mee ──────────────────────────────────────

create or replace function public.record_location_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into location_history
    (user_id, family_id, lat, lng, accuracy_m, speed_mps, battery, steps, recorded_at)
  values
    (new.user_id, new.family_id, new.lat, new.lng, new.accuracy_m,
     new.speed_mps, new.battery, new.steps, new.updated_at);
  return new;
end;
$$;

revoke execute on function public.record_location_history() from public, anon, authenticated;

-- Zelfde functie als in 016, enkel met de stappen erbij.
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
        (user_id, family_id, lat, lng, accuracy_m, speed_mps, battery, steps, recorded_at)
      values
        (new.user_id, new.family_id, new.lat, new.lng, new.accuracy_m,
         new.speed_mps, new.battery, new.steps, new.updated_at);
    end if;
    -- Huidige plek en zones ongemoeid; een gelijk tijdstip is een dubbele upload.
    return null;
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_location_order() from public, anon, authenticated;
