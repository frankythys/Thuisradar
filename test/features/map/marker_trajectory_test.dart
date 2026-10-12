import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/marker_trajectory.dart';
import 'package:thuisradar/features/map/domain/road_motion_path.dart';

import 'road_matching_test.dart' show point;

void main() {
  test('positie en camera-richting volgen de hoek in plaats van de diagonaal', () {
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50);
    final motion = MarkerTrajectory([a, corner, b], Duration.zero, const Duration(seconds: 5));
    expect(roadDistance(motion.point(const Duration(milliseconds: 1250)), point(25, 0)), lessThan(.01));
    expect(roadDistance(motion.point(const Duration(milliseconds: 3750)), point(50, 25)), lessThan(.01));
    expect(motion.bearing(const Duration(seconds: 1)), closeTo(90, .01));
    expect(motion.bearing(const Duration(seconds: 4)), closeTo(0, .01));
    expect(motion.point(const Duration(seconds: 20)), b);
    expect(motion.active(const Duration(seconds: 20)), isFalse);
  });
  test('nieuwe update bewaart het nog niet afgelegde deel van de bocht', () {
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50), c = point(50, 100);
    final old = MarkerTrajectory([a, corner, b], Duration.zero, const Duration(seconds: 5));
    const at = Duration(seconds: 1);
    final next = MarkerTrajectory.retarget(
      previous: old,
      target: c,
      at: at,
      duration: const Duration(seconds: 5),
      roadPath: [b, c],
    );
    expect(next.point(at), old.point(at));
    expect(next.path, contains(corner));
    expect(next.path, contains(b));
    expect(next.point(const Duration(seconds: 6)), c);
  });
  test('late wegmatch corrigeert dezelfde fix vanaf de zichtbare positie', () {
    final a = point(0, 0), corner = point(50, 0), b = point(50, 50);
    final old = MarkerTrajectory([a, b], Duration.zero, const Duration(seconds: 5));
    const at = Duration(milliseconds: 100);
    final next = MarkerTrajectory.retarget(
      previous: old,
      target: b,
      at: at,
      duration: const Duration(milliseconds: 4900),
      roadPath: [a, corner, b],
    );
    expect(next.point(at), old.point(at));
    expect(next.path, contains(corner));
    expect(next.point(const Duration(seconds: 5)), b);
  });
}
