# Volledige audit Thuisradar — 11 oktober 2026

Audit van A tot Z: ritten en ritkaarten, tracking en geofencing, kaart en performantie, Supabase-backend, en de overige features (auth, push, chat, SOS, gezin). Uitgevoerd op branch `claude/sharp-edison-3ekw7g`, vertrekkend van `8047477` (de GPS-ritten-audit van vandaag, zie `GPS_RITTEN_AUDIT_2026-10-11.md`). Daarna is `origin/main` (`5183f95`: A52-rendercrash en bewegingsfilter, zie `A52_HERSTART_DIAGNOSE.md`) in de branch gemerged, zodat die fixes mee in deze build zitten.

**Werkwijze.** Elke bevinding is getraceerd tot een concreet scenario. De belangrijkste zijn eerst met een falende test bewezen en daarna hersteld. Supabase is uitsluitend alleen-lezen bevraagd: SELECT, catalogus, advisors, logs en EXPLAIN zonder ANALYZE. Er is niets aan de live database gewijzigd en geen migratie uitgevoerd. In dit rapport staan geen coördinaten of keys, alleen geaggregeerde tellingen.

**Resultaat.** 25 problemen zijn hersteld, verdeeld over 8 fixcommits, 1 stijlcommit, 1 merge en dit rapport. Daarbij zit 1 nieuwe migratie (016), die de eigenaar zelf moet uitvoeren.
- **Flutter:** 421 tests groen na de merge met `5183f95`, `flutter analyze` 0 issues.
- **SQL:** de tests van 014, 015 en 016 slagen op een lokale PostgreSQL 16.
- **Nog niet getest op een fysiek toestel.** Zie het testplan onderaan.

---

## 1. Samenvatting voor de eigenaar

| Gebied | Toestand vóór | Na deze audit |
|---|---|---|
| Ritdetectie | Overlappende ritten en dubbele kilometers bij een meetgat, verkeerde bestemming na een korte stop, spookritten door binnenshuis-GPS | Hersteld en met tests vastgelegd |
| Ritkaart | Eindpunt op de laatste straat met GPS, routekaart van gisteren niet ingezoomd | Hersteld |
| Vlotheid ritschermen | Alles herberekend elke 5 s, de dag van vandaag elke minuut opnieuw gedownload (ook als het scherm al dicht was) | Eén keer per dag berekend en gecachet, ophalen stopt zonder kijkers |
| Kaart | Groepspin ±160 px te zuidelijk, "stilstaand sinds" altijd 0 min | Hersteld |
| Tracking | Eén `Error` stopte stil alle uploads tot een herstart, ontbrekende snelheid werd "stilstaand" | Hersteld |
| Uitloggen | Pushtoken bleef aan de vorige gebruiker hangen (SOS naar de verkeerde persoon mogelijk) | Hersteld |
| Backend | SOS-alarm kon naar een ander gezin verplaatst worden, oud punt kon de kaart terugzetten, cron-logboek groeide onbeperkt | Migratie 016 (handmatig uitvoeren) |
| A52 | Native crash van de renderer (Impeller/OpenGLES) bij terugkeren, drie keer vastgesteld op 11/10 | Omzeild in `5183f95` (Skia); nog te bevestigen op een nieuwe APK |
| Bewaartermijn locatiegeschiedenis | Geen: alles blijft bewaard (gratis plan vol in ±1 jaar met 4 leden) | **Beslispunt voor de eigenaar** (§4.0), niet automatisch ingevoerd |
| **GPS-gaten** | 102 gaten van meer dan 5 min in de historiek van één toestel (3–10/10) | **Open** (§4.1): op 11/10 vallen 3 van de 4 gaten samen met een A52-crash; voor de oudere gaten is de oorzaak niet bewezen |

### Wat jij nog moet doen

