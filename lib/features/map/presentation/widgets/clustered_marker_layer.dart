import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/geo.dart';

import '../../../places/domain/place_status.dart';
import '../../../location/domain/trip_status.dart';
import '../../../parked_car/domain/parked_car.dart';
import '../../domain/bubble_layout.dart';
import '../../domain/bubble_side.dart';
import '../../domain/colocated_anchor.dart';
import '../../domain/marker_cluster.dart';
import '../../domain/marker_motion.dart';
import '../../domain/marker_trajectory.dart';
import '../../domain/road_matching.dart';
import '../../domain/marker_spread.dart';
import '../../domain/marker_clearance.dart';
import '../../domain/member_on_map.dart';
import 'group_pin.dart';
import 'map_marker_spec.dart';
import 'offscreen_members_layer.dart' show ShownPin;
import 'member_marker.dart';
import 'member_history_bubble.dart';
import 'parked_car_specs.dart';
import 'walker_marker_spec.dart';
import 'walking_gif_frames.dart';
import '../../../places/presentation/place_images.dart';
import '../../../../l10n/l10n.dart';

typedef _Coord = ({double lat, double lng});

/// Marker-laag die bij elke zoom/verschuiving herberekent welke leden samen
/// vallen (op schermafstand) en ze als losse marker of groepspin toont.
///
/// Markers schuiven vloeiend van het vorige naar het nieuwste ontvangen punt;
/// er wordt nooit vooruit gerekend of geëxtrapoleerd.
class ClusteredMarkerLayer extends StatefulWidget {
  const ClusteredMarkerLayer({
    super.key,
    required this.members,
    required this.now,
    required this.onMemberTap,
    required this.onGroupTap,
    this.placeByUser = const {},
    this.stationarySinceByUser = const {},
    this.selectedUserId,
    this.myUserId,
    this.onHistory,
    this.reservedPlaces = const [],
    this.parkedCars = const [],
    this.onParkedCarTap,
    this.memberNames = const {},
    this.onNativeMarkers,
    this.overlay,
  });

  final List<MemberOnMap> members;
  final DateTime now;
  final ValueChanged<MemberOnMap> onMemberTap;
  final ValueChanged<LatLng> onGroupTap;
  final Map<String, PlaceStatus> placeByUser;
  final Map<String, DateTime> stationarySinceByUser;
  final String? selectedUserId;
  final String? myUserId;
  final ValueChanged<MemberOnMap>? onHistory;
  final List<LatLng> reservedPlaces;
  final List<ParkedCar> parkedCars;
  final ValueChanged<ParkedCar>? onParkedCarTap;
  final Map<String, String> memberNames;

  /// Met Google Maps: de markers gaan als afbeelding naar Google (die ze vast
  /// aan de kaart tekent); deze laag toont dan enkel onzichtbare tikvlakken.
  final ValueChanged<List<MapMarkerSpec>>? onNativeMarkers;

  /// Laag bovenop de markers die precies weet waar elke pin nu getekend
  /// wordt (bv. de randblokjes voor wie buiten beeld is).
  final Widget Function(List<ShownPin> pins)? overlay;

  @override
  State<ClusteredMarkerLayer> createState() => _ClusteredMarkerLayerState();
}

