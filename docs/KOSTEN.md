# Kosten

Thuisradar draait op **gratis** diensten. Alles wat geld kan kosten staat
**uit** of zit **achter een feature flag**. Dit document legt vast wat mag.

## Uitgangspunt

- Geen terugkerende kosten voor een gezinsapp. Enkel gratis tiers.
- Twijfel je of iets kost? Niet toevoegen. Eerst hier bespreken.

## Gratis diensten die we gebruiken

| Dienst | Waarvoor | Gratis? |
|---|---|---|
| **Supabase** (free tier) | Auth, database, realtime, Edge Functions | Ja, binnen de free-limieten |
| **Firebase Cloud Messaging (FCM)** | Push-meldingen (SOS, later aankomst/vertrek) | Ja, gratis |
| **OpenStreetMap-tegels** (via flutter_map) | De kaart op dit moment | Ja (fair-use; eigen `User-Agent` ingesteld) |
| **Google Maps SDK for Android** | *Later*: kaart + satelliet in de app | Ja, de **on-device Maps SDK** heeft geen kaart-laadkosten |

## Niet gebruiken (betalend)

Deze Google-/Maps-API's kosten per aanroep — **niet toevoegen**:

- **Places API** (plaatsen zoeken/autocomplete)
- **Geocoding API** (adres ↔ coördinaten)
- **Directions / Routes API** (routeberekening)

Hebben we zoiets nodig (bv. een adres bij een plaats tonen, of een
route-knop), dan:

1. kies een gratis alternatief (bv. OSM/Nominatim met strikte fair-use, of
   gewoon "Open in Google Maps" via een `geo:`-URL die de kaart-app opent), of
2. zet het **achter een feature flag** die standaard **uit** staat, zodat er
   nooit onbedoeld kosten ontstaan.

## Feature flags

Betaalbare of kosten-gevoelige features worden pas ingeschakeld na een
expliciete keuze. Houd ze centraal en standaard uit. Documenteer per flag wat
hij kost en waarom hij bestaat.

## Bij een latere verkoop

Wil de app ooit verkocht/verspreid worden, dan blijft de regel: de **basis
gratis houden**. Premium-functies (bv. langere geschiedenis, extra plaatsen,
kaartlagen) kunnen dan achter betaalde flags, maar het kerngebruik voor één
gezin mag geen kosten per gebruiker veroorzaken.
