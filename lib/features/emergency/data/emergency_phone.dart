import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sms'en en bellen vanaf deze gsm, voor de noodcontacten.
///
/// De app sms't en belt nooit zelf: de berichten- of telefoon-app opent met
/// alles ingevuld, en je tikt zelf op versturen of bellen. Zo zijn de door
/// Google Play beperkte toestemmingen "sms versturen" en "bellen" niet nodig,
/// en werkt het op Android en iPhone hetzelfde.
class EmergencyPhone {
  /// Opent de berichten-app met [text] klaar voor [phone]; zelf versturen.
  Future<void> openSms(String phone, String text) =>
      _open(Uri(scheme: 'sms', path: phone, queryParameters: {'body': text}));

  /// Opent de telefoon-app met [phone] klaar; zelf op bellen tikken.
  Future<void> openDialer(String phone) => _open(Uri(scheme: 'tel', path: phone));

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri)) debugPrint('Kon $uri niet openen');
    } catch (error) {
      debugPrint('Kon $uri niet openen: $error');
    }
  }
}
