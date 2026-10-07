import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/stationary_since.dart';

void main() {
  final t0 = DateTime(2026, 10, 7, 9);
  MemberLocation loc(String id, double lat, double lng, DateTime at) =>
      MemberLocation(userId: id, familyId: 'fam', latitude: lat, longitude: lng, updatedAt: at);

  test('dezelfde plek behoudt de begintijd', () {
    var anchors = updateStationaryAnchors(const {}, [loc('u', 51, 3, t0)]);
    expect(anchors['u']!.since, t0);

    // ~11 m verder, binnen de drempel: sinds blijft t0.
    final later = t0.add(const Duration(minutes: 1));
    anchors = updateStationaryAnchors(anchors, [loc('u', 51.0001, 3, later)]);
    expect(anchors['u']!.since, t0);
  });

  test('ver genoeg verplaatst start de teller opnieuw', () {
    final first = updateStationaryAnchors(const {}, [loc('u', 51, 3, t0)]);
    final t1 = t0.add(const Duration(minutes: 5));
    final second = updateStationaryAnchors(first, [loc('u', 51.01, 3, t1)]); // ~1,1 km
    expect(second['u']!.since, t1);
  });

  test('verdwenen leden vallen weg', () {
    final first = updateStationaryAnchors(const {}, [loc('u', 51, 3, t0)]);
    final second = updateStationaryAnchors(first, const []);
    expect(second.containsKey('u'), isFalse);
  });
}
