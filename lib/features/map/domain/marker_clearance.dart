import 'dart:ui';

/// Houdt een kaartmarker vrij van plaatsiconen, in schermpixels bij elke zoom.
Offset markerClearance(Rect marker, List<Offset> places) {
  var shift = 0.0;
  for (var pass = 0; pass < places.length; pass++) {
    final bounds = marker.shift(Offset(0, shift));
    final collisions = places.where(
      (point) => bounds.overlaps(
        Rect.fromCircle(center: point, radius: 16).inflate(8),
      ),
    );
    if (collisions.isEmpty) break;
    var next = shift;
    for (final point in collisions) {
      final candidate = point.dy - 24 - marker.bottom;
      if (candidate < next) next = candidate;
    }
    shift = next;
  }
  return Offset(0, shift);
}
