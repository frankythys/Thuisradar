-- 016: verbeteringen uit de audit van 11 oktober 2026.
-- Idempotent: veilig om opnieuw uit te voeren. Uitvoeren in de Supabase SQL
-- Editor, ná 015. De app werkt met én zonder deze migratie.
--
-- 1. Een ouder locatiepunt dat ná een nieuwer binnenkomt (trage 4G, time-out
--    die de request niet annuleerde) zet de kaart niet meer terug in de tijd
--    en laat de zones niet opnieuw evalueren op een oude plek.
-- 2. Een SOS-alarm kan enkel nog opgelost worden, niet verplaatst naar een
--    ander gezin of stil opnieuw geactiveerd.
-- 3. Locatiegeschiedenis ouder dan 90 dagen en cron-logboeken ouder dan 7
--    dagen worden elke nacht opgeruimd (gratis plan: 500 MB).
-- 4. Vaste search_path op de laatste drie functies zonder (advisor).

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

-- ─── 2. SOS: enkel eigen alarm, enkel oplossen ──────────────────────────────

drop policy if exists "sos: zelf oplossen" on public.sos_alerts;
create policy "sos: zelf oplossen" on public.sos_alerts
  for update
  using (user_id = (select auth.uid()) and public.is_family_member(family_id))
  with check (
    user_id = (select auth.uid())
    and public.is_family_member(family_id)
    and status = 'resolved'
  );

-- ─── 3. Opruimen (pg_cron, gratis in Supabase) ──────────────────────────────
-- De app toont hooguit 12 weken terug; 90 dagen houdt daar een marge op.

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('thuisradar-history-cleanup', '17 3 * * *',
      $job$delete from public.location_history where recorded_at < now() - interval '90 days'$job$);
    perform cron.schedule('thuisradar-cron-log-cleanup', '23 3 * * *',
      $job$delete from cron.job_run_details where end_time < now() - interval '7 days'$job$);
  else
    raise notice 'pg_cron niet actief: geschiedenis wordt niet automatisch opgeruimd';
  end if;
end;
$$;

-- ─── 4. Vaste search_path ───────────────────────────────────────────────────

alter function public.geo_distance_m(double precision, double precision, double precision, double precision)
  set search_path = '';
alter function public.geofence_key_hash(text) set search_path = '';
alter function public.enforce_place_limit() set search_path = public;
