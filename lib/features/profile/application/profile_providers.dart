import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../language/application/language_providers.dart';
import '../data/profile_preferences.dart';
import '../data/profile_repository.dart';

final profilePreferencesProvider = Provider((ref) => ProfilePreferences());
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseClientProvider)));
final notificationPreferencesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  return ref.watch(profileRepositoryProvider).preferences(userId);
});

/// Houdt `profiles.language` gelijk met de app-taal (migratie 022), zodat de
/// SOS-push in de taal van de ontvanger komt. Schrijft bij het aanmelden, bij
/// elke taalwissel en zodra het profiel bestaat (een nieuw account krijgt
/// zijn profiel pas in myFamilyProvider). ThuisradarApp kijkt hiernaar.
final profileLanguageSyncProvider = Provider<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final language = ref.watch(appLocalizationsProvider).localeName;
  if (userId == null) return;
  ref.watch(myFamilyProvider.select((family) => family.hasValue));
  ref.read(profileRepositoryProvider).setLanguage(userId, language).catchError((Object error) {
    debugPrint('Taal bewaren mislukt: $error');
  });
});
