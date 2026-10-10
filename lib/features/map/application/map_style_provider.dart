import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gewone kaart of satelliet (enkel met Google Maps). Onthouden tussen sessies.
class MapSatellite extends Notifier<bool> {
  static const _key = 'map_satellite';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    if (ref.mounted) state = saved;
  }

  Future<void> toggle() async {
    state = !state;
    await (await SharedPreferences.getInstance()).setBool(_key, state);
  }
}

final mapSatelliteProvider = NotifierProvider<MapSatellite, bool>(MapSatellite.new);
