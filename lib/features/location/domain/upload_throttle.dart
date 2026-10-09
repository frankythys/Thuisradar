import 'device_reading.dart';

/// Beslist welke GPS-metingen echt naar de server gaan.
///
/// De GPS-stroom levert vast elke 5 s een meting (zie `DeviceLocationSource`);
/// hier kiezen we het upload-tempo: elke meting tijdens een rit, om de 10 s
/// tijdens een eigen SOS, om de 15 s bij stilstand. Een wissel tussen rijden en
/// stilstaan gaat altijd meteen door, zodat vertrek en aankomst niet wachten.
class UploadThrottle {
  static const movingInterval = Duration(seconds: 5);
  static const sosInterval = Duration(seconds: 10);
  static const stillInterval = Duration(seconds: 15);

  /// Metingen komen niet op de milliseconde; een kleine speling voorkomt dat
  /// een meting van 14,9 s pas bij de volgende (20 s) geüpload wordt.
  static const _jitter = Duration(seconds: 1);

  /// Eigen SOS actief: vaker uploaden.
  bool fast = false;

  DateTime? _lastAt;
  var _lastMoving = false;

  Duration interval({required bool moving}) => moving ? movingInterval : (fast ? sosInterval : stillInterval);

  bool shouldUpload(DevicePosition position, DateTime now, {required bool moving}) {
    final last = _lastAt;
    if (last == null) return true;
    if (_movingOf(position) != _lastMoving) return true;
    return now.difference(last) >= interval(moving: moving) - _jitter;
  }

  /// Na een geslaagde upload; een mislukte telt niet, zodat de volgende
  /// meting meteen opnieuw probeert.
  void uploaded(DevicePosition position, DateTime now) {
    _lastAt = now;
    _lastMoving = _movingOf(position);
  }

  /// Onderweg volgens de bewegingsfilter (positieve snelheid). Onbekend en
  /// stilstaand tellen allebei als "niet onderweg", zodat GPS-ruis thuis
  /// (afwisselend onbekend/stil) geen upload-stortvloed geeft.
  static bool _movingOf(DevicePosition position) => (position.speedMps ?? 0) > 0;
}
