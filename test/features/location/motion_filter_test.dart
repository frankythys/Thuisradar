import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/motion_filter.dart';

void main() {
  final base = DateTime(2026, 1, 2, 10);

  DevicePosition pos(double lat, double lng, DateTime at, {double? accuracy, double? speed}) =>
      DevicePosition(latitude: lat, longitude: lng, timestamp: at, accuracyMeters: accuracy, speedMps: speed);

  test('een nauwkeurige fix wordt aanvaard', () {
    final accepted = MotionFilter().accept(pos(51, 3, base, accuracy: 10), base);
    expect(accepted, isNotNull);
  });

  test('een betrouwbare GPS-snelheid meldt meteen beweging', () {
    final filter = MotionFilter();
    final accepted = filter.accept(pos(51, 3, base, accuracy: 10, speed: 8), base);

    expect(accepted, isNotNull);
    expect(accepted!.speedMps, 8);
    expect(filter.wantsFastUpdates, isTrue);
  });

  test('een grove fix (binnenshuis) wordt bewaard maar meldt geen beweging', () {
    final accepted = MotionFilter().accept(pos(51, 3, base, accuracy: 80), base);

    expect(accepted, isNotNull);
    expect(accepted!.speedMps, isNull);
  });

  test('een volledig onbruikbare fix wordt geweigerd', () {
    expect(MotionFilter().accept(pos(51, 3, base, accuracy: 250), base), isNull);
  });

  test('opeenvolgende grove fixes ver uiteen melden nooit beweging', () {
    final filter = MotionFilter();
    var at = base;
    DevicePosition? last;
    for (var i = 0; i < 3; i++) {
      // Elke stap ~200 m, maar alle fixes zijn grof: geen bewijs van rijden.
      last = filter.accept(pos(51 + i * 0.0018, 3, at, accuracy: 80), at);
      at = at.add(const Duration(seconds: 30));
    }

    expect(last, isNotNull);
    expect(last!.speedMps, isNull);
    expect(filter.wantsFastUpdates, isFalse);
  });
}
