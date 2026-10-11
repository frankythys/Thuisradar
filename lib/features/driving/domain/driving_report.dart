import '../../location/domain/timeline.dart';
import '../../location/domain/track_point.dart';
import 'driving_activity.dart';
import '../../location/domain/travel_mode.dart';

DateTime drivingWeekStart(DateTime date) => DateTime(date.year, date.month, date.day - date.weekday + 1);

DateTime drivingWeekEnd(DateTime start) => DateTime(start.year, start.month, start.day + 7);

class DrivingTrip {
  const DrivingTrip({
    required this.start,
    required this.end,
    required this.kilometers,
    required this.topSpeed,
    this.mode = TravelMode.car,
  });

  final DateTime start;
  final DateTime end;
  final double kilometers;

  /// Hoogste gemeten snelheid in km/u (bij wandelen: het gemiddelde als de
  /// GPS geen snelheid gaf).
  final double topSpeed;
  final TravelMode mode;

  Duration get duration => end.difference(start);
}

/// Alle verplaatsingen van één gezinslid in een week, per vervoermiddel.
class DrivingReport {
  DrivingReport(this.all, {required this.hasHistory});

  /// Alle verplaatsingen, chronologisch: ritten, fietstochten en wandelingen.
  final List<DrivingTrip> all;
  final bool hasHistory;

  /// Enkel de autoritten.
  List<DrivingTrip> get trips => of(TravelMode.car);

  late final Map<TravelMode, List<DrivingTrip>> _byMode = {
    for (final mode in TravelMode.values) mode: List.unmodifiable(all.where((trip) => trip.mode == mode)),
  };

  /// De verplaatsingen met [mode]; zonder [mode] allemaal.
  List<DrivingTrip> of(TravelMode? mode) => mode == null ? all : _byMode[mode]!;

  /// Kilometers met de auto.
  double get kilometers => kilometersOf(TravelMode.car);

  double kilometersOf(TravelMode? mode) => of(mode).fold(0, (sum, trip) => sum + trip.kilometers);

  Duration durationOf(TravelMode? mode) => of(mode).fold(Duration.zero, (sum, trip) => sum + trip.duration);

  /// Hoogste snelheid met de auto.
  double? get topSpeed => topSpeedOf(TravelMode.car);

  double? topSpeedOf(TravelMode? mode) {
    final trips = of(mode);
    return trips.isEmpty ? null : trips.map((trip) => trip.topSpeed).reduce((a, b) => a > b ? a : b);
  }

  /// Gemiddelde snelheid in km/u over alle verplaatsingen met [mode].
  double? averageKmhOf(TravelMode? mode) {
    final hours = durationOf(mode).inSeconds / 3600;
    return hours <= 0 ? null : kilometersOf(mode) / hours;
  }
}

/// Geschatte verplaatsingen, elk met een vervoermiddel volgens
/// [classifyTravel]. GPS bepaalt niet of iemand bestuurder of passagier is.
/// Gaten van meer dan vijf minuten worden nooit als afstand opgeteld.
DrivingReport buildDrivingReport(List<TrackPoint> points, DateTime week) {
  final start = drivingWeekStart(week);
  final end = drivingWeekEnd(start);
  final sorted = points.where((p) => !p.recordedAt.isBefore(start) && p.recordedAt.isBefore(end)).toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final segments = <List<TrackPoint>>[];
  for (final point in withoutSpikes(sorted)) {
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
    // Dezelfde verplaatsingen als op de dagkaarten, zodat week en dag kloppen.
    final moves = buildDayActivities(
      buildTimeline(segment),
      segment,
    ).where((activity) => activity.kind == DrivingActivityKind.trip);
    for (final move in moves) {
      final speeds = segment
          .where((p) => !p.recordedAt.isBefore(move.start) && !p.recordedAt.isAfter(move.end))
          .map((p) => p.speedMps)
          .whereType<double>()
          .where((s) => s.isFinite && s >= 0 && s <= 70)
          .map((s) => s * 3.6)
          .toList();
      final meters = move.distanceMeters ?? 0;
      final seconds = move.duration.inSeconds;
      if (seconds <= 0 || meters / seconds > 70) continue;
      // Een autorit telt pas in het weekrapport met gemeten snelheid: snel
      // gemiddeld zonder één snelheidsmeting kan ook een meetgat zijn.
      if (move.mode == TravelMode.car && speeds.where((s) => s >= kCarSpeedKmh).length < 2) continue;
      trips.add(
        DrivingTrip(
          start: move.start,
          end: move.end,
          kilometers: meters / 1000,
          topSpeed: speeds.isEmpty ? meters / seconds * 3.6 : speeds.reduce((a, b) => a > b ? a : b),
          mode: move.mode,
        ),
      );
    }
  }
  return DrivingReport(List.unmodifiable(trips), hasHistory: segments.isNotEmpty);
}
