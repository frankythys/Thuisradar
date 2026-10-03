/// Hoelang de noodknop ingedrukt moet blijven voor een SOS afgaat.
const kSosHoldDuration = Duration(seconds: 3);

/// Een noodoproep (tabel `sos_alerts`).
class SosAlert {
  const SosAlert({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.active,
    required this.createdAt,
    this.resolvedAt,
  });

  factory SosAlert.fromJson(Map<String, dynamic> json) => SosAlert(
    id: json['id'] as String,
    familyId: json['family_id'] as String,
    userId: json['user_id'] as String,
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lng'] as num).toDouble(),
    active: json['status'] == 'active',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    resolvedAt: json['resolved_at'] == null ? null : DateTime.parse(json['resolved_at'] as String).toLocal(),
  );

  final String id;
  final String familyId;
  final String userId;
  final double latitude;
  final double longitude;
  final bool active;
  final DateTime createdAt;
  final DateTime? resolvedAt;
}

/// Kiest welk SOS-alarm als overlay getoond wordt: het eerste actieve alarm van
/// een ánder gezinslid dat nog niet is weggetikt. Eigen alarmen tonen we als
/// banner, niet als overlay. [active] is nieuwste eerst.
SosAlert? sosToShow(List<SosAlert> active, {required String? myUserId, required Set<String> dismissed}) {
  for (final alert in active) {
    if (alert.userId != myUserId && !dismissed.contains(alert.id)) return alert;
  }
  return null;
}
