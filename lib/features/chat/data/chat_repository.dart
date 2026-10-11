import 'dart:typed_data';

import '../domain/attachment.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/message.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// Zoveel recente berichten laadt de chat. PostgREST geeft er hoe dan ook
  /// hooguit 1000 terug; zonder eigen grens waren dat na een tijd de oudste.
  static const recentLimit = 500;

  /// Realtime berichten (oudste eerst). `order()` op een stream staat standaard
  /// op aflopend: we halen de nieuwste op en sorteren zelf oplopend.
  Stream<List<Message>> watchMessages(String familyId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(recentLimit)
        .map(
          (rows) => rows.map(Message.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  Future<String> attachmentUrl(String path) =>
      _client.storage.from('family-media').createSignedUrl(path, 300);

  Future<void> sendAttachment({
    required String familyId,
    required String userId,
    required Uint8List bytes,
    required String kind,
    required String extension,
    required String mime,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('Bijlage is groter dan 10 MB');
    }
    final path = '$familyId/$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final bucket = _client.storage.from('family-media');
    await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    try {
      await send(familyId: familyId, userId: userId, body: Attachment(path, kind).encode());
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
  }

  Future<void> send({required String familyId, required String userId, required String body}) {
    return _client.from('messages').insert({'family_id': familyId, 'user_id': userId, 'body': body});
  }
}
