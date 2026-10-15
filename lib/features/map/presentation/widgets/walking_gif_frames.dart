import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/walking_cycle.dart';
import 'walking_sneakers_painter.dart';

/// Eén beeld van de wandelanimatie en hoe lang het blijft staan.
typedef WalkingGifFrame = ({ui.Image image, Duration duration});

/// Eén platte sneaker, neus naar rechts, met transparante achtergrond. De
/// wandelbeweging zelf wordt in code getekend ([paintWalkingSneakers]).
const walkingSneakerAsset = 'assets/markers/sneaker.webp';

/// Grootte van één beeld in pixels: dezelfde verhouding als het vak van de
/// sneakers in de ballon (52 × 32), zodat de schoenen het hele vak vullen, en
/// scherp genoeg voor een 3×-scherm.
const kWalkingFrameWidth = 169;
const kWalkingFrameHeight = 104;

Future<List<WalkingGifFrame>>? _frames;
List<WalkingGifFrame>? _loaded;

/// De beelden als ze al getekend zijn, anders null. Zo toont een nieuwe
/// widget (bv. na opnieuw opbouwen) meteen de schoenen, zonder één beeld
/// met het wandelicoon ertussen.
List<WalkingGifFrame>? get walkingFramesLoaded => _loaded;

/// De beelden van de wandelanimatie: één naadloze cyclus van
/// [kWalkingLoopFrames] beelden, één keer getekend en daarna uit het
/// geheugen. De naam is gebleven van toen dit nog een GIF was.
///
/// De app speelt de beelden zelf af: op Google Maps is een marker een vaste
/// afbeelding, dus daar kan een animatie niet vanzelf bewegen. Lukt het
/// tekenen niet, dan een lege lijst (de ballon toont dan het wandelicoon) en
/// wordt het later opnieuw geprobeerd.
Future<List<WalkingGifFrame>> walkingGifFrames() => _frames ??= _load();

Future<List<WalkingGifFrame>> _load() async {
  ui.Image? sprite;
  try {
    final data = await rootBundle.load(walkingSneakerAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    sprite = (await codec.getNextFrame()).image;
    codec.dispose();
    final frames = await renderWalkingFrames(sprite);
    _loaded = frames;
    return frames;
  } catch (error) {
    debugPrint('Wandelanimatie laden mislukt: $error');
    _frames = null;
    return const [];
  } finally {
    sprite?.dispose();
  }
}

/// Tekent één volledige wandelcyclus met [sprite] als [kWalkingLoopFrames]
/// losse beelden van [kWalkingFrameWidth] × [kWalkingFrameHeight].
Future<List<WalkingGifFrame>> renderWalkingFrames(ui.Image sprite) async {
  const box = ui.Size(kWalkingFrameWidth * 1.0, kWalkingFrameHeight * 1.0);
  final frames = <WalkingGifFrame>[];
  for (var i = 0; i < kWalkingLoopFrames; i++) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Offset.zero & box);
    paintWalkingSneakers(canvas, box, sprite, i / kWalkingLoopFrames);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(kWalkingFrameWidth, kWalkingFrameHeight);
      frames.add((image: image, duration: kWalkFrameDuration));
    } finally {
      picture.dispose();
    }
  }
  return frames;
}
