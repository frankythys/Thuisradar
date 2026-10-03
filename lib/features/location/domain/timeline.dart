import 'dart:math' as math;

import 'track_point.dart';

enum TimelineKind { stop, move }

/// Eén blok in de locatietijdlijn: ofwel stilstaan op één plek (`stop`),
/// ofwel een verplaatsing ertussen (`move`).
class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.start,
    required this.end,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.placeName,
  });

  final TimelineKind kind;
  final DateTime start;
  final DateTime end;

  /// Representatief punt: het middelpunt van een stop, of het aankomstpunt van een move.
  final double latitude;
  final double longitude;

  /// Afgelegde afstand in meter (enkel voor een `move`).
  final double? distanceMeters;

  /// Naam van de plek bij een stop. Wordt in Fase D ingevuld vanuit geofences;
  /// nu altijd null, zodat het scherm dan niet herschreven hoeft te worden.
  final String? placeName;

  Duration get duration => end.difference(start);
}

const _defaultStopRadiusMeters = 100.0;
const _defaultMinStop = Duration(minutes: 5);

/// Bouwt een tijdlijn uit ruwe geschiedenispunten: opeenvolgende punten binnen
/// [stopRadiusMeters] van elkaar vormen een cluster; duurt een cluster minstens
/// [minStop], dan is het een stop, anders telt het mee als verplaatsing. Een
/// verplaatsing overbrugt het gat tussen twee stops (vertrek → aankomst).
///
/// Puur: geen Flutter of Supabase. Resultaat is chronologisch (oudste eerst).
List<TimelineEntry> buildTimeline(
  List<TrackPoint> points, {
  double stopRadiusMeters = _defaultStopRadiusMeters,
  Duration minStop = _defaultMinStop,
}) {
  if (points.isEmpty) return const [];

  final sorted = [...points]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  final clusters = <_Cluster>[];
  for (final point in sorted) {
    final current = clusters.isEmpty ? null : clusters.last;
    if (current == null ||
        _distanceMeters(current.centerLat, current.centerLng, point.latitude, point.longitude) >
            stopRadiusMeters) {
      clusters.add(_Cluster(point));
    } else {
      current.add(point);
    }
  }

  final entries = <TimelineEntry>[];
  final pending = <_Cluster>[];
  _Cluster? prevStop;

  void emitMove(_Cluster? nextStop) {
    final fromStop = prevStop;
    if (pending.isEmpty && (fromStop == null || nextStop == null)) return;

    final movePoints = <TrackPoint>[
      if (fromStop != null) fromStop.last,
      for (final cluster in pending) ...cluster.points,
      if (nextStop != null) nextStop.first,
    ];
    if (movePoints.length < 2) {
      pending.clear();
      return;
    }

    var distance = 0.0;
    for (var i = 1; i < movePoints.length; i++) {
      distance += _distanceMeters(
        movePoints[i - 1].latitude,
        movePoints[i - 1].longitude,
        movePoints[i].latitude,
        movePoints[i].longitude,
      );
    }

    // Vertrek = eerste bewegende punt (of het vertrek uit de vorige stop).
    final start = pending.isEmpty ? movePoints.first.recordedAt : pending.first.first.recordedAt;
    final end = nextStop != null ? nextStop.first.recordedAt : pending.last.last.recordedAt;
    final arrival = nextStop?.first ?? pending.last.last;

    entries.add(
      TimelineEntry(
        kind: TimelineKind.move,
        start: start,
        end: end,
        latitude: arrival.latitude,
        longitude: arrival.longitude,
        distanceMeters: distance,
      ),
    );
    pending.clear();
  }

  for (final cluster in clusters) {
    if (cluster.duration >= minStop) {
      emitMove(cluster);
      entries.add(
        TimelineEntry(
          kind: TimelineKind.stop,
          start: cluster.first.recordedAt,
          end: cluster.last.recordedAt,
          latitude: cluster.centerLat,
          longitude: cluster.centerLng,
        ),
      );
      prevStop = cluster;
    } else {
      pending.add(cluster);
    }
  }
  emitMove(null);

  return entries;
}

class _Cluster {
  _Cluster(TrackPoint first) : points = [first];

  final List<TrackPoint> points;

  void add(TrackPoint p) => points.add(p);

  TrackPoint get first => points.first;
  TrackPoint get last => points.last;
  Duration get duration => last.recordedAt.difference(first.recordedAt);

  double get centerLat => points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
  double get centerLng => points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
}

/// Afstand in meter tussen twee punten (haversine).
double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRad(double degrees) => degrees * math.pi / 180;
