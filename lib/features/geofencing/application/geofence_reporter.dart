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
    final queue = pruneReportQueue([...await _store.pending(), ...reports], now: _clock());
    final answers = <String>[];
    final remaining = <GeofenceReport>[];
    for (final report in queue) {
      // Na één netwerkfout de rest niet meer proberen: die faalt toch.
      if (remaining.isNotEmpty) {
        remaining.add(report);
        continue;
      }
      try {
        answers.add(await _api.send(deviceKey: key, report: report));
      } on GeofenceSendException catch (error) {
        if (error.retry) remaining.add(report);
        answers.add('error: ${error.message}');
      }
    }
    await _store.savePending(remaining);
    return answers;
  }

  /// Wachtrij leegmaken zonder nieuwe melding.
  Future<List<String>> flush() => report(const []);
}
