import 'package:supabase_flutter/supabase_flutter.dart';

/// Het eigen account wissen (Google Play eist dat in de app; migratie 025).
///
/// Eerst de eigen foto's en spraakberichten in Storage: Supabase laat die
/// niet via SQL wissen, en na het wissen van het account kan je ze niet meer
/// opzoeken (lezen vraagt lidmaatschap). Daarna wist `delete_my_account` het
/// account met alles wat eraan hangt. Afmelden op de gsm doet de aanroeper.
class AccountDeletionRepository {
  AccountDeletionRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'family-media';
  static const _pageSize = 100;

  Future<void> deleteMyAccount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Niet ingelogd');

    final paths = await _myMediaPaths(userId);
    if (paths.isNotEmpty) await _client.storage.from(_bucket).remove(paths);

    await _client.rpc<void>('delete_my_account');
  }

  /// Alle bijlagen die deze gebruiker in zijn gezinnen deelde
  /// (`<gezin>/<gebruiker>/<bestand>`, zie ChatRepository).
  Future<List<String>> _myMediaPaths(String userId) async {
    final rows = await _client.from('family_members').select('family_id').eq('user_id', userId);
    final paths = <String>[];
    for (final row in rows) {
      final folder = '${row['family_id']}/$userId';
      for (var offset = 0; ; offset += _pageSize) {
        final files = await _client.storage
            .from(_bucket)
            .list(
              path: folder,
              searchOptions: SearchOptions(limit: _pageSize, offset: offset),
            );
        paths.addAll(files.map((file) => '$folder/${file.name}'));
        if (files.length < _pageSize) break;
      }
    }
    return paths;
  }
}
