import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/device_reading.dart';

/// Leest de GPS-positie via `geolocator`. Op Android draait de stroom als
/// foreground service met een vaste melding, zodat hij ook op de achtergrond
/// blijft werken.
class DeviceLocationSource {
  static const _distanceFilterMeters = 25;
  static const _interval = Duration(seconds: 30);

  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Stream<DevicePosition> positions() {
    return Geolocator.getPositionStream(locationSettings: _settings()).map(
      (p) => DevicePosition(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        accuracyMeters: p.accuracy,
        speedMps: p.speed < 0 ? null : p.speed,
      ),
    );
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: _interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Thuisradar',
          notificationText: 'Je locatie wordt gedeeld met je familie',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanceFilterMeters);
  }
}
