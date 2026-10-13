import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'member_history_bubble.dart' show walkingGifAsset;

/// Eén beeld van de wandel-GIF en hoe lang het blijft staan.
typedef WalkingGifFrame = ({ui.Image image, Duration duration});

Future<List<WalkingGifFrame>>? _frames;

/// De beelden van de (transparante) wandel-GIF, één keer gedecodeerd, als
/// doorlopende pas die altijd vooruit stapt (zie [walkingLoop]).
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
    return walkingLoop(frames);
  } catch (error) {
    debugPrint('Wandel-GIF laden mislukt: $error');
    _frames = null;
    return const [];
  }
}

/// Zoveel beelden vormen samen één volledige pas die naadloos herhaalt.
///
/// De GIF zelf sluit niet aan: na beeld 30 springt de achterste schoen terug
/// naar voren. Heen en terug afspelen verbergt die sprong, maar dan stappen de
/// schoenen achteruit. Beelden 1–19 tonen één hele pas (neerzetten, afduwen,
/// doorzwaaien); beeld 19 → 1 is de kleinste overgang in de hele GIF (gemeten
/// per pixel), en omdat beide schoenen er gelijk uitzien loopt het zo
/// onafgebroken vooruit.
const kWalkingLoopFrames = 19;

/// Enkel vooruit: de eerste [kWalkingLoopFrames] beelden, telkens opnieuw.
List<T> walkingLoop<T>(List<T> frames) => frames.take(kWalkingLoopFrames).toList();
