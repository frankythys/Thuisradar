import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/emergency_contact.dart';

/// De eigen noodcontacten (tabel `emergency_contacts`, migratie 021). Enkel
/// de eigenaar leest en schrijft ze (RLS).
class EmergencyContactRepository {
  EmergencyContactRepository(this._client);

  final SupabaseClient _client;

  Future<List<EmergencyContact>> fetch(String userId) async {
    final rows = await _client
        .from('emergency_contacts')
        .select('position, name, phone')
        .eq('user_id', userId)
        .order('position');
    return rows.map(EmergencyContact.fromJson).toList();
  }

  /// Bewaart [contacts]; een plaats (1 of 2) zonder contact wordt gewist.
  Future<void> save(String userId, List<EmergencyContact> contacts) async {
    if (contacts.isNotEmpty) {
      await _client.from('emergency_contacts').upsert([
        for (final contact in contacts) contact.toJson(userId),
      ], onConflict: 'user_id,position');
    }
    final empty = [
      for (var position = 1; position <= kMaxEmergencyContacts; position++)
        if (!contacts.any((contact) => contact.position == position)) position,
    ];
    if (empty.isNotEmpty) {
      await _client.from('emergency_contacts').delete().eq('user_id', userId).inFilter('position', empty);
    }
  }
}
