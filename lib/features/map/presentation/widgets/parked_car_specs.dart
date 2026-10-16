import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../parked_car/domain/parked_car.dart';
import '../../../parked_car/presentation/parked_car_marker.dart';
import '../../domain/marker_nudge.dart';
import 'map_marker_spec.dart';

/// Autopinnen voor de kaart. Uitgezoomd kan een auto op het scherm over het
/// huis of een gezinslid vallen: dan schuift de pin net opzij ([nudgeClear]).
/// Ingezoomd is er ruimte genoeg en staat hij op zijn echte plek.
/// [obstacles] zijn schermrechthoeken (px) die vrij moeten blijven.
List<MapMarkerSpec> parkedCarSpecs(
  BuildContext context, {
  required MapCamera camera,
  required List<ParkedCar> cars,
  required Map<String, String> names,
  required List<Rect> obstacles,
  ValueChanged<ParkedCar>? onTap,
}) {
  if (cars.isEmpty) return const [];
  final tokens = context.tokens;
  final width = tokens.spaceXxl * 2 + tokens.spaceMd + tokens.spaceSm;
  final height = tokens.spaceXxl + tokens.spaceMd + tokens.spaceSm;
  final taken = [...obstacles];
  final specs = <MapMarkerSpec>[];
  for (final car in cars) {
    final point = LatLng(car.latitude, car.longitude);
    final screen = camera.latLngToScreenOffset(point);
    // De pin hangt onder zijn punt (uitlijning onderaan).
    final rect = Rect.fromLTWH(screen.dx - width / 2, screen.dy, width, height);
    final shift = nudgeClear(rect, taken);
    // Volgende auto's houden ook deze auto vrij.
    taken.add(rect.shift(shift));
    final name = names[car.userId] ?? context.l10n.commonMember;
    final tap = onTap == null ? null : () => onTap(car);
    specs.add(
      MapMarkerSpec(
        id: 'parked_car_${car.userId}',
        point: point,
        width: width,
        height: height,
        alignment: Alignment(2 * shift.dx / width, 1 + 2 * shift.dy / height),
        onTap: tap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: ParkedCarMarker(name: name),
        ),
        imageKey: name,
      ),
    );
  }
  return specs;
}
