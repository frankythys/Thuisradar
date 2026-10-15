import 'package:flutter/widgets.dart';

/// Foto's per plaatssoort (sleutel = `places.icon`), klein en uitgeknipt in
/// `assets/places/`. Thuis houdt zijn eigen huisje, "Andere" het speldje.
const _withPhoto = {'school', 'work', 'sports', 'store', 'daycare', 'park', 'refinery'};

/// Heeft deze plaatssoort een foto?
bool hasPlacePhoto(String key) => _withPhoto.contains(key);

/// Schuin aanzicht, voor de plaats op de kaart; null = geen foto.
String? placeMapAsset(String key) => hasPlacePhoto(key) ? 'assets/places/${key}_kaart.webp' : null;

/// Vooraanzicht, voor de statusballon; null = geen foto.
ImageProvider? placeBubbleImage(String key) =>
    hasPlacePhoto(key) ? AssetImage('assets/places/${key}_ballon.webp') : null;

/// Alle ballonfoto's, om vooraf te laden (Google tekent de ballon als
/// afbeelding en wacht niet op een foto die nog laadt).
List<ImageProvider> get placeBubbleImages => [for (final key in _withPhoto) placeBubbleImage(key)!];

/// Breedte van een plaats op de kaart (logische pixels); de hoogte volgt de
/// foto.
const kPlaceMapImageWidth = 46.0;
