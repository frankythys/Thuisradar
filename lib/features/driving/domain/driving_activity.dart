import '../../location/domain/motion_filter.dart';
import '../../location/domain/step_count.dart';
import '../../location/domain/timeline.dart';
import '../../location/domain/track_point.dart';
import '../../location/domain/track_segments.dart';
import '../../location/domain/travel_mode.dart';
import 'travel_legs.dart';

/// Soort activiteit in de dagtijdlijn van een gezinslid.
enum DrivingActivityKind { trip, stay }

/// Eén activiteit op een dag: een verplaatsing (rit) of een verblijf op één
/// plek. Puur model, los van Flutter en Supabase, zodat het te testen is.
class DrivingActivity {
  const DrivingActivity({
    required this.kind,
    required this.start,
    required this.end,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.fromLatitude,
    this.fromLongitude,
    this.placeName,
    this.mode = TravelMode.car,
    this.steps,
  });

  final DrivingActivityKind kind;
  final DateTime start;
  final DateTime end;

  /// Aankomstpunt van een rit, of het middelpunt van een verblijf.
  final double latitude;
  final double longitude;

  /// Afgelegde afstand in meter (enkel bij een rit).
  final double? distanceMeters;

  /// Vertrekpunt van een rit (de vorige stop), indien bekend.
  final double? fromLatitude;
  final double? fromLongitude;

  /// Naam van een eigen plaats bij een verblijf, indien binnen een zone.
  final String? placeName;

  /// Geschat vervoermiddel van een rit; zonder betekenis bij een verblijf.
  final TravelMode mode;

  /// Gezette stappen tijdens een wandeling, als het toestel ze meegaf.
  final int? steps;

  Duration get duration => end.difference(start);

  /// Gemiddelde snelheid in km/u (enkel bij een rit met gekende afstand).
  double? get averageKmh =>
      kind == DrivingActivityKind.trip ? averageSpeedKmh(distanceMeters, duration) : null;
}

/// Een rit is een aaneengesloten reeks metingen waarin de wagen rijdt. De reeks
/// stopt waar het toestel minstens [stillAfter] op dezelfde plek bleef (een
/// stop) of waar de metingen wegvallen ([maxGap]). Zo wordt een dag met veel
/// korte stops niet één "rit" van uren en wordt er nooit een gat overbrugd.
/// Puur: geen Flutter of Supabase. Resultaat is chronologisch (oudste eerst).
List<List<TrackPoint>> buildTripTracks(
  List<TrackPoint> points, {
  Duration stillAfter = kMinStop,
  double stillRadiusMeters = kStopRadiusMeters,
  Duration maxGap = kMaxTrackGap,
}) {
  final trips = <List<TrackPoint>>[];
  var current = <TrackPoint>[];
  TrackPoint? still;
  // Eerste meting buiten de stilstandstraal. Pas een tweede meting op rij
  // buiten de straal bewijst vertrek: één binnenshuis-uitschieter mag de
  // stilstand niet resetten, anders werd een avond thuis een "rit".
  TrackPoint? leaving;

  void close() {
    if (current.length > 1) trips.add(current);
    current = <TrackPoint>[];
  }

  for (final point in points) {
    if (current.isNotEmpty && point.recordedAt.difference(current.last.recordedAt) > maxGap) {
      close();
      still = null;
      leaving = null;
    }
    if (still == null) {
      still = point;
    } else if (_legMeters(still, point) > stillRadiusMeters && leaving == null) {
      leaving = point;
    } else {
      if (leaving != null && _legMeters(still, point) > stillRadiusMeters) {
        // Hij rijdt echt: de stilte begint opnieuw te tellen vanaf het vertrek.
        still = leaving;
      }
      leaving = null;
      if (_legMeters(still, point) > stillRadiusMeters) {
        leaving = point;
      } else if (point.recordedAt.difference(still.recordedAt) >= stillAfter) {
        // Lang genoeg op dezelfde plek: de rit is afgelopen.
        close();
        still = point;
      }
    }
    current.add(point);
  }
  close();
  return trips;
}

