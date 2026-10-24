import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../places/domain/place.dart';
import '../../../places/presentation/place_icons.dart';
import '../../../places/presentation/place_images.dart';
import '../../domain/google_camera.dart';
import '../../domain/place_radius.dart';
import '../../domain/map_style.dart';
import 'google_member_markers.dart';
import 'google_place_overlays.dart';
import 'map_marker_spec.dart';
import 'member_history_bubble.dart'
    show bubbleBikeImage, bubbleCarImage, bubbleHomeImage;
import 'widget_bitmap.dart';

/// Google Maps als achtergrond onder de bestaande kaart.
///
/// De bovenliggende flutter_map blijft alles doen (gebaren, markers, ballonnen,
/// groepspin, auto-fit); deze kaart tekent de ondergrond en de plaatsen en
/// volgt de camera via [controller]. Zelf reageert ze niet op aanraking.
///
/// Plaatsen en gezinsleden tekent Google zelf (als afbeeldingen): die zitten
/// zo vast aan de kaart en glijden niet mee terwijl de camera even achterloopt
/// tijdens het scrollen. De kaart erboven levert de markers via [markers].
class GoogleBaseMap extends StatefulWidget {
  const GoogleBaseMap({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.initialZoom,
    this.satellite,
    this.bottomPadding = 0,
    this.places = const [],
    this.markers,
  });

  final MapController controller;
  final LatLng initialCenter;
  final double initialZoom;

  /// Keuze met de kaartknop; `null` = automatisch (zie [showsSatellite]).
  final bool? satellite;
  final List<Place> places;

  /// Leden, groepspinnen en ballonnen zoals de kaart erboven ze berekent.
  final ValueListenable<List<MapMarkerSpec>>? markers;

  /// Hoogte van het onderpaneel: het Google-logo blijft erboven zichtbaar.
  final double bottomPadding;

  @override
  State<GoogleBaseMap> createState() => _GoogleBaseMapState();
}

class _GoogleBaseMapState extends State<GoogleBaseMap> {
  /// Onzichtbaar klein, maar groot genoeg om Google een nieuw beeld te laten
  /// tekenen.
  static const _redrawZoomStep = 0.01;
  static const _redrawDelay = Duration(milliseconds: 150);

  gm.GoogleMapController? _google;
  StreamSubscription<MapEvent>? _events;
  ({double latitude, double longitude, double zoom, double bearing})? _wanted;

  ({double latitude, double longitude, double zoom, double bearing})? _shown;
  bool _moving = false;
  double _zoom = 0;
  final _icons = <String, gm.BitmapDescriptor>{};
  double? _iconPixelRatio;
  late final _members = GoogleMemberMarkers(
    onChanged: (markers) {
      if (!mounted) return;
      final first = _memberMarkers.isEmpty && markers.isNotEmpty;
      setState(() => _memberMarkers = markers);
      // De eerste personen: Google tekent ze pas na een camerabeweging.
      if (first) {
        _redrawTries = 0;
        _scheduleRedraw();
      }
    },
  );
  Set<gm.Marker> _memberMarkers = const {};
  Timer? _redrawTimer;
  int _redrawTries = 0;
  final _mapReady = Completer<void>();
  Timer? _mapReadyFallback;

  /// Zoveel hertekenpogingen (elke [_redrawDelay]) voordat we opgeven.
  static const _redrawTriesMax = 60;

  /// Vangnet als Google geen `onCameraIdle` meldt (trage start, debugger):
  /// zonder dat signaal wacht het tekenen van de markers voorgoed.
  static const _mapReadyFallbackDelay = Duration(seconds: 4);

