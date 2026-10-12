import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'walking_gif_frames.dart';

/// Speelt de wandel-GIF af als widget (flutter_map), beeld per beeld op het
/// tempo van de GIF. Zolang de beelden laden, of als laden mislukt: het
/// wandelicoon.
class WalkingSneakers extends StatefulWidget {
  const WalkingSneakers({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<WalkingSneakers> createState() => _WalkingSneakersState();
}

class _WalkingSneakersState extends State<WalkingSneakers> {
  List<WalkingGifFrame> _frames = const [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(
      walkingGifFrames().then((frames) {
        if (!mounted || frames.isEmpty) return;
        setState(() => _frames = frames);
        _next();
      }),
    );
  }

  void _next() {
    _timer = Timer(_frames[_index].duration, () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _frames.length);
      _next();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
