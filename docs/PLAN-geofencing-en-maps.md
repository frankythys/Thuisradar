# Plan — Betrouwbare aankomstmeldingen (native geofencing) & gratis Google Maps

Status: **voorstel** · Taal: Vlaams · Kostenregel: enkel gratis diensten, al wat geld
kan kosten gaat achter een feature-flag (zie `KOSTEN.md`).

Twee losstaande sporen. Ze mogen apart gepland en uitgevoerd worden.

---

## Spoor A — Aankomst/vertrek zoals Life360 (native geofencing)

### Doel
Aankomst- en vertrekmeldingen (met geluid) die **betrouwbaar afgaan, ook als de app
dicht is of slaapt**, zonder dat de gebruiker eerst batterij-instellingen moet aanpassen.

### Huidige situatie
- Detectie gebeurt **server-side**: een Postgres-trigger op `member_locations`
  (`supabase/migrations/005_places.sql`) vergelijkt elke geüploade positie met de
  zones en zet een rij in `family_events` (`arrival`/`departure`).
- Die insert triggert `send-place-push` → FCM-push op kanaal `places_v2` (met geluid).
- **Zwakte:** dit vereist dat het toestel *blijft uploaden* terwijl het aankomt. Slaapt
  de app (Samsung "slapende apps", geen batterij-uitzondering), dan komt er geen upload
  → geen event → geen melding. Vandaar het batterij-gedoe.

### Waarom Life360 het zonder dat gedoe kan
1. Life360 registreert de zones bij de **native Android Geofencing-API**; het
   besturingssysteem zelf wekt de app bij een grensovergang — ook na app-kill.
2. Samsung heeft een witte lijst van populaire apps; nieuwe apps niet.

### Aanpak
Voeg **OS-niveau geofencing op het toestel** toe als primaire detectie. Android bewaakt
de zones en wekt een headless Dart-callback bij enter/exit; die callback legt het event
vast → de bestaande push-keten blijft ongewijzigd.

### Plugin-keuze (gratis)
- **`native_geofence`** — wrapt `GeofencingClient`, ondersteunt een headless
  background-callback. Voorkeur; modern en onderhouden.
- Alternatief: `geofence_service` (foreground-service-gebaseerd).
- **Niet** `flutter_background_geolocation` — dat is betaald (botst met de kostenregel).

### Fasen
1. **Spike** — plugin kiezen; één zone registreren; enter/exit testen met de app
   **weggeveegd** en het scherm vergrendeld. Verifiëren dat de callback vuurt.
2. **Zones registreren** uit de `places`-tabel; her-registreren bij toevoegen/wijzigen/
   verwijderen van een plaats en bij `BOOT_COMPLETED` (plugin regelt dit meestal).
3. **Event vastleggen in de callback** — in de headless isolate Supabase initialiseren
   (sessie wordt door `supabase_flutter` bewaard) en het `arrival`/`departure`-event
   schrijven via een RPC, zodat de bestaande `send-place-push`-keten afgaat.
4. **Ontdubbelen** met de server-side detectie: ofwel server-side uitzetten en enkel op
   geofencing vertrouwen, ofwel een `source`-veld + dedup-venster toevoegen zodat één
   aankomst niet twee meldingen geeft.

### Aandachtspunten / risico's
- **Auth in de headless isolate**: het event schrijven vereist een geldige sessie of een
  RPC die met een device-identifier werkt. Vooraf uitklaren.
- **Android-limieten**: max ~100 geofences per app; minimale praktische straal ~100 m;
  enter/exit heeft inherente vertraging (responsiveness).
- **OEM-variatie**: geofencing is op de meeste toestellen betrouwbaar, maar batterij-
  uitzondering blijft een nuttige extra (vooral voor de *live* kaart, niet meer voor de
  melding zelf).
- **Rechten**: `ACCESS_BACKGROUND_LOCATION` (al toegevoegd) + fijne locatie.

### Kosten
Gratis (plugin + OS-geofencing).

