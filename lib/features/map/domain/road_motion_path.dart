import 'dart:collection';
import 'dart:math' as math;

import '../../location/domain/motion_filter.dart';
import 'road_matching.dart';

typedef _Node = ({int way, RoadPoint point});
typedef _Edge = ({_Node node, double meters});

double roadDistance(RoadPoint a, RoadPoint b) => distanceMeters(a.lat, a.lng, b.lat, b.lng);

/// Korte verbinding over de beschikbare wegvorm. Kruisende wegen zijn alleen
/// verbonden als OSM een gedeelde knoop kent; eenrichtingsverkeer blijft gelden.
/// Geen verbinding of een onwaarschijnlijke omweg => geen geschatte route.
List<RoadPoint>? roadMotionPath(RoadPoint from, RoadPoint to, RoadNetwork roads) {
  final direct = roadDistance(from, to);
  if (direct < .1) return [from, to];
  final limit = math.min(2000.0, direct * 2.5 + 30);
  final graph = <_Node, List<_Edge>>{};
  final junctions = <RoadPoint, Set<_Node>>{};
  final start = (way: -1, point: from);
  final end = (way: -2, point: to);
  void edge(_Node a, _Node b) =>
      graph.putIfAbsent(a, () => []).add((node: b, meters: roadDistance(a.point, b.point)));
  for (final road in roads.segments) {
    if (math.min(roadDistance(from, road.a), roadDistance(from, road.b)) >
        limit + roadDistance(road.a, road.b)) {
      continue;
    }
    final points = <({double t, RoadPoint point})>[(t: 0, point: road.a), (t: 1, point: road.b)];
    for (final endpoint in [start, end]) {
      final projection = _project(endpoint.point, road);
      if (roadDistance(endpoint.point, projection.point) > 1) continue;
      points.add(projection);
      final node = (way: road.wayId, point: projection.point);
      if (endpoint == start) {
        edge(start, node);
      } else {
        edge(node, end);
      }
    }
    points.sort((a, b) => a.t.compareTo(b.t));
    for (var i = 1; i < points.length; i++) {
      final a = (way: road.wayId, point: points[i - 1].point);
      final b = (way: road.wayId, point: points[i].point);
      edge(a, b);
      if (!road.oneWay) edge(b, a);
    }
    for (final point in [road.a, road.b]) {
      junctions.putIfAbsent(point, () => {}).add((way: road.wayId, point: point));
    }
  }
  for (final nodes in junctions.values) {
    for (final a in nodes) {
      for (final b in nodes) {
        if (a != b && (roads.connections[a.way]?.contains(b.way) ?? false)) edge(a, b);
      }
    }
  }
  final queue = SplayTreeMap<double, List<_Node>>()..[0] = [start];
  final distances = <_Node, double>{start: 0};
  final previous = <_Node, _Node>{};
  while (queue.isNotEmpty) {
    final meters = queue.firstKey()!;
    final bucket = queue[meters]!;
    final node = bucket.removeLast();
    if (bucket.isEmpty) queue.remove(meters);
    if (meters > limit) return null;
    if (meters != distances[node]) continue;
    if (node == end) {
      final result = <RoadPoint>[to];
      var cursor = end;
      while (cursor != start) {
        cursor = previous[cursor]!;
        if (roadDistance(cursor.point, result.last) > .01) result.add(cursor.point);
      }
      return result.reversed.toList();
    }
    for (final next in graph[node] ?? const <_Edge>[]) {
      final total = meters + next.meters;
      if (total >= (distances[next.node] ?? double.infinity) || total > limit) continue;
      distances[next.node] = total;
      previous[next.node] = node;
      queue.putIfAbsent(total, () => []).add(next.node);
    }
  }
  return null;
}

({double t, RoadPoint point}) _project(RoadPoint point, RoadSegment road) {
  final scale = math.cos(point.lat * math.pi / 180);
  final dx = (road.b.lng - road.a.lng) * scale;
  final dy = road.b.lat - road.a.lat;
  final length = dx * dx + dy * dy;
  final t = length == 0
      ? 0.0
      : (((point.lng - road.a.lng) * scale * dx + (point.lat - road.a.lat) * dy) / length).clamp(0.0, 1.0);
  return (
    t: t,
    point: t < 1e-9
        ? road.a
        : t > 1 - 1e-9
        ? road.b
        : (lat: road.a.lat + dy * t, lng: road.a.lng + (road.b.lng - road.a.lng) * t),
  );
}
