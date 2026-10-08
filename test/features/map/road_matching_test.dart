import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/road_matching.dart';

RoadPoint point(double x, double y) => (lat: y / 111320, lng: x / 111320);
MemberLocation fix(
  double x,
  double y,
  int second, {
  double accuracy = 10,
  double speed = 10,
}) => MemberLocation(
  userId: 'u',
  familyId: 'f',
  latitude: point(x, y).lat,
  longitude: point(x, y).lng,
  updatedAt: DateTime.utc(2026, 10, 8).add(Duration(seconds: second)),
  accuracyMeters: accuracy,
  speedMps: speed,
);
RoadSegment road(int id, double y, {bool oneWay = false}) =>
    RoadSegment(id, point(-500, y), point(500, y), oneWay: oneWay);

void main() {
  test('reeks autoritpunten wordt op een duidelijke weg gematcht', () {
    final trace = [fix(0, 12, 0), fix(50, 12, 5), fix(100, 12, 10)];
    final result = matchRoadTrace(trace, RoadNetwork([road(1, 0)], {}));
    expect(result, isNotNull);
    expect(result!.lat, closeTo(0, 1e-9));
    expect(result.lng, closeTo(point(100, 0).lng, 1e-9));
    expect(trace.last.latitude, isNot(0));
  });
  test('gelijke parallelle wegen geven geen verzonnen zekerheid', () {
    final trace = [fix(0, 10, 0), fix(50, 10, 5), fix(100, 10, 10)];
    expect(
      matchRoadTrace(trace, RoadNetwork([road(1, 0), road(2, 20)], {})),
      isNull,
    );
  });
  test('voorgeschiedenis houdt auto bij dezelfde parallelle weg', () {
    final trace = [
      fix(0, 0, 0, accuracy: 5),
      fix(50, 0, 5, accuracy: 5),
      fix(100, 12, 10),
    ];
    final result = matchRoadTrace(
      trace,
      RoadNetwork([road(1, 0), road(2, 20)], {}),
    );
    expect(result!.lat, closeTo(0, 1e-9));
  });
  test('tegen rijrichting op eenrichtingsweg wordt niet gematcht', () {
    expect(
      matchRoadTrace([
        fix(100, 5, 0),
        fix(50, 5, 5),
        fix(0, 5, 10),
      ], RoadNetwork([road(1, 0, oneWay: true)], {})),
      isNull,
    );
  });
  test('lopen, grof GPS en ontbrekende wegen blijven ruwe GPS', () {
    final network = RoadNetwork([road(1, 0)], {});
    expect(
      matchRoadTrace([
        fix(0, 3, 0, speed: 2),
        fix(10, 3, 5, speed: 2),
        fix(20, 3, 10, speed: 2),
      ], network),
      isNull,
    );
    expect(
      matchRoadTrace([
        fix(0, 3, 0, accuracy: 80),
        fix(50, 3, 5),
        fix(100, 3, 10),
      ], network),
      isNull,
    );
    expect(
      matchRoadTrace([
        fix(0, 3, 0),
        fix(50, 3, 5),
        fix(100, 3, 10),
      ], const RoadNetwork([], {})),
      isNull,
    );
  });
  test('voetpaden en verboden autowegen worden niet gebruikt', () {
    final network = RoadNetwork.fromOverpass({
      'elements': [
        for (final highway in ['footway', 'residential'])
          {
            'type': 'way',
            'id': highway == 'footway' ? 1 : 2,
            'nodes': [10, 11],
            'geometry': [
              {'lat': 0, 'lon': 0},
              {'lat': 0, 'lon': 0.01},
            ],
            'tags': {
              'highway': highway,
              if (highway == 'residential') 'motor_vehicle': 'no',
            },
          },
      ],
    });
    expect(network.segments, isEmpty);
  });
}
