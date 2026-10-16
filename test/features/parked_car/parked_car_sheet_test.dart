import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/parked_car/domain/parked_car.dart';
import 'package:thuisradar/features/parked_car/presentation/parked_car_sheet.dart';

final _car = ParkedCar(
  userId: 'mama',
  familyId: 'f',
  latitude: 51.0543,
  longitude: 3.7174,
  parkedAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

Future<ParkedCarAction?> _open(
  WidgetTester tester, {
  ParkedCar? car,
  required bool mine,
  String? owner,
}) async {
  ParkedCarAction? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showParkedCarSheet(context, car: car, mine: mine, ownerName: owner),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('auto van iemand anders: navigeren en tonen, niet bijwerken of verwijderen', (tester) async {
    await _open(tester, car: _car, mine: false, owner: 'Mama');
    expect(find.text('Auto van Mama'), findsOneWidget);
    expect(find.text('Laatst opgeslagen: 5 min geleden'), findsOneWidget);
    expect(find.text('Navigeer naar de auto'), findsOneWidget);
    expect(find.text('Parkeerplek bijwerken'), findsNothing);
    expect(find.text('Parkeerplek verwijderen'), findsNothing);
  });

  testWidgets('eigen auto: alle acties; Navigeer geeft navigate terug', (tester) async {
    ParkedCarAction? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showParkedCarSheet(context, car: _car, mine: true),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Parkeerplek bijwerken'), findsOneWidget);
    expect(find.text('Parkeerplek verwijderen'), findsOneWidget);
    await tester.tap(find.text('Navigeer naar de auto'));
    await tester.pumpAndSettle();
    expect(chosen, ParkedCarAction.navigate);
  });

  testWidgets('nog geen eigen plek: enkel opslaan', (tester) async {
    await _open(tester, mine: true);
    expect(find.text('Auto hier opslaan'), findsOneWidget);
    expect(find.text('Navigeer naar de auto'), findsNothing);
  });
}
