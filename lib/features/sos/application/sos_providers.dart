import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/sos_repository.dart';
import '../domain/sos_alert.dart';

final sosRepositoryProvider = Provider<SosRepository>(
  (ref) => SosRepository(ref.watch(supabaseClientProvider)),
);

/// Realtime actieve SOS-alarmen van de familie.
final activeSosProvider = StreamProvider.family<List<SosAlert>, String>(
  (ref, familyId) => ref.watch(sosRepositoryProvider).watchActive(familyId),
);
