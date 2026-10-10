import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/data/places_repository.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/presentation/add_place_screen.dart';

class _MockPlacesRepository extends Mock implements PlacesRepository {}

const _thuis = Place(
  id: 'thuis',
  familyId: 'fam',
  name: 'Thuis',
  latitude: 51.1765,
  longitude: 4.4122,
  radiusMeters: 150,
  icon: 'home',
  address: 'Pierebeekstraat',
);

void main() {
  testWidgets('Thuis bewerken: het huisje staat precies op het punt dat bewaard wordt', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesRepositoryProvider.overrideWithValue(_MockPlacesRepository()),
          familyPlacesProvider.overrideWith((ref, id) => Stream.value(const [_thuis])),
          familyMembersProvider.overrideWith((ref, id) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AddPlaceScreen(familyId: 'fam', place: _thuis),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Het bewaarde punt is het midden van de kaart; het grote huisje moet daar
    // staan, niet erboven (vroeger 18 punten hoger = ~2 huizen verschil).
    final saved = tester.getCenter(find.byType(FlutterMap));
    final house = tester.getCenter(
      find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.home_rounded && w.size == 40),
    );
    expect(house.dx, closeTo(saved.dx, 0.5));
    expect(house.dy, closeTo(saved.dy, 0.5));
  });
}
