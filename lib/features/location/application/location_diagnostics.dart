import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/diagnostics_store.dart';
import '../domain/diagnostic_tally.dart';
import '../domain/motion_filter.dart';

/// Om de zoveel tijd een levensteken met de tellers sinds het vorige.
const diagnosticHeartbeat = Duration(minutes: 1);

final diagnosticsStoreProvider = Provider<DiagnosticsStore>((ref) => DiagnosticsStore());

/// In `main.dart` overschreven met het exemplaar dat al bij de appstart loopt.
final locationDiagnosticsProvider = Provider<LocationDiagnostics>((ref) {
  final diagnostics = LocationDiagnostics(ref.watch(diagnosticsStoreProvider));
  ref.onDispose(diagnostics.dispose);
  return diagnostics;
});

/// Legt lokaal vast waar de locatieketen stopt: GPS ontvangen → meting
/// aanvaard of geweigerd (met reden) → upload geslaagd of mislukt. Daarnaast
/// appstart, voorgrond/achtergrond, start/stop/fout van de GPS-stroom en een
/// periodiek levensteken.
///
/// Let op bij het lezen: een ontbrekend levensteken bewijst niet dat Android
/// het proces beëindigde — het kan ook bevroren/gepauzeerd zijn. Enkel een
/// nieuwe "appstart"-regel na het gat wijst op een herstart van het proces.
class LocationDiagnostics {
  LocationDiagnostics(this._sink, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DiagnosticsSink _sink;
  final DateTime Function() _clock;
  final _tally = DiagnosticTally();
  Timer? _heartbeat;
  DateTime? _lastBeatAt;
  Future<void> _writes = Future<void>.value();

  /// Appstart: schrijft de startregel en begint het levensteken.
  void start() {
    event('appstart');
    _heartbeat?.cancel();
    _lastBeatAt = _clock();
    _heartbeat = Timer.periodic(diagnosticHeartbeat, (_) => beat());
  }

  /// Een losse gebeurtenis, meteen weggeschreven.
  void event(String label, [Object? detail]) =>
      _write('${diagnosticTimestamp(_clock())} $label${detail == null ? '' : ': $detail'}');

  void lifecycle(AppLifecycleState state) => event(switch (state) {
    AppLifecycleState.resumed => 'voorgrond',
    AppLifecycleState.inactive => 'inactief',
    AppLifecycleState.hidden => 'verborgen',
    AppLifecycleState.paused => 'achtergrond',
    AppLifecycleState.detached => 'losgekoppeld',
  });

  void received() => _tally.onReceived(_clock());
  void accepted() => _tally.onAccepted();
  void rejected(RejectReason reason, double? accuracyMeters) => _tally.onRejected(reason, accuracyMeters);
  void throttled() => _tally.onThrottled();
  void uploadOk() => _tally.onUploadOk(_clock());

  /// Hoeveel punten nog in de wachtrij staan (komt in het levensteken).
  void pending(int count) => _tally.pending = count;

  void uploadFailed(Object error) {
    _tally.onUploadFailed();
    event('upload mislukt', error);
  }

  /// Levensteken met de tellers sinds het vorige. Kwam het vorige veel te
  /// laat (app bevroren of proces gestopt), dan staat de stilte erbij.
  void beat() {
    final now = _clock();
    final last = _lastBeatAt;
    _lastBeatAt = now;
    final silence = last == null ? null : now.difference(last);
    final late = silence != null && silence > diagnosticHeartbeat * 2
        ? ' · vorig levensteken ${silence.inSeconds} s geleden'
        : '';
    _write('${diagnosticTimestamp(now)} levensteken: ${_tally.summary(now)}$late');
  }

  /// Wacht tot alles weggeschreven is (voor export en tests).
  Future<void> flush() => _writes;

  void dispose() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void _write(String line) {
    debugPrint('[Diagnose] $line');
    _writes = _writes.then((_) async {
      try {
        await _sink.append([line]);
      } catch (error) {
        debugPrint('Diagnose wegschrijven mislukt: $error');
      }
    });
  }
}
