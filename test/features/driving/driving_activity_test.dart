import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/driving/presentation/driving_summary.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

void main() {
  final day = DateTime(2026, 1, 2);

  /// Een meting [minutes] na middernacht, [km] van het vertrekpunt (noordwaarts).
  TrackPoint p(int minutes, double km) => TrackPoint(
    latitude: 51 + km * 0.009,
    longitude: 3,
    recordedAt: day.add(Duration(minutes: minutes)),
  );

  TimelineEntry stop(int from, int to, {String? placeName}) => TimelineEntry(
    kind: TimelineKind.stop,
    start: day.add(Duration(minutes: from)),
    end: day.add(Duration(minutes: to)),
    latitude: 51,
    longitude: 3,
    placeName: placeName,
  );

  test('een verblijf uit de tijdlijn wordt een verblijf met de plaatsnaam', () {
    final activities = buildDayActivities([stop(60, 540, placeName: 'Werk')], const []);

    expect(activities, hasLength(1));
    expect(activities.single.kind, DrivingActivityKind.stay);
    expect(activities.single.placeName, 'Werk');
    expect(activities.single.duration, const Duration(hours: 8));
  });

  test('een rit loopt van de eerste tot de laatste rijdende meting', () {
    final activities = buildDayActivities(const [], [p(0, 0), p(1, 0.5), p(2, 1), p(3, 1.5)]);

    expect(activities, hasLength(1));
    final trip = activities.single;
    expect(trip.kind, DrivingActivityKind.trip);
    expect(trip.start, day);
    expect(trip.end, day.add(const Duration(minutes: 3)));
    expect(trip.fromLatitude, 51);
    expect(trip.latitude, closeTo(51.0135, 0.0001));
    expect(trip.distanceMeters, closeTo(1500, 60));
  });

  test('een korte stilstand (rood licht) blijft binnen de rit', () {
    final tracks = buildTripTracks([p(0, 0), p(1, 0.5), p(4, 0.5), p(5, 1)]);

    expect(tracks, hasLength(1));
    expect(tracks.single, hasLength(4));
  });

  test('lang stilstaan splitst de rit in twee ritten', () {
    final tracks = buildTripTracks([p(0, 0), p(1, 0.5), p(7, 0.5), p(8, 1)]);

    expect(tracks, hasLength(2));
    expect(tracks.first, hasLength(2));
    expect(tracks.last, hasLength(2));
  });

  test('een gat in de metingen splitst de rit in twee ritten', () {
    final tracks = buildTripTracks([p(0, 0), p(1, 0.5), p(20, 1), p(21, 1.5)]);

    expect(tracks, hasLength(2));
  });

  test('wat niet beweegt is geen rit', () {
    final activities = buildDayActivities(const [], [p(0, 0), p(1, 0.02), p(2, 0.04)]);

    expect(activities, isEmpty);
  });

  test('ritten en verblijven staan chronologisch', () {
    final activities = buildDayActivities([stop(60, 120)], [p(0, 0), p(1, 0.5)]);

    expect(activities.map((a) => a.kind), [
      DrivingActivityKind.trip,
      DrivingActivityKind.stay,
    ]);
  });

  test('het routespoor van een rit blijft binnen vertrek en aankomst', () {
    final activities = buildDayActivities(const [], [p(0, 0), p(1, 0.5), p(2, 1)]);
    final points = [p(-30, 0), p(0, 0), p(1, 0.5), p(2, 1), p(30, 1)];

    final track = activityTrack(activities.single, points);

    expect(track, hasLength(3));
    expect(track.first.recordedAt, day);
    expect(track.last.recordedAt, day.add(const Duration(minutes: 2)));
  });

  test('afstand en duur krijgen een leesbare notatie', () {
    expect(drivingDistance(79), '79 m');
    expect(drivingDistance(13200), '13,2 km');
    expect(drivingDistance(null), 'afstand onbekend');
    expect(drivingDuration(const Duration(hours: 7, minutes: 56)), '7 uur 56 min');
    expect(drivingDuration(const Duration(minutes: 45)), '45 min');
  });

  test('het daglabel toont Vandaag, Gisteren of de datum', () {
    final now = DateTime(2026, 1, 2, 18);
    expect(drivingDayLabel(DateTime(2026, 1, 2), now: now), 'Vandaag');
    expect(drivingDayLabel(DateTime(2026, 1, 1), now: now), 'Gisteren');
    expect(drivingDayLabel(DateTime(2025, 12, 29), now: now), 'ma 29/12');
  });
}
