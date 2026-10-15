/// Wat de bewegingssensoren van het toestel zelf denken dat iemand doet
/// (Android Activity Recognition, iPhone CoreMotion). Een extra signaal naast
/// GPS-snelheid en stappen; het zegt nooit welk soort voertuig (auto, bus,
/// trein): enkel "in een voertuig met motor". Puur: geen Flutter of Supabase.
enum MotionActivity {
  vehicle('vehicle'),
  bicycle('bicycle'),
  foot('foot'),
  still('still');

  const MotionActivity(this.dbValue);

  /// Waarde in de kolom `activity` (migratie 020).
  final String dbValue;

  /// Leest de kolomwaarde; onbekend of leeg wordt null.
  static MotionActivity? fromDb(Object? value) {
    for (final activity in values) {
      if (activity.dbValue == value) return activity;
    }
    return null;
  }
}

/// Eén herkenning van het toestel, met de zekerheid (0–100) en het tijdstip.
class ActivityReading {
  const ActivityReading(this.activity, this.confidence, this.at);

  /// null = het toestel wist het niet (kantelen, onbekend).
  final MotionActivity? activity;
  final int confidence;
  final DateTime at;
}

/// Onder deze zekerheid (%) telt een herkenning niet.
const kMinActivityConfidence = 70;

/// Ouder dan dit telt een herkenning niet meer. Het toestel meldt elke ±5 s;
/// bij stilstand pauzeert Android de meldingen, dan valt het signaal weg en
/// beslissen GPS en stappen alleen.
const kMaxActivityAge = Duration(seconds: 30);

/// De herkenning die bij een meting op [now] mee mag naar de server, of null
/// als ze te onzeker, te oud of onbekend is.
MotionActivity? currentActivity(ActivityReading? reading, DateTime now) {
  if (reading == null || reading.confidence < kMinActivityConfidence) return null;
  final age = now.difference(reading.at);
  // Een tijdstip ver in de toekomst is een verkeerde klok, niet te vertrouwen.
  if (age > kMaxActivityAge || age < const Duration(seconds: -10)) return null;
  return reading.activity;
}
