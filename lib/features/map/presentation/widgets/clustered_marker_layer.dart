import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../places/domain/place_status.dart';
import '../../../location/domain/trip_status.dart';
import '../../domain/bubble_side.dart';
import '../../domain/marker_cluster.dart';
import '../../domain/marker_motion.dart';
import '../../domain/marker_spread.dart';
import '../../domain/marker_clearance.dart';
import '../../domain/member_on_map.dart';
import 'group_pin.dart';
import 'member_marker.dart';
import 'member_history_bubble.dart';

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

  @override
  State<ClusteredMarkerLayer> createState() => _ClusteredMarkerLayerState();
}

class _ClusteredMarkerLayerState extends State<ClusteredMarkerLayer>
    with SingleTickerProviderStateMixin {
  /// Binnen deze schermafstand van het huis-icoon telt iemand als "bij huis".
  static const _nearPlacePx = 48.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: markerMotionMin,
  );
  final Map<String, _Coord> _from = {};
  final Map<String, _Coord> _to = {};
  final Map<String, DateTime> _lastAt = {};

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
    _controller.dispose();
    super.dispose();
  }

  /// Neemt nieuwe doelen over. Beweegt alleen als er echt een nieuw punt
  /// ontvangen is; de duur volgt het tijdsgat tussen de twee punten.
  void _syncTargets() {
    final seen = <String>{};
    Duration? duration;
    var changed = false;

    for (final member in widget.members) {
      final location = member.location;
      if (location == null) continue;
      final id = member.member.userId;
      seen.add(id);

      final target = (lat: location.latitude, lng: location.longitude);
      final current = _to[id];
      if (current == null) {
        _from[id] = target;
        _to[id] = target;
      } else if (current.lat != target.lat || current.lng != target.lng) {
        // Een rechte animatie tussen twee wegpunten kan dwars door een bocht
        // snijden. Auto's staan op de ontvangen (eventueel gematchte) positie.
        _from[id] =
            TripStatus.at(location, widget.now).state == TripState.moving
            ? target
            : _displayed(id);
        _to[id] = target;
        final previousAt = _lastAt[id];
        final gap = previousAt == null
            ? markerMotionMax
            : markerMotionDuration(previousAt, location.updatedAt);
        if (duration == null || gap > duration) duration = gap;
        changed = true;
      }
      _lastAt[id] = location.updatedAt;
    }

    _from.removeWhere((id, _) => !seen.contains(id));
    _to.removeWhere((id, _) => !seen.contains(id));
    _lastAt.removeWhere((id, _) => !seen.contains(id));

    if (!changed) return;
    if (duration != null) _controller.duration = duration;
    _controller.forward(from: 0);
  }

  /// Huidige, mogelijk nog bewegende, positie van een lid.
  _Coord _displayed(String id) {
    final from = _from[id];
    final to = _to[id];
    if (from == null) return to ?? (lat: 0, lng: 0);
    if (to == null) return from;
    final t = Curves.easeOut.transform(_controller.value);
    return lerpCoordinate(from, to, t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
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
    // Groeperen op echte afstand: enkel wie op dezelfde plek staat, komt
    // samen in één groepspin, ongeacht de zoom.
    final groups = clusterByMeters([
      for (final m in located)
        GeoClusterPoint(
          m.member.userId,
          coords[m.member.userId]!.lat,
          coords[m.member.userId]!.lng,
        ),
    ]);
    // Rijdende auto's houden ieder hun eigen exacte wegpositie.
    for (final member in located) {
      if (TripStatus.at(member.location, widget.now).state !=
          TripState.moving) {
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
    // Groep met de selectie als laatste tekenen (bovenop).
    groups.sort((a, b) {
      final aSel =
          widget.selectedUserId != null && a.contains(widget.selectedUserId);
      final bSel =
          widget.selectedUserId != null && b.contains(widget.selectedUserId);
      return (aSel ? 1 : 0) - (bSel ? 1 : 0);
    });

    final markers = <Marker>[];
    final placePoints = [
      for (final place in widget.reservedPlaces)
        camera.latLngToScreenOffset(place),
    ];
    bool isDriving(List<String> group) =>
        group.length == 1 &&
        TripStatus.at(byId[group.single]!.location, widget.now).state ==
            TripState.moving;
    Offset screenOf(String id) =>
        camera.latLngToScreenOffset(LatLng(coords[id]!.lat, coords[id]!.lng));

    // Vrijhouden van het huis-icoon: enkel voor wie echt bij dat icoon staat.
    // Wie verder weg is, mag niet over het huis heen naar boven geduwd worden
    // (anders komen mensen op aparte locaties toch op één hoop).
    final clearance = <String, Offset>{};
    for (final group in groups) {
      if (isDriving(group)) {
        clearance[group.first] = Offset.zero;
        continue;
      }
      final single = group.length == 1;
      final screenPoint = screenOf(group.first);
      final width = single ? MemberMarker.width : GroupPin.width;
      final height = single ? MemberMarker.height : GroupPin.height;
      clearance[group.first] = markerClearance(
        Rect.fromLTWH(
          screenPoint.dx - width / 2,
          single ? screenPoint.dy - height : screenPoint.dy,
          width,
          height,
        ),
        [
          for (final place in placePoints)
            if ((place - screenPoint).distance <= _nearPlacePx) place,
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
    for (final group in groups) {
      final groupMembers = [for (final id in group) byId[id]!];
      final anchor = coords[groupMembers.first.member.userId]!;
      final point = LatLng(anchor.lat, anchor.lng);
      final single = groupMembers.length == 1;
      final driving = isDriving(group);
      final width = single ? MemberMarker.width : GroupPin.width;
      final height = single ? MemberMarker.height : GroupPin.height;
      final offset = clearance[group.first]!;
      final shiftX = spread[group.first] ?? 0;
      for (final member in groupMembers) {
        offsets[member.member.userId] = Offset(shiftX, offset.dy);
      }

      if (groupMembers.length == 1) {
        final member = groupMembers.single;
        markers.add(
          Marker(
            point: point,
            width: MemberMarker.width,
            height: MemberMarker.height,
            alignment: driving
                ? Alignment.center
                : Alignment(2 * shiftX / width, -1 + 2 * offset.dy / height),
            child: GestureDetector(
              onTap: () => widget.onMemberTap(member),
              child: MemberMarker(
                entry: member,
                now: widget.now,
                placeStatus: widget.placeByUser[member.member.userId],
                selected: member.member.userId == widget.selectedUserId,
              ),
            ),
          ),
        );
      } else {
        markers.add(
          Marker(
            point: point,
            width: GroupPin.width,
            height: GroupPin.height,
            alignment: Alignment(2 * shiftX / width, 1 + 2 * offset.dy / height),
            child: GestureDetector(
              onTap: () => widget.onGroupTap(point),
              child: GroupPin(
                members: groupMembers,
                now: widget.now,
                placeByUser: widget.placeByUser,
                myUserId: widget.myUserId,
                selectedUserId: widget.selectedUserId,
                onMemberTap: widget.onMemberTap,
              ),
            ),
          ),
        );
      }
    }

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
              LatLng(coords[m.member.userId]!.lat, coords[m.member.userId]!.lng),
            ) +
            Offset(offsets[m.member.userId]?.dx ?? 0, 0),
    };
    for (final selected in bubbleMembers) {
      final id = selected.member.userId;
      final coordinate = coords[id]!;
      final point = LatLng(coordinate.lat, coordinate.lng);
      // Kies de vrije kant zodat de ballon nooit over een ander lid valt; dit
      // wordt bij elke zoom opnieuw bepaald (schermpixels).
      final self = screenById[id];
      final onRight =
          self == null ||
          chooseBubbleSide(self, [
                for (final entry in screenById.entries)
                  if (entry.key != id) entry.value,
              ]) ==
              BubbleSide.right;
      markers.add(
        Marker(
          point: point,
          width: 142,
          height: 48,
          alignment: Alignment(
            (onRight ? 1 : -1) + 2 * (offsets[id]?.dx ?? 0) / 142,
            -1 + 2 * (offsets[id]?.dy ?? 0) / 48,
          ),
          child: Transform.translate(
            // Zoals de referentie: hoger en verder over de bovenhoek.
            offset: Offset(onRight ? 20 : -20, -78),
            child: MemberHistoryBubble(
              entry: selected,
              now: widget.now,
              placeStatus: widget.placeByUser[id],
              stationarySince: widget.stationarySinceByUser[id],
              tailLeft: onRight,
              onTap: () => (widget.onHistory ?? widget.onMemberTap)(selected),
            ),
          ),
        ),
      );
    }
    return MarkerLayer(markers: markers);
  }
}
