import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/places/data/places_repository.dart';

void main() {
  test('delete vraagt de verwijderde rij op en filtert op precies één id', () async {
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.queryParameters['id'], 'eq.place-id');
      expect(request.url.queryParameters['select'], 'id');
      return http.Response('[{"id":"place-id"}]', 200, request: request, headers: {'content-type':'application/json'});
    }));
    await PlacesRepository(client).delete('place-id');
    await client.dispose();
  });
  test('RLS of een ontbrekende rij mag niet stilzwijgend slagen', () async {
    final client = SupabaseClient('https://example.test', 'test-key', httpClient: MockClient((request) async =>
      http.Response('[]', 200, request: request, headers: {'content-type':'application/json'})));
    await expectLater(PlacesRepository(client).delete('place-id'), throwsA(isA<PostgrestException>()));
    await client.dispose();
  });
}
