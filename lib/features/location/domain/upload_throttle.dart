import 'device_reading.dart';

/// Beslist welke GPS-metingen echt naar de server gaan.
///
/// De GPS-stroom levert vast elke 5 s een meting (zie `DeviceLocationSource`);
/// hier kiezen we het upload-tempo: elke meting tijdens een rit, om de 10 s
/// tijdens een eigen SOS, om de 15 s bij stilstand. Een wissel tussen rijden en
/// stilstaan gaat altijd meteen door, zodat vertrek en aankomst niet wachten.
/// Ook de bevestigde stilstand kort na een rit (rood licht, aankomst) gaat
/// meteen mee: anders bleef de kaart tot 20 s op de oude snelheid staan.
class UploadThrottle {
  static const movingInterval = Duration(seconds: 5);
  static const sosInterval = Duration(seconds: 10);
  static const stillInterval = Duration(seconds: 15);

  /// Zo lang na de laatste rijdende upload gaat een bevestigde stilstand
  /// meteen door.
  static const arrivalWindow = Duration(seconds: 60);

  /// Metingen komen niet op de milliseconde; een kleine speling voorkomt dat
  /// een meting van 14,9 s pas bij de volgende (20 s) geüpload wordt.
  static const _jitter = Duration(seconds: 1);

  /// Eigen SOS actief: vaker uploaden.
  bool fast = false;

  DateTime? _lastAt;
  var _lastMoving = false;
  double? _lastSpeed;
  DateTime? _lastMovingAt;

  Duration interval({required bool moving}) => moving ? movingInterval : (fast ? sosInterval : stillInterval);

  bool shouldUpload(DevicePosition position, DateTime now, {required bool moving}) {
    final last = _lastAt;
    if (last == null) return true;
    if (_movingOf(position) != _lastMoving) return true;
    // Onbekend na een rit, nu bevestigd stil: meteen. Thuis (lang geen rit)
    // blijft wisselen tussen onbekend en stil binnen het gewone tempo.
    final lastMovingAt = _lastMovingAt;
    if (position.speedMps == 0 &&
        _lastSpeed != 0 &&
        lastMovingAt != null &&
        now.difference(lastMovingAt) <= arrivalWindow) {
      return true;
    }
    return now.difference(last) >= interval(moving: moving) - _jitter;
  }

  /// Na een geslaagde upload; een mislukte telt niet, zodat de volgende
  /// meting meteen opnieuw probeert.
  void uploaded(DevicePosition position, DateTime now) {
    _lastAt = now;
    _lastMoving = _movingOf(position);
    _lastSpeed = position.speedMps;
    if (_lastMoving) _lastMovingAt = now;
  }

  /// Onderweg volgens de bewegingsfilter (positieve snelheid). Onbekend en
  /// stilstaand tellen allebei als "niet onderweg", zodat GPS-ruis thuis
  /// (afwisselend onbekend/stil) geen upload-stortvloed geeft.
  static bool _movingOf(DevicePosition position) => (position.speedMps ?? 0) > 0;
}
