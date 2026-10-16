import '../../../l10n/l10n.dart';
import '../data/emergency_phone.dart';
import '../domain/emergency_contact.dart';

/// Wat er met de noodcontacten gebeurde, voor de melding na een SOS. Enkel
/// wat echt vertrok, telt als verstuurd.
class EmergencyOutcome {
  const EmergencyOutcome({
    this.texted = const [],
    this.failed = const [],
    this.noNetwork = false,
    this.called,
    this.manual,
  });

  static const none = EmergencyOutcome();

  /// Wie de sms echt kreeg (het netwerk nam hem aan).
  final List<EmergencyContact> texted;

  /// Bij wie de sms niet vertrok.
  final List<EmergencyContact> failed;

  /// Geen simkaart of gsm-netwerk: dan lukt ook bellen niet.
  final bool noNetwork;

  /// Wie automatisch gebeld wordt.
  final EmergencyContact? called;

  /// Zonder toestemming (of op iPhone): voor wie de berichten-app openging.
  final EmergencyContact? manual;

  /// Korte uitleg voor de melding, of null zonder noodcontacten.
  String? summary(AppLocalizations l10n) {
    String names(List<EmergencyContact> contacts) => l10n.joinNames(contacts.map((contact) => contact.name));
    if (manual != null) return l10n.emergencyTapToSend(manual!.name);
    final parts = [
      if (texted.isNotEmpty) l10n.emergencySmsTo(names(texted)),
      if (failed.isNotEmpty)
        noNetwork ? l10n.emergencySmsNoNetwork(names(failed)) : l10n.emergencySmsFailed(names(failed)),
      if (called != null) l10n.emergencyCallingNow(called!.name),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
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

/// Verwittigt de noodcontacten bij een SOS: eerst een sms naar allemaal, dan
/// contact 1 bellen. Kan de gsm dat niet automatisch (geen toestemming of
/// iPhone), dan opent de berichten-app met de sms klaar voor contact 1.
/// Zonder simkaart of netwerk wordt er niet gebeld: dat lukt toch niet.
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
    final plan = planFor(contacts);
    if (plan.isEmpty) return EmergencyOutcome.none;
    final text = sosSmsText(l10n, senderName: senderName, latitude: latitude, longitude: longitude);
    final results = <EmergencyContact, SmsResult>{
      for (final contact in plan.smsTo) contact: await _phone.sendSms(dialablePhone(contact.phone), text),
    };
    final first = plan.callTo!;
    if (results.values.every((result) => result == SmsResult.notAllowed)) {
      // Niets automatisch: de sms klaarzetten is beter dan niets.
      await _phone.openSms(dialablePhone(first.phone), text);
      return EmergencyOutcome(manual: first);
    }
    final texted = [
      for (final MapEntry(:key, :value) in results.entries)
        if (value == SmsResult.sent) key,
    ];
    final failed = [
      for (final MapEntry(:key, :value) in results.entries)
        if (value != SmsResult.sent) key,
    ];
    final noNetwork = results.values.contains(SmsResult.noService);
    // Pas bellen na de sms'en: de oproep neemt het scherm over.
    final called = !noNetwork && await _phone.call(dialablePhone(first.phone));
    return EmergencyOutcome(
      texted: texted,
      failed: failed,
      noNetwork: noNetwork,
      called: called ? first : null,
    );
  }
}
