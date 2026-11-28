import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Plays the prepared CUTAWAN brand animation full-screen, then opens home.
class CutawanIntroScreen extends StatefulWidget {
  const CutawanIntroScreen({
    super.key,
    required this.controller,
    required this.onFinished,
  });

  final VideoPlayerController controller;
  final VoidCallback onFinished;

  @override
  State<CutawanIntroScreen> createState() => _CutawanIntroScreenState();
}

class _CutawanIntroScreenState extends State<CutawanIntroScreen> {
  bool _finished = false;

  VideoPlayerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handlePlayback);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startPlayback();
    });
  }

  Future<void> _startPlayback() async {
    try {
      await _controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _handlePlayback() {
    final value = _controller.value;
    if (!value.isInitialized ||
        value.isPlaying ||
        value.duration <= Duration.zero ||
        value.position < value.duration) {
      return;
    }
    _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePlayback);
    unawaited(_controller.dispose());
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _controller.value.size;
    return Scaffold(
      backgroundColor: const Color(0xFF101113),
      body: SizedBox.expand(
        child: size.width <= 0 || size.height <= 0
            ? const ColoredBox(color: Color(0xFF101113))
            : ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
      ),
    );
  }
}
