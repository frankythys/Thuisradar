# Meertaligheid (i18n)

Doel: bij beta/launch een veel groter publiek bereiken. Alles hieronder is gratis
(Flutter `gen-l10n`, geen betaalde vertaaldienst), zie `KOSTEN.md`.

## Beslissingen

- **Talen:** Nederlands (brontaal), Engels, Frans, Duits, Spaans, Portugees,
  Italiaans, Turks.
- **Terugval:** staat de taal van het toestel er niet tussen → **Engels**. Het
  toestel mag een voorkeurslijst hebben (bv. Arabisch, Frans): dan nemen we de
  eerste taal die we wél hebben (Frans).
- **Keuze:** standaard de toesteltaal; in **Profiel › Taal** kan je die
  overschrijven (handig in gemengde gezinnen). De keuze geldt meteen, zonder
  herstart, en wordt per toestel bewaard (`shared_preferences`, sleutel
  `app_language`).
- **Portugees** = Braziliaans Portugees (grootste groep). Europees Portugees kan
  later als `app_pt_PT.arb` met enkel de afwijkende zinnen.
- **Vertalen:** Claude vertaalt, native speakers uit de beta kijken na.
- **Gebruikersinhoud** (namen van plaatsen, chatberichten, gezinsnaam) wordt niet
  vertaald.

## Hoe het werkt (fundament — klaar)

| Onderdeel | Bestand |
|---|---|
| Vertalingen (bron = Nederlands, met `@`-beschrijving per tekst) | `lib/l10n/app_<taal>.arb` |
| Generator-instellingen | `l10n.yaml` (output in `lib/l10n/generated/`, gitignored) |
| `context.l10n` (valt in kale widgettests terug op Nederlands) | `lib/l10n/l10n.dart` |
| Talen, terugvallogica (pure Dart, getest) | `lib/features/language/domain/app_language.dart` |
| Bewaren van de keuze | `lib/features/language/data/language_store.dart` |
| Riverpod-keuze + delegates/locale voor MaterialApp | `lib/features/language/application/` |
| Rij en onderblad in Profiel | `lib/features/language/presentation/` |

`main.dart` leest de keuze vóór de eerste frame, zodat de app niet eerst in de
toesteltaal flitst. `flutter pub get` / `run` / `test` genereren de code opnieuw.

**Al omgezet:** onderste navigatie, het profielscherm, de taalkeuze.

### Een tekst toevoegen of omzetten

1. Sleutel + Nederlandse tekst + `@sleutel`-beschrijving in `app_nl.arb`
   (naam: `<feature><Wat>`, bv. `placesAddTitle`).
2. Dezelfde sleutel in de 7 andere `.arb`-bestanden.
3. In de widget: `context.l10n.placesAddTitle`.
4. Variabelen als placeholder (`'{name} is aangekomen'`), **nooit** zinnen aan
   elkaar plakken: de woordvolgorde verschilt per taal.
5. Aantallen via ICU-meervoud: `{count, plural, =1{1 lid} other{{count} leden}}`.

`test/features/language/arb_completeness_test.dart` faalt als een taal een
sleutel mist, een tekst leeg is of placeholders anders zijn.

## Stappenplan

### Fase 1 — Fundament ✅

### Fase 2 — App-teksten per feature (±700 teksten)

Eén commit per feature, in volgorde van wat een nieuwe gebruiker eerst ziet:

1. onboarding, auth (inloggen/registreren, toegangscode), familie maken/joinen,
   uitnodigen, toestemmingen
2. kaart (statusballonnen, gezinslid-info), SOS (aftellen, overlay)
3. plaatsen, meldingen, chat
4. noodcontacten, onderweg/ritten, gezinslid-detail, profiel-onderbladen
   (`profile_sheets.dart`, `pin_settings_tile.dart`, `diagnostics_export_tile.dart`)
5. gedeelde widgets (`ErrorView`, lege staten, `HomeShell`-terugvalnaam)

Bestaande widgettests blijven Nederlands (terugval van `context.l10n`); per feature
één extra test in een andere taal volstaat.

### Fase 3 — Teksten buiten widgets

- **`domain/` blijft puur Dart.** Teksten in `trip_status.dart`,
  `diagnostic_tally.dart` e.d. worden een waarde of enum; `presentation/` maakt er
  tekst van met `context.l10n`.
- **Tijd en datum:** `core/utils/time_format.dart` ("zonet", "5 min geleden",
  "gisteren") en de dagnamen in `driving_summary.dart` naar ICU-teksten +
  `DateFormat` van `intl` met de app-taal.
- **Adressen:** de native geocoder volgt de toesteltaal; geef de app-taal mee
  (`geocoding_source.dart`, `add_place_screen.dart`).
- **Meldingskanalen:** namen in `core/push/push_channels.dart` uit de app-taal
  halen (Android laat de naam van een bestaand kanaal bijwerken; het id niet
  wijzigen).
- **SOS-sms aan noodcontacten:** in de taal van wie de SOS stuurt.
- **Eenheden:** km/u en km blijven; mijlen pas als er vraag is uit VK/VS.

### Fase 4 — Pushmeldingen in de taal van de ontvanger

Nu zetten de Edge Functions (`send-sos-push`, `send-place-push`,
`send-chat-push`) Nederlandse tekst in de melding. Plan:

- Migratie `022_profile_language.sql`: kolom `profiles.language text` (bv. `'fr'`).
- De app schrijft de gekozen of opgeloste taal bij het opstarten en bij elke
  wijziging weg.
- `supabase/functions/_shared/i18n.ts`: teksttabel per taal met Engels als
  terugval; de functies groeperen tokens per taal van de ontvanger.
- Deploy van de drie functies + migratie manueel uitvoeren in de SQL Editor.

(Alternatief "data-only push en de app maakt de tekst" is minder betrouwbaar
als de app volledig dicht is — niet doen voor SOS.)

### Fase 5 — Platform en stores

- **Android 13+:** `res/xml/locales_config.xml` + `android:localeConfig` in het
  manifest, zodat de taal ook in Instellingen › Apps › Taal kan.
- **iPhone (later):** `CFBundleLocalizations` in `Info.plist` en vertaalde
  toestemmingsteksten (`InfoPlist.strings`, o.a. locatie "altijd") — Apple keurt
  af als die ontbreken of onduidelijk zijn.
- **Play Store:** titel, korte/lange beschrijving en screenshots per taal.
- **Privacybeleid** en de verplichte "prominente melding" voor achtergrondlocatie
  in elke taal (Google Play-eis voor locatie-apps).

### Fase 6 — Kwaliteit vóór beta

- Per taal één native tester die alle schermen doorloopt.
- Duits en Frans zijn tot ±30 % langer: elk scherm op een smalle gsm controleren
  (geen afgekapte knoppen, `maxLines`/`ellipsis` waar nodig).
- Turks: hoofdletters met `i/İ` niet zelf maken met `toUpperCase()`.
- Geen RTL-talen (Arabisch, Hebreeuws) in deze ronde; komen die later, dan
  `EdgeInsetsDirectional` en `AlignmentDirectional` gebruiken.

## Kosten

€0: alles draait lokaal of in de bestaande gratis diensten. Een vertaalplatform
(Weblate/Crowdin) is pas nodig als externe vertalers meewerken; beide hebben een
gratis plan voor kleine/open projecten.
