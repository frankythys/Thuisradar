import 'track_point.dart';

/// Meer dan dit per seconde (ruim sprinttempo) is geen stappen tellen maar
/// een teller die versprong.
const _maxStepsPerSecond = 4.0;

/// Gezette stappen langs [points] (oudste eerst), of null als het toestel
/// geen stappen meegaf. De teller zelf is een totaal (sinds herstart of sinds
/// de app luistert): we tellen enkel de stijgingen tussen opeenvolgende
/// metingen op. Valt de teller terug (herstart) of springt hij onmogelijk
/// ver, dan telt dat stuk niet. Puur: geen Flutter of Supabase.
int? stepsAlong(List<TrackPoint> points) {
  TrackPoint? previous;
  int? total;
  for (final point in points) {
    final steps = point.steps;
    if (steps == null) continue;
    final before = previous?.steps;
    if (previous != null && before != null) {
      final gained = steps - before;
      final seconds = point.recordedAt.difference(previous.recordedAt).inMilliseconds / 1000;
      if (gained >= 0 && seconds > 0 && gained <= seconds * _maxStepsPerSecond) {
        total = (total ?? 0) + gained;
      } else {
        total ??= 0;
      }
    }
    previous = point;
  }
  return total;
}