1. **Nieuwe APK bouwen en installeren** vanaf deze branch. De renderer-instelling uit `5183f95` werkt pas in een nieuwe build, hot reload volstaat niet. Controleer daarna op de A52 de stappen uit `A52_HERSTART_DIAGNOSE.md`: geen nieuwe native crash in de crashbuffer.
2. **Migratie 016 uitvoeren.** Open in Supabase › SQL Editor `supabase/migrations/016_audit_hardening.sql` en voer het uit. Het bestand is idempotent en werkt met de huidige app, ervoor of erna. Controle achteraf: `select jobname from cron.job;` moet `thuisradar-cron-log-cleanup` tonen, en `select tgname from pg_trigger where tgname in ('sos_alerts_guard','member_locations_order_guard');` beide triggers.
3. **Beslissen over een bewaartermijn** voor de locatiegeschiedenis (§4.0). Er wordt niets automatisch gewist zolang je niet beslist.
4. **Leaked Password Protection aanzetten** in Supabase › Authentication › Policies. Dit staat nu uit (advisor).
5. **Edge function `send-place-push` opnieuw deployen** vanuit de repo. De live versie (v8) gebruikt nog kanaal `places` en het standaardgeluid, de repo gebruikt `places_v2` en `thuisradar_arrival`.
6. **Het testplan** (§6) doorlopen op de Samsung A52 en de emulator.

---

## 2. Herstelde problemen (met bewijs)

### 2.1 Ritten en ritkaarten — commits `73df730` en `b79aacd`

| # | Ernst | Probleem | Fix | Test |
|---|---|---|---|---|
| R1 | Kritisch | De aankomstlogica koos het eerste verblijf binnen 20 minuten na de laatste ritmeting, zonder te kijken of er nog een rit tussen lag. Een meetgat midden in een rit gaf zo 12,4 km in plaats van 7,8 km, en twee overlappende ritten. Na een korte stop (school) werd de *volgende* stop (bakker) de bestemming. | De aankomst telt alleen over een echt meetgat (geen meting buiten de stopstraal tussendoor), of als een verblijf dat al loopt. | `trip_accuracy_test.dart`: meetgat midden in een rit en korte stop als bestemming |
| R2 | Hoog | Eén binnenshuis-uitschieter van meer dan 100 m zette de stilstand-teller terug. Met om de paar minuten zo'n meting werd een avond thuis een reeks spookritten, en viel ook het verblijf in stukken. | Pas een tweede meting op rij buiten de straal geldt als vertrek. Losse uitschieters (A → ver → terug bij A binnen 45 s) vallen weg vóór de tijdlijn en de ritten. | `trip_accuracy_test.dart`: binnenshuis-uitschieters |
| R3 | Middel | `withoutSpikes` hield een fout eerste punt (na een tunnel of meetgat) als anker en gooide de echte punten erna weg. De grens van 45 m/s liet bovendien snel snelwegrijden met wat GPS-ruis wegvallen. | Een fout eerste anker valt weg als de volgende meting bij de huidige past. De grens is nu 70 m/s, gelijk aan de bewegingsfilter en de routekaart. | Sprong na meetgat, snelweg aan 180 km/u |
| R4 | Middel | Topsnelheid uit één Doppler-piek ("max 216 km/u"). | Een piek telt alleen als een buurmeting minstens 60% haalt. | Doppler-piek |
| R5 | Middel | De ritkaart eindigde op de laatste straat met GPS, niet op de bestemming. De routekaart van "gisteren" was gecentreerd op de huidige positie van vandaag. | Het spoor eindigt op de bestemming, zonder lijn over het meetgat. De kaart van gisteren zoomt op de route. | `day_driving_test.dart` |
| R6 | Middel | Op zondag 25/10 (wintertijd, 25 uur) ontbrak het laatste uur van de dag: middernacht + 24 u = 23:00. Op 29/3 en 30/3 stond "Vandaag" bij gisteren, rekende de weekkiezer verkeerd en haalde de chip "Gisteren" eergisteren op. | Dagvensters lopen tot de volgende lokale middernacht. Datumverschillen worden in kalenderdagen berekend (`core/utils/calendar.dart`). | `calendar_test.dart`, `day_driving_test.dart`, ook uitgevoerd met `TZ=Europe/Brussels` |
| R7 | Middel | De 30-dagenweergave filterde geen GPS-sprongen. Een opgeslagen sprong van 8.868 km (één gezinslid, 7/10) verscheen dus als "Onderweg · 8868 km". | `withoutSpikes` ook daar. | — |
| P1 | Hoog (vlotheid) | De ritschermen volgen een klok die elke 5 s tikt. Bij elke tik werden de ritten van 7 dagen herberekend, en per rit werden alle punten van de dag opnieuw gefilterd en gesorteerd. Alle ritkaarten van een week werden tegelijk opgebouwd. | Nieuwe `DayDriving` (domain) + `dayDrivingProvider`: activiteiten en het spoor per rit worden één keer berekend, alleen als de geschiedenis of de plaatsen veranderen. De lijsten zijn lui, dus alleen zichtbare kaarten worden opgebouwd. Toekomstige dagen worden niet opgehaald. | `day_driving_test.dart` |
| P2 | Hoog (data/batterij) | `dayHistoryProvider` was niet `autoDispose`. Wie ooit een gezinslid opende, liet de app de hele dag van dat lid elke minuut opnieuw downloaden, tot een herstart. | `autoDispose`. Vandaag ververst alleen zolang iemand kijkt, afgelopen dagen blijven nog 5 min bewaard. | Bestaande provider-tests |
| P3 | Middel | De time-out van 10 s gold voor alle pagina's samen. Een drukke dag (±1.500–4.600 punten) of week kon daardoor "Laden mislukt" geven. | De time-out geldt per pagina van 1000 punten. | — |

