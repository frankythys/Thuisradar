import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/application/map_providers.dart';

void main() {
  test('stilstaand sinds onthoudt de begintijd over nieuwe uploads heen', () async {
    final updates = StreamController<List<MemberLocation>>();
    addTearDown(updates.close);
    final container = ProviderContainer(
      overrides: [familyLocationsProvider.overrideWith((ref, familyId) => updates.stream)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(stationarySinceProvider('fam-since'), (_, _) {});
    addTearDown(subscription.close);

    MemberLocation at(int second) => MemberLocation(
      userId: 'u1',
      familyId: 'fam-since',
      latitude: 51.0,
      longitude: 4.0,
      updatedAt: DateTime(2026, 10, 11, 13, 0, second),
    );

    for (final second in [0, 15, 30]) {
      updates.add([at(second)]);
      await pumpEventQueue();
      container.read(stationarySinceProvider('fam-since'));
    }

    expect(container.read(stationarySinceProvider('fam-since'))['u1'], DateTime(2026, 10, 11, 13));
  });
}
