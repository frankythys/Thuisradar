import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/place_icons.dart';
import '../../domain/edge_indicator.dart';
import '../../domain/marker_cluster.dart';
import '../../domain/member_on_map.dart';
import 'member_marker.dart';

/// Wat de kaart onderaan bedekt, gemeten vanaf de onderkant van de kaart: het
/// paneel ([sheet] hoog) en rechts erboven de knoppenkolom ([buttonsWidth]
/// breed inclusief marge, van [buttonsBottom] tot [buttonsTop] hoog).
typedef MapCover = ({double sheet, double buttonsWidth, double buttonsBottom, double buttonsTop});

/// Leden buiten beeld (bv. wie wegrijdt terwijl de kaart stilstaat): aan de
/// rand van de kaart een wit blokje met hun gezichtjes en een puntje naar waar
/// ze zijn. Wie samen staat, zit samen in één blokje: langs een zijrand onder
/// elkaar, langs boven- of onderrand naast elkaar, met bovenaan het icoon van
/// de plaats als ze daar allemaal zijn. Tik op een gezichtje om naar die
/// persoon te gaan.
class OffscreenMembersLayer extends StatefulWidget {
  const OffscreenMembersLayer({
    super.key,
    required this.members,
    required this.onTap,
    required this.cover,
    this.placeByUser = const {},
    this.coverChanges,
  });

  /// Eén gezichtje (of plaats-icoon) in het blokje.
  static const face = 28.0;
  static const _padding = 4.0;
  static const _thickness = face + 2 * _padding;

  /// Zo ver steekt het puntje buiten het blokje.
  static const tip = 8.0;

  /// Meer leden: de laatsten worden "+N".
  static const _maxFaces = 4;

  /// Afstand tot de rand van de kaart, het paneel en de knoppen.
  static const _margin = 8.0;

  /// Wie een pijl heeft, houdt die tot zijn gezichtje zo ver in beeld is.
  static const _hysteresis = 24.0;

  /// Het gezichtje van een marker staat boven zijn punt; dat telt.
  static const _avatarLift = MemberMarker.avatarSize * 0.75;

  /// Wie op het scherm dichter bij elkaar staat, zit in hetzelfde blokje.
  static const _together = 56.0;

  /// Zo lang glijdt een blokje naar zijn nieuwe plek.
  static const _glide = Duration(milliseconds: 220);

  final List<MemberOnMap> members;
  final ValueChanged<MemberOnMap> onTap;

  /// Waar elk lid nu is (voor het plaats-icoon in het blokje).
  final Map<String, PlaceStatus> placeByUser;

  /// Wat de kaart nu onderaan bedekt; opnieuw gelezen bij [coverChanges]
  /// (bv. als het paneel versleept wordt).
  final MapCover Function() cover;
  final Listenable? coverChanges;

  @override
  State<OffscreenMembersLayer> createState() => _OffscreenMembersLayerState();
}

class _OffscreenMembersLayerState extends State<OffscreenMembersLayer> {
  /// Welke groepen (via hun eerste lid) bij de vorige keer een blokje hadden
  /// (zie [OffscreenMembersLayer._hysteresis]).
  Set<String> _shown = const {};

  @override
  Widget build(BuildContext context) {
    final changes = widget.coverChanges;
    if (changes == null) return _arrows(context);
    return ListenableBuilder(listenable: changes, builder: (context, _) => _arrows(context));
  }

