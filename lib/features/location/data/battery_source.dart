import 'package:battery_plus/battery_plus.dart';

import '../domain/device_reading.dart';

class BatterySource {
  final Battery _battery = Battery();

  Future<BatteryReading> read() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return BatteryReading(
        level: level.clamp(0, 100),
        isCharging: state == BatteryState.charging || state == BatteryState.full,
      );
    } on Exception {
      return BatteryReading.unknown;
    }
  }
}
