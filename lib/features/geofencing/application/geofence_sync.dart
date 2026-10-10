import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../profile/application/profile_providers.dart';
import '../data/native_geofence_source.dart';
import '../domain/geofence_zone.dart';
import 'geofence_callback.dart';
import 'geofence_status.dart';
import 'geofencing_providers.dart';

/// Registreert de plaatsen van het gezin als zones bij Android, zodat het
/// toestel zelf aankomst/vertrek meldt, ook als de app dicht is of slaapt.
///
/// Start en stopt samen met het delen van de locatie. Bij elke wijziging van
/// de plaatsen (toevoegen, verschuiven, straal, verwijderen) worden enkel de
/// gewijzigde zones opnieuw geregistreerd.
class GeofenceSync extends Notifier<GeofenceStatus> {
  String? _userId;
  String? _familyId;
  int _generation = 0;

  /// Heeft Android de zones sinds deze start echt aanvaard? De lijst van de
  /// plugin onthoudt enkel wat ooit lukte; [NativeGeofenceSource.recreateAll]
  /// meldt geen weigering. Daarom bij de eerste sync alles opnieuw aanmelden.
  bool _confirmed = false;
  ProviderSubscription<AsyncValue<List<Place>>>? _places;
  Future<void> _work = Future<void>.value();

  NativeGeofenceSource get _native => ref.read(nativeGeofenceSourceProvider);

  @override
  GeofenceStatus build() {
    ref.onDispose(_detach);
    return GeofenceStatus.idle;
  }

  Future<void> start({required String userId, required String familyId}) async {
    if (_places != null && _userId == userId && _familyId == familyId) return;
    _detach();
    final generation = ++_generation;
    _confirmed = false;
    _userId = userId;
    _familyId = familyId;

    if (!await ref.read(profilePreferencesProvider).sharing(userId)) {
      if (ref.mounted && generation == _generation) await stop();
      return;
    }
    try {
      await _native.initialize();
      await _native.recreateAll();
      final key = await ref.read(geofenceStoreProvider).ensureDeviceKey();
      await ref.read(geofenceDeviceRepositoryProvider).register(key);
    } on PostgrestException catch (error) {
      debugPrint('Zonebewaking: toestel registreren mislukt ($error) — migratie 014 gedraaid?');
      if (ref.mounted && generation == _generation) state = GeofenceStatus.notConfigured;
      return;
    } on Object catch (error) {
      debugPrint('Zonebewaking starten mislukt: $error');
      if (ref.mounted && generation == _generation) state = GeofenceStatus.error;
      return;
    }
    if (!ref.mounted || generation != _generation) return;

    unawaited(ref.read(geofenceReporterProvider).flush().catchError((Object e) => <String>[]));
    _places = ref.listen<AsyncValue<List<Place>>>(familyPlacesProvider(familyId), (_, next) {
      final places = next.value;
      if (places != null) _enqueue(() => _sync(places, generation));
    }, fireImmediately: true);
  }

  /// Terug in de app (bv. na "Altijd toestaan" in de instellingen): liep het
  /// eerder mis, dan opnieuw proberen. Zo hoeft de app niet herstart te worden.
  Future<void> retry() async {
    final userId = _userId;
    final familyId = _familyId;
    if (userId == null || familyId == null) return;
    if (state == GeofenceStatus.active || state == GeofenceStatus.idle) return;
    _detach();
    await start(userId: userId, familyId: familyId);
  }

  /// Delen uit, afmelden of gezin verlaten: alle zones weg en de sleutel
  /// ongeldig, zodat dit toestel niets meer meldt.
  Future<void> stop() async {
    _detach();
    _generation++;
    _userId = null;
    _familyId = null;
    state = GeofenceStatus.idle;
    final store = ref.read(geofenceStoreProvider);
    try {
      for (final id in (await _native.registeredIds()).where(GeofenceZone.isOurs)) {
        await _native.remove(id);
      }
    } on Object catch (error) {
      debugPrint('Zones verwijderen mislukt: $error');
    }
    try {
      final key = await store.deviceKey();
      if (key != null) await ref.read(geofenceDeviceRepositoryProvider).unregister(key);
    } on Object catch (error) {
      debugPrint('Toestelsleutel afmelden mislukt: $error');
    }
    await store.clear();
  }

  void _enqueue(Future<void> Function() job) {
    _work = _work.then((_) => job()).catchError((Object error) => debugPrint('Zonebewaking: $error'));
  }

  Future<void> _sync(List<Place> places, int generation) async {
    if (!ref.mounted || generation != _generation) return;
    try {
      final plan = planGeofenceSync(registeredIds: await _native.registeredIds(), places: places);
      for (final id in plan.toRemove) {
        await _native.remove(id);
      }
      final toAdd = _confirmed ? plan.toAdd : [for (final place in places) GeofenceZone.fromPlace(place)];
      for (final zone in toAdd) {
        await _native.add(zone, onGeofenceTriggered);
      }
      if (ref.mounted && generation == _generation) {
        _confirmed = true;
        state = GeofenceStatus.active;
      }
    } on GeofencePermissionMissing {
      if (ref.mounted && generation == _generation) state = GeofenceStatus.permissionMissing;
    } on GeofenceUnavailable {
      if (ref.mounted && generation == _generation) state = GeofenceStatus.unavailable;
    } on Object catch (error) {
      debugPrint('Zones bijwerken mislukt: $error');
      if (ref.mounted && generation == _generation) state = GeofenceStatus.error;
    }
  }

  void _detach() {
    _places?.close();
    _places = null;
  }
}
