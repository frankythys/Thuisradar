/// Eén noodcontact (tabel `emergency_contacts`, migratie 021): iemand buiten
/// de app die bij een SOS een sms krijgt; contact 1 wordt daarna ook gebeld.
/// Puur model, los van Flutter en Supabase.
class EmergencyContact {
  const EmergencyContact({required this.position, required this.name, required this.phone});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    position: (json['position'] as num).toInt(),
    name: json['name'] as String,
    phone: json['phone'] as String,
  );

  /// 1 of 2. Contact 1 wordt na de sms ook gebeld.
  final int position;
  final String name;
  final String phone;

  Map<String, dynamic> toJson(String userId) => {
    'user_id': userId,
    'position': position,
    'name': name,
    'phone': phone,
  };

  @override
  bool operator ==(Object other) =>
      other is EmergencyContact && other.position == position && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(position, name, phone);
}

/// Hoe het versturen van één sms afliep.
enum SmsResult {
  /// Het netwerk nam de sms aan.
  sent,

  /// Niet automatisch: geen toestemming, of een iPhone.
  notAllowed,

  /// Geen simkaart of geen gsm-netwerk.
  noService,

  /// Iets anders liep mis.
  failed,
}

/// Hoeveel noodcontacten je kan instellen.
const kMaxEmergencyContacts = 2;

/// Zelfde regel als het telefoonnummer in het profiel (en de check in de
/// database): cijfers, spaties, haakjes en streepjes, eventueel met een +.
final _phonePattern = RegExp(r'^\+?[0-9 ()-]{6,24}$');

bool isValidPhone(String phone) => _phonePattern.hasMatch(phone.trim());

/// Het nummer zoals de telefoon het belt of sms't: enkel cijfers en een
/// eventuele + vooraan. "0470 12 34 56" wordt "0470123456".
String dialablePhone(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// Wat er bij een SOS met de noodcontacten gebeurt: wie een sms krijgt en
/// wie er daarna gebeld wordt.
class EmergencyPlan {
  const EmergencyPlan({required this.smsTo, required this.callTo});

  static const none = EmergencyPlan(smsTo: [], callTo: null);

  /// Iedereen met een geldig nummer, contact 1 eerst, zonder dubbels.
  final List<EmergencyContact> smsTo;

  /// Contact 1; zonder contact 1 het andere contact. null = niemand.
  final EmergencyContact? callTo;

  bool get isEmpty => smsTo.isEmpty;
}

EmergencyPlan planFor(List<EmergencyContact> contacts) {
  final valid = [
    for (final contact in contacts)
      if (contact.name.trim().isNotEmpty && isValidPhone(contact.phone)) contact,
  ]..sort((a, b) => a.position.compareTo(b.position));
  final seen = <String>{};
  final unique = [
    for (final contact in valid)
      if (seen.add(dialablePhone(contact.phone))) contact,
  ];
  return EmergencyPlan(smsTo: unique, callTo: unique.firstOrNull);
}

/// De sms die de noodcontacten krijgen, met een kaartlink naar de locatie.
/// Een gewone link (geen API): opent op elke telefoon in de kaarten-app.
String sosSmsText({required String senderName, required double latitude, required double longitude}) {
  final name = senderName.trim().isEmpty ? 'Iemand van je gezin' : senderName.trim();
  final lat = latitude.toStringAsFixed(5);
  final lng = longitude.toStringAsFixed(5);
  return 'SOS van $name: ik heb hulp nodig. Mijn locatie: '
      'https://maps.google.com/?q=$lat,$lng '
      '(automatisch bericht, ik kan misschien niet antwoorden)';
}

/// Waarom een noodcontact (nog) niet bewaard kan worden.
enum EmergencyContactProblem { missingName, missingPhone, invalidPhone }

/// Het probleem met een ingevuld noodcontact, of null als het goed is (of
/// helemaal leeg). De tekst erbij komt uit de vertalingen.
EmergencyContactProblem? emergencyContactError(String name, String phone) {
  final hasName = name.trim().isNotEmpty;
  final hasPhone = phone.trim().isNotEmpty;
  if (!hasName && !hasPhone) return null;
  if (!hasName) return EmergencyContactProblem.missingName;
  if (!hasPhone) return EmergencyContactProblem.missingPhone;
  if (!isValidPhone(phone)) return EmergencyContactProblem.invalidPhone;
  return null;
}
