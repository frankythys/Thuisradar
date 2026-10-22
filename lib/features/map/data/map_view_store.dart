import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/map_view.dart';

/// Onthoudt op dit toestel waar de kaart laatst stond, zodat ze bij de
/// volgende start meteen daar opent.
class MapViewStore {
  static const _key = 'map_last_view';

  Future<MapView?> read() async => MapView.decode((await SharedPreferences.getInstance()).getString(_key));

  Future<void> write(MapView view) async =>
      (await SharedPreferences.getInstance()).setString(_key, view.encode());
}

final mapViewStoreProvider = Provider((ref) => MapViewStore());

/// De bij het opstarten gelezen kaartpositie; `main.dart` vult die in.
final savedMapViewProvider = Provider<MapView?>((ref) => null);
