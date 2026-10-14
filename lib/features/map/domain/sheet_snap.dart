/// Waar het ledenpaneel naartoe klikt nadat je het loslaat, als fractie van
/// de schermhoogte. Puur: geen Flutter.
///
/// Onder de gewone stand ([rest]: gezinsnaam en knoppen zichtbaar) zijn er
/// enkel twee standen: [rest] of helemaal laag ([peek]: alleen de greep). Het
/// paneel blijft daar nooit half hangen. Boven [rest] blijft het vrij slepen,
/// dan geeft dit null.
///
/// [startedAbove]: de beweging begon boven de gewone stand. Dan stopt het
/// paneel eerst op [rest]; pas een volgende beweging naar beneden gaat naar
/// [peek]. Zo zijn het echte standen.
double? sheetSnapTarget(
  double size, {
  required double peek,
  required double rest,
  bool startedAbove = false,
}) {
  const tolerance = 0.002;
  if (rest <= peek || size >= rest - tolerance) return null;
  if (startedAbove) return rest;
  if (size <= peek + tolerance) return null;
  return size < (peek + rest) / 2 ? peek : rest;
}

/// Begint een beweging op [size] boven de gewone stand [rest]?
bool sheetAboveRest(double size, double rest) => size > rest + 0.002;
