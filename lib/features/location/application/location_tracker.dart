import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/battery_source.dart';
import '../data/device_location_source.dart';
import '../data/location_repository.dart';
import '../domain/device_reading.dart';
import '../domain/member_location.dart';
import '../domain/motion_filter.dart';
import '../domain/upload_throttle.dart';
import 'location_providers.dart';
import 'tracking_status.dart';
import '../../profile/application/profile_providers.dart';

/// Een hangende upload mag de volgende metingen niet blokkeren.
const _uploadTimeout = Duration(seconds: 15);

/// Na een onderbroken locatiestroom wachten we even voor we opnieuw proberen.
const _reattachBackoff = Duration(seconds: 5);

/// Zo lang zonder één meting = de GPS-stroom is stilgevallen.
const _silentStreamAfter = Duration(seconds: 45);

/// Deelt de locatie van dit toestel met de familie zolang hij gestart is.
///
/// De GPS-stroom draait aan één vast tempo en wordt nooit herstart om sneller
/// of trager te gaan: op Android stopt een herstart de voorgronddienst, die
/// vanuit de achtergrond niet opnieuw mag starten. Het upload-tempo (snel
/// tijdens een rit of SOS, rustig bij stilstand) regelt [UploadThrottle].
class LocationTracker extends Notifier<TrackingStatus> {
  StreamSubscription<DevicePosition>? _subscription;
  Timer? _reattachTimer;
  String? _userId;
  String? _familyId;
  bool _granted = false;
  int _generation = 0;
  int _streamGeneration = 0;
  MotionFilter _motion = MotionFilter();
  UploadThrottle _throttle = UploadThrottle();
  DateTime? _lastFixAt;
  Future<void> _uploads = Future<void>.value();

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
    final access = await _device.ensureAccess();
    if (!ref.mounted || generation != _generation) return;

    state = TrackingStatus.fromAccess(access);
    if (access != LocationAccess.granted) return;

    _granted = true;
    _attach();
  }

  Future<void> openSettings() => _device.openSettings();

  /// Tijdens een actieve SOS vaker uploaden. Wisselt enkel het upload-tempo,
  /// nooit de GPS-stroom zelf.
  void setFastUpdates(bool fast) => _throttle.fast = fast;

  /// De app komt terug op de voorgrond. Is de GPS-stroom intussen stilgevallen
  /// (Android stopte hem op de achtergrond), dan nu opnieuw aanhaken — op de
  /// voorgrond mag de voorgronddienst wél starten. Daarna meteen een verse
  /// positie delen, zodat de kaart niet op een oude plek blijft staan.
  void resume() {
    if (!_granted || _userId == null) return;
    final lastFix = _lastFixAt;
    if (_subscription == null || lastFix == null || DateTime.now().difference(lastFix) > _silentStreamAfter) {
      debugPrint('Locatiestroom stil sinds $lastFix — opnieuw aanhaken');
      _attach();
    }
    unawaited(refreshNow());
  }

  /// Vraagt nu één verse GPS-meting op en uploadt die meteen, los van het
  /// upload-tempo. Voor de knop Verversen en bij terugkeer naar de app.
  Future<void> refreshNow() async {
    if (!_granted || _userId == null) return;
    final generation = _generation;
    final position = await _device.currentPosition();
    if (position == null || !ref.mounted || generation != _generation) return;
    _queue(position, generation, force: true);
    await _uploads;
  }

  void _attach() {
    final streamGeneration = ++_streamGeneration;
    final generation = _generation;
    final old = _subscription;
    _subscription = null;
    _reattachTimer?.cancel();
    // Late events van de oude stroom worden genegeerd via de generatietellers.
    unawaited(old?.cancel());
    if (!ref.mounted) return;
    _subscription = _device.positions().listen(
      (position) {
        if (generation != _generation || streamGeneration != _streamGeneration) return;
        _lastFixAt = DateTime.now();
        _queue(position, generation);
      },
      onError: (Object error) {
        debugPrint('Locatiestroom fout: $error');
        if (ref.mounted && generation == _generation) state = TrackingStatus.error;
        _scheduleReattach(generation, streamGeneration);
      },
      onDone: () => _scheduleReattach(generation, streamGeneration),
    );
  }

  void _queue(DevicePosition position, int generation, {bool force = false}) {
    _uploads = _uploads.then((_) async {
      if (!ref.mounted || generation != _generation) return;
      await _onPosition(position, force: force);
    });
  }

  /// Herstelt de locatiestroom nadat Android hem onderweg stopzette of een fout
  /// gaf, zodat de kaart niet bevriest tot de gebruiker de app herstart.
  void _scheduleReattach(int generation, int streamGeneration) {
    if (!ref.mounted || generation != _generation || streamGeneration != _streamGeneration) return;
    _reattachTimer?.cancel();
    _reattachTimer = Timer(_reattachBackoff, () {
      if (generation != _generation || streamGeneration != _streamGeneration) return;
      if (ref.mounted) _attach();
    });
  }

  void stop() {
    _cancel();
    _userId = null;
    _familyId = null;
    _throttle.fast = false;
    state = TrackingStatus.idle;
  }

  Future<void> _onPosition(DevicePosition position, {required bool force}) async {
    final userId = _userId;
    final familyId = _familyId;
    final generation = _generation;
    if (userId == null || familyId == null) return;

    final now = DateTime.now();
    final accepted = _motion.accept(position, now);
    if (accepted == null) return;
    if (!force && !_throttle.shouldUpload(accepted, now, moving: _motion.wantsFastUpdates)) return;
    try {
      final battery = await _battery.read().timeout(_uploadTimeout);
      if (!ref.mounted || generation != _generation) return;
      final location = MemberLocation(
        userId: userId,
        familyId: familyId,
        latitude: accepted.latitude,
        longitude: accepted.longitude,
        accuracyMeters: accepted.accuracyMeters,
        speedMps: accepted.speedMps,
        battery: battery.level,
        isCharging: battery.isCharging,
        updatedAt: accepted.timestamp,
      );

      await _repository.upload(location).timeout(_uploadTimeout);
      _throttle.uploaded(accepted, now);
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
    _granted = false;
    _motion = MotionFilter();
    _throttle = UploadThrottle()..fast = _throttle.fast;
    _lastFixAt = null;
    _reattachTimer?.cancel();
    _reattachTimer = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
