import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/resilient_stream.dart';
import '../../../core/utils/resync_signal.dart';
import '../data/parked_car_repository.dart';
import '../domain/parked_car.dart';

final parkedCarRepositoryProvider = Provider<ParkedCarRepository>(
  (ref) => ParkedCarRepository(ref.watch(supabaseClientProvider)),
);

final familyParkedCarsProvider = StreamProvider.family<List<ParkedCar>, String>((ref, familyId) {
  final repository = ref.watch(parkedCarRepositoryProvider);
  return resilientStream(
    () => repository.watchFamily(familyId),
    resync: ref.watch(resyncSignalProvider).stream,
    onError: (error) => debugPrint('Parkeerplekkenstroom fout: $error'),
  );
});
