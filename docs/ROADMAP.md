# Roadmap

De volgorde waarin Thuisradar gebouwd wordt. ✅ = klaar, ⏳ = gepland.
Beslissingen en werkregels staan in `../CLAUDE.md`; kosten in `KOSTEN.md`.

## ✅ Klaar

- **Fase A** — Design system (tokens, thema, typografie, herbruikbare componenten).
- **Fase B** — Onboarding, account, familie maken/joinen, uitnodigen, welkom, toestemmingen.
- **Fase C** — Hoofdschermen: bottom navigation, kaart-restyle, gezinslid-detail met tijdlijn.
- **Fase D1** — SOS (noodknop 3 s vasthouden + realtime overlay).
- **Fase D2** — Plaatsen + aankomst/vertrek-meldingen (server-side geofence met hysterese, gewoon meldingskanaal; migratie `005_places.sql` en verder).
- **Fase D2.5** — SOS-push via FCM (komt binnen ook als de app dicht is).
- **Fase D3** — Meldingen (feed uit `family_events`, ongelezen-badge via `last_seen`).
- **Fase D4** — Chat (`messages` + realtime).
- **Fase D5** — Profielscherm (display_name bewerken, familie verlaten, uitloggen).
- **Fix** — Locatiegeschiedenis laadt nooit oneindig (stabiele dagsleutel + timeout).
- **Kaart-afwerking (huidige kaart, flutter_map + OpenStreetMap):**
  - Zichtbare terugknop op alle subschermen + predictive back.
  - Kaart springt niet meer terug: fit maar 1× bij openen, daarna nooit automatisch bewegen + "centreer"-knop.
  - SOS-houdknop betrouwbaar (20 px-tolerantie, wint de gesture van de kaart, 56 px, tril-feedback).
  - Tik op naam → kaart naar die persoon + info-kaartje met "Geschiedenis"; pijltje › opent het detail; marker-tik → zelfde kaartje.
  - Selectie-ring rond geselecteerd lid (op kaart én in lijst).
  - Overlappende leden groeperen in één groepspin met statusballon (pure Dart, getest).
- **Onderweg: wandelen en fietsen** — tab Rijden heet Onderweg met filter Alles / Auto / Fiets / Wandelen. Elke verplaatsing krijgt een geschat vervoermiddel (GPS-snelheid + gemiddeld tempo); wandelen telt vanaf 3,6 km/u als onderweg en wordt elke 5 s gelogd. Wandelingen tonen route, afstand, duur, gemiddeld tempo en stappen (stappenteller, migratie `019_steps.sql`).
- **SOS veiliger + noodcontacten** — na 3 s vasthouden 10 s aftellen met een grote knop Annuleren (sluiten annuleert ook); "Bel 112" is overal weg (per ongeluk bellen is te gevaarlijk). In Profiel › Noodcontacten stel je 2 mensen in, ook buiten de app: bij een SOS krijgen ze automatisch een sms met een kaartlink, daarna belt de gsm contact 1. Android rechtstreeks (toestemming sms + bellen, werkt ook zonder internet); iPhone kan dat niet automatisch, daar opent de berichten-app met de sms klaar. Migratie `021_emergency_contacts.sql` (enkel jij ziet je contacten).
- **Activiteitsherkenning (achter de vlag `USE_ACTIVITY_RECOGNITION`, standaard uit)** — de bewegingssensoren van het toestel (Android Activity Recognition, Sampling API elke ±5 s; iPhone CoreMotion) zeggen "voertuig", "fiets" of "te voet". Dat stuurt de live status bij waar GPS en stappen twijfelen: traag in de file blijft een auto, een e-bike of speed pedelec tot 50 km/u blijft een fiets. Het zegt niet wélk voertuig (auto, bus of trein zijn allemaal "voertuig"). Migratie `020_activity.sql`; de herkenning wordt ook in `location_history` bewaard, zodat de weekrapporten ze later kunnen gebruiken.

## ⏳ Nu / volgende

- **Afwerking** — release-keystore, versienummers, app-icoon, testdata opkuisen.

## ⏳ Later

- **Meertaligheid** — 8 talen (nl, en, fr, de, es, pt, it, tr), toesteltaal met keuze in Profiel, terugval Engels. Alle app-schermen vertaald; volgende stap: pushmeldingen van de server in de taal van de ontvanger (`TALEN.md`, fase 4).

- **Google Maps / satelliet** — overstap van flutter_map/OSM naar Google Maps (SDK for Android, gratis tier) met auto-satelliet en een lagen-knop. Domein-logica (fit-once, selectie, groepering) staat al los van flutter_map, dus de wissel blijft beperkt.
- **iPhone-versie** — voor Liam en mama, via Codemagic / TestFlight (geen lokale Mac nodig).
- **Eventueel verkopen** — zie `KOSTEN.md` voor wat gratis moet blijven en wat achter betaalde feature flags gaat.
