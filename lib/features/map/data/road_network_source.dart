import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../location/domain/member_location.dart';
import '../domain/road_matching.dart';

/// Gratis OSM-wegdata. Gebieden worden op schijf hergebruikt; geen verzoek per
/// GPS-fix. Publieke Overpass is alleen geschikt voor beperkt persoonlijk gebruik.
class RoadNetworkSource {
  RoadNetworkSource(
    this.client, {
    this.cacheDirectory = getApplicationSupportDirectory,
    this.endpoint = 'https://overpass-api.de/api/interpreter',
  });

  final http.Client client;
  final Future<Directory> Function() cacheDirectory;
  final String endpoint;
  final _memory = <String, RoadNetwork>{};
  bool _fetching = false;
  DateTime? _lastRequest;

  Future<RoadNetwork?> forFix(MemberLocation fix, DateTime now) async {
    try {
      return await _loadFix(fix, now);
    } catch (_) {
      return null;
    }
  }

  Future<RoadNetwork?> _loadFix(MemberLocation fix, DateTime now) async {
    // Vaste gebiedsvakken; het verzoek bevat geen ritpunten of gebruikers-ID.
    final row = (fix.latitude / 0.05).floor();
    final column = (fix.longitude / 0.08).floor();
    final key = '${row}_$column';
    if (_memory.containsKey(key)) return _memory[key];
    final directory = Directory('${(await cacheDirectory()).path}/roads');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$key.json.gz');
    if (await file.exists()) {
      try {
        if (now.difference((await file.stat()).modified) <
            const Duration(days: 30)) {
          final bytes = await file.readAsBytes();
          final network = await compute(
            _decodeCachedRoads,
            bytes,
            debugLabel: 'roads-cache-decode',
          );
          return _remember(key, network);
        }
      } catch (_) {
        /* Beschadigde cache wordt vervangen zodra netwerk beschikbaar is. */
      }
    }
    if (_fetching ||
        (_lastRequest != null &&
            now.difference(_lastRequest!) < const Duration(minutes: 1))) {
      return null;
    }
    _fetching = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = '${now.year}-${now.month}-${now.day}';
      final sameDay = prefs.getString('roads_budget_day') == day;
      final requests = sameDay ? prefs.getInt('roads_budget_requests') ?? 0 : 0;
      final bytes = sameDay ? prefs.getInt('roads_budget_bytes') ?? 0 : 0;
      // Bewust lage grens voor de gedeelde gratis server; geen betaalde fallback.
      if (requests >= 12 || bytes >= 6000000) return null;
      _lastRequest = now;
      await prefs.setString('roads_budget_day', day);
      await prefs.setInt('roads_budget_requests', requests + 1);
      final south = math.max(-90, row * 0.05 - 0.005);
      final north = math.min(90, (row + 1) * 0.05 + 0.005);
      final west = math.max(-180, column * 0.08 - 0.005);
      final east = math.min(180, (column + 1) * 0.08 + 0.005);
      final types = carHighways.join('|');
      final query =
          '[out:json][timeout:8];way[highway~"^($types)\$"]($south,$west,$north,$east);out geom;';
      final response = await client
          .post(
            Uri.parse(endpoint),
            headers: {
              'User-Agent': 'CircleBeacon/1.0 (personal family location app)',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 12));
      await prefs.setInt(
        'roads_budget_bytes',
        bytes + response.bodyBytes.length,
      );
      if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
        return null;
      }
      final decoded = await compute(
        _decodeDownloadedRoads,
        response.bodyBytes,
        debugLabel: 'roads-network-decode',
      );
      if (decoded == null) return null;
      final network = decoded.network;
      await file.writeAsBytes(decoded.compressed, flush: true);
      final files = await directory
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.json.gz'))
          .cast<File>()
          .toList();
      if (files.length > 16) {
        final dated = [
          for (final cached in files)
            (file: cached, at: (await cached.stat()).modified),
        ]..sort((a, b) => a.at.compareTo(b.at));
        for (final old in dated.take(files.length - 16)) {
          await old.file.delete();
        }
      }
      return _remember(key, network);
    } catch (_) {
      return null;
    } finally {
      _fetching = false;
    }
  }

  RoadNetwork _remember(String key, RoadNetwork network) {
    if (_memory.length >= 16) _memory.remove(_memory.keys.first);
    _memory[key] = network;
    return network;
  }
}

RoadNetwork _decodeCachedRoads(List<int> bytes) => RoadNetwork.fromOverpass(
  jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>,
);

({RoadNetwork network, List<int> compressed})? _decodeDownloadedRoads(
  List<int> bytes,
) {
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (json['elements'] is! List || json.containsKey('remark')) return null;
  return (
    network: RoadNetwork.fromOverpass(json),
    compressed: gzip.encode(bytes),
  );
}
