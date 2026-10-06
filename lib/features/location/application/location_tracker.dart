import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/battery_source.dart';
import '../data/device_location_source.dart';
import '../data/location_repository.dart';
import '../domain/device_reading.dart';
import '../domain/member_location.dart';
import '../domain/motion_filter.dart';
import 'location_providers.dart';
import 'tracking_status.dart';
import '../../profile/application/profile_providers.dart';

/// Tijdens een actieve SOS vaker uploaden.
const _sosInterval = Duration(seconds: 10);

/// Een hangende upload mag de volgende metingen niet blokkeren.
const _uploadTimeout = Duration(seconds: 15);

/// Na een onderbroken locatiestroom wachten we even voor we opnieuw proberen.
const _reattachBackoff = Duration(seconds: 5);

/// Deelt de locatie van dit toestel met de familie zolang hij gestart is.
class LocationTracker extends Notifier<TrackingStatus> {
  StreamSubscription<DevicePosition>? _subscription;
  Timer? _reattachTimer;
  String? _userId;
  String? _familyId;
  bool _fast = false;
  int _generation = 0;
  int _streamGeneration = 0;
  MotionFilter _motion = MotionFilter();
  Future<void> _uploads = Future<void>.value();
  Duration get _interval => _motion.wantsFastUpdates
      ? const Duration(seconds: 5)
      : (_fast ? _sosInterval : DeviceLocationSource.defaultInterval);

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

    unawaited(_attach());
  }

  Future<void> openSettings() => _device.openSettings();

  /// Schakelt tussen snel (tijdens een actieve SOS) en normaal uploaden.
  void setFastUpdates(bool fast) {
    if (_fast == fast) return;
    _fast = fast;
    if (_subscription != null) _attach();
  }

  Future<void> _attach() async {
    final streamGeneration = ++_streamGeneration;
    final generation = _generation;
    final old = _subscription;
    _subscription = null;
    _reattachTimer?.cancel();
    // De oude stroom (bij een intervalwissel of herstel) hoeven we niet af te
    // wachten: eventuele late events worden genegeerd via de generatietellers.
    unawaited(old?.cancel());
    if (!ref.mounted || generation != _generation || streamGeneration != _streamGeneration) return;
    _subscription = _device
        .positions(interval: _interval)
        .listen(
          (position) {
            if (generation != _generation || streamGeneration != _streamGeneration) return;
            _uploads = _uploads.then((_) async {
              if (!ref.mounted || generation != _generation) return;
              await _onPosition(position);
            });
          },
          onError: (Object error) {
            debugPrint('Locatiestroom fout: $error');
            if (ref.mounted && generation == _generation) state = TrackingStatus.error;
            _scheduleReattach(generation, streamGeneration);
          },
          onDone: () => _scheduleReattach(generation, streamGeneration),
        );
  }

  /// Herstelt de locatiestroom nadat Android hem onderweg stopzette of een fout
  /// gaf, zodat de kaart niet bevriest tot de gebruiker de app herstart.
  void _scheduleReattach(int generation, int streamGeneration) {
    if (!ref.mounted || generation != _generation || streamGeneration != _streamGeneration) return;
    _reattachTimer?.cancel();
    _reattachTimer = Timer(_reattachBackoff, () {
      if (generation != _generation || streamGeneration != _streamGeneration) return;
      if (ref.mounted) unawaited(_attach());
    });
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

    final oldInterval = _interval;
    final accepted = _motion.accept(position, DateTime.now());
    if (accepted == null) return;
    if (_interval != oldInterval) unawaited(_attach());
    position = accepted;
    try {
      final battery = await _battery.read().timeout(_uploadTimeout);
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

      await _repository.upload(location).timeout(_uploadTimeout);
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
    _streamGeneration++;
    _motion = MotionFilter();
    _reattachTimer?.cancel();
    _reattachTimer = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
