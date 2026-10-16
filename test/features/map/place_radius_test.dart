import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/place_radius.dart';

void main() {
  test('straal van een plaats pas zichtbaar als je ver ingezoomd bent', () {
    expect(showsPlaceRadius(12), isFalse);
    expect(showsPlaceRadius(15.9), isFalse);
    expect(showsPlaceRadius(kPlaceRadiusMinZoom), isTrue);
    expect(showsPlaceRadius(19), isTrue);
  });
}
