# Roadmap

De volgorde waarin Thuisradar gebouwd wordt. ✅ = klaar, ⏳ = gepland.
Beslissingen en werkregels staan in `../CLAUDE.md`; kosten in `KOSTEN.md`.

## ✅ Klaar

- **Fase A** — Design system (tokens, thema, typografie, herbruikbare componenten).
- **Fase B** — Onboarding, account, familie maken/joinen, uitnodigen, welkom, toestemmingen.
- **Fase C** — Hoofdschermen: bottom navigation, kaart-restyle, gezinslid-detail met tijdlijn.
- **Fase D1** — SOS (noodknop 3 s vasthouden + realtime overlay).
- **Fase D2.5** — SOS-push via FCM (komt binnen ook als de app dicht is).
- **Fix** — Locatiegeschiedenis laadt nooit oneindig (stabiele dagsleutel + timeout).
- **Kaart-afwerking (huidige kaart, flutter_map + OpenStreetMap):**
  - Zichtbare terugknop op alle subschermen + predictive back.
  - Kaart springt niet meer terug: fit maar 1× bij openen, daarna nooit automatisch bewegen + "centreer"-knop.
  - SOS-houdknop betrouwbaar (20 px-tolerantie, wint de gesture van de kaart, 56 px, tril-feedback).
  - Tik op naam → kaart naar die persoon + info-kaartje met "Geschiedenis"; pijltje › opent het detail; marker-tik → zelfde kaartje.
  - Selectie-ring rond geselecteerd lid (op kaart én in lijst).
  - Overlappende leden groeperen in één groepspin met statusballon (pure Dart, getest).

## ⏳ Nu / volgende

- **Fase D2** — Plaatsen + aankomst/vertrek-meldingen.
  - Server-side geofence-trigger met anti-flapping: metingen met `accuracy > 100 m` negeren; "binnen" = afstand `< straal`; "buiten" pas bij `> straal + 50 m` (hysterese); vertrek telt pas na ≥2 metingen of 3 min. Overgangslogica ook puur in Dart met unit-tests.
  - Push zonder alarmgeluid (gewoon meldingskanaal, niet het SOS-alarmkanaal).
  - Schermen: Plaatsen (13) en Plaats toevoegen (14). Migratie `005_places.sql`.
- **Fase D3** — Meldingen-tab (feed uit `family_events`, ongelezen-badge via `last_seen`).
- **Fase D4** — Chat (`messages` + realtime).
- **Fase D5** — Profielscherm (display_name bewerken, familie verlaten, uitloggen).
- **Afwerking** — release-keystore, versienummers, app-icoon, testdata opkuisen.

## ⏳ Later

- **Google Maps / satelliet** — overstap van flutter_map/OSM naar Google Maps (SDK for Android, gratis tier) met auto-satelliet en een lagen-knop. Domein-logica (fit-once, selectie, groepering) staat al los van flutter_map, dus de wissel blijft beperkt.
- **iPhone-versie** — voor Liam en mama, via Codemagic / TestFlight (geen lokale Mac nodig).
- **Eventueel verkopen** — zie `KOSTEN.md` voor wat gratis moet blijven en wat achter betaalde feature flags gaat.
