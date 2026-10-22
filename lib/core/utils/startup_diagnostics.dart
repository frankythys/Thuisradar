import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gerichte timing in debug/profile, zonder extra werk in release builds.
class StartupDiagnostics {
  StartupDiagnostics() {
    if (kReleaseMode) return;
    _watch.start();
    SchedulerBinding.instance.addTimingsCallback(_frames);
  }

  void watchFirstFrame() {
    if (kReleaseMode) return;
    SchedulerBinding.instance.addPostFrameCallback((_) => checkpoint('eerste Flutter-frame'));
  }

  final _watch = Stopwatch();
  int _previousStage = 0;
  int _lastFrameLog = -5000;

  final _once = <String>{};

  /// Zoals [checkpoint], maar elke stap maar één keer (bv. "eerste kaartbeeld",
  /// ook als het kaartscherm later opnieuw opgebouwd wordt).
  void checkpointOnce(String stage) {
    if (_once.add(stage)) checkpoint(stage);
  }

  void checkpoint(String stage) {
    if (kReleaseMode) return;
    final elapsed = _watch.elapsedMilliseconds;
    debugPrint('[Performance] $stage: ${elapsed - _previousStage} ms sinds vorige stap; totaal $elapsed ms');
    _previousStage = elapsed;
  }

  void _frames(List<FrameTiming> frames) {
    if (frames.isEmpty || _watch.elapsedMilliseconds - _lastFrameLog < 5000) {
      return;
    }
    final worst = frames.reduce((a, b) => a.totalSpan > b.totalSpan ? a : b);
    if (worst.totalSpan < const Duration(milliseconds: 100)) return;
    _lastFrameLog = _watch.elapsedMilliseconds;
    debugPrint(
      '[Performance] traag frame: build=${worst.buildDuration.inMilliseconds} ms, '
      'raster=${worst.rasterDuration.inMilliseconds} ms, '
      'vsync-wacht=${worst.vsyncOverhead.inMilliseconds} ms, '
      'totaal=${worst.totalSpan.inMilliseconds} ms',
    );
  }
}

/// De opstartmeting van `main.dart`, voor meetpunten verderop (de kaart).
/// Null in tests en waar niets gemeten wordt.
final startupDiagnosticsProvider = Provider<StartupDiagnostics?>((ref) => null);
