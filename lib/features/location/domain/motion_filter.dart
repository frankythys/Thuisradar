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
  int _movingSamples = 0;
  int _stillSamples = 0;
  bool? _moving;

  bool get wantsFastUpdates => _moving == true || _movingSamples > 0;

  DevicePosition? accept(DevicePosition point, DateTime now) {
    final accuracy = point.accuracyMeters;
    final age = now.difference(point.timestamp);
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180 ||
        (accuracy != null && (!accuracy.isFinite || accuracy < 0 || accuracy > _maxAccuracyMeters)) ||
        age > const Duration(seconds: 90) ||
        age < const Duration(seconds: -10)) {
      return null;
    }

    var previous = _previous;
    final seconds = previous == null
        ? null
        : point.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    if (seconds != null && seconds <= 0) return null;
    if (seconds != null && seconds > 90) {
      previous = null;
      _moving = null;
      _movingSamples = _stillSamples = 0;
    }
    final distance = previous == null
        ? null
        : distanceMeters(previous.latitude, previous.longitude, point.latitude, point.longitude);
    final uncertainty = (accuracy ?? 50) + (previous?.accuracyMeters ?? 50);
    if (distance != null && (distance - uncertainty) / seconds! > 70) return null;

    final coarse = accuracy != null && accuracy > _reliableAccuracyMeters;
    var speed = point.speedMps;
    if (speed != null && (!speed.isFinite || speed < 0 || speed > 70)) speed = null;
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
          speed >= 1.5 &&
          distance != null &&
          seconds! >= 2 &&
          distance + uncertainty < speed * seconds * 0.3) {
        speed = null;
      }
    }
    if (speed == null) {
      _movingSamples = _stillSamples = 0;
      _moving = null;
    } else if (speed >= 1.5) {
      _movingSamples++;
      _stillSamples = 0;
      if (_movingSamples >= 2) _moving = true;
    } else if (speed <= 0.8) {
      _stillSamples++;
      _movingSamples = 0;
      if (_stillSamples >= 2) _moving = false;
    } else {
      _movingSamples = _stillSamples = 0;
    }
    _previous = point;
    // Null betekent onbekend; nul bevestigd stilstaand; positief onderweg.
    final reportedSpeed = _moving == false
        ? 0.0
        : (_moving == true && speed != null && speed >= 1.5 ? speed : null);
    return DevicePosition(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
      accuracyMeters: accuracy,
      speedMps: reportedSpeed,
    );
  }
}
