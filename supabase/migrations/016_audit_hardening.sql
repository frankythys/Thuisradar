-- 016: verbeteringen uit de audit van 11 oktober 2026.
-- Idempotent: veilig om opnieuw uit te voeren. Uitvoeren in de Supabase SQL
-- Editor, ná 015. De app werkt met én zonder deze migratie.
--
-- 1. Een ouder locatiepunt dat ná een nieuwer binnenkomt (trage 4G, time-out
--    die de request niet annuleerde) zet de kaart niet meer terug in de tijd
--    en laat de zones niet opnieuw evalueren op een oude plek.
-- 2. SOS-alarm: de policy laat enkel het eigen alarm binnen het eigen gezin
--    naar 'resolved' zetten, en een trigger weigert expliciet elke wijziging
--    van gezin, afzender, locatie of aanmaaktijd en het heropenen. (Een
--    policy kan de oude rij niet met de nieuwe vergelijken; de trigger wel.)
-- 3. Het uitvoeringslogboek van pg_cron (enkel jobstatus, geen
--    gebruikersgegevens) wordt na 7 dagen opgeruimd.
-- 4. Vaste search_path op de laatste drie functies zonder (advisor).
--
-- Bewust NIET in deze migratie: een bewaartermijn voor location_history.
-- Dat is een keuze over persoonsgegevens, geen technische reparatie; zie
-- docs/AUDIT_VOLLEDIG_2026-10-11.md, beslispunt "Bewaartermijn".

-- ─── 1. Volgorde van locatie-uploads bewaken ────────────────────────────────

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
        (user_id, family_id, lat, lng, accuracy_m, speed_mps, battery, recorded_at)
      values
        (new.user_id, new.family_id, new.lat, new.lng, new.accuracy_m,
         new.speed_mps, new.battery, new.updated_at);
    end if;
    -- Huidige plek en zones ongemoeid; een gelijk tijdstip is een dubbele upload.
    return null;
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_location_order() from public, anon, authenticated;

drop trigger if exists member_locations_order_guard on public.member_locations;
create trigger member_locations_order_guard
  before update on public.member_locations
  for each row execute function public.guard_location_order();

-- ─── 2. SOS: enkel eigen alarm, enkel oplossen, niets verplaatsen ────────────

drop policy if exists "sos: zelf oplossen" on public.sos_alerts;
create policy "sos: zelf oplossen" on public.sos_alerts
  for update
  using (user_id = (select auth.uid()) and public.is_family_member(family_id))
  with check (
    user_id = (select auth.uid())
    and public.is_family_member(family_id)
    and status = 'resolved'
  );

-- Geldt voor iedereen, ook het dashboard: een alarm is een vaststaand feit.
-- Enkel status (naar 'resolved') en resolved_at mogen veranderen.
create or replace function public.guard_sos_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id is distinct from old.id
     or new.family_id is distinct from old.family_id
     or new.user_id is distinct from old.user_id
     or new.lat is distinct from old.lat
     or new.lng is distinct from old.lng
     or new.created_at is distinct from old.created_at then
    raise exception 'Een SOS-alarm kan niet verplaatst of aangepast worden'
      using errcode = '42501';
  end if;
  if old.status = 'resolved' and new.status is distinct from 'resolved' then
    raise exception 'Een opgelost SOS-alarm kan niet heropend worden'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_sos_update() from public, anon, authenticated;

drop trigger if exists sos_alerts_guard on public.sos_alerts;
create trigger sos_alerts_guard
  before update on public.sos_alerts
  for each row execute function public.guard_sos_update();

-- ─── 3. Cron-logboek opruimen (pg_cron, gratis in Supabase) ─────────────────
-- Elke minuut een rij (confirm-pending-departures): ±525.000 per jaar.

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('thuisradar-cron-log-cleanup', '23 3 * * *',
      $job$delete from cron.job_run_details where end_time < now() - interval '7 days'$job$);
  else
    raise notice 'pg_cron niet actief: cron-logboek wordt niet opgeruimd';
  end if;
end;
$$;

-- ─── 4. Vaste search_path ───────────────────────────────────────────────────

alter function public.geo_distance_m(double precision, double precision, double precision, double precision)
  set search_path = '';
alter function public.geofence_key_hash(text) set search_path = '';
alter function public.enforce_place_limit() set search_path = public;
