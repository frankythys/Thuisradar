import 'geofence_zone.dart';

enum GeofenceReportType { arrival, departure }

/// Eén aankomst of vertrek, zoals het toestel het doorgeeft aan de server.
class GeofenceReport {
  const GeofenceReport({
    required this.placeId,
    required this.type,
    required this.at,
    this.latitude,
    this.longitude,
  });

  factory GeofenceReport.fromJson(Map<String, dynamic> json) => GeofenceReport(
    placeId: json['place_id'] as String,
    type: GeofenceReportType.values.byName(json['type'] as String),
    at: DateTime.parse(json['at'] as String),
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lng'] as num?)?.toDouble(),
  );

  final String placeId;
  final GeofenceReportType type;
  final DateTime at;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
    'place_id': placeId,
    'type': type.name,
    'at': at.toUtc().toIso8601String(),
    'lat': latitude,
    'lng': longitude,
  };
}

/// Maakt per getriggerde zone één melding. Zones die niet van ons zijn, worden
/// overgeslagen.
List<GeofenceReport> reportsForZones({
  required Iterable<String> zoneIds,
  required GeofenceReportType type,
  required DateTime at,
  double? latitude,
  double? longitude,
}) => [
  for (final id in zoneIds)
    if (GeofenceZone.placeIdOf(id) case final placeId?)
      GeofenceReport(placeId: placeId, type: type, at: at, latitude: latitude, longitude: longitude),
];

/// Wachtrij voor meldingen die (nog) niet verstuurd raakten, bv. zonder netwerk.
/// Te oude meldingen weigert de server toch ('stale'), dus die vallen weg. De
/// volgorde blijft chronologisch: de server beslist per melding of ze nog klopt.
List<GeofenceReport> pruneReportQueue(
  List<GeofenceReport> queue, {
  required DateTime now,
  Duration maxAge = const Duration(minutes: 30),
  int maxLength = 20,
}) {
  final fresh = queue.where((r) => now.difference(r.at) < maxAge).toList()
    ..sort((a, b) => a.at.compareTo(b.at));
  return fresh.length <= maxLength ? fresh : fresh.sublist(fresh.length - maxLength);
}
