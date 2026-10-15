import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/feature_flags.dart';
import '../data/activity_source.dart';
import '../domain/motion_activity.dart';

/// Houdt de laatste activiteitsherkenning van dit toestel bij, zodat
/// [LocationTracker] ze bij elke meting kan meesturen. Doet niets met de
/// feature flag `USE_ACTIVITY_RECOGNITION` uit, of zonder toestemming.
class ActivityWatcher {
  ActivityWatcher(this._source, {bool? enabled}) : _enabled = enabled ?? FeatureFlags.useActivityRecognition;

  final ActivitySource _source;
  final bool _enabled;
  StreamSubscription<ActivityReading>? _subscription;
  ActivityReading? _latest;

  /// Verhoogd bij elke stop, zodat een trage start na een stop niets meer doet.
  int _generation = 0;

  /// Begint te luisteren als dat mag; een tweede keer is zonder effect.
  Future<void> start() async {
    if (!_enabled || _subscription != null) return;
    final generation = _generation;
    if (!await _source.hasAccess()) return;
    if (generation != _generation || _subscription != null) return;
    _subscription = _source.readings().listen(
      (reading) {
        if (generation == _generation) _latest = reading;
      },
      onError: (Object error) {
        // Geen Play Services of geen sensor: dan zonder herkenning verder.
        debugPrint('Activiteitsherkenning fout: $error');
        if (generation == _generation) _reset();
      },
      cancelOnError: true,
    );
  }

  /// De herkenning die bij een meting op [now] meegaat, of null.
  MotionActivity? current(DateTime now) => currentActivity(_latest, now);

  void stop() {
    _generation++;
    _reset();
  }

  void _reset() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _latest = null;
  }
}
