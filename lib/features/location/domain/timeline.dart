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

/// Binnen welke straal rond een punt tellen metingen als "op dezelfde plek"?
const kStopRadiusMeters = 100.0;

/// Hoe lang moet het toestel op dezelfde plek blijven voor het een stop is?
const kMinStop = Duration(minutes: 5);

/// Bouwt een tijdlijn uit ruwe geschiedenispunten: opeenvolgende punten binnen
/// [stopRadiusMeters] van elkaar vormen een cluster; duurt een cluster minstens
/// [minStop], dan is het een stop, anders telt het mee als verplaatsing. Een
/// verplaatsing overbrugt het gat tussen twee stops (vertrek → aankomst).
///
/// Puur: geen Flutter of Supabase. Resultaat is chronologisch (oudste eerst).
List<TimelineEntry> buildTimeline(
  List<TrackPoint> points, {
  double stopRadiusMeters = kStopRadiusMeters,
  Duration minStop = kMinStop,
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

  return _mergeSamePlaceStops(entries, stopRadiusMeters);
}

/// Een enkele GPS-uitschieter midden in een lange stop maakt soms twee losse
/// clusters op dezelfde plek, met een schijnverplaatsing ertussen. Liggen twee
/// opeenvolgende stops binnen [stopRadiusMeters] van elkaar, dan hoorden ze bij
/// elkaar: voeg ze samen en laat de verplaatsing ertussen vallen.
List<TimelineEntry> _mergeSamePlaceStops(List<TimelineEntry> entries, double stopRadiusMeters) {
  final merged = <TimelineEntry>[];
  TimelineEntry? pendingMove;
  for (final entry in entries) {
    if (entry.kind == TimelineKind.move) {
      pendingMove = entry;
      continue;
    }
    final last = merged.isEmpty ? null : merged.last;
    if (last != null &&
        last.kind == TimelineKind.stop &&
        _distanceMeters(last.latitude, last.longitude, entry.latitude, entry.longitude) <= stopRadiusMeters) {
      merged[merged.length - 1] = TimelineEntry(
        kind: TimelineKind.stop,
        start: last.start,
        end: entry.end,
        latitude: last.latitude,
        longitude: last.longitude,
        placeName: last.placeName ?? entry.placeName,
      );
      pendingMove = null;
    } else {
      if (pendingMove != null) {
        merged.add(pendingMove);
        pendingMove = null;
      }
      merged.add(entry);
    }
  }
  if (pendingMove != null) merged.add(pendingMove);
  return merged;
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
