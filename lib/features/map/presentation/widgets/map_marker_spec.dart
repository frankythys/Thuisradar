import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Eén marker zoals de kaartlaag hem berekent, los van wie hem tekent:
/// flutter_map (als widget) of Google Maps (als afbeelding).
class MapMarkerSpec {
  const MapMarkerSpec({
    required this.id,
    required this.point,
    required this.width,
    required this.height,
    required this.child,
    this.alignment = Alignment.center,
    this.offset = Offset.zero,
    this.onTap,
    this.pulse,
  });

  /// Vaste sleutel per marker (lid, groep of ballon).
  final String id;
  final LatLng point;
  final double width;
  final double height;
  final Alignment alignment;

  /// Extra verschuiving bovenop de uitlijning (bv. de statusballon).
  final Offset offset;

  /// Wat er getekend wordt (zonder de verschuiving).
  final Widget child;

  /// Tik op de marker; ook gebruikt voor de onzichtbare tikvlakken boven
  /// Google Maps.
  final VoidCallback? onTap;

  /// Lichtkring rond het geselecteerde rondje. Google Maps tekent die als
  /// eigen cirkel onder de marker, zodat ze vloeiend kan pulseren.
  final PulseSpot? pulse;

  /// Als flutter_map-marker, met [child] of een vervangende inhoud.
  Marker toMarker({Widget? replaceChild}) {
    final content = replaceChild ?? child;
    return Marker(
      point: point,
      width: width,
      height: height,
      alignment: alignment,
      child: offset == Offset.zero ? content : Transform.translate(offset: offset, child: content),
    );
  }
}

/// Waar het rondje met lichtkring in het markervak staat.
class PulseSpot {
  const PulseSpot({required this.center, required this.radius});

  /// Midden van het rondje, vanaf de linkerbovenhoek van het vak.
  final Offset center;

  /// Straal van het rondje (met selectierand) in punten.
  final double radius;
}
