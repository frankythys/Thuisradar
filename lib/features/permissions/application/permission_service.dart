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
    if (access != LocationAccess.granted) return false;
    // Android 10+: zonder "Altijd toestaan" stopt de locatie zodra de app naar
    // de achtergrond gaat. Op Android 11+ opent dit de instellingen; weigeren
    // mag — delen werkt dan enkel met de app open.
    if (!await Permission.locationAlways.isGranted) {
      await Permission.locationAlways.request();
    }
    return true;
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
