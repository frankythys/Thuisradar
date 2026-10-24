# Onderzoek vertraging Google-kaart — 13 oktober 2026

## Conclusie

De aangeleverde Android-log bewijst ernstige framehaperingen. Er is geen bewijs dat één Google-instelling, de internetverbinding of de API-sleutel alle vertraging veroorzaakt. De sterkste aanwijzingen zijn: zware native Maps-initialisatie, gelijktijdige geofence-achtergrondengines en debugcompilatie. De kaartarchitectuur voegt bovendien een asynchrone camera-overdracht en bitmapgeneratie toe, die achterlopen bij slepen en later verschijnen van ballonnen kunnen verklaren.

Dit is een onderzoek van de volledige aangeleverde log, applicatiecode en relevante lokaal geïnstalleerde pluginbron. Er is geen nieuwe prestatiemeting op de Samsung uitgevoerd. Oorzaken zijn daarom hieronder als bewezen gedrag of nog te meten bijdrage beschreven. Applicatiecode is niet aangepast.

## Gemeten in de aangeleverde log

Bron: `C:/Users/frank/.codex/attachments/1bc63ac7-e32a-4457-a1b2-7ba3c85a5fa9/Geplakte tekst.txt`. Regelnummering verwijst naar dat bestand.

| Signaal | Waarde | Betekenis en beperking |
|---|---:|---|
| Supabase initialisatie, regel 105 | 347 ms | Deel van opstart, niet afzonderlijk kaartladen. |
| Firebase gereed, regel 107 | 53 ms extra | Totaal 400 ms sinds de diagnostische stopwatch startte. |
| Eerste Flutter-frame, regel 108 | 1690 ms totaal | Eerste appframe; geen bewijs dat kaarttegels dan zichtbaar zijn. |
| Trage Flutter-builds, regels 135, 415, 603 | 177 / 125 / 204 ms | Veel groter dan circa 16,7 ms framebudget bij 60 Hz. Debugmodus beïnvloedt deze cijfers. |
| Grootste gelogde frame, regel 523 | 574 ms | Build 11 ms, raster 2 ms, vsync-overhead 561 ms. Dit wijst op laat beginnen van framewerk, niet op 574 ms Flutter-tekenwerk. De blokkade zelf wordt niet geïdentificeerd. |
| Android overgeslagen frames | o.a. 117 / 74 / 57 / 54 / 51 | Android meldt expliciet haperingen op de hoofdthread. Niet optellen tot totale kaartlaadtijd: meetvensters ontbreken. |
| Geofence-worker, regels 489 en 533 | 2208 / 1640 ms | Twee achtergrondtaken tijdens deze sessie; hun hele looptijd is geen bewijs van even lange UI-blokkade. |
| Maps TilePrep lock-wachttijden | o.a. 292 / 167 / 157 / 140 / 112 ms | Concrete wachttijden binnen Google Maps. Niet automatisch allemaal blokkades van de UI-thread. |
| Cronet fallback, regel 573 | waarschuwing | SDK meldt minder efficiënte HTTP-verwerking en ontbrekende cachingmogelijkheden in deze fallback. Werkelijke invloed op tegelduur is niet gemeten. |

De bestaande `StartupDiagnostics` logt maximaal eens per vijf seconden een slecht frame en alleen vanaf 100 ms. Dit is een steekproef, geen volledige framerapportage. De stopwatch begint na `WidgetsFlutterBinding.ensureInitialized()` en de eerste diagnostische setup; 1690 ms is dus ook niet de volledige tijd vanaf het starten van het proces.

## Bevindingen in code en pluginbron

### 1. Google volgt een tweede kaartcamera

`family_map.dart` bouwt een `GoogleMapStack`: Google Maps onderaan, een transparante `FlutterMap` erboven. Google-gebaren zijn uitgeschakeld. Gebaren veranderen eerst de FlutterMap-camera; `google_base_map.dart:87` ontvangt vervolgens een event en `_sync()` stuurt bij `:194` een asynchrone `moveCamera` naar de native kaart.

