/// Wat de kaart toont: midden en zoom. Puur model (geen Flutter of kaartpakket),
/// zodat de startlogica testbaar blijft.
class MapView {
  const MapView({required this.latitude, required this.longitude, required this.zoom});

  final double latitude;
  final double longitude;
  final double zoom;

  /// Compact bewaren: "51.05430,3.71740,14.5".
  String encode() =>
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)},${zoom.toStringAsFixed(2)}';

  /// Leest [encode] terug; null bij onzin (oude of beschadigde waarde).
  static MapView? decode(String? raw) {
    final parts = raw?.split(',');
    if (parts == null || parts.length != 3) return null;
    final values = parts.map(double.tryParse).toList();
    if (values.any((value) => value == null || !value.isFinite)) return null;
    final view = MapView(latitude: values[0]!, longitude: values[1]!, zoom: values[2]!);
    final valid =
        view.latitude.abs() <= 85 && view.longitude.abs() <= 180 && view.zoom >= 3 && view.zoom <= 21;
    return valid ? view : null;
  }

  @override
  bool operator ==(Object other) =>
      other is MapView && other.latitude == latitude && other.longitude == longitude && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(latitude, longitude, zoom);
}

/// Waar de kaart opent. Liefst waar ze de vorige keer stond ([saved]): dan
/// laadt Google meteen de juiste tegels (vaak nog uit zijn cache) in plaats
/// van eerst heel België en daarna nog eens de buurt. Anders de eigen locatie,
/// anders België.
MapView startView({MapView? saved, ({double latitude, double longitude})? own}) {
  if (saved != null) return saved;
  if (own != null) return MapView(latitude: own.latitude, longitude: own.longitude, zoom: 12);
  return fallbackView;
}

/// België, ver uitgezoomd: als er nog niets bekend is.
const fallbackView = MapView(latitude: 50.85, longitude: 4.35, zoom: 8);
