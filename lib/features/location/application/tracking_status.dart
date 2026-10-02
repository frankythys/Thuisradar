import '../domain/device_reading.dart';

enum TrackingStatus {
  idle,
  starting,
  active,

  /// Locatie werkt, maar de laatste upload naar de server mislukte.
  offline,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error;

  static TrackingStatus fromAccess(LocationAccess access) => switch (access) {
    LocationAccess.granted => TrackingStatus.starting,
    LocationAccess.denied => TrackingStatus.permissionDenied,
    LocationAccess.deniedForever => TrackingStatus.permissionDeniedForever,
    LocationAccess.serviceDisabled => TrackingStatus.serviceDisabled,
  };

  bool get needsUserAction =>
      this == permissionDenied || this == permissionDeniedForever || this == serviceDisabled;
}
