/// Een veilige zone (geofence) van de familie (tabel `places`).
class Place {
  const Place({
    required this.id,
    required this.familyId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.icon,
    this.watchedMembers,
    this.address,
    this.notifyArrival = true,
    this.notifyDeparture = true,
  });

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    familyId: json['family_id'] as String,
    name: json['name'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    radiusMeters: json['radius_m'] as int,
    icon: json['icon'] as String? ?? 'home',
    watchedMembers: (json['watched_members'] as List<dynamic>?)?.cast<String>(),
    address: json['address'] as String?,
    notifyArrival: json['notify_arrival'] as bool? ?? true,
    notifyDeparture: json['notify_departure'] as bool? ?? true,
  );

  final String id;
  final String familyId;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String icon;
  final String? address;
  final bool notifyArrival;
  final bool notifyDeparture;

  /// Over wie je meldingen wilt; null/leeg = iedereen.
  final List<String>? watchedMembers;
}
