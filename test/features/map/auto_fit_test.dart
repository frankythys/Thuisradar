import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/auto_fit.dart';

void main() {
  test('fit niet voor de kaart klaar is of er geen punten zijn', () {
    final fit = AutoFitController();
    expect(fit.shouldFit(mapReady: false, hasPoints: true), isFalse);
    expect(fit.shouldFit(mapReady: true, hasPoints: false), isFalse);
  });

  test('fit precies één keer automatisch', () {
    final fit = AutoFitController();
    expect(fit.shouldFit(mapReady: true, hasPoints: true), isTrue);
    fit.markFitted();
    expect(fit.shouldFit(mapReady: true, hasPoints: true), isFalse);
  });

  test('na eigen zoom/verschuiven nooit meer automatisch', () {
    final fit = AutoFitController();
    fit.lock();
    expect(fit.shouldFit(mapReady: true, hasPoints: true), isFalse);
  });

  test('een bewuste actie (centreerknop) mag altijd, ook na vergrendelen', () {
    final fit = AutoFitController();
    fit.lock();
    fit.markFitted();
    expect(fit.shouldFit(mapReady: true, hasPoints: true, deliberate: true), isTrue);
  });
}
