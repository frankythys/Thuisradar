import 'package:thuisradar/features/geofencing/data/geofence_store.dart';
import 'package:thuisradar/features/geofencing/domain/geofence_report.dart';

/// Opslag in het geheugen in plaats van SharedPreferences.
class FakeGeofenceStore implements GeofenceStore {
  String? key = 'toestel-sleutel';
  List<GeofenceReport> queue = [];

  @override
  Future<String?> deviceKey() async => key;

  @override
  Future<String> ensureDeviceKey() async => key ??= 'nieuwe-sleutel';

  @override
  Future<List<GeofenceReport>> pending(String deviceKey) async => [...queue];

  @override
  Future<void> enqueue(String deviceKey, List<GeofenceReport> reports) async {
    for (final report in reports) {
      if (!queue.contains(report)) queue.add(report);
    }
  }

  @override
  Future<void> acknowledge(String deviceKey, GeofenceReport report) async => queue.remove(report);

  @override
  Future<void> clear() async {
    key = null;
    queue = [];
  }
}
