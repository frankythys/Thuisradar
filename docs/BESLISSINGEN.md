# Beslissingen

Verstandige standaarden die ik zelfstandig koos tijdens het afwerken van de
roadmap (D2–D5 + afwerking). Volgens `../CLAUDE.md`.

## D2 — Plaatsen + aankomst/vertrek

- **Iconen**: vaste set (`home`, `school`, `work`, `sports`, `store`, `place`) i.p.v. vrije keuze — eenvoudig en herkenbaar.
- **Straal**: schuif 50–500 m, standaard 150 m (zoals gevraagd). Max 20 plaatsen/familie (server-trigger).
- **Plaats kiezen**: kaart verschuiven met vaste pin in het midden + straal-cirkel; géén adres-zoekfunctie (kosten).
- **watched_members**: standaard iedereen (`null`). De per-lid-keuze is in de DB voorbereid (`watched_members uuid[]`), maar de UI laat voorlopig altijd "iedereen" — minder schermen, zelfde gedrag als de afspraak "standaard iedereen". Later uitbreidbaar zonder migratie.
- **Push "Plaatsen"**: apart Edge Function `send-place-push` op `family_events` (arrival/departure), via een **normaal** kanaal `places` (geen alarmgeluid). Niet naar jezelf. Tekst: "X is aangekomen op Y" / "X is vertrokken van Y".
- **Ledenlijst-status**: "‹plaats› · sinds HH:mm" zodra `place_presence.is_inside`.
- **Tijdlijn**: stops krijgen een plaatsnaam als hun middelpunt binnen de straal van een plaats ligt (pure Dart `attachPlaceNames`, getest).

## D3 — Meldingen-tab

- Feed uit `family_events` (nieuwste eerst), met icoon per type (sos/arrival/departure).
- **Ongelezen-badge**: één `last_seen`-tijdstip per gebruiker (`event_reads`). Bij het openen van de tab wordt `last_seen` bijgewerkt; de badge telt events nadien.

## D4 — Chat

- `messages` + realtime; eenvoudige bellen-UI, eigen berichten rechts. Max 2000 tekens.

## D5 — Profielscherm

- `display_name` bewerken (bestaande `profiles`-update-policy). Familie verlaten (met bevestiging; bestaande "zelf verlaten"-policy). Uitloggen. App-versie tonen.

## Afwerking

- **Versienummer**: `1.0.0+2`.
- **App-icoon**: `flutter_launcher_icons` geconfigureerd op `assets/icon/icon.png`. Zolang dat bestand ontbreekt blijft het standaard Flutter-icoon; zet er een 1024×1024 PNG neer en draai `dart run flutter_launcher_icons`.
- **Testdata opkuisen**: handmatig in Supabase (geen code).

## Push-aanroep (SQL i.p.v. dashboard)

- Beide Edge Functions (`send-sos-push`, `send-place-push`) worden aangeroepen via **pg_net-triggers** in `supabase/migrations/007_push_triggers.sql` — geen Database Webhook in het dashboard nodig. (Supabase Database Webhooks zijn onder de motorkap net zulke pg_net-triggers.)
- Het webhook-geheim komt uit **Supabase Vault** (`name = 'webhook_secret'`, gelijk aan de function-secret `SOS_WEBHOOK_SECRET`) → **geen secret in git**. De functie-URL staat hardgecodeerd (project-ref is niet geheim) en is te overschrijven via Vault-secret `functions_base_url`.
- `send-place-push` negeert `sos`-events; SOS loopt via de `sos_alerts`-trigger.
- Een bestaande dashboard-webhook op `sos_alerts` moet verwijderd worden om dubbele SOS-pushes te vermijden.

## Migraties

- D3–D5: `supabase/migrations/006_rest.sql` (messages + event_reads + realtime).
- Push-triggers: `supabase/migrations/007_push_triggers.sql` (onvermijdelijke extra migratie voor de pg_net-aanroep). Eén keer draaien in de SQL Editor.
