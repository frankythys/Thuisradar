/// Eén chatbericht (tabel `messages`).
class Message {
  const Message({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.body,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as int,
    familyId: json['family_id'] as String,
    userId: json['user_id'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  final int id;
  final String familyId;
  final String userId;
  final String body;
  final DateTime createdAt;
}
