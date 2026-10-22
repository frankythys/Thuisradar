import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/edge_indicator.dart';
import '../../domain/member_on_map.dart';

/// Leden buiten beeld (bv. wie wegrijdt terwijl de kaart stilstaat): een
/// gezichtje aan de rand van de kaart met een puntje naar waar die persoon is.
/// Tik erop om naar die persoon te gaan. Jezelf niet: daarvoor is de
/// centreerknop.
class OffscreenMembersLayer extends StatelessWidget {
  const OffscreenMembersLayer({
    super.key,
    required this.members,
    required this.onTap,
    this.myUserId,
    this.bottomInset = 0,
  });

  /// Diameter van het witte rondje; het puntje steekt er [tip] buiten.
  static const circle = 46.0;
  static const tip = 9.0;
  static const _box = circle + 2 * tip;

  /// Afstand tot de rand van de kaart en tot het onderpaneel.
  static const _margin = 8.0;

  final List<MemberOnMap> members;
  final ValueChanged<MemberOnMap> onTap;
  final String? myUserId;

  /// Hoogte van het onderpaneel: wat erachter ligt, telt als buiten beeld.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final visible = Rect.fromLTRB(
      _margin,
      _margin,
      camera.size.width - _margin,
      camera.size.height - bottomInset - _margin,
    );
    final byId = {for (final member in members) member.member.userId: member};
    final indicators = edgeIndicators(
      {
        for (final member in members)
          if (member.member.userId != myUserId)
            if (member.location case final location?)
              member.member.userId: camera.latLngToScreenOffset(LatLng(location.latitude, location.longitude)),
      },
      visible,
      radius: _box / 2,
    );

    return SizedBox.expand(
      child: Stack(
        children: [
          for (final indicator in indicators)
            Positioned(
              left: indicator.position.dx - _box / 2,
              top: indicator.position.dy - _box / 2,
              child: _Indicator(
                member: byId[indicator.id]!,
                angle: indicator.angle,
                onTap: () => onTap(byId[indicator.id]!),
              ),
            ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.member, required this.angle, required this.onTap});

  final MemberOnMap member;
  final double angle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const box = OffscreenMembersLayer._box;
    return Semantics(
      button: true,
      label: member.member.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: box,
          child: CustomPaint(
            painter: _PointerPainter(angle: angle, shadows: context.tokens.shadowMarker),
            child: Center(
              child: MemberAvatar(member: member.member, size: OffscreenMembersLayer.circle - 6),
            ),
          ),
        ),
      ),
    );
  }
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
