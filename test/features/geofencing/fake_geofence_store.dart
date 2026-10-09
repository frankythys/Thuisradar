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
  Future<List<GeofenceReport>> pending() async => queue;

  @override
  Future<void> savePending(List<GeofenceReport> reports) async => queue = reports;

  @override
  Future<void> clear() async {
    key = null;
    queue = [];
  }
}
