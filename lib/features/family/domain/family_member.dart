class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.isOwner,
    required this.colorIndex,
  });

  /// Verwacht een rij uit `family_members` met een geneste `profiles`-relatie.
  factory FamilyMember.fromJson(Map<String, dynamic> json, {required int colorIndex}) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return FamilyMember(
      userId: json['user_id'] as String,
      displayName: (profile?['display_name'] as String?) ?? 'Gezinslid',
      isOwner: json['role'] == 'owner',
      colorIndex: colorIndex,
    );
  }

  final String userId;
  final String displayName;
  final bool isOwner;

  /// Positie in de familie (volgorde van toetreden); bepaalt de vaste kleur.
  final int colorIndex;

  String get initial =>
      displayName.isEmpty ? '?' : String.fromCharCode(displayName.runes.first).toUpperCase();
}
