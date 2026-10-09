import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/data/places_repository.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/presentation/add_place_screen.dart';

class _MockPlacesRepository extends Mock implements PlacesRepository {}

const _place = Place(
  id: 'p1',
  familyId: 'fam',
  name: 'Oma',
  latitude: 51.2,
  longitude: 4.4,
  radiusMeters: 200,
  icon: 'home',
  address: 'Dorpsstraat 1, Boom',
  notifyDeparture: false,
  watchedMembers: ['liam'],
);

void main() {
  testWidgets('bewerken opent met de bestaande gegevens en slaat op als update', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final repo = _MockPlacesRepository();
    when(
      () => repo.update(
        id: any(named: 'id'),
        name: any(named: 'name'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        radiusMeters: any(named: 'radiusMeters'),
        icon: any(named: 'icon'),
        address: any(named: 'address'),
        watchedMembers: any(named: 'watchedMembers'),
        notifyArrival: any(named: 'notifyArrival'),
        notifyDeparture: any(named: 'notifyDeparture'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placesRepositoryProvider.overrideWithValue(repo),
          familyPlacesProvider.overrideWith((ref, id) => Stream.value(const [_place])),
          familyMembersProvider.overrideWith(
            (ref, id) => Stream.value(const [
              FamilyMember(userId: 'liam', displayName: 'Liam', isOwner: false, colorIndex: 3),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AddPlaceScreen(familyId: 'fam', place: _place),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Plaats bewerken'), findsOneWidget);
    expect(find.text('Wijzigingen opslaan'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Oma'), findsOneWidget);
    expect(find.text('200 meter'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Oma'), 'Bij oma');
    await tester.tap(find.text('Wijzigingen opslaan'));
    await tester.pump(const Duration(milliseconds: 200));

    verify(
      () => repo.update(
        id: 'p1',
        name: 'Bij oma',
        latitude: 51.2,
        longitude: 4.4,
        radiusMeters: 200,
        icon: 'home',
        address: 'Dorpsstraat 1, Boom',
        watchedMembers: ['liam'],
        notifyArrival: true,
        notifyDeparture: false,
      ),
    ).called(1);
  });
}
