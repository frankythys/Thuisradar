import '../../location/domain/motion_filter.dart';
import '../../location/domain/step_count.dart';
import '../../location/domain/track_point.dart';
import '../../location/domain/travel_mode.dart';

/// Vanaf deze snelheid (km/u) rijdt of fietst iemand; eronder is het te voet
/// (of stilstaan).
const _vehicleKmh = kBikeAverageKmh;

/// Een stuk te voet binnen een verplaatsing wordt een eigen wandeling als het
/// minstens zo lang duurt én zo ver van zijn begin komt. Korter is een rood
/// licht, file of parkeren: dat blijft bij de rit.
const _minFootLeg = Duration(seconds: 60);
const _minFootReachMeters = 80.0;

/// Gaf het toestel stappen mee, dan moet een stuk te voet er ook echt zoveel
/// hebben (per seconde); anders is het file aan wandeltempo.
const _minStepsPerSecond = 0.6;

/// Splitst één verplaatsing in delen per vervoermiddel: met de auto naar de
/// parking, dan te voet naar de werf is een rit én een wandeling. Zonder
/// splitsen werd alles één "rit": een stop korter dan 5 minuten (uitstappen)
/// beëindigt een verplaatsing niet.
///
/// Elk volgend deel begint op het laatste punt van het vorige, zodat er geen
/// afstand verloren gaat. Puur: geen Flutter of Supabase.
List<List<TrackPoint>> splitByTravelMode(List<TrackPoint> track) {
  if (track.length < 3) return [track];
  // Aaneengesloten reeksen van dezelfde soort (voertuig of te voet).
  final runs = <List<TrackPoint>>[];
  bool? vehicleRun;
  for (final point in track) {
    final vehicle = _isVehicle(point);
    if (runs.isEmpty || vehicle != vehicleRun) {
      runs.add([point]);
      vehicleRun = vehicle;
    } else {
      runs.last.add(point);
    }
  }
  // Enkel echte stukken te voet of met een voertuig splitsen af; korte
  // stukjes (rood licht, één snelheidspiek) horen bij het deel errond.
  final legs = <List<TrackPoint>>[];
  bool? footLeg;
  for (final run in runs) {
    final foot = _isVehicle(run.first) ? (_isRealRide(run) ? false : null) : (_isRealWalk(run) ? true : null);
    if (legs.isEmpty) {
      legs.add([...run]);
      footLeg = foot;
    } else if (foot == null || footLeg == null || foot == footLeg) {
      legs.last.addAll(run);
      footLeg ??= foot;
    } else {
      legs.add([legs.last.last, ...run]);
      footLeg = foot;
    }
  }
  return legs;
}

bool _isVehicle(TrackPoint point) {
  final speed = point.speedMps;
  return speed != null && speed.isFinite && speed * 3.6 >= _vehicleKmh;
}

/// Een stuk met voertuigsnelheid telt pas als het een halve minuut duurt;
/// korter is een GPS-piek of even een sprintje.
bool _isRealRide(List<TrackPoint> run) =>
    run.last.recordedAt.difference(run.first.recordedAt) >= const Duration(seconds: 30);

bool _isRealWalk(List<TrackPoint> run) {
  final duration = run.last.recordedAt.difference(run.first.recordedAt);
  if (duration < _minFootLeg) return false;
  final start = run.first;
  final reach = run
      .map((p) => distanceMeters(start.latitude, start.longitude, p.latitude, p.longitude))
      .fold(0.0, (a, b) => a > b ? a : b);
  if (reach < _minFootReachMeters) return false;
  final steps = stepsAlong(run);
  return steps == null || steps >= duration.inSeconds * _minStepsPerSecond;
}
