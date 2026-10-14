import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_style.dart';

/// Keuze met de kaartknop: `null` = automatisch (zie [showsSatellite]),
/// `true` = satelliet, `false` = gewone kaart. Geldt voor deze sessie; bij
/// opstart weer automatisch.
class MapSatellite extends Notifier<bool?> {
  @override
  bool? build() => null;

  void choose({required bool satellite}) => state = satellite;
}

final mapSatelliteProvider = NotifierProvider<MapSatellite, bool?>(MapSatellite.new);
