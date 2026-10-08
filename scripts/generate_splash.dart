import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// Alleen de buitenhoeken afronden. Geen kleurcorrectie of uitsnede van het logo.
img.Image roundedArtwork(img.Image source, int size) {
  final artwork = img
      .copyResize(
        source,
        width: size,
        height: size,
        interpolation: img.Interpolation.average,
      )
      .convert(numChannels: 4);
  final radius = size * 0.22;
  for (final pixel in artwork) {
    final x = pixel.x + 0.5;
    final y = pixel.y + 0.5;
    final cx = x.clamp(radius, size - radius);
    final cy = y.clamp(radius, size - radius);
    final distance = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
    pixel.a = pixel.a * (radius + 0.5 - distance).clamp(0.0, 1.0);
  }
  return artwork;
}

void main() {
  final source = img.decodePng(
    File('assets/icon/CircleBeakon_icon.png').readAsBytesSync(),
  )!;
  final canvas = img.Image(width: 1152, height: 1152, numChannels: 4);
  final artwork = roundedArtwork(source, 600);
  if (artwork.getPixel(0, 0).a != 0) {
    throw StateError('Afgeronde hoeken moeten transparant zijn');
  }
  img.compositeImage(canvas, artwork, dstX: 276, dstY: 276);
  File('assets/markers/splash_android12.png')
      .writeAsBytesSync(img.encodePng(canvas));
  File('assets/markers/splash_rounded.png')
      .writeAsBytesSync(img.encodePng(roundedArtwork(source, 600)));
  final preview = img.Image(width: 412, height: 915, numChannels: 4);
  img.fill(preview, color: img.ColorRgba8(243, 248, 252, 255));
  img.compositeImage(preview, roundedArtwork(source, 172), dstX: 120, dstY: 371);
  Directory('build').createSync(recursive: true);
  File('build/splash-preview.png').writeAsBytesSync(img.encodePng(preview));
}
