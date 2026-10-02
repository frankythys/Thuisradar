import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/battery_source.dart';
import '../data/device_location_source.dart';
import '../data/location_repository.dart';
import '../domain/device_reading.dart';
import '../domain/member_location.dart';
import 'location_providers.dart';
import 'tracking_status.dart';

/// Deelt de locatie van dit toestel met de familie zolang hij gestart is.
class LocationTracker extends Notifier<TrackingStatus> {
  StreamSubscription<DevicePosition>? _subscription;
  String? _userId;
  String? _familyId;

  DeviceLocationSource get _device => ref.read(deviceLocationSourceProvider);
  BatterySource get _battery => ref.read(batterySourceProvider);
  LocationRepository get _repository => ref.read(locationRepositoryProvider);

  @override
  TrackingStatus build() {
    ref.onDispose(_cancel);
    return TrackingStatus.idle;
  }

  Future<void> start({required String userId, required String familyId}) async {
    if (_subscription != null && _userId == userId && _familyId == familyId) return;
    _cancel();
    _userId = userId;
    _familyId = familyId;

    final access = await _device.ensureAccess();
    if (!ref.mounted) return;

    state = TrackingStatus.fromAccess(access);
    if (access != LocationAccess.granted) return;

    _subscription = _device.positions().listen(
      _onPosition,
      onError: (Object error) {
        debugPrint('Locatiestroom fout: $error');
        if (ref.mounted) state = TrackingStatus.error;
      },
    );
  }

  Future<void> openSettings() => _device.openSettings();

  void stop() {
    _cancel();
    state = TrackingStatus.idle;
  }

  Future<void> _onPosition(DevicePosition position) async {
    final userId = _userId;
    final familyId = _familyId;
    if (userId == null || familyId == null) return;

    final battery = await _battery.read();
    final location = MemberLocation(
      userId: userId,
      familyId: familyId,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracyMeters,
      speedMps: position.speedMps,
      battery: battery.level,
      isCharging: battery.isCharging,
      updatedAt: position.timestamp,
    );

    try {
      await _repository.upload(location);
      if (ref.mounted) state = TrackingStatus.active;
    } on Exception catch (error) {
      debugPrint('Locatie uploaden mislukt: $error');
      if (ref.mounted) state = TrackingStatus.offline;
    }
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}
