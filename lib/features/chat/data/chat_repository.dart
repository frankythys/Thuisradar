import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/message.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// Realtime berichten (oudste eerst).
  Stream<List<Message>> watchMessages(String familyId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .order('created_at')
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  Future<void> send({required String familyId, required String userId, required String body}) {
    return _client.from('messages').insert({'family_id': familyId, 'user_id': userId, 'body': body});
  }
}
