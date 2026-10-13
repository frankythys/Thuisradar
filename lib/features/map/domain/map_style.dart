/// Vanaf dit zoomniveau (straatniveau) toont de kaart automatisch satelliet.
const kAutoSatelliteZoom = 18.0;

/// Satelliet of gewone kaart?
///
/// [choice] is de keuze met de kaartknop: `null` = automatisch (satelliet op
/// straatniveau), anders wint de keuze, ook ingezoomd.
bool showsSatellite({required bool? choice, required double zoom}) => choice ?? zoom >= kAutoSatelliteZoom;
