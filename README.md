# Thuisradar

Familie-locatie app (eigen alternatief voor Life360), gebouwd met **Flutter** en **Supabase**.

**Versie 1 (basis):** inloggen, familie aanmaken of joinen met een code, live kaart met
de locatie van elk gezinslid (ook op de achtergrond) en batterijniveau.
**Ook klaar:** plaatsen (geofences) met aankomst/vertrek-meldingen, geschiedenis per
gezinslid, Onderweg (ritten met auto/fiets/wandelen), familiechat, meldingen, SOS met
push en noodcontacten, parkeerplek en 8 talen. Zie `docs/ROADMAP.md` voor wat volgt.

➡️ **Installeren en starten: [docs/SETUP.md](docs/SETUP.md)**

## Projectstructuur

Per functie een map (*feature-first*), en binnen elke functie een vaste opdeling.
Geen "god classes": elk bestand doet één ding.

```
lib/
  main.dart, app.dart          opstarten
  core/                        config, thema, Supabase-client, hulpfuncties
  shared/widgets/              herbruikbare widgets (avatar, batterij, fout)
  features/
    auth/                      inloggen / registreren
    family/                    familie aanmaken, joinen, leden ophalen
    location/                  GPS + batterij lezen en uploaden (tracker)
    map/                       kaartscherm, markers, ledenlijst
      domain/                  pure Dart-modellen en logica (testbaar)
      data/                    praten met Supabase / toestel
      application/             Riverpod-providers, state
      presentation/            schermen en widgets
supabase/schema.sql            tabellen, beveiliging (RLS), functies, realtime
test/                          unit tests
```

Regels:
- `domain/` importeert geen Flutter of Supabase.
- Widgets praten nooit rechtstreeks met Supabase, enkel via providers en repositories.
- Een bestand dat boven de ~200 regels groeit, wordt opgesplitst.

## Commando's

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env.json
```
