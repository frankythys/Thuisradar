/// Minimale en maximale duur waarin een marker naar een nieuw ontvangen punt
/// mag schuiven. Kort genoeg om bij te blijven, lang genoeg om niet te springen.
const markerMotionMin = Duration(milliseconds: 800);
const markerMotionMax = Duration(milliseconds: 2000);

/// Kiest de animatieduur tussen twee ontvangen punten op basis van hun
/// tijdsverschil, begrensd tussen [markerMotionMin] en [markerMotionMax].
Duration markerMotionDuration(DateTime previous, DateTime next) {
  final gap = next.difference(previous);
  if (gap <= markerMotionMin) return markerMotionMin;
  if (gap >= markerMotionMax) return markerMotionMax;
  return gap;
}

/// Lineaire interpolatie tussen twee coördinaten (t in 0..1). Puur, zodat de
/// marker alleen tussen échte ontvangen punten beweegt en nooit extrapoleert.
({double lat, double lng}) lerpCoordinate(
  ({double lat, double lng}) from,
  ({double lat, double lng}) to,
  double t,
) => (lat: from.lat + (to.lat - from.lat) * t, lng: from.lng + (to.lng - from.lng) * t);