class _ClusteredMarkerLayerState extends State<ClusteredMarkerLayer>
    with SingleTickerProviderStateMixin {
  /// Binnen deze echte afstand van het huis telt iemand als "bij huis".
  static const _nearPlaceMeters = 200.0;

  final _clock = ValueNotifier<Duration>(Duration.zero);
  final _motions = <String, MarkerTrajectory>{};
  final Map<String, DateTime> _lastAt = {};
  final _roadPaths = <String, List<RoadPoint>?>{};
  Duration _tickerOffset = Duration.zero;
  late final Ticker _ticker = createTicker((elapsed) {
    _clock.value = _tickerOffset + elapsed;
    if (!_motions.values.any((motion) => motion.active(_clock.value))) {
      _ticker.stop();
    }
  });

  /// Vorige uitkomst van groeperen en ballonplaatsing: de volgende berekening
  /// houdt die vast tot het echt anders moet (zie de `previous`-parameters),
  /// zodat er bij zoomen en bewegen niets heen en weer springt.
  List<List<String>> _lastGroups = const [];
  Map<String, BubbleSide> _lastSides = const {};
  Map<String, BubblePlacement> _lastPlacements = const {};
  bool _homeSplit = false;

  /// Beelden van de wandelanimatie, enkel geladen als Google de markers tekent
  /// en iemand wandelt (het eerste is het stilstaande beeld in de ballon).
  List<WalkingGifFrame>? _walkerFrames;
  bool _loadingWalker = false;

  void _loadWalkerFrames() {
    if (_loadingWalker || _walkerFrames != null) return;
    _loadingWalker = true;
    unawaited(
      walkingGifFrames().then((frames) {
        _loadingWalker = false;
        if (mounted && frames.isNotEmpty) {
          setState(() => _walkerFrames = frames);
        }
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncTargets();
  }

  @override
  void didUpdateWidget(covariant ClusteredMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTargets();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// Neemt nieuwe doelen over. Beweegt alleen als er echt een nieuw punt
  /// ontvangen is; de duur volgt het tijdsgat tussen de twee punten.
  void _syncTargets() {
    final seen = <String>{};

    for (final member in widget.members) {
      final location = member.location;
      if (location == null) continue;
      final id = member.member.userId;
      seen.add(id);

      final target = (lat: location.latitude, lng: location.longitude);
      final current = _motions[id];
      if (current == null) {
        _motions[id] = MarkerTrajectory([target], _clock.value, Duration.zero);
      } else if (current.target != target ||
          (member.roadPath != null &&
              !identical(member.roadPath, _roadPaths[id]))) {
        final previousAt = _lastAt[id];
        final driving = TripStatus.at(location, widget.now).driving;
        if (previousAt != null && location.updatedAt.isBefore(previousAt)) {
          continue;
        }
        final gap =
            previousAt == location.updatedAt && current.active(_clock.value)
            ? current.duration - (_clock.value - current.started)
            : previousAt == null
            ? (driving ? markerDrivingMotionMax : markerMotionMax)
            : markerMotionDuration(
                previousAt,
                location.updatedAt,
                driving: driving,
              );
        _motions[id] = MarkerTrajectory.retarget(
          previous: current,
          target: target,
          at: _clock.value,
          duration: gap,
          roadPath: member.roadPath,
        );
      }
      _lastAt[id] = location.updatedAt;
      _roadPaths[id] = member.roadPath;
    }

    _motions.removeWhere((id, _) => !seen.contains(id));
    _lastAt.removeWhere((id, _) => !seen.contains(id));
    _roadPaths.removeWhere((id, _) => !seen.contains(id));
    if (!_ticker.isActive &&
        _motions.values.any((motion) => motion.active(_clock.value))) {
      _tickerOffset = _clock.value;
      _ticker.start();
    }
  }

  /// Huidige, mogelijk nog bewegende, positie van een lid.
  _Coord _displayed(String id) {
    return _motions[id]?.point(_clock.value) ?? (lat: 0, lng: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) => _buildLayer(context),
    );
  }

  Widget _buildLayer(BuildContext context) {
    final camera = MapCamera.of(context);

    // Leden met locatie; "ik" eerst zodat ik in een groep altijd zichtbaar ben.
    final located =
        [
          for (final m in widget.members)
            if (m.location != null) m,
        ]..sort((a, b) {
          if (a.member.userId == widget.myUserId) return -1;
          if (b.member.userId == widget.myUserId) return 1;
          return 0;
        });

    final byId = {for (final m in located) m.member.userId: m};
    final coords = {
      for (final m in located) m.member.userId: _displayed(m.member.userId),
    };
    // Enkel wie op dezelfde plek staat én op het scherm overlapt, komt samen
    // in één groepspin: thuis uitgezoomd één groep, ingezoomd elk apart.
    final groups = clusterByMetersAndScreen([
      for (final m in located)
        GeoScreenClusterPoint(
          m.member.userId,
          coords[m.member.userId]!.lat,
          coords[m.member.userId]!.lng,
          camera.latLngToScreenOffset(
            LatLng(coords[m.member.userId]!.lat, coords[m.member.userId]!.lng),
          ),
        ),
    ], previous: _lastGroups);
    _lastGroups = [
      for (final group in groups) [...group],
    ];
    // Op huisniveau scheiden alleen de avatars. Hun geografische ankers
    // blijven gelijk; bij uitzoomen berekenen we opnieuw de groepspinnen.
    // Met marge: pas onder 17,7 opnieuw samen, anders wipt het rond 18.
    _homeSplit = camera.zoom >= 18 || (_homeSplit && camera.zoom >= 17.7);
    if (_homeSplit) {
      final separate = [
        for (final group in groups)
          for (final id in group) [id],
      ];
      groups
        ..clear()
        ..addAll(separate);
    }
    // Rijdende auto's houden ieder hun eigen exacte wegpositie.
    for (final member in located) {
      if (!TripStatus.at(member.location, widget.now).driving) {
        continue;
      }
      final id = member.member.userId;
      for (final group in groups) {
        group.remove(id);
      }
      groups.removeWhere((group) => group.isEmpty);
      groups.add([id]);
    }
    // Een geselecteerde persoon blijft afzonderlijk herkenbaar, ook thuis
    // tussen andere gezinsleden op dezelfde locatie.
    final selectedId = widget.selectedUserId;
    if (selectedId != null && byId.containsKey(selectedId)) {
      for (final group in groups) {
        group.remove(selectedId);
      }
      groups.removeWhere((group) => group.isEmpty);
      groups.add([selectedId]);
    }
    // Samen thuis maar ingezoomd (geen groepspin meer): één gezamenlijk punt,
    // zodat ze hieronder vlak naast elkaar boven het huis komen te staan.
    final together = colocatedAnchors([
      for (final group in groups)
        if (group.length == 1 &&
            !TripStatus.at(byId[group.single]!.location, widget.now).driving)
          GeoClusterPoint(
            group.single,
            coords[group.single]!.lat,
            coords[group.single]!.lng,
          ),
    ]);
    coords.addAll(together);
    // Groep met de selectie als laatste tekenen (bovenop).
    groups.sort((a, b) {
      final aSel =
          widget.selectedUserId != null && a.contains(widget.selectedUserId);
      final bSel =
          widget.selectedUserId != null && b.contains(widget.selectedUserId);
      return (aSel ? 1 : 0) - (bSel ? 1 : 0);
    });

    final markers = <MapMarkerSpec>[];
    // Sneakers boven de Google-kaart: gaan niet naar Google (zie walkerOverlaySpec).
    final walkerOverlays = <MapMarkerSpec>[];
    final placePoints = [
      for (final place in widget.reservedPlaces)
        camera.latLngToScreenOffset(place),
    ];
    bool isDriving(List<String> group) =>
        group.length == 1 &&
        TripStatus.at(byId[group.single]!.location, widget.now).driving;
    Offset screenOf(String id) =>
        camera.latLngToScreenOffset(LatLng(coords[id]!.lat, coords[id]!.lng));

    // Vrijhouden van het huis-icoon: voor wie echt bij huis is (op echte
    // afstand, zodat het ook bij inzoomen blijft gelden). Wie verder weg is,
    // mag niet over het huis heen naar boven geduwd worden.
    final clearance = <String, Offset>{};
    for (final group in groups) {
      if (isDriving(group)) {
        clearance[group.first] = Offset.zero;
        continue;
      }
      final single = group.length == 1;
      // Een los rondje wijst met zijn puntje naar de stip op de plek; dat moet
      // op het huis staan, dus niet wegduwen. Enkel de groepspin houdt het
      // huis-icoon vrij.
      if (single) {
        clearance[group.first] = Offset.zero;
        continue;
      }
      final screenPoint = screenOf(group.first);
      final width = single ? MemberMarker.width : GroupPin.width;
      final height = single
          ? MemberMarker.height
          : GroupPin.heightFor(group.length);
      clearance[group.first] = markerClearance(
        Rect.fromLTWH(
          screenPoint.dx - width / 2,
          // Ook de groepspin staat bóven zijn punt: het puntje onderaan wijst
          // naar de plek (voorheen hing hij eronder, ±140 px te zuidelijk).
          screenPoint.dy - height,
          width,
          height,
        ),
        [
          for (final (index, place) in widget.reservedPlaces.indexed)
            if (distanceMeters(
                  coords[group.first]!.lat,
                  coords[group.first]!.lng,
                  place.latitude,
                  place.longitude,
                ) <=
                _nearPlaceMeters)
              placePoints[index],
        ],
      );
    }

    // Losse markers op aparte locaties die op het scherm over elkaar zouden
    // vallen, schuiven naast elkaar (auto's blijven op hun exacte positie).
    final spread = spreadHorizontally([
      for (final group in groups)
        if (!isDriving(group))
          SpreadItem(
            group.first,
            screenOf(group.first) + Offset(0, clearance[group.first]!.dy),
            group.length == 1
                ? MemberMarker.avatarSize / 2
                : GroupPin.clusterWidth(group.length) / 2,
          ),
    ]);
    final offsets = <String, Offset>{};
    final pins = <ShownPin>[];
    for (final group in groups) {
      final groupMembers = [for (final id in group) byId[id]!];
      final anchor = coords[groupMembers.first.member.userId]!;
      final point = LatLng(anchor.lat, anchor.lng);
      final single = groupMembers.length == 1;
      final driving = isDriving(group);
      final width = single ? MemberMarker.width : GroupPin.width;
      final height = single
          ? MemberMarker.height
          : GroupPin.heightFor(group.length);
      final offset = clearance[group.first]!;
      final shiftX = spread[group.first] ?? 0;
      for (final member in groupMembers) {
        offsets[member.member.userId] = Offset(shiftX, offset.dy);
      }
      final screen = screenOf(group.first);
      final shift = Offset(shiftX, offset.dy);
      pins.add((
        members: groupMembers,
        circles: single
            ? MemberMarker.circleAt(
                screen,
                shift: shift,
                selected: group.first == widget.selectedUserId,
                driving: driving,
              )
            : GroupPin.circlesAt(screen, groupMembers.length, shift: shift),
      ));

      if (groupMembers.length == 1) {
        final member = groupMembers.single;
        final selected = member.member.userId == widget.selectedUserId;
        Widget memberMarker() => MemberMarker(
          entry: member,
          now: widget.now,
          placeStatus: widget.placeByUser[member.member.userId],
          selected: selected,
        );
        markers.add(
          MapMarkerSpec(
            id: 'member_${member.member.userId}',
            point: point,
            width: MemberMarker.width,
            height: MemberMarker.height,
            alignment: driving
                ? Alignment.center
                : Alignment(2 * shiftX / width, -1 + 2 * offset.dy / height),
            onTap: () => widget.onMemberTap(member),
            child: GestureDetector(
              onTap: () => widget.onMemberTap(member),
              child: memberMarker(),
            ),
            imageKey: (
              Theme.of(context),
              MediaQuery.textScalerOf(context),
              member.member.initial,
              member.member.colorIndex,
              selected,
              driving,
            ),
          ),
        );
      } else {
        final pin = GroupPin(
          members: groupMembers,
          now: widget.now,
          placeByUser: widget.placeByUser,
          myUserId: widget.myUserId,
          selectedUserId: widget.selectedUserId,
          onMemberTap: widget.onMemberTap,
        );
        markers.add(
          MapMarkerSpec(
            id: 'group_${groupMembers.first.member.userId}',
            imageKey: (
              Theme.of(context),
              MediaQuery.textScalerOf(context),
              pin.imageKey(context.l10n),
            ),
            point: point,
            width: GroupPin.width,
            height: height,
            alignment: Alignment(
              2 * shiftX / width,
              -1 + 2 * offset.dy / height,
            ),
            onTap: () => widget.onGroupTap(point),
            child: GestureDetector(
              onTap: () => widget.onGroupTap(point),
              child: Align(alignment: Alignment.bottomCenter, child: pin),
            ),
          ),
        );
      }
    }

    // Auto's onderaan tekenen, maar vrij van huis en (stilstaande) leden.
    // Rijdende leden tellen niet mee, anders springt de auto mee als iemand
    // voorbijrijdt.
    markers.insertAll(
      0,
      parkedCarSpecs(
        context,
        camera: camera,
        cars: widget.parkedCars,
        names: widget.memberNames,
        onTap: widget.onParkedCarTap,
        obstacles: [
          for (final place in placePoints)
            Rect.fromCenter(
              center: place,
              width: kPlaceMapImageWidth,
              height: kPlaceMapImageWidth,
            ),
          for (final group in groups)
            if (!isDriving(group))
              _pinRect(
                screenOf(group.first) + offsets[group.first]!,
                group.length == 1
                    ? MemberMarker.avatarSize
                    : GroupPin.clusterWidth(group.length),
              ),
        ],
      ),
    );

    // Ook zonder selectie blijven losse leden hun infolabel behouden.
    // Groepen hebben hun eigen statusballon; bij selectie komt de persoonlijke
    // ballon bovenop, ongeacht snelheid of beschikbaarheid van geschiedenis.
    final bubbleMembers = selectedId != null && byId.containsKey(selectedId)
        ? [byId[selectedId]!]
        : [
            for (final group in groups)
              if (group.length == 1) byId[group.single]!,
          ];
    final screenById = {
      for (final m in located)
        m.member.userId:
            camera.latLngToScreenOffset(
              LatLng(
                coords[m.member.userId]!.lat,
                coords[m.member.userId]!.lng,
              ),
            ) +
            Offset(offsets[m.member.userId]?.dx ?? 0, 0),
    };
    double baseDyOf(MemberOnMap member) =>
        TripStatus.at(member.location, widget.now).driving ? -18 : -78;
    // Alle ballonnen samen plaatsen, zodat ze nooit over elkaar vallen; per lid
    // eerst de kant die vrij is van andere leden.
    final sides = {
      for (final member in bubbleMembers)
        if (screenById[member.member.userId] case final self?)
          member.member.userId: chooseBubbleSide(self, [
            for (final entry in screenById.entries)
              if (entry.key != member.member.userId) entry.value,
          ], previous: _lastSides[member.member.userId]),
    };
    _lastSides = sides;
    final placements = layoutBubbles(
      [
        for (final member in bubbleMembers)
          if (screenById[member.member.userId] case final self?)
            (
              id: member.member.userId,
              anchor: self + Offset(0, offsets[member.member.userId]?.dy ?? 0),
              preferred: sides[member.member.userId]!,
              baseDy: baseDyOf(member),
            ),
      ],
      previous: _lastPlacements,
      avatars: {
        // Het gezicht van elk los lid, in dezelfde coördinaten als de ballon
        // (die hangt een ballonhoogte hoger dan zijn ankerpunt).
        // Een rijdend lid staat gecentreerd op zijn punt, een stilstaand lid
        // als pin erboven.
        for (final entry in screenById.entries)
          entry.key: Rect.fromCenter(
            center:
                entry.value +
                Offset(
                  0,
                  (offsets[entry.key]?.dy ?? 0) +
                      (isDriving([entry.key])
                          ? 0
                          : MemberMarker.avatarSize / 2 - MemberMarker.height) +
                      kBubbleHeight,
                ),
            width: MemberMarker.avatarSize,
            height: MemberMarker.avatarSize,
          ),
      },
    );
    _lastPlacements = placements;
    final native = widget.onNativeMarkers;
    for (final selected in bubbleMembers) {
      final id = selected.member.userId;
      final coordinate = coords[id]!;
      final point = LatLng(coordinate.lat, coordinate.lng);
      final placement = placements[id];
      final onRight = placement == null || placement.side == BubbleSide.right;
      final status = TripStatus.at(selected.location, widget.now);
      final place = widget.placeByUser[id];
      final atPlace =
          place?.since != null &&
          !place!.since!.isAfter(widget.now) &&
          status.state != TripState.stale &&
          status.state != TripState.moving;
      final stopped =
          (status.state == TripState.stationary ||
              status.state == TripState.unknown) &&
          widget.stationarySinceByUser[id] != null &&
          !widget.stationarySinceByUser[id]!.isAfter(widget.now);
      final since = atPlace
          ? place.since
          : stopped
          ? widget.stationarySinceByUser[id]
          : null;
      final age = widget.now
          .difference(selected.location?.updatedAt ?? widget.now)
          .inSeconds
          .clamp(0, 99999999);
      final timeKey = status.state == TripState.moving
          ? 0
          : since != null && !since.isAfter(widget.now)
          ? widget.now.difference(since).inMinutes
          : age < 60
          ? age
          : age ~/ 60;
      void onBubbleTap() => (widget.onHistory ?? widget.onMemberTap)(selected);
      final alignment = Alignment(
        (onRight ? 1 : -1) + 2 * (offsets[id]?.dx ?? 0) / 142,
        -1 + 2 * (offsets[id]?.dy ?? 0) / 48,
      );
      // Zoals de referentie: hoger en verder over de bovenhoek.
      final offset = Offset(
        onRight ? kBubbleInset : -kBubbleInset,
        baseDyOf(selected) + (placement?.shiftY ?? 0),
      );
      // Google tekent een ballon als vaste afbeelding, met een stilstaand
      // beeld van de sneakers. De animatie speelt erboven als Flutter-widget:
      // een nieuw Google-markerbeeld per animatiebeeld liet de kaart knipperen.
      final animate =
          native != null && MemberHistoryBubble.isWalking(selected, widget.now);
      if (animate) _loadWalkerFrames();
      final walkerStill = animate ? _walkerFrames?.first.image : null;
      markers.add(
        MapMarkerSpec(
          id: 'bubble_$id',
          point: point,
          width: kBubbleWidth,
          height: kBubbleHeight,
          alignment: alignment,
          offset: offset,
          onTap: onBubbleTap,
          child: MemberHistoryBubble(
            entry: selected,
            now: widget.now,
            placeStatus: widget.placeByUser[id],
            stationarySince: widget.stationarySinceByUser[id],
            tailLeft: onRight,
            onTap: onBubbleTap,
            walker: animate ? WalkerDisplay.slot : WalkerDisplay.gif,
            walkerStill: walkerStill,
          ),
          imageKey: (
            Theme.of(context),
            MediaQuery.textScalerOf(context),
            // Andere taal → ballon opnieuw tekenen.
            Localizations.maybeLocaleOf(context),
            status.state,
            status.mode,
            status.speedKmh,
            atPlace ? place.name : null,
            atPlace ? place.icon : null,
            stopped,
            timeKey,
            onRight,
            walkerStill != null,
          ),
        ),
      );
      if (animate && walkerStill != null) {
        walkerOverlays.add(
          walkerOverlaySpec(
            id: 'walker_$id',
            point: point,
            alignment: alignment,
            offset: offset,
            slot: MemberHistoryBubble.walkerSlotFor(
              context,
              selected,
              widget.now,
              tailLeft: onRight,
            ),
          ),
        );
      }
    }

    final overlay = widget.overlay;
    Widget withOverlay(Widget layer) => overlay == null
        ? layer
        : Stack(fit: StackFit.expand, children: [layer, overlay(pins)]);
    if (native == null) {
      return withOverlay(
        MarkerLayer(markers: [for (final spec in markers) spec.toMarker()]),
      );
    }
    // Google tekent de markers; na deze frame doorgeven (niet tijdens build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) native(markers);
    });
    return withOverlay(
      MarkerLayer(
        markers: [
          for (final spec in markers)
            if (spec.onTap case final onTap?)
              spec.toMarker(
                replaceChild: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  // De groepsafbeelding heeft individuele avatars: behoud hun
                  // tikvlakken ook als Google het zichtbare beeld tekent.
                  child: spec.id.startsWith('group_')
                      ? Opacity(opacity: 0, child: spec.child)
                      : const SizedBox.expand(),
                ),
              ),
          // Laatst, dus bovenop; tikken gaat erdoor naar de ballon.
          for (final spec in walkerOverlays) spec.toMarker(),
        ],
      ),
    );
  }
}

/// Zichtbaar deel van een stilstaande pin: rondjes van [width] breed die met
/// hun puntje op [point] staan.
Rect _pinRect(Offset point, double width) => Rect.fromLTWH(
  point.dx - width / 2,
  point.dy - MemberMarker.height,
  width,
  MemberMarker.height,
);
