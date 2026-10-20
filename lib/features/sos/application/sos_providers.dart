import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resilient_stream.dart';
import '../../../core/utils/resync_signal.dart';
import '../data/sos_repository.dart';
import '../domain/sos_alert.dart';

final sosRepositoryProvider = Provider<SosRepository>(
  (ref) => SosRepository(ref.watch(supabaseClientProvider)),
);

/// Realtime actieve SOS-alarmen van de familie. Herstelt zichzelf als het
/// realtime-kanaal wegvalt: een inkomend alarm mag nooit stilvallen.
final activeSosProvider = StreamProvider.family<List<SosAlert>, String>((ref, familyId) {
  final repository = ref.watch(sosRepositoryProvider);
  return resilientStream(
    () => repository.watchActive(familyId),
    resync: ref.watch(resyncSignalProvider).stream,
    onError: (error) => debugPrint('SOS-stroom (realtime) fout: $error'),
  );
});

final sosReceiptsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, alertId) => ref.watch(sosRepositoryProvider).watchReceipts(alertId),
);
