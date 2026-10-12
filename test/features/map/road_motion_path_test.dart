import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/road_matching.dart';
import 'package:thuisradar/features/map/domain/road_motion_path.dart';

import 'road_matching_test.dart' show point;

void main() {
  test('bocht blijft op de verbonden wegsegmenten', () {
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50);
    final network = RoadNetwork(
      [RoadSegment(1, a, corner), RoadSegment(2, corner, b)],
      {
        1: {2},
        2: {1},
      },
    );
    expect(roadMotionPath(a, b, network), [a, corner, b]);
    expect(roadMotionPath(b, a, network), [b, corner, a]);
  });
  test('begin en einde binnen hetzelfde wegsegment', () {
    final a = point(20, 0), b = point(70, 0);
    final network = RoadNetwork([RoadSegment(1, point(0, 0), point(100, 0), oneWay: true)], {});
    final path = roadMotionPath(a, b, network)!;
    expect(roadDistance(path.first, a), lessThan(.01));
    expect(roadDistance(path.last, b), lessThan(.01));
    expect(roadMotionPath(b, a, network), isNull);
  });
  test('kruising zonder OSM-verbinding en ontbrekende weg geven geen route', () {
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50);
    final network = RoadNetwork([RoadSegment(1, a, corner), RoadSegment(2, corner, b)], {});
    expect(roadMotionPath(a, b, network), isNull);
    expect(roadMotionPath(a, b, const RoadNetwork([], {})), isNull);
  });
  test('lange omweg wordt niet als gereden traject verzonnen', () {
    final a = point(0, 0), far = point(0, 500), b = point(20, 0);
    final network = RoadNetwork([RoadSegment(1, a, far), RoadSegment(1, far, b)], {});
    expect(roadMotionPath(a, b, network), isNull);
  });
}
