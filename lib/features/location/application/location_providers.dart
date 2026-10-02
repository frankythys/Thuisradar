import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
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

/// Realtime: laatste locatie van elk gezinslid.
final familyLocationsProvider = StreamProvider.family<List<MemberLocation>, String>(
  (ref, familyId) => ref.watch(locationRepositoryProvider).watchFamily(familyId),
);