### Klaar wanneer
Fysieke test: binnen- en buitenlopen van een zone met de app weggeveegd en het toestel
vergrendeld geeft binnen enkele minuten een melding **met geluid** bij de andere leden.

---

## Spoor B — Google Maps gratis gebruiken

### Doel
De kaart van OpenStreetMap-tegels naar **Google Maps** overzetten (incl. satelliet),
zonder kosten.

### Kernfeit (de "gratis" grens)
- **Maps SDK for Android** (native, via `google_maps_flutter`) = **gratis, ongelimiteerde
  kaartweergave** op mobiel. Google rekent niets voor native kaart-weergave op Android/iOS.
  Satelliet is inbegrepen.
- Vereist wél een **Google Cloud-project met facturatie ingeschakeld** + een **API-sleutel**
  — maar de kaartweergave zelf kost **$0**.
- **Vermijden (kost geld), conform de kostenregel:** Places API, Geocoding API, Directions
  API en de Maps **JavaScript** API (web). We blijven de **gratis native geocoder**
  gebruiken voor adressen (`geocoding_source.dart`), geen Google-geocoding.

### De grote hobbel: markers
`google_maps_flutter`-markers zijn **bitmaps** (`BitmapDescriptor`), **geen Flutter-widgets**.
Onze avatar-markers, statusballon (met "sinds X", verspringen) en groepspin zijn juist
Flutter-widgets (via `flutter_map` `Marker(child:)`). Twee opties:

- **Optie A — widgets naar bitmap renderen** (`BitmapDescriptor.fromBytes`). Werkt, maar
  de levende ballon en animaties worden statisch en moeten bij elke wijziging opnieuw
  getekend worden.
- **Optie B — Flutter-widgets als overlay** bovenop de `GoogleMap`, gepositioneerd met
  `GoogleMapController.toScreenLocation(...)`. Behoudt onze widgets en logica, maar vereist
  herpositioneren bij elke camerabeweging (maatwerk).

Onze **domeinlogica blijft bruikbaar** — `auto_fit`, `marker_cluster`, `bubble_side`,
`stationary_since` zijn kaart-onafhankelijk (zoals in `CLAUDE.md`). Enkel de presentatie
(`family_map.dart`, `clustered_marker_layer.dart`) verandert.

### Fasen
1. **Cloud-setup** — project aanmaken, **Maps SDK for Android** inschakelen, API-sleutel
   met **restricties** (enkel Maps SDK for Android; app-restrictie op package-naam + SHA-1).
   Sleutel in `android/local.properties` / manifest-placeholder — **nooit in git**.
2. **Feature-flag `useGoogleMaps`** (standaard **uit**, conform kostenregel). Spike:
   een `GoogleMap` renderen naast de bestaande kaart.
3. **Marker-strategie kiezen** (A of B) en prototypen met één lid + ballon.
4. **Volledige port** van de presentatielaag achter de flag; camera (`auto_fit`) koppelen
   aan de `GoogleMapController`.
5. **Satelliet-toggle** toevoegen.

### Aandachtspunten / risico's
- **API-sleutelbeheer**: restricties verplicht, anders misbruikrisico. Sleutel uit git.
- **Facturatie-account vereist** (gratis, maar moet aanstaan) — let op dat er geen betaalde
  API's per ongeluk aangezet worden. `KOSTEN.md` bijwerken.
- **Marker-rework** is het echte werk (zie hierboven).
- **App-grootte** groeit (Google Play Services).

### Kosten
Kaartweergave gratis. Risico zit in *per ongeluk* een betaalde API aanzetten — daarom
blijft dit achter een feature-flag en houden we Places/Geocoding/Directions uit.

### Klaar wanneer
De kaart toont Google Maps (incl. satelliet) achter een flag, met werkende leden-markers,
ballon en groepspin, en zonder dat er in Google Cloud ook maar één betaalde API aanstaat.

---

## Volgorde-advies
1. **Spoor A eerst** — grootste gebruikerswaarde (betrouwbare meldingen) en gratis.
2. **Spoor B daarna** — vooral cosmetisch/satelliet; meer werk door de marker-rework.
