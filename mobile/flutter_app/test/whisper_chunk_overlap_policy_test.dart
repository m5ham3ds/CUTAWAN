import 'package:cutawan_mobile/services/whisper_chunk_overlap_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first chunk owns its complete non-overlapped window', () {
    expect(
      WhisperChunkOverlapPolicy.keepSegment(
        chunkOffsetMs: 0,
        overlapMs: 2000,
        localStartMs: 0,
        localEndMs: 1000,
      ),
      isTrue,
    );
  });

  test('later chunk discards only the first half of the shared overlap', () {
    expect(
      WhisperChunkOverlapPolicy.keepSegment(
        chunkOffsetMs: 28000,
        overlapMs: 2000,
        localStartMs: 0,
        localEndMs: 800,
      ),
      isFalse,
    );
    expect(
      WhisperChunkOverlapPolicy.keepSegment(
        chunkOffsetMs: 28000,
        overlapMs: 2000,
        localStartMs: 900,
        localEndMs: 1300,
      ),
      isTrue,
    );
  });

  test('later chunk retains segments around the overlap end', () {
    expect(
      WhisperChunkOverlapPolicy.keepSegment(
        chunkOffsetMs: 56000,
        overlapMs: 2000,
        localStartMs: 1800,
        localEndMs: 2600,
      ),
      isTrue,
    );
  });

  test('invalid or empty segment intervals are rejected', () {
    expect(
      WhisperChunkOverlapPolicy.keepSegment(
        chunkOffsetMs: 28000,
        overlapMs: 2000,
        localStartMs: 1000,
        localEndMs: 1000,
      ),
      isFalse,
    );
  });
}
