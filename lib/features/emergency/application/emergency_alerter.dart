import '../../../l10n/l10n.dart';
import '../data/emergency_phone.dart';
import '../domain/emergency_contact.dart';

/// Wat er met de noodcontacten gebeurde, voor de melding na een SOS.
class EmergencyOutcome {
  const EmergencyOutcome({this.manual});

  static const none = EmergencyOutcome();

  /// Voor wie de berichten-app openging, met de sms klaar.
  final EmergencyContact? manual;

  /// Korte uitleg voor de melding, of null zonder noodcontacten.
  String? summary(AppLocalizations l10n) => manual == null ? null : l10n.emergencyTapToSend(manual!.name);
}

/// De sms die de noodcontacten krijgen, met een kaartlink naar de locatie, in
/// de taal van wie de SOS stuurt.
String sosSmsText(
  AppLocalizations l10n, {
  required String senderName,
  required double latitude,
  required double longitude,
}) {
  final name = senderName.trim().isEmpty ? l10n.emergencySomeone : senderName.trim();
  return l10n.emergencySosSms(name, sosMapLink(latitude, longitude));
}

/// Verwittigt de noodcontacten bij een SOS: de berichten-app opent met de
/// sms en de kaartlink klaar voor contact 1 (zonder contact 1 het andere).
/// Versturen doet de gebruiker zelf; het gezin krijgt de SOS via de push.
class EmergencyAlerter {
  EmergencyAlerter(this._phone);

  final EmergencyPhone _phone;

  Future<EmergencyOutcome> alert({
    required AppLocalizations l10n,
    required List<EmergencyContact> contacts,
    required String senderName,
    required double latitude,
    required double longitude,
  }) async {
    final first = planFor(contacts).callTo;
    if (first == null) return EmergencyOutcome.none;
    final text = sosSmsText(l10n, senderName: senderName, latitude: latitude, longitude: longitude);
    await _phone.openSms(dialablePhone(first.phone), text);
    return EmergencyOutcome(manual: first);
  }
}
