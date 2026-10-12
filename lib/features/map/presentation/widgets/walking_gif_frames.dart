import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'member_history_bubble.dart' show walkingGifAsset;

/// Eén beeld van de wandel-GIF en hoe lang het blijft staan.
typedef WalkingGifFrame = ({ui.Image image, Duration duration});

Future<List<WalkingGifFrame>>? _frames;

/// Alle beelden van de (transparante) wandel-GIF, één keer gedecodeerd, als
/// heen-en-terug-reeks (zie [pingPong]): zo sluiten einde en begin zonder
/// sprong op elkaar aan.
///
/// De app speelt de beelden zelf af: op Google Maps is een marker een vaste
/// afbeelding, dus daar kan een GIF niet vanzelf bewegen. Lukt het laden
/// niet, dan een lege lijst (de ballon toont dan het wandelicoon) en wordt
/// het later opnieuw geprobeerd.
Future<List<WalkingGifFrame>> walkingGifFrames() => _frames ??= _decode();

Future<List<WalkingGifFrame>> _decode() async {
  try {
    final data = await rootBundle.load(walkingGifAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frames = <WalkingGifFrame>[];
    for (var i = 0; i < codec.frameCount; i++) {
      final frame = await codec.getNextFrame();
      final duration = frame.duration > Duration.zero ? frame.duration : const Duration(milliseconds: 100);
      frames.add((image: frame.image, duration: duration));
    }
    codec.dispose();
    return pingPong(frames);
  } catch (error) {
    debugPrint('Wandel-GIF laden mislukt: $error');
    _frames = null;
    return const [];
  }
}

/// Eerst vooruit, dan achteruit: 1 → 30 → 29 → … → 2, en dan weer 1. De
/// eerste en laatste komen maar één keer voor, anders bleven die beelden
/// dubbel zo lang staan.
List<T> pingPong<T>(List<T> frames) => [
  ...frames,
  if (frames.length > 2) ...frames.reversed.skip(1).take(frames.length - 2),
];
