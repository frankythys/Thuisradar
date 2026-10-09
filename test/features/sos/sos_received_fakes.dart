import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';
import 'package:thuisradar/features/sos/application/sos_providers.dart';
import 'package:thuisradar/features/sos/domain/sos_alert.dart';
import 'package:thuisradar/features/sos/presentation/sos_received_overlay.dart';

final sosNow = DateTime(2026, 10, 9, 14, 34);

final sosTestAlert = SosAlert(
  id: 'a1',
  familyId: 'fam',
  userId: 'liam',
  latitude: 51.0543,
  longitude: 3.7174,
  active: true,
  createdAt: DateTime(2026, 10, 9, 14, 32),
);

class FakeGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async =>
      const PlaceAddress(street: 'Kerkstraat 42', municipality: 'Gent');
}

List<Override> sosReceivedOverrides({List<Map<String, dynamic>> receipts = const []}) => [
  currentUserIdProvider.overrideWithValue('papa'),
  clockProvider.overrideWith((ref) => Stream.value(sosNow)),
  familyMembersProvider('fam').overrideWith(
    (ref) => Stream.value(const [
      FamilyMember(userId: 'papa', displayName: 'Papa', isOwner: true, colorIndex: 0),
      FamilyMember(userId: 'liam', displayName: 'Liam', isOwner: false, colorIndex: 2, phone: '0470000000'),
      FamilyMember(userId: 'mama', displayName: 'Mama', isOwner: false, colorIndex: 4),
    ]),
  ),
  familyLocationsProvider('fam').overrideWith(
    (ref) => Stream.value([
      MemberLocation(
        userId: 'liam',
        familyId: 'fam',
        latitude: 51.0543,
        longitude: 3.7174,
        battery: 45,
        updatedAt: DateTime(2026, 10, 9, 14, 33),
      ),
    ]),
  ),
  familyPlacesProvider('fam').overrideWith((ref) => Stream.value(const [])),
  sosReceiptsProvider('a1').overrideWith((ref) => Stream.value(receipts)),
  geocodingSourceProvider.overrideWithValue(FakeGeocoding()),
];

Widget sosReceivedApp({List<Map<String, dynamic>> receipts = const []}) => ProviderScope(
  overrides: sosReceivedOverrides(receipts: receipts),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SosReceivedOverlay(alert: sosTestAlert, name: 'Liam', onShowOnMap: () {}, onDismiss: () {}),
    ),
  ),
);

/// De kaarttegels willen een cachemap; geef een tijdelijke map.
void mockMapCache() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.path,
  );
}
