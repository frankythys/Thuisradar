import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gewone kaart bij opstart; de handmatige keuze geldt voor deze sessie.
class MapSatellite extends Notifier<bool> {
  static const _key = 'map_satellite';

  @override
  bool build() {
    return false;
  }

  Future<void> toggle() async {
    state = !state;
    await (await SharedPreferences.getInstance()).setBool(_key, state);
  }
}

final mapSatelliteProvider = NotifierProvider<MapSatellite, bool>(MapSatellite.new);
