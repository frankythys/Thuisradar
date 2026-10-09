import 'dart:ui';

import '../../../core/utils/geo.dart';

/// Eén te clusteren punt: een gezinslid-id met zijn positie op het scherm (px).
class ClusterPoint {
  const ClusterPoint(this.id, this.position);

  final String id;
  final Offset position;
}

/// Groepeert punten die op het scherm dichter dan [thresholdPx] bij het anker
/// van een bestaande groep liggen. Behoudt de invoervolgorde: het eerste punt
/// van een groep is het anker (representatief). Puur en deterministisch, zodat
/// het bij elke zoom opnieuw berekend kan worden.
List<List<String>> clusterByScreenDistance(List<ClusterPoint> points, {double thresholdPx = 40}) {
  final anchors = <Offset>[];
  final groups = <List<String>>[];

  for (final point in points) {
    var placed = false;
    for (var i = 0; i < anchors.length; i++) {
      if ((anchors[i] - point.position).distance <= thresholdPx) {
        groups[i].add(point.id);
        placed = true;
        break;
      }
    }
    if (!placed) {
      anchors.add(point.position);
      groups.add([point.id]);
    }
  }

  return groups;
}

/// Eén te groeperen lid met zijn echte positie (graden).
class GeoClusterPoint {
  const GeoClusterPoint(this.id, this.latitude, this.longitude);

  final String id;
  final double latitude;
  final double longitude;
}

/// Leden staan pas samen in één groepspin als ze echt op dezelfde plek zijn:
/// binnen [thresholdMeters] van het anker van een groep, op elke zoom. Twee
/// mensen op aparte locaties blijven zo altijd apart, ook als je uitzoomt.
/// Behoudt de invoervolgorde; het eerste punt van een groep is het anker.
List<List<String>> clusterByMeters(List<GeoClusterPoint> points, {double thresholdMeters = 60}) {
  final anchors = <GeoClusterPoint>[];
  final groups = <List<String>>[];

  for (final point in points) {
    var placed = false;
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      if (distanceMeters(anchor.latitude, anchor.longitude, point.latitude, point.longitude) <=
          thresholdMeters) {
        groups[i].add(point.id);
        placed = true;
        break;
      }
    }
    if (!placed) {
      anchors.add(point);
      groups.add([point.id]);
    }
  }

  return groups;
}
