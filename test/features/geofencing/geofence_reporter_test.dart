import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/geofencing/application/geofence_reporter.dart';
import 'package:thuisradar/features/geofencing/data/geofence_event_api.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_report.dart';

import 'fake_geofence_store.dart';

class _MockApi extends Mock implements GeofenceEventApi {}

void main() {
  late _MockApi api;
  late FakeGeofenceStore store;
  var now = DateTime(2026, 10, 8, 17, 40);

  setUpAll(() {
    registerFallbackValue(GeofenceReport(placeId: '', type: GeofenceReportType.arrival, at: DateTime(2026)));
  });

  setUp(() {
    api = _MockApi();
    store = FakeGeofenceStore();
    now = DateTime(2026, 10, 8, 17, 40);
  });

  GeofenceReporter reporter() => GeofenceReporter(store: store, api: api, clock: () => now);

  GeofenceReport arrivalHome() =>
      GeofenceReport(placeId: 'thuis', type: GeofenceReportType.arrival, at: DateTime(2026, 10, 8, 17, 40));

  test('thuis om 17:40: aankomst gaat meteen naar de server', () async {
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: any(named: 'report'),
      ),
    ).thenAnswer((_) async => 'recorded');

    expect(await reporter().report([arrivalHome()]), ['recorded']);
    final sent =
        verify(
              () => api.send(
                deviceKey: 'toestel-sleutel',
                report: captureAny(named: 'report'),
              ),
            ).captured.single
            as GeofenceReport;
    expect(sent.at, DateTime(2026, 10, 8, 17, 40));
    expect(store.queue, isEmpty);
  });

  test('geen netwerk bij aankomst (wifi wisselt): later alsnog met tijdstip 17:40', () async {
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: any(named: 'report'),
      ),
    ).thenThrow(const GeofenceSendException('geen netwerk', retry: true));
    await reporter().report([arrivalHome()]);
    expect(store.queue.single.placeId, 'thuis');

    // 17:45: de app opent (of een volgende zone-overgang) → wachtrij leegmaken.
    now = DateTime(2026, 10, 8, 17, 45);
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: any(named: 'report'),
      ),
    ).thenAnswer((_) async => 'recorded');
    expect(await reporter().flush(), ['recorded']);
    final sent =
        verify(
              () => api.send(
                deviceKey: any(named: 'deviceKey'),
                report: captureAny(named: 'report'),
              ),
            ).captured.last
            as GeofenceReport;
    expect(sent.at, DateTime(2026, 10, 8, 17, 40));
    expect(store.queue, isEmpty);
  });

  test('server weigert definitief: niet blijven proberen', () async {
    when(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: any(named: 'report'),
      ),
    ).thenThrow(const GeofenceSendException('geweigerd', retry: false));
    await reporter().report([arrivalHome()]);
    expect(store.queue, isEmpty);
  });

  test('afgemeld (geen sleutel): niets versturen', () async {
    store.key = null;
    expect(await reporter().report([arrivalHome()]), isEmpty);
    verifyNever(
      () => api.send(
        deviceKey: any(named: 'deviceKey'),
        report: any(named: 'report'),
      ),
    );
  });
}
