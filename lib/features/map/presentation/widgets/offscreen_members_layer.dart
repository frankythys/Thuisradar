import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/edge_indicator.dart';
import '../../domain/marker_cluster.dart';
import '../../domain/member_on_map.dart';
import 'member_marker.dart';

/// Wat de kaart onderaan bedekt, gemeten vanaf de onderkant van de kaart: het
/// paneel ([sheet] hoog) en rechts erboven de knoppenkolom ([buttonsWidth]
/// breed inclusief marge, van [buttonsBottom] tot [buttonsTop] hoog).
typedef MapCover = ({double sheet, double buttonsWidth, double buttonsBottom, double buttonsTop});

/// Leden buiten beeld (bv. wie wegrijdt terwijl de kaart stilstaat): een
/// gezichtje aan de rand van de kaart met een puntje naar waar die persoon is.
/// Wie op de kaart samen staat, krijgt één pijl met hun gezichtjes samen.
/// Tik op een pijl om naar die persoon (of groep) te gaan.
class OffscreenMembersLayer extends StatefulWidget {
  const OffscreenMembersLayer({
    super.key,
    required this.members,
    required this.onTap,
    required this.cover,
    this.onGroupTap,
    this.coverChanges,
  });

  /// Diameter van het witte rondje; het puntje steekt er [tip] buiten.
  static const circle = 50.0;
  static const tip = 9.0;
  static const _box = circle + 2 * tip;

  /// Afstand tot de rand van de kaart, het paneel en de knoppen.
  static const _margin = 8.0;

  /// Wie een pijl heeft, houdt die tot zijn gezichtje zo ver in beeld is.
  static const _hysteresis = 24.0;

  /// Het gezichtje van een marker staat boven zijn punt; dat telt.
  static const _avatarLift = MemberMarker.avatarSize * 0.75;

  /// Wie op het scherm dichter bij elkaar staat, deelt één pijl.
  static const _together = 56.0;

  /// Zo lang glijdt een pijl naar zijn nieuwe plek.
  static const _glide = Duration(milliseconds: 220);

  final List<MemberOnMap> members;

  /// Tik op de pijl van één persoon.
  final ValueChanged<MemberOnMap> onTap;

  /// Tik op de pijl van een groep: de plek van de groep. Zonder: zoals [onTap]
  /// met de eerste van de groep.
  final ValueChanged<LatLng>? onGroupTap;

  /// Wat de kaart nu onderaan bedekt; opnieuw gelezen bij [coverChanges]
  /// (bv. als het paneel versleept wordt).
  final MapCover Function() cover;
  final Listenable? coverChanges;

  @override
  State<OffscreenMembersLayer> createState() => _OffscreenMembersLayerState();
}

class _OffscreenMembersLayerState extends State<OffscreenMembersLayer> {
  /// Welke groepen (via hun eerste lid) bij de vorige keer een pijl hadden
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
    const box = OffscreenMembersLayer._box;
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
    final indicators = edgeIndicators(
      {for (final anchor in groups.keys) anchor: faces[anchor]!},
      visible,
      radius: box / 2,
      shown: _shown,
      hysteresis: OffscreenMembersLayer._hysteresis,
      avoid: [if (cover.buttonsTop > cover.buttonsBottom) buttons],
    );
    _shown = {for (final indicator in indicators) indicator.id};

    return SizedBox.expand(
      child: Stack(
        children: [
          for (final indicator in indicators)
            AnimatedPositioned(
              key: ValueKey(indicator.id),
              duration: OffscreenMembersLayer._glide,
              curve: Curves.easeOut,
              left: indicator.position.dx - box / 2,
              top: indicator.position.dy - box / 2,
              child: _Indicator(
                members: groups[indicator.id]!,
                angle: indicator.angle,
                onTap: () => _tap(groups[indicator.id]!),
              ),
            ),
        ],
      ),
    );
  }

  void _tap(List<MemberOnMap> group) {
    final onGroupTap = widget.onGroupTap;
    final location = group.first.location;
    if (group.length == 1 || onGroupTap == null || location == null) return widget.onTap(group.first);
    onGroupTap(LatLng(location.latitude, location.longitude));
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.members, required this.angle, required this.onTap});

  final List<MemberOnMap> members;
  final double angle;
  final VoidCallback onTap;

  /// Meer dan drie: twee gezichtjes en "+N".
  static const _maxFaces = 3;
  static const _face = 30.0;

  @override
  Widget build(BuildContext context) {
    const box = OffscreenMembersLayer._box;
    // Zacht verschijnen in plaats van plots op te springen.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: OffscreenMembersLayer._glide,
      builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Semantics(
        button: true,
        label: members.map((m) => m.member.displayName).join(', '),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: box,
            child: CustomPaint(
              painter: _PointerPainter(angle: angle, shadows: context.tokens.shadowMarker),
              child: members.length == 1
                  ? Center(child: MemberAvatar(member: members.single.member, size: OffscreenMembersLayer.circle - 6))
                  : _group(),
            ),
          ),
        ),
      ),
    );
  }

  /// Twee naast elkaar of drie als driehoek, zoals de groepspin.
  Widget _group() {
    final extra = members.length > _maxFaces ? members.length - (_maxFaces - 1) : 0;
    final shown = extra > 0 ? members.take(_maxFaces - 1).toList() : members;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    final offsets = slots == 2
        ? const [Offset(-9, 0), Offset(9, 0)]
        : const [Offset(0, -8), Offset(-9, 7), Offset(9, 7)];
    Widget at(Offset offset, Widget child) => Positioned(
      left: OffscreenMembersLayer._box / 2 + offset.dx - _face / 2,
      top: OffscreenMembersLayer._box / 2 + offset.dy - _face / 2,
      child: child,
    );
    return Stack(
      children: [
        if (extra > 0) at(offsets.last, _plus(extra)),
        // Achterste eerst; de eerste van de groep ligt bovenop.
        for (final (index, member) in shown.indexed.toList().reversed)
          at(
            offsets[index],
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: MemberAvatar(member: member.member, size: _face - 3),
            ),
          ),
      ],
    );
  }

  Widget _plus(int extra) => Container(
    width: _face,
    height: _face,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Text(
      '+$extra',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
    ),
  );
}

/// Wit rondje met een puntje in de richting [angle].
class _PointerPainter extends CustomPainter {
  const _PointerPainter({required this.angle, required this.shadows});

  final double angle;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = OffscreenMembersLayer.circle / 2;
    Offset at(double distance, double turn) =>
        center + Offset(math.cos(angle + turn), math.sin(angle + turn)) * distance;
    // De voet van het puntje ligt binnen het rondje, dus geen naad.
    final pointer = Path()
      ..addPolygon([at(radius * 0.8, -0.45), at(radius + OffscreenMembersLayer.tip, 0), at(radius * 0.8, 0.45)], true);
    final shape = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      pointer,
    );
    for (final shadow in shadows) {
      canvas.drawPath(shape.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(shape, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => old.angle != angle || old.shadows != shadows;
}