De code houdt maar één cameraopdracht tegelijk in vlucht en slaat tussentijdse standen over. Dit voorkomt een onbeperkte wachtrij, maar maakt Google afhankelijk van de overdracht en native verwerking. Bij native belasting kan de ondergrond zichtbaar achterlopen. Er is geen timing van event tot native cameraframe, dus de precieze bijdrage blijft onbekend. Er wordt hier `moveCamera`, niet `animateCamera`, gebruikt: een lange camera-animatie is niet aangetroffen.

### 2. Ballonnen wachten en worden naar PNG omgezet

`google_base_map.dart:122` laat markertekenen wachten op zowel afbeelding-precache als de eerste `onCameraIdle`. Dat event bewijst geen volledig geladen tegelbeeld. `google_member_markers.dart` voegt 40 ms samenvoegwachttijd toe en begrenst nieuwe renderstarts tot intervallen van 200 ms. Bestaande markerposities worden maximaal ongeveer 30 keer per seconde bijgewerkt.

`widget_bitmap.dart` bouwt en tekent een aparte widgetboom, leest pixels terug en encodeert PNG. De gewone markerafbeeldingen worden wel gecachet. Bij gewijzigde inhoud of layout kan opnieuw tekenen nodig zijn. Animaties renderen hun frames achter elkaar; de wandelreeks gebruikt maximaal 19 beelden. In `_render()` volgt de publicatie pas na het verwerken van de geselecteerde specs. Een dure animatie kan daarmee andere nieuwe markerafbeeldingen later laten verschijnen.

De betreffende code is een concrete bron van extra werk en wachttijd. De log bevat geen afzonderlijke bitmapduur of aantallen markerupdates; het aandeel in de waargenomen haperingen is niet bewezen.

### 3. Geofencing start tegelijk met de kaart

`map_screen.dart:91` start geofencebewaking na het eerste schermframe. `geofence_sync.dart:56` herregistreert opgeslagen zones via `recreateAll()`. De plugin `native_geofence-1.3.1` hermaakt hierbij alle opgeslagen geofences met hun opgeslagen instellingen; de operatie filtert niet op de huidige familie.

Nieuwe zones krijgen in `native_geofence_source.dart:54` terecht lege `initialTriggers`. Herregistratie hergebruikt echter de eerder opgeslagen instellingen. Als oudere zones andere initial triggers hebben, kunnen die bij herregistratie terugkomen. Dat is een te controleren mogelijkheid, geen bewezen toestand van dit toestel.

De log toont twee workerstarts met tijdelijk twee verbonden Flutter-engines, inclusief plugininitialisatie. De serverantwoorden zijn `already_outside` en `already_inside`. Dat bewijst dat deze meldingen de serverstatus niet veranderden; het bewijst geen oneindige lus. Wel is het herhaald starten van engines tijdens kaartladen een duidelijke kandidaat voor CPU-concurrentie. De framehapering van 574 ms valt in de logvolgorde tijdens de tweede worker.

### 4. Maps zelf verricht zwaar opstartwerk

De log toont het dynamisch laden van de Google Maps-module, native bibliotheekinitialisatie, JIT-compilatie, tegelvoorbereiding en lock-wachttijden. Google meldt `loadedRenderer: LATEST`. Een oude Google Maps-renderer is daarom geen aangetoonde oorzaak.

De fallback-Cronetwaarschuwing en Google Play services-brokerfout verdienen controle als tegelvertraging in profile/release blijft bestaan. De brokerfout noemt `com.google.android.gms`, niet een expliciete Maps-autorisatiefout voor de app. Uit deze melding volgt niet dat de Maps API-sleutel onjuist is. De vele Floggerwaarschuwingen bewijzen evenmin hoeveel tijd logging kost.

### 5. Debugmodus en renderinstellingen

De sessie draait op een fysieke SM A525F in debugmodus, via wireless ADB, met widgettracking en debugger. Debugcijfers zijn geen betrouwbare release-prestatiemeting. Wireless ADB betekent ook niet dat elke kaarttegel via de pc wordt geladen.

