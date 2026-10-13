import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/driving/domain/driving_activity.dart';
import 'package:thuisradar/features/driving/presentation/driving_activity_card.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/travel_mode.dart';

class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

void main() {
  bool isCar(Widget widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == 'assets/markers/auto.png';

  Future<void> pump(
    WidgetTester tester,
    DrivingActivityKind kind, {
    TravelMode mode = TravelMode.car,
    DateTime? end,
    Duration? waiting,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [geocodingSourceProvider.overrideWithValue(_NoGeocoding())],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DrivingActivityCard(
            activity: DrivingActivity(
              kind: kind,
              start: DateTime(2026, 10, 9, 17, 11),
              end: end ?? DateTime(2026, 10, 9, 17, 15),
              latitude: 51.18,
              longitude: 4.38,
              distanceMeters: 1800,
              fromLatitude: 51.17,
              fromLongitude: 4.395,
              mode: mode,
              waiting: waiting,
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

  testWidgets('een wandeling toont de wandelaar, duur en gemiddeld tempo', (tester) async {
    await pump(tester, DrivingActivityKind.trip, mode: TravelMode.walk);
    expect(find.byWidgetPredicate(isCar), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/markers/wandelen.png',
      ),
      findsOneWidget,
    );
    // 1,8 km in 4 minuten.
    expect(find.text('4 min · gem. 27,0 km/u'), findsOneWidget);
  });

  testWidgets('een rit met file toont de duur en hoelang er stilgestaan werd', (tester) async {
    await pump(
      tester,
      DrivingActivityKind.trip,
      end: DateTime(2026, 10, 9, 18, 36),
      waiting: const Duration(minutes: 47),
    );
    expect(find.textContaining('waarvan 47 min stilstaan of stapvoets'), findsOneWidget);
    expect(find.byIcon(Icons.traffic_outlined), findsOneWidget);
  });

  testWidgets('een vlotte rit toont geen wachttijd', (tester) async {
    await pump(tester, DrivingActivityKind.trip, waiting: const Duration(seconds: 40));
    expect(find.byIcon(Icons.traffic_outlined), findsNothing);
  });
}