### 2.2 Tracking — commit `05bead1`

| # | Ernst | Probleem | Fix | Test |
|---|---|---|---|---|
| T6 | Middel→Hoog | De uploadketen (`_uploads.then(...)`) had geen foutafvanger. Eén `Error` (geen `Exception`) liet daarna elke meting stil overslaan tot de app herstartte. | `catchError` op de keten. | `location_tracker_reliability_test.dart`: faalt zonder de fix (1 upload), slaagt met de fix (2) |
| T7 | Middel | Android laat snelheid en nauwkeurigheid weg als het ze niet mat. Geolocator maakte daar 0,0 van, dus een rijdende auto met een wifi-fix werd "stilstaand" en een grove fix "exact". | `hasSpeed` en `hasAccuracy` worden gebruikt; een ontbrekende waarde blijft onbekend. | Gecontroleerd in de broncode van geolocator 4.4.0 |
| T8 | Middel | De leeftijd van een meting werd gemeten nadat ze achter trage uploads had gewacht, waardoor verse metingen als "te oud" geweigerd werden. | Leeftijd vanaf ontvangst. | — |

### 2.3 Auth, push en gezin — commit `e2c7ca3`

| # | Ernst | Probleem | Fix |
|---|---|---|---|
| A1 | Kritisch | Het pushtoken werd pas *na* `signOut` verwijderd. Zonder sessie filterde RLS die delete stil weg. Mislukte daarna `deleteToken()` (offline), dan bleef het toestel SOS-, chat- en plaatsmeldingen van de vorige gebruiker krijgen. | Het token wordt van de server gehaald vóór het afmelden. |
| A2 | Hoog | Een fout op de auth-stroom (token verversen zonder bereik) verving de hele app door een foutscherm zonder knop om opnieuw te proberen. Tab, chattekst en weggetikte SOS gingen verloren. | Tijdelijke fouten worden genegeerd; gotrue probeert zelf opnieuw. Test: `auth_repository_test.dart`. |
| A3 | Middel | Offline uitloggen gooide een exceptie en het profielscherm bleef open. | Afgevangen, het scherm sluit. |
| A4 | Middel | Gezin aanmaken of joinen zonder netwerk: geen enkele melding. | Nederlandse foutmelding. |

### 2.4 Kaart — commit `164d50e`

| # | Ernst | Probleem | Fix | Test |
|---|---|---|---|---|
| K1 | Hoog | Een groepspin (2+ leden samen, niet thuis) hing **onder** de locatie. Het puntje wees ±160 px (±400 m op zoom 15) te zuidelijk. | De groep staat net als een los rondje boven zijn punt, met het puntje op de plek. | `group_pin_anchor_test.dart`: 460 → 300 px |
| K2 | Hoog | `stationarySinceProvider` wiste zijn begintijd in `onDispose`. Riverpod roept dat ook aan vóór elke herberekening, dus "stilstaand sinds" stond bij elke upload (elke 15 s) weer op 0. | Die `onDispose` is weg. | `stationary_since_provider_test.dart`: 13:00:30 → 13:00:00 |
| K3 | Middel | `HomeShell` herbouwde alle tabs bij elke locatie-update van elk lid. | `select` op de leeg/niet-leeg-vlag. | — |

