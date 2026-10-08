import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/places/data/places_repository.dart';

void main() {
  test('opslaan verstuurt de gekozen locatie en alle instellingen', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/places');
        expect(jsonDecode(request.body), {
          'family_id': 'fam',
          'name': 'Werk',
          'lat': 51.2,
          'lng': 3.8,
          'radius_m': 250,
          'icon': 'work',
          'address': 'Teststraat 1',
          'watched_members': ['u1'],
          'notify_arrival': true,
          'notify_departure': false,
        });
        return http.Response('', 201, request: request);
      }),
    );
    addTearDown(client.dispose);
    await PlacesRepository(client).create(
      familyId: 'fam',
      name: 'Werk',
      latitude: 51.2,
      longitude: 3.8,
      radiusMeters: 250,
      icon: 'work',
      address: 'Teststraat 1',
      watchedMembers: ['u1'],
      notifyDeparture: false,
    );
    expect(requests, 1);
  });

  test('afgewezen opslag wordt als fout doorgegeven', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient(
        (request) async => http.Response(
          '{"message":"Geen toegang","code":"42501"}',
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      PlacesRepository(
        client,
      ).create(familyId: 'fam', name: 'Thuis', latitude: 51, longitude: 3, radiusMeters: 150, icon: 'home'),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('delete vraagt de verwijderde rij op en filtert op precies één id', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.queryParameters['id'], 'eq.place-id');
        expect(request.url.queryParameters['select'], 'id');
        return http.Response(
          '[{"id":"place-id"}]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await PlacesRepository(client).delete('place-id');
    await client.dispose();
  });
  test('RLS of een ontbrekende rij mag niet stilzwijgend slagen', () async {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient(
        (request) async =>
            http.Response('[]', 200, request: request, headers: {'content-type': 'application/json'}),
      ),
    );
    await expectLater(PlacesRepository(client).delete('place-id'), throwsA(isA<PostgrestException>()));
    await client.dispose();
  });
}
