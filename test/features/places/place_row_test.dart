import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/places/domain/place.dart';
import 'package:thuisradar/features/places/presentation/place_row.dart';

Place _place({bool arrival = true, bool departure = true, List<String>? watched, String? owner}) => Place(
  id: 'p',
  familyId: 'f',
  name: 'Thuis',
  latitude: 51,
  longitude: 4,
  radiusMeters: 150,
  icon: 'home',
  notifyArrival: arrival,
  notifyDeparture: departure,
  watchedMembers: watched,
  ownerUserId: owner,
);

void main() {
  test('meldingsregel vat aankomst en vertrek kort samen', () {
    expect(notificationSummary(_place()), 'Aankomst & vertrek');
    expect(notificationSummary(_place(departure: false)), 'Enkel aankomst');
    expect(notificationSummary(_place(arrival: false)), 'Enkel vertrek');
    expect(notificationSummary(_place(arrival: false, departure: false)), 'Meldingen uit');
  });

  test('beperkt tot enkele leden: dat staat erbij', () {
    expect(notificationSummary(_place(watched: ['a'])), 'Aankomst & vertrek · voor 1 lid');
    expect(notificationSummary(_place(watched: ['a', 'b'])), 'Aankomst & vertrek · voor 2 leden');
  });
}
