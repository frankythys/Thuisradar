/// Waar het ledenpaneel naartoe klikt nadat je het loslaat, als fractie van
/// de schermhoogte. Puur: geen Flutter.
///
/// Onder de gewone stand ([rest]: gezinsnaam en knoppen zichtbaar) zijn er
/// enkel twee standen: [rest] of helemaal laag ([peek]: alleen de greep). Het
/// paneel blijft daar nooit half hangen. Boven [rest] blijft het vrij slepen,
/// dan geeft dit null.
double? sheetSnapTarget(double size, {required double peek, required double rest}) {
  const tolerance = 0.002;
  if (rest <= peek || size <= peek + tolerance || size >= rest - tolerance) return null;
  return size < (peek + rest) / 2 ? peek : rest;
}
