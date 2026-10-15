import '../data/emergency_phone.dart';
import '../domain/emergency_contact.dart';

/// Wat er met de noodcontacten gebeurde, voor de melding na een SOS.
class EmergencyOutcome {
  const EmergencyOutcome({this.texted = const [], this.called, this.manual});

  static const none = EmergencyOutcome();

  /// Wie automatisch een sms kreeg.
  final List<EmergencyContact> texted;

  /// Wie automatisch gebeld wordt.
  final EmergencyContact? called;

  /// Zonder toestemming (of op iPhone): voor wie de berichten-app openging.
  final EmergencyContact? manual;

  /// Korte uitleg voor de melding, of null zonder noodcontacten.
  String? get summary {
    final names = texted.map((contact) => contact.name).join(' en ');
    if (texted.isNotEmpty && called != null) return 'Sms naar $names, nu bellen naar ${called!.name}.';
    if (texted.isNotEmpty) return 'Sms naar $names.';
    if (called != null) return 'Nu bellen naar ${called!.name}.';
    if (manual != null) return 'Tik op versturen om ${manual!.name} te sms\'en.';
    return null;
  }
}

/// Verwittigt de noodcontacten bij een SOS: eerst een sms naar allemaal, dan
/// contact 1 bellen. Kan de gsm dat niet automatisch (geen toestemming of
/// iPhone), dan opent de berichten-app met de sms klaar voor contact 1.
class EmergencyAlerter {
  EmergencyAlerter(this._phone);

  final EmergencyPhone _phone;

  Future<EmergencyOutcome> alert({
    required List<EmergencyContact> contacts,
    required String senderName,
    required double latitude,
    required double longitude,
  }) async {
    final plan = planFor(contacts);
    if (plan.isEmpty) return EmergencyOutcome.none;
    final text = sosSmsText(senderName: senderName, latitude: latitude, longitude: longitude);
    final texted = <EmergencyContact>[];
    for (final contact in plan.smsTo) {
      if (await _phone.sendSms(dialablePhone(contact.phone), text)) texted.add(contact);
    }
    final first = plan.callTo!;
    if (texted.isEmpty) {
      // Niets automatisch: de sms klaarzetten is beter dan niets.
      await _phone.openSms(dialablePhone(first.phone), text);
      return EmergencyOutcome(manual: first);
    }
    // Pas bellen na de sms'en: de oproep neemt het scherm over.
    final called = await _phone.call(dialablePhone(first.phone));
    return EmergencyOutcome(texted: texted, called: called ? first : null);
  }
}
