# third_party

Gepatchte kopieën van externe pakketten. Ze worden via `dependency_overrides` in
`pubspec.yaml` gebruikt in plaats van de versie van pub.dev.

## google_maps_flutter_android 2.21.0

Bron: <https://pub.dev/packages/google_maps_flutter_android/versions/2.21.0>
(BSD-licentie, zie `google_maps_flutter_android/LICENSE`). Weggelaten: `example/`,
`test/`, `pigeons/` en `android/src/test/`.

### Waarom

Elke markerwijziging, ook enkel een nieuwe positie, stuurt de volledige afbeelding
mee. De originele plugin decodeerde die PNG telkens opnieuw, twee keer per update
(builder en marker), op de Android-hoofdthread. Een bewegend lid schuift tot 30
keer per seconde, en de wandel-GIF wisselt van beeld op het tempo van de GIF. Dat
werk deed de kaart haperen.

### De patch (alles gemarkeerd met `Thuisradar-patch`)

- `android/.../BytesCache.java` (nieuw): een LRU-cache van PNG-bytes naar een
  kant-en-klare `BitmapDescriptor`. Begrensd op 96 afbeeldingen en 24 MB.
- `android/.../Convert.java`: `getBitmapFromBytes` kijkt eerst in de cache.
- `android/.../MarkerController.java`: `setIcon` slaat hetzelfde icoon over.

De Dart-kant is ongewijzigd.

### Bijwerken naar een nieuwe versie

1. Download de nieuwe versie van pub.dev en vervang deze map. Laat dezelfde mappen
   weg als hierboven.
2. Pas de drie wijzigingen hierboven opnieuw toe.
3. Pas het versienummer in deze README aan en draai `flutter pub get`.
4. Test op de A52 of markers vloeiend schuiven.

Lost Flutter het probleem upstream op (een cache in de plugin zelf), verwijder dan
deze map en de `dependency_overrides`.
