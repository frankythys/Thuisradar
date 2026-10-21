# Onafhankelijke Play Store-audit CircleBeacon (Thuisradar) — 21 oktober 2026

**Scope:** broncode op `main` (commit `034045a`, gelijk met `origin/main`), Android-manifest en
buildconfiguratie, Supabase-schema, migraties en Edge Functions, en het Google Play-beleid
(online gecontroleerd). **Niet bekeken:** live Supabase-project (RLS-status, toegepaste migraties,
Auth-instellingen), Play Console, Google Cloud-sleutelbeperkingen, een release-AAB en gedrag op
toestellen.

Ter vergelijking: de audit van 15 oktober (`PLAYSTORE_AUDIT_2026-10-15.md`). Per punt staat
hieronder of het sindsdien opgelost is.

## Oordeel

**Nog niet indienen voor productie.** Sinds 15 oktober is veel opgelost (signing, de melding vóór
achtergrondlocatie, eerlijke privacyteksten, batterij-optimalisatie niet meer standaard, familie
verlaten zonder beheerder). Er blijven **drie harde blokkades**: geen accountverwijdering, geen
privacybeleid-URL en `SEND_SMS` in het manifest. Daarnaast is er één ernstig privacyprobleem in de
backend: de locatiegeschiedenis wordt nooit opgeruimd.

## Stand na de oplossingen (zelfde dag)

| # | Status | Wat er veranderde |
|---|---|---|
| B1 | **Opgelost in code** | Profiel → *Account verwijderen* (`delete_account_tile.dart`, `account_deletion_repository.dart`) en `delete_my_account()` in migratie 025; webpagina `/account/delete` in `site/`. |
| B2 | **Opgelost in code** | Privacybeleid in `site/` (nl/en), link in Profiel → Privacy (`site_links.dart`). **Moet nog online** (`site/README.md`). |
| B3 | **Opgelost** | `SEND_SMS`/`CALL_PHONE` weg (met `tools:node="remove"`). De SOS opent de berichten-app met de sms klaar voor contact 1 (contact 2 als reserve). |
| H1 | **Opgelost in migratie 025** | Geschiedenis mee bij vertrek/verwijderen, oude restjes opgeruimd, pg_cron wist alles ouder dan 31 dagen. |
| H2 | **Opgelost in migratie 025** | Codes met 40 bits (32 tekens, geen 0/O/1/I), max. 5 foute pogingen per kwartier per gebruiker. |
| M1 | **Opgelost** | Geofence-receiver `exported="false"`. |
| M5 | **Opgelost** | Webhook-geheim in constante tijd (`_shared/webhook_secret.ts`). |
| H3, H4, H5, M2–M4, M6, M7 | Open | Console-werk (declaraties, Data safety, doelgroep, testaccount), sleutelbeperkingen in Google Cloud, vertaling van de SOS-push. |

Release-volgorde: migratie 025 draaien **samen met** de nieuwe app-versie (een oudere app
loopt vast op een foute uitnodigingscode), en de website online zetten vóór de indiening.

## 1. Blokkeert publicatie

