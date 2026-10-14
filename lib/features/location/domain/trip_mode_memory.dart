import 'member_location.dart';
import 'motion_filter.dart' show kMovingSpeedMps;
import 'travel_mode.dart';
import 'trip_hint.dart';

/// Houdt per lid een rustige weergavestatus bij over meerdere metingen heen.
/// Enkel weergave: GPS en ritgeschiedenis blijven origineel.
///
/// De stappenteller is het sterkste bewijs: lopen de stappen op, dan wandelt
/// iemand; beweegt iemand zonder stappen, dan zit hij in een voertuig (ook in
/// de file aan 5 km/u). Gemeten op 14 oktober: in de auto bleef de teller een
/// uur op hetzelfde getal, te voet liep hij ±8 stappen per 5 s op.
///
/// - Onderweg en stilstaand volgen meteen de meting: het toestel bevestigt
///   beweging zelf al met twee metingen.
/// - Een voertuig blijft onthouden tijdens verkeerslicht en file, tot iemand
///   echt uitstapt (stappen) of [parkedAfter] stilstaat.
/// - Een voertuig is een auto, tenzij de rit [_bikeAfterSamples] metingen
///   lang onder [_carKmh] blijft aan fietstempo; een auto die al eens
///   duidelijk snel ging, wordt nooit meer een fiets.
/// - Zonder stappenteller: zoals vroeger op snelheid ([kBikeAverageKmh]).
class TripModeMemory {
  final _members = <String, _Trip>{};

  /// Zo lang stilstaan beëindigt een rit (met stappenteller; zonder: korter).
  static const parkedAfter = Duration(minutes: 5);
  static const _parkedWithoutSteps = Duration(seconds: 90);

  /// Langer zonder meting: de geschiedenis telt niet meer.
  static const _gapReset = Duration(seconds: 90);

  /// Boven deze snelheid (km/u) bewijzen stappen geen wandeling (schokken op
  /// de fiets of in de auto).
  static const _maxStepKmh = 20;

  /// Eén meting vanaf [_surelyCarKmh], of twee op rij vanaf [_carKmh]: auto.
  static const _carKmh = 30;
  static const _surelyCarKmh = 35;

  /// Een fiets: zoveel metingen onderweg (±3 min), het grootste deel vanaf
  /// [_bikeMinKmh], en nooit een auto-snelheid.
  static const _bikeAfterSamples = 36;
  static const _bikeMinKmh = 10;

  List<MemberLocation> update(List<MemberLocation> locations) {
    final present = locations.map((location) => location.userId).toSet();
    _members.removeWhere((id, _) => !present.contains(id));
    return [for (final location in locations) _update(location)];
  }

  MemberLocation _update(MemberLocation location) {
    final trip = _members.putIfAbsent(location.userId, _Trip.new);
    final previous = trip.updatedAt;
    if (previous != null && !location.updatedAt.isAfter(previous)) return _withHint(location, trip);
    if (previous != null && location.updatedAt.difference(previous) > _gapReset) trip.reset();
    trip.updatedAt = location.updatedAt;

    final speed = location.speedMps;
    final valid = speed != null && speed.isFinite && speed >= 0 && speed <= 70;
    final onFoot = trip.steps.onFoot(location.updatedAt, location.steps);
    if (valid) _apply(trip, speed, location.updatedAt, onFoot);
    return _withHint(location, trip);
  }

  MemberLocation _withHint(MemberLocation location, _Trip trip) {
    final hint = trip.hint;
    return hint == null ? location : location.copyWith(tripHint: hint);
  }

  void _apply(_Trip trip, double speed, DateTime at, bool? onFoot) {
    if (speed < kMovingSpeedMps) {
      trip.moving = false;
      trip.stoppedAt ??= at;
      final parked = at.difference(trip.stoppedAt!) >= (trip.steps.known ? parkedAfter : _parkedWithoutSteps);
      if (onFoot == true || parked) trip.leaveVehicle();
      return;
    }
    final kmh = (speed * 3.6).round();
    trip
      ..moving = true
      ..stoppedAt = null
      ..speedKmh = kmh;
    if (onFoot == true && kmh < _maxStepKmh) {
      trip
        ..leaveVehicle()
        ..mode = TravelMode.walk;
      return;
    }
    // Zonder stappen in beweging, of te snel om te wandelen: een voertuig.
    final inVehicle = trip.vehicle != null || onFoot == false || kmh >= kBikeAverageKmh;
    if (!inVehicle) {
      trip.mode = TravelMode.walk;
      return;
    }
    _drive(trip, kmh);
  }

  void _drive(_Trip trip, int kmh) {
    trip.vehicle ??= TravelMode.car;
    trip.vehicleSamples++;
    if (kmh >= _bikeMinKmh) trip.briskSamples++;
    if (kmh >= _surelyCarKmh || (kmh >= _carKmh && trip.lastKmh >= _carKmh)) {
      trip
        ..carSure = true
        ..vehicle = TravelMode.car;
    } else if (!trip.carSure &&
        trip.vehicleSamples >= _bikeAfterSamples &&
        trip.briskSamples * 10 >= trip.vehicleSamples * 6) {
      trip.vehicle = TravelMode.bike;
    }
    trip
      ..lastKmh = kmh
      ..mode = trip.vehicle;
  }
}

class _Trip {
  DateTime? updatedAt;
  bool? moving;
  TravelMode? mode;
  int? speedKmh;
  DateTime? stoppedAt;
  final steps = StepWindow();

  /// Het voertuig van deze rit (auto of fiets), null = te voet of onbekend.
  TravelMode? vehicle;
  bool carSure = false;
  int vehicleSamples = 0;
  int briskSamples = 0;
  int lastKmh = 0;

  TripHint? get hint => moving == null
      ? null
      : TripHint(moving: moving!, mode: mode ?? TravelMode.walk, speedKmh: moving! ? speedKmh : null);

  void leaveVehicle() {
    vehicle = null;
    carSure = false;
    vehicleSamples = 0;
    briskSamples = 0;
    lastKmh = 0;
  }

  void reset() {
    moving = null;
    mode = null;
    speedKmh = null;
    stoppedAt = null;
    steps.clear();
    leaveVehicle();
  }
}

/// Zet de stappenteller van de laatste seconden om in "te voet" of niet.
class StepWindow {
  /// Vergelijk met een meting tussen [_minGap] en [_window] geleden.
  static const _window = Duration(seconds: 20);
  static const _minGap = Duration(seconds: 4);

  /// Zoveel stappen of meer: te voet. Zoveel of minder: niet te voet.
  static const _onFootSteps = 6;
  static const _stillSteps = 2;

  final _samples = <({DateTime at, int steps})>[];

  /// Heeft dit toestel een stappenteller (ooit een waarde gestuurd)?
  bool known = false;

  /// Te voet volgens de stappen tot [at]; null als dat nog niet te zeggen is.
  bool? onFoot(DateTime at, int? steps) {
    if (steps == null) return null;
    known = true;
    // Een lagere teller (nieuwe dag, herstart) begint opnieuw.
    _samples.removeWhere((s) => at.difference(s.at) > _window || s.steps > steps);
    final reference = _samples.where((s) => at.difference(s.at) >= _minGap).firstOrNull;
    _samples.add((at: at, steps: steps));
    if (reference == null) return null;
    final walked = steps - reference.steps;
    if (walked >= _onFootSteps) return true;
    return walked <= _stillSteps ? false : null;
  }

  void clear() {
    _samples.clear();
    known = false;
  }
}