  Future<void> _assetsReady = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
    _wanted = (
      latitude: widget.initialCenter.latitude,
      longitude: widget.initialCenter.longitude,
      zoom: widget.initialZoom,
      bearing: 0.0,
    );
    widget.markers?.addListener(_onMarkers);
    _events = widget.controller.mapEventStream.listen((event) {
      final camera = event.camera;
      final before = showsSatellite(choice: widget.satellite, zoom: _zoom);
      final radiusBefore = showsPlaceRadius(_zoom);
      _zoom = camera.zoom;
      final changed =
          showsSatellite(choice: widget.satellite, zoom: _zoom) != before ||
          showsPlaceRadius(_zoom) != radiusBefore;
      if (changed && mounted) setState(() {});
      _wanted = (
        latitude: camera.center.latitude,
        longitude: camera.center.longitude,
        zoom: camera.zoom,
        bearing: (-camera.rotation + 360) % 360,
      );
      unawaited(_sync());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIcons();
    // Afbeeldingen in de markers moeten klaar zijn vóór we ze tekenen.
    _assetsReady = Future.wait([
      for (final image in <ImageProvider>[
        bubbleHomeImage,
        bubbleCarImage,
        bubbleBikeImage,
        ...placeBubbleImages,
      ])
        precacheImage(image, context),
    ]);
    _onMarkers();
  }

  void _onMarkers() {
    final markers = widget.markers;
    if (markers == null || !mounted) return;
    _members.update(
      markers.value,
      wrap: wrapForBitmap(context),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      ready: Future.wait([_assetsReady, _mapReady.future]),
    );
  }

  /// Tekent elk gebruikt plaats-icoon één keer als bitmap.
  void _loadIcons() {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (_iconPixelRatio != pixelRatio) {
      _iconPixelRatio = pixelRatio;
      _icons.clear();
    }
    for (final key in widget.places.map((p) => p.icon).toSet()) {
      if (_icons.containsKey(key)) continue;
      final photo = placeMapAsset(key);
      final bitmap = photo != null
          ? placeImageBitmap(
              photo,
              width: kPlaceMapImageWidth,
              pixelRatio: pixelRatio,
            )
          : placeIconBitmap(
              placeIcon(key),
              color: AppColors.primary,
              size: 20,
              pixelRatio: pixelRatio,
            );
      unawaited(
        bitmap.then((icon) {
          if (!mounted || _iconPixelRatio != pixelRatio) return;
          setState(() => _icons[key] = icon);
        }),
      );
    }
  }

  @override
  void didUpdateWidget(covariant GoogleBaseMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.places != widget.places) _loadIcons();
    if (oldWidget.markers != widget.markers) {
      oldWidget.markers?.removeListener(_onMarkers);
      widget.markers?.addListener(_onMarkers);
    }
    if (oldWidget.bottomPadding != widget.bottomPadding) {
      _shown = null; // middelpunt verschuift mee met de padding
      unawaited(_sync());
    }
  }

  @override
  void dispose() {
    widget.markers?.removeListener(_onMarkers);
    _redrawTimer?.cancel();
    _mapReadyFallback?.cancel();
    _members.dispose();
    unawaited(_events?.cancel());
    super.dispose();
  }

  /// Eén verplaatsing tegelijk; tussentijdse camerastanden worden overgeslagen,
  /// enkel de laatste telt.
  Future<void> _sync() async {
    final google = _google;
    if (google == null || _moving) return;
    while (mounted) {
      final wanted = _wanted;
      if (wanted == null) return;
      final shown = _shown;
      if (shown != null &&
          !googleCameraChanged(
            (
              latitude: shown.latitude,
              longitude: shown.longitude,
              zoom: shown.zoom,
            ),
            (
              latitude: wanted.latitude,
              longitude: wanted.longitude,
              zoom: wanted.zoom,
            ),
          ) &&
          (shown.bearing - wanted.bearing).abs() < .001) {
        return;
      }
      _moving = true;
      final target = googleCameraTarget(
        latitude: wanted.latitude,
        longitude: wanted.longitude,
        zoom: wanted.zoom,
        bottomPadding: widget.bottomPadding,
        bearing: wanted.bearing,
      );
      try {
        await google.moveCamera(
          gm.CameraUpdate.newCameraPosition(
            gm.CameraPosition(
              target: gm.LatLng(target.latitude, target.longitude),
              zoom: wanted.zoom,
              bearing: wanted.bearing,
            ),
          ),
        );
        _shown = wanted;
      } on Exception catch (error) {
        debugPrint('Google-kaart volgen mislukt: $error');
        return;
      } finally {
        _moving = false;
      }
    }
  }

  /// De kaart is klaar genoeg om de eerste markers te tekenen: één keer, via
  /// `onCameraIdle` of het vangnet. Zet de hertekenpogingen terug op nul, want
  /// bij een trage start (debug) kunnen ze opgebruikt zijn vóór de kaart klaar
  /// was; dan verschenen de personen nooit en zonder foutmelding.
  void _completeMapReady() {
    if (_mapReady.isCompleted) return;
    _mapReady.complete();
    _mapReadyFallback?.cancel();
    _mapReadyFallback = null;
    _redrawTries = 0;
    _onMarkers();
    if (_memberMarkers.isNotEmpty) _scheduleRedraw();
  }

