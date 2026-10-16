import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/shared/widgets/location_preview.dart';

void main() {
  test('routelink naar een punt; te voet voor een geparkeerde auto', () {
    final car = directionsUri(51.0543, 3.7174);
    expect(car.host, 'www.google.com');
    expect(car.queryParameters['destination'], '51.0543,3.7174');
    expect(car.queryParameters.containsKey('travelmode'), isFalse);

    expect(directionsUri(51.0543, 3.7174, walking: true).queryParameters['travelmode'], 'walking');
  });
}
