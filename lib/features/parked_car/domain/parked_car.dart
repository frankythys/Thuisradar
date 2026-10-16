/// De laatst opgeslagen parkeerplek van één gezinslid.
class ParkedCar {
  const ParkedCar({
    required this.userId,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.parkedAt,
  });

  factory ParkedCar.fromJson(Map<String, dynamic> json) => ParkedCar(
    userId: json['user_id'] as String,
    familyId: json['family_id'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    parkedAt: DateTime.parse(json['parked_at'] as String).toLocal(),
  );

  final String userId;
  final String familyId;
  final double latitude;
  final double longitude;
  final DateTime parkedAt;
}
