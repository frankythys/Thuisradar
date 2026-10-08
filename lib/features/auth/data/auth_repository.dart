import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  static const _nameKey = 'display_name';

  Stream<Session?> watchSession() async* {
    yield _client.auth.currentSession;
    yield* _client.auth.onAuthStateChange.map((state) => state.session);
  }

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Geeft `true` terug als er meteen een sessie is, `false` als de gebruiker
  /// eerst zijn e-mail moet bevestigen.
  Future<bool> signUp({required String email, required String password, required String displayName}) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {_nameKey: displayName},
    );
    return response.session != null;
  }

  Future<void> resetPassword(String email) => _client.auth.resetPasswordForEmail(email);

  Future<void> signOut() => _client.auth.signOut();

  /// Werkt de weergavenaam van de ingelogde gebruiker bij.
  Future<void> updateDisplayName(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').update({'display_name': name}).eq('id', user.id);
  }

  /// Zorgt dat er een profielrij bestaat voor de ingelogde gebruiker.
  /// De naam komt uit de metadata die bij het registreren is opgeslagen.
  Future<void> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final name = (user.userMetadata?[_nameKey] as String?)?.trim();
    await _client
        .from('profiles')
        .upsert(
          {'id': user.id, 'display_name': (name == null || name.isEmpty) ? 'Gezinslid' : name},
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }
}
