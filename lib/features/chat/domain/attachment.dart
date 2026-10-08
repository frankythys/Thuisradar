import 'dart:convert';

class Attachment {
  const Attachment(this.path, this.kind);
  final String path;
  final String kind;
  String encode() => jsonEncode({'attachment': path, 'kind': kind});
  static Attachment? parse(String body, String familyId) {
    try {
      final data = jsonDecode(body);
      if (data is! Map || !const ['image', 'audio'].contains(data['kind'])) {
        return null;
      }
      final path = data['attachment'];
      if (path is! String || !path.startsWith('$familyId/') || path.contains('..')) {
        return null;
      }
      return Attachment(path, data['kind'] as String);
    } catch (_) {
      return null;
    }
  }
}
