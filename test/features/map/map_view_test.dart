import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/map/application/map_view_recorder.dart';
import 'package:thuisradar/features/map/data/map_view_store.dart';
import 'package:thuisradar/features/map/domain/map_view.dart';

class _Store extends Mock implements MapViewStore {}

const _gent = MapView(latitude: 51.0543, longitude: 3.7174, zoom: 14.5);

void main() {
  setUpAll(() => registerFallbackValue(_gent));

  group('opslaan en teruglezen', () {
    test('encode/decode geeft dezelfde plek terug', () {
      expect(MapView.decode(_gent.encode()), _gent);
    });

    test('onzin of buiten de wereld: niets', () {
      for (final raw in [null, '', 'abc', '51,4', '51,4,x', '95,4,10', '51,200,10', '51,4,30', 'NaN,4,10']) {
        expect(MapView.decode(raw), isNull, reason: raw);
      }
    });
  });

  group('waar de kaart opent', () {
    test('liefst waar ze de vorige keer stond', () {
      expect(startView(saved: _gent, own: (latitude: 50.0, longitude: 5.0)), _gent);
    });

    test('anders de eigen locatie, op buurtniveau', () {
      expect(
        startView(own: (latitude: 50.0, longitude: 5.0)),
        const MapView(latitude: 50, longitude: 5, zoom: 12),
      );
    });

    test('anders België, uitgezoomd', () {
      expect(startView(), fallbackView);
      expect(fallbackView.zoom, 8);
    });
  });

  testWidgets('de kaart bewaart haar positie pas als ze even stilligt', (tester) async {
    final store = _Store();
    when(() => store.write(any())).thenAnswer((_) async {});
    final controller = MapController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FlutterMap(
          mapController: controller,
          options: const MapOptions(initialCenter: LatLng(50.85, 4.35), initialZoom: 8),
          children: const [],
        ),
      ),
    );
    final recorder = MapViewRecorder(controller, store, quiet: const Duration(milliseconds: 500));
    addTearDown(recorder.dispose);
    recorder.start();

    controller.move(const LatLng(51.0543, 3.7174), 14);
    await tester.pump(const Duration(milliseconds: 200));
    controller.move(const LatLng(51.06, 3.72), 15);
    await tester.pump(const Duration(milliseconds: 200));
    verifyNever(() => store.write(any()));

    await tester.pump(const Duration(milliseconds: 600));
    final saved = verify(() => store.write(captureAny())).captured.single as MapView;
    expect(saved.latitude, closeTo(51.06, 1e-6));
    expect(saved.longitude, closeTo(3.72, 1e-6));
    expect(saved.zoom, 15);
  });
}
