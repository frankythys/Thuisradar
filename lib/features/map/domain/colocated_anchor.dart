import '../../../core/utils/geo.dart';
import 'marker_cluster.dart';

/// Leden die samen op één plek staan (bv. allemaal thuis) maar ingezoomd geen
/// groepspin meer vormen, krijgen één gezamenlijk punt: het midden van hun
/// posities (bij het waaiertje rond Thuis = het huis zelf). De kaart schuift
/// ze daarna op het scherm vlak naast elkaar. Zo blijven ze bij elke zoom
/// dicht bij huis, in plaats van tientallen meters uit elkaar te staan.
///
/// [singles]: leden die als los rondje getoond worden (geen groepspin, niet
/// rijdend). Geeft enkel voor leden met minstens één buur binnen
/// [thresholdMeters] een nieuw punt terug.
Map<String, ({double lat, double lng})> colocatedAnchors(
  List<GeoClusterPoint> singles, {
  double thresholdMeters = 60,
}) {
  final groups = clusterByMeters(singles, thresholdMeters: thresholdMeters);
  final byId = {for (final p in singles) p.id: p};
  final result = <String, ({double lat, double lng})>{};
  for (final group in groups) {
    if (group.length < 2) continue;
    final points = [for (final id in group) byId[id]!];
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    // Zekerheid: enkel als iedereen echt dicht bij dat midden staat.
    if (points.every((p) => distanceMeters(lat, lng, p.latitude, p.longitude) <= thresholdMeters)) {
      for (final id in group) {
        result[id] = (lat: lat, lng: lng);
      }
    }
  }
  return result;
}
