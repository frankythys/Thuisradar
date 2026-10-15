import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/l10n/l10n.dart';
import 'package:thuisradar/features/places/presentation/place_icons.dart';
import 'package:thuisradar/features/places/presentation/place_images.dart';

final _nl = lookupAppLocalizations(const Locale('nl'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nieuwe soorten met Vlaamse naam', () {
    expect(placeIconKeys, containsAll(['daycare', 'park', 'refinery']));
    expect(placeIconKeys.last, 'place', reason: '"Andere" blijft achteraan');
    expect(placeIconLabel(_nl, 'daycare'), 'Kinderopvang');
    expect(placeIconLabel(_nl, 'park'), 'Park');
    expect(placeIconLabel(_nl, 'refinery'), 'Raffinaderij');
  });

  test('enkel "Andere" houdt het speldje, de rest (ook Thuis) krijgt een foto', () {
    expect(hasPlacePhoto('place'), isFalse);
    expect(placeMapAsset('place'), isNull);
    expect(placeBubbleImage('place'), isNull);
    expect(placeMapAsset('home'), 'assets/places/home_kaart.webp');
    for (final key in placeIconKeys.where((k) => k != 'place')) {
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
