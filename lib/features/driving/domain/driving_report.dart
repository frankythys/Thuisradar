import '../../location/domain/timeline.dart';
import '../../location/domain/track_point.dart';

DateTime drivingWeekStart(DateTime date) => DateTime(date.year, date.month, date.day - date.weekday + 1);

DateTime drivingWeekEnd(DateTime start) => DateTime(start.year, start.month, start.day + 7);

class DrivingTrip {
  const DrivingTrip({
    required this.start,
    required this.end,
    required this.kilometers,
    required this.topSpeed,
  });

  final DateTime start;
  final DateTime end;
  final double kilometers;
  final double topSpeed;
}

class DrivingReport {
  const DrivingReport(this.trips, {required this.hasHistory});

  final List<DrivingTrip> trips;
  final bool hasHistory;
  double get kilometers => trips.fold(0, (sum, trip) => sum + trip.kilometers);
  double? get topSpeed =>
      trips.isEmpty ? null : trips.map((trip) => trip.topSpeed).reduce((a, b) => a > b ? a : b);
}

/// Geschatte ritten: minstens twee snelheidsmetingen vanaf 25 km/u in een
/// verplaatsing. GPS bepaalt niet of iemand bestuurder of passagier is.
/// Gaten van meer dan vijf minuten worden nooit als gereden afstand opgeteld.
DrivingReport buildDrivingReport(List<TrackPoint> points, DateTime week) {
  final start = drivingWeekStart(week);
  final end = drivingWeekEnd(start);
  final sorted = points.where((p) => !p.recordedAt.isBefore(start) && p.recordedAt.isBefore(end)).toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final segments = <List<TrackPoint>>[];
  for (final point in sorted) {
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      continue;
    }
    if (segments.isEmpty ||
        point.recordedAt.difference(segments.last.last.recordedAt) > const Duration(minutes: 5)) {
      segments.add([]);
    }
    if (segments.last.isEmpty || point.recordedAt.isAfter(segments.last.last.recordedAt)) {
      segments.last.add(point);
    }
  }
  final trips = <DrivingTrip>[];
  for (final segment in segments) {
    for (final entry in buildTimeline(segment).where((e) => e.kind == TimelineKind.move)) {
      final speeds = segment
          .where((p) => !p.recordedAt.isBefore(entry.start) && !p.recordedAt.isAfter(entry.end))
          .map((p) => p.speedMps)
          .whereType<double>()
          .where((s) => s.isFinite && s >= 0 && s <= 70)
          .map((s) => s * 3.6)
          .toList();
      final meters = entry.distanceMeters ?? 0;
      final seconds = entry.duration.inSeconds;
      if (speeds.where((s) => s >= 25).length < 2 || meters < 100 || seconds <= 0 || meters / seconds > 70) {
        continue;
      }
      trips.add(
        DrivingTrip(
          start: entry.start,
          end: entry.end,
          kilometers: meters / 1000,
          topSpeed: speeds.reduce((a, b) => a > b ? a : b),
        ),
      );
    }
  }
  return DrivingReport(List.unmodifiable(trips), hasHistory: segments.isNotEmpty);
}
