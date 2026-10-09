import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/data/places_repository.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';
import 'package:thuisradar/features/places/presentation/places_screen.dart';

class _MockPlacesRepository extends Mock implements PlacesRepository {}

const _family = Family(id: 'fam', name: 'Thys', inviteCode: 'ABC12345');
const _place = Place(
  id: 'p1',
  familyId: 'fam',
  name: 'Thuis',
  latitude: 51,
  longitude: 3.7,
  radiusMeters: 150,
  icon: 'home',
);

Future<void> _pump(WidgetTester tester, PlacesRepository repo) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        placesRepositoryProvider.overrideWithValue(repo),
        familyPlacesProvider.overrideWith((ref, arg) => Stream.value(const [_place])),
        familyPresenceProvider.overrideWith((ref, arg) => Stream.value(const <PlacePresence>[])),
        familyMembersProvider.overrideWith((ref, arg) => Stream.value(const <FamilyMember>[])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PlacesScreen(family: _family),
      ),
    ),
  );
}

/// Verwijderen zit achter het ⋮-menu van de plaats.
Future<void> _openDelete(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Opties'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Verwijderen'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockPlacesRepository repo;

  setUp(() {
    repo = _MockPlacesRepository();
    when(() => repo.delete(any())).thenAnswer((_) async {});
  });

  testWidgets('verwijderen vraagt bevestiging en roept delete aan na bevestigen', (tester) async {
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await _openDelete(tester);
    expect(find.text('Plaats verwijderen?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Verwijderen'));
    await tester.pumpAndSettle();

    verify(() => repo.delete('p1')).called(1);
    expect(find.text('Nog geen plaatsen'), findsOneWidget);
    expect(find.byTooltip('Opties'), findsNothing);
  });

  testWidgets('annuleren verwijdert niets', (tester) async {
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await _openDelete(tester);
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();

    verifyNever(() => repo.delete(any()));
  });
  testWidgets('mislukte verwijdering behoudt de plaats en toont een fout', (tester) async {
    when(() => repo.delete(any())).thenThrow(Exception('database unavailable'));
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _openDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Verwijderen'));
    await tester.pumpAndSettle();
    expect(find.text('Thuis'), findsOneWidget);
    expect(find.text('Verwijderen mislukt. Probeer opnieuw.'), findsOneWidget);
  });
}
