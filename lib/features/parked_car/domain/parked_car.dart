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

/// Waar het kaartje om de auto te plaatsen begint: de bestaande parkeerplek,
/// anders een verse GPS-meting, anders de laatst gedeelde locatie. Null als
/// er niets bekend is (dan begint de kaart op een standaardplek).
({double latitude, double longitude})? parkedCarStartPoint({
  ParkedCar? existing,
  ({double latitude, double longitude})? fresh,
  ({double latitude, double longitude})? lastShared,
}) {
  if (existing != null) return (latitude: existing.latitude, longitude: existing.longitude);
  return fresh ?? lastShared;
}
