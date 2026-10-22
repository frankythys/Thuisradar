import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/language/application/language_providers.dart';
import 'package:thuisradar/features/language/domain/app_language.dart';
import 'package:thuisradar/features/profile/application/profile_providers.dart';
import 'package:thuisradar/features/profile/data/profile_repository.dart';

class _Profiles extends Mock implements ProfileRepository {}

class _Client extends Mock implements SupabaseClient {}

const _family = Family(id: 'fam', name: 'Thys', inviteCode: 'K7Q2M9XA');

void main() {
  late _Profiles profiles;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    profiles = _Profiles();
    when(() => profiles.setLanguage(any(), any())).thenAnswer((_) async {});
  });

  ProviderContainer container({String? userId = 'me'}) {
    final c = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profiles),
        currentUserIdProvider.overrideWithValue(userId),
        savedLanguageProvider.overrideWithValue(AppLanguage.fr),
        myFamilyProvider.overrideWith((ref) async => _family),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('aangemeld: de app-taal komt in het profiel, ook na een taalwissel', () async {
    final c = container();
    c.listen(profileLanguageSyncProvider, (_, _) {});
    await pumpEventQueue();
    verify(() => profiles.setLanguage('me', 'fr')).called(greaterThanOrEqualTo(1));

    await c.read(languageOverrideProvider.notifier).choose(AppLanguage.de);
    await pumpEventQueue();
    verify(() => profiles.setLanguage('me', 'de')).called(1);
  });

  test('niet aangemeld: niets naar de server', () async {
    final c = container(userId: null);
    c.listen(profileLanguageSyncProvider, (_, _) {});
    await pumpEventQueue();
    verifyNever(() => profiles.setLanguage(any(), any()));
  });

  test('zonder migratie 022 (kolom ontbreekt): geen fout', () async {
    final client = _Client();
    when(
      () => client.from('profiles'),
    ).thenThrow(const PostgrestException(message: "Could not find the 'language' column", code: 'PGRST204'));
    await expectLater(ProfileRepository(client).setLanguage('me', 'fr'), completes);
  });

  test('een andere serverfout wordt niet ingeslikt', () async {
    final client = _Client();
    when(() => client.from('profiles')).thenThrow(const PostgrestException(message: 'offline', code: '500'));
    await expectLater(ProfileRepository(client).setLanguage('me', 'fr'), throwsA(isA<PostgrestException>()));
  });
}
