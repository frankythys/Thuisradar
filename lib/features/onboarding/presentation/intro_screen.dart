import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Lokale intro voor de onboarding. Een videofout blokkeert nooit.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onFinished, this.controller});

  final VoidCallback onFinished;

  /// Een meegegeven controller is ook eigendom van dit scherm.
  @visibleForTesting
  final VideoPlayerController? controller;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final VideoPlayerController _controller;
  bool _finished = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        VideoPlayerController.asset('assets/Intro/Intro_vertical.mp4');
    _controller.addListener(_checkPlayback);
    unawaited(_play());
  }

  Future<void> _play() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || _finished) return;
      setState(() {});
      await _controller.play();
    } catch (error) {
      debugPrint('Intro afspelen mislukt: $error');
      _finish();
    }
  }

  void _checkPlayback() {
    final value = _controller.value;
    if (value.hasError || value.isCompleted) _finish();
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    // De gate vervangt dit scherm; dispose stopt ook het geluid.
    widget.onFinished();
  }

  Future<void> _toggleSound() async {
    final muted = !_muted;
    try {
      await _controller.setVolume(muted ? 0 : 1);
      if (mounted) setState(() => _muted = muted);
    } catch (error) {
      debugPrint('Introvolume aanpassen mislukt: $error');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkPlayback);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF081B2A),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF081B2A),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: _controller.value.isInitialized
                    ? VideoPlayer(_controller)
                    : Image.asset(
                        'assets/Intro/intro_poster.jpg',
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Overslaan'),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton.filledTonal(
                    onPressed: _toggleSound,
                    tooltip: _muted ? 'Geluid aan' : 'Geluid uit',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
