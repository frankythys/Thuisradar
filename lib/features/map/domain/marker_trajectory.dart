import 'dart:math' as math;

import 'marker_motion.dart';
import 'road_matching.dart';
import 'road_motion_path.dart';

/// Een eigen tijdlijn per lid: updates van een ander lid mogen deze beweging
/// niet vertragen of herstarten. Posities blijven binnen ontvangen wegpunten.
class MarkerTrajectory {
  MarkerTrajectory(this.path, this.started, this.duration) {
    for (var i = 1; i < path.length; i++) {
      _lengths.add(_lengths.last + roadDistance(path[i - 1], path[i]));
    }
  }

  final List<RoadPoint> path;
  final Duration started;
  final Duration duration;
  final _lengths = <double>[0];
  RoadPoint get target => path.last;

  bool active(Duration at) => _lengths.last > .01 && at - started < duration;
  double _progress(Duration at) => duration.inMicroseconds == 0
      ? 1
      : ((at - started).inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);

  RoadPoint point(Duration at) => _point(_progress(at));
  RoadPoint _point(double progress) {
    final distance = _lengths.last * progress;
    for (var i = 1; i < path.length; i++) {
      if (distance <= _lengths[i] && _lengths[i] > _lengths[i - 1]) {
        return lerpCoordinate(
          path[i - 1],
          path[i],
          (distance - _lengths[i - 1]) / (_lengths[i] - _lengths[i - 1]),
        );
      }
    }
    return target;
  }

  List<RoadPoint> remaining(Duration at) {
    final distance = _lengths.last * _progress(at);
    return [
      point(at),
      for (var i = 1; i < path.length; i++)
        if (_lengths[i] > distance + .01) path[i],
    ];
  }

  static MarkerTrajectory retarget({
    required MarkerTrajectory previous,
    required RoadPoint target,
    required Duration at,
    required Duration duration,
    List<RoadPoint>? roadPath,
  }) {
    final from = previous.point(at);
    var path = <RoadPoint>[from, target];
    if (roadPath != null && roadPath.length >= 2 && roadDistance(roadPath.last, target) < 1) {
      if (roadDistance(previous.target, roadPath.first) < 1) {
        path = [...previous.remaining(at), ...roadPath.skip(1)];
      } else {
        // Een late wegmatch voor dezelfde fix vervangt de rechte animatie
        // vanaf haar huidige positie, zonder terug te springen naar de start.
        final trimmed = _trimFrom(from, roadPath);
        if (trimmed != null) path = trimmed;
      }
    }
    return MarkerTrajectory(path, at, duration);
  }
}

List<RoadPoint>? _trimFrom(RoadPoint from, List<RoadPoint> path) {
  var closest = double.infinity;
  RoadPoint? projection;
  var segment = 0;
  final scale = math.cos(from.lat * math.pi / 180);
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1];
    final b = path[i];
    final dx = (b.lng - a.lng) * scale;
    final dy = b.lat - a.lat;
    final length = dx * dx + dy * dy;
    final t = length == 0
        ? 0.0
        : (((from.lng - a.lng) * scale * dx + (from.lat - a.lat) * dy) / length).clamp(0.0, 1.0);
    final point = lerpCoordinate(a, b, t);
    final distance = roadDistance(from, point);
    if (distance < closest) {
      closest = distance;
      projection = point;
      segment = i;
    }
  }
  if (projection == null || closest > 5) return null;
  return [from, if (closest > .01) projection, ...path.skip(segment)];
}
