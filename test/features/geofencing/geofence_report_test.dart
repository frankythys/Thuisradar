import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_report.dart';

void main() {
  final at = DateTime.utc(2026, 10, 8, 15, 40);

  test('elke zone van ons wordt één melding; vreemde zones niet', () {
    final reports = reportsForZones(
      zoneIds: const ['tr1|thuis|51.00000|4.00000|150', 'ander'],
      type: GeofenceReportType.arrival,
      at: at,
      latitude: 51,
      longitude: 4,
    );
    expect(reports.single.placeId, 'thuis');
    expect(reports.single.type, GeofenceReportType.arrival);
  });

  test('melding overleeft opslaan in de wachtrij met haar tijdstip', () {
    final report = GeofenceReport(placeId: 'thuis', type: GeofenceReportType.departure, at: at, latitude: 51);
    final back = GeofenceReport.fromJson(report.toJson());
    expect(back.placeId, 'thuis');
    expect(back.type, GeofenceReportType.departure);
    expect(back.at, at);
    expect(back.latitude, 51);
    expect(back.longitude, isNull);
  });

  test('wachtrij: oud valt weg, rest blijft in volgorde', () {
    final old = GeofenceReport(placeId: 'werk', type: GeofenceReportType.departure, at: at);
    final arrive = GeofenceReport(
      placeId: 'thuis',
      type: GeofenceReportType.arrival,
      at: at.add(const Duration(minutes: 40)),
    );
    final leave = GeofenceReport(
      placeId: 'thuis',
      type: GeofenceReportType.departure,
      at: at.add(const Duration(minutes: 35)),
    );
    final pruned = pruneReportQueue([old, arrive, leave], now: at.add(const Duration(minutes: 45)));
    expect(pruned, [leave, arrive]);
  });

  test('wachtrij houdt hoogstens de laatste meldingen bij', () {
    final queue = [
      for (var i = 0; i < 25; i++)
        GeofenceReport(
          placeId: 'p$i',
          type: GeofenceReportType.arrival,
          at: at.add(Duration(seconds: i)),
        ),
    ];
    final pruned = pruneReportQueue(queue, now: at.add(const Duration(minutes: 1)));
    expect(pruned.length, 20);
    expect(pruned.first.placeId, 'p5');
  });
}
