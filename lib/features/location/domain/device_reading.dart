/// Eén meting van dit toestel, los van de gebruikte GPS-bibliotheek.
class DevicePosition {
  const DevicePosition({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracyMeters;
  final double? speedMps;
}

class BatteryReading {
  const BatteryReading({this.level, this.isCharging});

  static const unknown = BatteryReading();

  final int? level;
  final bool? isCharging;
}

/// Resultaat van de toestemmingscontrole voor locatie.
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }
