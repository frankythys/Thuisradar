import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/device_reading.dart';

/// Leest de GPS-positie via `geolocator`. Op Android draait de stroom als
/// foreground service met een vaste melding, zodat hij ook op de achtergrond
/// blijft werken.
class DeviceLocationSource {
  DeviceLocationSource({String Function()? notificationText})
    : _notificationText = notificationText ?? (() => 'Je locatie wordt gedeeld met je familie');

  /// Tekst van de vaste melding tijdens het delen, in de taal van de app.
  final String Function() _notificationText;

  static const _distanceFilterMeters = 0;

  /// Vast meetinterval van de GPS-stroom. Bewust één vaste waarde: de stroom
  /// mag nooit herstart worden om het tempo te wisselen, want op Android stopt
  /// dat de voorgronddienst en mag die vanuit de achtergrond (zakje, scherm
  /// uit) niet opnieuw starten — dan valt het delen stil tot de app herstart.
  /// Hoe vaak er geüpload wordt, regelt de tracker zelf.
  static const streamInterval = Duration(seconds: 5);

  /// Vraagt de toestemming als die er nog niet is. Enkel na de uitleg
  /// (`showLocationDisclosure`): Play eist die vóór de Android-vraag.
  Future<LocationAccess> ensureAccess() => _access(request: true);

  /// Kijkt alleen of er toestemming is, zonder de Android-vraag te tonen.
  Future<LocationAccess> checkAccess() => _access(request: false);

  Future<LocationAccess> _access({required bool request}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (request && permission == LocationPermission.denied) {
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

  /// Android laat snelheid en nauwkeurigheid weg als het ze niet mat;
  /// geolocator maakt daar dan 0,0 van. Zonder de `has*`-vlag werd een
  /// rijdende auto met een wifi-fix zo "stilstaand" en een grove fix "exact".
  DevicePosition _toDevice(Position p) => DevicePosition(
    latitude: p.latitude,
    longitude: p.longitude,
    timestamp: p.timestamp,
    accuracyMeters: p.hasAccuracy ? p.accuracy : null,
    speedMps: p.hasSpeed && p.speed >= 0 ? p.speed : null,
  );

  Stream<DevicePosition> positions() {
    return Geolocator.getPositionStream(locationSettings: _settings(streamInterval)).map(_toDevice);
  }

  LocationSettings _settings(Duration interval) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: interval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'CircleBeacon',
          notificationText: _notificationText(),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanceFilterMeters);
  }
}
