import 'member_location.dart';
import 'motion_activity.dart';
import 'motion_filter.dart' show kMovingSpeedMps;
import 'step_window.dart';
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
/// - Met activiteitsherkenning van het toestel ([MemberLocation.activity],
///   feature flag): "voertuig" maakt meteen een auto (ook traag in de file),
///   "fiets" meteen een fiets tot [_maxBikeKmh] (e-bike, speed pedelec,
///   bergaf). Zonder stappen beslist "te voet" of "voertuig" ook over uit- of
///   instappen. Het signaal stuurt enkel bij: zonder herkenning blijft alles
///   zoals hierboven, er wordt nooit op gewacht.
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

  /// Sneller dan dit (km/u) is geen fiets, ook niet als het toestel dat zegt.
  static const _maxBikeKmh = 50;

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
    // De stappen gaan voor; zonder bruikbare stappen beslist de herkenning.
    final onFoot =
        trip.steps.onFoot(location.updatedAt, location.steps) ?? _onFootBySensor(location.activity);
    if (valid) _apply(trip, speed, location.updatedAt, onFoot, location.activity);
    return _withHint(location, trip);
  }

  MemberLocation _withHint(MemberLocation location, _Trip trip) {
    final hint = trip.hint;
    return hint == null ? location : location.copyWith(tripHint: hint);
  }

  static bool? _onFootBySensor(MotionActivity? activity) => switch (activity) {
    MotionActivity.foot => true,
    MotionActivity.vehicle || MotionActivity.bicycle => false,
    MotionActivity.still || null => null,
  };

  void _apply(_Trip trip, double speed, DateTime at, bool? onFoot, MotionActivity? activity) {
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
    // Trappen geeft soms ook stappen: zegt het toestel "fiets" aan fietstempo,
    // dan wint de fiets. Bij het uitstappen winnen de stappen wel, want de
    // herkenning loopt dan nog even achter.
    final pedalling = activity == MotionActivity.bicycle && kmh >= _bikeMinKmh;
    if (onFoot == true && kmh < _maxStepKmh && !pedalling) {
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
    _drive(trip, kmh, activity);
  }

  void _drive(_Trip trip, int kmh, MotionActivity? activity) {
    trip.vehicle ??= TravelMode.car;
    trip.vehicleSamples++;
    if (kmh >= _bikeMinKmh) trip.briskSamples++;
    final bySensor = switch (activity) {
      MotionActivity.vehicle => TravelMode.car,
      MotionActivity.bicycle when kmh <= _maxBikeKmh => TravelMode.bike,
      _ => null,
    };
    final carSpeed = kmh >= _surelyCarKmh || (kmh >= _carKmh && trip.lastKmh >= _carKmh);
    if (bySensor != null) {
      trip
        ..sensorVehicle = bySensor
        ..carSure = bySensor == TravelMode.car
        ..vehicle = bySensor;
    } else if (kmh > _maxBikeKmh || (carSpeed && trip.sensorVehicle != TravelMode.bike)) {
      // Een fiets volgens het toestel blijft een fiets aan 35 km/u; boven
      // [_maxBikeKmh] wint de snelheid toch.
      trip
        ..carSure = true
        ..sensorVehicle = null
        ..vehicle = TravelMode.car;
    } else if (!trip.carSure &&
        trip.sensorVehicle == null &&
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

  /// Voertuig volgens de activiteitsherkenning van het toestel, null = geen.
  TravelMode? sensorVehicle;
  int vehicleSamples = 0;
  int briskSamples = 0;
  int lastKmh = 0;

  TripHint? get hint => moving == null
      ? null
      : TripHint(moving: moving!, mode: mode ?? TravelMode.walk, speedKmh: moving! ? speedKmh : null);

  void leaveVehicle() {
    vehicle = null;
    carSure = false;
    sensorVehicle = null;
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
