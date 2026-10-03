import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/family_event.dart';

class EventsRepository {
  EventsRepository(this._client);

  final SupabaseClient _client;

  /// Realtime feed van familie-gebeurtenissen (nieuwste eerst).
  Stream<List<FamilyEvent>> watchEvents(String familyId) {
    return _client
        .from('family_events')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .map(
          (rows) =>
              rows.map(FamilyEvent.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<DateTime?> fetchLastSeen(String userId, String familyId) async {
    final row = await _client
        .from('event_reads')
        .select('last_seen_at')
        .eq('user_id', userId)
        .eq('family_id', familyId)
        .maybeSingle();
    final value = row?['last_seen_at'] as String?;
    return value == null ? null : DateTime.parse(value).toLocal();
  }

  Future<void> markSeen(String userId, String familyId) {
    return _client.from('event_reads').upsert({
      'user_id': userId,
      'family_id': familyId,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,family_id');
  }
}
