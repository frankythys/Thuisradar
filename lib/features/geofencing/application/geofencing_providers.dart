import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/geofence_device_repository.dart';
import '../data/geofence_event_api.dart';
import '../data/geofence_store.dart';
import '../data/native_geofence_source.dart';
import 'geofence_reporter.dart';
import 'geofence_status.dart';
import 'geofence_sync.dart';

final nativeGeofenceSourceProvider = Provider<NativeGeofenceSource>((ref) => NativeGeofenceSource());

final geofenceStoreProvider = Provider<GeofenceStore>((ref) => GeofenceStore());

final geofenceDeviceRepositoryProvider = Provider<GeofenceDeviceRepository>(
  (ref) => GeofenceDeviceRepository(ref.watch(supabaseClientProvider)),
);

final geofenceReporterProvider = Provider<GeofenceReporter>(
  (ref) => GeofenceReporter(
    store: ref.watch(geofenceStoreProvider),
    api: GeofenceEventApi(ref.watch(supabaseClientProvider)),
  ),
);

/// Houdt de zones van Android gelijk met de plaatsen van het gezin.
final geofenceSyncProvider = NotifierProvider<GeofenceSync, GeofenceStatus>(GeofenceSync.new);
