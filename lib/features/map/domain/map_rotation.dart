/// Vanaf deze afwijking (graden) staat de kaart zichtbaar gedraaid en toont
/// de kompasknop zich.
const kNorthTolerance = 0.5;

/// Draaiing in graden, teruggebracht tot -180..180. Terug naar het noorden
/// draaien neemt zo altijd de korte weg (350° wordt -10°, niet 350° terug).
double normalizedRotation(double degrees) {
  final wrapped = degrees % 360;
  return wrapped > 180 ? wrapped - 360 : wrapped;
}

/// Staat het noorden niet meer boven?
bool isRotated(double degrees) => normalizedRotation(degrees).abs() >= kNorthTolerance;
