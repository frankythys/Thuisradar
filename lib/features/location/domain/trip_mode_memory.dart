import 'member_location.dart';
import 'motion_filter.dart' show kMovingSpeedMps;
import 'travel_mode.dart';
import 'trip_hint.dart';
import 'trip_status.dart' show kBikeDisplayKmh, travelModeForSpeed;

/// Houdt per lid een rustige weergavestatus bij over meerdere metingen heen,
/// zodat de kaart niet bij elke GPS-ruis wisselt tussen wandelen, stilstaan,
/// fietsen en rijden. Enkel weergave: GPS en ritgeschiedenis blijven origineel.
///
/// - Vertrekken of stoppen vraagt twee opeenvolgende metingen.
/// - Fiets en auto zijn "plakkerig": afremmen of een verkeerslicht (tot een
///   minuut) blijft onderweg, met hetzelfde vervoermiddel. Pas na
///   [parkedAfter] stilstand, of als de stappenteller echt stappen telt, kan
///   het weer wandelen worden.
/// - Hoger vervoermiddel pas na twee metingen boven de grens (een fietser die
///   even bergaf 27 km/u gaat, blijft een fietser).
class TripModeMemory {
  final _members = <String, _Trip>{};

  /// Na zo lang stilstaan is een rit of fietstocht voorbij.
  static const parkedAfter = Duration(seconds: 90);

  /// Langer zonder meting: de geschiedenis telt niet meer.
  static const _gapReset = Duration(seconds: 45);

  /// Zo lang mag een fietser of auto stilstaan en toch onderweg blijven.
  static const _pauseFor = Duration(seconds: 60);

  /// Onder deze snelheid (m/s) telt een meting zeker als stilstaan.
  static const _stopMps = 0.6;

  /// Onder deze snelheid (km/u) tijdens [_slowFor] wordt een fietser een wandelaar.
  static const _walkKmh = 8;
  static const _slowFor = Duration(seconds: 20);

  /// Eén meting boven deze snelheid (km/u) is meteen een auto.
  static const _surelyCarKmh = 40;

  /// Zoveel stappen bij lage snelheid sinds de laatste snelle meting = te voet.
  static const _onFootSteps = 12;

  List<MemberLocation> update(List<MemberLocation> locations) {
    final present = locations.map((location) => location.userId).toSet();
    _members.removeWhere((id, _) => !present.contains(id));
    return [for (final location in locations) _update(location)];
  }

  MemberLocation _update(MemberLocation location) {
    final trip = _members.putIfAbsent(location.userId, _Trip.new);
    final previous = trip.updatedAt;
    if (previous != null && !location.updatedAt.isAfter(previous)) {
      return trip.hint == null ? location : location.copyWith(tripHint: trip.hint);
    }
    if (previous != null && location.updatedAt.difference(previous) > _gapReset) trip.reset();
    trip.updatedAt = location.updatedAt;

    final speed = location.speedMps;
    final valid = speed != null && speed.isFinite && speed >= 0 && speed <= 70;
    if (valid) _apply(trip, speed, location);
    return trip.hint == null ? location : location.copyWith(tripHint: trip.hint);
  }

