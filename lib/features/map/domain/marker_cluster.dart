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

/// Eén lid met zijn echte positie én zijn plek op het scherm.
class GeoScreenClusterPoint {
  const GeoScreenClusterPoint(this.id, this.latitude, this.longitude, this.screen);

  final String id;
  final double latitude;
  final double longitude;
  final Offset screen;
}

/// Samen in één groepspin enkel als leden echt op dezelfde plek zijn
/// (binnen [thresholdMeters]) én op het scherm over elkaar zouden vallen
/// (binnen [thresholdPx]). Zo staat het gezin thuis uitgezoomd als één
/// groep, maar ingezoomd gaat elk rondje apart staan (zoals Life360). Wie
/// ergens anders is, blijft altijd apart. Het eerste punt is het anker.
///
/// [previous]: de groepen van de vorige berekening. Wie al samen stond, gaat
/// pas uit elkaar voorbij een ruimere grens ([release] keer de drempels), zodat
/// een lid rond de grens niet bij elke pixel zoom in en uit de groep springt.
List<List<String>> clusterByMetersAndScreen(
  List<GeoScreenClusterPoint> points, {
  double thresholdMeters = 60,
  double thresholdPx = 48,
  List<List<String>> previous = const [],
  double release = 1.35,
}) {
  final groupOf = <String, int>{
    for (final (index, group) in previous.indexed)
      for (final id in group) id: index,
  };
  bool together(String a, String b) => groupOf[a] != null && groupOf[a] == groupOf[b];

  final anchors = <GeoScreenClusterPoint>[];
  final groups = <List<String>>[];

  for (final point in points) {
    var placed = false;
    for (var i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      final factor = together(anchor.id, point.id) ? release : 1.0;
      if ((anchor.screen - point.screen).distance <= thresholdPx * factor &&
          distanceMeters(anchor.latitude, anchor.longitude, point.latitude, point.longitude) <=
              thresholdMeters * factor) {
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
