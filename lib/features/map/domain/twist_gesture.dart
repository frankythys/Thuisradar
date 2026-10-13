import 'dart:math' as math;

import 'map_rotation.dart';

/// Een aanraakpunt op het scherm (logische pixels).
typedef TouchPoint = ({double x, double y});

/// Zoveel graden moeten twee vingers samen draaien voor de kaart meedraait,
/// zoals in Google Maps. Schuiven of zoomen met twee vingers draait zo niet
/// per ongeluk mee.
const kTwistThreshold = 25.0;

/// Gaan de vingers eerst zoveel uit elkaar of naar elkaar (20%), dan is het
/// een zoomgebaar: de kaart draait in dat gebaar niet meer.
const kPinchLock = 1.2;

/// Hoek (graden, -180..180) waarover de lijn tussen twee vingers gedraaid is.
///
/// Flutter geeft die hoek zelf niet genormaliseerd door: een draai van +1°
/// kan als -359° binnenkomen (afhankelijk van welke vinger eerst neerkwam),
/// waardoor een drempel op die ruwe waarde altijd meteen gehaald wordt.
double twistDegrees(TouchPoint startA, TouchPoint startB, TouchPoint nowA, TouchPoint nowB) {
  final before = math.atan2(startB.y - startA.y, startB.x - startA.x);
  final after = math.atan2(nowB.y - nowA.y, nowB.x - nowA.x);
  return normalizedRotation((after - before) * 180 / math.pi);
}

/// Volgt de vingers op de kaart en zegt of draaien toegelaten is: pas na een
/// draai van [threshold] graden met twee vingers, tot alle vingers los zijn.
/// Begint het gebaar als zoomen ([kPinchLock]), dan draait het nooit.
class TwistGesture {
  TwistGesture({this.threshold = kTwistThreshold});

  final double threshold;
  final _now = <int, TouchPoint>{};
  ({int a, int b, TouchPoint startA, TouchPoint startB})? _pair;
  bool _rotating = false;
  bool _zooming = false;

  /// Mag de kaart in dit gebaar draaien?
  bool get rotating => _rotating;

  void down(int pointer, TouchPoint at) {
    _now[pointer] = at;
    if (_pair == null && _now.length == 2) {
      final [a, b] = _now.keys.toList();
      _pair = (a: a, b: b, startA: _now[a]!, startB: _now[b]!);
    }
  }

  void move(int pointer, TouchPoint at) {
    if (!_now.containsKey(pointer)) return;
    _now[pointer] = at;
    final pair = _pair;
    if (_rotating || _zooming || pair == null) return;
    final nowA = _now[pair.a]!;
    final nowB = _now[pair.b]!;
    final scale = _distance(nowA, nowB) / _distance(pair.startA, pair.startB);
    if (scale >= kPinchLock || scale <= 1 / kPinchLock) {
      _zooming = true;
      return;
    }
    if (twistDegrees(pair.startA, pair.startB, nowA, nowB).abs() >= threshold) _rotating = true;
  }

  void up(int pointer) {
    _now.remove(pointer);
    if (_pair case final pair? when pair.a == pointer || pair.b == pointer) _pair = null;
    if (_now.isEmpty) _rotating = _zooming = false;
  }

  static double _distance(TouchPoint a, TouchPoint b) =>
      math.max(1, math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2)));
}
