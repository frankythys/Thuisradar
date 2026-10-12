import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/auth/data/biometric_login.dart';
import 'package:thuisradar/features/auth/presentation/biometric_lock.dart';

class _Bio extends Mock implements BiometricLogin {}

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

  Future<void> pump(WidgetTester tester, _Bio bio, {bool enabled = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => Stream.value(session)),
          biometricLoginProvider.overrideWithValue(bio),
          biometricEnabledProvider('google-user').overrideWith((ref) async => enabled),
        ],
        child: MaterialApp(
          builder: (context, child) => BiometricLock(onSignedOut: () {}, child: child!),
          home: const Scaffold(body: Text('Gezinskaart')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Google-sessie blijft afgeschermd na annuleren en opent alleen na geslaagde scan', (tester) async {
    final bio = _Bio();
    when(() => bio.authenticate()).thenAnswer((_) async => false);
    await pump(tester, bio);
    expect(find.text('Gezinskaart'), findsNothing);
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsNothing);
    when(() => bio.authenticate()).thenAnswer((_) async => true);
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsOneWidget);
    // Expliciet afsluiten behoudt de sessie en vraagt alleen een nieuwe scan.
    final container = ProviderScope.containerOf(tester.element(find.text('Gezinskaart')));
    container.read(biometricLockRequestProvider.notifier).lock();
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsNothing);
    expect(container.read(sessionProvider).value, same(session));
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsOneWidget);
    // Open detailpagina wordt bij achtergrond/terugkeer ook afgeschermd.
    final context = tester.element(find.text('Gezinskaart'));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('PrivÃ©profiel'))));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('PrivÃ©profiel'), findsNothing);
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(find.text('PrivÃ©profiel'), findsOneWidget);
  });

  testWidgets('zonder opt-in blijft de app toegankelijk zonder scan', (tester) async {
    final bio = _Bio();
    await pump(tester, bio, enabled: false);
    expect(find.text('Gezinskaart'), findsOneWidget);
    verifyNever(() => bio.authenticate());
  });

  testWidgets('scan-fout ontgrendelt de sessie niet', (tester) async {
    final bio = _Bio();
    when(() => bio.authenticate()).thenThrow(StateError('Geen vingerafdruk ingesteld'));
    await pump(tester, bio);
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(find.text('Gezinskaart'), findsNothing);
    expect(find.text('Geen vingerafdruk ingesteld'), findsOneWidget);
  });
}
