/// Laatste bekende locatie van één gezinslid (tabel `member_locations`).
class MemberLocation {
  const MemberLocation({
    required this.userId,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.accuracyMeters,
    this.speedMps,
    this.battery,
    this.isCharging,
  });

  factory MemberLocation.fromJson(Map<String, dynamic> json) => MemberLocation(
    userId: json['user_id'] as String,
    familyId: json['family_id'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    accuracyMeters: (json['accuracy_m'] as num?)?.toDouble(),
    speedMps: (json['speed_mps'] as num?)?.toDouble(),
    battery: json['battery'] as int?,
    isCharging: json['is_charging'] as bool?,
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
  );

  final String userId;
  final String familyId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMps;
  final int? battery;
  final bool? isCharging;
  final DateTime updatedAt;

  /// Nieuwe locatie met een andere positie; overige velden blijven gelijk.
  MemberLocation copyWith({double? latitude, double? longitude}) => MemberLocation(
    userId: userId,
    familyId: familyId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracyMeters: accuracyMeters,
    speedMps: speedMps,
    battery: battery,
    isCharging: isCharging,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'family_id': familyId,
    'lat': latitude,
    'lng': longitude,
    'accuracy_m': accuracyMeters,
    'speed_mps': speedMps,
    'battery': battery,
    'is_charging': isCharging,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