/// Een kort meetgat vlak voor de aankomst (een tunnel, een parkeergarage, even
/// geen signaal) hoort nog bij de rit. Eindigt een rit minder dan [kArrivalGap]
/// voor een verblijf begint, dan is dat verblijf de bestemming: de rit krijgt de
/// plek, de aankomsttijd en de laatste afstand tot daar. Grotere gaten (toestel
/// uit) overbruggen we niet — dan blijven het losse ritten.
const kArrivalGap = Duration(minutes: 20);

/// De activiteiten van één dag: verblijven uit de tijdlijn en verplaatsingen
/// (te voet, met de fiets of de auto) uit de echte metingen, chronologisch
/// (oudste eerst). Een verplaatsing met minder dan [minTripMeters] beweging is
/// ruis en valt weg; een wandeling moet minstens [minWalkMeters] lang zijn.
List<DrivingActivity> buildDayActivities(
  List<TimelineEntry> entries,
  List<TrackPoint> points, {
  double minTripMeters = 100,
}) {
  final activities = <DrivingActivity>[];
  final stops = <TimelineEntry>[];
  for (final entry in entries) {
    if (entry.kind != TimelineKind.stop) continue;
    stops.add(entry);
    activities.add(
      DrivingActivity(
        kind: DrivingActivityKind.stay,
        start: entry.start,
        end: entry.end,
        latitude: entry.latitude,
        longitude: entry.longitude,
        placeName: entry.placeName,
      ),
    );
  }
  final clean = withoutSpikes(points);
  // Eerst per vervoermiddel splitsen (rijden naar de parking, dan te voet
  // verder), dan per deel enkel het stuk waarin echt bewogen wordt: zonder de
  // minuten stilstaan ervoor (nog thuis) en erna (al aangekomen). Een spoor
  // dat alleen uit stilstaan bestaat, is geen verplaatsing.
  final legs = [
    for (final raw in buildTripTracks(clean))
      for (final leg in splitByTravelMode(raw)) trimStill(leg),
  ];
  for (final track in legs) {
    if (track.length < 2 || trackMeters(track) < minTripMeters) continue;
    // Een geïsoleerde uitschieter die door de tijdlijn in een verblijf werd
    // samengevoegd is geen rit. Echte rondritten blijven aparte verplaatsingen,
    // net als een trage wandeling die de tijdlijn als verblijf zag (de
    // bewegingsfilter bevestigde toen wél beweging).
    if (!_confirmedMoving(track) &&
        stops.any(
          (stop) => !track.first.recordedAt.isBefore(stop.start) && !track.last.recordedAt.isAfter(stop.end),
        )) {
      continue;
    }
    final arrival = _arrivalStop(track.last, stops, clean);
    final last = track.last;
    final bridged = arrival != null && arrival.start.isAfter(last.recordedAt);
    final endLatitude = arrival?.latitude ?? last.latitude;
    final endLongitude = arrival?.longitude ?? last.longitude;
    final endTime = bridged ? arrival.start : last.recordedAt;

    var meters = trackMeters(track);
    if (bridged) {
      meters += distanceMeters(last.latitude, last.longitude, endLatitude, endLongitude);
    }
    if (meters < minTripMeters) continue;
    final mode = classifyTravel(
      meters: meters,
      duration: endTime.difference(track.first.recordedAt),
      speedsMps: track.map((point) => point.speedMps),
    );
    // Rondlopen in huis of het stukje naar de auto is geen wandeling, tenzij
    // de stappenteller bewijst dat er echt gestapt werd.
    final steps = mode == TravelMode.walk ? stepsAlong(track) : null;
    if (mode == TravelMode.walk && meters < minWalkMeters(steps)) continue;
    activities.add(
      DrivingActivity(
        kind: DrivingActivityKind.trip,
        start: track.first.recordedAt,
        end: endTime,
        latitude: endLatitude,
        longitude: endLongitude,
        distanceMeters: meters,
        fromLatitude: track.first.latitude,
        fromLongitude: track.first.longitude,
        mode: mode,
        steps: steps,
      ),
    );
  }
  return _withoutOverlap(activities)..sort((a, b) => a.start.compareTo(b.start));
}

