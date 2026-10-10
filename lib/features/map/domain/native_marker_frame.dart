import 'dart:ui';

/// Hoe een flutter_map-marker als afbeelding in Google Maps komt.
///
/// flutter_map plaatst een vak van [size] rond het kaartpunt volgens een
/// uitlijning (`alignX`/`alignY` zoals `Alignment`) en een extra verschuiving
/// [offset]. Google verwacht één afbeelding met een ankerpunt (0..1) dat op het
/// kaartpunt komt. Het canvas omvat daarom het vak én het kaartpunt zelf, zodat
/// het anker altijd binnen de afbeelding valt.
/// Een [margin] laat ruimte voor schaduw en lichtkring buiten het vak.
class NativeMarkerFrame {
  const NativeMarkerFrame({required this.canvas, required this.child, required this.anchor});

  /// Grootte van de afbeelding.
  final Size canvas;

  /// Waar het oorspronkelijke vak in de afbeelding staat.
  final Rect child;

  /// Punt van de afbeelding (0..1) dat op de kaartpositie staat.
  final Offset anchor;
}

NativeMarkerFrame nativeMarkerFrame({
  required Size size,
  double alignX = 0,
  double alignY = 0,
  Offset offset = Offset.zero,
  double margin = 0,
}) {
  // Vak ten opzichte van het kaartpunt (0,0), zoals flutter_map het tekent.
  final box = Rect.fromCenter(
    center: Offset(alignX * size.width / 2 + offset.dx, alignY * size.height / 2 + offset.dy),
    width: size.width,
    height: size.height,
  );
  // [margin]: ruimte voor wat buiten het vak getekend wordt (schaduw, gloed).
  final bounds = box.inflate(margin).expandToInclude(Rect.fromLTWH(0, 0, 0, 0));
  return NativeMarkerFrame(
    canvas: bounds.size,
    child: box.shift(-bounds.topLeft),
    anchor: Offset(-bounds.left / bounds.width, -bounds.top / bounds.height),
  );
}
