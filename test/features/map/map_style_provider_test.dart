import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/map/application/map_style_provider.dart';

void main() {
  test('standaard gewone kaart; satelliet wordt onthouden na herstart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    expect(first.read(mapSatelliteProvider), isFalse);

    await first.read(mapSatelliteProvider.notifier).toggle();
    expect(first.read(mapSatelliteProvider), isTrue);

    // App opnieuw geopend.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(mapSatelliteProvider);
    await pumpEventQueue();
    expect(second.read(mapSatelliteProvider), isTrue);
  });
}