/// Een verblijf begint pas als de verplaatsing ervoor gedaan is en stopt als
/// de volgende begint: de tijdlijn zag een trage wandeling soms al als
/// verblijf, met overlappende tijden als gevolg.
List<DrivingActivity> _withoutOverlap(List<DrivingActivity> activities) {
  final trips = [
    for (final a in activities)
      if (a.kind == DrivingActivityKind.trip) a,
  ];
  return [
    for (final activity in activities)
      if (activity.kind == DrivingActivityKind.trip) activity else ?_clipStay(activity, trips),
  ];
}

DrivingActivity? _clipStay(DrivingActivity stay, List<DrivingActivity> trips) {
  var start = stay.start;
  var end = stay.end;
  for (final trip in trips) {
    if (trip.start.isBefore(start) || trip.start == start) {
      if (trip.end.isAfter(start)) start = trip.end;
    } else if (trip.start.isBefore(end)) {
      end = trip.start;
    }
  }
  if (!end.isAfter(start)) return null;
  if (start == stay.start && end == stay.end) return stay;
  return DrivingActivity(
    kind: stay.kind,
    start: start,
    end: end,
    latitude: stay.latitude,
    longitude: stay.longitude,
    placeName: stay.placeName,
  );
}

/// Bevestigde de bewegingsfilter van het toestel minstens een minuut lang
/// beweging (positieve snelheid in het merendeel van de metingen)? Een
/// GPS-uitschieter heeft dat nooit.
bool _confirmedMoving(List<TrackPoint> track) {
  if (track.last.recordedAt.difference(track.first.recordedAt) < const Duration(minutes: 1)) return false;
  final moving = track.where((p) => (p.speedMps ?? 0) >= kMovingSpeedMps).length;
  return moving >= 6 && moving * 2 >= track.length;
}

/// De bestemming van een rit die eindigt op [last]:
/// - een verblijf dat al loopt op het moment van de laatste meting (de
///   tijdlijn zag de stop iets vroeger beginnen dan het getrimde ritspoor), of
/// - het eerste verblijf binnen [kArrivalGap] erna, maar enkel over een echt
///   meetgat (tunnel, parkeergarage): ligt er tussendoor een meting die niet
///   bij dat verblijf hoort, dan was er nog een andere verplaatsing of stop en
///   is dat verblijf niet de bestemming van deze rit.
TimelineEntry? _arrivalStop(TrackPoint last, List<TimelineEntry> stops, List<TrackPoint> clean) {
  TimelineEntry? arrival;
  for (final stop in stops) {
    final meters = distanceMeters(last.latitude, last.longitude, stop.latitude, stop.longitude);
    if (!stop.start.isAfter(last.recordedAt)) {
      if (!stop.end.isBefore(last.recordedAt) && meters <= kStopRadiusMeters) return stop;
      continue;
    }
    if (stop.start.difference(last.recordedAt) > kArrivalGap) continue;
    final seconds = stop.start.difference(last.recordedAt).inMilliseconds / 1000;
    if (meters > kStopRadiusMeters && meters / seconds > kMaxPlausibleSpeedMps) continue;
    if (_measuredElsewhere(clean, last.recordedAt, stop)) continue;
    if (arrival == null || stop.start.isBefore(arrival.start)) arrival = stop;
  }
  return arrival;
}

/// Ligt er tussen [after] en het begin van [stop] een meting buiten de
/// stopstraal van [stop]? [clean] is oudste eerst.
bool _measuredElsewhere(List<TrackPoint> clean, DateTime after, TimelineEntry stop) {
  var low = 0;
  var high = clean.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (clean[mid].recordedAt.isAfter(after)) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }
  for (var i = low; i < clean.length && clean[i].recordedAt.isBefore(stop.start); i++) {
    final point = clean[i];
    if (distanceMeters(point.latitude, point.longitude, stop.latitude, stop.longitude) > kStopRadiusMeters) {
      return true;
    }
  }
  return false;
}

