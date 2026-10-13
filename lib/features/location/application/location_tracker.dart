import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../data/battery_source.dart';
import '../data/device_location_source.dart';
import '../data/location_repository.dart';
import '../data/step_source.dart';
import '../domain/device_reading.dart';
import '../domain/member_location.dart';
import '../domain/motion_filter.dart';
import '../domain/pending_uploads.dart';
import '../domain/upload_throttle.dart';
import 'location_diagnostics.dart';
import 'location_providers.dart';
import 'tracking_status.dart';
import '../../profile/application/profile_providers.dart';

/// Een hangende upload mag de volgende metingen niet blokkeren.
const _uploadTimeout = Duration(seconds: 15);

/// Na een onderbroken locatiestroom wachten we even voor we opnieuw proberen.
const _reattachBackoff = Duration(seconds: 5);

/// Zo lang zonder één meting = de GPS-stroom is stilgevallen.
const _silentStreamAfter = Duration(seconds: 45);

/// Zoveel keer op rij weigert de server hetzelfde punt (geen netwerkfout):
/// dan valt het weg, anders bleef de hele wachtrij erachter hangen.
const _maxServerRefusals = 3;

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
  StreamSubscription<int>? _steps;
  int? _latestSteps;

  /// Punten die nog naar de server moeten (bv. even geen internet).
  final _pending = PendingUploads();

  /// Na een mislukte upload: wachten tot deze timer afloopt.
  Timer? _retryTimer;

  DeviceLocationSource get _device => ref.read(deviceLocationSourceProvider);
  BatterySource get _battery => ref.read(batterySourceProvider);
  LocationRepository get _repository => ref.read(locationRepositoryProvider);
  LocationDiagnostics get _diagnostics => ref.read(locationDiagnosticsProvider);
  StepSource get _stepSource => ref.read(stepSourceProvider);

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
      _diagnostics.event('delen niet gestart', 'gepauzeerd in profiel');
      state = TrackingStatus.idle;
      return;
    }
    final access = await _device.ensureAccess();
    if (!ref.mounted || generation != _generation) return;

    state = TrackingStatus.fromAccess(access);
    if (access != LocationAccess.granted) {
      _diagnostics.event('delen niet gestart', 'locatietoestemming: ${access.name}');
      return;
    }

    _granted = true;
    _diagnostics.event('delen gestart');
    _attach();
    unawaited(_attachSteps());
  }

  /// Vraagt toestemming voor de stappenteller en telt meteen mee als die er
  /// is. Geeft terug of het gelukt is.
  Future<bool> enableSteps() async {
    if (!await _stepSource.requestAccess()) return false;
    if (ref.mounted) await _attachSteps();
    return true;
  }

  /// Luistert naar de stappenteller als er toestemming is. Zonder toestemming
  /// of stappenteller blijven de stappen gewoon leeg; het delen gaat door.
  Future<void> _attachSteps() async {
    if (_steps != null || !_granted) return;
    final generation = _generation;
    if (!await _stepSource.hasAccess()) return;
    if (!ref.mounted || generation != _generation || _steps != null) return;
    _steps = _stepSource.counts().listen(
      (steps) {
        if (generation == _generation) _latestSteps = steps;
      },
      onError: (Object error) {
        debugPrint('Stappenteller fout: $error');
        if (generation != _generation) return;
        unawaited(_steps?.cancel());
        _steps = null;
        _latestSteps = null;
      },
      cancelOnError: true,
    );
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
    if (_subscription == null || lastFix == null || clock.now().difference(lastFix) > _silentStreamAfter) {
      debugPrint('Locatiestroom stil sinds $lastFix — opnieuw aanhaken');
      _diagnostics.event('stroom stil bij hervatten', 'laatste GPS ${lastFix ?? 'nooit'}');
      _attach();
    }
    // Intussen misschien toestemming gegeven voor de stappenteller.
    unawaited(_attachSteps());
    unawaited(refreshNow());
  }

  /// Vraagt nu één verse GPS-meting op en uploadt die meteen, los van het
  /// upload-tempo. Voor de knop Verversen en bij terugkeer naar de app.
  Future<void> refreshNow() async {
    if (!_granted || _userId == null) return;
    final generation = _generation;
    final position = await _device.currentPosition();
    if (!ref.mounted || generation != _generation) return;
    _diagnostics.event('verse meting', position == null ? 'geen positie' : 'ontvangen');
    if (position == null) return;
    // Telt mee als ontvangen, anders stond "aanvaard" hoger dan "ontvangen".
    _diagnostics.received();
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
    _diagnostics.event('stroom gestart');
    _subscription = _device.positions().listen(
      (position) {
        if (generation != _generation || streamGeneration != _streamGeneration) return;
        _lastFixAt = clock.now();
        _diagnostics.received();
        _queue(position, generation);
      },
      onError: (Object error) {
        debugPrint('Locatiestroom fout: $error');
        if (ref.mounted) _diagnostics.event('stroom fout', error);
        if (ref.mounted && generation == _generation) state = TrackingStatus.error;
        _scheduleReattach(generation, streamGeneration);
      },
      onDone: () {
        if (ref.mounted) _diagnostics.event('stroom gestopt');
        _scheduleReattach(generation, streamGeneration);
      },
    );
  }

  void _queue(DevicePosition position, int generation, {bool force = false}) {
    // De leeftijd telt vanaf ontvangst: wacht een meting achter een trage
    // upload, dan is ze daarom nog niet "te oud".
    final receivedAt = clock.now();
    _uploads = _uploads
        .then((_) async {
          if (!ref.mounted || generation != _generation) return;
          await _onPosition(position, receivedAt: receivedAt, force: force);
        })
        // Eén onverwachte Error mag de keten niet breken: anders werd elke
        // volgende meting stil overgeslagen tot de app herstartte.
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Locatie verwerken mislukt: $error');
          debugPrintStack(stackTrace: stackTrace);
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

  /// Stopt het delen; [reason] komt in het diagnoselogboek (bv. "uitgelogd").
  void stop({String? reason}) {
    if (_granted) _diagnostics.event('delen gestopt', reason);
    _cancel();
    _userId = null;
    _familyId = null;
    _throttle.fast = false;
    state = TrackingStatus.idle;
  }

  Future<void> _onPosition(
    DevicePosition position, {
    required DateTime receivedAt,
    required bool force,
  }) async {
    final userId = _userId;
    final familyId = _familyId;
    final generation = _generation;
    if (userId == null || familyId == null) return;

    final now = receivedAt;
    final accepted = _motion.accept(position, now);
    final diagnostics = _diagnostics;
    if (accepted == null) {
      diagnostics.rejected(_motion.lastRejection ?? RejectReason.invalid, position.accuracyMeters);
      return;
    }
    diagnostics.accepted();
    if (!force && !_throttle.shouldUpload(accepted, now, moving: _motion.wantsFastUpdates)) {
      diagnostics.throttled();
      // Nog iets in de wachtrij en de wachttijd is om: nu opnieuw proberen.
      if (!_pending.isEmpty && _retryTimer == null) await _flush(generation);
      return;
    }
    BatteryReading? battery;
    try {
      battery = await _battery.read().timeout(_uploadTimeout);
    } on Exception catch (error) {
      // Zonder batterijstand gaat de locatie toch mee.
      debugPrint('Batterij lezen mislukt: $error');
    }
    if (!ref.mounted || generation != _generation) return;
    _pending.add(
      MemberLocation(
        userId: userId,
        familyId: familyId,
        latitude: accepted.latitude,
        longitude: accepted.longitude,
        accuracyMeters: accepted.accuracyMeters,
        speedMps: accepted.speedMps,
        battery: battery?.level,
        isCharging: battery?.isCharging,
        steps: _latestSteps,
        updatedAt: accepted.timestamp,
      ),
    );
    // Het upload-tempo telt vanaf het moment dat het punt klaarstaat, ook
    // zonder netwerk: zo blijft het spoor even fijn en komt er geen vergeefse
    // poging bij elke meting.
    _throttle.uploaded(accepted, now);
    if (force || _retryTimer == null) await _flush(generation, force: force);
  }

  /// Verstuurt de wachtrij, oudste eerst: zo eindigt de kaart op de nieuwste
  /// plek en komen gemiste punten in de geschiedenis. Stopt bij de eerste
  /// mislukte poging en probeert later opnieuw, steeds iets later.
  Future<void> _flush(int generation, {bool force = false}) async {
    if (force) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
    final diagnostics = _diagnostics;
    final backlog = _pending.length;
    var sent = 0;
    while (!_pending.isEmpty) {
      if (!ref.mounted || generation != _generation) return;
      final next = _pending.next!;
      try {
        await _repository.upload(next).timeout(_uploadTimeout);
        _pending.sent();
        sent++;
        diagnostics.uploadOk();
        if (ref.mounted && generation == _generation) state = TrackingStatus.active;
      } on Object catch (error) {
        debugPrint('Locatie uploaden mislukt: $error');
        diagnostics.uploadFailed(error);
        if (!ref.mounted || generation != _generation) return;
        state = TrackingStatus.offline;
        if (error is PostgrestException && _pending.failures + 1 >= _maxServerRefusals) {
          // De server weigert dit punt telkens: overslaan, de rest gaat door.
          diagnostics.event('punt overgeslagen', 'server weigert het: ${error.message}');
          _pending.sent();
          continue;
        }
        _scheduleRetry(generation, _pending.failed());
        break;
      }
    }
    diagnostics.pending(_pending.length);
    if (backlog > 1 && sent > 1) diagnostics.event('wachtrij verstuurd', '$sent punten nagestuurd');
  }

  void _scheduleRetry(int generation, Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!ref.mounted || generation != _generation || _pending.isEmpty) return;
      _uploads = _uploads.then((_) => _flush(generation)).catchError((Object error) {
        debugPrint('Wachtrij versturen mislukt: $error');
      });
    });
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
    _retryTimer?.cancel();
    _retryTimer = null;
    _pending.clear();
    _subscription?.cancel();
    _subscription = null;
    _steps?.cancel();
    _steps = null;
    _latestSteps = null;
  }
}
