import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/account_deletion_repository.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => AccountDeletionRepository(ref.watch(supabaseClientProvider)),
);

final sessionProvider = StreamProvider<Session?>((ref) => ref.watch(authRepositoryProvider).watchSession());

/// Id van de ingelogde gebruiker, of null.
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider).value?.user.id);

/// True zolang iemand via de herstellink binnenkwam en nog geen nieuw
/// wachtwoord koos; AuthGate toont dan het scherm "Nieuw wachtwoord".
final passwordRecoveryProvider = NotifierProvider<PasswordRecovery, bool>(PasswordRecovery.new);

class PasswordRecovery extends Notifier<bool> {
  @override
  bool build() {
    final subscription = ref
        .watch(authRepositoryProvider)
        .watchPasswordRecovery()
        .listen((_) => state = true);
    ref.onDispose(subscription.cancel);
    return false;
  }

  /// Nieuw wachtwoord gekozen (of overgeslagen): verder naar de app.
  void finish() => state = false;
}
