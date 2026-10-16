/// Vanaf deze zoom tekenen we de straal (perimeter) van een plaats. Verder
/// uitgezoomd blijft enkel het icoon: de cirkel is dan alleen ruis die over
/// pinnen en straten valt.
const kPlaceRadiusMinZoom = 16.0;

/// Toont de kaart de straal van plaatsen bij deze [zoom]?
bool showsPlaceRadius(double zoom) => zoom >= kPlaceRadiusMinZoom;
