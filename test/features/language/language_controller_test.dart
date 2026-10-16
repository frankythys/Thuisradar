import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/language/application/language_providers.dart';
import 'package:thuisradar/features/language/data/language_store.dart';
import 'package:thuisradar/features/language/domain/app_language.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('start met de bij het opstarten gelezen keuze', () {
    final container = ProviderContainer(overrides: [savedLanguageProvider.overrideWithValue(AppLanguage.de)]);
    addTearDown(container.dispose);

    expect(container.read(languageOverrideProvider), AppLanguage.de);
  });

  test('een keuze geldt meteen en blijft bewaard; null = weer de toesteltaal', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(languageOverrideProvider.notifier);

    await controller.choose(AppLanguage.tr);
    expect(container.read(languageOverrideProvider), AppLanguage.tr);
    expect(await LanguageStore().read(), 'tr');

    await controller.choose(null);
    expect(container.read(languageOverrideProvider), isNull);
    expect(await LanguageStore().read(), isNull);
  });

  test('appLocalizationsProvider volgt de eigen keuze, ook buiten widgets', () async {
    final container = ProviderContainer(overrides: [savedLanguageProvider.overrideWithValue(AppLanguage.de)]);
    addTearDown(container.dispose);
    expect(
      container.read(appLocalizationsProvider).locationSharingNotice,
      'Dein Standort wird mit deiner Familie geteilt',
    );

    await container.read(languageOverrideProvider.notifier).choose(AppLanguage.fr);
    expect(container.read(appLocalizationsProvider).channelSos, 'Alarmes SOS');
  });
}