### 2.5 Realtime-streams — commit `bf8abf4`

| # | Ernst | Probleem | Fix |
|---|---|---|---|
| S1 | Hoog | `order('created_at')` op een Supabase-stream staat standaard op **aflopend**, terwijl het chatscherm oplopend verwacht. Meldingen en SOS hadden geen volgorde en geen grens. Boven 1000 rijen (meldingen: ±6 weken tot 4 maanden) kwamen willekeurige oude rijen terug en ontbraken de nieuwste. | Expliciet de nieuwste ophalen en client-side sorteren, met een grens: chat 500, meldingen 300, SOS 100. |

### 2.6 Backend — migratie 016 (`08d9a03`, aangevuld in de laatste commit)

| # | Ernst | Probleem | Fix |
|---|---|---|---|
| D1 | Middel | Een upload-time-out annuleert de request niet. Een ouder punt dat ná een nieuwer binnenkwam, zette de kaart terug in de tijd en liet de zones op een oude plek evalueren (valse aankomst of vertrek). Live zijn er 10 dubbele `(user_id, recorded_at)`. | BEFORE UPDATE-trigger: een ouder punt gaat alleen naar de geschiedenis, een dubbel punt wordt genegeerd. Een toestelklok die voorliep bevriest de kaart niet. |
| D2 | Middel | De SOS-update-policy controleerde alleen `user_id`. Een (ex-)lid kon een eigen alarm naar een ander gezin verplaatsen of stil heractiveren. | Twee lagen. **Policy:** alleen het eigen alarm, alleen als lid van het huidige gezin, en alleen naar `status = 'resolved'`. Een policy kan de oude rij echter niet met de nieuwe vergelijken; ze verbiedt dus niet zelf dat `family_id` naar een ander gezin waarvan je ook lid bent verandert. **Trigger `sos_alerts_guard`:** weigert expliciet elke wijziging van `family_id`, `user_id`, `lat`/`lng`, `created_at` en `id`, en het heropenen van een opgelost alarm. Dat geldt voor iedereen, ook via het dashboard. Alleen `status` → `resolved` en `resolved_at` mogen veranderen. SQL-test `016_audit_hardening_test.sql`: verplaatsen, locatie of afzender wijzigen en heropenen worden geweigerd, (opnieuw) oplossen mag. De test draait als superuser, dus hij bewijst de trigger maar niet de RLS-policy (zie §4.7). |
| D3 | Laag | `cron.job_run_details` krijgt elke minuut een rij (±525.000 per jaar). Dat is het uitvoeringslogboek van pg_cron, met alleen de jobstatus en geen gebruikersgegevens. | pg_cron ruimt rijen ouder dan 7 dagen op. De locatiegeschiedenis wordt **niet** aangeraakt; zie §4.0. |
| D4 | Laag | 3 functies zonder vaste `search_path` (advisor). | Vastgezet. |

### 2.7 Vervolgronde (na de audit)

| # | Ernst | Probleem | Fix | Test |
|---|---|---|---|---|
| V1 | Hoog | Een uitnodigingscode vervalt nooit en is niet in te trekken; de beheerder kan niemand verwijderen. | Migratie 017: een code is 7 dagen geldig, `join_family` weigert een verlopen code, `rotate_invite_code` en `remove_member` alleen voor de beheerder. Verwijderen haalt het lid ook van de kaart en vernieuwt de code. In de app: vervaldatum, "Nieuwe code maken" en een verwijderknop in het gezinsblad. | SQL `017_invite_expiry_test.sql` (15 checks), `invite_renew_test.dart`, `remove_member_test.dart` |
| V2 | Hoog | Het wachtwoord werd bij "Onthouden" bewaard en na uitloggen opnieuw ingevuld. | Alleen het e-mailadres wordt nog onthouden. Een oud bewaard wachtwoord wordt bij het eerste lezen gewist. Uitloggen wist ook het wachtwoord van de vingerafdruk-login. | `biometric_login_test.dart`, `login_screen_test.dart` |
| V3 | Middel | Een rit over middernacht viel in twee stukken (23:50–00:20). | Per dag wordt 3 u marge opgehaald. Een rit telt op zijn vertrekdag en blijft heel; verblijven worden op de dag afgeknipt. | `midnight_trip_test.dart` |

