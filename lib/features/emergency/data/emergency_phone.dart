import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sms'en en bellen vanaf deze gsm, voor de noodcontacten.
///
/// Android: rechtstreeks, zonder tikken (SmsManager en een directe oproep via
/// `MainActivity`), met de toestemmingen "sms versturen" en "bellen". Werkt
/// ook zonder internet; kost een gewone sms van je eigen abonnement.
/// iPhone: Apple laat een app nooit zelf sms'en of bellen; daar kan enkel
/// de berichten- of telefoon-app openen met alles ingevuld.
class EmergencyPhone {
  static const _channel = MethodChannel('be.thuisradar/emergency');

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Kan deze gsm automatisch sms'en en bellen (Android met toestemming)?
  Future<bool> canSendAutomatically() async {
    if (!_android) return false;
    try {
      return await Permission.sms.isGranted && await Permission.phone.isGranted;
    } catch (error) {
      debugPrint('Toestemming sms/bellen onbekend: $error');
      return false;
    }
  }

  /// Vraagt de toestemmingen "sms versturen" en "bellen". Geeft terug of
  /// beide gegeven zijn (op iPhone altijd false: daar bestaat het niet).
  Future<bool> requestAccess() async {
    if (!_android) return false;
    try {
      final statuses = await [Permission.sms, Permission.phone].request();
      if (statuses.values.every((status) => status.isGranted)) return true;
      // Eerder "niet meer vragen": Android toont geen venster meer, dus de
      // instellingen van de app openen.
      if (statuses.values.any((status) => status.isPermanentlyDenied)) await openAppSettings();
      return false;
    } catch (error) {
      debugPrint('Toestemming sms/bellen vragen mislukt: $error');
      return false;
    }
  }

  /// Verstuurt [text] meteen naar [phone], zonder tikken (enkel Android met
  /// toestemming). Geeft terug of het lukte.
  Future<bool> sendSms(String phone, String text) =>
      _direct('sendSms', {'phone': phone, 'text': text}, Permission.sms);

  /// Belt [phone] meteen (enkel Android met toestemming). Geeft terug of het
  /// lukte.
  Future<bool> call(String phone) => _direct('call', {'phone': phone}, Permission.phone);

  /// Opent de berichten-app met [text] klaar voor [phone]; zelf versturen.
  Future<void> openSms(String phone, String text) =>
      _open(Uri(scheme: 'sms', path: phone, queryParameters: {'body': text}));

  /// Opent de telefoon-app met [phone] klaar; zelf op bellen tikken.
  Future<void> openDialer(String phone) => _open(Uri(scheme: 'tel', path: phone));

  Future<bool> _direct(String method, Map<String, String> arguments, Permission permission) async {
    if (!_android) return false;
    try {
      if (!await permission.isGranted) return false;
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on PlatformException catch (error) {
      debugPrint('Noodcontact $method mislukt: ${error.code} ${error.message}');
    } on MissingPluginException catch (error) {
      debugPrint('Noodcontact-kanaal ontbreekt: $error');
    }
    return false;
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri)) debugPrint('Kon $uri niet openen');
    } catch (error) {
      debugPrint('Kon $uri niet openen: $error');
    }
  }
}
