import 'package:native_geofence/native_geofence.dart';

import '../domain/geofence_zone.dart';

export 'package:native_geofence/native_geofence.dart' show GeofenceCallbackParams, GeofenceEvent;

/// Top-level functie met `@pragma('vm:entry-point')` die Android oproept.
typedef GeofenceHandler = Future<void> Function(GeofenceCallbackParams params);

/// Geen toestemming "Altijd toestaan" voor locatie: Android weigert zones.
class GeofencePermissionMissing implements Exception {
  const GeofencePermissionMissing();
}

/// Dunne laag rond `native_geofence`, zodat de rest testbaar blijft.
class NativeGeofenceSource {
  NativeGeofenceManager get _manager => NativeGeofenceManager.instance;

  Future<void> initialize() => _guard(_manager.initialize);

  /// Android vergeet zones o.a. als locatie even uit stond. Opnieuw aanmelden
  /// bij de start van de app houdt ze levend (de plugin onthoudt ze zelf).
  Future<void> recreateAll() => _guard(_manager.reCreateAfterReboot);

  Future<List<String>> registeredIds() => _guard(_manager.getRegisteredGeofenceIds);

  /// [callback] moet een top-level functie met `@pragma('vm:entry-point')` zijn.
  Future<void> add(GeofenceZone zone, GeofenceHandler callback) => _guard(
    () => _manager.createGeofence(
      Geofence(
        id: zone.id,
        location: Location(latitude: zone.latitude, longitude: zone.longitude),
        radiusMeters: zone.radiusMeters,
        triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
        iosSettings: const IosGeofenceSettings(),
        // Geen melding bij het registreren zelf: enkel echte overgangen.
        androidSettings: const AndroidGeofenceSettings(initialTriggers: {}),
      ),
      callback,
    ),
  );

  Future<void> remove(String id) => _guard(() => _manager.removeGeofenceById(id));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on NativeGeofenceException catch (error) {
      if (error.code == NativeGeofenceErrorCode.missingLocationPermission ||
          error.code == NativeGeofenceErrorCode.missingBackgroundLocationPermission) {
        throw const GeofencePermissionMissing();
      }
      rethrow;
    }
  }
}
