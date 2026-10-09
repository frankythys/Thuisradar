import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/driving/presentation/driving_activity_card.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';

class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

void main() {
  bool isCar(Widget widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == 'assets/markers/auto.png';

  Future<void> pump(WidgetTester tester, DrivingActivityKind kind) => tester.pumpWidget(
    ProviderScope(
      overrides: [geocodingSourceProvider.overrideWithValue(_NoGeocoding())],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DrivingActivityCard(
            activity: DrivingActivity(
              kind: kind,
              start: DateTime(2026, 10, 9, 17, 11),
              end: DateTime(2026, 10, 9, 17, 15),
              latitude: 51.18,
              longitude: 4.38,
              distanceMeters: 1800,
              fromLatitude: 51.17,
              fromLongitude: 4.395,
            ),
            places: const [],
          ),
        ),
      ),
    ),
  );

  testWidgets('een ritkaartje toont de 3D-auto', (tester) async {
    await pump(tester, DrivingActivityKind.trip);
    expect(find.byWidgetPredicate(isCar), findsOneWidget);
  });

  testWidgets('een verblijf toont geen auto', (tester) async {
    await pump(tester, DrivingActivityKind.stay);
    expect(find.byWidgetPredicate(isCar), findsNothing);
  });
}
