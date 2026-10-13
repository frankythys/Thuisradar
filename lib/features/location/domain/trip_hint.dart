import 'travel_mode.dart';

/// Wat [TripModeMemory] over meerdere metingen heen besloot: onderweg of niet,
/// met welk vervoermiddel en welke snelheid er getoond wordt. Enkel voor de
/// weergave; nooit naar de database.
class TripHint {
  const TripHint({required this.moving, this.mode = TravelMode.walk, this.speedKmh});

  final bool moving;
  final TravelMode mode;

  /// Laatste geldige snelheid onderweg (km/u); terugval voor een meting zonder
  /// bruikbare snelheid of net onder de grens tijdens het afremmen.
  final int? speedKmh;

  @override
  bool operator ==(Object other) =>
      other is TripHint && other.moving == moving && other.mode == mode && other.speedKmh == speedKmh;

  @override
  int get hashCode => Object.hash(moving, mode, speedKmh);
}
