/// Adres van een locatie, uit reverse geocoding: straat en gemeente.
///
/// Puur model, los van de `geocoding`-bibliotheek, zodat de weergave testbaar
/// blijft zonder platformkanalen.
class PlaceAddress {
  const PlaceAddress({this.street, this.municipality});

  /// Straatnaam (+ huisnummer), indien bekend.
  final String? street;

  /// Gemeente/stad, indien bekend.
  final String? municipality;

  bool get isEmpty => label.isEmpty;

  /// "Kerkstraat 42, Gent" — enkel de delen die bekend zijn.
  String get label => [street, municipality]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(', ');

  @override
  bool operator ==(Object other) =>
      other is PlaceAddress &&
      other.street == street &&
      other.municipality == municipality;

  @override
  int get hashCode => Object.hash(street, municipality);

  @override
  String toString() => 'PlaceAddress($label)';
}

/// Raster waarop we coördinaten afronden voor het cacheen van adressen.
/// 1/2000 graad is ongeveer 55 meter: precies genoeg voor straat + gemeente,
/// maar niet voor elke meter een nieuwe reverse-geocoding-aanvraag.
const addressGrid = 2000.0;

/// Rondt een coördinaat af op het adresraster, zodat opeenvolgende
/// locatie-updates binnen dezelfde buurt dezelfde cachesleutel delen.
(double latitude, double longitude) snapToAddressGrid(double latitude, double longitude) => (
  (latitude * addressGrid).roundToDouble() / addressGrid,
  (longitude * addressGrid).roundToDouble() / addressGrid,
);
