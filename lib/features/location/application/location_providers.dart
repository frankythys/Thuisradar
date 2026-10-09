import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resilient_stream.dart';
import '../../../core/utils/resync_signal.dart';
import '../data/battery_source.dart';
import '../data/device_location_source.dart';
import '../data/location_repository.dart';
import '../domain/member_location.dart';
import 'location_tracker.dart';
import 'tracking_status.dart';

final deviceLocationSourceProvider = Provider<DeviceLocationSource>((ref) => DeviceLocationSource());

final batterySourceProvider = Provider<BatterySource>((ref) => BatterySource());

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(supabaseClientProvider)),
);

final locationTrackerProvider = NotifierProvider<LocationTracker, TrackingStatus>(LocationTracker.new);

/// Realtime: laatste locatie van elk gezinslid. Herstelt zichzelf als het
/// realtime-kanaal wegvalt en haalt vers op bij elk resync-signaal.
final familyLocationsProvider = StreamProvider.family<List<MemberLocation>, String>((ref, familyId) {
  final repository = ref.watch(locationRepositoryProvider);
  return resilientStream(
    () => repository.watchFamily(familyId),
    resync: ref.watch(resyncSignalProvider).stream,
    onError: (error) => debugPrint('Locatiestroom (realtime) fout: $error'),
  );
});
