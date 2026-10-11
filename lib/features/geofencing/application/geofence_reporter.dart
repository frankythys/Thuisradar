import '../data/geofence_event_api.dart';
import '../data/geofence_store.dart';
import '../domain/geofence_report.dart';

/// Verstuurt aankomst/vertrek van dit toestel. Zonder netwerk blijft een melding
/// in de wachtrij en gaat ze mee bij de volgende kans (volgende zone-overgang
/// of als de app opent), met haar oorspronkelijke tijdstip.
class GeofenceReporter {
  GeofenceReporter({required this._store, required this._api, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final GeofenceStore _store;
  final GeofenceEventApi _api;
  final DateTime Function() _clock;

  /// Antwoorden van de server per verstuurde melding (voor logs en tests).
  Future<List<String>> report(List<GeofenceReport> reports) async {
    final key = await _store.deviceKey();
    if (key == null) return const []; // afgemeld of delen uit
    // Eerst duurzaam opslaan, ook als de callback tijdens het versturen stopt.
    await _store.enqueue(key, reports);
    final pending = await _store.pending(key);
    final queue = pruneReportQueue(pending, now: _clock());
    for (final report in pending) {
      if (!queue.contains(report)) await _store.acknowledge(key, report);
    }
    final answers = <String>[];
    for (final report in queue) {
      if (await _store.deviceKey() != key) break;
      try {
        answers.add(await _api.send(deviceKey: key, report: report));
        await _store.acknowledge(key, report);
      } on GeofenceSendException catch (error) {
        answers.add('error: ${error.message}');
        // Na één netwerkfout blijven deze en volgende meldingen bewaard.
        if (error.retry) break;
        await _store.acknowledge(key, report);
      }
    }
    return answers;
  }

  /// Wachtrij leegmaken zonder nieuwe melding.
  Future<List<String>> flush() => report(const []);
}
