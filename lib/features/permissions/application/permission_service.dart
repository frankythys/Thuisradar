import 'package:permission_handler/permission_handler.dart';

import '../../location/data/device_location_source.dart';
import '../../location/domain/device_reading.dart';

/// Vraagt de rechten die Thuisradar nodig heeft. Locatie loopt via dezelfde
/// geolocator-bron als de tracker; meldingen en batterij via permission_handler.
class PermissionService {
  PermissionService(this._location);

  final DeviceLocationSource _location;

  Future<bool> requestLocation() async {
    final access = await _location.ensureAccess();
    return access == LocationAccess.granted;
  }

  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> requestBatteryExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<void> openSettings() => openAppSettings();
}
