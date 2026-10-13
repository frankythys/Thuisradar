import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/bubble_layout.dart';
import 'map_marker_spec.dart';
import 'member_history_bubble.dart';
import 'walking_gif_frames.dart';

/// De wandelende sneakers als aparte Google-marker, exact op de lege plek
/// ([MemberHistoryBubble.walkerSlot]) van de ballon met [alignment] en
/// [offset].
///
/// Enkel het vak van de sneakers wordt getekend, met een smalle rand: elk
/// beeld is zo een kleine afbeelding, die Android vlot kan wisselen.
MapMarkerSpec walkerSpec({
  required String id,
  required LatLng point,
  required Alignment alignment,
  required Offset offset,
  required List<WalkingGifFrame> frames,
}) {
  const slot = MemberHistoryBubble.walkerSlot;
  // Midden van de ballon t.o.v. het kaartpunt, zoals flutter_map hem plaatst.
  final bubbleCenter = Offset(
    alignment.x * kBubbleWidth / 2 + offset.dx,
    alignment.y * kBubbleHeight / 2 + offset.dy,
  );
  final slotCenter = bubbleCenter - const Offset(kBubbleWidth / 2, kBubbleHeight / 2) + slot.center;
  final images = [
    for (final frame in frames)
      (
        child: RawImage(image: frame.image, width: slot.width, height: slot.height, fit: BoxFit.contain),
        duration: frame.duration,
      ),
  ];
  return MapMarkerSpec(
    id: id,
    point: point,
    width: slot.width,
    height: slot.height,
    offset: slotCenter,
    margin: 2,
    frames: images,
    child: images.first.child,
  );
}
