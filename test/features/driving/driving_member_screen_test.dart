import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/driving/presentation/driving_member_screen.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/shared/widgets/location_preview.dart';

const _member = FamilyMember(userId: 'u1', displayName: 'Franky', isOwner: true, colorIndex: 0);
final _day = DateTime(2026, 1, 2);

/// Geen echte geocoder in tests; de eigen plaatsen leveren de namen.
class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

const _places = [
  Place(id: 'home', familyId: 'fam', name: 'Thuis', latitude: 51.0, longitude: 3.7, radiusMeters: 200, icon: 'home'),
  Place(id: 'work', familyId: 'fam', name: 'Werk', latitude: 51.05, longitude: 3.72, radiusMeters: 200, icon: 'work'),
];

final _entries = [
  TimelineEntry(
    kind: TimelineKind.stop,
    start: _day.add(const Duration(hours: 6)),
    end: _day.add(const Duration(hours: 6, minutes: 16)),
    latitude: 51.0,
    longitude: 3.7,
  ),
  TimelineEntry(
    kind: TimelineKind.move,
    start: _day.add(const Duration(hours: 6, minutes: 16)),
    end: _day.add(const Duration(hours: 7, minutes: 55)),
    latitude: 51.05,
    longitude: 3.72,
    distanceMeters: 15800,
  ),
  TimelineEntry(
    kind: TimelineKind.stop,
    start: _day.add(const Duration(hours: 7, minutes: 55)),
    end: _day.add(const Duration(hours: 15, minutes: 51)),
    latitude: 51.05,
    longitude: 3.72,
  ),
];

/// De ruwe GPS-punten van de rit (elke twee minuten, zoals het toestel ze
/// terwijl het rijdt verstuurt): de kaart volgt deze punten met de bocht van
/// de weg erin, niet de rechte lijn tussen de stopplaatsen.
final _points = [
  for (final minute in [16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60])
    TrackPoint(
      latitude: 51.0 + minute / 1000,
      longitude: 3.7 + minute / 2000,
      recordedAt: _day.add(Duration(hours: 6, minutes: minute)),
    ),
];

/// Dezelfde rit, maar met een gat van twintig minuten in de metingen (toestel
/// uit): de kaart mag dat gat nooit met een rechte lijn overbruggen.
final _gappedPoints = [
  for (final point in _points)
    if (point.recordedAt.isBefore(_day.add(const Duration(hours: 6, minutes: 40))) ||
        point.recordedAt.isAfter(_day.add(const Duration(hours: 6, minutes: 55))))
      point,
];

Future<void> _pump(WidgetTester tester, {DayHistory? history}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 1, 2, 18))),
        geocodingSourceProvider.overrideWithValue(_NoGeocoding()),
        familyPlacesProvider.overrideWith((ref, id) => Stream.value(_places)),
        dayHistoryProvider.overrideWith(
          (ref, query) async => query.day == _day
              ? history ?? (entries: _entries, points: _points)
              : (entries: const <TimelineEntry>[], points: const <TrackPoint>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: DrivingMemberScreen(member: _member, familyId: 'fam', week: _day),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toont de dag, de kaart en de ritten en verblijven van die dag', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester);

    expect(find.text('Vandaag'), findsOneWidget);
    // Verblijven komen uit de tijdlijn, met hun eigen plaatsnaam en duur.
    expect(find.text('Thuis'), findsWidgets);
    expect(find.text('Werk'), findsWidgets);
    expect(find.text('7 uur 56 min'), findsOneWidget);
    // De rit loopt van de eerste tot de laatste rijdende meting (06:16 - 07:00).
    expect(find.textContaining('06:16 - 07:00'), findsOneWidget);
    expect(find.textContaining('5,1 km'), findsOneWidget);
    // Alleen de rit heeft een kaart (het verblijf niet), en die kaart volgt het
    // echte routespoor van die rit: alle punten, als één aaneengesloten lijn.
    expect(find.byType(LocationPreview), findsOneWidget);
    final preview = tester.widget<LocationPreview>(find.byType(LocationPreview));
    expect(preview.segments, hasLength(1));
    expect(preview.segments.single, hasLength(_points.length));
    expect(preview.segments.single.first.latitude, _points.first.latitude);
    expect(preview.segments.single.last.longitude, _points.last.longitude);
    // Inzoomen op de rit zelf en geen avatar-marker: het spoor met begin- en
    // eindpunt vertelt het verhaal.
    expect(preview.fitBounds, isTrue);
    expect(preview.showMarker, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('een gat in de metingen wordt niet met een rechte lijn verbonden', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pump(tester, history: (entries: _entries, points: _gappedPoints));

    // Twee korte ritten na elkaar in plaats van één rit die het gat overbrugt.
    final previews = tester.widgetList<LocationPreview>(find.byType(LocationPreview)).toList();
    expect(previews, hasLength(2));
    for (final preview in previews) {
      expect(preview.segments, hasLength(1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('toont de lege staat zonder daggeschiedenis', (tester) async {
    await _pump(tester, history: (entries: const <TimelineEntry>[], points: const <TrackPoint>[]));

    expect(find.text('Geen locatiegeschiedenis deze week.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
