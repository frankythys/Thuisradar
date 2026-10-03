import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/chat_repository.dart';
import '../data/chat_store.dart';
import '../domain/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider)),
);

final chatStoreProvider = Provider<ChatStore>((ref) => ChatStore());

final familyMessagesProvider = StreamProvider.family<List<Message>, String>(
  (ref, familyId) => ref.watch(chatRepositoryProvider).watchMessages(familyId),
);
