import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import 'walking_gif_frames.dart';

/// Speelt de wandelanimatie af als widget, beeld per beeld op het tempo van
/// de cyclus (zie `walkingGifFrames`), in de maat van het scherm (vsync).
/// Zijn de beelden al getekend, dan staan ze er meteen; anders tot ze klaar
/// zijn (of als het mislukt) het wandelicoon.
class WalkingSneakers extends StatefulWidget {
  const WalkingSneakers({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<WalkingSneakers> createState() => _WalkingSneakersState();
}

class _WalkingSneakersState extends State<WalkingSneakers> with SingleTickerProviderStateMixin {
  List<WalkingGifFrame> _frames = walkingFramesLoaded ?? const [];
  int _index = 0;
  late final Ticker _ticker = createTicker(_tick);

  @override
  void initState() {
    super.initState();
    if (_frames.isNotEmpty) {
      unawaited(_ticker.start());
      return;
    }
    unawaited(
      walkingGifFrames().then((frames) {
        if (!mounted || frames.isEmpty) return;
        setState(() => _frames = frames);
        unawaited(_ticker.start());
      }),
    );
  }

  /// Welk beeld nu, uit de verstreken tijd: geen opgestapelde vertraging.
  void _tick(Duration elapsed) {
    final step = _frames.first.duration.inMicroseconds;
    if (step <= 0) return;
    final index = (elapsed.inMicroseconds ~/ step) % _frames.length;
    if (index != _index) setState(() => _index = index);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frames.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Icon(Icons.directions_walk, color: AppColors.primary, size: 23),
      );
    }
    return RawImage(
      image: _frames[_index].image,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
    );
  }
}
