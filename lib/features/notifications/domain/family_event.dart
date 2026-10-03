enum FamilyEventType { sos, arrival, departure, unknown }

/// Eén gebeurtenis uit de gedeelde feed (tabel `family_events`).
class FamilyEvent {
  const FamilyEvent({
    required this.id,
    required this.familyId,
    required this.actorUserId,
    required this.type,
    required this.createdAt,
    this.placeId,
  });

  factory FamilyEvent.fromJson(Map<String, dynamic> json) => FamilyEvent(
    id: json['id'] as int,
    familyId: json['family_id'] as String,
    actorUserId: json['actor_user_id'] as String,
    type: switch (json['type']) {
      'sos' => FamilyEventType.sos,
      'arrival' => FamilyEventType.arrival,
      'departure' => FamilyEventType.departure,
      _ => FamilyEventType.unknown,
    },
    placeId: json['place_id'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final int id;
  final String familyId;
  final String actorUserId;
  final FamilyEventType type;
  final String? placeId;
  final DateTime createdAt;
}
