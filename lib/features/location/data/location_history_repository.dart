import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/track_point.dart';
import 'location_repository.dart' show isMissingStepsColumn;

class LocationHistoryRepository {
  LocationHistoryRepository(this._client, {this.pageTimeout = const Duration(seconds: 10)});

  final SupabaseClient _client;

  /// Maximale wachttijd per pagina van 1000 punten. Per pagina en niet voor het
  /// geheel: een drukke dag of week telt vele pagina's, en die mogen samen
  /// langer duren zonder dat één trage aanvraag eindeloos blijft hangen.
  final Duration pageTimeout;

  static const _columns = 'lat, lng, speed_mps, battery, steps, recorded_at';
  static const _columnsWithoutSteps = 'lat, lng, speed_mps, battery, recorded_at';

  /// Zonder migratie 019 bestaat `steps` niet; dan zonder stappen ophalen.
  bool _withoutSteps = false;

  /// Alle geschiedenispunten van [userId] op de kalenderdag van [day].
  Future<List<TrackPoint>> fetchDay(String userId, DateTime day) async {
    final (start, end) = dayBounds(day);
    return fetchRange(userId, start, end);
  }

  Future<List<TrackPoint>> fetchRange(String userId, DateTime start, DateTime end) async {
    if (_withoutSteps) return _fetchRange(userId, start, end, _columnsWithoutSteps);
    try {
      return await _fetchRange(userId, start, end, _columns);
    } on PostgrestException catch (error) {
      if (!isMissingStepsColumn(error)) rethrow;
      _withoutSteps = true;
      return _fetchRange(userId, start, end, _columnsWithoutSteps);
    }
  }

  Future<List<TrackPoint>> _fetchRange(String userId, DateTime start, DateTime end, String columns) async {
    final points = <TrackPoint>[];
    const pageSize = 1000;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await _client
          .from('location_history')
          .select(columns)
          .eq('user_id', userId)
          .gte('recorded_at', start.toUtc().toIso8601String())
          .lt('recorded_at', end.toUtc().toIso8601String())
          // Expliciet oplopend: `order()` staat standaard op aflopend (nieuwste
          // eerst), en ritten, routekaart en gatendetectie verwachten oudste eerst.
          .order('recorded_at', ascending: true)
          .range(offset, offset + pageSize - 1)
          .timeout(pageTimeout);
      points.addAll(rows.map(TrackPoint.fromJson));
      if (rows.length < pageSize) break;
    }
    return points;
  }
}

/// Lokale middernacht tot de volgende lokale middernacht. Niet `+ 24 uur`: de
/// dag van de overgang naar wintertijd duurt 25 uur en die naar zomertijd 23.
(DateTime, DateTime) dayBounds(DateTime day) =>
    (DateTime(day.year, day.month, day.day), DateTime(day.year, day.month, day.day + 1));
