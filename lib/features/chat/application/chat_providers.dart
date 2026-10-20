import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resilient_stream.dart';
import '../../../core/utils/resync_signal.dart';
import '../data/chat_repository.dart';
import '../data/chat_store.dart';
import '../domain/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider)),
);

final chatStoreProvider = Provider<ChatStore>((ref) => ChatStore());

/// Realtime chatberichten; herstelt zichzelf als het realtime-kanaal wegvalt.
final familyMessagesProvider = StreamProvider.family<List<Message>, String>((ref, familyId) {
  final repository = ref.watch(chatRepositoryProvider);
  return resilientStream(
    () => repository.watchMessages(familyId),
    resync: ref.watch(resyncSignalProvider).stream,
    onError: (error) => debugPrint('Chatstroom (realtime) fout: $error'),
  );
});