---

## 3. Gecontroleerd en in orde

- **RLS:** aan op alle 15 tabellen. Er is geen pad om locaties, historiek, chat of media van een ander gezin te lezen. Alle security-definer-functies hebben `search_path`.
- **Live versus repo:** 19 functies, policies, triggers, publicatie, cron en bucket zijn identiek. De enige afwijking is `send-place-push`.
- **Cron `confirm-pending-departures`:** 263 runs, allemaal geslaagd (gemiddeld 5 ms).
- **Dag-query:** EXPLAIN geeft een index scan op `(user_id, recorded_at desc)`. Paginering omzeilt de limiet van 1000 rijen.
- **Tijden:** overal `timestamptz`. De app schrijft UTC (`toUtc`) en leest lokaal (`toLocal`).
- **Wachtrij-fix van de vorige audit:** de geofence-meldingen met een sleutel per melding zijn correct.
- **Bestaande audit-fixes:** de rondrit-fix, de afstand na het sprongfilter en de merge-regel voor verblijven werken.
- **OSM:** de `userAgentPackageName` klopt, de naamsvermelding staat er, tegels worden op schijf gecachet.
- **Secrets:** alleen de publishable key in de app, geen tokens of coördinaten in de logs, `allowBackup=false`.
- **AutoFitController:** trekt de gebruiker niet terug na een gebaar.

---

## 4. Open bevindingen (geprioriteerd)

Niet in deze audit hersteld. Deze punten zijn groter, vragen een productkeuze, of vragen een test op een toestel.

### 4.0 Beslispunt: bewaartermijn locatiegeschiedenis

Dit is een keuze over persoonsgegevens, geen technische reparatie. Daarom zit het niet in migratie 016.

- **Feiten:** `location_history` telde 16.063 rijen in ±8,5 dagen (±1.500 per actief lid per dag, ±205 bytes per rij inclusief index). Met 4 actieve leden is dat ±450 MB per jaar; het gratis plan heeft 500 MB. Nu wordt niets opgeruimd.
- **Wat de app nodig heeft:** de weekkiezer gaat 12 weken terug (±84 dagen), de detailweergave 30 dagen.
- **Afwegingen:**
  - Een kortere termijn betekent minder gevoelige gegevens en minder opslag, maar oudere ritten zijn dan weg.
  - Een termijn korter dan 84 dagen maakt oudere weken in de weekkiezer leeg.
  - Wordt het een termijn, vermeld die dan aan de gezinsleden (AVG: transparantie).
- **Uitvoeren na een beslissing** (vervang `N` door het gekozen aantal dagen, in de SQL Editor):

```sql
select cron.schedule('thuisradar-history-cleanup', '17 3 * * *',
  $$delete from public.location_history where recorded_at < now() - interval 'N days'$$);
```

Ongedaan maken: `select cron.unschedule('thuisradar-history-cleanup');` Al gewiste rijen komen daarmee niet terug.

### 4.1 Hoog: volledigheid van ritten (GPS-gaten)

De historiek van één toestel bevat 102 meetgaten van meer dan 5 minuten (3–11 oktober). **De oorzaak daarvan is niet bewezen.** De tellingen tonen dat er gaten zijn, niet waarom. Hieronder staan de kandidaat-oorzaken, van vastgesteld naar vermoed.

0. **Vastgesteld: native crashes op de A52.** Op 11/10 om 10:00:32, 11:50:39 en 12:51:35 crashte de app met `SIGSEGV` in de Impeller/OpenGLES-renderer (`A52_HERSTART_DIAGNOSE.md`). Een crash beëindigt het proces en daarmee de GPS-stroom; tot de app weer opent wordt er niets gemeten. **Nagegaan voor 11/10 (alleen-lezen query op `location_history`, Europe/Brussels):** het toestel had die dag 4 gaten van meer dan 5 minuten. Drie ervan beginnen enkele seconden vóór een vastgestelde crash:

   | Laatste meting vóór het gat | Crash (crashbuffer) | Eerste meting na het gat | Gat |
   |---|---|---|---|
   | 10:00:30 | 10:00:32 | 10:13:13 | 12,7 min |
   | 11:50:20 | 11:50:39 | 11:56:26 | 6,1 min |
   | 12:51:33 | 12:51:35 | 13:07:13 | 15,7 min |
   | 09:39:18 | — (geen crash bekend) | 09:56:25 | 17,1 min |

   Voor die dag zijn de crashes dus **aangetoond** de oorzaak van 3 van de 4 gaten. Het gat van 09:39 heeft een andere, onbekende oorzaak. Voor de 102 gaten van 3–10 oktober is dit **niet** nagegaan: de crashbuffer van die dagen is niet gelezen.
   - *Omzeild in `5183f95`* (Skia in plaats van Impeller), nog te bevestigen op een nieuwe APK.
   - *Na te gaan:* de crashtijden en de crashbuffer (`adb logcat -b crash`) naast de gaten in `location_history` leggen, en de locatiediagnose-export van dezelfde dag erbij nemen.

