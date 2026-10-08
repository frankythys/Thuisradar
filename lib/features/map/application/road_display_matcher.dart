import 'package:flutter/foundation.dart';

import '../../location/domain/member_location.dart';
import '../../location/domain/trip_status.dart';
import '../data/road_network_source.dart';
import '../domain/member_on_map.dart';
import '../domain/road_matching.dart';

/// Houdt alleen recente ruwe punten bij; database en ritgeschiedenis worden
/// nooit overschreven met een geschatte wegpositie.
class RoadDisplayMatcher {
  RoadDisplayMatcher(this.source);
  final RoadNetworkSource source;
  final _traces = <String, List<MemberLocation>>{};
  final _matches = <String, ({MemberLocation raw, RoadPoint point})>{};
  bool _disposed = false;

  void dispose() => _disposed = true;

  List<MemberOnMap> display(List<MemberOnMap> members, DateTime now) => [
    for (final member in members) _display(member, now),
  ];

  MemberOnMap _display(MemberOnMap member, DateTime now) {
    final fix = member.location;
    final match = _matches[member.member.userId];
    if (fix == null ||
        match == null ||
        fix.updatedAt != match.raw.updatedAt ||
        fix.latitude != match.raw.latitude ||
        fix.longitude != match.raw.longitude ||
        TripStatus.at(fix, now).state != TripState.moving) {
      return member;
    }
    return MemberOnMap(
      member: member.member,
      location: fix.copyWith(
        latitude: match.point.lat,
        longitude: match.point.lng,
      ),
    );
  }

  Future<void> update(List<MemberOnMap> members, DateTime now) async {
    final present = members.map((member) => member.member.userId).toSet();
    _traces.removeWhere((id, _) => !present.contains(id));
    _matches.removeWhere((id, _) => !present.contains(id));
    // Verzoeken blijven serieel om de gedeelde wegdataserver niet te belasten.
    for (final member in members) {
      if (_disposed) return;
      final fix = member.location;
      final id = member.member.userId;
      if (fix == null ||
          TripStatus.at(fix, now).state != TripState.moving ||
          fix.accuracyMeters == null ||
          !fix.accuracyMeters!.isFinite ||
          fix.accuracyMeters! <= 0 ||
          fix.accuracyMeters! > 50) {
        _traces.remove(id);
        _matches.remove(id);
        continue;
      }
      final trace = _traces.putIfAbsent(id, () => []);
      if (trace.isNotEmpty) {
        if (!fix.updatedAt.isAfter(trace.last.updatedAt)) continue;
        if (fix.updatedAt.difference(trace.last.updatedAt) >
            const Duration(seconds: 30)) {
          trace.clear();
        }
      }
      trace.add(fix);
      trace.removeWhere(
        (point) =>
            fix.updatedAt.difference(point.updatedAt) >
            const Duration(seconds: 60),
      );
      if (trace.length > 8) trace.removeRange(0, trace.length - 8);
      _matches.remove(id);
      if (trace.length < 3 ||
          !trace.any((point) => (point.speedMps ?? 0) >= 5)) {
        continue;
      }
      final snapshot = List<MemberLocation>.of(trace);
      final roads = await source.forFix(fix, now);
      if (_disposed ||
          !identical(_traces[id], trace) ||
          trace.last.updatedAt != fix.updatedAt ||
          roads == null) {
        continue;
      }
      final point = await compute(_matchTrace, (
        trace: snapshot,
        roads: roads,
      ), debugLabel: 'roads-map-matching');
      // Tijdens de berekening kan een stop of nieuw GPS-punt binnenkomen.
      if (_disposed ||
          !identical(_traces[id], trace) ||
          trace.last.updatedAt != fix.updatedAt) {
        continue;
      }
      if (point != null) _matches[id] = (raw: fix, point: point);
    }
  }
}

RoadPoint? _matchTrace(
  ({List<MemberLocation> trace, RoadNetwork roads}) input,
) => matchRoadTrace(input.trace, input.roads);
