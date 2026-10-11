/// Hoe iemand zich verplaatste. Enkel een schatting op basis van GPS-snelheid:
/// een trage autorit in de file of een snelle e-bike kan verkeerd vallen.
enum TravelMode {
  walk('Wandelen', 'wandeling', 'wandelingen'),
  bike('Fietsen', 'fietstocht', 'fietstochten'),
  car('Rijden', 'rit', 'ritten');

  const TravelMode(this.label, this.singular, this.plural);

  /// "Wandelen", "Fietsen" of "Rijden".
  final String label;

  /// "wandeling", "fietstocht" of "rit".
  final String singular;
  final String plural;

  String count(int n) => '$n ${n == 1 ? singular : plural}';
}

/// Vanaf deze snelheid (km/u) telt een meting als "snel" voor de auto.
const kCarSpeedKmh = 25.0;

/// Vanaf deze snelheid (km/u) telt een meting als fietsen i.p.v. wandelen.
/// Lopen (joggen, ±10 km/u) valt er net onder.
const kBikeSpeedKmh = 13.0;

/// Gemiddelde snelheid (km/u) waarboven het zeker geen wandeling meer is.
const kBikeAverageKmh = 9.0;

/// Een wandeling korter dan dit is geen wandeling maar GPS-ruis rond huis of
/// het stukje naar de auto.
const kMinWalkMeters = 300.0;

/// Schat het vervoermiddel van een verplaatsing van [meters] in [duration]
/// met de gemeten GPS-snelheden [speedsMps] (m/s; onbruikbare waarden mogen
/// erin zitten, die vallen weg). Puur: geen Flutter of Supabase.
///
/// Eén losse snelheidspiek bewijst niets: minstens twee metingen én een vijfde
/// van alle metingen moet boven de grens liggen (een fietser die even 27 km/u
/// bergaf gaat, blijft een fietser). De gemiddelde snelheid (afstand / tijd)
/// vangt de gevallen zonder bruikbare GPS-snelheid op.
TravelMode classifyTravel({
  required double meters,
  required Duration duration,
  required Iterable<double?> speedsMps,
}) {
  final speeds = [
    for (final speed in speedsMps)
      if (speed != null && speed.isFinite && speed >= 0 && speed <= 70) speed * 3.6,
  ];
  final seconds = duration.inMilliseconds / 1000;
  final average = seconds > 0 ? meters / seconds * 3.6 : 0.0;
  bool mostly(double kmh) {
    final count = speeds.where((speed) => speed >= kmh).length;
    return count >= 2 && count >= speeds.length * 0.2;
  }

  if (mostly(kCarSpeedKmh) || average >= kCarSpeedKmh) return TravelMode.car;
  if (mostly(kBikeSpeedKmh) || average >= kBikeAverageKmh) return TravelMode.bike;
  return TravelMode.walk;
}

/// Gemiddelde snelheid in km/u, of null zonder duur.
double? averageSpeedKmh(double? meters, Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  if (meters == null || seconds <= 0) return null;
  return meters / seconds * 3.6;
}
