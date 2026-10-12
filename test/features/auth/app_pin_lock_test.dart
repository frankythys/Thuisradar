import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/auth/data/pin_lock.dart';
import 'package:thuisradar/features/auth/presentation/app_pin_lock.dart';

class _Pin extends Mock implements PinLock {}

void main() {
  final session = Session(
    accessToken: 'token',
    refreshToken: 'refresh',
    tokenType: 'bearer',
    user: User(
      id: 'google-user',
      appMetadata: {'provider': 'google'},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-10-12T00:00:00Z',
    ),
  );

  testWidgets('toegangscode werkt zonder biometrie en een foute code opent niets', (tester) async {
    final pin = _Pin();
    when(() => pin.verify('google-user', '000000')).thenAnswer((_) async => false);
    when(() => pin.verify('google-user', '123456')).thenAnswer((_) async => true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(session)),
          pinLockProvider.overrideWithValue(pin),
          pinEnabledProvider('google-user').overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          builder: (context, child) => AppPinLock(onSignedOut: () {}, child: child!),
          home: const Scaffold(body: Text('Gezinskaart')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Ontgrendelen'));
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsNothing);
    expect(find.text('Onjuiste toegangscode.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Ontgrendelen'));
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsOneWidget);
  });

  testWidgets('zonder toegangscode blijft de app toegankelijk', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(session)),
          pinEnabledProvider('google-user').overrideWith((ref) async => false),
        ],
        child: MaterialApp(
          builder: (context, child) => AppPinLock(onSignedOut: () {}, child: child!),
          home: const Scaffold(body: Text('Gezinskaart')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsOneWidget);
  });
}