  /// De Flutter-kaart blijft bestaan wanneer alleen de native Google-kaart
  /// wordt vernieuwd. Neem daarom haar actuele camera over; de widgetdefaults
  /// zijn alleen juist bij de eerste appstart en zouden een hervatte kaart
  /// terugzetten naar de standaardzoom.
  void _followCurrentOverlayCamera() {
    final camera = widget.controller.camera;
    _zoom = camera.zoom;
    _wanted = (
      latitude: camera.center.latitude,
      longitude: camera.center.longitude,
      zoom: camera.zoom,
      bearing: (-camera.rotation + 360) % 360,
    );
  }

  /// Google (de nieuwe tekenmotor in een textuur) zet nieuwe markers pas op
  /// het scherm na een camerabeweging. Bij het opstarten staat de camera stil
  /// (de kaart opent op de bewaarde plek), dus bleven de personen weg tot je
  /// scrolde. Een onzichtbaar kleine zoomstap, even laten staan zodat Google
  /// een beeld tekent, en dan terug naar de stand van de kaart erboven.
  void _scheduleRedraw() {
    _redrawTimer?.cancel();
    _redrawTimer = Timer(_redrawDelay, () => unawaited(_redraw()));
  }

  Future<void> _redraw() async {
    final google = _google;
    final wanted = _wanted;
    if (!mounted) return;
    if (google == null || wanted == null || _moving || !_mapReady.isCompleted) {
      // Wacht tot de kaart haar eerste beeld heeft en de markers er zijn:
      // straks opnieuw proberen.
      if (_redrawTries++ < _redrawTriesMax) {
        _scheduleRedraw();
      } else {
        debugPrint(
          'Kaart: eerste markers niet hertekend (kaart bleef te lang bezet)',
        );
      }
      return;
    }
    final target = googleCameraTarget(
      latitude: wanted.latitude,
      longitude: wanted.longitude,
      zoom: wanted.zoom,
      bottomPadding: widget.bottomPadding,
      bearing: wanted.bearing,
    );
    try {
      await google.moveCamera(
        gm.CameraUpdate.newCameraPosition(
          gm.CameraPosition(
            target: gm.LatLng(target.latitude, target.longitude),
            zoom: wanted.zoom + _redrawZoomStep,
            bearing: wanted.bearing,
          ),
        ),
      );
      // Eerst een beeld laten tekenen: twee bewegingen binnen dezelfde frame
      // heffen elkaar op en dan blijft de kaart onveranderd.
      await Future<void>.delayed(_redrawDelay);
    } on Exception catch (error) {
      debugPrint('Google-kaart hertekenen mislukt: $error');
    }
    if (!mounted) return;
    _shown = null; // terug naar exact de stand van de kaart erboven
    // De eerste keer dat Google zijn eigen beeld met de personen tekent.
    unawaited(_sync());
  }

  @override
  Widget build(BuildContext context) {
    final target = googleCameraTarget(
      latitude: widget.initialCenter.latitude,
      longitude: widget.initialCenter.longitude,
      zoom: widget.initialZoom,
      bottomPadding: widget.bottomPadding,
    );
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: gm.LatLng(target.latitude, target.longitude),
        zoom: widget.initialZoom,
      ),
      mapType: showsSatellite(choice: widget.satellite, zoom: _zoom)
          ? gm.MapType.hybrid
          : gm.MapType.normal,
      // De straal pas ver ingezoomd; uitgezoomd enkel het icoon.
      circles: showsPlaceRadius(_zoom)
          ? placeCircles(
              widget.places,
              color: AppColors.primary,
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
            )
          : const {},
      markers: {...placeMarkers(widget.places, _icons), ..._memberMarkers},
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      // Alle bediening zit in de kaart erboven.
      zoomGesturesEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      indoorViewEnabled: false,
      onMapCreated: (controller) {
        _google = controller;
        _followCurrentOverlayCamera();
        _mapReadyFallback = Timer(_mapReadyFallbackDelay, () {
          if (!_mapReady.isCompleted) {
            debugPrint('Kaart: geen camerastilte gemeld, markers toch tekenen');
          }
          _completeMapReady();
        });
        unawaited(_sync());
      },
      onCameraIdle: () {
        // Een aangemaakte controller betekent nog geen afgewerkte kaart.
        // Teken de eerste ballonnen pas na de eerste camerabeweging, ook
        // wanneer de gebruiker de kaart nog niet heeft aangeraakt.
        _completeMapReady();
      },
    );
  }
}
