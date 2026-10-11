class Family {
  const Family({required this.id, required this.name, required this.inviteCode, this.inviteExpiresAt});

  factory Family.fromJson(Map<String, dynamic> json) => Family(
    id: json['id'] as String,
    name: json['name'] as String,
    inviteCode: json['invite_code'] as String,
    inviteExpiresAt: switch (json['invite_expires_at']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
  );

  final String id;
  final String name;
  final String inviteCode;

  /// Tot wanneer de uitnodigingscode werkt; null = onbekend (migratie 017 nog
  /// niet uitgevoerd) of geen vervaldatum.
  final DateTime? inviteExpiresAt;

  bool inviteExpiredAt(DateTime now) => inviteExpiresAt != null && !inviteExpiresAt!.isAfter(now);
}
