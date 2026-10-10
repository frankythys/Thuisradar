import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/geofencing/application/geofence_status.dart';
import 'package:thuisradar/features/geofencing/presentation/geofence_banner.dart';

void main() {
  Future<void> show(WidgetTester tester, GeofenceStatus status) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GeofenceBanner(status: status, onRetry: () {}),
      ),
    ),
  );

  testWidgets('locatienauwkeurigheid uit: de kaart zegt wat te doen', (tester) async {
    await show(tester, GeofenceStatus.unavailable);
    expect(find.textContaining('Google-locatienauwkeurigheid'), findsOneWidget);
    expect(find.text('Opnieuw'), findsOneWidget);
  });

  testWidgets('zones actief: geen melding', (tester) async {
    await show(tester, GeofenceStatus.active);
    expect(find.byType(TextButton), findsNothing);
  });
}
