import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/step_count.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';

void main() {
  final start = DateTime(2026, 10, 7, 14);
  TrackPoint at(int seconds, int? steps) => TrackPoint(
    latitude: 51,
    longitude: 4,
    recordedAt: start.add(Duration(seconds: seconds)),
    steps: steps,
  );

  test('telt de stijging van de teller tijdens de wandeling', () {
    expect(stepsAlong([at(0, 12000), at(5, 12008), at(10, 12017)]), 17);
  });

  test('zonder stappen van het toestel: onbekend', () {
    expect(stepsAlong([at(0, null), at(5, null)]), isNull);
    expect(stepsAlong([at(0, 100)]), isNull);
    expect(stepsAlong(const []), isNull);
  });

  test('metingen zonder stappen ertussen worden overgeslagen', () {
    expect(stepsAlong([at(0, 500), at(5, null), at(10, 520)]), 20);
  });

  test('een herstart (teller valt terug) telt dat stuk niet, de rest wel', () {
    expect(stepsAlong([at(0, 9000), at(5, 9008), at(10, 3), at(15, 12)]), 17);
  });

  test('een onmogelijke sprong telt niet', () {
    expect(stepsAlong([at(0, 100), at(5, 5000), at(10, 5008)]), 8);
  });
}
