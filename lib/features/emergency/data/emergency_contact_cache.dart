import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/emergency_contact.dart';

/// Kopie van de noodcontacten op de gsm, zodat een SOS ze ook zonder
/// internet kan sms'en (de sms zelf heeft geen internet nodig).
class EmergencyContactCache {
  static String _key(String userId) => 'emergency_contacts_$userId';

  Future<List<EmergencyContact>> read(String userId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key(userId));
      if (raw == null) return const [];
      return [
        for (final item in jsonDecode(raw) as List<dynamic>)
          EmergencyContact.fromJson(item as Map<String, dynamic>),
      ];
    } catch (error) {
      debugPrint('Noodcontacten lokaal lezen mislukt: $error');
      return const [];
    }
  }

  Future<void> write(String userId, List<EmergencyContact> contacts) async {
    try {
      final json = jsonEncode([for (final contact in contacts) contact.toJson(userId)]);
      await (await SharedPreferences.getInstance()).setString(_key(userId), json);
    } catch (error) {
      debugPrint('Noodcontacten lokaal bewaren mislukt: $error');
    }
  }
}
