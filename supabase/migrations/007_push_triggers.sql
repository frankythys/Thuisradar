-- Fase D2.5/D3: push volledig via SQL (pg_net), zonder dashboard-webhooks.
-- Roept de Edge Functions send-sos-push en send-place-push rechtstreeks aan.
-- Het webhook-geheim komt uit de Vault (name = 'webhook_secret'); geen secret in git.
-- Uitvoeren in Supabase > SQL Editor > New query > Run. Mag opnieuw draaien.

create extension if not exists pg_net;

-- Oude config-tabel uit een eerdere opzet opruimen (indien aanwezig).
drop table if exists private.push_config;

create schema if not exists private;

-- ─── Hulpfunctie: een Edge Function aanroepen ───────────────────────────────
-- URL standaard hardgecodeerd (project-ref is niet geheim); eventueel te
-- overschrijven via Vault-secret 'functions_base_url'. Het header-geheim komt
-- altijd uit Vault-secret 'webhook_secret'.

create or replace function private.call_push(fn text, payload jsonb)
returns void
language plpgsql
security definer
set search_path = net, vault, public
as $$
declare
  secret   text;
  base_url text;
begin
  select decrypted_secret into secret
    from vault.decrypted_secrets where name = 'webhook_secret';
  if secret is null then
    return; -- geen geheim ingesteld
  end if;

  select decrypted_secret into base_url
    from vault.decrypted_secrets where name = 'functions_base_url';
  base_url := coalesce(base_url, 'https://ragkwonerrhntpboenni.supabase.co/functions/v1');

  perform net.http_post(
    url := base_url || '/' || fn,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', secret
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

-- ─── Trigger: Plaatsen-push bij aankomst/vertrek (SOS wordt genegeerd) ───────

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
