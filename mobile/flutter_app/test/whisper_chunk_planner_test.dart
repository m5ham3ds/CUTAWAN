import 'package:cutawan_mobile/services/whisper_chunk_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short and exact thirty-second audio use one complete chunk', () {
    final short = WhisperChunkPlanner.plan(5 * 16000);
    expect(short, hasLength(1));
    expect(short.single.startSample, 0);
    expect(short.single.endSample, 5 * 16000);
    expect(short.single.ownedStartSample, 0);
    expect(short.single.ownedEndSample, 5 * 16000);

    final exact = WhisperChunkPlanner.plan(30 * 16000);
    expect(exact, hasLength(1));
    expect(exact.single.ownedStartSample, 0);
    expect(exact.single.ownedEndSample, 30 * 16000);
  });

  test('overlap ownership is contiguous with no gaps or double ownership', () {
    final total = 60 * 16000;
    final chunks = WhisperChunkPlanner.plan(total);

    expect(chunks.map((chunk) => chunk.startSample).toList(), [
      0,
      28 * 16000,
      56 * 16000,
    ]);
    expect(chunks.first.ownedStartSample, 0);
    expect(chunks.first.ownedEndSample, 29 * 16000);
    expect(chunks[1].ownedStartSample, 29 * 16000);
    expect(chunks[1].ownedEndSample, 57 * 16000);
    expect(chunks.last.ownedStartSample, 57 * 16000);
    expect(chunks.last.ownedEndSample, total);

    for (var index = 1; index < chunks.length; index++) {
      expect(chunks[index].ownedStartSample, chunks[index - 1].ownedEndSample);
    }
    expect(chunks.first.ownsMidpointMs(29000), isFalse);
    expect(chunks[1].ownsMidpointMs(29000), isTrue);
    expect(chunks[1].ownsMidpointMs(57000), isFalse);
    expect(chunks.last.ownsMidpointMs(57000), isTrue);
  });

  test('chunk ownership remains contiguous around the first overlap boundary', () {
    final total = 30 * 16000 + 1;
    final chunks = WhisperChunkPlanner.plan(total);

    expect(chunks, hasLength(2));
    expect(chunks.first.ownedEndSample, 29 * 16000);
    expect(chunks.last.ownedStartSample, 29 * 16000);
    expect(chunks.last.ownedEndSample, total);
  });

  test('zero input is empty and negative input is rejected', () {
    expect(WhisperChunkPlanner.plan(0), isEmpty);
    expect(() => WhisperChunkPlanner.plan(-1), throwsRangeError);
  });
}
