/// Huidige aanwezigheid van één lid in één plaats (tabel `place_presence`).
class PlacePresence {
  const PlacePresence({required this.userId, required this.placeId, required this.isInside, this.since});

  factory PlacePresence.fromJson(Map<String, dynamic> json) => PlacePresence(
    userId: json['user_id'] as String,
    placeId: json['place_id'] as String,
    isInside: json['is_inside'] as bool? ?? false,
    since: json['since'] == null ? null : DateTime.parse(json['since'] as String).toLocal(),
  );

  final String userId;
  final String placeId;
  final bool isInside;
  final DateTime? since;
}
