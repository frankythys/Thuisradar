import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/clustered_marker_layer.dart';
import 'package:thuisradar/features/map/presentation/widgets/location_pointer.dart';
import 'package:thuisradar/features/parked_car/domain/parked_car.dart';
import 'package:thuisradar/features/parked_car/presentation/parked_car_marker.dart';
import 'package:thuisradar/features/places/presentation/place_images.dart';

void main() {
  // Thuis, Franky staat thuis, de auto ±25 m verder op straat.
  const home = LatLng(51.1765, 4.4122);
  const street = LatLng(51.17672, 4.41225);
  final now = DateTime(2026, 10, 16, 13);

  Future<void> pumpMap(WidgetTester tester, double zoom) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FlutterMap(
            options: MapOptions(initialCenter: home, initialZoom: zoom, maxZoom: 21),
            children: [
              ClusteredMarkerLayer(
                members: [
                  MemberOnMap(
                    member: const FamilyMember(
                      userId: 'Franky',
                      displayName: 'Franky',
                      isOwner: true,
                      colorIndex: 0,
                    ),
                    location: MemberLocation(
                      userId: 'Franky',
                      familyId: 'gezin',
                      latitude: home.latitude,
                      longitude: home.longitude,
                      updatedAt: now,
                      speedMps: 0,
                    ),
                  ),
                ],
                parkedCars: [
                  ParkedCar(
                    userId: 'Franky',
                    familyId: 'gezin',
                    latitude: street.latitude,
                    longitude: street.longitude,
                    parkedAt: now,
                  ),
                ],
                memberNames: const {'Franky': 'Franky'},
                now: now,
                reservedPlaces: const [home],
                onMemberTap: (_) {},
                onGroupTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('uitgezoomd: de autopin valt niet over het huis of Franky', (tester) async {
    for (final zoom in [12.0, 14.0, 16.0]) {
      await pumpMap(tester, zoom);
      final car = tester.getRect(find.byType(ParkedCarMarker));
      final house = Rect.fromCenter(
        center: tester.getCenter(find.byType(FlutterMap)),
        width: kPlaceMapImageWidth,
        height: kPlaceMapImageWidth,
      );
      final dot = tester.getCenter(find.byType(LocationDot));
      final pin = Rect.fromLTWH(dot.dx - 32, dot.dy - 96, 64, 96);
      expect(car.overlaps(house), isFalse, reason: 'huis, zoom $zoom');
      expect(car.overlaps(pin), isFalse, reason: 'Franky, zoom $zoom');
    }
  });

  testWidgets('ingezoomd: de autopin staat op zijn echte plek', (tester) async {
    await pumpMap(tester, 20);
    final camera = MapCamera.of(tester.element(find.byType(ClusteredMarkerLayer)));
    final real = camera.latLngToScreenOffset(street);
    final car = tester.getRect(find.byType(ParkedCarMarker));
    expect(car.topCenter.dx, closeTo(real.dx, 0.5));
    expect(car.topCenter.dy, closeTo(real.dy, 0.5));
  });
}
