import 'package:flutter_test/flutter_test.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:thuisradar/features/geofencing/data/native_geofence_source.dart';

void main() {
  NativeGeofenceException failure(NativeGeofenceErrorCode code, String message) =>
      NativeGeofenceException(code: code, message: message);

  test('Android-code 1000 (GEOFENCE_NOT_AVAILABLE) = locatienauwkeurigheid uit', () {
    final error = geofenceFailure(
      failure(
        NativeGeofenceErrorCode.pluginInternal,
        'com.google.android.gms.common.api.ApiException: 1000: ',
      ),
    );
    expect(error, isA<GeofenceUnavailable>());
  });

  test('geen achtergrondtoestemming blijft "toestemming ontbreekt"', () {
    final error = geofenceFailure(failure(NativeGeofenceErrorCode.missingBackgroundLocationPermission, ''));
    expect(error, isA<GeofencePermissionMissing>());
  });

  test('andere fout blijft de oorspronkelijke fout', () {
    final original = failure(NativeGeofenceErrorCode.pluginInternal, 'ApiException: 1001: ');
    expect(geofenceFailure(original), same(original));
  });
}
