import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:thuisradar/features/onboarding/presentation/intro_screen.dart';

class _Video extends VideoPlayerController {
  _Video({this.fail = false}) : super.asset('test.mp4');
  final bool fail;
  bool released = false;
  @override
  Future<void> initialize() async {
    if (fail) throw StateError('Video unavailable');
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> dispose() async {
    released = true;
    await super.dispose();
  }
}

void main() {
  testWidgets('Overslaan gaat door en ruimt de speler op', (tester) async {
    final controller = _Video();
    await tester.pumpWidget(MaterialApp(home: _Flow(controller: controller)));
    await tester.pump();
    await tester.tap(find.text('Overslaan'));
    await tester.pump();
    expect(find.text('Onboarding'), findsOneWidget);
    expect(controller.released, isTrue);
  });
  testWidgets('voltooide video gaat automatisch naar onboarding', (tester) async {
    final controller = _Video();
    await tester.pumpWidget(MaterialApp(home: _Flow(controller: controller)));
    await tester.pump();
    controller.value = controller.value.copyWith(isCompleted: true);
    await tester.pump();
    expect(find.text('Onboarding'), findsOneWidget);
  });
  testWidgets('verbergt de Android-balken tijdens de video en zet ze daarna terug', (tester) async {
    final modes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      // Terugzetten met zichtbare balken gaat via setEnabledSystemUIOverlays.
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') modes.add(call.arguments);
      if (call.method == 'SystemChrome.setEnabledSystemUIOverlays') modes.add('overlays');
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(MaterialApp(home: _Flow(controller: _Video())));
    await tester.pump();
    expect(modes, ['SystemUiMode.immersiveSticky']);

    await tester.tap(find.text('Overslaan'));
    await tester.pump();
    expect(modes.last, 'overlays');
  });
  testWidgets('afspeelfout blokkeert de onboarding niet', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _Flow(controller: _Video(fail: true))));
    await tester.pump();
    expect(find.text('Onboarding'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Flow extends StatefulWidget {
  const _Flow({required this.controller});
  final VideoPlayerController controller;
  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  bool finished = false;
  @override
  Widget build(BuildContext context) => finished
      ? const Scaffold(body: Text('Onboarding'))
      : IntroScreen(controller: widget.controller, onFinished: () => setState(() => finished = true));
}
