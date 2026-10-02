import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final sessionProvider = StreamProvider<Session?>((ref) => ref.watch(authRepositoryProvider).watchSession());

/// Id van de ingelogde gebruiker, of null.
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider).value?.user.id);
