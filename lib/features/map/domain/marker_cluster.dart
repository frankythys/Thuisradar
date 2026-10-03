import 'dart:ui';

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
