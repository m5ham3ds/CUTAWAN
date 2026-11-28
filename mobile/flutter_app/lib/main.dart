import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Keep Android's plain launch background visible until the first video
  // frame is ready. This prevents a still logo or placeholder screen.
  binding.deferFirstFrame();

  VideoPlayerController? introController;
  try {
    final controller = VideoPlayerController.asset(
      'assets/cutawan_intro.mp4',
    );
    introController = controller;
    await controller.initialize().timeout(const Duration(seconds: 20));
    await controller.setLooping(false);
    await controller.setVolume(0);
  } catch (_) {
    try {
      await introController?.dispose();
    } catch (_) {
      // Continue to the dashboard if the intro asset cannot be prepared.
    }
    introController = null;
  }

  runApp(
    CutawanApp(
      showIntro: introController != null,
      introController: introController,
    ),
  );
  binding.allowFirstFrame();
}
