class WhisperChunkWindow {
  const WhisperChunkWindow({
    required this.startSample,
    required this.endSample,
    required this.ownedStartSample,
    required this.ownedEndSample,
  });

  final int startSample;
  final int endSample;

  /// The chunk may contain overlap before/after this range, but only segment
  /// midpoints inside this half-open interval are committed to the transcript.
  final int ownedStartSample;
  final int ownedEndSample;

  int get ownedStartMs =>
      (ownedStartSample * 1000 / WhisperChunkPlanner.sampleRate).round();

  int get ownedEndMs =>
      (ownedEndSample * 1000 / WhisperChunkPlanner.sampleRate).round();

  bool ownsMidpointMs(double midpointMs) =>
      midpointMs >= ownedStartMs && midpointMs < ownedEndMs;
}

class WhisperChunkPlanner {
  static const sampleRate = 16000;
  static const chunkSeconds = 30;
  static const overlapSeconds = 2;

  static const chunkSamples = sampleRate * chunkSeconds;
  static const overlapSamples = sampleRate * overlapSeconds;
  static const stepSamples = chunkSamples - overlapSamples;
  static const ownershipInsetSamples = overlapSamples ~/ 2;

  static List<WhisperChunkWindow> plan(int totalSamples) {
    if (totalSamples < 0) {
      throw RangeError.value(totalSamples, 'totalSamples');
    }
    if (totalSamples == 0) return const [];

    final chunks = <WhisperChunkWindow>[];
    var start = 0;
    while (start < totalSamples) {
      final end = (start + chunkSamples).clamp(0, totalSamples).toInt();
      final ownedStart = start == 0
          ? 0
          : start + ownershipInsetSamples;
      final ownedEnd = end >= totalSamples
          ? totalSamples
          : start + chunkSamples - ownershipInsetSamples;
      chunks.add(WhisperChunkWindow(
        startSample: start,
        endSample: end,
        ownedStartSample: ownedStart,
        ownedEndSample: ownedEnd,
      ));
      if (end >= totalSamples) break;
      start += stepSamples;
    }
    return chunks;
  }
}