| # | Ernst | Bevinding | Actie |
|---|---|---|---|
| B1 | **Kritiek** | **Geen accountverwijdering**, niet in de app en niet via het web. Er is enkel uitloggen, familie verlaten en "opgeslagen login verwijderen". Play eist voor elke app waarin je een account aanmaakt **beide**: een pad in de app én een webpagina/formulier dat je in de Play Console invult. *(Open sinds 15/10.)* | Supabase RPC/Edge Function `delete_account` (service role) die `auth.users` en alle rijen wist: profiles, family_members, member_locations, **location_history**, place_presence, chat, media in `family-media`, device_tokens, emergency_contacts, parked_cars, sos_*. Knop in Profiel met bevestiging (+ opnieuw inloggen). Publieke webpagina met uitleg of formulier. |
| B2 | **Kritiek** | **Geen privacybeleid-URL.** Er is geen link in de app, nergens een URL. Play eist die verplicht bij gevoelige rechten (achtergrondlocatie, microfoon, camera/foto's, activiteit). *(Open sinds 15/10.)* | Publiceer een beleid (bv. GitHub Pages of Cloudflare Pages) dat noemt: welke gegevens, verwerkers (Supabase, Firebase/FCM, Google Maps, OpenStreetMap/Overpass), bewaartermijnen, rechten (AVG), contact en minimumleeftijd. Link in Profiel → Privacy en in de Play Console. |
| B3 | **Hoog** | **`SEND_SMS` (en `CALL_PHONE`) in het manifest.** `SEND_SMS` is een beperkte toestemming. De enige uitzondering die past is "Physical safety/emergency alerts", en Google keurt die alleen goed als er **geen alternatief** is. Een SMS-intent is zo'n alternatief. Kans op afwijzing of vertraging is groot. | **Aanbevolen:** verwijder `SEND_SMS` en `CALL_PHONE` en gebruik op Android hetzelfde pad als op iPhone (`sms:`/`tel:` via `url_launcher`, met alles al ingevuld). De terugvaloptie bestaat al in `emergency_phone.dart` (`no_permission` → berichten-app). Wil je echt automatisch sms'en, vul dan het Permissions Declaration Form in, met video, en reken op weken review. |

## 2. Hoog — oplossen vóór productie

| # | Bevinding | Actie |
|---|---|---|
| H1 | **De locatiegeschiedenis wordt nooit opgeruimd.** De cron in `schema.sql:240` staat in commentaar, en migratie 016 laat de bewaartermijn bewust weg. Zo groeit `location_history` onbeperkt (zeer gevoelige gegevens; AVG-dataminimalisatie). Daarbovenop: **wie het gezin verlaat of verwijderd wordt, blijft met zijn volledige geschiedenis leesbaar voor de anderen.** `leave_family`/`remove_member` wissen enkel `member_locations` en `place_presence`, en de RLS-policy kijkt alleen naar `family_id`. *(Open sinds 15/10.)* | Nieuwe migratie: (a) `delete from location_history where user_id = … and family_id = …` in `leave_family` en `remove_member`; (b) pg_cron-job met een vaste bewaartermijn (bv. 30 dagen), plus dezelfde termijn in het privacybeleid. |
| H2 | **Uitnodigingscode van 32 bits zonder poginglimiet.** De code is 8 hextekens uit een UUID. `join_family` kun je onbeperkt aanroepen, en wie binnen is, ziet meteen de **live locatie** van het hele gezin. Een vervaldatum van 7 dagen helpt, maar vervangt geen rate-limit. *(Open sinds 15/10.)* | Langere code (10 tot 12 tekens, base32) **en** een poginglimiet per gebruiker in `join_family` (tabel met tellers), liefst ook bevestiging door de beheerder van nieuwe leden of een melding bij elk nieuw lid. |
| H3 | **Play Console-declaraties voor locatie.** `ACCESS_BACKGROUND_LOCATION` en `FOREGROUND_SERVICE_LOCATION` hebben elk een declaratie nodig met een **video** die de melding in de app, de Android-vraag en de functie toont. | Neem een korte video op (A52): uitleg-dialoog → "Altijd toestaan" → vaste melding → kaart. Beschrijf achtergrondlocatie als kernfunctie in de storevermelding. |
| H4 | **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.** Google laat dit recht alleen toe voor functies die zonder niet werken, en vraagt ernaar bij de review. Locatie delen via een foreground service heeft het meestal niet nodig. | Liefst verwijderen (de foreground service houdt het delen al levend) en de gebruiker in plaats daarvan naar de batterij-instellingen sturen (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, dat vraagt geen recht). Hou je het, zorg dan dat de vraag enkel komt na een eigen tik van de gebruiker (dat is nu zo). |
| H5 | **Doelgroep en kinderen.** Een gezinsapp trekt kinderen aan. Kies je in de Play Console een doelgroep onder 13, dan geldt het Families-beleid (streng voor locatie en accounts). In België geldt 13 jaar als minimumleeftijd voor toestemming onder de AVG. | Kies als doelgroep 13+ (of 18+, met ouders als gebruikers), zet de minimumleeftijd in de voorwaarden en het beleid, en laat in de storevermelding niets naar kinderen onder 13 verwijzen. |

## 3. Middel

| # | Bevinding | Actie |
|---|---|---|
| M1 | **Geofence-receivers staan `exported="true"` zonder toestemmingscontrole** (`NativeGeofenceBroadcastReceiver`, reboot-receiver). Elke andere app kan zo een nep-aankomst of -vertrek binnenschieten, en die kan naar het gezin doorgemeld worden. | `NativeGeofenceBroadcastReceiver` op `exported="false"`: de PendingIntent van Play-services werkt ook zonder export. De boot-receiver kan exported blijven (BOOT_COMPLETED is een beschermde broadcast). Test daarna aankomst en vertrek opnieuw. |
| M2 | **Data safety-formulier.** Veel te declareren: precieze en benaderende locatie (ook op de achtergrond), naam, e-mail, telefoonnummer (profiel en noodcontacten), berichten, foto's, audio (spraakberichten), fysieke activiteit (stappen, activiteitsherkenning), app-interacties en apparaat-ID's (FCM-token). Alles versleuteld onderweg, verwijderbaar zodra B1 af is. | Vul het in vanuit deze lijst. Verkeerde of onvolledige antwoorden zijn een veelvoorkomende reden voor afwijzing. |
| M3 | **Stalkerware-beleid.** Wederzijds delen waarbij ieder zelf instemt (zoals Life360) mag. Dat blijft zo zolang er altijd een vaste melding staat (dat is zo: `setOngoing: true`) en het delen te pauzeren is (ook zo). | Zet **geen** `isMonitoringTool`-vlag: met een onterechte vlag word je afgewezen. Presenteer de app in de storevermelding als wederzijds en vrijwillig delen, nooit als "iemand volgen". |
| M4 | **Google Maps-sleutel.** Die staat in de APK (normaal), maar moet in Google Cloud beperkt zijn tot de package `be.thuisradar.thuisradar` plus de SHA-1 van **zowel de upload-sleutel als de Play App Signing-sleutel**. Anders stopt de kaart in de Play-build of kan iemand de sleutel misbruiken. | Controleer dit in Google Cloud. Doe hetzelfde voor de Firebase/Google Sign-In-clients (SHA-1 van Play App Signing toevoegen). |
| M5 | **Webhook-geheim wordt vergeleken met `!==`** (`send-chat-push/handler.ts:67`, `send-place-push/index.ts:72`), niet in constante tijd. Laag risico, wel makkelijk op te lossen. | Vergelijk in constante tijd (`crypto.subtle.timingSafeEqual` in Deno). |
| M6 | **De SOS-push is alleen in het Nederlands** ("… heeft hulp nodig!", `send-sos-push/index.ts`), terwijl de app 8 talen heeft. | Zend de taal mee of gebruik `title_loc_key`/`body_loc_key`. |
| M7 | **Reviewers hebben toegang nodig.** Zonder account en gezin ziet Google niets. | Maak een testaccount met een gezin (en een tweede lid dat locatie deelt), en zet de gegevens bij "App access" in de Play Console. |

## 4. Laag / onderhoud

- `android:label="CircleBeacon"` en de redirect-scheme `com.circlebeacon.app` tegenover package
  `be.thuisradar.thuisradar`: dat mag, maar zorg dat de storenaam, ontwikkelaarsnaam en het
  privacybeleid dezelfde merknaam gebruiken.
- `applicationId` heeft nog de `TODO`-comment uit de template; het package ligt na de eerste upload vast.
- 12 Dart-bestanden zijn langer dan 300 regels (grootste: `clustered_marker_layer.dart`, 617), terwijl je eigen
  richtlijn ~200 is. Geen blokkade.
- Logging met `debugPrint` (74×) komt ook in release-builds in logcat terecht. Ik vond geen
  tokens of coördinaten in die logs, enkel foutcodes. In orde.

## 5. Wat goed is

- Release-signing met een upload-sleutel; `key.properties` en `*.jks` worden correct genegeerd door git.
- `allowBackup="false"`, ongebruikte foreground service-types verwijderd (`FOREGROUND_SERVICE_HEALTH`).
- Duidelijke melding vóór de locatievraag, die ook "wanneer de app gesloten is" noemt (d764876).
- Vaste melding tijdens het delen, en pauzeren kan.
- RLS op alle tabellen, `security definer`-hulpfuncties, RPC's voor familie aanmaken en joinen, privé
  storage-bucket met familie-mappen, Edge Functions beveiligd met een geheime header.
- Secrets (env.json, google-services.json, service accounts) staan niet in git.
- Featuregerichte opbouw, pure domeinlaag, 165 testbestanden.

## 6. Tests en statische analyse

Uitgevoerd op 21/10 op `034045a`, na `flutter gen-l10n`:

- `flutter analyze`: **0 issues**.
- `flutter test`: **724 tests, allemaal geslaagd**.

Let op: in een verse checkout geeft `flutter analyze` 76 fouten zolang `flutter gen-l10n` nog niet
gedraaid heeft (`lib/l10n/generated/` staat in `.gitignore`). Neem `flutter gen-l10n` op in je
release-checklist en in een eventuele CI-stap.

Niet getest: release-AAB, het gemergde release-manifest, de Edge Functions (Deno-tests) en
gedrag op toestellen (achtergrond, herstart, Doze).

## 7. Volgorde van werken

1. B3: SMS en bellen via een intent (klein, haalt meteen een blokkade weg).
2. H1 + B1: migratie voor opruimen/bewaartermijn en accountverwijdering (functie, knop, webpagina).
3. B2: privacybeleid publiceren en linken.
4. H2, M1, M5: verstevigen (code, receiver, webhook).
5. AAB bouwen met de upload-sleutel, het gemergde manifest controleren (targetSdk 36, rechten), interne test
   in de Play Console.
6. Console: Data safety, locatie- en FGS-declaraties met video, doelgroep, app access, contentclassificatie.

## Bronnen (Play-beleid)

- [SMS- en gesprekslogrechten, uitzonderingen](https://support.google.com/googleplay/android-developer/answer/10208820)
- [Malware/stalkerware-beleid](https://support.google.com/googleplay/android-developer/answer/9888380)
- [Gebruik van de isMonitoringTool-vlag](https://support.google.com/googleplay/android-developer/answer/12955211)
