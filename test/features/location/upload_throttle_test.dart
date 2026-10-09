import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/location/domain/device_reading.dart';
import 'package:thuisradar/features/location/domain/upload_throttle.dart';

void main() {
  final t0 = DateTime(2026, 10, 9, 12);
  DevicePosition still(DateTime at) =>
      DevicePosition(latitude: 51.2, longitude: 4.4, timestamp: at, speedMps: 0);
  DevicePosition driving(DateTime at) =>
      DevicePosition(latitude: 51.2, longitude: 4.4, timestamp: at, speedMps: 14);

  test('de eerste meting gaat altijd door', () {
    expect(UploadThrottle().shouldUpload(still(t0), t0, moving: false), isTrue);
  });

  test('bij stilstand hoogstens om de 15 s', () {
    final throttle = UploadThrottle()..uploaded(still(t0), t0);
    final t5 = t0.add(const Duration(seconds: 5));
    final t10 = t0.add(const Duration(seconds: 10));
    final t15 = t0.add(const Duration(seconds: 15));
    expect(throttle.shouldUpload(still(t5), t5, moving: false), isFalse);
    expect(throttle.shouldUpload(still(t10), t10, moving: false), isFalse);
    expect(throttle.shouldUpload(still(t15), t15, moving: false), isTrue);
  });

  test('een meting net onder het interval telt mee (speling)', () {
    final throttle = UploadThrottle()..uploaded(still(t0), t0);
    final almost = t0.add(const Duration(milliseconds: 14600));
    expect(throttle.shouldUpload(still(almost), almost, moving: false), isTrue);
  });

  test('tijdens een rit elke meting van 5 s', () {
    final throttle = UploadThrottle()..uploaded(driving(t0), t0);
    final t5 = t0.add(const Duration(seconds: 5));
    expect(throttle.shouldUpload(driving(t5), t5, moving: true), isTrue);
  });

  test('vertrek en aankomst gaan meteen door, ongeacht het interval', () {
    final throttle = UploadThrottle()..uploaded(still(t0), t0);
    final t2 = t0.add(const Duration(seconds: 2));
    expect(throttle.shouldUpload(driving(t2), t2, moving: true), isTrue);
    throttle.uploaded(driving(t2), t2);
    final t3 = t0.add(const Duration(seconds: 3));
    expect(throttle.shouldUpload(still(t3), t3, moving: false), isTrue);
  });

  test('onbekend en stil wisselen thuis geeft geen extra uploads', () {
    final throttle = UploadThrottle()..uploaded(still(t0), t0);
    final t5 = t0.add(const Duration(seconds: 5));
    final unknown = DevicePosition(latitude: 51.2, longitude: 4.4, timestamp: t5);
    expect(throttle.shouldUpload(unknown, t5, moving: false), isFalse);
  });

  test('tijdens een eigen SOS om de 10 s', () {
    final throttle = UploadThrottle()
      ..fast = true
      ..uploaded(still(t0), t0);
    final t10 = t0.add(const Duration(seconds: 10));
    expect(throttle.shouldUpload(still(t10), t10, moving: false), isTrue);
  });
}