  void _apply(_Trip trip, double speed, MemberLocation location) {
    final at = location.updatedAt;
    final kmh = (speed * 3.6).round();
    final fast = speed >= kMovingSpeedMps;
    final steps = location.steps;
    if (trip.moving == null) {
      // Eerste meting: niets om mee te vergelijken.
      trip.moving = fast;
      if (fast) trip.start(travelModeForSpeed(kmh), kmh, steps);
      return;
    }

    if (trip.moving!) {
      if (!fast) {
        trip.slowSamples++;
        trip.pausedAt ??= at;
        // Fiets en auto: een verkeerslicht of file is nog geen stop.
        final sticky = trip.mode == TravelMode.bike || trip.mode == TravelMode.car;
        final stopped = sticky
            ? at.difference(trip.pausedAt!) >= _pauseFor
            : (speed < _stopMps && trip.slowSamples >= 2) || trip.slowSamples >= 3;
        if (stopped) {
          trip
            ..moving = false
            ..stoppedAt = trip.pausedAt
            ..pausedAt = null
            ..fastSamples = 0;
        } else if (sticky) {
          trip.speedKmh = kmh;
        }
        return;
      }
      trip
        ..slowSamples = 0
        ..pausedAt = null
        ..speedKmh = kmh;
    } else {
      final stoppedFor = trip.stoppedAt == null ? null : at.difference(trip.stoppedAt!);
      if (stoppedFor != null && stoppedFor >= parkedAfter) trip.mode = null;
      if (!fast) {
        trip.fastSamples = 0;
        return;
      }
      trip.fastSamples++;
      // Na een korte stop (verkeerslicht) rijdt een auto of fiets meteen verder.
      final resume = trip.mode != null && trip.mode != TravelMode.walk;
      if (!resume && trip.fastSamples < 2) return;
      trip.moving = true;
      trip.slowSamples = 0;
      trip.stoppedAt = null;
      if (trip.mode == null) {
        trip.start(travelModeForSpeed(kmh), kmh, steps);
        return;
      }
      trip.speedKmh = kmh;
    }
    _chooseMode(trip, kmh, steps, at);
  }

  void _chooseMode(_Trip trip, int kmh, int? steps, DateTime at) {
    final mode = trip.mode ?? TravelMode.walk;
    // Stappen bij lage snelheid: uitgestapt of afgestapt.
    if (kmh < kBikeDisplayKmh) {
      final base = trip.stepsAtFast;
      if (steps != null && base != null && steps - base >= _onFootSteps && mode != TravelMode.walk) {
        trip.setMode(TravelMode.walk, steps);
        return;
      }
      if (steps != null && (base == null || steps < base)) trip.stepsAtFast = steps;
    } else {
      trip.stepsAtFast = steps ?? trip.stepsAtFast;
    }

    final candidate = travelModeForSpeed(kmh);
    if (candidate.index > mode.index) {
      trip.upgradeSamples = trip.upgradeTo == candidate ? trip.upgradeSamples + 1 : 1;
      trip.upgradeTo = candidate;
      if (trip.upgradeSamples >= 2 || kmh >= _surelyCarKmh) trip.setMode(candidate, steps);
    } else {
      trip.upgradeSamples = 0;
      trip.upgradeTo = null;
    }

    if (trip.mode == TravelMode.bike && kmh < _walkKmh) {
      trip.slowSince ??= at;
      if (at.difference(trip.slowSince!) >= _slowFor) trip.setMode(TravelMode.walk, steps);
    } else {
      trip.slowSince = null;
    }
  }
}

class _Trip {
  DateTime? updatedAt;
  bool? moving;
  TravelMode? mode;
  int? speedKmh;
  DateTime? stoppedAt;
  DateTime? pausedAt;
  DateTime? slowSince;
  int? stepsAtFast;
  int fastSamples = 0;
  int slowSamples = 0;
  TravelMode? upgradeTo;
  int upgradeSamples = 0;

  TripHint? get hint => moving == null
      ? null
      : TripHint(moving: moving!, mode: mode ?? TravelMode.walk, speedKmh: moving! ? speedKmh : null);

  void start(TravelMode travel, int kmh, int? steps) {
    mode = travel;
    speedKmh = kmh;
    stepsAtFast = steps;
    upgradeTo = null;
    upgradeSamples = 0;
    slowSince = null;
  }

  void setMode(TravelMode travel, int? steps) {
    mode = travel;
    stepsAtFast = steps;
    upgradeTo = null;
    upgradeSamples = 0;
    slowSince = null;
  }

  void reset() {
    moving = null;
    mode = null;
    speedKmh = null;
    stoppedAt = null;
    pausedAt = null;
    slowSince = null;
    stepsAtFast = null;
    fastSamples = 0;
    slowSamples = 0;
    upgradeTo = null;
    upgradeSamples = 0;
  }
}
