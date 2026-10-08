import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sos_alert.dart';

class SosRepository {
  SosRepository(this._client);

  final SupabaseClient _client;

  Future<void> acknowledge(String alertId, String userId, {bool onTheWay = false}) async {
    final values = <String, dynamic>{'alert_id': alertId, 'user_id': userId};
    if (onTheWay) values['on_the_way'] = true;
    await _client
        .from('sos_receipts')
        .upsert(values, onConflict: 'alert_id,user_id', ignoreDuplicates: !onTheWay);
  }

  Stream<List<Map<String, dynamic>>> watchReceipts(String alertId) =>
      _client.from('sos_receipts').stream(primaryKey: ['alert_id', 'user_id']).eq('alert_id', alertId);

  /// Stuurt een noodoproep met de laatst bekende locatie.
  Future<void> raise({
    required String familyId,
    required String userId,
    required double latitude,
    required double longitude,
  }) {
    return _client.from('sos_alerts').insert({
      'family_id': familyId,
      'user_id': userId,
      'lat': latitude,
      'lng': longitude,
    });
  }

  /// Markeert een eigen alarm als opgelost.
  Future<void> resolve(String id) {
    return _client
        .from('sos_alerts')
        .update({'status': 'resolved', 'resolved_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Realtime stroom van de actieve alarmen van de familie (nieuwste eerst).
  Stream<List<SosAlert>> watchActive(String familyId) {
    return _client
        .from('sos_alerts')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .map(
          (rows) =>
              rows.map(SosAlert.fromJson).where((a) => a.active).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }
}
