import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;
  Future<Map<String, dynamic>> preferences(String userId) async =>
      await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle() ??
      {};
  Future<void> setNotification(String userId, String key, bool enabled) async {
    if (!const ['arrival', 'departure', 'sos'].contains(key)) {
      throw ArgumentError.value(key);
    }
    await _client.from('notification_preferences').upsert({
      'user_id': userId,
      key: enabled,
    });
  }

  Future<void> setPhone(String userId, String? phone) async {
    await _client.from('profiles').update({'phone': phone}).eq('id', userId);
  }

  Future<void> setColor(String userId, int index) async {
    await _client
        .from('profiles')
        .update({'color_index': index})
        .eq('id', userId);
  }
}