/// Knipt het stilstaan aan begin en einde van een spoor weg: vertrek is de
/// laatste meting nog binnen [radiusMeters] van het beginpunt, aankomst de
/// eerste meting al binnen [radiusMeters] van het eindpunt.
///
/// Binnen die straal kan wel al bewogen zijn: te voet duurt 100 m ruim een
/// minuut. Metingen waar het toestel beweging meldde, of die gestaag van het
/// beginpunt weg (of naar het eindpunt toe) gaan, horen dus nog bij de
/// verplaatsing; anders miste elke wandeling 200 m en begon ze te laat.
List<TrackPoint> trimStill(List<TrackPoint> track, {double radiusMeters = kStopRadiusMeters}) {
  if (track.length < 2) return track;
  var first = 0;
  while (first + 1 < track.length && _legMeters(track.first, track[first + 1]) <= radiusMeters) {
    first++;
  }
  var last = track.length - 1;
  while (last - 1 > first && _legMeters(track.last, track[last - 1]) <= radiusMeters) {
    last--;
  }
  if (last > first) {
    while (first > 0 &&
        (_deviceMoving(track[first - 1]) || _steadyStep(track.first, track[first - 1], track[first]))) {
      first--;
    }
    while (last < track.length - 1 &&
        (_deviceMoving(track[last + 1]) || _steadyStep(track.last, track[last + 1], track[last]))) {
      last++;
    }
  }
  return track.sublist(first, last + 1);
}

/// Meldde de bewegingsfilter van het toestel hier beweging? Die bevestigt
/// pas na meerdere metingen én echte verplaatsing, dus GPS-ruis telt niet.
bool _deviceMoving(TrackPoint point) => (point.speedMps ?? 0) >= kMovingSpeedMps;

/// Ligt [far] gestaag verder van [anchor] dan [near], kort na elkaar gemeten
/// en minstens wandeltempo? Dan is het tussenstuk beweging, geen GPS-ruis.
bool _steadyStep(TrackPoint anchor, TrackPoint near, TrackPoint far) {
  final seconds = (far.recordedAt.difference(near.recordedAt).inMilliseconds / 1000).abs();
  if (seconds <= 0 || seconds > 30) return false;
  final gained = _legMeters(anchor, far) - _legMeters(anchor, near);
  return gained >= 3 && gained / seconds >= 0.5;
}

/// Afgelegde afstand langs een reeks metingen (haversine per been).
double trackMeters(List<TrackPoint> track) {
  var meters = 0.0;
  for (var index = 1; index < track.length; index++) {
    meters += _legMeters(track[index - 1], track[index]);
  }
  return meters;
}

double _legMeters(TrackPoint a, TrackPoint b) =>
    distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude);

/// De GPS-punten tussen vertrek en aankomst van [activity]: de echte route van
/// die rit, zodat de kaart op de rit zelf kan inzoomen. Zonder GPS-sprongen,
/// zodat er geen zigzag over de kaart loopt. Leeg voor een verblijf of als er
/// geen punten in dat tijdsvak vallen.
List<TrackPoint> activityTrack(DrivingActivity activity, List<TrackPoint> points) {
  if (activity.kind != DrivingActivityKind.trip) return const [];
  return [
    for (final point in withoutSpikes(points))
      if (!point.recordedAt.isBefore(activity.start) && !point.recordedAt.isAfter(activity.end)) point,
  ];
}

/// Alle ritten van een dag als routestukken, zonder het stilstaan ertussen.
/// Voor de dagkaart: rondlopen in een winkel of binnenshuis-GPS is geen route
/// en gaf een wirwar van lijnen op de plek waar je stond.
List<List<TrackPoint>> dayRoutes(List<TimelineEntry> entries, List<TrackPoint> points) => [
  for (final activity in buildDayActivities(entries, points))
    if (activity.kind == DrivingActivityKind.trip) ...splitTrackGaps(activityTrack(activity, points)),
];

/// Hoger dan dit (≈ 250 km/u) tussen twee metingen is geen rijden maar een
/// GPS-sprong (bv. even een zendmastpositie). Dezelfde grens als de
/// bewegingsfilter en de routekaart: met 45 m/s viel snel snelwegrijden plus
/// wat GPS-ruis al weg.
const kMaxPlausibleSpeedMps = 70.0;

