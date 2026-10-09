import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/onboarding/presentation/intro_screen.dart';
import 'package:thuisradar/features/onboarding/presentation/onboarding_gate.dart';
import 'package:thuisradar/features/onboarding/presentation/onboarding_screen.dart';

class _Player extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(1080, 1920),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

Future<void> _start(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const OnboardingGate(child: Text('App')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => VideoPlayerPlatform.instance = _Player());

  testWidgets('afgebroken onboarding toont intro opnieuw na herstart', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_intro_seen': true});
    await _start(tester);
    expect(find.byType(IntroScreen), findsOneWidget);
    await tester.tap(find.text('Overslaan'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _start(tester);
    expect(find.byType(IntroScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('volledig afronden stopt intro bij volgende appstart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _start(tester);
    await tester.tap(find.text('Overslaan'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Volgende'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Aan de slag'));
    await tester.pumpAndSettle();
    expect(find.text('App'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _start(tester);
    expect(find.text('App'), findsOneWidget);
    expect(find.byType(IntroScreen), findsNothing);
  });
}
