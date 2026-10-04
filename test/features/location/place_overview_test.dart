import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/place_overview.dart';
import 'package:thuisradar/features/notifications/domain/family_event.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/domain/place_presence.dart';

Place _place(String id, String name) => Place(
  id: id,
  familyId: 'fam',
  name: name,
  latitude: 51,
  longitude: 3.7,
  radiusMeters: 150,
  icon: 'home',
);

FamilyEvent _arrival(String placeId, DateTime at) => FamilyEvent(
  id: at.millisecondsSinceEpoch,
  familyId: 'fam',
  actorUserId: 'u1',
  type: FamilyEventType.arrival,
  placeId: placeId,
  createdAt: at,
);

void main() {
  final now = DateTime(2026, 10, 4, 13, 30);

  test('plaatsen waar nu iemand is komen eerst', () {
    final result = placeOverviews(
      [_place('a', 'School'), _place('b', 'Thuis')],
      [
        PlacePresence(
          userId: 'u1',
          placeId: 'b',
          isInside: true,
          since: now.subtract(const Duration(hours: 2)),
        ),
      ],
      const [],
    );

    expect(result.first.place.name, 'Thuis');
    expect(result.first.presentCount, 1);
    expect(result.first.since, now.subtract(const Duration(hours: 2)));
  });

  test('daarna de drukst bezochte zones, dan alfabetisch', () {
    final result = placeOverviews(
      [_place('a', 'Werk'), _place('b', 'School'), _place('c', 'Sport')],
      const [],
      [
        _arrival('a', now.subtract(const Duration(days: 1))),
        _arrival('a', now.subtract(const Duration(days: 2))),
        _arrival('b', now.subtract(const Duration(days: 3))),
      ],
    );

    expect(result.map((p) => p.place.name), ['Werk', 'School', 'Sport']);
  });

  test('houdt de laatste aankomst bij per plaats', () {
    final last = now.subtract(const Duration(hours: 1));
    final result = placeOverviews(
      [_place('a', 'Thuis')],
      const [],
      [_arrival('a', now.subtract(const Duration(days: 2))), _arrival('a', last)],
    );

    expect(result.single.lastArrival, last);
  });

  test('beperkt tot het opgegeven aantal', () {
    final result = placeOverviews(
      [_place('a', 'A'), _place('b', 'B'), _place('c', 'C'), _place('d', 'D')],
      const [],
      const [],
      limit: 2,
    );

    expect(result, hasLength(2));
  });

  test('negeert vertrek-gebeurtenissen', () {
    final result = placeOverviews(
      [_place('a', 'Thuis'), _place('b', 'School')],
      const [],
      [
        FamilyEvent(
          id: 1,
          familyId: 'fam',
          actorUserId: 'u1',
          type: FamilyEventType.departure,
          placeId: 'b',
          createdAt: now,
        ),
      ],
    );

    expect(result.map((p) => p.place.name), ['School', 'Thuis']);
  });
}