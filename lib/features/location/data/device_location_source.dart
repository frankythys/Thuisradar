import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/device_reading.dart';

/// Leest de GPS-positie via `geolocator`. Op Android draait de stroom als
/// foreground service met een vaste melding, zodat hij ook op de achtergrond
/// blijft werken.
class DeviceLocationSource {
  static const _distanceFilterMeters = 0;
  static const defaultInterval = Duration(seconds: 30);

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

  /// Een verse GPS-meting; lukt dat niet binnen [timeout] (bv. binnenshuis),
  /// dan de laatst bekende positie. Null als er helemaal niets is.
  Future<DevicePosition?> currentPosition({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
      return _toDevice(p);
    } on Exception {
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : _toDevice(last);
      } on Exception {
        return null;
      }
    }
  }

  DevicePosition _toDevice(Position p) => DevicePosition(
    latitude: p.latitude,
    longitude: p.longitude,
    timestamp: p.timestamp,
    accuracyMeters: p.accuracy,
    speedMps: p.speed < 0 ? null : p.speed,
  );

  Stream<DevicePosition> positions({Duration interval = defaultInterval}) {
    return Geolocator.getPositionStream(locationSettings: _settings(interval)).map(
      (p) => DevicePosition(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
        accuracyMeters: p.accuracy,
        speedMps: p.speed < 0 ? null : p.speed,
      ),
    );
  }

  LocationSettings _settings(Duration interval) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: interval,
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
