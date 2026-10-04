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
import '../../profile/application/profile_providers.dart';

/// Tijdens een actieve SOS vaker uploaden.
const _sosInterval = Duration(seconds: 10);

/// Deelt de locatie van dit toestel met de familie zolang hij gestart is.
class LocationTracker extends Notifier<TrackingStatus> {
  StreamSubscription<DevicePosition>? _subscription;
  String? _userId;
  String? _familyId;
  bool _fast = false;
  int _generation = 0;

  DeviceLocationSource get _device => ref.read(deviceLocationSourceProvider);
  BatterySource get _battery => ref.read(batterySourceProvider);
  LocationRepository get _repository => ref.read(locationRepositoryProvider);

  @override
  TrackingStatus build() {
    ref.onDispose(_cancel);
    return TrackingStatus.idle;
  }

  Future<void> start({required String userId, required String familyId}) async {
    if (_subscription != null && _userId == userId && _familyId == familyId) {
      return;
    }
    _cancel();
    final generation = _generation;
    _userId = userId;
    _familyId = familyId;

    final sharing = await ref.read(profilePreferencesProvider).sharing(userId);
    if (!ref.mounted || generation != _generation) return;
    if (!sharing) {
      state = TrackingStatus.idle;
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    final access = await _device.ensureAccess();
    if (!ref.mounted || generation != _generation) return;

    state = TrackingStatus.fromAccess(access);
    if (access != LocationAccess.granted) return;

    _attach();
  }

  Future<void> openSettings() => _device.openSettings();

  /// Schakelt tussen snel (tijdens een actieve SOS) en normaal uploaden.
  void setFastUpdates(bool fast) {
    if (_fast == fast) return;
    _fast = fast;
    if (_subscription != null) _attach();
  }

  void _attach() {
    _subscription?.cancel();
    _subscription = _device
        .positions(
          interval: _fast ? _sosInterval : DeviceLocationSource.defaultInterval,
        )
        .listen(
          _onPosition,
          onError: (Object error) {
            debugPrint('Locatiestroom fout: $error');
            if (ref.mounted) state = TrackingStatus.error;
          },
        );
  }

  void stop() {
    _cancel();
    _userId = null;
    _familyId = null;
    _fast = false;
    state = TrackingStatus.idle;
  }

  Future<void> _onPosition(DevicePosition position) async {
    final userId = _userId;
    final familyId = _familyId;
    final generation = _generation;
    if (userId == null || familyId == null) return;

    final battery = await _battery.read();
    if (!ref.mounted || generation != _generation) return;
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
      if (ref.mounted && generation == _generation) {
        state = TrackingStatus.active;
      }
    } on Exception catch (error) {
      debugPrint('Locatie uploaden mislukt: $error');
      if (ref.mounted && generation == _generation) {
        state = TrackingStatus.offline;
      }
    }
  }

  void _cancel() {
    _generation++;
    _subscription?.cancel();
    _subscription = null;
  }
}
