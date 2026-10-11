import 'dart:math' as math;

import 'device_reading.dart';

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const radians = math.pi / 180;
  final a =
      math.pow(math.sin((lat2 - lat1) * radians / 2), 2) +
      math.cos(lat1 * radians) *
          math.cos(lat2 * radians) *
          math.pow(math.sin((lon2 - lon1) * radians / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}

/// Vanaf deze snelheid (m/s, 3,6 km/u) is iemand onderweg: ook een rustige
/// wandeling telt, zodat het spoor dan net zo fijn wordt gelogd als een rit.
/// Dezelfde grens geldt voor de status op de kaart ([TripStatus]).
const kMovingSpeedMps = 1.0;

/// Waarom [MotionFilter.accept] een meting weigerde; voor de locatiediagnose.
enum RejectReason {
  invalid('ongeldig'),
  inaccurate('onnauwkeurig'),
  stale('te oud'),
  future('in de toekomst'),
  notNewer('niet nieuwer'),
  jump('onmogelijke sprong');

  const RejectReason(this.label);

  final String label;
}

/// Alleen echte, recente metingen. Twee opeenvolgende bewijzen zijn nodig
/// voor een statuswissel; GPS-snelheid bewijst nooit een vervoermiddel.
class MotionFilter {
  /// Boven deze nauwkeurigheid is een fix te grof om nog iets mee te doen.
  static const _maxAccuracyMeters = 100.0;

  /// Tussen [_reliableAccuracyMeters] en [_maxAccuracyMeters] houden we de fix
  /// wél bij voor aanwezigheid en geschiedenis (binnenshuis via wifi/zendmast),
  /// maar leiden we er nooit beweging uit af — anders zou GPS-ruis een rit lijken.
  static const _reliableAccuracyMeters = 50.0;

  DevicePosition? _previous;
  DevicePosition? _motionOrigin;
  int _movingSamples = 0;
  int _stillSamples = 0;
  bool? _moving;

  bool get wantsFastUpdates => _moving == true || _movingSamples > 0;

  /// Reden van de laatste weigering; null als de laatste meting aanvaard werd.
  RejectReason? get lastRejection => _lastRejection;
  RejectReason? _lastRejection;

  DevicePosition? accept(DevicePosition point, DateTime now) {
    _lastRejection = _reject(point, now);
    if (_lastRejection != null) return null;
    return _accept(point);
  }

  RejectReason? _reject(DevicePosition point, DateTime now) {
    final accuracy = point.accuracyMeters;
    final age = now.difference(point.timestamp);
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180 ||
        (accuracy != null && (!accuracy.isFinite || accuracy < 0))) {
      return RejectReason.invalid;
    }
    if (accuracy != null && accuracy > _maxAccuracyMeters) return RejectReason.inaccurate;
    if (age > const Duration(seconds: 90)) return RejectReason.stale;
    if (age < const Duration(seconds: -10)) return RejectReason.future;
    return null;
  }

  DevicePosition? _accept(DevicePosition point) {
    final accuracy = point.accuracyMeters;

    var previous = _previous;
    final seconds = previous == null
        ? null
        : point.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (seconds != null && seconds <= 0) {
      _lastRejection = RejectReason.notNewer;
      return null;
    }
    if (seconds != null && seconds > 90) {
      previous = null;
      _motionOrigin = null;
      _moving = null;
      _movingSamples = _stillSamples = 0;
    }
    final distance = previous == null
        ? null
        : distanceMeters(previous.latitude, previous.longitude, point.latitude, point.longitude);
    final uncertainty = (accuracy ?? 50) + (previous?.accuracyMeters ?? 50);
    if (distance != null && (distance - uncertainty) / seconds! > 70) {
      _lastRejection = RejectReason.jump;
      return null;
    }

    final coarse = accuracy != null && accuracy > _reliableAccuracyMeters;
    var speed = point.speedMps;
    if (speed != null && (!speed.isFinite || speed < 0 || speed > 70)) speed = null;
    // GPS-snelheid alleen bewijst geen verplaatsing. Bewaar een beginpunt zodat
    // ook kleine wandelstappen samen buiten de onzekerheid kunnen komen.
    final origin = _motionOrigin ??= point;
    final movedFromOrigin = distanceMeters(
      origin.latitude,
      origin.longitude,
      point.latitude,
      point.longitude,
    );
    final originUncertainty = (origin.accuracyMeters ?? 50) + (accuracy ?? 50);
    if (coarse) {
      // Te grof om beweging te bewijzen: enkel een aanwezigheidspunt.
      speed = null;
    } else {
      // Zonder GPS-snelheid alleen afleiden buiten de onzekerheid van beide fixes.
      if (speed == null && distance != null && seconds! >= 2 && distance > uncertainty) {
        speed = distance / seconds;
      }
      // Een hoge snelheid terwijl de nauwkeurige fix niet beweegt is geen bewijs.
      if (speed != null &&
          speed >= kMovingSpeedMps &&
          distance != null &&
          seconds! >= 2 &&
          distance + uncertainty < speed * seconds * 0.3) {
        speed = null;
      }
    }
    if (speed == null) {
      _movingSamples = _stillSamples = 0;
      _moving = null;
      _motionOrigin = point;
    } else if (speed >= kMovingSpeedMps) {
      _movingSamples++;
      _stillSamples = 0;
      // Twee metingen én echte verplaatsing, ook bij een GPS-snelheid.
      if (_movingSamples >= 2 && movedFromOrigin > originUncertainty) _moving = true;
    } else if (speed <= 0.8) {
      _stillSamples++;
      _movingSamples = 0;
      if (_stillSamples >= 2) {
        _moving = false;
        _motionOrigin = point;
      }
    } else {
      _movingSamples = _stillSamples = 0;
    }
    _previous = point;
    // Null betekent onbekend; nul bevestigd stilstaand; positief onderweg.
    final reportedSpeed = _moving == false
        ? 0.0
        : (_moving == true && speed != null && speed >= kMovingSpeedMps ? speed : null);
    return DevicePosition(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
      accuracyMeters: accuracy,
      speedMps: reportedSpeed,
    );
  }
}