/// Laat metingen weg die onmogelijk snel van de vorige wegspringen. Een sprong
/// heen en terug wordt zo één weggelaten punt i.p.v. twee lange lijnen.
/// Is de sprong juist de eerste meting (van de dag of na een meetgat), dan is
/// het anker zelf fout: past de volgende meting wel bij de huidige, dan valt
/// het anker weg in plaats van alle echte metingen erna.
List<TrackPoint> withoutSpikes(List<TrackPoint> track, {double maxSpeedMps = kMaxPlausibleSpeedMps}) {
  bool implausible(TrackPoint from, TrackPoint to) {
    final seconds = to.recordedAt.difference(from.recordedAt).inMilliseconds / 1000;
    if (seconds <= 0 || seconds > kMaxTrackGap.inSeconds) return false;
    final meters = _legMeters(from, to);
    return meters / seconds > maxSpeedMps && meters > kStopRadiusMeters;
  }

  final kept = <TrackPoint>[];
  final sorted = [
    for (final point in track)
      if (point.latitude.isFinite &&
          point.longitude.isFinite &&
          point.latitude.abs() <= 90 &&
          point.longitude.abs() <= 180)
        point,
  ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  for (var index = 0; index < sorted.length; index++) {
    final point = sorted[index];
    if (kept.isNotEmpty) {
      final previous = kept.last;
      if (!point.recordedAt.isAfter(previous.recordedAt)) continue;
      if (implausible(previous, point)) {
        final anchorStartsRun =
            kept.length == 1 ||
            previous.recordedAt.difference(kept[kept.length - 2].recordedAt) > kMaxTrackGap;
        final next = index + 1 < sorted.length ? sorted[index + 1] : null;
        if (anchorStartsRun &&
            next != null &&
            next.recordedAt.isAfter(point.recordedAt) &&
            !implausible(point, next)) {
          kept
            ..removeLast()
            ..add(point);
        }
        continue;
      }
    }
    kept.add(point);
  }
  return _withoutLoneOutliers(kept);
}

/// Binnenshuis springt de GPS soms één meting 100-200 m weg en meteen terug.
/// Dat is te traag voor de snelheidsgrens, maar het is geen beweging: de
/// buren liggen vlak bij elkaar en kort na elkaar. Zulke losse punten braken
/// een avond thuis op in stukjes (geen verblijf meer) en in spookritten.
/// Enkel binnen 45 s: rijdend meet het toestel elke 5 s, dus een echte
/// keerbeweging heeft altijd meerdere metingen ver weg, nooit één.
List<TrackPoint> _withoutLoneOutliers(List<TrackPoint> points) {
  const window = Duration(seconds: 45);
  return [
    for (var i = 0; i < points.length; i++)
      if (i == 0 ||
          i == points.length - 1 ||
          points[i + 1].recordedAt.difference(points[i - 1].recordedAt) > window ||
          _legMeters(points[i - 1], points[i + 1]) > kStopRadiusMeters ||
          _legMeters(points[i - 1], points[i]) <= kStopRadiusMeters ||
          _legMeters(points[i], points[i + 1]) <= kStopRadiusMeters)
        points[i],
  ];
}

/// Hoogste gemeten snelheid in km/u langs [track], of null zonder bruikbare
/// GPS-snelheid. Onzinwaarden (negatief, boven 70 m/s ≈ 250 km/u) tellen niet.
int? topSpeedKmh(List<TrackPoint> track) {
  bool usable(double? speed) => speed != null && speed.isFinite && speed >= 0 && speed <= 70;
  double? top;
  for (var index = 0; index < track.length; index++) {
    final speed = track[index].speedMps;
    if (!usable(speed)) continue;
    // Eén losse Doppler-piek ("max 216 km/u" tussen 50 en 60) telt niet: een
    // bruikbare buur moet minstens 60% van die snelheid halen.
    final neighbours = [
      if (index > 0 && usable(track[index - 1].speedMps)) track[index - 1].speedMps!,
      if (index + 1 < track.length && usable(track[index + 1].speedMps)) track[index + 1].speedMps!,
    ];
    if (neighbours.isNotEmpty && neighbours.every((other) => other < speed! * 0.6)) continue;
    if (top == null || speed! > top) top = speed;
  }
  return top == null ? null : (top * 3.6).round();
}
