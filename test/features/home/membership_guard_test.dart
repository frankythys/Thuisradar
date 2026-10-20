import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/geofencing/application/geofence_status.dart';
import 'package:thuisradar/features/geofencing/application/geofence_sync.dart';
import 'package:thuisradar/features/geofencing/application/geofencing_providers.dart';
import 'package:thuisradar/features/home/application/membership_guard.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/application/location_tracker.dart';
import 'package:thuisradar/features/location/application/tracking_status.dart';

var _trackerStops = 0;
var _zoneStops = 0;

class _Tracker extends LocationTracker {
  @override
  TrackingStatus build() => TrackingStatus.idle;

  @override
  void stop({String? reason}) => _trackerStops++;
}

class _Zones extends GeofenceSync {
  @override
  GeofenceStatus build() => GeofenceStatus.idle;

  @override
  Future<void> stop() async => _zoneStops++;
}

const _me = FamilyMember(userId: 'liam', displayName: 'Liam', isOwner: false, colorIndex: 1);
const _papa = FamilyMember(userId: 'papa', displayName: 'Papa', isOwner: true, colorIndex: 0);

void main() {
  late StreamController<List<FamilyMember>> members;
  late int familyFetches;

  setUp(() {
    _trackerStops = 0;
    _zoneStops = 0;
    familyFetches = 0;
    members = StreamController<List<FamilyMember>>();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('liam'),
        familyMembersProvider('fam').overrideWith((ref) => members.stream),
        myFamilyProvider.overrideWith((ref) async {
          familyFetches++;
          return const Family(id: 'fam', name: 'Gezin', inviteCode: 'X');
        }),
        locationTrackerProvider.overrideWith(_Tracker.new),
        geofenceSyncProvider.overrideWith(_Zones.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(myFamilyProvider, (_, _) {});
    container.listen(membershipGuardProvider('fam'), (_, _) {});
  });

  test('zolang ik in de ledenlijst sta, blijft alles draaien', () async {
    members.add(const [_papa, _me]);
    await pumpEventQueue();

    expect(_trackerStops, 0);
    expect(_zoneStops, 0);
    expect(familyFetches, 1);
  });

  test('uit het gezin verwijderd: delen stopt en het gezin wordt opnieuw opgehaald', () async {
    members.add(const [_papa, _me]);
    await pumpEventQueue();
    members.add(const [_papa]);
    await pumpEventQueue();

    expect(_trackerStops, 1);
    expect(_zoneStops, 1);
    expect(familyFetches, 2);
  });
}
