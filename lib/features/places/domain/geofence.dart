/// Overgang die een nieuwe meting veroorzaakt.
enum GeofenceTransition { arrival, departure }

/// Aanwezigheidsstatus van één lid voor één plaats (spiegelt place_presence).
class PresenceState {
  const PresenceState({this.isInside = false, this.outsideCount = 0, this.outsideSince, this.since});

  final bool isInside;
  final int outsideCount;
  final DateTime? outsideSince;
  final DateTime? since;
}

/// Resultaat van een evaluatie: de nieuwe status en een eventuele overgang.
class GeofenceResult {
  const GeofenceResult(this.state, [this.transition]);

  final PresenceState state;
  final GeofenceTransition? transition;
}

/// Pure anti-flapping-logica, identiek aan de server-trigger `evaluate_geofences`:
///  * meting met `accuracyMeters > maxAccuracyMeters` → negeren (geen verandering);
///  * binnen = `distanceMeters < radiusMeters`;
///  * buiten (bevestigd) = `distanceMeters > radiusMeters + hysteresisMeters`;
///  * vertrek telt pas na `>= minOutsideReadings` metingen in de buitenzone
///    OF na `minOutsideDuration`;
///  * band ertussen = geen verandering.
GeofenceResult evaluateGeofence({
  required PresenceState current,
  required double distanceMeters,
  required double radiusMeters,
  required DateTime at,
  double? accuracyMeters,
  double hysteresisMeters = 50,
  int minOutsideReadings = 2,
  Duration minOutsideDuration = const Duration(minutes: 3),
  double maxAccuracyMeters = 100,
}) {
  if (accuracyMeters != null && accuracyMeters > maxAccuracyMeters) {
    return GeofenceResult(current);
  }

  if (distanceMeters < radiusMeters) {
    if (!current.isInside) {
      return GeofenceResult(PresenceState(isInside: true, since: at), GeofenceTransition.arrival);
    }
    // Blijft binnen: eventuele vertrek-tellers resetten.
    return GeofenceResult(PresenceState(isInside: true, since: current.since));
  }

  if (distanceMeters > radiusMeters + hysteresisMeters) {
    if (!current.isInside) return GeofenceResult(current);

    final outsideSince = current.outsideSince ?? at;
    final count = current.outsideSince == null ? 1 : current.outsideCount + 1;
    final confirmed = count >= minOutsideReadings || at.difference(outsideSince) >= minOutsideDuration;

    if (confirmed) {
      return GeofenceResult(const PresenceState(), GeofenceTransition.departure);
    }
    return GeofenceResult(
      PresenceState(isInside: true, since: current.since, outsideSince: outsideSince, outsideCount: count),
    );
  }

  // Band (straal..straal+hysterese): geen verandering.
  return GeofenceResult(current);
}