De AndroidManifest schakelt Impeller expliciet uit (`:31–32`). De log waarschuwt dat deze opt-out wordt uitgefaseerd. Dit is een relevante configuratie voor een gecontroleerde vergelijking, geen bewijs dat Impeller aanzetten alles oplost.

`pubspec.lock` bevat `google_maps_flutter_android 2.21.0`. De lokaal geïnstalleerde documentatie vermeldt Texture Layer Hybrid Composition als standaard en beveelt die aan boven de oudere Hybrid Composition. Er is geen expliciete `useAndroidViewSurface`-override in `lib`. De logregel “legacy platform view rendering strategy” is dus onvoldoende om te concluderen dat de app de minder efficiënte pluginmodus forceert. Ook zijn Flutter-compositionstrategie, Google Maps-renderer en Flutter-renderer drie verschillende zaken.

## Meldingen die de kaartvertraging niet verklaren

- De fatale `READ_PHONE_STATE`-fout is van `com.google.android.talk`, PID 14211. Thuisradar gebruikt PID 18813. Dit is geen aangetoonde Thuisradar-crash en geen reden om die telefoonpermissie toe te voegen.
- Verouderde dependencymeldingen en Gradle/Kotlinwaarschuwingen bewijzen geen vertraging tijdens kaartinteractie.
- Java-GC-regels noemen de totale duur van concurrente opruiming; die totale duur is geen gelijkwaardige stop van de UI. De gemelde stopmomenten zijn veel korter.

## Aanpak voor een aantoonbare verbetering

1. Meet op dezelfde Samsung in profilemodus, bijvoorbeeld `C:/Programming/flutter/bin/flutter.bat run --profile --dart-define-from-file=env.json -d <actueel-device-id>`. Vergelijk eerste opening en heropening, op dezelfde verbinding. Meet afzonderlijk kaartcontroller gereed, eerste camerastilte, eerste zichtbare kaarttegels en eerste markers.
2. Voeg meetpunten toe rond camera-events/`moveCamera`, elke bitmaprender, native markerupdates en geofence-engine-starts. Gebruik volledige framegegevens en DevTools/native profiling; de bestaande vijfsecondenlog is te grof.
3. Vergelijk in een diagnostische build dezelfde kaart met geofence-start tijdelijk uitgesteld. Behoud locatiebewaking in de uiteindelijke oplossing. Inspecteer opgeslagen initial triggers en oude zones voordat het herregistratiegedrag wordt gewijzigd.
4. Vergelijk gewone markers met wandelanimaties uitgeschakeld. Als PNG-werk domineert: beperk werk per frame en publiceer gereedgemaakte markers stapsgewijs; behoud de bestaande cache.
5. Vergelijk camerarespons met Google als directe eigenaar van de gebaren. Dit is een grotere architectuurwijziging met gevolgen voor selectie, clustering en ballonplaatsing; eerst meten, dan beslissen.
6. Vergelijk Impeller aan/uit en controleer native tegel/netwerkvertraging. Verander niet tegelijk alle instellingen, zodat duidelijk blijft welke wijziging helpt.

## Verificatie

Zes bestaande tests voor Google-kaartopbouw, bitmapgeneratie en camera/focusgedrag zijn geslaagd:

- `test/features/map/family_map_google_test.dart`
- `test/features/map/widget_bitmap_test.dart`
- `test/features/map/family_map_camera_test.dart`

Deze tests controleren functionaliteit; ze reproduceren geen native Android-framehaperingen.

`flutter analyze --no-pub` is gestart maar leverde tijdens dit onderzoek geen eindresultaat op. Een geslaagde volledige statische analyse kan daarom niet worden bevestigd.

## Officiële documentatie

- [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance): meten op een fysiek toestel in profilemodus.
- [Flutter rendering performance](https://docs.flutter.dev/perf/rendering-performance): debugmodus is niet representatief voor release-prestaties.
- [Google Maps Android-plugin: display mode](https://pub.dev/packages/google_maps_flutter_android#display-mode): aanbevolen standaardweergave en onderscheid met Hybrid Composition.
- [Android platform views](https://docs.flutter.dev/platform-integration/android/platform-views): native compositing en prestatieafwegingen.
