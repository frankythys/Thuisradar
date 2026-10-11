import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/geofencing/application/geofence_reporter.dart';
import 'package:thuisradar/features/geofencing/data/geofence_event_api.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_report.dart';

import 'features/geofencing/fake_geofence_store.dart';

import 'package:mocktail/mocktail.dart';

class Api extends Mock implements GeofenceEventApi {}

void main() {
  final t = DateTime(2026, 10, 11, 10);
  TrackPoint p(int minute, double lat) => TrackPoint(
    latitude: lat,
    longitude: 4,
    recordedAt: t.add(Duration(minutes: minute)),
    speedMps: 15,
  );
  test('een echte rondrit van 4,4 km blijft behouden', () {
    final points = [p(0, 52), p(1, 52.01), p(2, 52.02), p(3, 52.01), p(4, 52)];
    expect(trackMeters(points), greaterThan(4400));
    expect(buildDayActivities(buildTimeline(points), points).single.distanceMeters, greaterThan(4400));
  });
  test('rondrit tussen twee verblijven op dezelfde plek blijft behouden', () {
    final points = [p(0, 52), p(5, 52), p(6, 52.01), p(7, 52.02), p(8, 52.01), p(9, 52), p(14, 52)];
    final entries = buildTimeline(points);
    expect(entries.where((e) => e.kind == TimelineKind.stop), hasLength(2));
    expect(
      buildDayActivities(entries, points).where((a) => a.kind == DrivingActivityKind.trip),
      hasLength(1),
    );
  });
  test('GPS-sprong telt niet mee in de ritafstand', () {
    final points = [p(0, 52), p(1, 52.01), p(2, 53), p(3, 52.02)];
    final activity = buildDayActivities(buildTimeline(points), points).single;
    expect(activity.distanceMeters, lessThan(2300));
    expect(activity.distanceMeters, closeTo(trackMeters(activityTrack(activity, points)), 0.01));
    expect(trackMeters(activityTrack(activity, points)), lessThan(2300));
  });
  test('gelijktijdige flush behoudt een nieuwe niet-verstuurde melding', () async {
    final api = Api();
    final store = FakeGeofenceStore();
    final gate = Completer<String>();
    final entered = Completer<void>();
    final a = GeofenceReport(placeId: 'A', type: GeofenceReportType.arrival, at: t);
    final b = GeofenceReport(placeId: 'B', type: GeofenceReportType.departure, at: t);
    store.queue = [a];
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: a,
      ),
    ).thenAnswer((_) {
      if (!entered.isCompleted) entered.complete();
      return gate.future;
    });
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: b,
      ),
    ).thenThrow(const GeofenceSendException('offline', retry: true));
    final old = GeofenceReporter(store: store, api: api, clock: () => t).flush();
    await entered.future;
    // A second callback succeeds for A but cannot send the new B.
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: a,
      ),
    ).thenAnswer((_) async => 'recorded');
    await GeofenceReporter(store: store, api: api, clock: () => t).report([b]);
    expect(store.queue, [b]);
    gate.complete('recorded');
    await old;
    expect(store.queue, [b]);
  });
}
