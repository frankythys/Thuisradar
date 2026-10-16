import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/parked_car/data/parked_car_repository.dart';

void main() {
  test('slaat de parkeerplek op met sleutel per gebruiker en familie', () async {
    final parkedAt = DateTime.utc(2026, 10, 16, 9, 30);
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/parked_cars');
        expect(request.url.queryParameters['on_conflict'], 'user_id,family_id');
        expect(jsonDecode(request.body), {
          'user_id': 'user-1',
          'family_id': 'family-1',
          'lat': 51.2,
          'lng': 3.8,
          'parked_at': parkedAt.toIso8601String(),
        });
        return http.Response('', 201, request: request);
      }),
    );
    addTearDown(client.dispose);

    await ParkedCarRepository(client)
        .save(userId: 'user-1', familyId: 'family-1', latitude: 51.2, longitude: 3.8, parkedAt: parkedAt);
  });

  test('verwijdert enkel de parkeerplek van deze gebruiker in deze familie', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.queryParameters['user_id'], 'eq.user-1');
        expect(request.url.queryParameters['family_id'], 'eq.family-1');
        expect(request.url.queryParameters['select'], 'user_id');
        return http.Response(
          '[{"user_id":"user-1"}]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    await ParkedCarRepository(client).remove(userId: 'user-1', familyId: 'family-1');
  });
}