De volgende oorzaken volgen uit de code en het gedrag van de plugins. Ze zijn mogelijk, maar niet aangetoond op een toestel:

1. **Tracking stopt bij wegvegen uit recents, een proceskill (Samsung "slapende apps") of een reboot.** De GPS-dienst van geolocator is gebonden aan de Activity-engine en herstart niet. Alleen de zones komen terug na een reboot.
   - *Op korte termijn:* een onboarding-stap "niet wegvegen", met Samsung-instructies ("Nooit slapende apps") en een melding als er lang niets geüpload is.
   - *Structureel:* een *gestarte* voorgronddienst (`stopWithTask=false`), los van de Activity, met boot-start.
2. **Geen offline buffer.** Een mislukte upsert gooit het punt weg, dus 12 minuten zonder data zou 12 minuten zonder spoor betekenen.
   - *Fix:* een lokale persistente wachtrij, en de achterstand in batch naar `location_history` via een RPC (nieuwe migratie), met ontdubbeling op `(user_id, recorded_at)`.
3. **Koude start zonder netwerk: tracking start nooit.** De tracker start pas in `MapScreen`, en dat scherm komt pas na een online `myFamilyProvider`.
   - *Fix:* `familyId` lokaal cachen en de tracker starten vanuit een listener op het hoogste niveau.
4. **Herstel op de achtergrond probeert de voorgronddienst opnieuw te starten.** Op Android 12+ geeft dat een `ForegroundServiceStartNotAllowedException`, en daarna blijft de stroom stil zonder dat de app het merkt.
   - *Fix:* `getServiceStatusStream()`, exponentiële backoff, en een waakhond op `_lastFixAt` in de diagnose-heartbeat.
5. **Batterij:** `LocationAccuracy.high` elke 5 s, een permanent wakelock, en ook stilstaand een upload elke 15 s (±5.760 rijen per dag mogelijk).
   - *Fix:* bij bevestigde stilstand uploaden om de 60–120 s, en een adaptieve GPS-stroom.
6. **Een sessie die verloopt** (refresh token geweigerd) stopt tracker, geofences en de toestelsleutel niet. Alleen uitloggen via het profiel doet dat.
   - *Fix:* een `ref.listen(currentUserIdProvider)` op het hoogste niveau.

### 4.2 Hoog: security en privacy

1. ~~**De uitnodigingscode** vervalt nooit, is niet te roteren, en de eigenaar kan een lid niet verwijderen.~~ **Opgelost** in `e451824` + migratie 017 (zie §2.7). Nog open: de code blijft 8 hex-tekens (32 bit, compatibel met het invoerveld) en er is geen limiet op het aantal join-pogingen. De locatiegeschiedenis van een verwijderd lid blijft zichtbaar voor het gezin (zie §4.0).
2. ~~**Het wachtwoord wordt standaard bewaard** en na uitloggen weer ingevuld.~~ **Opgelost** in `f1fae7b` (zie §2.7). Nog open: zolang de vingerafdruk-login aan staat en je ingelogd bent, staat het wachtwoord versleuteld op het toestel. De biometrie is een controle in de app, niet cryptografisch aan de sleutel gebonden.
3. **Als Firebase niet initialiseert, crasht de app** (grijs scherm), terwijl `main.dart` "zonder push" belooft. Dat is relevant voor een latere iOS-build zonder plist.
   - *Fix:* `PushGate` alleen actief als `Firebase.apps.isNotEmpty`.
