import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_timeline.dart';

const _school = Place(
  id: 'p1',
  familyId: 'fam',
  name: 'School',
  latitude: 51.05,
  longitude: 3.72,
  radiusMeters: 150,
  icon: 'school',
);

TimelineEntry _stop(double lat, double lng) => TimelineEntry(
  kind: TimelineKind.stop,
  start: DateTime(2026, 1, 2, 8),
  end: DateTime(2026, 1, 2, 8, 30),
  latitude: lat,
  longitude: lng,
);

void main() {
  test('een stop binnen de straal krijgt de plaatsnaam', () {
    final result = attachPlaceNames([_stop(51.05, 3.72)], const [_school]);
    expect(result.single.placeName, 'School');
  });

  test('een stop ver van elke plaats blijft zonder naam', () {
    final result = attachPlaceNames([_stop(50.0, 3.0)], const [_school]);
    expect(result.single.placeName, isNull);
  });

  test('zonder plaatsen verandert er niets', () {
    final entries = [_stop(51.05, 3.72)];
    expect(attachPlaceNames(entries, const []), same(entries));
  });
}
