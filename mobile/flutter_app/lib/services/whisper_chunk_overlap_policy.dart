/// Assigns overlapped Whisper segments to one chunk deterministically.
///
/// For the default two-second overlap, the shared audio is split at its
/// midpoint. The earlier chunk owns the first half; the later chunk owns the
/// second half. This avoids dropping an entire segment just because its
/// midpoint falls anywhere inside the overlap.
class WhisperChunkOverlapPolicy {
  const WhisperChunkOverlapPolicy._();

  static bool keepSegment({
    required int chunkOffsetMs,
    required int overlapMs,
    required int localStartMs,
    required int localEndMs,
  }) {
    if (localEndMs <= localStartMs) return false;
    if (chunkOffsetMs <= 0 || overlapMs <= 0) return true;
    final midpoint = (localStartMs + localEndMs) / 2;
    return midpoint >= overlapMs / 2;
  }
}