  Widget _arrows(BuildContext context) {
    const margin = OffscreenMembersLayer._margin;
    const tip = OffscreenMembersLayer.tip;
    final camera = MapCamera.of(context);
    final size = camera.size;
    final cover = widget.cover();
    final visible = Rect.fromLTRB(margin, margin, size.width - margin, size.height - cover.sheet - margin);
    final buttons = Rect.fromLTRB(
      size.width - cover.buttonsWidth - margin,
      size.height - cover.buttonsTop - margin,
      size.width,
      size.height - cover.buttonsBottom + margin,
    );
    final avoid = [if (cover.buttonsTop > cover.buttonsBottom) buttons];

    final byId = {for (final member in widget.members) member.member.userId: member};
    final faces = <String, Offset>{
      for (final member in widget.members)
        if (member.location case final location?)
          member.member.userId:
              camera.latLngToScreenOffset(LatLng(location.latitude, location.longitude)) -
              const Offset(0, OffscreenMembersLayer._avatarLift),
    };
    // Groepen op het scherm; de eerste van elke groep is het anker.
    final groups = {
      for (final group in clusterByScreenDistance(
        [for (final MapEntry(key: id, value: face) in faces.entries) ClusterPoint(id, face)],
        thresholdPx: OffscreenMembersLayer._together,
      ))
        group.first: [for (final id in group) byId[id]!],
    };
    const radius = OffscreenMembersLayer._thickness / 2 + tip;
    final indicators = edgeIndicators(
      {for (final anchor in groups.keys) anchor: faces[anchor]!},
      visible,
      radius: radius,
      shown: _shown,
      hysteresis: OffscreenMembersLayer._hysteresis,
      avoid: avoid,
    );
    _shown = {for (final indicator in indicators) indicator.id};

    // Elk blokje ligt langs zijn rand; lange blokjes schuiven binnen het
    // zichtbare deel, weg van de knoppen en van elkaar.
    final placed = <Rect>[];
    final children = <Widget>[];
    for (final indicator in indicators) {
      final group = groups[indicator.id]!;
      final place = _sharedPlace(group);
      final items = math.min(group.length, OffscreenMembersLayer._maxFaces) + (place == null ? 0 : 1);
      final length = items * OffscreenMembersLayer.face + 2 * OffscreenMembersLayer._padding;
      final inner = visible.deflate(radius);
      final vertical =
          indicator.position.dx <= inner.left + 0.5 || indicator.position.dx >= inner.right - 0.5;
      final capsule = _fit(
        Rect.fromCenter(
          center: indicator.position,
          width: vertical ? OffscreenMembersLayer._thickness : length,
          height: vertical ? length : OffscreenMembersLayer._thickness,
        ),
        vertical: vertical,
        within: visible.deflate(tip),
        avoid: [...avoid, ...placed],
      );
      placed.add(capsule);
      children.add(
        AnimatedPositioned(
          key: ValueKey(indicator.id),
          duration: OffscreenMembersLayer._glide,
          curve: Curves.easeOut,
          left: capsule.left - tip,
          top: capsule.top - tip,
          child: _Indicator(
            members: group,
            place: place,
            angle: indicator.angle,
            vertical: vertical,
            capsule: capsule.size,
            onTap: widget.onTap,
          ),
        ),
      );
    }
    return SizedBox.expand(child: Stack(children: children));
  }

  /// De plaats waar de hele groep is, of null.
  PlaceStatus? _sharedPlace(List<MemberOnMap> group) {
    final first = widget.placeByUser[group.first.member.userId];
    if (first == null) return null;
    for (final member in group.skip(1)) {
      final place = widget.placeByUser[member.member.userId];
      if (place == null || place.name != first.name || place.icon != first.icon) return null;
    }
    return first;
  }

