/// Eén punt uit de locatiegeschiedenis (tabel `location_history`).
class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.battery,
    this.speedMps,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    battery: json['battery'] as int?,
    speedMps: (json['speed_mps'] as num?)?.toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String).toLocal(),
  );

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final int? battery;
  final double? speedMps;
}
