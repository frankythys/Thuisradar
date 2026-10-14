import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/walking_cycle.dart';

/// Tekent de twee wandelende sneakers in een vak van [box] op tijdstip [t]
/// (0..1 binnen de cyclus): eerst de achterste voet (halve cyclus verder),
/// dan de voorste. [sprite] is één platte schoen, neus naar rechts.
void paintWalkingSneakers(Canvas canvas, Size box, ui.Image sprite, double t) {
  _paintShoe(canvas, box, sprite, t + 0.5, far: true);
  _paintShoe(canvas, box, sprite, t, far: false);
}

/// Donkerder maken van de achterste voet ([kFarShade]), alfa ongemoeid.
const _farShade = ColorFilter.matrix(<double>[
  kFarShade, 0, 0, 0, 0, //
  0, kFarShade, 0, 0, 0, //
  0, 0, kFarShade, 0, 0, //
  0, 0, 0, 1, 0, //
]);

void _paintShoe(Canvas canvas, Size box, ui.Image sprite, double phase, {required bool far}) {
  final pose = sneakerPose(phase);
  final width = kShoeLength * box.width;
  final height = width * sprite.height / sprite.width;
  final ground = kGround * box.height - (far ? kFarRaise * box.height : 0);
  final cx = box.width / 2 + pose.x * box.width;
  final cy = ground - kLift * box.height * pose.lift - sneakerBottom(pose.pitchDegrees, width, height);

  // Schaduw op de grond: kleiner en lichter naarmate de voet hoger komt.
  final k = 1 - 0.5 * pose.lift;
  final shadow = Paint()
    ..color = AppColors.ink.withValues(alpha: 0.22 * (1 - 0.6 * pose.lift))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.height * 0.008);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, ground), width: width * 0.84 * k, height: box.height * 0.023 * k),
    shadow,
  );

  final paint = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = true;
  if (far) paint.colorFilter = _farShade;
  canvas
    ..save()
    ..translate(cx, cy)
    ..rotate(pose.pitchDegrees * math.pi / 180)
    ..drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      paint,
    )
    ..restore();
}
