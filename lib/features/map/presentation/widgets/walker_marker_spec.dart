import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/bubble_layout.dart';
import 'google_walker_overlay.dart';
import 'map_marker_spec.dart';
import 'member_history_bubble.dart';

/// De wandelende sneakers boven de Google-kaart ([GoogleWalkerOverlay]),
/// exact op het vak ([slot], zie [MemberHistoryBubble.walkerSlotFor]) van de ballon met
/// [alignment] en [offset], plus een smalle rand ([GoogleWalkerOverlay.bleed]).
///
/// Dit gaat niet naar Google: de kaart erboven tekent het als widget, zodat
/// Google voor de animatie niets hoeft te verversen.
MapMarkerSpec walkerOverlaySpec({
  required String id,
  required LatLng point,
  required Alignment alignment,
  required Offset offset,
  Rect slot = MemberHistoryBubble.walkerSlot,
}) {
  // Midden van de ballon t.o.v. het kaartpunt, zoals flutter_map hem plaatst.
  final bubbleCenter = Offset(
    alignment.x * kBubbleWidth / 2 + offset.dx,
    alignment.y * kBubbleHeight / 2 + offset.dy,
  );
  final slotCenter = bubbleCenter - const Offset(kBubbleWidth / 2, kBubbleHeight / 2) + slot.center;
  const bleed = GoogleWalkerOverlay.bleed;
  return MapMarkerSpec(
    id: id,
    point: point,
    width: slot.width + 2 * bleed,
    height: slot.height + 2 * bleed,
    offset: slotCenter,
    child: GoogleWalkerOverlay(width: slot.width, height: slot.height),
  );
}
