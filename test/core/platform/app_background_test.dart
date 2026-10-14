import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/platform/app_background.dart';
import 'package:thuisradar/shared/widgets/back_to_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AppBackground.channelName);
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android: vraagt de activiteit om naar de achtergrond te gaan', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await const AppBackground().moveToBackground();
    expect(calls, ['moveToBackground']);
  });

  test('iPhone: niets (geen terug-knop)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await const AppBackground().moveToBackground();
    expect(calls, isEmpty);
  });

  testWidgets('terug op het hoofdscherm sluit niet maar gaat naar de achtergrond', (tester) async {
    var background = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BackToBackground(onBackground: () => background++, child: const Text('Kaart')),
      ),
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(background, 1);
    expect(find.text('Kaart'), findsOneWidget);
  });

  testWidgets('een geopend scherm erbovenop gaat gewoon terug', (tester) async {
    var background = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: BackToBackground(onBackground: () => background++, child: const Text('Kaart')),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('Detail')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Kaart'), findsOneWidget);
    expect(background, 0);
  });
}
