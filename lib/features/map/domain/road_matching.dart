import 'dart:math' as math;

import '../../location/domain/member_location.dart';
import '../../location/domain/motion_filter.dart';

typedef RoadPoint = ({double lat, double lng});

class RoadSegment {
  const RoadSegment(this.wayId, this.a, this.b, {this.oneWay = false});
  final int wayId;
  final RoadPoint a;
  final RoadPoint b;
  final bool oneWay;
}

class RoadNetwork {
  const RoadNetwork(this.segments, this.connections);
  final List<RoadSegment> segments;
  final Map<int, Set<int>> connections;

  factory RoadNetwork.fromOverpass(Map<String, dynamic> json) {
    final segments = <RoadSegment>[];
    final nodeWays = <int, Set<int>>{};
    for (final element in json['elements'] as List? ?? const []) {
      if (element is! Map || element['type'] != 'way') continue;
      final tags = element['tags'] as Map? ?? const {};
      if (!carHighways.contains(tags['highway']) ||
          ['no', 'private'].contains(
            tags['motor_vehicle'] ?? tags['vehicle'] ?? tags['access'],
          )) {
        continue;
      }
      final id = element['id'];
      final geometry = element['geometry'];
      final nodes = element['nodes'];
      if (id is! int ||
          geometry is! List ||
          nodes is! List ||
          geometry.length != nodes.length) {
        continue;
      }
      final points = <RoadPoint>[];
      for (var i = 0; i < geometry.length; i++) {
        final point = geometry[i];
        if (point is! Map || point['lat'] is! num || point['lon'] is! num) {
          continue;
        }
        points.add((
          lat: (point['lat'] as num).toDouble(),
          lng: (point['lon'] as num).toDouble(),
        ));
        if (nodes[i] is int) {
          nodeWays.putIfAbsent(nodes[i] as int, () => {}).add(id);
        }
      }
      // Een ontbrekend geometriepunt mag geen fictieve verbindingslijn maken.
      if (points.length != geometry.length) continue;
      final reversed = tags['oneway'] == '-1';
      final ordered = reversed ? points.reversed.toList() : points;
      final oneWay =
          reversed ||
          ['yes', '1', 'true'].contains(tags['oneway']) ||
          tags['junction'] == 'roundabout';
      for (var i = 1; i < ordered.length; i++) {
        segments.add(
          RoadSegment(id, ordered[i - 1], ordered[i], oneWay: oneWay),
        );
      }
    }
    final connections = <int, Set<int>>{};
    for (final ways in nodeWays.values) {
      for (final way in ways) {
        connections.putIfAbsent(way, () => {}).addAll(ways);
      }
    }
    return RoadNetwork(segments, connections);
  }
}

const carHighways = {
  'motorway',
  'motorway_link',
  'trunk',
  'trunk_link',
  'primary',
  'primary_link',
  'secondary',
  'secondary_link',
  'tertiary',
  'tertiary_link',
  'unclassified',
  'residential',
  'living_street',
  'service',
};

class _Candidate {
  const _Candidate(this.point, this.way, this.cost);
  final RoadPoint point;
  final int way;
  final double cost;
}

/// Conservatieve matching van een reeks metingen, met richting, OSM-verbindingen
/// en alternatieve wegen. Geen betrouwbare, onderscheidbare match => ruwe GPS.
RoadPoint? matchRoadTrace(List<MemberLocation> trace, RoadNetwork roads) {
  if (trace.length < 3 || !trace.any((p) => (p.speedMps ?? 0) >= 5)) {
    return null;
  }
  List<_Candidate> previous = [];
  List<double> costs = [];
  for (var i = 0; i < trace.length; i++) {
    final fix = trace[i];
    final accuracy = fix.accuracyMeters;
    if (accuracy == null ||
        !accuracy.isFinite ||
        accuracy <= 0 ||
        accuracy > 50) {
      return null;
    }
    final sigma = accuracy.clamp(5.0, 25.0);
    final scaleX = 111320 * math.cos(fix.latitude * math.pi / 180);
    const scaleY = 111320.0;
    final last = i > 0 ? trace[i - 1] : null;
    final dx = last == null ? 0.0 : (fix.longitude - last.longitude) * scaleX;
    final dy = last == null ? 0.0 : (fix.latitude - last.latitude) * scaleY;
    final movement = math.sqrt(dx * dx + dy * dy);
    final candidates = <_Candidate>[];
    for (final road in roads.segments) {
      final ax = (road.a.lng - fix.longitude) * scaleX;
      final ay = (road.a.lat - fix.latitude) * scaleY;
      final vx = (road.b.lng - road.a.lng) * scaleX;
      final vy = (road.b.lat - road.a.lat) * scaleY;
      final length2 = vx * vx + vy * vy;
      if (length2 < 1) continue;
      final t = (-(ax * vx + ay * vy) / length2).clamp(0.0, 1.0);
      final x = ax + t * vx;
      final y = ay + t * vy;
      final distance2 = x * x + y * y;
      if (distance2 > math.pow((accuracy * 2).clamp(15.0, 50.0), 2)) continue;
      var cost = distance2 / (2 * sigma * sigma);
      if (movement >= 20) {
        final cosine = (dx * vx + dy * vy) / (movement * math.sqrt(length2));
        if (road.oneWay && cosine < -0.2) continue;
        cost += 3 * (1 - (road.oneWay ? cosine : cosine.abs()));
      }
      candidates.add(
        _Candidate(
          (lat: fix.latitude + y / scaleY, lng: fix.longitude + x / scaleX),
          road.wayId,
          cost,
        ),
      );
    }
    candidates.sort((a, b) => a.cost.compareTo(b.cost));
    // Eén kandidaat per weg; aangrenzende segmenten zijn geen alternatieve weg.
    final unique = <_Candidate>[];
    final seen = <int>{};
    for (final candidate in candidates) {
      if (seen.add(candidate.way)) unique.add(candidate);
      if (unique.length == 6) break;
    }
    if (unique.isEmpty) return null;
    final nextCosts = <double>[];
    for (final candidate in unique) {
      var best = double.infinity;
      if (previous.isEmpty) best = 0;
      for (var j = 0; j < previous.length; j++) {
        final prior = previous[j];
        final matchedDistance = distanceMeters(
          prior.point.lat,
          prior.point.lng,
          candidate.point.lat,
          candidate.point.lng,
        );
        final connected =
            prior.way == candidate.way ||
            (roads.connections[prior.way]?.contains(candidate.way) ?? false);
        final transition =
            (matchedDistance - movement).abs() / math.max(10, sigma) +
            (connected ? 0 : 4);
        best = math.min(best, costs[j] + transition);
      }
      nextCosts.add(best + candidate.cost);
    }
    final minimum = nextCosts.reduce(math.min);
    costs = nextCosts.map((cost) => cost - minimum).toList();
    previous = unique;
  }
  final ranking = List.generate(previous.length, (i) => i)
    ..sort((a, b) => costs[a].compareTo(costs[b]));
  if (ranking.length > 1 && costs[ranking[1]] - costs[ranking.first] < 2) {
    return null;
  }
  return previous[ranking.first].point;
}
