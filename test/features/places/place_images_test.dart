import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/places/presentation/place_icons.dart';
import 'package:thuisradar/features/places/presentation/place_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nieuwe soorten met Vlaamse naam', () {
    expect(placeIconKeys, containsAll(['daycare', 'park', 'refinery']));
    expect(placeIconKeys.last, 'place', reason: '"Andere" blijft achteraan');
    expect(placeIconLabel('daycare'), 'Kinderopvang');
    expect(placeIconLabel('park'), 'Park');
    expect(placeIconLabel('refinery'), 'Raffinaderij');
  });

  test('thuis en andere houden hun eigen beeld, de rest krijgt een foto', () {
    expect(hasPlacePhoto('home'), isFalse);
    expect(hasPlacePhoto('place'), isFalse);
    expect(placeMapAsset('home'), isNull);
    expect(placeBubbleImage('place'), isNull);
    for (final key in placeIconKeys.where((k) => k != 'home' && k != 'place')) {
      expect(hasPlacePhoto(key), isTrue, reason: key);
    }
  });

  test('elke foto bestaat in de assets (schuin voor de kaart, recht voor de ballon)', () async {
    for (final key in placeIconKeys.where(hasPlacePhoto)) {
      final map = placeMapAsset(key)!;
      expect(map, endsWith('_kaart.webp'));
      expect((await rootBundle.load(map)).lengthInBytes, greaterThan(0), reason: map);
      final bubble = 'assets/places/${key}_ballon.webp';
      expect(placeBubbleImages, contains(placeBubbleImage(key)));
      expect((await rootBundle.load(bubble)).lengthInBytes, greaterThan(0), reason: bubble);
    }
  });
}
