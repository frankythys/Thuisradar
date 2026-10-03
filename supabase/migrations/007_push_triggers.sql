-- Fase D2.5/D3: push volledig via SQL (pg_net), zonder dashboard-webhooks.
-- Roept de Edge Functions send-sos-push en send-place-push rechtstreeks aan.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.
--
-- LET OP: zet eenmalig de configuratie (zie onderaan, NIET in git), en
-- verwijder een eventuele bestaande Database Webhook op sos_alerts om dubbele
-- SOS-pushes te vermijden.

create extension if not exists pg_net;

-- ─── Config (URL + webhook-geheim) in een privétabel, niet in git ───────────

create schema if not exists private;

create table if not exists private.push_config (
  id                 integer primary key default 1 check (id = 1),
  functions_base_url text not null,
  webhook_secret     text not null
);

alter table private.push_config enable row level security;
revoke all on private.push_config from anon, authenticated;

-- ─── Hulpfunctie: een Edge Function aanroepen ───────────────────────────────

create or replace function private.call_push(fn text, payload jsonb)
returns void
language plpgsql
security definer
set search_path = private, net, public
as $$
declare
  cfg private.push_config%rowtype;
begin
  select * into cfg from private.push_config where id = 1;
  if cfg.functions_base_url is null then
    return; -- nog niet geconfigureerd
  end if;

  perform net.http_post(
    url := cfg.functions_base_url || '/' || fn,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', cfg.webhook_secret
    ),
    body := payload
  );
end;
$$;

revoke execute on function private.call_push(text, jsonb) from public, anon, authenticated;

-- ─── Trigger: SOS-push bij een nieuw alarm ──────────────────────────────────

create or replace function public.notify_sos_push()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  perform private.call_push('send-sos-push', jsonb_build_object('record', to_jsonb(new)));
  return new;
end;
$$;

drop trigger if exists sos_alerts_push on public.sos_alerts;
create trigger sos_alerts_push
  after insert on public.sos_alerts
  for each row execute function public.notify_sos_push();

-- ─── Trigger: Plaatsen-push bij aankomst/vertrek ────────────────────────────

create or replace function public.notify_place_push()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if new.type in ('arrival', 'departure') then
    perform private.call_push('send-place-push', jsonb_build_object('record', to_jsonb(new)));
  end if;
  return new;
end;
$$;

drop trigger if exists family_events_push on public.family_events;
create trigger family_events_push
  after insert on public.family_events
  for each row execute function public.notify_place_push();

revoke execute on function public.notify_sos_push() from public, anon, authenticated;
revoke execute on function public.notify_place_push() from public, anon, authenticated;

-- ─── Eenmalig zelf instellen (NIET committen) ───────────────────────────────
-- Vervang <REF> door je project-ref en <GEHEIM> door je SOS_WEBHOOK_SECRET:
--
--   insert into private.push_config (id, functions_base_url, webhook_secret)
--   values (1, 'https://<REF>.supabase.co/functions/v1', '<GEHEIM>')
--   on conflict (id) do update
--     set functions_base_url = excluded.functions_base_url,
--         webhook_secret     = excluded.webhook_secret;
