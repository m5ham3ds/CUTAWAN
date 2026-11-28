import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays the supplied CUTAWAN brand intro once, then hands off to the app.
class CutawanIntroScreen extends StatefulWidget {
  const CutawanIntroScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<CutawanIntroScreen> createState() => _CutawanIntroScreenState();
}

class _CutawanIntroScreenState extends State<CutawanIntroScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/cutawan_intro.mp4');
    _controller.addListener(_handlePlayback);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setLooping(false);
      // Keep the uploaded MP4 untouched while honoring the silent intro request.
      await _controller.setVolume(0);
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();
    } catch (_) {
      _finish();
    }
  }

  void _handlePlayback() {
    if (!_controller.value.isInitialized ||
        _controller.value.isPlaying ||
        _controller.value.position < _controller.value.duration) {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Scaffold(
        backgroundColor: const Color(0xFF101113),
        body: Center(
          child: _ready && _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : Image.asset(
                  'assets/cutawan_logo.jpg',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'CUTAWAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
