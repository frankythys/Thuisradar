import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/data/road_network_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final now = DateTime.now();
  final fix = MemberLocation(
    userId: 'private-user',
    familyId: 'private-family',
    latitude: 51.21,
    longitude: 4.41,
    updatedAt: now,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('road-source-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('gebied wordt eenmaal geladen en op schijf hergebruikt', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      final query = Uri.splitQueryString(request.body)['data']!;
      expect(query, contains('out geom'));
      expect(query, isNot(contains(fix.userId)));
      expect(query, isNot(contains(fix.familyId)));
      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'way',
              'id': 1,
              'tags': {'highway': 'residential'},
              'nodes': [1, 2],
              'geometry': [
                {'lat': 51.21, 'lon': 4.41},
                {'lat': 51.22, 'lon': 4.41},
              ],
            },
          ],
        }),
        200,
      );
    });
    final source = RoadNetworkSource(
      client,
      cacheDirectory: () async => directory,
    );
    expect((await source.forFix(fix, now))!.segments, hasLength(1));
    expect(await source.forFix(fix, now), isNotNull);
    final restarted = RoadNetworkSource(
      client,
      cacheDirectory: () async => directory,
    );
    expect(await restarted.forFix(fix, now), isNotNull);
    expect(requests, 1);
    client.close();
  });

  test(
    'serverfout valt terug en veroorzaakt geen verzoek per GPS-punt',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('', 429);
      });
      final source = RoadNetworkSource(
        client,
        cacheDirectory: () async => directory,
      );
      expect(await source.forFix(fix, now), isNull);
      expect(
        await source.forFix(fix, now.add(const Duration(seconds: 5))),
        isNull,
      );
      expect(requests, 1);
      client.close();
    },
  );

  test(
    'daglimiet blokkeert netwerkverzoeken zonder betaalde fallback',
    () async {
      SharedPreferences.setMockInitialValues({
        'roads_budget_day': '${now.year}-${now.month}-${now.day}',
        'roads_budget_requests': 12,
      });
      final client = MockClient(
        (_) async => throw StateError('Geen verzoek toegestaan'),
      );
      final source = RoadNetworkSource(
        client,
        cacheDirectory: () async => directory,
      );
      expect(await source.forFix(fix, now), isNull);
      client.close();
    },
  );
}
