import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sms'en en bellen vanaf deze gsm, voor de noodcontacten.
///
/// De app sms't en belt nooit zelf: de berichten- of telefoon-app opent met
/// alles ingevuld, en je tikt zelf op versturen of bellen. Zo zijn de door
/// Google Play beperkte toestemmingen "sms versturen" en "bellen" niet nodig,
/// en werkt het op Android en iPhone hetzelfde.
class EmergencyPhone {
  static const _channel = MethodChannel('be.thuisradar/app');

  /// Android can tell whether a SIM is present without reading its number or
  /// requesting phone-state permission. Unknown platforms remain usable.
  Future<bool> hasSmsSim() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('hasSmsSim') ?? true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  /// Opent de berichten-app met [text] klaar voor [phone]; zelf versturen.
  Future<void> openSms(String phone, String text) async {
    if (!await hasSmsSim()) throw const SmsUnavailableException();
    await _open(Uri(scheme: 'sms', path: phone, queryParameters: {'body': text}));
  }

  /// Opent de telefoon-app met [phone] klaar; zelf op bellen tikken.
  Future<void> openDialer(String phone) => _open(Uri(scheme: 'tel', path: phone));

  Future<void> _open(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Android kon de berichten- of telefoon-app niet openen.');
    } catch (error) {
      // Log geen volledige URI: bij sms bevat die de tekst en locatie.
      debugPrint('Nood-app openen mislukt: ${error.runtimeType}');
      rethrow;
    }
  }
}

class SmsUnavailableException implements Exception {
  const SmsUnavailableException();
}