  /// Schuift [rect] langs zijn rand ([vertical]: op en neer) tot het binnen
  /// [within] past en niets uit [avoid] raakt.
  Rect _fit(Rect rect, {required bool vertical, required Rect within, required List<Rect> avoid}) {
    Rect clamp(Rect r) => vertical
        ? r.shift(Offset(0, (within.top - r.top).clamp(0, double.infinity) + (within.bottom - r.bottom).clamp(double.negativeInfinity, 0)))
        : r.shift(Offset((within.left - r.left).clamp(0, double.infinity) + (within.right - r.right).clamp(double.negativeInfinity, 0), 0));
    var result = clamp(rect);
    for (var tries = 0; tries <= avoid.length; tries++) {
      final hit = avoid.where((area) => area.overlaps(result)).firstOrNull;
      if (hit == null) break;
      // Erboven (of links ervan); past dat niet, dan eronder (of rechts).
      final before = vertical
          ? result.shift(Offset(0, hit.top - result.bottom))
          : result.shift(Offset(hit.left - result.right, 0));
      final fits = vertical ? before.top >= within.top : before.left >= within.left;
      result = fits
          ? before
          : clamp(vertical ? result.shift(Offset(0, hit.bottom - result.top)) : result.shift(Offset(hit.right - result.left, 0)));
    }
    return result;
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.members,
    required this.place,
    required this.angle,
    required this.vertical,
    required this.capsule,
    required this.onTap,
  });

  final List<MemberOnMap> members;
  final PlaceStatus? place;
  final double angle;
  final bool vertical;
  final Size capsule;
  final ValueChanged<MemberOnMap> onTap;

  @override
  Widget build(BuildContext context) {
    const tip = OffscreenMembersLayer.tip;
    const max = OffscreenMembersLayer._maxFaces;
    final extra = members.length > max ? members.length - (max - 1) : 0;
    final shown = extra > 0 ? members.take(max - 1).toList() : members;
    final items = [
      if (place case final place?) _place(place),
      for (final member in shown) _face(member),
      if (extra > 0) _plus(extra),
    ];
    // Zacht verschijnen in plaats van plots op te springen.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: OffscreenMembersLayer._glide,
      builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Semantics(
        label: members.map((m) => m.member.displayName).join(', '),
        child: SizedBox(
          width: capsule.width + 2 * tip,
          height: capsule.height + 2 * tip,
          child: CustomPaint(
            painter: _CapsulePainter(angle: angle, shadows: context.tokens.shadowMarker),
            child: Padding(
              padding: const EdgeInsets.all(tip + OffscreenMembersLayer._padding),
              child: Flex(
                direction: vertical ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
                children: items,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(MemberOnMap member) => Semantics(
    button: true,
    label: member.member.displayName,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(member),
      child: SizedBox.square(
        dimension: OffscreenMembersLayer.face,
        child: Center(child: MemberAvatar(member: member.member, size: OffscreenMembersLayer.face - 2)),
      ),
    ),
  );

  Widget _place(PlaceStatus place) => SizedBox.square(
    dimension: OffscreenMembersLayer.face,
    child: Center(
      child: place.icon == 'home'
          ? Image.asset('assets/markers/huis.png', width: 24, height: 24, fit: BoxFit.contain)
          : Icon(placeIcon(place.icon), size: 18, color: AppColors.primary),
    ),
  );

  Widget _plus(int extra) => SizedBox.square(
    dimension: OffscreenMembersLayer.face,
    child: Center(
      child: Container(
        width: OffscreenMembersLayer.face - 2,
        height: OffscreenMembersLayer.face - 2,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Text(
          '+$extra',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ),
    ),
  );
}

/// Wit afgerond blokje met een puntje in de richting [angle].
class _CapsulePainter extends CustomPainter {
  const _CapsulePainter({required this.angle, required this.shadows});

  final double angle;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    const tip = OffscreenMembersLayer.tip;
    final body = (Offset.zero & size).deflate(tip);
    final center = body.center;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final across = Offset(-direction.dy, direction.dx);
    // Afstand van het midden tot de rand van het blokje in die richting.
    final toEdge = math.min(
      direction.dx.abs() < 1e-6 ? double.infinity : body.width / 2 / direction.dx.abs(),
      direction.dy.abs() < 1e-6 ? double.infinity : body.height / 2 / direction.dy.abs(),
    );
    final base = center + direction * (toEdge - 6);
    final pointer = Path()
      ..addPolygon([base + across * 7, center + direction * (toEdge + tip), base - across * 7], true);
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(body.shortestSide / 2))),
      pointer,
    );
    for (final shadow in shadows) {
      canvas.drawPath(shape.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(shape, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CapsulePainter old) => old.angle != angle || old.shadows != shadows;
}
