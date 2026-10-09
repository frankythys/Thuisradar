import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/track_point.dart';

class LocationHistoryRepository {
  LocationHistoryRepository(this._client);

  final SupabaseClient _client;

  /// Alle geschiedenispunten van [userId] op de kalenderdag van [day].
  Future<List<TrackPoint>> fetchDay(String userId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return fetchRange(userId, start, end);
  }

  Future<List<TrackPoint>> fetchRange(String userId, DateTime start, DateTime end) async {
    final points = <TrackPoint>[];
    const pageSize = 1000;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await _client
          .from('location_history')
          .select('lat, lng, speed_mps, battery, recorded_at')
          .eq('user_id', userId)
          .gte('recorded_at', start.toUtc().toIso8601String())
          .lt('recorded_at', end.toUtc().toIso8601String())
          // Expliciet oplopend: `order()` staat standaard op aflopend (nieuwste
          // eerst), en ritten, routekaart en gatendetectie verwachten oudste eerst.
          .order('recorded_at', ascending: true)
          .range(offset, offset + pageSize - 1);
      points.addAll(rows.map(TrackPoint.fromJson));
      if (rows.length < pageSize) break;
    }
    return points;
  }
}
