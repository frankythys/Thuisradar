# GPS-fence en ritten: controle op 11 oktober 2026

Productieproject Thuisradar is via het ingelogde Supabase-dashboard alleen-lezen gecontroleerd met SELECT-query's. Er zijn geen databasefuncties aangeroepen die aanwezigheid of meldingen wijzigen en geen migraties uitgevoerd. Tijden hieronder zijn Europe/Berlin (UTC+2).

## Bewezen codefouten

1. `GeofenceReporter.report()` leest de hele wachtrij en overschrijft die na netwerkverwerking. Twee gelijktijdige reporters kunnen een nieuwe, nog niet verstuurde melding wissen. De reproductie laat een oude flush afronden nadat een tweede reporter een netwerkfout heeft opgeslagen; de wachtrij wordt leeg. De app start een flush terwijl Android-callbacks dezelfde opslag gebruiken. Historisch verlies is niet bewezen: Supabase bevat geen log van lokaal verdwenen meldingen.
2. `buildDayActivities()` verwijdert ritten waarvan de bestemming binnen 100 meter van het vertrek ligt, ongeacht de afgelegde route. Een gecontroleerde rondrit van ruim 4,4 km verdwijnt. Een getroffen historische rondrit is niet vastgesteld.
3. `buildDayActivities()` berekent afstand met ongefilterde punten; `activityTrack()` filtert pas daarna GPS-sprongen. De synthetische reproductie geeft meer dan 200 km versus minder dan 2,3 km kaartspoor.

## Aanvullend bewijs uit Supabase

- Historiek: Franky 10.849 punten, Liam 4.715 punten, vanaf 3 oktober. Beide hebben vijf dubbele tijdstippen. Meetgaten boven vijf minuten: Franky 102, Liam 15. Deze tellingen bewijzen geen oorzaak van meetverlies.
- Liam heeft vijf opeenvolgende locatieveranderingen met meer dan 100 meter afstand, binnen vijf minuten, boven de kaartfiltergrens van 45 m/s. De grootste is 8.868.398 meter in 128,08 seconden op 7 oktober 20:05:17.880. De opgeslagen nauwkeurigheid bij dat punt is 5 meter. De herkomst (toestel, emulator, test of andere invoer) is niet uit deze records vastgesteld.
- Een reproductie met de echte begin- en eindpunten van drie reeksen identieke coördinaten tussen 20:00 en 20:15 die dag geeft in de huidige code ongeveer 8.873 km als dagrit. Het gefilterde kaartspoor bevat één punt. Dit is bewijs dat huidige code deze opgeslagen locaties fout verwerkt; het bewijst niet welk scherm een oudere appversie toen toonde.
- Franky, Thuis, 10 oktober: toestelvertrek om 10:12:38.939 en toestelaankomst om 10:12:44.765. Hun opgegeven posities liggen respectievelijk 147 en 132 meter van het huidige plaatscentrum. De dichtstbijzijnde geschiedenispositie om 10:12:48.429 ligt op 6 meter, met nauwkeurigheid 12,691 meter. Dit toont tegenstrijdige bronnen. De vertrekbevestiging uit migratie 015 noemt dit bestaande incident als aanleiding; het is geen bewijs dat die latere wijziging faalt.

## Actieve Supabase-configuratie

`evaluate_geofences`, `record_geofence_event` en `confirm_pending_departures` zijn via `pg_get_functiondef` gelezen. De actieve aankomst/vertrekfunctie bevat de pending-departure-logica van migratie 015. Cron-job `confirm-pending-departures` staat actief en draait elke minuut. Alle 70 bewaarde uitvoeringen hebben status `succeeded`; laatste gecontroleerde uitvoering 11 oktober 10:05. Geen aanwezigheid met een wachtend vertrek op het controlemoment.

## Verificatie

126 bestaande tests voor geofencing, driving en location slagen. `test/audit_reproduction_test.dart` bevat drie tests die het foutieve gedrag aantonen. `test/supabase_audit_reproduction_test.dart` reproduceert de afstandsfout met productiepunten. Deze tests verwachten het waargenomen defect en zijn dus bewijsreproducties, geen tests die correct gedrag garanderen.

Op het moment van de audit was productiecode niet gewijzigd. Geen test op een fysiek toestel uitgevoerd. Geen verloren lokale meldingen of historische verdwenen rondritten bewezen.

## Uitgevoerde correctie

Na opdracht van de gebruiker is de appcode aangepast. Dagritten, het routespoor en het weekrapport filteren onmogelijke sprongen voordat afstand wordt berekend. Dubbele tijdstippen en ongeldige coördinaten worden overgeslagen; meetgaten blijven losse ritstukken. Rondritten verdwijnen niet langer door hun eindpunt. De tijdlijn voegt verblijven op dezelfde plek alleen samen wanneer ertussen hoogstens één punt buiten de stopstraal ligt, zodat een echte rondrit tussen verblijven behouden blijft. Een losse uitschieter binnen een samengevoegd verblijf vormt geen rit.

Geofence-meldingen worden vóór verzending afzonderlijk opgeslagen, per toestelsleutel. Bevestigen verwijdert alleen die melding; een retry schrijft geen verouderde lijst terug. De bestaande offline wachtrij wordt bij de eerste lezing overgenomen. Een late callback met een oude toestelsleutel komt niet in de wachtrij van een nieuwe sleutel terecht.

De eerdere reproducties zijn omgezet naar regressietests die correct gedrag verwachten. Er zijn opslagtests voor twee store-instanties, migratie en een late callback, plus een rondrit tussen twee verblijven. De volledige Flutter-testsuite slaagt: 388 tests. `dart analyze lib test` meldt geen problemen. Supabase is niet gewijzigd; er is geen databasemigratie nodig. De wijziging is nog niet op een fysiek toestel getest of geïnstalleerd.