4. **Een lid dat het gezin verlaat, blijft met zijn laatste locatie en historiek zichtbaar.** Er is ook geen DELETE-policy op de eigen historiek, wat relevant is voor de AVG.
5. **Brede grants:** `anon`/`authenticated` hebben EXECUTE op `net.http_post`. Dat is nu waarschijnlijk niet via de API bereikbaar; controleer of `net` niet bij de "exposed schemas" staat.

### 4.3 Middel: ritten (functioneel)

1. ~~**Ritten over middernacht** worden gesplitst.~~ **Opgelost** in `a35e12d` (zie §2.7). Nog open: een nachtrit die langer dan 3 uur na middernacht doorloopt, wordt na die 3 uur afgekapt, en het weekrapport splitst nog op de grens zondag → maandag.
2. ~~**Het weekoverzicht en de dagkaarten** gebruiken verschillende algoritmes. Het rapport vereist 25 km/u of meer; de dagkaart toont elke verplaatsing vanaf 100 m (ook wandelen) met het auto-icoon.~~ **Opgelost** in `1c513fb` en `39871ef`: het weekrapport bouwt op `buildDayActivities`, elke verplaatsing krijgt een vervoermiddel (`classifyTravel`), en wandelen en fietsen staan apart in de tab Onderweg.
3. **De 30-dagenweergave** haalt ±45.000 ruwe punten op (±45 pagina's na elkaar) om enkel verblijven te tonen.
   - *Fix:* aggregatie op de server (RPC of view per dag), of decoderen en `buildTimeline` in een isolate.
4. **Eén mislukte dag** in de weekweergave verdwijnt zonder melding.
5. **Live wegcorrectie:** de Overpass-vakken zijn in steden te groot (>2 MB, verworpen zonder negatieve cache, dagbudget snel op), en `compute()` kopieert het hele wegennet per fix.

### 4.4 Middel: geofencing

1. Het tijdstip van een zonemelding is de uitvoeringstijd van de WorkManager-worker. In Doze kan dat minuten tot uren te laat zijn.
2. Tijdelijke serverfouten (5xx, deadlock, statement-timeout) worden als definitief behandeld en de melding gaat verloren. De wachtrij wordt alleen bij een volgende overgang geleegd.
3. **Valse aankomsten:** de Android-zone is minstens 100 m, terwijl een plaats 50 m kan zijn, en een aankomst vraagt geen bevestiging. Voorbijrijden op 80 m geeft dan een melding.
4. De server-cron bevestigt ook een vertrek dat alleen uit één foute server-fix kwam (`pending_source` ontbreekt).
5. Er is geen banner als "Altijd toestaan" of de batterijvrijstelling ontbreekt.
6. `NativeGeofenceBroadcastReceiver` staat op `exported="true"`; `false` is voldoende.

### 4.5 Middel: vlotheid kaart en UI

1. De markerlaag herbouwt alle markerwidgets per frame tijdens animaties, en GPS-ruis bij stilstand start elke 15 s een animatie van 2 s. *Fix:* een dode zone van ±15 m bij stilstand en gecachte markerwidgets.
2. `familyMembersProvider` gebruikt geen `resilientStream`. Bij een kanaalfout flitst de kaart leeg, en profielwijzigingen (naam, telefoon) komen niet binnen.
3. Adressen worden per raster van 5,5 m opgevraagd. Dat geeft veel geocoder-oproepen en flikkerende tekst tijdens het rijden.
4. "Sinds HH:mm" in de ledenlijst toont de laatste upload, niet het begin van het verblijf.
5. Chat:
   - een `AudioPlayer` per bubbel, ook bij foto's;
   - een signed URL van 300 s, dus na 5 minuten opnieuw afspelen faalt;
   - foto's zonder `cacheWidth`;
   - een volledige FlutterMap per gedeelde locatie.
6. `AddPlaceScreen` herbouwt het hele formulier per frame tijdens het slepen.
7. Op het Google Maps-pad (achter de vlag) worden markerbitmaps te vaak opnieuw gerenderd.

### 4.6 Middel: SOS en edge functions

1. SOS offline: geen wachtrij of herhaalpoging, en geen voorstel om te sms'en of 112 te bellen.
2. Alarmen vervallen niet, en wegtikken wordt niet bewaard.
3. Twee keer inhouden geeft twee alarmen.
4. `send-sos-push` en `send-place-push`: geen try/catch, `Promise.all`, en de rij wordt niet opnieuw gelezen. Bij een fout gaat een SOS-push stil verloren.
   - *Fix:* `allSettled`, try/catch, het OAuth-token cachen, `timingSafeEqual`.

### 4.7 Laag

- Advisors: 15 policies met `auth.uid()` zonder `(select …)`, en 11 foreign keys zonder index. Op deze schaal nog geen probleem.
- `families.created_by` en `places.created_by` met `ON DELETE NO ACTION` blokkeren het verwijderen van een account.
- `supabase/tests` draait als superuser, dus RLS-policies (ook die van 016) worden niet getest; de triggers wel. `run.sh` gooit de foutoutput van het laden weg.
- `flutter_svg` en `cupertino_icons` worden niet gebruikt.
- Assets: ±5 MB aan splash-bronnen en een auto-afbeelding van 1254² voor een weergave van 38×32.
- Lint: `discarded_futures` toevoegen; `unawaited_futures` mist futures in synchrone callbacks.

---

## 5. Commits van deze audit

| Commit | Inhoud |
|---|---|
| `1833ab0` | `dart format -l 110`, geen logicawijziging |
| `73df730` | Ritten één keer per dag berekend, autoDispose, dagvenster bij zomertijd, time-out per pagina |
| `b79aacd` | Bestemming, afstand, spookritten, sprongfilter, topsnelheid, ritkaart, kalenderdagen |
| `05bead1` | Uploadketen, `hasSpeed`/`hasAccuracy`, leeftijd vanaf ontvangst |
| `e2c7ca3` | Pushtoken vóór afmelden, auth-stroomfout, offline uitloggen, foutmelding gezin |
| `164d50e` | Groepspin, stilstaand sinds, HomeShell-rebuilds |
| `bf8abf4` | Volgorde en grens van chat, meldingen en SOS |
| `08d9a03` | Migratie 016 + SQL-test |
| `02d2847` | Merge van `origin/main` (`5183f95`): A52-rendercrash, bewegingsfilter, eerste kaartbeeld |
| (laatste) | 016: SOS-trigger tegen verplaatsen en heropenen, bewaartermijn eruit (beslispunt), rapport bijgewerkt |

## 6. Testplan op een toestel (Samsung A52 "Papa" + emulator "Liam")

1. **Rit met tunnel of parkeergarage.** Rij naar een plek waar de GPS even wegvalt vlak voor aankomst. Controleer:
   - de rit eindigt op de bestemming;
   - het eindpunt op de ritkaart staat op die plek;
   - de kilometers zijn niet dubbel.
2. **Korte stop.** Rij thuis → school (5–10 min blijven) → winkel. Je moet twee aparte ritten zien, met de juiste bestemmingen.
3. **Avond thuis.** De volgende ochtend: geen ritten tussen thuiskomst en vertrek.
4. **Groepspin.** Twee toestellen samen op een plek die geen opgeslagen plaats is. Het puntje moet op de plek staan, ook bij zoom 15.
5. **Stilstaand sinds.** Blijf 10 min stilstaan buiten een plaats. De ballon moet ±10 min tonen, niet 0.
6. **Uitloggen en wisselen.** Papa logt uit en Liam logt in op hetzelfde toestel. Stuur een SOS vanaf een ander toestel: alleen Liams gezin mag die krijgen.
7. **Chat.** Het nieuwste bericht staat onderaan.
8. **Wintertijd.** Op zondag 25/10 laat 's avonds een rit maken. De rit moet op 25/10 staan.
9. **Na migratie 016.** Rij een stuk met slechte 4G. De kaart mag niet terugspringen naar een oudere positie.
10. **A52-renderer (nieuwe APK).** Kaart openen, zoomen, een persoon selecteren, naar het startscherm en de app heropenen. Zoom en selectie moeten blijven staan, en de crashbuffer mag geen nieuwe native crash tonen.
11. **Gaten na de crashfix.** Na een paar dagen met de nieuwe APK: tel opnieuw de gaten van meer dan 5 minuten. Zijn ze sterk gedaald, dan waren de crashes een hoofdoorzaak. Blijven ze, dan is §4.1 (achtergrond en offline) de volgende stap.
