import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/member_avatar.dart';
import '../../domain/edge_indicator.dart';
import '../../domain/member_on_map.dart';
import 'member_marker.dart';

/// Wat de kaart onderaan bedekt, gemeten vanaf de onderkant van de kaart: het
/// paneel ([sheet] hoog) en rechts erboven de knoppenkolom ([buttonsWidth]
/// breed inclusief marge, van [buttonsBottom] tot [buttonsTop] hoog).
typedef MapCover = ({double sheet, double buttonsWidth, double buttonsBottom, double buttonsTop});

/// Leden buiten beeld (bv. wie wegrijdt terwijl de kaart stilstaat): een
/// gezichtje aan de rand van de kaart met een puntje naar waar die persoon is.
/// Tik erop om naar die persoon te gaan.
class OffscreenMembersLayer extends StatefulWidget {
  const OffscreenMembersLayer({
    super.key,
    required this.members,
    required this.onTap,
    required this.cover,
    this.coverChanges,
  });

  /// Diameter van het witte rondje; het puntje steekt er [tip] buiten.
  static const circle = 46.0;
  static const tip = 9.0;
  static const _box = circle + 2 * tip;

  /// Afstand tot de rand van de kaart, het paneel en de knoppen.
  static const _margin = 8.0;

  /// Wie een pijl heeft, houdt die tot zijn gezichtje zo ver in beeld is.
  static const _hysteresis = 24.0;

  /// Het gezichtje van een marker staat boven zijn punt; dat telt.
  static const _avatarLift = MemberMarker.avatarSize * 0.75;

  /// Zo lang glijdt een pijl naar zijn nieuwe plek.
  static const _glide = Duration(milliseconds: 220);

  final List<MemberOnMap> members;
  final ValueChanged<MemberOnMap> onTap;

  /// Wat de kaart nu onderaan bedekt; opnieuw gelezen bij [coverChanges]
  /// (bv. als het paneel versleept wordt).
  final MapCover Function() cover;
  final Listenable? coverChanges;

  @override
  State<OffscreenMembersLayer> createState() => _OffscreenMembersLayerState();
}

class _OffscreenMembersLayerState extends State<OffscreenMembersLayer> {
  /// Wie bij de vorige keer een pijl had (zie [OffscreenMembersLayer._hysteresis]).
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
    final indicators = edgeIndicators(
      {
        for (final member in widget.members)
          if (member.location case final location?)
            member.member.userId:
                camera.latLngToScreenOffset(LatLng(location.latitude, location.longitude)) -
                const Offset(0, OffscreenMembersLayer._avatarLift),
      },
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
                member: byId[indicator.id]!,
                angle: indicator.angle,
                onTap: () => widget.onTap(byId[indicator.id]!),
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
    // Zacht verschijnen in plaats van plots op te springen.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: OffscreenMembersLayer._glide,
      builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Semantics(
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
