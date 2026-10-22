import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/map_ready_gate.dart';

void main() {
  // testWidgets: timers lopen op de nepklok van de tester.
  testWidgets('kaart opent al op de bewaarde plek (geen beweging): toch klaar na korte tijd', (tester) async {
    final gate = MapReadyGate();
    addTearDown(gate.dispose);

    gate.created();
    await tester.pump(const Duration(milliseconds: 600));
    expect(gate.isReady, isFalse, reason: 'eerst nog even wachten op een camerabeweging');
    await tester.pump(const Duration(milliseconds: 200));
    expect(gate.isReady, isTrue);
  });

  testWidgets('camera komt tot rust: meteen klaar, zonder te wachten', (tester) async {
    final gate = MapReadyGate();
    addTearDown(gate.dispose);

    gate.created();
    await tester.pump(const Duration(milliseconds: 100));
    gate.cameraIdle();
    expect(gate.isReady, isTrue);
  });

  testWidgets('niet klaar zolang de kaart niet aangemaakt is', (tester) async {
    final gate = MapReadyGate();
    addTearDown(gate.dispose);

    await tester.pump(const Duration(seconds: 5));
    expect(gate.isReady, isFalse);
  });

  testWidgets('twee keer rust of aanmaken: geen fout', (tester) async {
    final gate = MapReadyGate();
    addTearDown(gate.dispose);

    gate
      ..created()
      ..created()
      ..cameraIdle()
      ..cameraIdle();
    await tester.pump(const Duration(seconds: 1));
    expect(gate.isReady, isTrue);
  });
}
