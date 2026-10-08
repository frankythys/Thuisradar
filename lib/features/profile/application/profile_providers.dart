import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/profile_preferences.dart';
import '../data/profile_repository.dart';

final profilePreferencesProvider = Provider((ref) => ProfilePreferences());
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseClientProvider)));
final notificationPreferencesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  return ref.watch(profileRepositoryProvider).preferences(userId);
});
